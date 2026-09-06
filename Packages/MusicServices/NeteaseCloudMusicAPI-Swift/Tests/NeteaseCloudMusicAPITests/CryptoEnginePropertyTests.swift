// CryptoEnginePropertyTests.swift
// 加密引擎属性测试
// 使用 SwiftCheck 验证加密引擎的通用正确性属性

import XCTest
import SwiftCheck
@testable import NeteaseCloudMusicAPI

final class CryptoEnginePropertyTests: XCTestCase {

    // MARK: - 辅助方法

    /// 将大写十六进制字符串转换为 Data
    /// - Parameter hex: 十六进制字符串（大写或小写均可）
    /// - Returns: 转换后的 Data，如果 hex 无效则返回 nil
    private func hexToData(_ hex: String) -> Data? {
        let cleanHex = hex.lowercased()
        guard cleanHex.count % 2 == 0 else { return nil }

        var data = Data()
        var index = cleanHex.startIndex
        while index < cleanHex.endIndex {
            let nextIndex = cleanHex.index(index, offsetBy: 2)
            let byteString = String(cleanHex[index..<nextIndex])
            guard let byte = UInt8(byteString, radix: 16) else { return nil }
            data.append(byte)
            index = nextIndex
        }
        return data
    }

    /// 减少属性测试迭代次数以加快测试速度
    private let quickArgs = CheckerArguments(maxAllowableSuccessfulTests: 5)

    // MARK: - Property 1: EAPI 加密解密 Round-Trip

    /// 属性测试 1：EAPI 加密解密 Round-Trip
    /// 对于任意有效的 JSON 字典，使用 eapi 模式加密后再解密，应该产生与原始输入等价的 JSON 对象。
    /// 验证流程：eapiEncrypt → hex 转 Data → AES-ECB 解密 → 分隔符拆分 → 验证 text 部分与原始 JSON 等价
    // **Validates: Requirements 1.6, 1.8, 1.9**
    func testProperty1_EAPIRoundTrip() {
        property("EAPI 加密解密 round-trip 保持数据不变", arguments: quickArgs) <- forAll { (key: String, value: String) in
            // 过滤掉空键（JSON 键不能为空字符串在某些场景下可能有问题）
            // 以及过滤掉包含特殊字符可能导致 JSON 序列化不确定性的情况
            let safeKey = key.isEmpty ? "k" : String(key.prefix(50))
            let safeValue = String(value.prefix(100))

            // 构造 JSON 字典
            let originalObject: [String: Any] = [safeKey: safeValue]
            let url = "/api/test/property"

            do {
                // 1. 使用 eapiEncrypt 加密
                let encrypted = try CryptoEngine.eapiEncrypt(url: url, object: originalObject)

                // 2. 将加密后的 hex 字符串转换为 Data
                guard let encryptedData = self.hexToData(encrypted.params) else {
                    return false
                }

                // 3. 使用 eapiKey 进行 AES-ECB 解密
                let eapiKeyData = Data(NCMConstants.eapiKey.utf8)
                let decryptedData = try CryptoEngine.aesECBDecrypt(data: encryptedData, key: eapiKeyData)

                // 4. 解密后的内容格式为：{url}-36cd479b6b5-{text}-36cd479b6b5-{digest}
                guard let decryptedString = String(data: decryptedData, encoding: .utf8) else {
                    return false
                }

                // 5. 用分隔符拆分
                let parts = decryptedString.components(separatedBy: "-36cd479b6b5-")
                guard parts.count == 3 else {
                    return false
                }

                // 6. 验证第一部分是原始 URL
                guard parts[0] == url else {
                    return false
                }

                // 7. 验证第二部分（text）可以解析为 JSON，且与原始对象等价
                let textData = Data(parts[1].utf8)
                guard let parsedObject = try JSONSerialization.jsonObject(with: textData, options: []) as? [String: Any] else {
                    return false
                }

                // 验证解析后的 JSON 与原始对象等价
                guard let parsedValue = parsedObject[safeKey] as? String else {
                    return false
                }
                guard parsedValue == safeValue else {
                    return false
                }

                // 8. 验证第三部分（digest）是 32 位 MD5 哈希
                guard parts[2].count == 32 else {
                    return false
                }

                // 9. 验证 digest 的正确性：重新计算 MD5 并比较
                let expectedMessage = "nobody\(url)use\(parts[1])md5forencrypt"
                let expectedDigest = CryptoEngine.md5(expectedMessage)
                guard parts[2] == expectedDigest else {
                    return false
                }

                return true
            } catch {
                // 加密或解密过程中出错
                return false
            }
        }
    }

    // MARK: - Property 2: LinuxAPI 加密解密 Round-Trip

    /// 属性测试 2：LinuxAPI 加密解密 Round-Trip
    /// 对于任意有效的 JSON 字典，使用 linuxapi 模式加密后，用 linuxapi 密钥解密，
    /// 应该产生包含原始 params 的等价 JSON 对象。
    // **Validates: Requirements 1.7, 1.10**
    func testProperty2_LinuxAPIRoundTrip() {
        property("LinuxAPI 加密解密 round-trip 保持数据不变", arguments: quickArgs) <- forAll { (paramKey: String, paramValue: String) in
            // 构造安全的键值对
            let safeKey = paramKey.isEmpty ? "k" : String(paramKey.prefix(50))
            let safeValue = String(paramValue.prefix(100))

            // 构造包含 method、url、params 的 JSON 对象
            let params: [String: Any] = [safeKey: safeValue]
            let originalObject: [String: Any] = [
                "method": "POST",
                "url": "https://music.163.com/api/test",
                "params": params
            ]

            do {
                // 1. 使用 linuxapiEncrypt 加密
                let encrypted = try CryptoEngine.linuxapiEncrypt(originalObject)

                // 2. 将 hex eparams 转换为 Data
                guard let encryptedData = self.hexToData(encrypted.eparams) else {
                    return false
                }

                // 3. 使用 linuxapiKey 进行 AES-ECB 解密
                let linuxapiKeyData = Data(NCMConstants.linuxapiKey.utf8)
                let decryptedData = try CryptoEngine.aesECBDecrypt(data: encryptedData, key: linuxapiKeyData)

                // 4. 解析解密后的 JSON
                guard let decryptedObject = try JSONSerialization.jsonObject(with: decryptedData, options: []) as? [String: Any] else {
                    return false
                }

                // 5. 验证 method 字段
                guard let method = decryptedObject["method"] as? String, method == "POST" else {
                    return false
                }

                // 6. 验证 url 字段
                guard let urlStr = decryptedObject["url"] as? String,
                      urlStr == "https://music.163.com/api/test" else {
                    return false
                }

                // 7. 验证 params 字段包含原始参数
                guard let decryptedParams = decryptedObject["params"] as? [String: Any] else {
                    return false
                }
                guard let decryptedValue = decryptedParams[safeKey] as? String else {
                    return false
                }
                guard decryptedValue == safeValue else {
                    return false
                }

                return true
            } catch {
                // 加密或解密过程中出错
                return false
            }
        }
    }

    // MARK: - Property 3: WeAPI 加密输出结构有效性

    /// 属性测试 3：WeAPI 加密输出结构有效性
    /// 对于任意有效的 JSON 字典，使用 weapi 模式加密后，输出应该包含：
    /// - 非空的 params（base64 编码字符串）
    /// - 非空的 encSecKey（hex 编码字符串）
    /// - encSecKey 长度应为 256 个 hex 字符（128 字节 RSA 输出）
    // **Validates: Requirements 1.5**
    func testProperty3_WeAPIOutputStructureValidity() {
        property("WeAPI 加密输出结构有效：非空 params(base64)、非空 encSecKey(256 hex 字符)", arguments: quickArgs) <- forAll { (key: String, value: String) in
            // 构造安全的键值对
            let safeKey = key.isEmpty ? "k" : String(key.prefix(50))
            let safeValue = String(value.prefix(100))

            let jsonObject: [String: Any] = [safeKey: safeValue]

            do {
                // 1. 使用 weapiEncrypt 加密
                let result = try CryptoEngine.weapiEncrypt(jsonObject)

                // 2. 验证 params 非空
                guard !result.params.isEmpty else {
                    return false
                }

                // 3. 验证 params 是有效的 base64 编码字符串
                guard let decodedData = Data(base64Encoded: result.params),
                      !decodedData.isEmpty else {
                    return false
                }

                // 4. 验证 encSecKey 非空
                guard !result.encSecKey.isEmpty else {
                    return false
                }

                // 5. 验证 encSecKey 长度为 256 个 hex 字符（128 字节 RSA 输出 × 2）
                guard result.encSecKey.count == 256 else {
                    return false
                }

                // 6. 验证 encSecKey 只包含有效的十六进制字符
                let hexCharSet = CharacterSet(charactersIn: "0123456789abcdef")
                guard result.encSecKey.unicodeScalars.allSatisfy({ hexCharSet.contains($0) }) else {
                    return false
                }

                return true
            } catch {
                // 加密过程中出错
                return false
            }
        }
    }
}
