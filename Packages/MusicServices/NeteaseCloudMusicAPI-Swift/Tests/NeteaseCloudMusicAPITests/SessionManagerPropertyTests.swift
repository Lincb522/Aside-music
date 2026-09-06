// SessionManagerPropertyTests.swift
// 会话管理属性测试
// 使用 SwiftCheck 验证会话管理器的通用正确性属性

import XCTest
import SwiftCheck
@testable import NeteaseCloudMusicAPI

final class SessionManagerPropertyTests: XCTestCase {

    // MARK: - 测试配置

    /// 减少属性测试迭代次数以加快测试速度
    private let quickArgs = CheckerArguments(maxAllowableSuccessfulTests: 5)

    // MARK: - 辅助生成器

    /// 生成随机平台类型
    private static let platformGen: Gen<PlatformType> =
        Gen.fromElements(of: PlatformType.allCases)

    /// 生成安全的 Cookie 键（仅包含字母数字和下划线，非空）
    private static let cookieKeyGen: Gen<String> =
        Gen.fromElements(of: Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_"))
            .proliferateNonEmpty
            .map { String($0.prefix(20)) }

    /// 生成安全的 Cookie 值（仅包含可打印 ASCII 字符，不含分号和等号）
    private static let cookieValueGen: Gen<String> =
        Gen.fromElements(of: Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"))
            .proliferateNonEmpty
            .map { String($0.prefix(50)) }

    /// 生成随机匿名令牌字符串
    private static let anonymousTokenGen: Gen<String> =
        Gen.fromElements(of: Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789+/="))
            .proliferateNonEmpty
            .map { String($0.prefix(100)) }

    /// 生成随机 Cookie 字典（不包含 MUSIC_U）
    private static let cookieDictWithoutMusicUGen: Gen<[String: String]> = {
        let pairGen = Gen<(String, String)>.zip(cookieKeyGen, cookieValueGen)
        return pairGen.proliferate
            .suchThat { pairs in pairs.count <= 10 }
            .map { pairs in
                var dict = [String: String]()
                for (key, value) in pairs {
                    // 排除 MUSIC_U 键，确保不包含认证令牌
                    if key != "MUSIC_U" {
                        dict[key] = value
                    }
                }
                return dict
            }
    }()

    /// 生成随机 Cookie 字典（可能包含任意键）
    private static let cookieDictGen: Gen<[String: String]> = {
        let pairGen = Gen<(String, String)>.zip(cookieKeyGen, cookieValueGen)
        return pairGen.proliferate
            .suchThat { pairs in pairs.count <= 10 }
            .map { pairs in
                var dict = [String: String]()
                for (key, value) in pairs {
                    dict[key] = value
                }
                return dict
            }
    }()

    // MARK: - Property 7: 匿名令牌回退

    /// 属性测试 7：匿名令牌回退
    /// 对于任意不包含 MUSIC_U 令牌的会话状态，构建的 Cookie 头中
    /// MUSIC_A 字段应该等于配置的匿名令牌值。
    // **Validates: Requirements 3.2**
    func testProperty7_AnonymousTokenFallback() {
        property("无 MUSIC_U 时，Cookie 头中 MUSIC_A 应等于匿名令牌", arguments: quickArgs) <- forAllNoShrink(
            SessionManagerPropertyTests.platformGen,
            SessionManagerPropertyTests.anonymousTokenGen,
            SessionManagerPropertyTests.cookieDictWithoutMusicUGen
        ) { (platform: PlatformType, anonToken: String, cookies: [String: String]) in
            // 确保 cookies 中不包含 MUSIC_U
            var safeCookies = cookies
            safeCookies.removeValue(forKey: "MUSIC_U")
            // 同时移除 MUSIC_A，以便测试回退逻辑
            safeCookies.removeValue(forKey: "MUSIC_A")

            // 创建会话管理器
            let session = SessionManager(
                platformType: platform,
                anonymousToken: anonToken,
                cookies: safeCookies
            )

            // 构建 Cookie 头（使用 eapi 模式）
            let cookieHeader = session.buildCookieHeader(for: "/api/test", crypto: .eapi)

            // 解析 Cookie 头字符串，提取 MUSIC_A 的值
            let cookiePairs = cookieHeader.components(separatedBy: "; ")
            var parsedCookies = [String: String]()
            for pair in cookiePairs {
                let kv = pair.split(separator: "=", maxSplits: 1)
                if kv.count == 2 {
                    let key = String(kv[0]).removingPercentEncoding ?? String(kv[0])
                    let value = String(kv[1]).removingPercentEncoding ?? String(kv[1])
                    parsedCookies[key] = value
                }
            }

            // 验证 MUSIC_A 等于匿名令牌
            guard let musicA = parsedCookies["MUSIC_A"] else {
                // 如果匿名令牌为空，MUSIC_A 可能为空字符串
                return anonToken.isEmpty
            }
            return musicA == anonToken
        }
    }

    // MARK: - Property 8: Cookie 更新

    /// 属性测试 8：Cookie 更新
    /// 对于任意包含有效 key=value 对的 Set-Cookie 头列表，更新会话后，
    /// 会话的 cookie 存储应该包含所有新设置的 cookie 值。
    // **Validates: Requirements 3.3**
    func testProperty8_CookieUpdate() {
        // 生成 Set-Cookie 头列表
        let setCookieGen: Gen<[(String, String)]> = Gen<(String, String)>.zip(
            SessionManagerPropertyTests.cookieKeyGen,
            SessionManagerPropertyTests.cookieValueGen
        ).proliferateNonEmpty.map { Array($0.prefix(8)) }

        property("Set-Cookie 头更新后，会话应包含所有新 cookie 值", arguments: quickArgs) <- forAllNoShrink(
            setCookieGen
        ) { (cookiePairs: [(String, String)]) in
            // 创建空会话
            let session = SessionManager(
                platformType: .iphone,
                anonymousToken: "",
                cookies: [:]
            )

            // 构建 Set-Cookie 头字符串列表
            // 格式：key=value; Path=/; Domain=.music.163.com
            let setCookieHeaders = cookiePairs.map { key, value in
                "\(key)=\(value); Path=/; HttpOnly"
            }

            // 更新 Cookie
            session.updateCookies(from: setCookieHeaders)

            // 验证所有新设置的 cookie 都存在于会话中
            for (key, value) in cookiePairs {
                guard session.cookies[key] == value else {
                    return false
                }
            }
            return true
        }
    }

    // MARK: - Property 9: 请求头必需字段完整性

    /// 属性测试 9：请求头必需字段完整性
    /// 对于任意平台类型和会话状态，构建的设备元数据 Cookie 和 EAPI/API 请求头
    /// 应该包含所有必需字段（osver、deviceId、os、appver、channel、__csrf、requestId）。
    // **Validates: Requirements 3.4, 3.5**
    func testProperty9_RequiredHeaderFieldsCompleteness() {
        property("EAPI 请求头应包含所有必需字段", arguments: quickArgs) <- forAllNoShrink(
            SessionManagerPropertyTests.platformGen,
            SessionManagerPropertyTests.cookieDictGen
        ) { (platform: PlatformType, cookies: [String: String]) in
            // 创建会话管理器
            let session = SessionManager(
                platformType: platform,
                anonymousToken: "test_anon_token",
                cookies: cookies
            )

            // 生成 CSRF 令牌
            let csrfToken = cookies["__csrf"] ?? "test_csrf"

            // 构建 EAPI 请求头
            let header = session.buildEAPIHeader(csrfToken: csrfToken)

            // 验证所有必需字段都存在
            let requiredFields = ["osver", "deviceId", "os", "appver", "channel", "__csrf", "requestId"]
            for field in requiredFields {
                guard header[field] != nil else {
                    return false
                }
                // 验证字段值非空
                guard !header[field]!.isEmpty else {
                    // __csrf 可以为空字符串（未登录时）
                    if field == "__csrf" {
                        continue
                    }
                    return false
                }
            }

            // 验证 __csrf 字段等于传入的 csrfToken
            guard header["__csrf"] == csrfToken else {
                return false
            }

            return true
        }
    }

    /// 属性测试 9 补充：Cookie 头中也应包含设备元数据必需字段
    /// 验证 buildCookieHeader 生成的 Cookie 字符串包含必需的设备元数据字段
    // **Validates: Requirements 3.4**
    func testProperty9_CookieHeaderRequiredFields() {
        property("Cookie 头应包含设备元数据必需字段", arguments: quickArgs) <- forAllNoShrink(
            SessionManagerPropertyTests.platformGen
        ) { (platform: PlatformType) in
            // 创建空会话管理器
            let session = SessionManager(
                platformType: platform,
                anonymousToken: "test_token",
                cookies: [:]
            )

            // 构建 Cookie 头
            let cookieHeader = session.buildCookieHeader(for: "/api/test", crypto: .eapi)

            // 解析 Cookie 头
            let cookiePairs = cookieHeader.components(separatedBy: "; ")
            var parsedCookies = [String: String]()
            for pair in cookiePairs {
                let kv = pair.split(separator: "=", maxSplits: 1)
                if kv.count == 2 {
                    let key = String(kv[0]).removingPercentEncoding ?? String(kv[0])
                    let value = String(kv[1]).removingPercentEncoding ?? String(kv[1])
                    parsedCookies[key] = value
                }
            }

            // 验证设备元数据必需字段存在
            let requiredCookieFields = ["osver", "deviceId", "os", "appver", "channel"]
            for field in requiredCookieFields {
                guard let value = parsedCookies[field], !value.isEmpty else {
                    return false
                }
            }

            return true
        }
    }

    // MARK: - Property 10: 会话序列化 Round-Trip

    /// 属性测试 10：会话序列化 Round-Trip
    /// 对于任意有效的 SessionManager 状态（包含任意 cookie、平台类型和匿名令牌），
    /// 序列化后再反序列化应该产生等价的会话对象。
    // **Validates: Requirements 3.7, 3.8**
    func testProperty10_SessionSerializationRoundTrip() {
        property("会话序列化后再反序列化应产生等价的会话对象", arguments: quickArgs) <- forAllNoShrink(
            SessionManagerPropertyTests.platformGen,
            SessionManagerPropertyTests.anonymousTokenGen,
            SessionManagerPropertyTests.cookieDictGen
        ) { (platform: PlatformType, anonToken: String, cookies: [String: String]) in
            // 创建原始会话管理器
            let original = SessionManager(
                platformType: platform,
                anonymousToken: anonToken,
                cookies: cookies
            )

            do {
                // 序列化
                let data = try original.serialize()

                // 反序列化
                let restored = try SessionManager.deserialize(from: data)

                // 验证所有属性等价
                // 1. 平台类型
                guard restored.platformType == original.platformType else {
                    return false
                }

                // 2. 匿名令牌
                guard restored.anonymousToken == original.anonymousToken else {
                    return false
                }

                // 3. Cookie 存储
                guard restored.cookies == original.cookies else {
                    return false
                }

                // 4. 设备 ID
                guard restored.deviceId == original.deviceId else {
                    return false
                }

                // 5. WNMCID
                guard restored.wnmcid == original.wnmcid else {
                    return false
                }

                return true
            } catch {
                // 序列化或反序列化失败
                return false
            }
        }
    }
}
