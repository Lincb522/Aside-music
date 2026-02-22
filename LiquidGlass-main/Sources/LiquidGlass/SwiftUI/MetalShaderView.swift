import SwiftUI
import UIKit
import MetalKit
import simd

/// Metal shader uniform 参数（16 字节对齐）
struct Uniforms {
    var resolution: SIMD2<Float>
    var time: Float
    var blurScale: Float
    var boxSize: SIMD2<Float>
    var cornerRadius: Float
    var tintColor: SIMD3<Float>
    var tintAlpha: Float
}

/// Metal 渲染的 SwiftUI 桥接视图
struct MetalShaderView: UIViewRepresentable {
    let cornerRadius: CGFloat
    let blurScale: CGFloat
    var tintColor: CGColor
    let updateMode: SnapshotUpdateMode
    
    func makeUIView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = MTLCreateSystemDefaultDevice()
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        view.isOpaque = false
        view.layer.isOpaque = false
        view.backgroundColor = .clear
        view.enableSetNeedsDisplay = true
        view.delegate = context.coordinator
        return view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.mtkView = uiView
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            cornerRadius: cornerRadius,
            updateMode: updateMode,
            blurScale: blurScale,
            tintColor: tintColor
        )
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MTKViewDelegate {
        weak var mtkView: MTKView?
        
        private var pipelineState: MTLRenderPipelineState!
        private var samplerState: MTLSamplerState!
        private var commandQueue: MTLCommandQueue!
        private var device: MTLDevice!
        private let startTime = CFAbsoluteTimeGetCurrent()

        var backgroundProvider: BackgroundTextureProvider!
        
        var cornerRadius: CGFloat
        var updateMode: SnapshotUpdateMode
        var blurScale: CGFloat
        var tintColor: CGColor
    
        @MainActor
        init(cornerRadius: CGFloat, updateMode: SnapshotUpdateMode, blurScale: CGFloat, tintColor: CGColor) {
            self.cornerRadius = cornerRadius
            self.updateMode = updateMode
            self.blurScale = blurScale
            self.tintColor = tintColor
            super.init()

            device = MTLCreateSystemDefaultDevice()
            commandQueue = device.makeCommandQueue()

            let library = try! device.makeDefaultLibrary(bundle: .module)

            let pipelineDesc = MTLRenderPipelineDescriptor()
            pipelineDesc.vertexFunction = library.makeFunction(name: "vertexPassthrough")
            pipelineDesc.fragmentFunction = library.makeFunction(name: "liquidGlassFragment")
            pipelineDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
            pipelineState = try! device.makeRenderPipelineState(descriptor: pipelineDesc)
            
            let samplerDesc = MTLSamplerDescriptor()
            samplerDesc.minFilter = .linear
            samplerDesc.magFilter = .linear
            samplerDesc.sAddressMode = .clampToEdge
            samplerDesc.tAddressMode = .clampToEdge
            samplerState = device.makeSamplerState(descriptor: samplerDesc)

            backgroundProvider = BackgroundTextureProvider(device: device)
            backgroundProvider.updateMode = updateMode
            
            backgroundProvider.didUpdateTexture = { [weak self] in
                DispatchQueue.main.async {
                    self?.mtkView?.setNeedsDisplay()
                }
            }
        }

        func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable,
                  let descriptor = view.currentRenderPassDescriptor else { return }
            
            descriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
            descriptor.colorAttachments[0].loadAction = .clear
            descriptor.colorAttachments[0].storeAction = .store

            let commandBuffer = commandQueue.makeCommandBuffer()!
            let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)!
            encoder.setRenderPipelineState(pipelineState)

            // 构建 uniform
            let (r, g, b, a) = extractRGBA(from: tintColor)
            var uniforms = Uniforms(
                resolution: SIMD2<Float>(Float(view.drawableSize.width), Float(view.drawableSize.height)),
                time: Float(CFAbsoluteTimeGetCurrent() - startTime),
                blurScale: Float(blurScale),
                boxSize: SIMD2<Float>(Float(view.drawableSize.width), Float(view.drawableSize.height)),
                cornerRadius: min(
                    Float(cornerRadius * view.contentScaleFactor),
                    min(Float(view.drawableSize.width), Float(view.drawableSize.height)) / 2.0
                ),
                tintColor: SIMD3<Float>(r, g, b),
                tintAlpha: a
            )
            
            encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)

            backgroundProvider.blurRadius = Float(blurScale) * 30.0
            guard let snapshotTexture = backgroundProvider.currentTexture(for: mtkView!) else {
                encoder.endEncoding()
                return
            }
            encoder.setFragmentTexture(snapshotTexture, index: 0)
            encoder.setFragmentSamplerState(samplerState, index: 0)

            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            encoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
        
        // MARK: - 工具
        
        private func extractRGBA(from color: CGColor) -> (Float, Float, Float, Float) {
            let uiColor = UIColor(cgColor: color)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
            return (Float(r), Float(g), Float(b), Float(a))
        }
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
