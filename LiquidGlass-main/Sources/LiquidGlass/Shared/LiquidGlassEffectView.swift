import UIKit
import MetalKit
import SwiftUI
import simd

/// UIKit 版液态玻璃效果视图
@MainActor
public final class LiquidGlassEffectView: UIView {
    
    public var cornerRadius: CGFloat {
        didSet { coordinator.cornerRadius = cornerRadius }
    }
    public var blurScale: CGFloat {
        didSet { coordinator.blurScale = blurScale }
    }
    public var glassColor: UIColor {
        didSet { coordinator.tintColor = glassColor.cgColor }
    }
    public var updateMode: SnapshotUpdateMode {
        didSet { coordinator.updateMode = updateMode }
    }

    private let mtkView: MTKView
    private let coordinator: MetalShaderView.Coordinator

    public init(
        frame: CGRect = .zero,
        cornerRadius: CGFloat = 20,
        updateMode: SnapshotUpdateMode = .continuous(),
        blurScale: CGFloat = 0.5,
        glassColor: UIColor = .gray.withAlphaComponent(0.2)
    ) {
        self.cornerRadius = cornerRadius
        self.blurScale = blurScale
        self.glassColor = glassColor
        self.updateMode = updateMode

        mtkView = MTKView(frame: frame, device: MTLCreateSystemDefaultDevice())
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        mtkView.isOpaque = false
        mtkView.backgroundColor = .clear
        mtkView.enableSetNeedsDisplay = true
        mtkView.clipsToBounds = true

        coordinator = .init(
            cornerRadius: cornerRadius,
            updateMode: updateMode,
            blurScale: blurScale,
            tintColor: glassColor.cgColor
        )

        super.init(frame: frame)

        coordinator.mtkView = mtkView
        mtkView.delegate = coordinator
        addSubview(mtkView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        mtkView.frame = bounds
    }
}
