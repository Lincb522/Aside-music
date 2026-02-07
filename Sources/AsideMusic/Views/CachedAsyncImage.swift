import SwiftUI
import Combine

// MARK: - 图片缓存配置
private struct ImageCacheConfig {
    static let maxMemoryCost = 30 * 1024 * 1024  // 30MB 内存限制
    static let maxCount = 100                     // 最多缓存 100 张图片
    static let maxConcurrentLoads = 4             // 最大并发加载数
}

// MARK: - 图片内存缓存
private let imageCache: NSCache<NSString, UIImage> = {
    let cache = NSCache<NSString, UIImage>()
    cache.totalCostLimit = ImageCacheConfig.maxMemoryCost
    cache.countLimit = ImageCacheConfig.maxCount
    return cache
}()

// MARK: - 图片加载并发控制
private let imageConcurrencyQueue = DispatchQueue(label: "com.aside.imageLoader", qos: .userInitiated, attributes: .concurrent)
private let imageSemaphore = DispatchSemaphore(value: ImageCacheConfig.maxConcurrentLoads)

class ImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var isLoading = false
    
    private var cancellable: AnyCancellable?
    private var currentUrl: URL?
    private var loadingTask: DispatchWorkItem?
    
    deinit {
        cancel()
    }
    
    func load(url: URL) {
        let cacheKey = url.absoluteString as NSString
        if let cachedImage = imageCache.object(forKey: cacheKey) {
            self.image = cachedImage
            self.isLoading = false
            return
        }
        
        if url == currentUrl && (image != nil || isLoading) { return }
        
        cancel()
        currentUrl = url
        isLoading = true
        image = nil
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            imageSemaphore.wait()
            defer { imageSemaphore.signal() }
            
            if self.loadingTask?.isCancelled == true { return }
            
            if let cachedImage = imageCache.object(forKey: cacheKey) {
                DispatchQueue.main.async {
                    if self.currentUrl == url {
                        self.image = cachedImage
                        self.isLoading = false
                    }
                }
                return
            }
            
            if let data = CacheManager.shared.getImageData(forKey: url.absoluteString),
               let cachedImage = self.downsampleImage(data: data, maxSize: 300) {
                
                // 计算图片内存成本
                let cost = cachedImage.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
                imageCache.setObject(cachedImage, forKey: cacheKey, cost: cost)
                
                DispatchQueue.main.async {
                    if self.currentUrl == url {
                        self.image = cachedImage
                        self.isLoading = false
                    }
                }
                return
            }
            
            DispatchQueue.main.async {
                if self.currentUrl != url { return }
                
                self.cancellable = URLSession.shared.dataTaskPublisher(for: url)
                    .map { [weak self] output -> UIImage? in
                        // 在后台线程进行图片解码和降采样
                        return self?.downsampleImage(data: output.data, maxSize: 300)
                    }
                    .replaceError(with: nil)
                    .receive(on: DispatchQueue.main)
                    .sink { [weak self] downloadedImage in
                        guard let self = self, self.currentUrl == url else { return }
                        self.isLoading = false
                        
                        if let image = downloadedImage {
                            self.image = image
                            
                            // 计算内存成本
                            let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
                            imageCache.setObject(image, forKey: cacheKey, cost: cost)
                            
                            // 异步保存到磁盘（使用压缩后的数据）
                            if let data = image.jpegData(compressionQuality: 0.7) {
                                DispatchQueue.global(qos: .background).async {
                                    CacheManager.shared.setImageData(data, forKey: url.absoluteString)
                                }
                            }
                        }
                    }
            }
        }
        
        loadingTask = workItem
        imageConcurrencyQueue.async(execute: workItem)
    }
    
    /// 图片降采样 - 减少内存占用
    private func downsampleImage(data: Data, maxSize: CGFloat) -> UIImage? {
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, imageSourceOptions) else {
            return UIImage(data: data)
        }
        
        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxSize * UIScreen.main.scale
        ] as CFDictionary
        
        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions) else {
            return UIImage(data: data)
        }
        
        return UIImage(cgImage: downsampledImage)
    }
    
    func cancel() {
        loadingTask?.cancel()
        loadingTask = nil
        cancellable?.cancel()
        cancellable = nil
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
            .onChange(of: url) { newUrl in
                if let newUrl = newUrl {
                    loader.load(url: newUrl)
                }
            }
            .onDisappear {
                // 视图消失时取消加载
                loader.cancel()
            }
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

