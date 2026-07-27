import SwiftUI
import Combine

// MARK: - 图片缓存配置
private struct ImageCacheConfig {
    static let schemaVersion = 4
    static let maxMemoryCost = 80 * 1024 * 1024   // 80MB 内存限制
    static let maxCount = 700                      // 歌单长列表需要保留更多缩略图，最终仍受内存成本限制
    static let maxConcurrentLoads = 6              // 最大并发加载数
    static let screenScale: CGFloat = 3.0          // 现代 iPhone 均为 3x Retina
    static let defaultMaxPointSize: CGFloat = 400
    static let maximumMaxPointSize: CGFloat = 768

    static func normalizedMaxPointSize(width: CGFloat?, height: CGFloat?) -> CGFloat {
        guard let requested = [width, height].compactMap({ $0 }).filter({ $0 > 0 }).max() else {
            return defaultMaxPointSize
        }
        return normalizedMaxPointSize(requested + 8)
    }

    static func normalizedMaxPointSize(_ requested: CGFloat) -> CGFloat {
        let bucket = ceil(max(requested, 1) / 16) * 16
        return min(max(bucket, 48), maximumMaxPointSize)
    }

    static func cacheKey(for url: URL, maxSize: CGFloat) -> String {
        "artwork-v\(schemaVersion):\(url.absoluteString)#decode:\(Int(normalizedMaxPointSize(maxSize)))"
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
        diskPath: "zijiu.Mono.com.url_image_cache"
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

            if let image = await requestImage(url: url, maxSize: normalizedMaxSize) {
                return image
            }

            // 同一资源先尝试 CDN 的等价地址。网易云图片签名可跨 p1-p4，
            // QQ 专辑图则可能只保留部分固定尺寸。
            for candidate in directCDNFallbackCandidates(for: url) where !Task.isCancelled {
                if let image = await requestImage(url: candidate, maxSize: normalizedMaxSize) {
                    AppLogger.info(
                        "[Artwork] CDN 地址回退成功 primary=\(url.host ?? "unknown") fallback=\(candidate.host ?? "unknown")",
                        step: "artwork.cdn-fallback"
                    )
                    return image
                }
            }

            // 搜索的三个平台会并行返回。主封面先失败时短暂等待其余平台完成注册，
            // 再使用同名同歌手的其他专辑版本或平台封面回退。
            var fallbacks = SongArtworkFallbackRegistry.shared.fallbackCandidates(for: url)
            if fallbacks.isEmpty, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 320_000_000)
                fallbacks = SongArtworkFallbackRegistry.shared.fallbackCandidates(for: url)
            }

            let requestedPixels = Int(ceil(normalizedMaxSize * ImageCacheConfig.screenScale))
            for candidate in fallbacks.prefix(5) where !Task.isCancelled {
                let fallbackURL = candidate.artworkURL(atLeastPixelSize: requestedPixels)
                if let image = await requestImage(url: fallbackURL, maxSize: normalizedMaxSize) {
                    AppLogger.info(
                        "[Artwork] 同曲封面回退成功 primary=\(url.host ?? "unknown") fallback=\(fallbackURL.host ?? "unknown")",
                        step: "artwork.song-fallback"
                    )
                    return image
                }
            }

            AppLogger.debug(
                "[Artwork] 封面加载失败 url=\(url.absoluteString)",
                step: "artwork.failed"
            )
            return nil
        }
        
        inFlightTasks[key] = task
        return await task.value
    }

    private func requestImage(url: URL, maxSize: CGFloat) async -> UIImage? {
        do {
            if url.isFileURL {
                let data = try Data(contentsOf: url)
                return downsampleImage(data: data, maxSize: maxSize)
            }

            let (data, response) = try await imageSession.data(from: url)
            if let http = response as? HTTPURLResponse,
               !(200...299).contains(http.statusCode) {
                AppLogger.debug(
                    "[Artwork] CDN 响应异常 status=\(http.statusCode) host=\(url.host ?? "unknown") path=\(url.lastPathComponent)",
                    step: "artwork.http"
                )
                return nil
            }

            guard !data.isEmpty else {
                AppLogger.debug(
                    "[Artwork] CDN 返回空数据 host=\(url.host ?? "unknown")",
                    step: "artwork.empty-data"
                )
                return nil
            }
            guard let image = downsampleImage(data: data, maxSize: maxSize) else {
                AppLogger.debug(
                    "[Artwork] 返回内容不是有效图片 host=\(url.host ?? "unknown") bytes=\(data.count)",
                    step: "artwork.decode"
                )
                return nil
            }
            return image
        } catch is CancellationError {
            return nil
        } catch {
            AppLogger.debug(
                "[Artwork] 请求失败 host=\(url.host ?? "unknown") error=\(error.localizedDescription)",
                step: "artwork.request"
            )
            return nil
        }
    }

    private func directCDNFallbackCandidates(for url: URL) -> [URL] {
        var candidates: [URL] = []
        var seen = Set([url.absoluteString])

        func append(_ candidate: URL?) {
            guard let candidate, seen.insert(candidate.absoluteString).inserted else { return }
            candidates.append(candidate)
        }

        let host = url.host?.lowercased() ?? ""
        if host.range(of: #"^p[1-4]\.music\.126\.net$"#, options: .regularExpression) != nil {
            for index in 1...4 {
                guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { continue }
                components.host = "p\(index).music.126.net"
                components.scheme = "https"
                append(components.url)
            }

            if var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                components.queryItems = components.queryItems?.filter { $0.name != "param" }
                append(components.url)
            }
        }

        if host == "y.gtimg.cn" {
            let value = url.absoluteString
            if url.lastPathComponent.hasPrefix("T015R") {
                let filename = url.deletingPathExtension().lastPathComponent
                if let marker = filename.range(of: "M101") {
                    let vid = String(filename[marker.upperBound...])
                    if !vid.isEmpty {
                        append(URL(string: "https://shp.qpic.cn/qqvideo_ori/0/\(vid)_496_280/0"))
                    }
                }
            } else if let range = value.range(of: #"R\d+x\d+"#, options: .regularExpression) {
                for size in [500, 300, 180] {
                    append(URL(string: value.replacingCharacters(in: range, with: "R\(size)x\(size)")))
                }
            }
        }

        return candidates
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
        
        // 1. 内存缓存命中 → 立即返回
        if let cachedImage = imageCache.object(forKey: cacheKey) {
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
            
            // 2. 磁盘缓存命中（在后台线程读取和降采样）
            let diskImage: UIImage? = await Task.detached(priority: .userInitiated) {
                guard let data = CacheManager.shared.getImageData(forKey: key) else { return nil }
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
                
                let jpegData = image.jpegData(compressionQuality: 0.92)
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
        let normalizedMaxSize = ImageCacheConfig.normalizedMaxPointSize(width: width, height: height)
        let minimumPixelSize = Int(ceil(normalizedMaxSize * ImageCacheConfig.screenScale))

        var requestURL = url
        if let url, url.absoluteString.hasPrefix("//") {
            requestURL = URL(string: "https:\(url.absoluteString)")
        }
        if let requestURL, requestURL.scheme == "http",
           var components = URLComponents(url: requestURL, resolvingAgainstBaseURL: false) {
            components.scheme = "https"
            self.url = (components.url ?? requestURL).artworkURL(atLeastPixelSize: minimumPixelSize)
        } else if let requestURL {
            self.url = requestURL.artworkURL(atLeastPixelSize: minimumPixelSize)
        } else {
            self.url = nil
        }
        self.placeholder = placeholder()
        self.transition = transition
        self.contentMode = contentMode
        self.maxDecodeSize = normalizedMaxSize
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
