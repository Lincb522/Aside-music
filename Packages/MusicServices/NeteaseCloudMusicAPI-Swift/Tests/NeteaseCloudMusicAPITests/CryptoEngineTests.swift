// CryptoEngineTests.swift
// 加密引擎单元测试
// 验证 AES-CBC、AES-ECB 加密/解密和 MD5 哈希的正确性

import XCTest
@testable import NeteaseCloudMusicAPI

final class CryptoEngineTests: XCTestCase {

    // MARK: - MD5 测试

    /// 验证空字符串的 MD5 哈希值
    func testMD5EmptyString() {
        let result = CryptoEngine.md5("")
        // 空字符串的 MD5 是已知常量
        XCTAssertEqual(result, "d41d8cd98f00b204e9800998ecf8427e")
    }

    /// 验证常见字符串的 MD5 哈希值
    func testMD5KnownStrings() {
        // "hello" 的 MD5
        XCTAssertEqual(CryptoEngine.md5("hello"), "5d41402abc4b2a76b9719d911017c592")
        // "abc" 的 MD5
        XCTAssertEqual(CryptoEngine.md5("abc"), "900150983cd24fb0d6963f7d28e17f72")
        // "123456" 的 MD5
        XCTAssertEqual(CryptoEngine.md5("123456"), "e10adc3949ba59abbe56e057f20f883e")
    }

    /// 验证 MD5 输出格式为 32 位小写十六进制
    func testMD5OutputFormat() {
        let result = CryptoEngine.md5("test")
        XCTAssertEqual(result.count, 32)
        // 验证所有字符都是小写十六进制字符
        let hexCharSet = CharacterSet(charactersIn: "0123456789abcdef")
        XCTAssertTrue(result.unicodeScalars.allSatisfy { hexCharSet.contains($0) })
    }

    // MARK: - AES-CBC 加密测试

    /// 验证使用预设密钥和 IV 的 AES-CBC 加密
    func testAESCBCEncryptWithPresetKey() throws {
        let plaintext = "hello world"
        let data = Data(plaintext.utf8)
        let key = Data(NCMConstants.presetKey.utf8)
        let iv = Data(NCMConstants.iv.utf8)

        let encrypted = try CryptoEngine.aesCBCEncrypt(data: data, key: key, iv: iv)

        // 加密结果不应为空
        XCTAssertFalse(encrypted.isEmpty)
        // 加密结果长度应为 AES 块大小（16 字节）的整数倍
        XCTAssertEqual(encrypted.count % 16, 0)
        // 加密结果不应等于原始数据
        XCTAssertNotEqual(encrypted, data)
    }

    /// 验证 AES-CBC 加密结果可以 base64 编码（WeAPI 需要）
    func testAESCBCEncryptBase64Output() throws {
        let plaintext = "{\"ids\":\"[347230]\"}"
        let data = Data(plaintext.utf8)
        let key = Data(NCMConstants.presetKey.utf8)
        let iv = Data(NCMConstants.iv.utf8)

        let encrypted = try CryptoEngine.aesCBCEncrypt(data: data, key: key, iv: iv)
        let base64 = encrypted.base64EncodedString()

        // base64 编码结果不应为空
        XCTAssertFalse(base64.isEmpty)
        // 验证 base64 可以解码回原始加密数据
        XCTAssertEqual(Data(base64Encoded: base64), encrypted)
    }

    /// 验证相同输入产生相同的 AES-CBC 加密结果（确定性）
    func testAESCBCEncryptDeterministic() throws {
        let data = Data("test data".utf8)
        let key = Data(NCMConstants.presetKey.utf8)
        let iv = Data(NCMConstants.iv.utf8)

        let encrypted1 = try CryptoEngine.aesCBCEncrypt(data: data, key: key, iv: iv)
        let encrypted2 = try CryptoEngine.aesCBCEncrypt(data: data, key: key, iv: iv)

        XCTAssertEqual(encrypted1, encrypted2)
    }

    // MARK: - AES-ECB 加密/解密测试

    /// 验证 AES-ECB 加密解密 round-trip（使用 EAPI 密钥）
    func testAESECBRoundTripWithEAPIKey() throws {
        let plaintext = "hello world"
        let data = Data(plaintext.utf8)
        let key = Data(NCMConstants.eapiKey.utf8)

        let encrypted = try CryptoEngine.aesECBEncrypt(data: data, key: key)
        let decrypted = try CryptoEngine.aesECBDecrypt(data: encrypted, key: key)

        XCTAssertEqual(decrypted, data)
        XCTAssertEqual(String(data: decrypted, encoding: .utf8), plaintext)
    }

    /// 验证 AES-ECB 加密解密 round-trip（使用 LinuxAPI 密钥）
    func testAESECBRoundTripWithLinuxAPIKey() throws {
        let plaintext = "{\"method\":\"POST\",\"url\":\"https://music.163.com/api/song/detail\"}"
        let data = Data(plaintext.utf8)
        let key = Data(NCMConstants.linuxapiKey.utf8)

        let encrypted = try CryptoEngine.aesECBEncrypt(data: data, key: key)
        let decrypted = try CryptoEngine.aesECBDecrypt(data: encrypted, key: key)

        XCTAssertEqual(decrypted, data)
        XCTAssertEqual(String(data: decrypted, encoding: .utf8), plaintext)
    }

    /// 验证 AES-ECB 加密结果格式
    func testAESECBEncryptOutputFormat() throws {
        let data = Data("test".utf8)
        let key = Data(NCMConstants.eapiKey.utf8)

        let encrypted = try CryptoEngine.aesECBEncrypt(data: data, key: key)

        // 加密结果不应为空
        XCTAssertFalse(encrypted.isEmpty)
        // 加密结果长度应为 AES 块大小（16 字节）的整数倍
        XCTAssertEqual(encrypted.count % 16, 0)
    }

    /// 验证 AES-ECB 加密结果可以转换为大写十六进制（EAPI/LinuxAPI 需要）
    func testAESECBEncryptHexOutput() throws {
        let data = Data("test data for hex".utf8)
        let key = Data(NCMConstants.eapiKey.utf8)

        let encrypted = try CryptoEngine.aesECBEncrypt(data: data, key: key)
        let hexString = encrypted.map { String(format: "%02X", $0) }.joined()

        // 十六进制字符串长度应为加密数据长度的 2 倍
        XCTAssertEqual(hexString.count, encrypted.count * 2)
        // 验证所有字符都是大写十六进制字符
        let hexCharSet = CharacterSet(charactersIn: "0123456789ABCDEF")
        XCTAssertTrue(hexString.unicodeScalars.allSatisfy { hexCharSet.contains($0) })
    }

    /// 验证相同输入产生相同的 AES-ECB 加密结果（确定性）
    func testAESECBEncryptDeterministic() throws {
        let data = Data("deterministic test".utf8)
        let key = Data(NCMConstants.eapiKey.utf8)

        let encrypted1 = try CryptoEngine.aesECBEncrypt(data: data, key: key)
        let encrypted2 = try CryptoEngine.aesECBEncrypt(data: data, key: key)

        XCTAssertEqual(encrypted1, encrypted2)
    }

    /// 验证空数据的 AES-ECB 加密解密 round-trip
    func testAESECBRoundTripEmptyData() throws {
        let data = Data()
        let key = Data(NCMConstants.eapiKey.utf8)

        let encrypted = try CryptoEngine.aesECBEncrypt(data: data, key: key)
        // 空数据加密后应该有 PKCS7 填充（一个完整块）
        XCTAssertEqual(encrypted.count, 16)

        let decrypted = try CryptoEngine.aesECBDecrypt(data: encrypted, key: key)
        XCTAssertEqual(decrypted, data)
    }

    /// 验证较长数据的 AES-ECB 加密解密 round-trip
    func testAESECBRoundTripLongData() throws {
        // 构造一个超过多个 AES 块大小的 JSON 字符串
        let plaintext = String(repeating: "abcdefghijklmnop", count: 10)
        let data = Data(plaintext.utf8)
        let key = Data(NCMConstants.linuxapiKey.utf8)

        let encrypted = try CryptoEngine.aesECBEncrypt(data: data, key: key)
        let decrypted = try CryptoEngine.aesECBDecrypt(data: encrypted, key: key)

        XCTAssertEqual(String(data: decrypted, encoding: .utf8), plaintext)
    }

    /// 验证使用错误密钥解密会失败或产生不同结果
    func testAESECBDecryptWithWrongKey() throws {
        let data = Data("secret message".utf8)
        let correctKey = Data(NCMConstants.eapiKey.utf8)
        let wrongKey = Data(NCMConstants.linuxapiKey.utf8)

        let encrypted = try CryptoEngine.aesECBEncrypt(data: data, key: correctKey)

        // 使用错误密钥解密，结果应该不等于原始数据
        // 注意：CCCrypt 可能不会报错，但解密结果会是乱码
        if let decrypted = try? CryptoEngine.aesECBDecrypt(data: encrypted, key: wrongKey) {
            XCTAssertNotEqual(decrypted, data)
        }
        // 如果抛出错误也是可接受的行为
    }

    // MARK: - WeAPI 加密测试

    /// 验证 WeAPI 加密返回非空的 params 和 encSecKey
    func testWeAPIEncryptReturnsNonEmptyResult() throws {
        let jsonObject: [String: Any] = ["id": 347230, "c": "[{\"id\":347230}]"]

        let result = try CryptoEngine.weapiEncrypt(jsonObject)

        // params 不应为空
        XCTAssertFalse(result.params.isEmpty, "params 不应为空")
        // encSecKey 不应为空
        XCTAssertFalse(result.encSecKey.isEmpty, "encSecKey 不应为空")
    }

    /// 验证 WeAPI 加密的 params 是有效的 base64 编码字符串
    func testWeAPIEncryptParamsIsValidBase64() throws {
        let jsonObject: [String: Any] = ["ids": "[347230]"]

        let result = try CryptoEngine.weapiEncrypt(jsonObject)

        // params 应该是有效的 base64 字符串，可以解码
        let decodedData = Data(base64Encoded: result.params)
        XCTAssertNotNil(decodedData, "params 应该是有效的 base64 编码字符串")
        XCTAssertFalse(decodedData!.isEmpty, "base64 解码后的数据不应为空")
    }

    /// 验证 WeAPI 加密的 encSecKey 是 256 个 hex 字符（128 字节 RSA 输出）
    func testWeAPIEncryptEncSecKeyLength() throws {
        let jsonObject: [String: Any] = ["test": "value"]

        let result = try CryptoEngine.weapiEncrypt(jsonObject)

        // encSecKey 应为 256 个 hex 字符（128 字节 RSA 输出 × 2）
        XCTAssertEqual(result.encSecKey.count, 256,
                       "encSecKey 应为 256 个 hex 字符，实际为 \(result.encSecKey.count)")
    }

    /// 验证 WeAPI 加密的 encSecKey 只包含小写十六进制字符
    func testWeAPIEncryptEncSecKeyIsHex() throws {
        let jsonObject: [String: Any] = ["name": "test"]

        let result = try CryptoEngine.weapiEncrypt(jsonObject)

        // 验证所有字符都是小写十六进制字符
        let hexCharSet = CharacterSet(charactersIn: "0123456789abcdef")
        XCTAssertTrue(result.encSecKey.unicodeScalars.allSatisfy { hexCharSet.contains($0) },
                      "encSecKey 应只包含小写十六进制字符")
    }

    /// 验证 WeAPI 加密对不同输入产生不同的 params（因为随机密钥不同）
    func testWeAPIEncryptProducesDifferentResults() throws {
        let jsonObject: [String: Any] = ["id": 12345]

        let result1 = try CryptoEngine.weapiEncrypt(jsonObject)
        let result2 = try CryptoEngine.weapiEncrypt(jsonObject)

        // 由于每次生成不同的随机密钥，params 和 encSecKey 应该不同
        // 注意：理论上有极小概率相同，但实际上几乎不可能
        XCTAssertNotEqual(result1.params, result2.params,
                          "两次加密应产生不同的 params（随机密钥不同）")
        XCTAssertNotEqual(result1.encSecKey, result2.encSecKey,
                          "两次加密应产生不同的 encSecKey（随机密钥不同）")
    }

    /// 验证 WeAPI 加密可以处理空 JSON 对象
    func testWeAPIEncryptEmptyObject() throws {
        let jsonObject: [String: Any] = [:]

        let result = try CryptoEngine.weapiEncrypt(jsonObject)

        // 即使是空对象，也应该产生有效的加密结果
        XCTAssertFalse(result.params.isEmpty)
        XCTAssertEqual(result.encSecKey.count, 256)
    }

    /// 验证 WeAPI 加密可以处理包含中文的 JSON 对象
    func testWeAPIEncryptWithChineseContent() throws {
        let jsonObject: [String: Any] = ["keywords": "周杰伦", "type": 1]

        let result = try CryptoEngine.weapiEncrypt(jsonObject)

        XCTAssertFalse(result.params.isEmpty)
        XCTAssertEqual(result.encSecKey.count, 256)
        // params 应该是有效的 base64
        XCTAssertNotNil(Data(base64Encoded: result.params))
    }

    /// 验证 WeAPI 加密可以处理较大的 JSON 对象
    func testWeAPIEncryptLargeObject() throws {
        // 构造一个包含多个字段的较大 JSON 对象
        var jsonObject: [String: Any] = [:]
        for i in 0..<50 {
            jsonObject["key_\(i)"] = "value_\(i)_" + String(repeating: "x", count: 100)
        }

        let result = try CryptoEngine.weapiEncrypt(jsonObject)

        XCTAssertFalse(result.params.isEmpty)
        XCTAssertEqual(result.encSecKey.count, 256)
        XCTAssertNotNil(Data(base64Encoded: result.params))
    }

    // MARK: - EAPI 加密测试

    /// 验证 EAPI 加密返回非空的大写 hex 输出
    func testEAPIEncryptProducesNonEmptyHexOutput() throws {
        let url = "/api/song/detail"
        let object: [String: Any] = ["id": 347230]

        let result = try CryptoEngine.eapiEncrypt(url: url, object: object)

        // params 不应为空
        XCTAssertFalse(result.params.isEmpty, "EAPI 加密结果 params 不应为空")
    }

    /// 验证 EAPI 加密输出是大写十六进制字符串
    func testEAPIEncryptOutputIsUppercaseHex() throws {
        let url = "/api/song/detail"
        let object: [String: Any] = ["id": 347230, "c": "[{\"id\":347230}]"]

        let result = try CryptoEngine.eapiEncrypt(url: url, object: object)

        // 验证所有字符都是大写十六进制字符
        let hexCharSet = CharacterSet(charactersIn: "0123456789ABCDEF")
        XCTAssertTrue(result.params.unicodeScalars.allSatisfy { hexCharSet.contains($0) },
                      "EAPI 加密输出应只包含大写十六进制字符")
        // hex 字符串长度应为偶数（每个字节 2 个 hex 字符）
        XCTAssertEqual(result.params.count % 2, 0, "hex 字符串长度应为偶数")
    }

    /// 验证 EAPI 加密-解密 round-trip 正确性
    func testEAPIEncryptDecryptRoundTrip() throws {
        let url = "/api/song/detail"
        let object: [String: Any] = ["id": 347230, "name": "test"]

        // 加密
        let encrypted = try CryptoEngine.eapiEncrypt(url: url, object: object)

        // 解密：EAPI 加密的内容是 "{url}-36cd479b6b5-{text}-36cd479b6b5-{digest}"
        // 解密后不是直接得到原始 JSON，而是拼接后的字符串
        // 所以我们需要手动验证 round-trip：加密后的 hex 可以被 AES-ECB 解密
        let cleanHex = encrypted.params.lowercased()
        var hexData = Data()
        var index = cleanHex.startIndex
        while index < cleanHex.endIndex {
            let nextIndex = cleanHex.index(index, offsetBy: 2)
            let byteString = String(cleanHex[index..<nextIndex])
            guard let byte = UInt8(byteString, radix: 16) else {
                XCTFail("无效的 hex 字符")
                return
            }
            hexData.append(byte)
            index = nextIndex
        }

        let eapiKeyData = Data(NCMConstants.eapiKey.utf8)
        let decryptedData = try CryptoEngine.aesECBDecrypt(data: hexData, key: eapiKeyData)
        let decryptedString = String(data: decryptedData, encoding: .utf8)
        XCTAssertNotNil(decryptedString, "解密后的数据应为有效的 UTF-8 字符串")

        // 验证解密后的字符串包含 URL 和分隔符
        XCTAssertTrue(decryptedString!.contains(url), "解密后的字符串应包含原始 URL")
        XCTAssertTrue(decryptedString!.contains("-36cd479b6b5-"), "解密后的字符串应包含分隔符")

        // 验证解密后的字符串格式：{url}-36cd479b6b5-{text}-36cd479b6b5-{digest}
        let parts = decryptedString!.components(separatedBy: "-36cd479b6b5-")
        XCTAssertEqual(parts.count, 3, "解密后的字符串应由分隔符分为 3 部分")
        XCTAssertEqual(parts[0], url, "第一部分应为原始 URL")

        // 验证第二部分（text）可以解析为 JSON，且包含原始数据
        let textData = Data(parts[1].utf8)
        let parsedObject = try JSONSerialization.jsonObject(with: textData, options: []) as? [String: Any]
        XCTAssertNotNil(parsedObject, "text 部分应为有效的 JSON")
        XCTAssertEqual(parsedObject?["id"] as? Int, 347230, "解析后的 JSON 应包含原始 id")
        XCTAssertEqual(parsedObject?["name"] as? String, "test", "解析后的 JSON 应包含原始 name")

        // 验证第三部分（digest）是 32 位 MD5 哈希
        XCTAssertEqual(parts[2].count, 32, "digest 部分应为 32 位 MD5 哈希")
    }

    /// 验证 EAPI 解密已知测试向量
    func testEAPIDecryptWithKnownTestVector() throws {
        // 先用已知数据加密，然后验证解密结果
        let url = "/api/test"
        let object: [String: Any] = ["key": "value"]

        // 手动构造加密数据作为测试向量
        let jsonData = try JSONSerialization.data(withJSONObject: object, options: [])
        let text = String(data: jsonData, encoding: .utf8)!
        let message = "nobody\(url)use\(text)md5forencrypt"
        let digest = CryptoEngine.md5(message)
        let combined = "\(url)-36cd479b6b5-\(text)-36cd479b6b5-\(digest)"

        // AES-ECB 加密
        let eapiKeyData = Data(NCMConstants.eapiKey.utf8)
        _ = try CryptoEngine.aesECBEncrypt(data: Data(combined.utf8), key: eapiKeyData)

        // 使用 eapiDecrypt 解密 — 注意 eapiDecrypt 期望解密后的数据是 JSON
        // 但 EAPI 加密的内容是拼接字符串，不是纯 JSON
        // 所以 eapiDecrypt 用于解密 EAPI 响应（响应体是纯 JSON 加密后的 hex）

        // 构造一个纯 JSON 的加密测试向量
        let pureJsonEncrypted = try CryptoEngine.aesECBEncrypt(data: jsonData, key: eapiKeyData)
        let pureJsonHex = pureJsonEncrypted.map { String(format: "%02X", $0) }.joined()

        // 解密并验证
        let decrypted = try CryptoEngine.eapiDecrypt(hexString: pureJsonHex)
        XCTAssertEqual(decrypted["key"] as? String, "value", "解密后的 JSON 应包含原始键值对")
    }

    /// 验证 EAPI 加密相同输入产生相同结果（确定性）
    func testEAPIEncryptDeterministic() throws {
        let url = "/api/song/detail"
        let object: [String: Any] = ["id": 12345]

        let result1 = try CryptoEngine.eapiEncrypt(url: url, object: object)
        let result2 = try CryptoEngine.eapiEncrypt(url: url, object: object)

        // EAPI 加密是确定性的（没有随机密钥），相同输入应产生相同输出
        XCTAssertEqual(result1.params, result2.params,
                       "EAPI 加密应为确定性的，相同输入产生相同输出")
    }

    /// 验证 EAPI 解密可以处理小写和大写 hex 输入
    func testEAPIDecryptHandlesMixedCaseHex() throws {
        let object: [String: Any] = ["test": "data"]
        let jsonData = try JSONSerialization.data(withJSONObject: object, options: [])
        let eapiKeyData = Data(NCMConstants.eapiKey.utf8)
        let encrypted = try CryptoEngine.aesECBEncrypt(data: jsonData, key: eapiKeyData)

        // 大写 hex
        let upperHex = encrypted.map { String(format: "%02X", $0) }.joined()
        let result1 = try CryptoEngine.eapiDecrypt(hexString: upperHex)
        XCTAssertEqual(result1["test"] as? String, "data")

        // 小写 hex
        let lowerHex = encrypted.map { String(format: "%02x", $0) }.joined()
        let result2 = try CryptoEngine.eapiDecrypt(hexString: lowerHex)
        XCTAssertEqual(result2["test"] as? String, "data")
    }

    /// 验证 EAPI 加密可以处理空 JSON 对象
    func testEAPIEncryptEmptyObject() throws {
        let url = "/api/test"
        let object: [String: Any] = [:]

        let result = try CryptoEngine.eapiEncrypt(url: url, object: object)

        XCTAssertFalse(result.params.isEmpty, "空对象加密后 params 不应为空")
        // 验证是大写 hex
        let hexCharSet = CharacterSet(charactersIn: "0123456789ABCDEF")
        XCTAssertTrue(result.params.unicodeScalars.allSatisfy { hexCharSet.contains($0) })
    }

    /// 验证 EAPI 解密无效 hex 字符串时抛出错误
    func testEAPIDecryptInvalidHexThrows() {
        // 奇数长度的 hex 字符串
        XCTAssertThrowsError(try CryptoEngine.eapiDecrypt(hexString: "ABC")) { error in
            XCTAssertTrue(error is CryptoEngine.CryptoError, "应抛出 CryptoError")
        }

        // 包含非 hex 字符
        XCTAssertThrowsError(try CryptoEngine.eapiDecrypt(hexString: "GHIJ")) { error in
            XCTAssertTrue(error is CryptoEngine.CryptoError, "应抛出 CryptoError")
        }
    }

    // MARK: - LinuxAPI 加密测试

    /// 验证 LinuxAPI 加密返回非空的大写 hex 输出
    func testLinuxAPIEncryptProducesNonEmptyHexOutput() throws {
        let jsonObject: [String: Any] = [
            "method": "POST",
            "url": "https://music.163.com/api/song/detail",
            "params": ["id": 347230]
        ]

        let result = try CryptoEngine.linuxapiEncrypt(jsonObject)

        // eparams 不应为空
        XCTAssertFalse(result.eparams.isEmpty, "LinuxAPI 加密结果 eparams 不应为空")
    }

    /// 验证 LinuxAPI 加密输出是大写十六进制字符串
    func testLinuxAPIEncryptOutputIsUppercaseHex() throws {
        let jsonObject: [String: Any] = [
            "method": "POST",
            "url": "https://music.163.com/api/song/detail",
            "params": ["id": 347230, "c": "[{\"id\":347230}]"]
        ]

        let result = try CryptoEngine.linuxapiEncrypt(jsonObject)

        // 验证所有字符都是大写十六进制字符
        let hexCharSet = CharacterSet(charactersIn: "0123456789ABCDEF")
        XCTAssertTrue(result.eparams.unicodeScalars.allSatisfy { hexCharSet.contains($0) },
                      "LinuxAPI 加密输出应只包含大写十六进制字符")
        // hex 字符串长度应为偶数
        XCTAssertEqual(result.eparams.count % 2, 0, "hex 字符串长度应为偶数")
    }

    /// 验证 LinuxAPI 加密-解密 round-trip：加密后用 linuxapiKey 解密可还原原始 JSON
    func testLinuxAPIEncryptDecryptRoundTrip() throws {
        let jsonObject: [String: Any] = [
            "method": "POST",
            "url": "https://music.163.com/api/song/detail",
            "params": ["id": 347230]
        ]

        // 加密
        let encrypted = try CryptoEngine.linuxapiEncrypt(jsonObject)

        // 将 hex 字符串转换为 Data
        let cleanHex = encrypted.eparams.lowercased()
        var hexData = Data()
        var index = cleanHex.startIndex
        while index < cleanHex.endIndex {
            let nextIndex = cleanHex.index(index, offsetBy: 2)
            let byteString = String(cleanHex[index..<nextIndex])
            guard let byte = UInt8(byteString, radix: 16) else {
                XCTFail("无效的 hex 字符")
                return
            }
            hexData.append(byte)
            index = nextIndex
        }

        // 使用 linuxapiKey 解密
        let linuxapiKeyData = Data(NCMConstants.linuxapiKey.utf8)
        let decryptedData = try CryptoEngine.aesECBDecrypt(data: hexData, key: linuxapiKeyData)

        // 解析解密后的 JSON
        let decryptedObject = try JSONSerialization.jsonObject(with: decryptedData, options: []) as? [String: Any]
        XCTAssertNotNil(decryptedObject, "解密后的数据应为有效的 JSON 字典")

        // 验证解密后的 JSON 包含原始字段
        XCTAssertEqual(decryptedObject?["method"] as? String, "POST", "解密后应包含原始 method 字段")
        XCTAssertEqual(decryptedObject?["url"] as? String,
                       "https://music.163.com/api/song/detail", "解密后应包含原始 url 字段")

        // 验证 params 字段
        let params = decryptedObject?["params"] as? [String: Any]
        XCTAssertNotNil(params, "解密后应包含 params 字段")
        XCTAssertEqual(params?["id"] as? Int, 347230, "params 中应包含原始 id")
    }

    /// 验证 LinuxAPI 加密是确定性的（相同输入产生相同输出）
    func testLinuxAPIEncryptDeterministic() throws {
        let jsonObject: [String: Any] = [
            "method": "POST",
            "url": "https://music.163.com/api/test",
            "params": ["key": "value"]
        ]

        let result1 = try CryptoEngine.linuxapiEncrypt(jsonObject)
        let result2 = try CryptoEngine.linuxapiEncrypt(jsonObject)

        // LinuxAPI 加密是确定性的，相同输入应产生相同输出
        XCTAssertEqual(result1.eparams, result2.eparams,
                       "LinuxAPI 加密应为确定性的，相同输入产生相同输出")
    }

    /// 验证 LinuxAPI 加密可以处理空 params 的 JSON 对象
    func testLinuxAPIEncryptEmptyParams() throws {
        let jsonObject: [String: Any] = [
            "method": "POST",
            "url": "https://music.163.com/api/test",
            "params": [String: Any]()
        ]

        let result = try CryptoEngine.linuxapiEncrypt(jsonObject)

        XCTAssertFalse(result.eparams.isEmpty, "空 params 加密后 eparams 不应为空")
        // 验证是大写 hex
        let hexCharSet = CharacterSet(charactersIn: "0123456789ABCDEF")
        XCTAssertTrue(result.eparams.unicodeScalars.allSatisfy { hexCharSet.contains($0) })
    }

    /// 验证 LinuxAPI 加密可以处理包含中文的 JSON 对象
    func testLinuxAPIEncryptWithChineseContent() throws {
        let jsonObject: [String: Any] = [
            "method": "POST",
            "url": "https://music.163.com/api/search",
            "params": ["keywords": "周杰伦", "type": 1]
        ]

        let result = try CryptoEngine.linuxapiEncrypt(jsonObject)

        XCTAssertFalse(result.eparams.isEmpty)
        let hexCharSet = CharacterSet(charactersIn: "0123456789ABCDEF")
        XCTAssertTrue(result.eparams.unicodeScalars.allSatisfy { hexCharSet.contains($0) })

        // 验证 round-trip：解密后应包含中文内容
        var hexData = Data()
        let cleanHex = result.eparams.lowercased()
        var idx = cleanHex.startIndex
        while idx < cleanHex.endIndex {
            let nextIdx = cleanHex.index(idx, offsetBy: 2)
            let byteStr = String(cleanHex[idx..<nextIdx])
            hexData.append(UInt8(byteStr, radix: 16)!)
            idx = nextIdx
        }
        let linuxapiKeyData = Data(NCMConstants.linuxapiKey.utf8)
        let decryptedData = try CryptoEngine.aesECBDecrypt(data: hexData, key: linuxapiKeyData)
        let decryptedObject = try JSONSerialization.jsonObject(with: decryptedData, options: []) as? [String: Any]
        let params = decryptedObject?["params"] as? [String: Any]
        XCTAssertEqual(params?["keywords"] as? String, "周杰伦", "解密后应包含中文关键词")
    }
}
