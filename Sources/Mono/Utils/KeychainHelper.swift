import Foundation
import Security

/// 安全存储工具
/// 优先使用 Keychain，如果 Keychain 不可用则自动降级到文件存储
/// 支持 Keychain Access Group，主 App 与 Extension 共享数据
enum KeychainHelper {
    
    private static let service = "zijiu.Mono.com"
    
    /// Keychain Access Group — 主 App 和 Extension 共享
    /// 运行时自动探测：带 group 可用就用 group，否则回退到不带 group 的普通 Keychain
    /// 都不行才降级到文件存储
    private static let resolvedAccessGroup: String? = {
        let testKey = "__keychain_group_test__"
        let testData = "test".data(using: .utf8)!
        
        // 从 entitlements 运行时获取实际的 keychain-access-groups（含 Team ID 前缀）
        // 模拟器和真机上 Xcode 会自动展开 $(AppIdentifierPrefix)
        let candidates: [String] = {
            // 方法1：尝试写入一条不带 group 的记录，然后读回它的 accessGroup
            let probeKey = "__keychain_group_probe__"
            let probeAdd: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: probeKey,
                kSecValueData as String: testData
            ]
            SecItemDelete(probeAdd as CFDictionary)
            let addSt = SecItemAdd(probeAdd as CFDictionary, nil)
            defer {
                let del: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: service,
                    kSecAttrAccount as String: probeKey
                ]
                SecItemDelete(del as CFDictionary)
            }
            if addSt == errSecSuccess {
                let readQuery: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: service,
                    kSecAttrAccount as String: probeKey,
                    kSecReturnAttributes as String: true,
                    kSecMatchLimit as String: kSecMatchLimitOne
                ]
                var result: AnyObject?
                if SecItemCopyMatching(readQuery as CFDictionary, &result) == errSecSuccess,
                   let attrs = result as? [String: Any],
                   let defaultGroup = attrs[kSecAttrAccessGroup as String] as? String {
                    // defaultGroup 就是 "TEAMID.com.xxx" 格式
                    // 尝试用它的 Team ID 前缀 + 我们想要的 group 后缀
                    let suffix = "zijiu.Mono.com"
                    if defaultGroup.hasSuffix(suffix) {
                        return [defaultGroup]
                    }
                    // 提取 Team ID 前缀
                    if let dotIndex = defaultGroup.firstIndex(of: ".") {
                        let teamPrefix = String(defaultGroup[defaultGroup.startIndex...dotIndex])
                        return [teamPrefix + suffix, defaultGroup]
                    }
                    return [defaultGroup]
                }
            }
            return []
        }()
        
        for group in candidates {
            var groupQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: testKey,
                kSecAttrAccessGroup as String: group,
                kSecValueData as String: testData
            ]
            let groupStatus = SecItemAdd(groupQuery as CFDictionary, nil)
            
            let groupDel: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: testKey,
                kSecAttrAccessGroup as String: group
            ]
            SecItemDelete(groupDel as CFDictionary)
            
            if groupStatus == errSecSuccess || groupStatus == errSecDuplicateItem {
                #if DEBUG
                print("[KeychainHelper] ✅ Access Group '\(group)' 可用")
                #endif
                return group
            }
        }
        
        #if DEBUG
        print("[KeychainHelper] ⚠️ Access Group 不可用，回退到普通 Keychain")
        #endif
        return nil
    }()
    
    /// Keychain 是否可用（启动时检测一次）
    /// 不带 accessGroup 再探测一次，确认普通 Keychain 是否可用
    private static let keychainAvailable: Bool = {
        // 如果 resolvedAccessGroup 已经成功，Keychain 肯定可用
        if resolvedAccessGroup != nil { return true }
        
        let testKey = "__keychain_test__"
        let testData = "test".data(using: .utf8)!
        
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: testKey,
            kSecValueData as String: testData
        ]
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        
        let delQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: testKey
        ]
        SecItemDelete(delQuery as CFDictionary)
        
        let available = (addStatus == errSecSuccess || addStatus == errSecDuplicateItem)
        #if DEBUG
        print("[KeychainHelper] Keychain \(available ? "✅ 可用（无 Group）" : "❌ 不可用(status=\(addStatus))，降级到文件存储")")
        #endif
        return available
    }()
    
    // MARK: - 首次安装清理
    
    /// 删除 App 重装后清除残留的 Keychain 数据
    /// UserDefaults 随 App 卸载被清除，Keychain 不会
    /// 利用这个差异检测是否为全新安装
    static func cleanupIfFreshInstall() {
        let key = "mono_keychain_installed"
        if UserDefaults.standard.bool(forKey: key) { return }
        
        #if DEBUG
        print("[KeychainHelper] 检测到全新安装，但按照要求保留之前安装的 Keychain UDID 与数据")
        #endif
        
        // 我们不再执行 SecItemDelete，使得所有的设备 UDID（包括 mono_device_uuid 与 mlg.access.seed.v2）
        // 都能够得到完整的跨卸载保留。
        
        // 仅清理文件存储降级目录即可
        if FileManager.default.fileExists(atPath: storageDir.path) {
            try? FileManager.default.removeItem(at: storageDir)
            try? FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)
        }
        
        UserDefaults.standard.set(true, forKey: key)
    }
    
    // MARK: - 公开接口（String）
    
    static func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        if keychainAvailable {
            keychainSave(key: key, data: data)
        } else {
            fileSave(key: key, data: data)
        }
    }
    
    static func loadString(key: String) -> String? {
        let data = keychainAvailable ? keychainLoad(key: key) : fileLoad(key: key)
        guard let data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    // MARK: - 公开接口（Int）
    
    static func save(key: String, intValue: Int) {
        let data = withUnsafeBytes(of: intValue) { Data($0) }
        if keychainAvailable {
            keychainSave(key: key, data: data)
        } else {
            fileSave(key: key, data: data)
        }
    }
    
    static func loadInt(key: String) -> Int? {
        let data = keychainAvailable ? keychainLoad(key: key) : fileLoad(key: key)
        guard let data, data.count == MemoryLayout<Int>.size else { return nil }
        return data.withUnsafeBytes { $0.load(as: Int.self) }
    }
    
    // MARK: - 公开接口（Data）
    
    static func save(key: String, data: Data) {
        if keychainAvailable {
            keychainSave(key: key, data: data)
        } else {
            fileSave(key: key, data: data)
        }
    }
    
    static func loadData(key: String) -> Data? {
        keychainAvailable ? keychainLoad(key: key) : fileLoad(key: key)
    }
    
    // MARK: - 公开接口（Codable）
    
    /// 存储任意 Codable 对象
    static func save<T: Encodable>(key: String, object: T) {
        guard let data = try? JSONEncoder().encode(object) else {
            #if DEBUG
            print("[KeychainHelper] ⚠️ 编码失败 key=\(key)")
            #endif
            return
        }
        save(key: key, data: data)
    }
    
    /// 读取任意 Codable 对象
    static func loadObject<T: Decodable>(key: String, as type: T.Type) -> T? {
        guard let data = loadData(key: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
    
    // MARK: - 删除
    
    static func delete(key: String) {
        if keychainAvailable {
            keychainDelete(key: key)
        } else {
            fileDelete(key: key)
        }
    }
    
    /// 清除本 App 在 Keychain 中存储的所有数据
    static func deleteAll() {
        if keychainAvailable {
            var query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service
            ]
            if let group = resolvedAccessGroup {
                query[kSecAttrAccessGroup as String] = group
            }
            SecItemDelete(query as CFDictionary)
        }
        // 同时清理文件降级存储
        if FileManager.default.fileExists(atPath: storageDir.path) {
            try? FileManager.default.removeItem(at: storageDir)
        }
        #if DEBUG
        print("[KeychainHelper] 🗑️ 已清除所有 Keychain 与文件存储数据")
        #endif
    }

    // MARK: - Keychain 实现（带 Access Group）
    
    /// 构建基础查询字典（自动附加 accessGroup）
    private static func baseQuery(for key: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        if let group = resolvedAccessGroup {
            query[kSecAttrAccessGroup as String] = group
        }
        return query
    }
    
    private static func keychainSave(key: String, data: Data) {
        keychainDelete(key: key)
        var query = baseQuery(for: key)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        query[kSecValueData as String] = data
        var status = SecItemAdd(query as CFDictionary, nil)
        
        // 如果是 duplicate（理论上 delete 后不应该出现），尝试 update
        if status == errSecDuplicateItem {
            let updateQuery = baseQuery(for: key)
            let updateAttrs: [String: Any] = [kSecValueData as String: data]
            status = SecItemUpdate(updateQuery as CFDictionary, updateAttrs as CFDictionary)
        }
        
        // 写入后回读验证
        if status == errSecSuccess {
            if keychainLoad(key: key) != nil {
                #if DEBUG
                print("[Keychain] ✅ 写入并验证成功 key=\(key) (\(data.count) bytes)")
                #endif
                return
            }
            #if DEBUG
            print("[Keychain] ⚠️ 写入成功但回读失败 key=\(key)，降级到文件存储")
            #endif
        } else {
            #if DEBUG
            print("[Keychain] ⚠️ 写入失败 key=\(key) status=\(status)，降级到文件存储")
            #endif
        }
        
        // Keychain 写入不可靠时，同时写一份到文件兜底
        fileSave(key: key, data: data)
    }
    
    private static func keychainLoad(key: String) -> Data? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data {
            return data
        }
        // Keychain 读不到时，尝试从文件兜底读取
        if let fileData = fileLoad(key: key) {
            #if DEBUG
            print("[Keychain] ℹ️ Keychain 未命中 key=\(key)，从文件兜底读取")
            #endif
            return fileData
        }
        return nil
    }
    
    private static func keychainDelete(key: String) {
        let query = baseQuery(for: key)
        SecItemDelete(query as CFDictionary)
    }
    
    // MARK: - 文件存储降级（巨魔/无签名环境）
    
    private nonisolated(unsafe) static var storageDir: URL = {
        let base = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent(".mono_secure", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var url = dir
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
        return dir
    }()
    
    private static func fileUrl(for key: String) -> URL {
        storageDir.appendingPathComponent(key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? key)
    }
    
    private static func fileSave(key: String, data: Data) {
        do {
            try data.write(to: fileUrl(for: key), options: .completeFileProtectionUntilFirstUserAuthentication)
        } catch {
            #if DEBUG
            print("[FileStore] ⚠️ 写入失败 key=\(key) error=\(error)")
            #endif
        }
    }
    
    private static func fileLoad(key: String) -> Data? {
        try? Data(contentsOf: fileUrl(for: key))
    }
    
    private static func fileDelete(key: String) {
        try? FileManager.default.removeItem(at: fileUrl(for: key))
    }
}
