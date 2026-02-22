import UIKit
import SwiftUI
import Metal
import MetalKit
import MetalPerformanceShaders

/// 背景快照刷新模式
public enum SnapshotUpdateMode: Sendable {
    /// 按固定间隔持续刷新（默认 ~20fps）
    case continuous(interval: TimeInterval = 1.0 / 20.0)
    /// 只截取一次，之后复用
    case once
    /// 手动调用 `invalidate()` 时才刷新
    case manual
}

@MainActor
public final class BackgroundTextureProvider {
    
    // MARK: - 配置
    
    public var updateMode: SnapshotUpdateMode = .continuous() {
        didSet { scheduleUpdateLoop() }
    }
    
    public var blurRadius: Float = 0 {
        didSet {
            guard abs(oldValue - blurRadius) > 0.5 else { return }
            invalidate()
        }
    }
    
    public var didUpdateTexture: (() -> Void)?
    
    // MARK: - 依赖
    
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let capturer = HierarchySnapshotCapturer()
    
    // MARK: - 状态
    
    private weak var targetView: UIView?
    private var backdropView = BackdropView()
    private var displayLink: CADisplayLink?
    private var isCapturing = false
    private var frameInterval: Int = 3 // 默认 ~20fps (60/3)
    private var frameCounter = 0
    
    private var sourceTexture: MTLTexture?
    private var blurredTexture: MTLTexture?
    private var lastTextureSize: CGSize = .zero
    
    private var cachedTexture: MTLTexture? {
        didSet { didUpdateTexture?() }
    }
    
    // MARK: - 初始化
    
    init(device: MTLDevice) {
        self.device = device
        self.commandQueue = device.makeCommandQueue()!
    }
    
    deinit {
        displayLink?.invalidate()
    }
    
    // MARK: - 公开 API
    
    public func currentTexture(for view: UIView) -> MTLTexture? {
        if targetView !== view {
            targetView = view
            invalidate()
            scheduleUpdateLoop()
        }
        
        if cachedTexture == nil {
            refreshTexture()
        }
        
        return cachedTexture
    }
    
    public func invalidate() {
        cachedTexture = nil
    }
    
    // MARK: - 刷新调度
    
    private func scheduleUpdateLoop() {
        displayLink?.invalidate()
        displayLink = nil
        
        switch updateMode {
        case .continuous(let interval):
            // 用 CADisplayLink 替代 Timer，与屏幕刷新同步
            frameInterval = max(1, Int(round(1.0 / (interval * 60.0))))
            frameCounter = 0
            let link = CADisplayLink(target: self, selector: #selector(displayLinkFired))
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 10, maximum: 30, preferred: Float(1.0 / interval))
            link.add(to: .main, forMode: .common)
            displayLink = link
            
        case .once:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.refreshTexture()
            }
            
        case .manual:
            break
        }
    }
    
    @objc private func displayLinkFired() {
        refreshTexture()
    }
    
    // MARK: - 截图 & 纹理
    
    private func refreshTexture() {
        guard let view = targetView, !isCapturing else { return }
        
        isCapturing = true
        defer { isCapturing = false }
        
        // 确保 backdropView 在目标视图下方
        if backdropView.superview !== view.superview {
            view.superview?.insertSubview(backdropView, belowSubview: view)
        }
        backdropView.frame = view.frame
        
        let scale = UIScreen.main.scale * 0.6 // 降低截图分辨率节省性能
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        
        let renderer = UIGraphicsImageRenderer(size: backdropView.bounds.size, format: format)
        let image = renderer.image { _ in
            backdropView.drawHierarchy(in: backdropView.bounds, afterScreenUpdates: false)
        }
        guard let cgImage = image.cgImage else { return }
        
        let width = cgImage.width
        let height = cgImage.height
        let currentSize = CGSize(width: width, height: height)
        
        // 只在尺寸变化时重建纹理
        if sourceTexture == nil || lastTextureSize != currentSize {
            sourceTexture = makeTexture(width: width, height: height)
            blurredTexture = makeTexture(width: width, height: height)
            lastTextureSize = currentSize
        }
        
        guard let source = sourceTexture else { return }
        uploadPixels(to: source, from: cgImage)
        
        // 无模糊直接返回
        if blurRadius <= 0 {
            cachedTexture = source
            return
        }
        
        // MPS 高斯模糊
        guard let blurred = blurredTexture,
              let buffer = commandQueue.makeCommandBuffer() else {
            cachedTexture = source
            return
        }
        
        let sigma = blurRadius * Float(scale / UIScreen.main.scale)
        let blur = MPSImageGaussianBlur(device: device, sigma: sigma)
        blur.edgeMode = .clamp
        blur.encode(commandBuffer: buffer, sourceTexture: source, destinationTexture: blurred)
        buffer.commit()
        
        cachedTexture = blurred
    }
    
    // MARK: - Metal 工具
    
    private func makeTexture(width: Int, height: Int) -> MTLTexture? {
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        desc.usage = [.shaderRead, .shaderWrite]
        desc.storageMode = .shared
        return device.makeTexture(descriptor: desc)
    }
    
    private func uploadPixels(to texture: MTLTexture, from image: CGImage) {
        let w = image.width, h = image.height
        let bytesPerRow = w * 4
        let colorSpace = image.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        
        guard let ctx = CGContext(
            data: nil, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ), let data = (ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h)), ctx.data).1
        else { return }
        
        texture.replace(
            region: MTLRegionMake2D(0, 0, w, h),
            mipmapLevel: 0,
            withBytes: data,
            bytesPerRow: bytesPerRow
        )
    }
}

/// CABackdropLayer 代理视图 — 用于捕获视图层级下方的内容
final class BackdropView: UIView {
    override class var layerClass: AnyClass {
        NSClassFromString("CABackdropLayer") ?? CALayer.self
    }
}
