import SwiftUI
import Combine

// MARK: - 图片缓存配置
private struct ImageCacheConfig {
    static let maxMemoryCost = 80 * 1024 * 1024   // 80MB 内存限制
    static let maxCount = 300                      // 最多缓存 300 张图片
    static let maxConcurrentLoads = 8              // 最大并发加载数
}

// MARK: - 图片内存缓存
private let imageCache: NSCache<NSString, UIImage> = {
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
        memoryCapacity: 20 * 1024 * 1024,   // 20MB 内存
        diskCapacity: 100 * 1024 * 1024,     // 100MB 磁盘
        diskPath: "aside_image_cache"
    )
    return URLSession(configuration: config)
}()

// MARK: - 图片加载去重管理器
private actor ImageLoadCoordinator {
    static let shared = ImageLoadCoordinator()
    
    private var inFlightTasks: [String: Task<UIImage?, Never>] = [:]
    
    func loadImage(url: URL) async -> UIImage? {
        let key = url.absoluteString
        
        // 如果已有相同 URL 的加载任务，直接复用
        if let existingTask = inFlightTasks[key] {
            return await existingTask.value
        }
        
        let task = Task<UIImage?, Never> {
            defer { inFlightTasks.removeValue(forKey: key) }
            
            do {
                let (data, _) = try await imageSession.data(from: url)
                return downsampleImage(data: data, maxSize: 300)
            } catch {
                return nil
            }
        }
        
        inFlightTasks[key] = task
        return await task.value
    }
    
    /// 图片降采样 - 减少内存占用
    private func downsampleImage(data: Data, maxSize: CGFloat) -> UIImage? {
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, imageSourceOptions) else {
            return UIImage(data: data)
        }
        
        // 使用固定 scale 3.0 避免在非主线程访问 UIScreen
        let scale: CGFloat = 3.0
        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxSize * scale
        ] as CFDictionary
        
        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions) else {
            return UIImage(data: data)
        }
        
        return UIImage(cgImage: downsampledImage)
    }
}


class ImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var isLoading = false
    
    private var loadTask: Task<Void, Never>?
    private var currentUrl: URL?
    
    deinit {
        loadTask?.cancel()
    }
    
    func load(url: URL) {
        let cacheKey = url.absoluteString as NSString
        
        // 1. 内存缓存命中 → 立即返回
        if let cachedImage = imageCache.object(forKey: cacheKey) {
            self.image = cachedImage
            self.isLoading = false
            return
        }
        
        // 避免重复加载同一 URL
        if url == currentUrl && (image != nil || isLoading) { return }
        
        cancel()
        currentUrl = url
        isLoading = true
        
        loadTask = Task { [weak self] in
            guard let self = self else { return }
            
            // 2. 磁盘缓存命中
            if let data = CacheManager.shared.getImageData(forKey: url.absoluteString) {
                let diskImage = await Task.detached(priority: .userInitiated) {
                    return self.downsampleImage(data: data, maxSize: 300)
                }.value
                
                if Task.isCancelled { return }
                
                if let diskImage = diskImage {
                    let cost = diskImage.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
                    imageCache.setObject(diskImage, forKey: cacheKey, cost: cost)
                    
                    await MainActor.run {
                        guard self.currentUrl == url else { return }
                        self.image = diskImage
                        self.isLoading = false
                    }
                    return
                }
            }
            
            if Task.isCancelled { return }
            
            // 3. 网络加载（通过 coordinator 去重）
            let downloadedImage = await ImageLoadCoordinator.shared.loadImage(url: url)
            
            if Task.isCancelled { return }
            
            await MainActor.run {
                guard self.currentUrl == url else { return }
                self.isLoading = false
                
                if let image = downloadedImage {
                    self.image = image
                    
                    let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
                    imageCache.setObject(image, forKey: cacheKey, cost: cost)
                    
                    // 异步保存到磁盘
                    Task.detached(priority: .background) {
                        if let data = image.jpegData(compressionQuality: 0.7) {
                            CacheManager.shared.setImageData(data, forKey: url.absoluteString)
                        }
                    }
                }
            }
        }
    }
    
    /// 图片降采样 - 减少内存占用
    private func downsampleImage(data: Data, maxSize: CGFloat) -> UIImage? {
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, imageSourceOptions) else {
            return UIImage(data: data)
        }
        
        let scale = UIScreen.main.scale
        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxSize * scale
        ] as CFDictionary
        
        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions) else {
            return UIImage(data: data)
        }
        
        return UIImage(cgImage: downsampledImage)
    }
    
    func cancel() {
        loadTask?.cancel()
        loadTask = nil
        isLoading = false
    }
}

struct CachedAsyncImage<Placeholder: View>: View {
    @StateObject private var loader = ImageLoader()
    private let url: URL?
    private let placeholder: Placeholder
    private let transition: AnyTransition
    private let contentMode: SwiftUI.ContentMode
    
    init(
        url: URL?,
        @ViewBuilder placeholder: () -> Placeholder,
        transition: AnyTransition = .opacity.animation(.easeIn(duration: 0.2)),
        contentMode: SwiftUI.ContentMode = .fill,
        width: CGFloat? = nil,
        height: CGFloat? = nil
    ) {
        self.url = url
        self.placeholder = placeholder()
        self.transition = transition
        self.contentMode = contentMode
    }
    
    var body: some View {
        content
            .onAppear {
                if let url = url {
                    loader.load(url: url)
                }
            }
            .onChange(of: url) { _, newUrl in
                if let newUrl = newUrl {
                    loader.load(url: newUrl)
                }
            }
            // 不在 onDisappear 取消加载，避免滚动时反复重新请求
    }
    
    @ViewBuilder
    private var content: some View {
        if let image = loader.image {
            Image(uiImage: image)
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
