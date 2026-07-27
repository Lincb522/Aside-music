// 安全配置管理 — 从 Info.plist 读取敏感配置，避免硬编码在源码中

import Foundation

/// 安全配置管理器
/// 所有敏感信息（API Key、服务器地址等）从 Info.plist 或环境变量读取
enum SecureConfig {
    private enum TokenVault {
        private static let storageMask: UInt8 = 0x39
        private static let markerMask: UInt8 = 0x17

        private static let currentStorageSeed: [UInt8] = [84, 85, 94, 23, 88, 90, 90, 92, 74, 74, 23, 74, 92, 92, 93, 23, 79, 11]
        private static let legacyStorageSeed: [UInt8] = [84, 86, 87, 86, 85, 86, 94, 76, 92, 102, 88, 73, 80, 102, 77, 86, 82, 92, 87]
        private static let keyMaterialSeed: [UInt8] = [84, 86, 87, 86, 85, 86, 94, 76, 92, 23, 88, 90, 90, 92, 74, 74, 23, 79, 88, 76, 85, 77]
        private static let markerSeed: [UInt8] = [122, 123, 99, 37]
        private static let fallbackBundleSeed: [UInt8] = [90, 120, 121, 120, 123, 120, 112, 98, 114, 57, 117, 98, 121, 115, 123, 114]

        static func loadToken() -> String? {
            if let token = readToken(for: currentStorageKey, rewrapIfNeeded: true) {
                return token
            }

            guard let legacy = readToken(for: legacyStorageKey, rewrapIfNeeded: false) else {
                return nil
            }

            persist(legacy)
            KeychainHelper.delete(key: legacyStorageKey)
            return legacy
        }

        static func persist(_ token: String) {
            let normalized = token.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else {
                clear()
                return
            }

            KeychainHelper.save(key: currentStorageKey, value: encode(normalized) ?? normalized)
            if legacyStorageKey != currentStorageKey {
                KeychainHelper.delete(key: legacyStorageKey)
            }
        }

        static func clear() {
            KeychainHelper.delete(key: currentStorageKey)
            if legacyStorageKey != currentStorageKey {
                KeychainHelper.delete(key: legacyStorageKey)
            }
        }

        private static func readToken(for key: String, rewrapIfNeeded: Bool) -> String? {
            guard let rawValue = KeychainHelper.loadString(key: key)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                !rawValue.isEmpty else {
                return nil
            }

            if let decoded = decode(rawValue) {
                return decoded
            }

            if rewrapIfNeeded {
                KeychainHelper.save(key: key, value: encode(rawValue) ?? rawValue)
            }
            return rawValue
        }

        private static func encode(_ token: String) -> String? {
            guard !token.isEmpty else { return nil }

            let key = keyMaterial
            let payload = Array(token.utf8).enumerated().map { index, byte in
                byte ^ key[index % key.count] ^ UInt8((index * 29 + 7) & 0xFF)
            }
            return Data(marker + payload).base64EncodedString()
        }

        private static func decode(_ encoded: String) -> String? {
            guard let data = Data(base64Encoded: encoded) else { return nil }

            let bytes = [UInt8](data)
            guard bytes.count >= marker.count else { return nil }
            guard Array(bytes.prefix(marker.count)) == marker else { return nil }

            let key = keyMaterial
            let payload = bytes.dropFirst(marker.count).enumerated().map { index, byte in
                byte ^ key[index % key.count] ^ UInt8((index * 29 + 7) & 0xFF)
            }

            return String(bytes: payload, encoding: .utf8)
        }

        private static var currentStorageKey: String {
            reveal(currentStorageSeed, mask: storageMask)
        }

        private static var legacyStorageKey: String {
            reveal(legacyStorageSeed, mask: storageMask)
        }

        private static var marker: [UInt8] {
            Array(reveal(markerSeed, mask: markerMask).utf8)
        }

        private static var keyMaterial: [UInt8] {
            let fallbackBundle = reveal(fallbackBundleSeed, mask: markerMask)
            let bundleID = Bundle.main.bundleIdentifier ?? fallbackBundle
            let source = Array(reveal(keyMaterialSeed, mask: storageMask).utf8) + Array(bundleID.utf8)

            return source.enumerated().map { index, byte in
                byte ^ UInt8((index * 17 + 31) & 0xFF)
            }
        }

        private static func reveal(_ seed: [UInt8], mask: UInt8) -> String {
            String(decoding: seed.map { $0 ^ mask }, as: UTF8.self)
        }
    }
    
    // MARK: - API 服务器

    /// 读取配置值：环境变量优先，其次 Info.plist（忽略未展开的 $(...) 占位）
    private static func configValue(_ key: String) -> String? {
        if let envValue = ProcessInfo.processInfo.environment[key],
           !envValue.isEmpty {
            return envValue
        }
        if let plistValue = Bundle.main.object(forInfoDictionaryKey: key) as? String,
           !plistValue.isEmpty,
           !plistValue.hasPrefix("$(") {
            return plistValue
        }
        return nil
    }

    /// 是否配置了备用线路
    static var hasBackupLine: Bool {
        hasFirstBackupLine || hasSecondBackupLine
    }

    /// 是否配置了第一备用线路
    static var hasFirstBackupLine: Bool {
        configValue("API_BASE_URL_BACKUP") != nil
            && configValue("QQ_MUSIC_BASE_URL_BACKUP") != nil
            && configValue("QISHUI_BASE_URL_BACKUP") != nil
            && configValue("KUGOU_BASE_URL_BACKUP") != nil
    }

    /// 是否配置了第二备用线路
    static var hasSecondBackupLine: Bool {
        configValue("API_BASE_URL_BACKUP_2") != nil
            && configValue("QQ_MUSIC_BASE_URL_BACKUP_2") != nil
            && configValue("QISHUI_BASE_URL_BACKUP_2") != nil
            && configValue("KUGOU_BASE_URL_BACKUP_2") != nil
    }

    /// ncm API 服务器地址（指定线路）
    static func apiBaseURL(for line: ServerLine) -> String {
        if line == .backup, let backup = configValue("API_BASE_URL_BACKUP") {
            return backup
        }
        if line == .backup2, let backup = configValue("API_BASE_URL_BACKUP_2") {
            return backup
        }
        if let primary = configValue("API_BASE_URL") {
            return primary
        }
        AppLogger.error("API_BASE_URL 未配置，请在 Secrets.xcconfig 中设置")
        #if DEBUG
        return "http://localhost:3000"
        #else
        assertionFailure(String(localized: "API_BASE_URL 未配置"))
        return "http://localhost:3000"
        #endif
    }

    /// qcm API 服务器地址（指定线路）
    static func qqMusicBaseURL(for line: ServerLine) -> String {
        if line == .backup, let backup = configValue("QQ_MUSIC_BASE_URL_BACKUP") {
            return backup
        }
        if line == .backup2, let backup = configValue("QQ_MUSIC_BASE_URL_BACKUP_2") {
            return backup
        }
        if let primary = configValue("QQ_MUSIC_BASE_URL") {
            return primary
        }
        AppLogger.error("QQ_MUSIC_BASE_URL 未配置，请在 Secrets.xcconfig 中设置")
        #if DEBUG
        return "http://localhost:8000"
        #else
        assertionFailure(String(localized: "QQ_MUSIC_BASE_URL 未配置"))
        return "http://localhost:8000"
        #endif
    }

    /// KCM API 服务器地址（指定线路）
    static func kugouBaseURL(for line: ServerLine) -> String {
        if line == .backup, let backup = configValue("KUGOU_BASE_URL_BACKUP") {
            return backup
        }
        if line == .backup2, let backup = configValue("KUGOU_BASE_URL_BACKUP_2") {
            return backup
        }
        if let primary = configValue("KUGOU_BASE_URL") {
            return primary
        }
        AppLogger.error("KUGOU_BASE_URL 未配置，请在 Secrets.xcconfig 中设置")
        #if DEBUG
        return "http://localhost:3004"
        #else
        assertionFailure(String(localized: "KUGOU_BASE_URL 未配置"))
        return "http://localhost:3004"
        #endif
    }

    /// 汽水音乐 API 服务器地址（指定线路）
    static func qishuiBaseURL(for line: ServerLine) -> String {
        if line == .backup, let backup = configValue("QISHUI_BASE_URL_BACKUP") {
            return backup
        }
        if line == .backup2, let backup = configValue("QISHUI_BASE_URL_BACKUP_2") {
            return backup
        }
        if line == .primary, let primary = configValue("QISHUI_BASE_URL") {
            return primary
        }
        // 回退机制：如果没配专门的汽水地址，就用对应线路 QCM 的地址加上 /qishui
        let qqBase = qqMusicBaseURL(for: line)
        let base = qqBase.hasSuffix("/") ? String(qqBase.dropLast()) : qqBase
        return "\(base)/qishui"
    }

    /// ncm API 服务器地址（当前线路）
    static var apiBaseURL: String {
        apiBaseURL(for: ServerLineManager.currentLine)
    }

    /// qcm API 服务器地址（当前线路）
    static var qqMusicBaseURL: String {
        qqMusicBaseURL(for: ServerLineManager.currentLine)
    }

    /// KCM API 服务器地址（当前线路）
    static var kugouBaseURL: String {
        kugouBaseURL(for: ServerLineManager.currentLine)
    }

    /// 汽水音乐 API 服务器地址（当前线路）
    static var qishuiBaseURL: String {
        qishuiBaseURL(for: ServerLineManager.currentLine)
    }

    /// Mono 官网地址，用于公开分享页与短链接
    static var officialWebsiteBaseURL: String {
        if let envURL = ProcessInfo.processInfo.environment["MONO_OFFICIAL_BASE_URL"],
           !envURL.isEmpty {
            return envURL
        }
        if let plistURL = Bundle.main.object(forInfoDictionaryKey: "MONO_OFFICIAL_BASE_URL") as? String,
           !plistURL.isEmpty,
           !plistURL.hasPrefix("$(") {
            return plistURL
        }
        return "https://mono.zijiu522.cn"
    }
    
    // MARK: - API Token
    
    /// 用户配置的 API 访问令牌，存储在 Keychain 中
    static var apiToken: String? {
        get { TokenVault.loadToken() }
        set {
            if let value = newValue, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                TokenVault.persist(value)
            } else {
                TokenVault.clear()
            }
        }
    }
    
    // MARK: - VIP Cookie
    
    /// 服务器 VIP 账号 Cookie（用于非会员用户的内容请求回退）
    /// 配置方式：在 Secrets.xcconfig 中设置 VIP_COOKIE = MUSIC_U=xxx; __csrf=xxx
    static var vipCookie: String? {
        if let env = ProcessInfo.processInfo.environment["VIP_COOKIE"],
           !env.isEmpty {
            return env
        }
        if let plist = Bundle.main.object(forInfoDictionaryKey: "VIP_COOKIE") as? String,
           !plist.isEmpty,
           !plist.hasPrefix("$(") {
            return plist
        }
        return nil
    }
}
