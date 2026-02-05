import Foundation
import Combine

class CacheManager {
    static let shared = CacheManager()
    
    // Memory Cache
    private let memoryCache = NSCache<NSString, AnyObject>()
    
    // Disk Cache Directory
    private var diskCacheURL: URL {
        let urls = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        let cacheDirectory = urls[0].appendingPathComponent("AsideMusicCache")
        
        // Create directory if not exists
        if !FileManager.default.fileExists(atPath: cacheDirectory.path) {
            try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true, attributes: nil)
        }
        
        return cacheDirectory
    }
    
    // Configuration
    private let memoryLimit = 50 * 1024 * 1024 // 50MB (降低)
    private let diskLimit = 300 * 1024 * 1024 // 300MB (降低)
    private let defaultExpiration: TimeInterval = 60 * 60 * 24 * 7 // 7 Days
    
    init() {
        memoryCache.totalCostLimit = memoryLimit
        memoryCache.countLimit = 100 // 限制对象数量
        // Clean disk cache on background launch
        DispatchQueue.global(qos: .utility).async {
            self.cleanExpiredDiskCache()
        }
    }
    
    // MARK: - Generic Data Caching
    
    /// Save object to cache
    /// - Parameters:
    ///   - object: The object to save (must be Codable)
    ///   - key: Unique key
    ///   - ttl: Time to live in seconds (default: 7 days). Pass nil for permanent (until disk limit).
    func setObject<T: Codable>(_ object: T, forKey key: String, ttl: TimeInterval? = nil) {
        // 1. Save to Memory
        if let encoded = try? JSONEncoder().encode(object) {
            memoryCache.setObject(encoded as NSData, forKey: key as NSString, cost: encoded.count)
            
            // 2. Save to Disk (Async)
            DispatchQueue.global(qos: .background).async {
                self.saveToDisk(data: encoded, key: key, ttl: ttl)
            }
        }
    }
    
    func getObject<T: Codable>(forKey key: String, type: T.Type) -> T? {
        // 1. Try Memory
        if let data = memoryCache.object(forKey: key as NSString) as? Data {
            if let object = try? JSONDecoder().decode(T.self, from: data) {
                return object
            }
        }
        
        // 2. Try Disk
        if let data = loadFromDisk(key: key) {
            // Restore to Memory
            memoryCache.setObject(data as NSData, forKey: key as NSString, cost: data.count)
            
            if let object = try? JSONDecoder().decode(T.self, from: data) {
                return object
            }
        }
        
        return nil
    }
    
    /// 获取原始数据（用于预热缓存）
    func getData(forKey key: String) -> Data? {
        // 1. Try Memory
        if let data = memoryCache.object(forKey: key as NSString) as? Data {
            return data
        }
        
        // 2. Try Disk
        if let data = loadFromDisk(key: key) {
            memoryCache.setObject(data as NSData, forKey: key as NSString, cost: data.count)
            return data
        }
        
        return nil
    }
    
    // MARK: - Image Caching Helpers
    
    func setImageData(_ data: Data, forKey key: String) {
        memoryCache.setObject(data as NSData, forKey: key as NSString, cost: data.count)
        DispatchQueue.global(qos: .background).async {
            self.saveToDisk(data: data, key: key, ttl: nil) // Images usually don't expire quickly
        }
    }
    
    // Direct disk access (Blocking, use on background thread)
    func getImageData(forKey key: String) -> Data? {
        if let data = memoryCache.object(forKey: key as NSString) as? Data {
            return data
        }
        // If not in memory, try load from disk synchronously
        if let data = loadFromDisk(key: key) {
            memoryCache.setObject(data as NSData, forKey: key as NSString, cost: data.count)
            return data
        }
        return nil
    }
    
    // Async version for background disk reads
    func getImageDataAsync(forKey key: String, completion: @escaping (Data?) -> Void) {
        if let data = memoryCache.object(forKey: key as NSString) as? Data {
            completion(data)
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                completion(nil)
                return
            }
            let data = self.loadFromDisk(key: key)
            if let data = data {
                self.memoryCache.setObject(data as NSData, forKey: key as NSString, cost: data.count)
            }
            DispatchQueue.main.async {
                completion(data)
            }
        }
    }
    
    func removeObject(forKey key: String) {
        memoryCache.removeObject(forKey: key as NSString)
        removeFromDisk(key: key)
    }
    
    func clearAll() {
        memoryCache.removeAllObjects()
        try? FileManager.default.removeItem(at: diskCacheURL)
    }
    
    // MARK: - Cache Info
    
    func calculateCacheSize() -> String {
        guard let urls = try? FileManager.default.contentsOfDirectory(at: diskCacheURL, includingPropertiesForKeys: [.totalFileAllocatedSizeKey], options: .skipsHiddenFiles) else {
            return "0 MB"
        }
        
        var size: Int64 = 0
        for url in urls {
            if let resourceValues = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey]),
               let allocatedSize = resourceValues.totalFileAllocatedSize {
                size += Int64(allocatedSize)
            }
        }
        
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    func clearCache(completion: @escaping () -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            self.clearAll()
            DispatchQueue.main.async {
                completion()
            }
        }
    }
    
    // MARK: - Disk Operations
    
    private func saveToDisk(data: Data, key: String, ttl: TimeInterval?) {
        let fileURL = diskCacheURL.appendingPathComponent(key.cacheFileName)
        do {
            try data.write(to: fileURL)
            
            // Calculate expiration date
            let expirationDate = Date().addingTimeInterval(ttl ?? defaultExpiration)
            
            // Save attributes: Modification Date (for LRU) and Expiration Date
            let attributes: [FileAttributeKey: Any] = [
                .modificationDate: Date(),
                .creationDate: expirationDate // We abuse creationDate to store expiration to avoid sidecar files
            ]
            try FileManager.default.setAttributes(attributes, ofItemAtPath: fileURL.path)
        } catch {
            print("Disk Cache Save Error: \(error)")
        }
    }
    
    private func loadFromDisk(key: String) -> Data? {
        let fileURL = diskCacheURL.appendingPathComponent(key.cacheFileName)
        
        // Check existence and expiration
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        
        if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path) {
            // Check Expiration (stored in creationDate)
            if let expirationDate = attributes[.creationDate] as? Date {
                if Date() > expirationDate {
                    try? FileManager.default.removeItem(at: fileURL)
                    return nil
                }
            }
        }
        
        if let data = try? Data(contentsOf: fileURL) {
            // Update modification date to mark as recently used (LRU)
            // Don't touch creationDate (expiration)
            try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: fileURL.path)
            return data
        }
        return nil
    }
    
    private func removeFromDisk(key: String) {
        let fileURL = diskCacheURL.appendingPathComponent(key.cacheFileName)
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    private func cleanExpiredDiskCache() {
        DispatchQueue.global(qos: .utility).async {
            guard let fileURLs = try? FileManager.default.contentsOfDirectory(at: self.diskCacheURL, includingPropertiesForKeys: [.contentModificationDateKey, .totalFileAllocatedSizeKey], options: .skipsHiddenFiles) else { return }
            
            var files = [(url: URL, date: Date, size: Int)]()
            var totalSize = 0
            
            for url in fileURLs {
                if let resourceValues = try? url.resourceValues(forKeys: [.contentModificationDateKey, .totalFileAllocatedSizeKey]),
                   let date = resourceValues.contentModificationDate,
                   let size = resourceValues.totalFileAllocatedSize {
                    
                    // Remove expired immediately
                    // Check creationDate for expiration
                    if let expirationDate = resourceValues.creationDate {
                        if Date() > expirationDate {
                             try? FileManager.default.removeItem(at: url)
                             continue
                        }
                    }
                    // Fallback to old expiration interval check if creationDate is not set correctly or for legacy files
                    else if Date().timeIntervalSince(date) > self.defaultExpiration {
                        try? FileManager.default.removeItem(at: url)
                        continue
                    }
                    
                    files.append((url, date, size))
                    totalSize += size
                }
            }
            
            // If over limit, remove oldest files
            if totalSize > self.diskLimit {
                files.sort { $0.date < $1.date } // Oldest first
                
                for file in files {
                    if totalSize <= self.diskLimit { break }
                    try? FileManager.default.removeItem(at: file.url)
                    totalSize -= file.size
                }
            }
        }
    }
}

// Helper for Key Hashing - 使用 SHA256 替代不安全的 MD5
import CryptoKit

extension String {
    /// 生成安全的缓存文件名（使用 SHA256）
    var cacheFileName: String {
        let digest = SHA256.hash(data: self.data(using: .utf8) ?? Data())
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
    
    /// 保留 MD5 用于向后兼容（标记为废弃）
    @available(*, deprecated, message: "Use cacheFileName (SHA256) instead")
    var md5: String {
        let digest = Insecure.MD5.hash(data: self.data(using: .utf8) ?? Data())
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}
