// NCMConstants.swift
// ncm API 常量定义
// 包含所有加密密钥、初始化向量、公钥、域名等配置常量

import Foundation

/// ncm API 核心常量
enum NCMConstants {
    /// WeAPI 加密预设密钥（AES-CBC）
    static let presetKey = "0CoJUm6Qyw8W8jud"

    /// AES-CBC 加密初始化向量
    static let iv = "0102030405060708"

    /// LinuxAPI 加密密钥（AES-ECB）
    static let linuxapiKey = "rFgB&h#%2?^eDg:Q"

    /// EAPI 加密密钥（AES-ECB）
    static let eapiKey = "e82ckenh8dichen8"

    /// Base62 字符集，用于生成随机密钥
    static let base62 = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

    /// RSA 公钥（PEM 格式），用于 WeAPI 加密模式
    static let publicKeyPEM = """
    -----BEGIN PUBLIC KEY-----
    MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDgtQn2JZ34ZC28NWYpAUd98iZ3\
    7BUrX/aKzmFbt7clFSs6sXqHauqKWqdtLkF2KexO40H1YTX8z2lSgBBOAxLsvaklV8k4cBFK9snQXE9/\
    DDaFt6Rr7iVZMldczhC0JNgTz+SHXT6CBHuX3e9SdB1Ua44oncaTWz7OBGLbCiK45wIDAQAB
    -----END PUBLIC KEY-----
    """

    /// ncm主域名
    static let domain = "https://music.163.com"

    /// ncm API 接口域名
    static let apiDomain = "https://interface.music.163.com"

    /// 需要归一化为 200 的特殊状态码集合
    static let specialStatusCodes: Set<Int> = [201, 302, 400, 502, 800, 801, 802, 803]
}
