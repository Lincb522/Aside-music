import Foundation
import Security

/// 安全存储工具
/// 优先使用 Keychain，如果 Keychain 不可用则自动降级到文件存储
enum KeychainHelper {
    
    private static let service = "com.aside.music"
    
    /// Keychain 是否可用（启动时检测一次）
    private static let keychainAvailable: Bool = {
        let testKey = "__keychain_test__"
        let testData = "test".data(using: .utf8)!
        
        // 尝试写入
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: testKey,
            kSecValueData as String: testData
        ]
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        
        // 清理
        let delQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: testKey
        ]
        SecItemDelete(delQuery as CFDictionary)
        
        let available = (addStatus == errSecSuccess || addStatus == errSecDuplicateItem)
        #if DEBUG
        print("[KeychainHelper] Keychain \(available ? "✅ 可用" : "❌ 不可用(status=\(addStatus))，降级到文件存储")")
        #endif
        return available
    }()
    
    // MARK: - 公开接口
    
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
    
    static func delete(key: String) {
        if keychainAvailable {
            keychainDelete(key: key)
        } else {
            fileDelete(key: key)
        }
    }

    // MARK: - Keychain 实现
    
    private static func keychainSave(key: String, data: Data) {
        keychainDelete(key: key)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecValueData as String: data
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        #if DEBUG
        if status != errSecSuccess {
            print("[Keychain] ⚠️ 写入失败 key=\(key) status=\(status)")
        }
        #endif
    }
    
    private static func keychainLoad(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }
    
    private static func keychainDelete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
    
    // MARK: - 文件存储降级（巨魔/无签名环境）
    
    private static var storageDir: URL = {
        let dir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(".aside_secure", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // 排除 iCloud 备份
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
