// NeteaseCloudMusicAPITests.swift
// ncm API 基础测试
// 验证 Package 结构和基本导入是否正常

import XCTest
@testable import NeteaseCloudMusicAPI

final class NeteaseCloudMusicAPITests: XCTestCase {
    /// 验证常量定义是否正确
    func testConstantsAreDefined() {
        // 验证加密密钥
        XCTAssertEqual(NCMConstants.presetKey, "0CoJUm6Qyw8W8jud")
        XCTAssertEqual(NCMConstants.iv, "0102030405060708")
        XCTAssertEqual(NCMConstants.linuxapiKey, "rFgB&h#%2?^eDg:Q")
        XCTAssertEqual(NCMConstants.eapiKey, "e82ckenh8dichen8")

        // 验证 base62 字符集长度
        XCTAssertEqual(NCMConstants.base62.count, 62)

        // 验证域名
        XCTAssertEqual(NCMConstants.domain, "https://music.163.com")
        XCTAssertEqual(NCMConstants.apiDomain, "https://interface.music.163.com")

        // 验证公钥包含 PEM 头尾标记
        XCTAssertTrue(NCMConstants.publicKeyPEM.contains("BEGIN PUBLIC KEY"))
        XCTAssertTrue(NCMConstants.publicKeyPEM.contains("END PUBLIC KEY"))

        // 验证特殊状态码集合
        XCTAssertEqual(NCMConstants.specialStatusCodes, [201, 302, 400, 502, 800, 801, 802, 803])
    }
}
