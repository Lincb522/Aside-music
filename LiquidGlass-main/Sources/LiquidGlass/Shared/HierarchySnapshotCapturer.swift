import UIKit
import QuartzCore

/// 视图层级快照捕获器 — 截取目标视图在根视图中的区域
final class HierarchySnapshotCapturer {
    
    @MainActor
    lazy var captureScale: CGFloat = UIScreen.main.scale * 0.6
    
    private var cachedFormat: UIGraphicsImageRendererFormat?
    private var lastRectSize: CGSize = .zero
    
    @MainActor
    func captureSnapshot(for glassView: UIView) -> CGImage? {
        // 找到根视图
        var root = glassView.superview
        while let parent = root?.superview {
            root = parent
        }
        guard let rootView = root else { return nil }
        
        let rect = glassView.convert(glassView.bounds, to: rootView)
        let w = Int(rect.width * captureScale)
        let h = Int(rect.height * captureScale)
        guard w > 0, h > 0 else { return nil }
        
        // 复用 format 对象
        if cachedFormat == nil || lastRectSize != rect.size {
            let fmt = UIGraphicsImageRendererFormat()
            fmt.scale = captureScale
            fmt.opaque = false
            fmt.preferredRange = .standard
            cachedFormat = fmt
            lastRectSize = rect.size
        }
        
        guard let fmt = cachedFormat else { return nil }
        let renderer = UIGraphicsImageRenderer(size: rect.size, format: fmt)
        
        let image = renderer.image { ctx in
            ctx.cgContext.translateBy(x: -rect.origin.x, y: -rect.origin.y)
            
            let savedAlpha = glassView.layer.opacity
            glassView.layer.opacity = 0
            rootView.drawHierarchy(in: rootView.bounds, afterScreenUpdates: false)
            glassView.layer.opacity = savedAlpha
        }
        
        return image.cgImage
    }
}
