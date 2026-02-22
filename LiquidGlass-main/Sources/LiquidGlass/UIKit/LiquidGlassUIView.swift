import UIKit
import MetalKit
import simd

/// UIKit 版液态玻璃视图 — 可直接添加到任意 UIView
@MainActor
public class LiquidGlassUIView: UIView {

    // MARK: - 公开属性

    public var cornerRadius: CGFloat = 20 {
        didSet { metalView.setNeedsDisplay() }
    }

    public var updateMode: SnapshotUpdateMode = .continuous() {
        didSet { backgroundProvider?.updateMode = updateMode }
    }

    public var blurScale: CGFloat = 0.5 {
        didSet { metalView.setNeedsDisplay() }
    }

    public var glassTintColor: UIColor = .gray.withAlphaComponent(0.2) {
        didSet { metalView.setNeedsDisplay() }
    }

    // MARK: - 私有属性

    private var metalView: MTKView!
    private var coordinator: MetalCoordinator!
    private var backgroundProvider: BackgroundTextureProvider?

    // MARK: - 初始化

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    public convenience init(
        cornerRadius: CGFloat = 20,
        updateMode: SnapshotUpdateMode = .continuous(),
        blurScale: CGFloat = 0.5,
        tintColor: UIColor = .gray.withAlphaComponent(0.2)
    ) {
        self.init(frame: .zero)
        self.cornerRadius = cornerRadius
        self.updateMode = updateMode
        self.blurScale = blurScale
        self.glassTintColor = tintColor
        backgroundProvider?.updateMode = updateMode
    }

    // MARK: - 公开方法

    /// 手动刷新背景纹理（updateMode 为 .manual 时使用）
    public func invalidateBackground() {
        backgroundProvider?.invalidate()
        metalView.setNeedsDisplay()
    }

    // MARK: - 内部

    private func setupView() {
        backgroundColor = .clear
        clipsToBounds = true

        metalView = MTKView()
        metalView.device = MTLCreateSystemDefaultDevice()
        metalView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        metalView.isOpaque = false
        metalView.layer.isOpaque = false
        metalView.backgroundColor = .clear
        metalView.enableSetNeedsDisplay = true
        metalView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(metalView)
        
        NSLayoutConstraint.activate([
            metalView.topAnchor.constraint(equalTo: topAnchor),
            metalView.leadingAnchor.constraint(equalTo: leadingAnchor),
            metalView.trailingAnchor.constraint(equalTo: trailingAnchor),
            metalView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        guard let device = metalView.device else { return }

        coordinator = MetalCoordinator(device: device, parentView: self)
        metalView.delegate = coordinator

        backgroundProvider = BackgroundTextureProvider(device: device)
        backgroundProvider?.updateMode = updateMode
        backgroundProvider?.didUpdateTexture = { [weak self] in
            DispatchQueue.main.async { self?.metalView.setNeedsDisplay() }
        }
        coordinator.backgroundProvider = backgroundProvider
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        metalView.setNeedsDisplay()
    }
}

// MARK: - Metal Coordinator

private class MetalCoordinator: NSObject, MTKViewDelegate {
    weak var parentView: LiquidGlassUIView?
    var backgroundProvider: BackgroundTextureProvider?

    private var pipelineState: MTLRenderPipelineState!
    private var samplerState: MTLSamplerState!
    private var commandQueue: MTLCommandQueue!
    private var device: MTLDevice!
    private let startTime = CFAbsoluteTimeGetCurrent()

    init(device: MTLDevice, parentView: LiquidGlassUIView) {
        self.device = device
        self.parentView = parentView
        super.init()

        commandQueue = device.makeCommandQueue()
        
        guard let library = try? device.makeDefaultLibrary(bundle: .module) else { return }

        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction = library.makeFunction(name: "vertexPassthrough")
        desc.fragmentFunction = library.makeFunction(name: "liquidGlassFragment")
        desc.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineState = try? device.makeRenderPipelineState(descriptor: desc)
        
        let samplerDesc = MTLSamplerDescriptor()
        samplerDesc.minFilter = .linear
        samplerDesc.magFilter = .linear
        samplerDesc.sAddressMode = .clampToEdge
        samplerDesc.tAddressMode = .clampToEdge
        samplerState = device.makeSamplerState(descriptor: samplerDesc)
    }

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let parentView = parentView,
              let pipelineState = pipelineState else { return }

        descriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].storeAction = .store

        let commandBuffer = commandQueue.makeCommandBuffer()!
        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)!
        encoder.setRenderPipelineState(pipelineState)

        let tint = parentView.glassTintColor
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        tint.getRed(&r, green: &g, blue: &b, alpha: &a)

        var uniforms = Uniforms(
            resolution: SIMD2<Float>(Float(view.drawableSize.width), Float(view.drawableSize.height)),
            time: Float(CFAbsoluteTimeGetCurrent() - startTime),
            blurScale: Float(parentView.blurScale),
            boxSize: SIMD2<Float>(Float(view.drawableSize.width), Float(view.drawableSize.height)),
            cornerRadius: min(
                Float(parentView.cornerRadius * view.contentScaleFactor),
                min(Float(view.drawableSize.width), Float(view.drawableSize.height)) / 2.0
            ),
            tintColor: SIMD3<Float>(Float(r), Float(g), Float(b)),
            tintAlpha: Float(a)
        )

        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)

        if let provider = backgroundProvider {
            provider.blurRadius = Float(parentView.blurScale) * 30.0
            if let texture = provider.currentTexture(for: parentView) {
                encoder.setFragmentTexture(texture, index: 0)
                encoder.setFragmentSamplerState(samplerState, index: 0)
            }
        }

        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
}
