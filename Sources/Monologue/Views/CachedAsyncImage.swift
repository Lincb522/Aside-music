import SwiftUI
import Combine

// MARK: - 图片缓存配置
private struct ImageCacheConfig {
    static let maxMemoryCost = 80 * 1024 * 1024   // 80MB 内存限制
    static let maxCount = 150                      // 最多缓存 150 张图片
    static let maxConcurrentLoads = 6              // 最大并发加载数
    static let screenScale: CGFloat = 3.0          // 现代 iPhone 均为 3x Retina
    static let defaultMaxPointSize: CGFloat = 400

    static func normalizedMaxPointSize(width: CGFloat?, height: CGFloat?) -> CGFloat {
        guard let requested = [width, height].compactMap({ $0 }).filter({ $0 > 0 }).max() else {
            return defaultMaxPointSize
        }
        return normalizedMaxPointSize(requested + 8)
    }

    static func normalizedMaxPointSize(_ requested: CGFloat) -> CGFloat {
        let bucket = ceil(max(requested, 1) / 16) * 16
        return min(max(bucket, 48), defaultMaxPointSize)
    }

    static func cacheKey(for url: URL, maxSize: CGFloat) -> String {
        "\(url.absoluteString)#decode:\(Int(normalizedMaxPointSize(maxSize)))"
    }
}

// MARK: - 图片内存缓存
private nonisolated(unsafe) let imageCache: NSCache<NSString, UIImage> = {
    let cache = NSCache<NSString, UIImage>()
    cache.totalCostLimit = ImageCacheConfig.maxMemoryCost
    cache.countLimit = ImageCacheConfig.maxCount
    return cache
}()

// MARK: - 共享 URLSession（带并发限制）
private let imageSession: URLSession = {
    let config = URLSessionConfiguration.default
    config.httpMaximumConnectionsPerHost = ImageCacheConfig.maxConcurrentLoads
    config.timeoutIntervalForRequest = 15
    config.urlCache = URLCache(
        memoryCapacity: 10 * 1024 * 1024,   // 10MB 内存（降低以减少内存压力）
        diskCapacity: 100 * 1024 * 1024,     // 100MB 磁盘
        diskPath: "zijiu.Monologue.com.url_image_cache"
    )
    return URLSession(configuration: config)
}()

// MARK: - 图片加载去重管理器
actor ImageLoadCoordinator {
    static let shared = ImageLoadCoordinator()
    
    private var inFlightTasks: [String: Task<UIImage?, Never>] = [:]
    
    func loadImage(url: URL, maxSize: CGFloat = ImageCacheConfig.defaultMaxPointSize) async -> UIImage? {
        let normalizedMaxSize = ImageCacheConfig.normalizedMaxPointSize(maxSize)
        let key = ImageCacheConfig.cacheKey(for: url, maxSize: normalizedMaxSize)
        
        // 如果已有相同 URL 的加载任务，直接复用
        if let existingTask = inFlightTasks[key] {
            return await existingTask.value
        }
        
        let task = Task<UIImage?, Never> {
            defer { inFlightTasks.removeValue(forKey: key) }
            
            do {
                let (data, response) = try await imageSession.data(from: url)
                if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    return nil
                }
                return downsampleImage(data: data, maxSize: normalizedMaxSize)
            } catch {
                return nil
            }
        }
        
        inFlightTasks[key] = task
        return await task.value
    }
    
    private func downsampleImage(data: Data, maxSize: CGFloat) -> UIImage? {
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, imageSourceOptions),
              CGImageSourceGetType(imageSource) != nil,
              CGImageSourceGetCount(imageSource) > 0 else {
            return UIImage(data: data)
        }
        
        let maxPixelSize = maxSize * ImageCacheConfig.screenScale
        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        
        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions as CFDictionary) else {
            return UIImage(data: data)
        }
        
        return UIImage(cgImage: downsampledImage)
    }
}


@MainActor
class ImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var isLoading = false
    
    private var loadTask: Task<Void, Never>?
    private var currentUrl: URL?
    private var currentRequestKey: String?
    
    deinit {
        loadTask?.cancel()
    }
    
    func load(url: URL, maxSize: CGFloat = ImageCacheConfig.defaultMaxPointSize) {
        let normalizedMaxSize = ImageCacheConfig.normalizedMaxPointSize(maxSize)
        let cacheKeyStr = ImageCacheConfig.cacheKey(for: url, maxSize: normalizedMaxSize)
        let cacheKey = cacheKeyStr as NSString
        let legacyCacheKey = url.absoluteString as NSString
        
        // 1. 内存缓存命中 → 立即返回
        if let cachedImage = imageCache.object(forKey: cacheKey)
            ?? (normalizedMaxSize >= ImageCacheConfig.defaultMaxPointSize ? imageCache.object(forKey: legacyCacheKey) : nil) {
            self.image = cachedImage
            self.isLoading = false
            self.currentUrl = url
            self.currentRequestKey = cacheKeyStr
            return
        }
        
        // 避免重复加载同一 URL
        if cacheKeyStr == currentRequestKey && (image != nil || isLoading) { return }
        
        cancel()
        currentUrl = url
        currentRequestKey = cacheKeyStr
        isLoading = true
        
        loadTask = Task { [weak self] in
            guard let self = self else { return }
            
            let key = cacheKeyStr
            let legacyKey = url.absoluteString
            
            // 2. 磁盘缓存命中（在后台线程读取和降采样）
            let diskImage: UIImage? = await Task.detached(priority: .userInitiated) {
                guard let data = CacheManager.shared.getImageData(forKey: key)
                    ?? CacheManager.shared.getImageData(forKey: legacyKey) else { return nil }
                return Self.downsampleImageStatic(data: data, maxSize: normalizedMaxSize)
            }.value
            
            if Task.isCancelled { return }
            
            if let diskImage {
                let cost = diskImage.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
                imageCache.setObject(diskImage, forKey: key as NSString, cost: cost)
                
                guard self.currentRequestKey == key else { return }
                self.image = diskImage
                self.isLoading = false
                return
            }
            
            if Task.isCancelled { return }
            
            // 3. 网络加载（通过 coordinator 去重）
            let downloadedImage = await ImageLoadCoordinator.shared.loadImage(url: url, maxSize: normalizedMaxSize)
            
            if Task.isCancelled { return }
            
            guard self.currentRequestKey == key else { return }
            self.isLoading = false
            
            if let image = downloadedImage {
                self.image = image
                
                let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
                imageCache.setObject(image, forKey: key as NSString, cost: cost)
                
                let jpegData = image.jpegData(compressionQuality: 0.85)
                if let jpegData {
                    Task.detached(priority: .background) {
                        CacheManager.shared.setImageData(jpegData, forKey: key)
                    }
                }
            }
        }
    }
    
    nonisolated static func downsampleImageStatic(data: Data, maxSize: CGFloat) -> UIImage? {
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, imageSourceOptions),
              CGImageSourceGetType(imageSource) != nil,
              CGImageSourceGetCount(imageSource) > 0 else {
            return UIImage(data: data)
        }
        
        let maxPixelSize = maxSize * ImageCacheConfig.screenScale
        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        
        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions as CFDictionary) else {
            return UIImage(data: data)
        }
        
        return UIImage(cgImage: downsampledImage)
    }
    
    func cancel() {
        loadTask?.cancel()
        loadTask = nil
        isLoading = false
    }
    
    /// 仅在还在加载中时取消（已加载完成的图片保留）
    func cancelIfLoading() {
        guard isLoading else { return }
        cancel()
    }
}

struct CachedAsyncImage<Placeholder: View>: View {
    @StateObject private var loader = ImageLoader()
    private let url: URL?
    private let placeholder: Placeholder
    private let transition: AnyTransition
    private let contentMode: SwiftUI.ContentMode
    private let maxDecodeSize: CGFloat
    
    init(
        url: URL?,
        @ViewBuilder placeholder: () -> Placeholder,
        transition: AnyTransition = .opacity.animation(.easeIn(duration: 0.2)),
        contentMode: SwiftUI.ContentMode = .fill,
        width: CGFloat? = nil,
        height: CGFloat? = nil
    ) {
        if let url, url.scheme == "http",
           var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            components.scheme = "https"
            self.url = components.url ?? url
        } else {
            self.url = url
        }
        self.placeholder = placeholder()
        self.transition = transition
        self.contentMode = contentMode
        self.maxDecodeSize = ImageCacheConfig.normalizedMaxPointSize(width: width, height: height)
    }

    init(
        url: URL?,
        width: CGFloat?,
        height: CGFloat?,
        @ViewBuilder placeholder: () -> Placeholder,
        transition: AnyTransition = .opacity.animation(.easeIn(duration: 0.2)),
        contentMode: SwiftUI.ContentMode = .fill
    ) {
        self.init(
            url: url,
            placeholder: placeholder,
            transition: transition,
            contentMode: contentMode,
            width: width,
            height: height
        )
    }
    
    var body: some View {
        content
            .onAppear {
                ImageMemoryWarningObserver.shared.registerIfNeeded()
                if let url = url {
                    loader.load(url: url, maxSize: maxDecodeSize)
                }
            }
            .onChange(of: url) { _, newUrl in
                if let newUrl = newUrl {
                    loader.load(url: newUrl, maxSize: maxDecodeSize)
                }
            }
            .onDisappear {
                // 视图离屏时取消正在进行的加载（已加载完成的不受影响）
                loader.cancelIfLoading()
            }
    }
    
    @ViewBuilder
    private var content: some View {
        // 优先使用 loader 已加载的图片；若 loader 尚未触发（onAppear 还没执行），
        // 则直接内联查询内存缓存，避免首帧显示 placeholder 导致封面"闪白"。
        // 两个来源合并到同一个 if 分支，防止 loader 加载后分支切换触发 transition 动画。
        let resolvedImage: UIImage? = loader.image
            ?? (url.flatMap { imageCache.object(forKey: ImageCacheConfig.cacheKey(for: $0, maxSize: maxDecodeSize) as NSString) })
            ?? (maxDecodeSize >= ImageCacheConfig.defaultMaxPointSize ? url.flatMap { imageCache.object(forKey: $0.absoluteString as NSString) } : nil)

        if let resolvedImage {
            Image(uiImage: resolvedImage)
                .resizable()
                .aspectRatio(contentMode: contentMode)
                .transition(transition)
        } else {
            placeholder
        }
    }
}

// MARK: - 全局图片缓存清理
extension CachedAsyncImage {
    /// 清理图片内存缓存
    static func clearMemoryCache() {
        imageCache.removeAllObjects()
    }
}

// MARK: - 内存警告监听器（App 级别注册一次）
final class ImageMemoryWarningObserver: @unchecked Sendable {
    static let shared = ImageMemoryWarningObserver()
    private var registered = false
    
    func registerIfNeeded() {
        guard !registered else { return }
        registered = true
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil, queue: .main
        ) { _ in
            imageCache.removeAllObjects()
            imageSession.configuration.urlCache?.removeAllCachedResponses()
        }
    }
}
