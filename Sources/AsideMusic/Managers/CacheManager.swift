import Foundation
import Combine

class CacheManager {
    static let shared = CacheManager()
    
    private let memoryCache = NSCache<NSString, AnyObject>()
    
    private var diskCacheURL: URL {
        let urls = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        let cacheDirectory = urls[0].appendingPathComponent("AsideMusicCache")
        
        if !FileManager.default.fileExists(atPath: cacheDirectory.path) {
            try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true, attributes: nil)
        }
        
        return cacheDirectory
    }
    
    private let memoryLimit = AppConfig.Cache.memoryLimit
    private let diskLimit = AppConfig.Cache.diskLimit
    private let defaultExpiration: TimeInterval = AppConfig.Cache.defaultTTL
    
    init() {
        memoryCache.totalCostLimit = memoryLimit
        memoryCache.countLimit = 100
        DispatchQueue.global(qos: .utility).async {
            self.cleanExpiredDiskCache()
        }
    }
    
    // MARK: - 通用数据缓存
    
    func setObject<T: Codable>(_ object: T, forKey key: String, ttl: TimeInterval? = nil) {
        if let encoded = try? JSONEncoder().encode(object) {
            memoryCache.setObject(encoded as NSData, forKey: key as NSString, cost: encoded.count)
            
            DispatchQueue.global(qos: .background).async {
                self.saveToDisk(data: encoded, key: key, ttl: ttl)
            }
        }
    }
    
    func getObject<T: Codable>(forKey key: String, type: T.Type) -> T? {
        if let data = memoryCache.object(forKey: key as NSString) as? Data {
            if let object = try? JSONDecoder().decode(T.self, from: data) {
                return object
            }
        }
        
        if let data = loadFromDisk(key: key) {
            memoryCache.setObject(data as NSData, forKey: key as NSString, cost: data.count)
            
            if let object = try? JSONDecoder().decode(T.self, from: data) {
                return object
            }
        }
        
        return nil
    }
    
    /// 获取原始数据（用于预热缓存）
    func getData(forKey key: String) -> Data? {
        if let data = memoryCache.object(forKey: key as NSString) as? Data {
            return data
        }
        
        if let data = loadFromDisk(key: key) {
            memoryCache.setObject(data as NSData, forKey: key as NSString, cost: data.count)
            return data
        }
        
        return nil
    }
    
    // MARK: - 图片缓存
    
    func setImageData(_ data: Data, forKey key: String) {
        memoryCache.setObject(data as NSData, forKey: key as NSString, cost: data.count)
        DispatchQueue.global(qos: .background).async {
            self.saveToDisk(data: data, key: key, ttl: nil)
        }
    }
    
    func getImageData(forKey key: String) -> Data? {
        if let data = memoryCache.object(forKey: key as NSString) as? Data {
            return data
        }
        if let data = loadFromDisk(key: key) {
            memoryCache.setObject(data as NSData, forKey: key as NSString, cost: data.count)
            return data
        }
        return nil
    }
    
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
    
    // MARK: - 缓存信息
    
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
    
    // MARK: - 磁盘操作
    
    private func saveToDisk(data: Data, key: String, ttl: TimeInterval?) {
        let fileURL = diskCacheURL.appendingPathComponent(key.cacheFileName)
        do {
            try data.write(to: fileURL)
            
            let expirationDate = Date().addingTimeInterval(ttl ?? defaultExpiration)
            let attributes: [FileAttributeKey: Any] = [
                .modificationDate: Date(),
                .creationDate: expirationDate
            ]
            try FileManager.default.setAttributes(attributes, ofItemAtPath: fileURL.path)
        } catch {
            AppLogger.error("磁盘缓存写入失败: \(error)")
        }
    }
    
    private func loadFromDisk(key: String) -> Data? {
        let fileURL = diskCacheURL.appendingPathComponent(key.cacheFileName)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        
        if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path) {
            if let expirationDate = attributes[.creationDate] as? Date {
                if Date() > expirationDate {
                    try? FileManager.default.removeItem(at: fileURL)
                    return nil
                }
            }
        }
        
        if let data = try? Data(contentsOf: fileURL) {
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
                    
                    if let expirationDate = resourceValues.creationDate {
                        if Date() > expirationDate {
                             try? FileManager.default.removeItem(at: url)
                             continue
                        }
                    } else if Date().timeIntervalSince(date) > self.defaultExpiration {
                        try? FileManager.default.removeItem(at: url)
                        continue
                    }
                    
                    files.append((url, date, size))
                    totalSize += size
                }
            }
            
            if totalSize > self.diskLimit {
                files.sort { $0.date < $1.date }
                
                for file in files {
                    if totalSize <= self.diskLimit { break }
                    try? FileManager.default.removeItem(at: file.url)
                    totalSize -= file.size
                }
            }
        }
    }
}

// MARK: - 缓存文件名哈希
import CryptoKit

extension String {
    /// 生成安全的缓存文件名（使用 SHA256）
    var cacheFileName: String {
        let digest = SHA256.hash(data: self.data(using: .utf8) ?? Data())
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
    
    @available(*, deprecated, message: "Use cacheFileName (SHA256) instead")
    var md5: String {
        let digest = Insecure.MD5.hash(data: self.data(using: .utf8) ?? Data())
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}
