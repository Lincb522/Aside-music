// CryptoEngine.swift
// 加密引擎模块
// 实现 WeAPI、LinuxAPI、EAPI 和明文四种加密模式的底层加密原语

import Foundation
import CommonCrypto
import Security

/// WeAPI 加密结果
struct WeAPIEncryptedParams {
    /// 双重 AES-CBC 加密后的 base64 编码字符串
    let params: String
    /// RSA 加密的反转密钥，hex 编码字符串
    let encSecKey: String
}

/// EAPI 加密结果
struct EAPIEncryptedParams {
    /// AES-ECB 加密后的大写十六进制字符串
    let params: String
}

/// LinuxAPI 加密结果
struct LinuxAPIEncryptedParams {
    /// AES-ECB 加密后的大写十六进制字符串
    let eparams: String
}

/// 加密引擎（无状态枚举）
/// 提供 AES-CBC、AES-ECB 加密/解密和 MD5 哈希等底层加密原语
enum CryptoEngine {

    // MARK: - 加密错误类型

    /// 加密操作错误
    enum CryptoError: Error, LocalizedError {
        /// 加密失败
        case encryptionFailed(detail: String)
        /// 解密失败
        case decryptionFailed(detail: String)

        var errorDescription: String? {
            switch self {
            case .encryptionFailed(let detail):
                return "加密失败: \(detail)"
            case .decryptionFailed(let detail):
                return "解密失败: \(detail)"
            }
        }
    }

    // MARK: - WeAPI 加密

    /// 使用 WeAPI 模式加密 JSON 对象
    /// 流程：JSON 序列化 → 双重 AES-CBC 加密 → RSA 加密反转密钥
    /// - Parameter jsonObject: 待加密的 JSON 字典
    /// - Returns: 包含 params 和 encSecKey 的加密结果
    /// - Throws: `CryptoError.encryptionFailed` 如果加密操作失败
    static func weapiEncrypt(_ jsonObject: [String: Any]) throws -> WeAPIEncryptedParams {
        // 1. 将 JSON 对象序列化为字符串
        let jsonData = try JSONSerialization.data(withJSONObject: jsonObject, options: [])
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw CryptoError.encryptionFailed(detail: "WeAPI JSON 序列化为字符串失败")
        }

        // 2. 从 base62 字符集生成 16 字符随机密钥
        let base62Chars = Array(NCMConstants.base62)
        var secretKey = ""
        for _ in 0..<16 {
            let randomIndex = Int.random(in: 0..<base62Chars.count)
            secretKey.append(base62Chars[randomIndex])
        }

        let presetKeyData = Data(NCMConstants.presetKey.utf8)
        let ivData = Data(NCMConstants.iv.utf8)
        let secretKeyData = Data(secretKey.utf8)

        // 3. 第一次 AES-CBC 加密：使用 presetKey 加密 JSON 字符串，然后 base64 编码
        let firstEncrypted = try aesCBCEncrypt(data: Data(jsonString.utf8), key: presetKeyData, iv: ivData)
        let firstBase64 = firstEncrypted.base64EncodedString()

        // 4. 第二次 AES-CBC 加密：使用随机密钥加密第一次的 base64 结果，然后 base64 编码
        let secondEncrypted = try aesCBCEncrypt(data: Data(firstBase64.utf8), key: secretKeyData, iv: ivData)
        let params = secondEncrypted.base64EncodedString()

        // 5. 反转随机密钥字符串
        let reversedSecretKey = String(secretKey.reversed())

        // 6. RSA 加密反转的密钥，输出为 hex 编码字符串
        let rsaEncrypted = try rsaEncrypt(data: Data(reversedSecretKey.utf8), publicKeyPEM: NCMConstants.publicKeyPEM)
        let encSecKey = rsaEncrypted.map { String(format: "%02x", $0) }.joined()

        return WeAPIEncryptedParams(params: params, encSecKey: encSecKey)
    }

    // MARK: - LinuxAPI 加密

    /// 使用 LinuxAPI 模式加密 JSON 对象
    /// 输入的 jsonObject 应包含 method、url 和 params 字段
    /// 流程：JSON 序列化 → AES-ECB 加密（linuxapiKey）→ 大写 hex
    /// - Parameter jsonObject: 包含 method、url、params 字段的 JSON 字典
    /// - Returns: 包含大写 hex 编码 eparams 的加密结果
    /// - Throws: `CryptoError.encryptionFailed` 如果加密操作失败
    static func linuxapiEncrypt(_ jsonObject: [String: Any]) throws -> LinuxAPIEncryptedParams {
        // 1. 将 JSON 对象序列化为字符串
        let jsonData = try JSONSerialization.data(withJSONObject: jsonObject, options: [])
        guard String(data: jsonData, encoding: .utf8) != nil else {
            throw CryptoError.encryptionFailed(detail: "LinuxAPI JSON 序列化为字符串失败")
        }

        // 2. 使用 linuxapiKey 进行 AES-ECB 加密
        let linuxapiKeyData = Data(NCMConstants.linuxapiKey.utf8)
        let encrypted = try aesECBEncrypt(data: jsonData, key: linuxapiKeyData)

        // 3. 转换为大写十六进制字符串
        let hexString = encrypted.map { String(format: "%02X", $0) }.joined()

        return LinuxAPIEncryptedParams(eparams: hexString)
    }

    // MARK: - EAPI 加密

    /// 使用 EAPI 模式加密数据
    /// 流程：JSON 序列化 → 计算 MD5 摘要 → 拼接分隔符 → AES-ECB 加密 → 大写 hex
    /// - Parameters:
    ///   - url: API 路径（如 `/api/song/detail`）
    ///   - object: 待加密的 JSON 字典
    /// - Returns: 包含大写 hex 编码 params 的加密结果
    /// - Throws: `CryptoError.encryptionFailed` 如果加密操作失败
    static func eapiEncrypt(url: String, object: [String: Any]) throws -> EAPIEncryptedParams {
        // 1. 将 JSON 对象序列化为字符串
        let jsonData = try JSONSerialization.data(withJSONObject: object, options: [])
        guard let text = String(data: jsonData, encoding: .utf8) else {
            throw CryptoError.encryptionFailed(detail: "EAPI JSON 序列化为字符串失败")
        }

        // 2. 计算 MD5 摘要：message = "nobody{url}use{text}md5forencrypt"
        let message = "nobody\(url)use\(text)md5forencrypt"
        let digest = md5(message)

        // 3. 用分隔符 `-36cd479b6b5-` 拼接："{url}-36cd479b6b5-{text}-36cd479b6b5-{digest}"
        let combined = "\(url)-36cd479b6b5-\(text)-36cd479b6b5-\(digest)"

        // 4. 使用 eapiKey 进行 AES-ECB 加密
        let eapiKeyData = Data(NCMConstants.eapiKey.utf8)
        let encrypted = try aesECBEncrypt(data: Data(combined.utf8), key: eapiKeyData)

        // 5. 转换为大写十六进制字符串
        let hexString = encrypted.map { String(format: "%02X", $0) }.joined()

        return EAPIEncryptedParams(params: hexString)
    }

    // MARK: - EAPI 解密

    /// 解密 EAPI 响应数据
    /// 流程：hex 字符串 → Data → AES-ECB 解密 → JSON 解析
    /// - Parameter hexString: 十六进制编码的加密响应体
    /// - Returns: 解析后的 JSON 字典
    /// - Throws: `CryptoError.decryptionFailed` 如果解密或 JSON 解析失败
    static func eapiDecrypt(hexString: String) throws -> [String: Any] {
        // 1. 将十六进制字符串转换为 Data
        let cleanHex = hexString.lowercased()
        guard cleanHex.count % 2 == 0 else {
            throw CryptoError.decryptionFailed(detail: "EAPI 解密失败：hex 字符串长度不是偶数")
        }

        var hexData = Data()
        var index = cleanHex.startIndex
        while index < cleanHex.endIndex {
            let nextIndex = cleanHex.index(index, offsetBy: 2)
            let byteString = String(cleanHex[index..<nextIndex])
            guard let byte = UInt8(byteString, radix: 16) else {
                throw CryptoError.decryptionFailed(detail: "EAPI 解密失败：无效的 hex 字符 '\(byteString)'")
            }
            hexData.append(byte)
            index = nextIndex
        }

        // 2. 使用 eapiKey 进行 AES-ECB 解密
        let eapiKeyData = Data(NCMConstants.eapiKey.utf8)
        let decryptedData = try aesECBDecrypt(data: hexData, key: eapiKeyData)

        // 3. 将解密后的数据解析为 JSON
        guard let jsonObject = try JSONSerialization.jsonObject(with: decryptedData, options: []) as? [String: Any] else {
            throw CryptoError.decryptionFailed(detail: "EAPI 解密失败：解密后的数据无法解析为 JSON 字典")
        }

        return jsonObject
    }

    // MARK: - AES-CBC 加密

    /// 使用 AES-CBC 模式加密数据
    /// - Parameters:
    ///   - data: 待加密的原始数据
    ///   - key: AES 密钥（16/24/32 字节）
    ///   - iv: 初始化向量（16 字节）
    /// - Returns: 加密后的数据（包含 PKCS7 填充）
    /// - Throws: `CryptoError.encryptionFailed` 如果加密操作失败
    static func aesCBCEncrypt(data: Data, key: Data, iv: Data) throws -> Data {
        // 计算输出缓冲区大小：原始数据长度 + 一个块大小（用于 PKCS7 填充）
        let bufferSize = data.count + kCCBlockSizeAES128
        var buffer = Data(count: bufferSize)
        var numBytesEncrypted: size_t = 0

        // 使用 PKCS7 填充的 AES-CBC 加密
        // CBC 模式不设置 kCCOptionECBMode 标志
        let status = buffer.withUnsafeMutableBytes { bufferPtr in
            data.withUnsafeBytes { dataPtr in
                key.withUnsafeBytes { keyPtr in
                    iv.withUnsafeBytes { ivPtr in
                        CCCrypt(
                            CCOperation(kCCEncrypt),           // 加密操作
                            CCAlgorithm(kCCAlgorithmAES128),   // AES-128 算法
                            CCOptions(kCCOptionPKCS7Padding),  // PKCS7 填充，无 ECB 标志 = CBC 模式
                            keyPtr.baseAddress,                // 密钥
                            key.count,                         // 密钥长度
                            ivPtr.baseAddress,                 // 初始化向量
                            dataPtr.baseAddress,               // 输入数据
                            data.count,                        // 输入数据长度
                            bufferPtr.baseAddress,             // 输出缓冲区
                            bufferSize,                        // 输出缓冲区大小
                            &numBytesEncrypted                 // 实际加密字节数
                        )
                    }
                }
            }
        }

        // 检查加密操作是否成功
        guard status == kCCSuccess else {
            throw CryptoError.encryptionFailed(detail: "AES-CBC 加密失败，CCCrypt 返回状态码: \(status)")
        }

        // 截取实际加密数据
        return buffer.prefix(numBytesEncrypted)
    }

    // MARK: - AES-ECB 加密

    /// 使用 AES-ECB 模式加密数据
    /// - Parameters:
    ///   - data: 待加密的原始数据
    ///   - key: AES 密钥（16/24/32 字节）
    /// - Returns: 加密后的数据（包含 PKCS7 填充）
    /// - Throws: `CryptoError.encryptionFailed` 如果加密操作失败
    static func aesECBEncrypt(data: Data, key: Data) throws -> Data {
        // 计算输出缓冲区大小
        let bufferSize = data.count + kCCBlockSizeAES128
        var buffer = Data(count: bufferSize)
        var numBytesEncrypted: size_t = 0

        // 使用 PKCS7 填充 + ECB 模式的 AES 加密
        // ECB 模式设置 kCCOptionECBMode 标志，不使用 IV
        let status = buffer.withUnsafeMutableBytes { bufferPtr in
            data.withUnsafeBytes { dataPtr in
                key.withUnsafeBytes { keyPtr in
                    CCCrypt(
                        CCOperation(kCCEncrypt),                                          // 加密操作
                        CCAlgorithm(kCCAlgorithmAES128),                                  // AES-128 算法
                        CCOptions(kCCOptionPKCS7Padding | kCCOptionECBMode),               // PKCS7 填充 + ECB 模式
                        keyPtr.baseAddress,                                               // 密钥
                        key.count,                                                        // 密钥长度
                        nil,                                                              // ECB 模式不使用 IV
                        dataPtr.baseAddress,                                              // 输入数据
                        data.count,                                                       // 输入数据长度
                        bufferPtr.baseAddress,                                            // 输出缓冲区
                        bufferSize,                                                       // 输出缓冲区大小
                        &numBytesEncrypted                                                // 实际加密字节数
                    )
                }
            }
        }

        // 检查加密操作是否成功
        guard status == kCCSuccess else {
            throw CryptoError.encryptionFailed(detail: "AES-ECB 加密失败，CCCrypt 返回状态码: \(status)")
        }

        // 截取实际加密数据
        return buffer.prefix(numBytesEncrypted)
    }

    // MARK: - AES-ECB 解密

    /// 使用 AES-ECB 模式解密数据
    /// - Parameters:
    ///   - data: 待解密的加密数据
    ///   - key: AES 密钥（16/24/32 字节）
    /// - Returns: 解密后的原始数据（自动移除 PKCS7 填充）
    /// - Throws: `CryptoError.decryptionFailed` 如果解密操作失败
    static func aesECBDecrypt(data: Data, key: Data) throws -> Data {
        // 计算输出缓冲区大小（解密后数据不会超过输入大小 + 一个块）
        let bufferSize = data.count + kCCBlockSizeAES128
        var buffer = Data(count: bufferSize)
        var numBytesDecrypted: size_t = 0

        // 使用 PKCS7 填充 + ECB 模式的 AES 解密
        let status = buffer.withUnsafeMutableBytes { bufferPtr in
            data.withUnsafeBytes { dataPtr in
                key.withUnsafeBytes { keyPtr in
                    CCCrypt(
                        CCOperation(kCCDecrypt),                                          // 解密操作
                        CCAlgorithm(kCCAlgorithmAES128),                                  // AES-128 算法
                        CCOptions(kCCOptionPKCS7Padding | kCCOptionECBMode),               // PKCS7 填充 + ECB 模式
                        keyPtr.baseAddress,                                               // 密钥
                        key.count,                                                        // 密钥长度
                        nil,                                                              // ECB 模式不使用 IV
                        dataPtr.baseAddress,                                              // 输入数据
                        data.count,                                                       // 输入数据长度
                        bufferPtr.baseAddress,                                            // 输出缓冲区
                        bufferSize,                                                       // 输出缓冲区大小
                        &numBytesDecrypted                                                // 实际解密字节数
                    )
                }
            }
        }

        // 检查解密操作是否成功
        guard status == kCCSuccess else {
            throw CryptoError.decryptionFailed(detail: "AES-ECB 解密失败，CCCrypt 返回状态码: \(status)")
        }

        // 截取实际解密数据
        return buffer.prefix(numBytesDecrypted)
    }

    // MARK: - MD5 哈希

    /// 计算字符串的 MD5 哈希值
    /// - Parameter string: 待哈希的字符串
    /// - Returns: 32 位小写十六进制 MD5 哈希字符串
    static func md5(_ string: String) -> String {
        let data = Data(string.utf8)
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))

        // 使用 CommonCrypto 的 CC_MD5 计算哈希
        data.withUnsafeBytes { dataPtr in
            _ = CC_MD5(dataPtr.baseAddress, CC_LONG(data.count), &digest)
        }

        // 将字节数组转换为小写十六进制字符串
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - RSA 加密

    /// 使用 RSA 公钥加密数据（无填充模式）
    /// 通过纯 Swift 大数运算实现，匹配 Node.js 的 RSA_NO_PADDING 行为
    /// - Parameters:
    ///   - data: 待加密的原始数据
    ///   - publicKeyPEM: PEM 格式的 RSA 公钥字符串
    /// - Returns: RSA 加密后的数据（128 字节，对应 1024 位密钥）
    /// - Throws: `CryptoError.encryptionFailed` 如果公钥解析或加密操作失败
    static func rsaEncrypt(data: Data, publicKeyPEM: String) throws -> Data {
        // 1. 解析 PEM 公钥：去除头尾标记和换行符，提取 base64 编码的 DER 数据
        let pemContent = publicKeyPEM
            .replacingOccurrences(of: "-----BEGIN PUBLIC KEY-----", with: "")
            .replacingOccurrences(of: "-----END PUBLIC KEY-----", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .trimmingCharacters(in: .whitespaces)

        // 2. Base64 解码得到 DER 格式的公钥数据
        guard let derData = Data(base64Encoded: pemContent) else {
            throw CryptoError.encryptionFailed(detail: "RSA 公钥 base64 解码失败")
        }

        // 3. 从 DER 数据中解析 RSA 公钥的 modulus(n) 和 exponent(e)
        let (modulus, exponent) = try parseRSAPublicKeyDER(derData)

        // 4. 对输入数据进行左侧零填充，使其长度等于模数字节长度（128 字节）
        let modulusLength = (modulus.bitWidth + 7) / 8
        var paddedBytes = [UInt8](data)
        if paddedBytes.count < modulusLength {
            paddedBytes = [UInt8](repeating: 0, count: modulusLength - paddedBytes.count) + paddedBytes
        }

        // 5. 将填充后的数据转换为大整数，执行模幂运算: c = m^e mod n
        let message = BigUInt(paddedBytes)
        let cipher = modPow(base: message, exponent: exponent, modulus: modulus)

        // 6. 将结果转换为固定长度的字节数组（128 字节）
        var resultBytes = cipher.toBytes()
        if resultBytes.count < modulusLength {
            resultBytes = [UInt8](repeating: 0, count: modulusLength - resultBytes.count) + resultBytes
        }

        return Data(resultBytes)
    }

    // MARK: - DER 公钥解析

    /// 从 DER 编码的 PKCS#1/PKCS#8 公钥数据中提取 modulus 和 exponent
    private static func parseRSAPublicKeyDER(_ derData: Data) throws -> (modulus: BigUInt, exponent: BigUInt) {
        let bytes = [UInt8](derData)
        var index = 0

        // 解析外层 SEQUENCE
        guard index < bytes.count, bytes[index] == 0x30 else {
            throw CryptoError.encryptionFailed(detail: "DER 解析失败：缺少外层 SEQUENCE 标签")
        }
        index += 1
        _ = try parseDERLength(bytes: bytes, index: &index)

        // 检查是否为 PKCS#8 格式（包含 AlgorithmIdentifier SEQUENCE）
        if index < bytes.count && bytes[index] == 0x30 {
            // 跳过 AlgorithmIdentifier SEQUENCE
            index += 1
            let algLen = try parseDERLength(bytes: bytes, index: &index)
            index += algLen

            // 解析 BIT STRING（包含实际的 PKCS#1 公钥）
            guard index < bytes.count, bytes[index] == 0x03 else {
                throw CryptoError.encryptionFailed(detail: "DER 解析失败：缺少 BIT STRING 标签")
            }
            index += 1
            _ = try parseDERLength(bytes: bytes, index: &index)
            // 跳过 BIT STRING 的未使用位数字节
            guard index < bytes.count else {
                throw CryptoError.encryptionFailed(detail: "DER 解析失败：BIT STRING 数据不完整")
            }
            index += 1

            // 解析内层 SEQUENCE（PKCS#1 公钥）
            guard index < bytes.count, bytes[index] == 0x30 else {
                throw CryptoError.encryptionFailed(detail: "DER 解析失败：缺少内层 SEQUENCE 标签")
            }
            index += 1
            _ = try parseDERLength(bytes: bytes, index: &index)
        }

        // 解析 modulus (INTEGER)
        guard index < bytes.count, bytes[index] == 0x02 else {
            throw CryptoError.encryptionFailed(detail: "DER 解析失败：缺少 modulus INTEGER 标签")
        }
        index += 1
        let modLen = try parseDERLength(bytes: bytes, index: &index)
        var modBytes = Array(bytes[index..<(index + modLen)])
        index += modLen
        // 去除前导零字节
        while modBytes.first == 0x00 && modBytes.count > 1 {
            modBytes.removeFirst()
        }

        // 解析 exponent (INTEGER)
        guard index < bytes.count, bytes[index] == 0x02 else {
            throw CryptoError.encryptionFailed(detail: "DER 解析失败：缺少 exponent INTEGER 标签")
        }
        index += 1
        let expLen = try parseDERLength(bytes: bytes, index: &index)
        var expBytes = Array(bytes[index..<(index + expLen)])
        // 去除前导零字节
        while expBytes.first == 0x00 && expBytes.count > 1 {
            expBytes.removeFirst()
        }

        return (BigUInt(modBytes), BigUInt(expBytes))
    }

    /// 解析 DER 长度字段
    private static func parseDERLength(bytes: [UInt8], index: inout Int) throws -> Int {
        guard index < bytes.count else {
            throw CryptoError.encryptionFailed(detail: "DER 长度解析失败：索引越界")
        }
        let first = bytes[index]
        index += 1

        if first < 0x80 {
            // 短格式：长度直接编码在一个字节中
            return Int(first)
        } else {
            // 长格式：第一个字节的低 7 位表示后续长度字节数
            let numBytes = Int(first & 0x7F)
            guard index + numBytes <= bytes.count else {
                throw CryptoError.encryptionFailed(detail: "DER 长度解析失败：数据不足")
            }
            var length = 0
            for _ in 0..<numBytes {
                length = (length << 8) | Int(bytes[index])
                index += 1
            }
            return length
        }
    }

    // MARK: - 大整数运算（用于 RSA 无填充加密）

    /// 简易大整数类型，用于 RSA 模幂运算
    /// 内部使用 UInt32 数组存储，低位在前（little-endian）
    struct BigUInt {
        var digits: [UInt32] // 低位在前

        /// 从字节数组初始化（大端序）
        init(_ bytes: [UInt8]) {
            // 将字节数组转换为 UInt32 数组（低位在前）
            var result: [UInt32] = []
            var i = bytes.count
            while i > 0 {
                var value: UInt32 = 0
                let start = max(0, i - 4)
                for j in start..<i {
                    value = (value << 8) | UInt32(bytes[j])
                }
                result.append(value)
                i = start
            }
            // 去除高位零
            while result.count > 1 && result.last == 0 {
                result.removeLast()
            }
            self.digits = result.isEmpty ? [0] : result
        }

        /// 从单个 UInt32 值初始化
        init(value: UInt32) {
            self.digits = [value]
        }

        /// 内部初始化
        private init(digits: [UInt32]) {
            var d = digits
            while d.count > 1 && d.last == 0 {
                d.removeLast()
            }
            self.digits = d.isEmpty ? [0] : d
        }

        /// 位宽
        var bitWidth: Int {
            guard let last = digits.last, last != 0 else { return 0 }
            return (digits.count - 1) * 32 + (32 - last.leadingZeroBitCount)
        }

        /// 检查是否为零
        var isZero: Bool {
            return digits.count == 1 && digits[0] == 0
        }

        /// 获取指定位的值
        func bit(at position: Int) -> Bool {
            let wordIndex = position / 32
            let bitIndex = position % 32
            guard wordIndex < digits.count else { return false }
            return (digits[wordIndex] >> bitIndex) & 1 == 1
        }

        /// 转换为字节数组（大端序）
        func toBytes() -> [UInt8] {
            if isZero { return [0] }
            var result: [UInt8] = []
            for i in stride(from: digits.count - 1, through: 0, by: -1) {
                let d = digits[i]
                result.append(UInt8((d >> 24) & 0xFF))
                result.append(UInt8((d >> 16) & 0xFF))
                result.append(UInt8((d >> 8) & 0xFF))
                result.append(UInt8(d & 0xFF))
            }
            // 去除前导零
            while result.count > 1 && result.first == 0 {
                result.removeFirst()
            }
            return result
        }

        /// 大整数乘法
        static func multiply(_ a: BigUInt, _ b: BigUInt) -> BigUInt {
            let n = a.digits.count
            let m = b.digits.count
            var result = [UInt32](repeating: 0, count: n + m)

            for i in 0..<n {
                var carry: UInt64 = 0
                for j in 0..<m {
                    let product = UInt64(a.digits[i]) * UInt64(b.digits[j]) + UInt64(result[i + j]) + carry
                    result[i + j] = UInt32(product & 0xFFFFFFFF)
                    carry = product >> 32
                }
                if carry > 0 {
                    result[i + m] += UInt32(carry)
                }
            }

            return BigUInt(digits: result)
        }

        /// 大整数取模
        static func mod(_ a: BigUInt, _ m: BigUInt) -> BigUInt {
            if a.compare(m) == .orderedAscending { return a }
            // 使用长除法取模
            return divMod(a, m).remainder
        }

        /// 比较两个大整数
        func compare(_ other: BigUInt) -> ComparisonResult {
            if digits.count != other.digits.count {
                return digits.count < other.digits.count ? .orderedAscending : .orderedDescending
            }
            for i in stride(from: digits.count - 1, through: 0, by: -1) {
                if digits[i] != other.digits[i] {
                    return digits[i] < other.digits[i] ? .orderedAscending : .orderedDescending
                }
            }
            return .orderedSame
        }

        /// 大整数除法和取模（返回商和余数）
        static func divMod(_ a: BigUInt, _ b: BigUInt) -> (quotient: BigUInt, remainder: BigUInt) {
            if b.isZero { fatalError("除以零") }
            if a.compare(b) == .orderedAscending {
                return (BigUInt(value: 0), a)
            }

            // 使用移位除法
            var remainder = a
            var quotientDigits = [UInt32](repeating: 0, count: a.digits.count)

            let shift = a.bitWidth - b.bitWidth
            var divisor = leftShift(b, by: shift)

            for i in stride(from: shift, through: 0, by: -1) {
                if remainder.compare(divisor) != .orderedAscending {
                    remainder = subtract(remainder, divisor)
                    let wordIndex = i / 32
                    let bitIndex = i % 32
                    if wordIndex < quotientDigits.count {
                        quotientDigits[wordIndex] |= (1 << bitIndex)
                    }
                }
                divisor = rightShift(divisor, by: 1)
            }

            return (BigUInt(digits: quotientDigits), remainder)
        }

        /// 左移
        static func leftShift(_ a: BigUInt, by shift: Int) -> BigUInt {
            if shift == 0 { return a }
            let wordShift = shift / 32
            let bitShift = shift % 32

            var result = [UInt32](repeating: 0, count: a.digits.count + wordShift + 1)
            if bitShift == 0 {
                for i in 0..<a.digits.count {
                    result[i + wordShift] = a.digits[i]
                }
            } else {
                var carry: UInt32 = 0
                for i in 0..<a.digits.count {
                    let shifted = (UInt64(a.digits[i]) << bitShift) | UInt64(carry)
                    result[i + wordShift] = UInt32(shifted & 0xFFFFFFFF)
                    carry = UInt32(shifted >> 32)
                }
                if carry > 0 {
                    result[a.digits.count + wordShift] = carry
                }
            }

            return BigUInt(digits: result)
        }

        /// 右移
        static func rightShift(_ a: BigUInt, by shift: Int) -> BigUInt {
            if shift == 0 { return a }
            let wordShift = shift / 32
            let bitShift = shift % 32

            if wordShift >= a.digits.count { return BigUInt(value: 0) }

            let newCount = a.digits.count - wordShift
            var result = [UInt32](repeating: 0, count: newCount)

            if bitShift == 0 {
                for i in 0..<newCount {
                    result[i] = a.digits[i + wordShift]
                }
            } else {
                for i in 0..<newCount {
                    result[i] = a.digits[i + wordShift] >> bitShift
                    if i + wordShift + 1 < a.digits.count {
                        result[i] |= a.digits[i + wordShift + 1] << (32 - bitShift)
                    }
                }
            }

            return BigUInt(digits: result)
        }

        /// 大整数减法（假设 a >= b）
        static func subtract(_ a: BigUInt, _ b: BigUInt) -> BigUInt {
            var result = [UInt32](repeating: 0, count: a.digits.count)
            var borrow: Int64 = 0

            for i in 0..<a.digits.count {
                let aVal = Int64(a.digits[i])
                let bVal = i < b.digits.count ? Int64(b.digits[i]) : 0
                let diff = aVal - bVal - borrow
                if diff < 0 {
                    result[i] = UInt32(diff + 0x100000000)
                    borrow = 1
                } else {
                    result[i] = UInt32(diff)
                    borrow = 0
                }
            }

            return BigUInt(digits: result)
        }
    }

    /// 模幂运算: base^exponent mod modulus
    /// 使用平方-乘法算法（从高位到低位）
    static func modPow(base: BigUInt, exponent: BigUInt, modulus: BigUInt) -> BigUInt {
        if modulus.isZero { fatalError("模数不能为零") }
        var result = BigUInt(value: 1)
        let base = BigUInt.mod(base, modulus)

        let expBitWidth = exponent.bitWidth
        for i in stride(from: expBitWidth - 1, through: 0, by: -1) {
            // 平方
            result = BigUInt.mod(BigUInt.multiply(result, result), modulus)
            // 如果当前位为 1，则乘以 base
            if exponent.bit(at: i) {
                result = BigUInt.mod(BigUInt.multiply(result, base), modulus)
            }
        }

        return result
    }
}
