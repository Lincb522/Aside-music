import Foundation

public struct NCMUploadFile: Sendable {
    public let filename: String
    public let mimeType: String
    public let data: Data

    public init(filename: String, mimeType: String, data: Data) {
        self.filename = filename
        self.mimeType = mimeType
        self.data = data
    }
}

public struct NCMVoiceUploadMetadata: Sendable {
    public var voiceListID: String
    public var categoryID: String
    public var secondCategoryID: String
    public var description: String
    public var songName: String?
    public var autoPublish: Bool
    public var autoPublishText: String?
    public var coverImageID: String?
    public var composedSongIDs: [Int]
    public var isPrivate: Bool
    public var publishTime: Int
    public var orderNumber: Int

    public init(
        voiceListID: String,
        categoryID: String,
        secondCategoryID: String,
        description: String,
        songName: String? = nil,
        autoPublish: Bool = false,
        autoPublishText: String? = nil,
        coverImageID: String? = nil,
        composedSongIDs: [Int] = [],
        isPrivate: Bool = false,
        publishTime: Int = 0,
        orderNumber: Int = 1
    ) {
        self.voiceListID = voiceListID
        self.categoryID = categoryID
        self.secondCategoryID = secondCategoryID
        self.description = description
        self.songName = songName
        self.autoPublish = autoPublish
        self.autoPublishText = autoPublishText
        self.coverImageID = coverImageID
        self.composedSongIDs = composedSongIDs
        self.isPrivate = isPrivate
        self.publishTime = publishTime
        self.orderNumber = orderNumber
    }

    fileprivate var requestFields: [String: String] {
        var fields: [String: String] = [
            "autoPublish": autoPublish ? "1" : "0",
            "categoryId": categoryID,
            "description": description,
            "privacy": isPrivate ? "1" : "0",
            "publishTime": String(publishTime),
            "orderNo": String(orderNumber),
            "secondCategoryId": secondCategoryID,
            "voiceListId": voiceListID,
        ]
        if let songName { fields["songName"] = songName }
        if let autoPublishText { fields["autoPublishText"] = autoPublishText }
        if let coverImageID { fields["coverImgId"] = coverImageID }
        if !composedSongIDs.isEmpty {
            fields["composedSongs"] = composedSongIDs.map(String.init).joined(separator: ",")
        }
        return fields
    }
}

private struct MultipartFormData {
    let boundary: String
    private(set) var data = Data()

    mutating func appendField(name: String, value: String) {
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        append(value)
        append("\r\n")
    }

    mutating func appendFile(name: String, file: NCMUploadFile) {
        let filename = file.filename.replacingOccurrences(of: "[\"\\r\\n]", with: "_", options: .regularExpression)
        let mimeType = file.mimeType.replacingOccurrences(of: "[\\r\\n]", with: "", options: .regularExpression)
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
        append("Content-Type: \(mimeType.isEmpty ? "application/octet-stream" : mimeType)\r\n\r\n")
        data.append(file.data)
        append("\r\n")
    }

    mutating func finish() {
        append("--\(boundary)--\r\n")
    }

    private mutating func append(_ value: String) {
        data.append(Data(value.utf8))
    }
}

public enum EventPrivacy: Int, Codable, CaseIterable, Sendable {
    case everyone = 0
    case following = 1
    case onlyMe = 2
    case mutualFollowing = 6
}

public enum RepUGCExamType: String, Codable, CaseIterable, Sendable {
    case musicalStyle = "musicalStyleEnter"
    case language = "languageEnter"
    case originalSinger = "oriSingerEnter"
    case emotion = "emotionEnter"
}

public struct AdListeningRightsGainParameters: Sendable {
    public var reqUID: String?
    public var contextInfo: String?
    public var creativeType: Int?
    public var generalRightsInfo: String?
    public var typeIDs: String?
    public var uid: Int?
    public var exposureTime: Int?
    public var clickTime: Int?
    public var extraRightsType: Int?
    public var playContinuously: Bool?
    public var source: Int?
    public var rightsGainMethod: Int?
    public var extraRightsGainMethod: Int?
    public var extraRightsGainDuration: Int?
    public var nextRightsGainDuration: Int?
    public var rightsGainType: Int?
    public var rightsGainDuration: Int?
    public var gainMethodStep: Int?
    public var rightsExtJSON: String?
    public var appInfo: String?
    public var installed: Int?
    public var sniffTime: Int?

    public init(
        reqUID: String? = nil,
        contextInfo: String? = nil,
        creativeType: Int? = nil,
        generalRightsInfo: String? = nil,
        typeIDs: String? = nil,
        uid: Int? = nil,
        exposureTime: Int? = nil,
        clickTime: Int? = nil,
        extraRightsType: Int? = nil,
        playContinuously: Bool? = nil,
        source: Int? = nil,
        rightsGainMethod: Int? = nil,
        extraRightsGainMethod: Int? = nil,
        extraRightsGainDuration: Int? = nil,
        nextRightsGainDuration: Int? = nil,
        rightsGainType: Int? = nil,
        rightsGainDuration: Int? = nil,
        gainMethodStep: Int? = nil,
        rightsExtJSON: String? = nil,
        appInfo: String? = nil,
        installed: Int? = nil,
        sniffTime: Int? = nil
    ) {
        self.reqUID = reqUID
        self.contextInfo = contextInfo
        self.creativeType = creativeType
        self.generalRightsInfo = generalRightsInfo
        self.typeIDs = typeIDs
        self.uid = uid
        self.exposureTime = exposureTime
        self.clickTime = clickTime
        self.extraRightsType = extraRightsType
        self.playContinuously = playContinuously
        self.source = source
        self.rightsGainMethod = rightsGainMethod
        self.extraRightsGainMethod = extraRightsGainMethod
        self.extraRightsGainDuration = extraRightsGainDuration
        self.nextRightsGainDuration = nextRightsGainDuration
        self.rightsGainType = rightsGainType
        self.rightsGainDuration = rightsGainDuration
        self.gainMethodStep = gainMethodStep
        self.rightsExtJSON = rightsExtJSON
        self.appInfo = appInfo
        self.installed = installed
        self.sniffTime = sniffTime
    }

    fileprivate var requestData: [String: Any] {
        var data: [String: Any] = [:]
        if let reqUID { data["reqUid"] = reqUID }
        if let contextInfo { data["contextInfo"] = contextInfo }
        if let creativeType { data["creativeType"] = creativeType }
        if let generalRightsInfo { data["generalRightsInfo"] = generalRightsInfo }
        if let typeIDs { data["type_ids"] = typeIDs }
        if let uid { data["uid"] = uid }
        if let exposureTime { data["exposureTime"] = exposureTime }
        if let clickTime { data["clickTime"] = clickTime }
        if let extraRightsType { data["extraRightsType"] = extraRightsType }
        if playContinuously == true { data["playContinuously"] = true }
        if let source { data["source"] = source }
        if let rightsGainMethod { data["rightsGainMethod"] = rightsGainMethod }
        if let extraRightsGainMethod { data["extraRightsGainMethod"] = extraRightsGainMethod }
        if let extraRightsGainDuration { data["extraRightsGainDuration"] = extraRightsGainDuration }
        if let nextRightsGainDuration { data["nextRightsGainDuration"] = nextRightsGainDuration }
        if let rightsGainType { data["rightsGainType"] = rightsGainType }
        if let rightsGainDuration { data["rightsGainDuration"] = rightsGainDuration }
        if let gainMethodStep { data["gainMethodStep"] = gainMethodStep }
        if let rightsExtJSON { data["rightsExtJson"] = rightsExtJSON }
        if let appInfo { data["appInfo"] = appInfo }
        if let installed { data["installed"] = installed }
        if let sniffTime { data["sniffTime"] = sniffTime }
        return data
    }
}

extension NCMClient {
    public func voiceUpload(
        songFile: NCMUploadFile,
        imageFile: NCMUploadFile? = nil,
        metadata: NCMVoiceUploadMetadata
    ) async throws -> APIResponse {
        guard let serverUrl else {
            throw NCMError.invalidResponse(detail: "voiceUpload 仅支持后端代理模式，请先设置 serverUrl")
        }

        let route = "/voice/upload"
        let base = serverUrl.hasSuffix("/") ? String(serverUrl.dropLast()) : serverUrl
        guard var components = URLComponents(string: base + route) else {
            throw NCMError.invalidResponse(detail: "无效的后端 URL")
        }
        if let apiToken, !apiToken.isEmpty {
            components.queryItems = (components.queryItems ?? []) + [URLQueryItem(name: "token", value: apiToken)]
        }
        guard let url = components.url else {
            throw NCMError.invalidResponse(detail: "无效的后端 URL")
        }

        let boundary = "NCM-\(UUID().uuidString)"
        var form = MultipartFormData(boundary: boundary)
        for (name, value) in metadata.requestFields.sorted(by: { $0.key < $1.key }) {
            form.appendField(name: name, value: value)
        }
        form.appendFile(name: "songFile", file: songFile)
        if let imageFile {
            form.appendFile(name: "imgFile", file: imageFile)
        }
        form.finish()

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        let expectedSessionGeneration = requestSessionGeneration()
        guard let cookieSnapshot = requestClient.sessionManager.cookieHeaderSnapshot(
            for: route,
            crypto: .eapi,
            ifSessionGeneration: expectedSessionGeneration
        ) else {
            throw CancellationError()
        }
        let cookie = cookieSnapshot.header
        if !cookie.isEmpty {
            request.setValue(cookie, forHTTPHeaderField: "Cookie")
        }
        request.httpBody = form.data

        let start = CFAbsoluteTimeGetCurrent()
        let (data, response) = try await requestClient.session.data(for: request)
        let httpResponse = response as? HTTPURLResponse
        return try parseProxyResponse(
            data: data,
            httpResponse: httpResponse,
            statusCode: httpResponse?.statusCode ?? 200,
            route: route,
            uri: route,
            ms: Int((CFAbsoluteTimeGetCurrent() - start) * 1_000),
            expectedSessionGeneration: cookieSnapshot.sessionGeneration
        )
    }

    public func adGet(typeIDs: String = "[\"400002_0\"]") async throws -> APIResponse {
        try await backendRoute("/ad/get", data: ["type_ids": typeIDs])
    }

    public func adListeningRights() async throws -> APIResponse {
        try await backendRoute("/ad/listening/rights")
    }

    public func adListeningRightsGain(
        _ parameters: AdListeningRightsGainParameters = .init()
    ) async throws -> APIResponse {
        try await backendRoute("/ad/listening/rights/gain", data: parameters.requestData)
    }

    public func captchaSafeSent(ctcode: String = "86") async throws -> APIResponse {
        try await backendRoute("/captcha/safe/sent", data: ["ctcode": ctcode])
    }

    public func captchaSentV1(phone: String, ctcode: String = "86") async throws -> APIResponse {
        try await backendRoute("/captcha/sent/v1", data: ["phone": phone, "ctcode": ctcode])
    }

    public func commentAdd(id: Int, type: CommentType, content: String) async throws -> APIResponse {
        try await backendRoute("/comment/add", data: [
            "id": id,
            "type": type.rawValue,
            "content": content,
        ])
    }

    public func commentDelete(id: Int, type: CommentType, commentID: Int) async throws -> APIResponse {
        try await backendRoute("/comment/delete", data: [
            "id": id,
            "type": type.rawValue,
            "cid": commentID,
        ])
    }

    public func commentReply(
        id: Int,
        type: CommentType,
        commentID: Int,
        content: String
    ) async throws -> APIResponse {
        try await backendRoute("/comment/reply", data: [
            "id": id,
            "type": type.rawValue,
            "cid": commentID,
            "content": content,
        ])
    }

    public func deviceKickoff(deviceKey: String, captcha: String? = nil) async throws -> APIResponse {
        var data: [String: Any] = ["deviceKey": deviceKey]
        if let captcha { data["captcha"] = captcha }
        return try await backendRoute("/device/kickoff", data: data)
    }

    public func deviceList() async throws -> APIResponse {
        try await backendRoute("/device/list")
    }

    public func eventPrivacy(eventID: String, privacy: EventPrivacy) async throws -> APIResponse {
        try await backendRoute("/event/privacy", data: [
            "evId": eventID,
            "privacy": privacy.rawValue,
        ])
    }

    public func likeV1(id: Int, like: Bool = true) async throws -> APIResponse {
        try await backendRoute("/like/v1", data: ["id": id, "like": like])
    }

    public func middlePlayDoLottery(
        activityID: Int = 6_501_202,
        drawCount: Int = 1
    ) async throws -> APIResponse {
        try await backendRoute("/middle/play/do/lottery", data: [
            "activityId": activityID,
            "drawCount": drawCount,
        ])
    }

    public func middlePlayLotteryRemainChance(
        activityID: Int = 6_501_202
    ) async throws -> APIResponse {
        try await backendRoute("/middle/play/lottery/remain/chance", data: ["activityId": activityID])
    }

    public func registerCheckTokenV2() async throws -> APIResponse {
        try await backendRoute("/register/checktoken/v2")
    }

    public func registerCheckTokenV3() async throws -> APIResponse {
        try await backendRoute("/register/checktoken/v3")
    }

    public func repUGCActivityCollect(activityID: Int = 5_001) async throws -> APIResponse {
        try await backendRoute("/rep/ugc/activity/collect", data: ["activityId": activityID])
    }

    public func repUGCActivityGet() async throws -> APIResponse {
        try await backendRoute("/rep/ugc/activity/get")
    }

    public func repUGCExamInfoGet(examType: RepUGCExamType) async throws -> APIResponse {
        try await backendRoute("/rep/ugc/exam/info/get", data: ["examType": examType.rawValue])
    }

    public func repUGCExamQuestionSingleGet(
        examType: RepUGCExamType,
        taskID: String
    ) async throws -> APIResponse {
        try await backendRoute("/rep/ugc/exam/question/single/get", data: [
            "examType": examType.rawValue,
            "taskId": taskID,
        ])
    }

    public func repUGCExamResultGet(
        examType: RepUGCExamType,
        taskID: String
    ) async throws -> APIResponse {
        try await backendRoute("/rep/ugc/exam/result/get", data: [
            "examType": examType.rawValue,
            "taskId": taskID,
        ])
    }

    public func repUGCExamStart(examType: RepUGCExamType) async throws -> APIResponse {
        try await backendRoute("/rep/ugc/exam/start", data: ["examType": examType.rawValue])
    }

    public func repUGCExamSubmit(
        examType: RepUGCExamType,
        taskID: String,
        questionID: String,
        answer: String
    ) async throws -> APIResponse {
        try await backendRoute("/rep/ugc/exam/submit", data: [
            "examType": examType.rawValue,
            "taskId": taskID,
            "questionId": questionID,
            "answer": answer,
        ])
    }

    public func repUGCUserCollectVIP(activityID: Int = 5_001) async throws -> APIResponse {
        try await backendRoute("/rep/ugc/user/collect-vip", data: ["activityId": activityID])
    }

    public func repUGCUserGet() async throws -> APIResponse {
        try await backendRoute("/rep/ugc/user/get")
    }

    public func repUGCUserSign() async throws -> APIResponse {
        try await backendRoute("/rep/ugc/user/sign")
    }

    public func repUGCUserVIP() async throws -> APIResponse {
        try await backendRoute("/rep/ugc/user/vip")
    }

    public func songSimiGet(id: Int) async throws -> APIResponse {
        try await backendRoute("/song/simi/get", data: ["id": id])
    }

    public func songWikiInfo(id: Int) async throws -> APIResponse {
        try await backendRoute("/song/wiki/info", data: ["id": id])
    }

    public func thinktankAuditResourceDetail(type: Int = 4) async throws -> APIResponse {
        try await backendRoute("/thinktank/audit/resource/detail", data: ["type": type])
    }

    public func thinktankAuditResourceUpdate(
        taskID: String,
        judgement: Int,
        type: Int = 4
    ) async throws -> APIResponse {
        try await backendRoute("/thinktank/audit/resource/update", data: [
            "taskId": taskID,
            "judgement": judgement,
            "type": type,
        ])
    }

    public func userEventAll() async throws -> APIResponse {
        try await backendRoute("/user/event/all")
    }

    public func yunbeiTaskFinishV1(yunbeiAmount: Int = 150) async throws -> APIResponse {
        try await backendRoute("/yunbei/task/finish/v1", data: ["yunbeiAmount": yunbeiAmount])
    }

    public func yunbeiTaskListV1() async throws -> APIResponse {
        try await backendRoute("/yunbei/task/list/v1")
    }

    public func yunbeiTaskRecommendSong(
        offset: Int = 0,
        limit: Int = 10
    ) async throws -> APIResponse {
        try await backendRoute("/yunbei/task/recommend/song", data: [
            "offset": offset,
            "limit": limit,
        ])
    }
}
