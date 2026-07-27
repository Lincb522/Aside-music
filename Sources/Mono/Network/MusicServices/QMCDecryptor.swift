import Foundation

/// QMC2 解密器 — 移植自 qmc2-crypto (Rust)
/// 支持 .mflac / .mgg 加密文件的流式解密
final class QMCDecryptor: @unchecked Sendable {

    // MARK: - Public

    /// 从 ekey 创建解密器
    /// - Parameter ekey: Base64 编码的加密密钥
    /// - Returns: 解密器实例
    static func create(ekey: String) throws -> QMCDecryptor {
        let realKey = try EKeyParser.parse(ekey: ekey)
        if realKey.count > 300 {
            return QMCDecryptor(crypto: RC4Crypto(key: realKey))
        } else {
            return QMCDecryptor(crypto: MapCrypto(key: realKey))
        }
    }

    /// 就地解密数据
    /// - Parameters:
    ///   - data: 要解密的数据（会被原地修改）
    ///   - offset: 数据在原始文件中的字节偏移
    func decrypt(_ data: inout Data, offset: Int) {
        data.withUnsafeMutableBytes { buffer in
            guard let ptr = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            crypto.decrypt(ptr, count: buffer.count, offset: offset)
        }
    }

    /// 解密整个文件数据并返回新 Data
    func decryptData(_ data: Data) -> Data {
        var mutable = data
        decrypt(&mutable, offset: 0)
        return mutable
    }

    // MARK: - Private

    private let crypto: QMC2CryptoProtocol

    private init(crypto: QMC2CryptoProtocol) {
        self.crypto = crypto
    }
}

// MARK: - Protocol

private protocol QMC2CryptoProtocol {
    func decrypt(_ buffer: UnsafeMutablePointer<UInt8>, count: Int, offset: Int)
}

// MARK: - TEA (Tencent variant, 16 rounds)

private enum TEA {
    static let delta: UInt32 = 0x9e3779b9
    static let rounds: UInt32 = 16

    static func ecbDecrypt(block: UInt64, key: (UInt32, UInt32, UInt32, UInt32)) -> UInt64 {
        var y = UInt32(block >> 32)
        var z = UInt32(block & 0xFFFF_FFFF)
        var sum = delta &* rounds

        for _ in 0..<rounds {
            z = z &- (((y << 4) &+ key.2) ^ (sum &+ y) ^ ((y >> 5) &+ key.3))
            y = y &- (((z << 4) &+ key.0) ^ (sum &+ z) ^ ((z >> 5) &+ key.1))
            sum = sum &- delta
        }

        return (UInt64(y) << 32) | UInt64(z)
    }

    static func ecbEncrypt(block: UInt64, key: (UInt32, UInt32, UInt32, UInt32)) -> UInt64 {
        var y = UInt32(block >> 32)
        var z = UInt32(block & 0xFFFF_FFFF)
        var sum: UInt32 = 0

        for _ in 0..<rounds {
            sum = sum &+ delta
            y = y &+ (((z << 4) &+ key.0) ^ (sum &+ z) ^ ((z >> 5) &+ key.1))
            z = z &+ (((y << 4) &+ key.2) ^ (sum &+ y) ^ ((y >> 5) &+ key.3))
        }

        return (UInt64(y) << 32) | UInt64(z)
    }

    static func parseKey(_ keyBytes: [UInt8]) -> (UInt32, UInt32, UInt32, UInt32)? {
        guard keyBytes.count >= 16 else { return nil }
        let k0 = readBE32(keyBytes, 0)
        let k1 = readBE32(keyBytes, 4)
        let k2 = readBE32(keyBytes, 8)
        let k3 = readBE32(keyBytes, 12)
        return (k0, k1, k2, k3)
    }

    static func readBE32(_ data: [UInt8], _ offset: Int) -> UInt32 {
        UInt32(data[offset]) << 24
        | UInt32(data[offset + 1]) << 16
        | UInt32(data[offset + 2]) << 8
        | UInt32(data[offset + 3])
    }

    static func readBE64(_ data: [UInt8], _ offset: Int) -> UInt64 {
        UInt64(readBE32(data, offset)) << 32 | UInt64(readBE32(data, offset + 4))
    }

    static func writeBE64(_ value: UInt64, to data: inout [UInt8], at offset: Int) {
        data[offset]     = UInt8((value >> 56) & 0xFF)
        data[offset + 1] = UInt8((value >> 48) & 0xFF)
        data[offset + 2] = UInt8((value >> 40) & 0xFF)
        data[offset + 3] = UInt8((value >> 32) & 0xFF)
        data[offset + 4] = UInt8((value >> 24) & 0xFF)
        data[offset + 5] = UInt8((value >> 16) & 0xFF)
        data[offset + 6] = UInt8((value >> 8) & 0xFF)
        data[offset + 7] = UInt8(value & 0xFF)
    }
}

// MARK: - tc_tea CBC Decrypt

private enum TcTea {
    static let saltLen = 2
    static let zeroLen = 7
    static let fixedPaddingLen = 1 + saltLen + zeroLen

    /// tc_tea CBC 解密
    static func decrypt(cipher: [UInt8], key: [UInt8]) -> [UInt8]? {
        guard let teaKey = TEA.parseKey(key) else { return nil }
        let inputLen = cipher.count
        guard inputLen >= fixedPaddingLen, inputLen % 8 == 0 else { return nil }

        var plain = [UInt8](repeating: 0, count: inputLen)
        var iv1: UInt64 = 0
        var iv2: UInt64 = 0

        for blockIdx in stride(from: 0, to: inputLen, by: 8) {
            let cipherBlock = TEA.readBE64(cipher, blockIdx)
            let result = cipherBlock ^ iv2
            let nextIv2 = TEA.ecbDecrypt(block: result, key: teaKey)
            let plainBlock = nextIv2 ^ iv1
            TEA.writeBE64(plainBlock, to: &plain, at: blockIdx)
            iv1 = cipherBlock
            iv2 = nextIv2
        }

        let padSize = Int(plain[0] & 0x07)
        let startLoc = 1 + padSize + saltLen
        let endLoc = inputLen - zeroLen

        guard endLoc > startLoc else { return nil }

        let zeroCheck = plain[endLoc...].reduce(0) { $0 | $1 }
        guard zeroCheck == 0 else { return nil }

        return Array(plain[startLoc..<endLoc])
    }
}

// MARK: - EKey Parser

private enum EKeyParser {
    static let encV2Prefix = Array("QQMusic EncV2,Key:".utf8)
    static let encV2Stage1Key = Array("386ZJY!@#*$%^&)(".utf8)
    static let encV2Stage2Key = Array("**#!(#$%&^a1cZ,T".utf8)

    /// 解析 QMC EKey；兼容 EncV2 双层 TEA 包装，并返回供文件解密使用的完整密钥。
    static func parse(ekey: String) throws -> [UInt8] {
        let trimmed = ekey.trimmingCharacters(in: CharacterSet(charactersIn: "\0"))
        guard let decoded = Data(base64Encoded: trimmed) else {
            throw QMCError.ekeyParseError
        }

        var ekeyBytes = Array(decoded)
        guard ekeyBytes.count >= 8 else { throw QMCError.ekeyParseError }

        if ekeyBytes.starts(with: encV2Prefix) {
            let encV2Blob = Array(ekeyBytes[encV2Prefix.count...])
            guard let stage1 = TcTea.decrypt(cipher: encV2Blob, key: encV2Stage1Key) else {
                throw QMCError.keyDeriveError
            }
            guard let stage2 = TcTea.decrypt(cipher: stage1, key: encV2Stage2Key) else {
                throw QMCError.keyDeriveError
            }
            guard let innerDecoded = Data(base64Encoded: Data(stage2)) else {
                throw QMCError.ekeyParseError
            }
            ekeyBytes = Array(innerDecoded)
            guard ekeyBytes.count >= 8 else { throw QMCError.ekeyParseError }
        }

        let header = Array(ekeyBytes[0..<8])
        let body = Array(ekeyBytes[8...])
        let teaKey = deriveTeaKey(header: header)

        guard let decryptedBody = TcTea.decrypt(cipher: body, key: teaKey) else {
            throw QMCError.keyDeriveError
        }

        return header + decryptedBody
    }

    private static func simpleMakeKey(seed: UInt8, size: Int) -> [UInt8] {
        (0..<size).map { i in
            let value = Float(seed) + Float(i) * 0.1
            return UInt8(100.0 * abs(tan(value)))
        }
    }

    private static func deriveTeaKey(header: [UInt8]) -> [UInt8] {
        let simpleKey = simpleMakeKey(seed: 106, size: 8)
        var teaKey = [UInt8](repeating: 0, count: 16)
        for i in stride(from: 0, to: 16, by: 2) {
            teaKey[i] = simpleKey[i / 2]
            teaKey[i + 1] = header[i / 2]
        }
        return teaKey
    }
}

// MARK: - RC4 Variant

private final class RC4Crypto: QMC2CryptoProtocol {
    private static let firstSegmentSize = 0x80      // 128
    private static let otherSegmentSize = 0x1400     // 5120

    private let s: [UInt8]
    private let hash: UInt32
    private let rc4Key: [UInt8]

    init(key: [UInt8]) {
        let n = key.count
        var sBox = [UInt8](repeating: 0, count: n)
        sBox.withUnsafeMutableBufferPointer { sPtr in
            let sBase = sPtr.baseAddress!
            for i in 0..<n { sBase[i] = UInt8(i & 0xFF) }
            key.withUnsafeBufferPointer { kPtr in
                let kBase = kPtr.baseAddress!
                var j = 0
                for i in 0..<n {
                    j = (j &+ Int(sBase[i]) &+ Int(kBase[i])) % n
                    let tmp = sBase[i]; sBase[i] = sBase[j]; sBase[j] = tmp
                }
            }
        }
        self.s = sBox
        self.rc4Key = key
        self.hash = RC4Crypto.calcHashBase(key)
    }

    func decrypt(_ buffer: UnsafeMutablePointer<UInt8>, count: Int, offset: Int) {
        var off = offset
        var remaining = count
        var i = 0

        if off < Self.firstSegmentSize {
            let len = min(remaining, Self.firstSegmentSize - off)
            encodeFirstSegment(buffer + i, count: len, offset: off)
            i += len; remaining -= len; off += len
        }

        let toAlign = off % Self.otherSegmentSize
        if toAlign != 0 {
            let len = min(remaining, Self.otherSegmentSize - toAlign)
            encodeOtherSegment(buffer + i, count: len, offset: off)
            i += len; remaining -= len; off += len
        }

        while remaining > Self.otherSegmentSize {
            encodeOtherSegment(buffer + i, count: Self.otherSegmentSize, offset: off)
            i += Self.otherSegmentSize
            remaining -= Self.otherSegmentSize
            off += Self.otherSegmentSize
        }

        if remaining > 0 {
            encodeOtherSegment(buffer + i, count: remaining, offset: off)
        }
    }

    private func calcSegmentKey(id: Int, seed: UInt8) -> Int {
        let dividend = Double(hash)
        let divisor = Double((id + 1) * Int(seed))
        return Int(dividend / divisor * 100.0)
    }

    private func encodeFirstSegment(_ buf: UnsafeMutablePointer<UInt8>, count: Int, offset: Int) {
        rc4Key.withUnsafeBufferPointer { keyPtr in
            let n = keyPtr.count
            let base = keyPtr.baseAddress!
            for i in 0..<count {
                let pos = offset + i
                let key1 = base[pos % n]
                let key2 = calcSegmentKey(id: pos, seed: key1)
                buf[i] ^= base[key2 % n]
            }
        }
    }

    private func encodeOtherSegment(_ buf: UnsafeMutablePointer<UInt8>, count: Int, offset: Int) {
        let n = rc4Key.count
        let segId = offset / Self.otherSegmentSize
        let segIdSmall = segId & 0x1FF

        var discardCount = calcSegmentKey(id: segId, seed: rc4Key[segIdSmall]) & 0x1FF
        discardCount += offset % Self.otherSegmentSize

        var sBox = s
        sBox.withUnsafeMutableBufferPointer { sPtr in
            let sBase = sPtr.baseAddress!
            var j = 0
            var k = 0

            for _ in 0..<discardCount {
                j = (j &+ 1) % n
                k = (Int(sBase[j]) &+ k) % n
                let tmp = sBase[j]; sBase[j] = sBase[k]; sBase[k] = tmp
            }

            for i in 0..<count {
                j = (j &+ 1) % n
                k = (Int(sBase[j]) &+ k) % n
                let tmp = sBase[j]; sBase[j] = sBase[k]; sBase[k] = tmp
                buf[i] ^= sBase[(Int(sBase[j]) &+ Int(sBase[k])) % n]
            }
        }
    }

    private static func calcHashBase(_ data: [UInt8]) -> UInt32 {
        var hash: UInt32 = 1
        for value in data {
            let v = UInt32(value)
            if v == 0 { continue }
            let next = hash &* v
            if next == 0 || next <= hash { break }
            hash = next
        }
        return hash
    }
}

// MARK: - Map Variant

private final class MapCrypto: QMC2CryptoProtocol {
    private let key: [UInt8]

    init(key: [UInt8]) {
        self.key = key
    }

    func decrypt(_ buffer: UnsafeMutablePointer<UInt8>, count: Int, offset: Int) {
        key.withUnsafeBufferPointer { keyPtr in
            let n = keyPtr.count
            let base = keyPtr.baseAddress!
            for i in 0..<count {
                var off = offset + i
                if off > 0x7FFF { off %= 0x7FFF }
                let index = (off &* off &+ 71214) % n
                let value = base[index]
                let rotation = (index + 4) & 0b111
                buffer[i] ^= (value << rotation) | (value >> rotation)
            }
        }
    }
}

// MARK: - Errors

enum QMCError: LocalizedError {
    case ekeyParseError
    case keyDeriveError
    case decryptionFailed

    var errorDescription: String? {
        switch self {
        case .ekeyParseError: return String(localized: "ekey 解析失败")
        case .keyDeriveError: return String(localized: "密钥派生失败")
        case .decryptionFailed: return String(localized: "解密失败")
        }
    }
}

// MARK: - QMC 边下边解密下载器

/// 旧实现是「整包下载 → 全量解密 → 落盘」两段串行：大文件（无损 mflac 动辄
/// 几十 MB）要先等下载完、再等一轮全量 RC4，出声延迟 = 下载 + 解密之和，
/// 峰值内存还要吃下密文与明文两份拷贝。
///
/// QMC2 的 RC4 / Map 密文都支持任意字节偏移的随机访问解密，因此这里改成
/// 流式管线：CDN 分块到达 → 按累计偏移就地解密 → 追加写入临时文件，
/// 下载结束的瞬间明文文件即就绪（解密耗时完全摊进网络等待里），
/// 峰值内存降到单个分块大小。成功后原子移动到目标路径，
/// 保证缓存目录里永远不会出现半截文件被误判为完整缓存。
final class QMCStreamDownloader: NSObject, URLSessionDataDelegate, @unchecked Sendable {

    enum DownloadError: LocalizedError {
        case badStatus(Int)
        case cancelled
        case fileSystem(String)

        var errorDescription: String? {
            switch self {
            case .badStatus(let code): return "QMC 下载失败 HTTP \(code)"
            case .cancelled: return "QMC 下载已取消"
            case .fileSystem(let message): return "QMC 写入失败: \(message)"
            }
        }
    }

    private let decryptor: QMCDecryptor
    private let destination: URL
    private let tempURL: URL

    private let lock = NSLock()
    private var handle: FileHandle?
    private var bytesWritten: Int = 0
    private var continuation: CheckedContinuation<Int, Error>?
    private var session: URLSession?
    private var finished = false

    init(decryptor: QMCDecryptor, destination: URL) {
        self.decryptor = decryptor
        self.destination = destination
        self.tempURL = destination
            .deletingLastPathComponent()
            .appendingPathComponent(".\(destination.lastPathComponent).\(UUID().uuidString.prefix(8)).part")
        super.init()
    }

    /// 下载并解密到目标文件，返回写入字节数。
    /// 支持 Task 取消：取消时立刻中断连接并清理临时文件。
    func download(
        from url: URL,
        priority: Float = URLSessionTask.defaultPriority
    ) async throws -> Int {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Int, Error>) in
                lock.lock()
                continuation = cont
                lock.unlock()
                start(url: url, priority: priority)
            }
        } onCancel: {
            cancel()
        }
    }

    private func start(url: URL, priority: Float) {
        FileManager.default.createFile(atPath: tempURL.path, contents: nil)
        guard let fileHandle = try? FileHandle(forWritingTo: tempURL) else {
            finish(.failure(DownloadError.fileSystem("无法创建临时文件")))
            return
        }

        lock.lock()
        handle = fileHandle
        lock.unlock()

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 15 * 60
        config.waitsForConnectivity = true
        // 解密在 delegate 串行队列上进行，不阻塞主线程
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.name = "qmc.stream.downloader"
        queue.qualityOfService = priority <= URLSessionTask.lowPriority ? .utility : .userInitiated

        let urlSession = URLSession(configuration: config, delegate: self, delegateQueue: queue)
        lock.lock()
        session = urlSession
        lock.unlock()

        let task = urlSession.dataTask(with: url)
        task.priority = min(URLSessionTask.highPriority, max(URLSessionTask.lowPriority, priority))
        task.resume()
    }

    private func cancel() {
        lock.lock()
        let urlSession = session
        lock.unlock()
        urlSession?.invalidateAndCancel()
        finish(.failure(DownloadError.cancelled))
    }

    private func finish(_ result: Result<Int, Error>) {
        lock.lock()
        guard !finished else {
            lock.unlock()
            return
        }
        finished = true
        let cont = continuation
        continuation = nil
        let fileHandle = handle
        handle = nil
        let urlSession = session
        session = nil
        lock.unlock()

        try? fileHandle?.close()
        urlSession?.finishTasksAndInvalidate()

        switch result {
        case .success(let count):
            do {
                if FileManager.default.fileExists(atPath: destination.path) {
                    try? FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.moveItem(at: tempURL, to: destination)
                cont?.resume(returning: count)
            } catch {
                try? FileManager.default.removeItem(at: tempURL)
                cont?.resume(throwing: DownloadError.fileSystem(error.localizedDescription))
            }
        case .failure(let error):
            try? FileManager.default.removeItem(at: tempURL)
            cont?.resume(throwing: error)
        }
    }

    // MARK: - URLSessionDataDelegate

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            completionHandler(.cancel)
            finish(.failure(DownloadError.badStatus(http.statusCode)))
            return
        }
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        lock.lock()
        guard !finished, let fileHandle = handle else {
            lock.unlock()
            return
        }
        let offset = bytesWritten
        bytesWritten += data.count
        lock.unlock()

        var chunk = data
        decryptor.decrypt(&chunk, offset: offset)
        fileHandle.write(chunk)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            finish(.failure(error))
        } else {
            lock.lock()
            let count = bytesWritten
            lock.unlock()
            finish(.success(count))
        }
    }
}
