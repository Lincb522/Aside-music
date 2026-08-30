import Foundation
import Network
import XCTest
@testable import NeteaseCloudMusicAPI

final class LoopbackHTTPServer: @unchecked Sendable {
    private let listener: NWListener
    private let failFirstRedirect: Bool
    private let queue = DispatchQueue(label: "NCMContractTests.LoopbackHTTPServer")
    private let ready = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var boundPort: UInt16?
    private var redirectCount = 0
    private var finalCount = 0
    private var normalCount = 0

    init(failFirstRedirect: Bool = false) throws {
        self.failFirstRedirect = failFirstRedirect
        listener = try NWListener(using: .tcp, on: .any)
        listener.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.lock.lock()
                self.boundPort = self.listener.port?.rawValue
                self.lock.unlock()
                self.ready.signal()
            case .failed:
                self.ready.signal()
            default:
                break
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }
        listener.start(queue: queue)

        guard ready.wait(timeout: .now() + 5) == .success, port != nil else {
            listener.cancel()
            throw NSError(domain: "NCMContractTests.LoopbackHTTPServer", code: 1)
        }
    }

    deinit {
        listener.cancel()
    }

    var baseURL: String {
        "http://127.0.0.1:\(port!)"
    }

    var requestCounts: (redirect: Int, final: Int, normal: Int) {
        lock.lock()
        defer { lock.unlock() }
        return (redirectCount, finalCount, normalCount)
    }

    private var port: UInt16? {
        lock.lock()
        defer { lock.unlock() }
        return boundPort
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        receiveRequest(on: connection, data: Data())
    }

    private func receiveRequest(on connection: NWConnection, data: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16_384) { [weak self] chunk, _, complete, error in
            guard let self else { return }
            var requestData = data
            if let chunk { requestData.append(chunk) }
            if requestData.range(of: Data("\r\n\r\n".utf8)) != nil || complete || error != nil {
                self.respond(to: connection, requestData: requestData)
            } else {
                self.receiveRequest(on: connection, data: requestData)
            }
        }
    }

    private func respond(to connection: NWConnection, requestData: Data) {
        let requestLine = String(decoding: requestData, as: UTF8.self)
            .components(separatedBy: "\r\n")
            .first ?? ""
        let path = requestLine.split(separator: " ").dropFirst().first.map(String.init) ?? "/"

        let response: String
        let redirectLocation = "\(baseURL)/final.mp3"
        lock.lock()
        if path == "/song/url/v1/302" {
            redirectCount += 1
            if failFirstRedirect && redirectCount == 1 {
                response = "HTTP/1.1 500 Internal Server Error\r\nContent-Type: application/json\r\nContent-Length: 30\r\nConnection: close\r\n\r\n{\"code\":500,\"message\":\"retry\"}"
            } else {
                response = "HTTP/1.1 302 Found\r\nLocation: \(redirectLocation)\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
            }
        } else if path == "/final.mp3" {
            finalCount += 1
            response = "HTTP/1.1 200 OK\r\nContent-Length: 5\r\nConnection: close\r\n\r\nAUDIO"
        } else {
            normalCount += 1
            response = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: 12\r\nConnection: close\r\n\r\n{\"code\":200}"
        }
        lock.unlock()

        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}

final class RecordingURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var recordedRequest: URLRequest?
    private static var retryRedirectAttempts = 0

    static func reset() {
        lock.lock()
        recordedRequest = nil
        retryRedirectAttempts = 0
        lock.unlock()
    }

    static func request() -> URLRequest? {
        lock.lock()
        defer { lock.unlock() }
        return recordedRequest
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        var captured = request
        if captured.httpBody == nil, let stream = captured.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var body = Data()
            var buffer = [UInt8](repeating: 0, count: 4_096)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                body.append(buffer, count: count)
            }
            captured.httpBody = body
        }
        let path = request.url?.path
        let isRedirect = path == "/song/url/v1/302"
        let isQRCheck = path == "/login/qr/check"
        let isRetryRedirect = isRedirect
            && String(decoding: captured.httpBody ?? Data(), as: UTF8.self).contains("id=500")
        Self.lock.lock()
        Self.recordedRequest = captured
        if isRetryRedirect { Self.retryRedirectAttempts += 1 }
        let shouldFailFirst = isRetryRedirect && Self.retryRedirectAttempts == 1
        Self.lock.unlock()

        var headers = ["Content-Type": "application/json"]
        if isRedirect && !shouldFailFirst {
            headers["Location"] = "https://audio.example.test/final.mp3"
        } else {
            headers["Set-Cookie"] = "MUSIC_U=session-value; Path=/; HttpOnly"
        }
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: shouldFailFirst ? 500 : isRedirect ? 302 : 200,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        let responseData = shouldFailFirst
            ? Data(#"{"code":500,"message":"retry"}"#.utf8)
            : isQRCheck
            ? Data(#"{"code":803,"cookie":"MUSIC_A=; Max-Age=0; Path=/; MUSIC_U=qr-session; Path=/; HttpOnly"}"#.utf8)
            : isRedirect ? Data() : Data(#"{"code":200}"#.utf8)
        client?.urlProtocol(self, didLoad: responseData)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

final class DelayedSessionURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var started = DispatchSemaphore(value: 0)
    private static var release = DispatchSemaphore(value: 0)

    static func reset() {
        lock.lock()
        started = DispatchSemaphore(value: 0)
        release = DispatchSemaphore(value: 0)
        lock.unlock()
    }

    static func waitUntilStarted(timeout: DispatchTime) -> DispatchTimeoutResult {
        lock.lock()
        let semaphore = started
        lock.unlock()
        return semaphore.wait(timeout: timeout)
    }

    static func releaseResponse() {
        lock.lock()
        let semaphore = release
        lock.unlock()
        semaphore.signal()
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        let started = Self.started
        let release = Self.release
        Self.lock.unlock()
        started.signal()
        guard release.wait(timeout: .now() + 5) == .success else {
            client?.urlProtocol(self, didFailWithError: URLError(.timedOut))
            return
        }

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": "application/json",
                "Set-Cookie": "MUSIC_U=stale-session; Path=/; HttpOnly",
            ]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(#"{"code":200}"#.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {
        Self.releaseResponse()
    }
}

final class Enhanced440ContractTests: XCTestCase {
    private var client: NCMClient!

    override func setUp() {
        super.setUp()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RecordingURLProtocol.self]
        client = NCMClient(
            serverUrl: "https://backend.example.test",
            urlSession: URLSession(configuration: configuration)
        )
    }

    override func tearDown() {
        client = nil
        super.tearDown()
    }

    private func assertRoute(
        _ path: String,
        call: () async throws -> APIResponse,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        RecordingURLProtocol.reset()
        _ = try await call()
        let request = try XCTUnwrap(RecordingURLProtocol.request(), file: file, line: line)
        XCTAssertEqual(request.httpMethod, "POST", file: file, line: line)
        XCTAssertEqual(request.url?.path, path, file: file, line: line)
    }

    private func formBody() throws -> [String: String] {
        let request = try XCTUnwrap(RecordingURLProtocol.request())
        guard let data = request.httpBody, !data.isEmpty else { return [:] }
        let body = try XCTUnwrap(String(data: data, encoding: .utf8))
        var components = URLComponents()
        components.percentEncodedQuery = body
        return Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map {
            ($0.name, $0.value ?? "")
        })
    }

    func testAdCaptchaCommentAndDeviceRoutes() async throws {
        XCTAssertEqual(NCMAPIVersion.backend, "4.40.1")
        try await assertRoute("/ad/get") { try await client.adGet() }
        try await assertRoute("/ad/listening/rights") { try await client.adListeningRights() }
        try await assertRoute("/ad/listening/rights/gain") {
            try await client.adListeningRightsGain()
        }
        try await assertRoute("/captcha/safe/sent") { try await client.captchaSafeSent() }
        try await assertRoute("/captcha/sent/v1") { try await client.captchaSentV1(phone: "10000000000") }
        try await assertRoute("/comment/add") {
            try await client.commentAdd(id: 1, type: .podcast, content: "content")
        }
        XCTAssertEqual(try formBody()["type"], "7")
        try await assertRoute("/comment/delete") {
            try await client.commentDelete(id: 1, type: .song, commentID: 2)
        }
        try await assertRoute("/comment/reply") {
            try await client.commentReply(id: 1, type: .song, commentID: 2, content: "reply")
        }
        try await assertRoute("/device/kickoff") { try await client.deviceKickoff(deviceKey: "device-key") }
        try await assertRoute("/device/list") { try await client.deviceList() }
    }

    func testEventLotteryAndCheckTokenRoutes() async throws {
        try await assertRoute("/event/privacy") {
            try await client.eventPrivacy(eventID: "event-id", privacy: .mutualFollowing)
        }
        try await assertRoute("/like/v1") { try await client.likeV1(id: 1) }
        try await assertRoute("/middle/play/do/lottery") { try await client.middlePlayDoLottery() }
        try await assertRoute("/middle/play/lottery/remain/chance") {
            try await client.middlePlayLotteryRemainChance()
        }
        try await assertRoute("/register/checktoken/v2") { try await client.registerCheckTokenV2() }
        try await assertRoute("/register/checktoken/v3") { try await client.registerCheckTokenV3() }
    }

    func testRepUGCRoutes() async throws {
        try await assertRoute("/rep/ugc/activity/collect") { try await client.repUGCActivityCollect() }
        try await assertRoute("/rep/ugc/activity/get") { try await client.repUGCActivityGet() }
        try await assertRoute("/rep/ugc/exam/info/get") {
            try await client.repUGCExamInfoGet(examType: .musicalStyle)
        }
        try await assertRoute("/rep/ugc/exam/question/single/get") {
            try await client.repUGCExamQuestionSingleGet(examType: .language, taskID: "task-id")
        }
        try await assertRoute("/rep/ugc/exam/result/get") {
            try await client.repUGCExamResultGet(examType: .originalSinger, taskID: "task-id")
        }
        try await assertRoute("/rep/ugc/exam/start") {
            try await client.repUGCExamStart(examType: .emotion)
        }
        try await assertRoute("/rep/ugc/exam/submit") {
            try await client.repUGCExamSubmit(
                examType: .emotion,
                taskID: "task-id",
                questionID: "question-id",
                answer: "A"
            )
        }
        try await assertRoute("/rep/ugc/user/collect-vip") { try await client.repUGCUserCollectVIP() }
        try await assertRoute("/rep/ugc/user/get") { try await client.repUGCUserGet() }
        try await assertRoute("/rep/ugc/user/sign") { try await client.repUGCUserSign() }
        try await assertRoute("/rep/ugc/user/vip") { try await client.repUGCUserVIP() }
    }

    func testSongThinktankEventAndYunbeiRoutes() async throws {
        try await assertRoute("/song/simi/get") { try await client.songSimiGet(id: 1) }
        try await assertRoute("/song/wiki/info") { try await client.songWikiInfo(id: 1) }
        try await assertRoute("/thinktank/audit/resource/detail") {
            try await client.thinktankAuditResourceDetail()
        }
        try await assertRoute("/thinktank/audit/resource/update") {
            try await client.thinktankAuditResourceUpdate(taskID: "task-id", judgement: 1)
        }
        try await assertRoute("/user/event/all") { try await client.userEventAll() }
        try await assertRoute("/yunbei/task/finish/v1") { try await client.yunbeiTaskFinishV1() }
        try await assertRoute("/yunbei/task/list/v1") { try await client.yunbeiTaskListV1() }
        try await assertRoute("/yunbei/task/recommend/song") { try await client.yunbeiTaskRecommendSong() }
    }

    func testCriticalV440ParameterNamesAndValues() async throws {
        let gain = AdListeningRightsGainParameters(
            reqUID: "request-id",
            typeIDs: "[\"400002_0\"]",
            playContinuously: true,
            rightsExtJSON: "{}"
        )
        try await assertRoute("/ad/listening/rights/gain") {
            try await client.adListeningRightsGain(gain)
        }
        var body = try formBody()
        XCTAssertEqual(body["reqUid"], "request-id")
        XCTAssertEqual(body["type_ids"], "[\"400002_0\"]")
        XCTAssertEqual(body["playContinuously"], "true")
        XCTAssertEqual(body["rightsExtJson"], "{}")

        try await assertRoute("/ad/listening/rights/gain") {
            try await client.adListeningRightsGain(.init(reqUID: "request-id", playContinuously: false))
        }
        body = try formBody()
        XCTAssertEqual(body["reqUid"], "request-id")
        XCTAssertNil(body["playContinuously"])

        try await assertRoute("/device/kickoff") {
            try await client.deviceKickoff(deviceKey: "device-key", captcha: "1234")
        }
        body = try formBody()
        XCTAssertEqual(body["deviceKey"], "device-key")
        XCTAssertNil(body["key"])
        XCTAssertEqual(body["captcha"], "1234")

        try await assertRoute("/event/privacy") {
            try await client.eventPrivacy(eventID: "event-id", privacy: .mutualFollowing)
        }
        body = try formBody()
        XCTAssertEqual(body["evId"], "event-id")
        XCTAssertEqual(body["privacy"], "6")
    }

    func testChangedLoginAndSongV1Contracts() async throws {
        let directCaptchaData = NCMClient.loginCellphoneRequestData(
            phone: "10000000000",
            password: "",
            countrycode: "852",
            captcha: "1234",
            secureCaptcha: "secure-captcha"
        )
        XCTAssertEqual(directCaptchaData["secureCaptcha"] as? String, "secure-captcha")
        XCTAssertNil(directCaptchaData["sca"])
        XCTAssertNil(directCaptchaData["password"])

        try await assertRoute("/captcha/sent/v1") {
            try await client.captchaSentV1(phone: "10000000000", ctcode: "852")
        }
        var body = try formBody()
        XCTAssertEqual(body["phone"], "10000000000")
        XCTAssertEqual(body["ctcode"], "852")
        XCTAssertNil(body["cellphone"])
        XCTAssertNil(body["secrete"])

        try await assertRoute("/login/cellphone") {
            try await client.loginCellphone(
                phone: "10000000000",
                countrycode: "852",
                captcha: "1234",
                secureCaptcha: "secure-captcha"
            )
        }
        body = try formBody()
        XCTAssertEqual(body["phone"], "10000000000")
        XCTAssertEqual(body["countrycode"], "852")
        XCTAssertEqual(body["captcha"], "1234")
        XCTAssertEqual(body["sca"], "secure-captcha")
        XCTAssertNil(body["secureCaptcha"])
        XCTAssertEqual(body["type"], "1")
        XCTAssertEqual(body["https"], "true")
        XCTAssertEqual(body["remember"], "true")
        XCTAssertNil(body["password"])
        XCTAssertNil(body["md5_password"])

        try await assertRoute("/login/cellphone") {
            try await client.loginCellphone(
                phone: "10000000000",
                password: "legacy-password",
                countrycode: "86"
            )
        }
        body = try formBody()
        XCTAssertEqual(body["md5_password"], CryptoEngine.md5("legacy-password"))
        XCTAssertNil(body["password"])
        XCTAssertNil(body["captcha"])
        XCTAssertNil(body["sca"])
        XCTAssertNil(body["secureCaptcha"])

        let directPasswordData = NCMClient.loginCellphoneRequestData(
            phone: "10000000000",
            password: "legacy-password",
            countrycode: "86",
            captcha: nil,
            secureCaptcha: nil
        )
        XCTAssertEqual(
            directPasswordData["password"] as? String,
            CryptoEngine.md5("legacy-password")
        )
        XCTAssertNil(directPasswordData["md5_password"])

        try await assertRoute("/song/url/v1") {
            try await client.songUrlV1(ids: [1], level: .vivid)
        }
        body = try formBody()
        XCTAssertEqual(body["id"], "1")
        XCTAssertEqual(body["level"], "vivid")
        XCTAssertEqual(body["encodeType"], "mp3")
        XCTAssertNil(body["immerseType"])

        try await assertRoute("/song/url/v1") {
            try await client.songUrlV1(ids: [1], level: .sky, immersiveType: .stereo)
        }
        body = try formBody()
        XCTAssertEqual(body["immerseType"], "ste")
        XCTAssertEqual(body["encodeType"], "flac")

        try await assertRoute("/user/event") {
            try await client.userEvent(uid: 1, lasttime: 0, limit: 20)
        }
        body = try formBody()
        XCTAssertEqual(body["lasttime"], "0")
        XCTAssertEqual(body["fromRN"], "true")
    }

    func testVividDownloadAndRedirectContracts() async throws {
        try await assertRoute("/song/download/url/v1") {
            try await client.songDownloadUrlV1(id: 1, level: .vivid)
        }
        var body = try formBody()
        XCTAssertEqual(body["id"], "1")
        XCTAssertEqual(body["level"], "vivid")

        RecordingURLProtocol.reset()
        let response = try await client.songUrlV1302(id: 1, level: .vivid)
        let request = try XCTUnwrap(RecordingURLProtocol.request())
        XCTAssertEqual(request.url?.path, "/song/url/v1/302")
        body = try formBody()
        XCTAssertEqual(body["id"], "1")
        XCTAssertEqual(body["level"], "vivid")
        XCTAssertEqual(response.status, 302)
        XCTAssertEqual(response.body["code"] as? Int, 302)
        XCTAssertEqual(response.body["url"] as? String, "https://audio.example.test/final.mp3")

        RecordingURLProtocol.reset()
        let retryResponse = try await client.songUrlV1302(id: 500, level: .vivid)
        XCTAssertEqual(retryResponse.status, 302)
        XCTAssertEqual(retryResponse.body["url"] as? String, "https://audio.example.test/final.mp3")
    }

    func testRedirectIsNotFollowedByRealURLSession() async throws {
        let server = try LoopbackHTTPServer()
        let configuration = URLSessionConfiguration.ephemeral
        let liveClient = NCMClient(
            serverUrl: server.baseURL,
            urlSession: URLSession(configuration: configuration)
        )

        let redirect = try await liveClient.songUrlV1302(id: 1, level: .vivid)
        XCTAssertEqual(redirect.status, 302)
        XCTAssertEqual(redirect.body["url"] as? String, "\(server.baseURL)/final.mp3")

        let normal = try await liveClient.deviceList()
        XCTAssertEqual(normal.status, 200)
        let counts = server.requestCounts
        XCTAssertEqual(counts.redirect, 1)
        XCTAssertEqual(counts.final, 0)
        XCTAssertEqual(counts.normal, 1)
    }

    func testRedirectAfterRetryIsNotFollowedByRealURLSession() async throws {
        let server = try LoopbackHTTPServer(failFirstRedirect: true)
        let configuration = URLSessionConfiguration.ephemeral
        let liveClient = NCMClient(
            serverUrl: server.baseURL,
            urlSession: URLSession(configuration: configuration)
        )

        let response = try await liveClient.songUrlV1302(id: 1, level: .vivid)
        XCTAssertEqual(response.status, 302)
        XCTAssertEqual(response.body["url"] as? String, "\(server.baseURL)/final.mp3")
        let counts = server.requestCounts
        XCTAssertEqual(counts.redirect, 2)
        XCTAssertEqual(counts.final, 0)
    }

    func testQRRequestsBypassCachesAndAcceptLoginCookieBody() async throws {
        try await assertRoute("/login/qr/key") { try await client.loginQrKey() }
        var request = try XCTUnwrap(RecordingURLProtocol.request())
        var queryItems = URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertNotNil(queryItems.first { $0.name == "timestamp" }?.value)
        XCTAssertNotNil(queryItems.first { $0.name == "device_uuid" }?.value)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Cache-Control"), "no-store, no-cache, max-age=0")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Pragma"), "no-cache")
        var body = try formBody()
        XCTAssertEqual(body["type"], "3")
        XCTAssertNotNil(body["timestamp"])

        try await assertRoute("/login/qr/check") { try await client.loginQrCheck(key: "qr-key") }
        request = try XCTUnwrap(RecordingURLProtocol.request())
        queryItems = URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertNotNil(queryItems.first { $0.name == "timestamp" }?.value)
        XCTAssertNotNil(queryItems.first { $0.name == "device_uuid" }?.value)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Cache-Control"), "no-store, no-cache, max-age=0")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Pragma"), "no-cache")
        body = try formBody()
        XCTAssertEqual(body["key"], "qr-key")
        XCTAssertEqual(body["type"], "3")
        XCTAssertNotNil(body["timestamp"])

        let response = try await client.loginQrCheck(key: "qr-key")
        XCTAssertEqual(response.body["code"] as? Int, 803)
        let cookie = try XCTUnwrap(response.body["cookie"] as? String)
        XCTAssertEqual(NCMClient.normalizeCookieHeader(cookie), "MUSIC_U=qr-session")
    }

    func testProxyResponseSetCookieUpdatesClientSession() async throws {
        try await assertRoute("/device/list") { try await client.deviceList() }

        XCTAssertEqual(client.currentCookies["MUSIC_U"], "session-value")
    }

    func testCapturedSessionTokenRejectsRequestAfterSessionReplacement() async throws {
        client.setCookie("MUSIC_U=account-a")
        let token = client.captureSessionToken()
        client.clearCookies()
        client.setCookie("MUSIC_U=account-b")
        RecordingURLProtocol.reset()

        do {
            _ = try await client.withSessionToken(token) {
                try await self.client.deviceList()
            }
            XCTFail("A stale session token must not issue a request")
        } catch is CancellationError {
            XCTAssertNil(RecordingURLProtocol.request())
        }
        XCTAssertEqual(client.currentCookies["MUSIC_U"], "account-b")
    }

    func testSessionTokenRejectsResultWhenSessionChangesInsideOperation() async throws {
        client.setCookie("MUSIC_U=account-a")
        let token = client.captureSessionToken()

        do {
            _ = try await client.withSessionToken(token) {
                XCTAssertEqual(try self.client.currentSessionCookieHeader(), "MUSIC_U=account-a")
                self.client.clearCookies()
                self.client.setCookie("MUSIC_U=account-b")
                return 1
            }
            XCTFail("A result produced after session replacement must be cancelled")
        } catch is CancellationError {
            XCTAssertEqual(client.currentCookies["MUSIC_U"], "account-b")
        }
    }

    func testInFlightResponseCannotMutateReplacementSession() async throws {
        DelayedSessionURLProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [DelayedSessionURLProtocol.self]
        let staleClient = NCMClient(
            cookie: "MUSIC_U=account-a",
            serverUrl: "https://backend.example.test",
            urlSession: URLSession(configuration: configuration)
        )

        let request = Task { try await staleClient.deviceList() }
        XCTAssertEqual(
            DelayedSessionURLProtocol.waitUntilStarted(timeout: .now() + 5),
            .success
        )
        staleClient.clearCookies()
        staleClient.setCookie("MUSIC_U=account-b")
        DelayedSessionURLProtocol.releaseResponse()

        do {
            _ = try await request.value
            XCTFail("A response from the replaced session must be cancelled")
        } catch is CancellationError {
            XCTAssertEqual(staleClient.currentCookies["MUSIC_U"], "account-b")
        }
    }

    func testExpiredCookieDoesNotDiscardFollowingLoginCookie() {
        let raw = "MUSIC_A=; Max-Age=0; Expires=Thu, 01 Jan 1970 00:00:00 GMT; Path=/; "
            + "MUSIC_U=session-value; Max-Age=1296000; Path=/; HttpOnly; "
            + "__csrf=csrf-value; Path=/"

        XCTAssertEqual(
            NCMClient.normalizeCookieHeader(raw),
            "MUSIC_U=session-value; __csrf=csrf-value"
        )
    }

    func testCookieNormalizationKeepsLastValueAndAcceptsCleanHeader() {
        XCTAssertEqual(
            NCMClient.normalizeCookieHeader("MUSIC_U=old; Path=/; MUSIC_U=new; Path=/"),
            "MUSIC_U=new"
        )
        XCTAssertEqual(
            NCMClient.normalizeCookieHeader("MUSIC_U=session-value; __csrf=csrf-value"),
            "MUSIC_U=session-value; __csrf=csrf-value"
        )
    }

    func testVoiceUploadUsesMultipartFilesAndCover() async throws {
        let audio = NCMUploadFile(
            filename: "voice.mp3",
            mimeType: "audio/mpeg",
            data: Data([0x01, 0x02])
        )
        let image = NCMUploadFile(
            filename: "cover.jpg",
            mimeType: "image/jpeg",
            data: Data([0x03, 0x04])
        )
        let metadata = NCMVoiceUploadMetadata(
            voiceListID: "10",
            categoryID: "1",
            secondCategoryID: "2",
            description: "Description",
            songName: "Voice"
        )

        try await assertRoute("/voice/upload") {
            try await client.voiceUpload(songFile: audio, imageFile: image, metadata: metadata)
        }

        let request = try XCTUnwrap(RecordingURLProtocol.request())
        XCTAssertTrue(request.value(forHTTPHeaderField: "Content-Type")?.hasPrefix("multipart/form-data; boundary=") == true)
        let body = try XCTUnwrap(request.httpBody)
        let bodyText = String(decoding: body, as: UTF8.self)
        XCTAssertTrue(bodyText.contains("name=\"songFile\"; filename=\"voice.mp3\""))
        XCTAssertTrue(bodyText.contains("name=\"imgFile\"; filename=\"cover.jpg\""))
        XCTAssertTrue(bodyText.contains("name=\"songName\"\r\n\r\nVoice"))
        XCTAssertTrue(bodyText.contains("name=\"categoryId\"\r\n\r\n1"))
        XCTAssertTrue(bodyText.contains("name=\"secondCategoryId\"\r\n\r\n2"))
        XCTAssertTrue(bodyText.contains("name=\"voiceListId\"\r\n\r\n10"))
        XCTAssertTrue(bodyText.contains("name=\"description\"\r\n\r\nDescription"))

        let coverMetadata = NCMVoiceUploadMetadata(
            voiceListID: "10",
            categoryID: "1",
            secondCategoryID: "2",
            description: "Description",
            coverImageID: "99"
        )
        try await assertRoute("/voice/upload") {
            try await client.voiceUpload(songFile: audio, metadata: coverMetadata)
        }
        let coverRequest = try XCTUnwrap(RecordingURLProtocol.request())
        let coverBody = String(decoding: try XCTUnwrap(coverRequest.httpBody), as: UTF8.self)
        XCTAssertFalse(coverBody.contains("name=\"imgFile\""))
        XCTAssertTrue(coverBody.contains("name=\"coverImgId\"\r\n\r\n99"))
    }
}
