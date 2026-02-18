import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

/// 像素化图片组件 — CIPixellate + 精确像素输出，确保锐利不模糊
struct PixelatedImageView: View {
    let url: URL?
    var pixelScale: CGFloat = 6
    var size: CGFloat = 200
    
    @State private var pixelatedImage: CGImage?
    @State private var currentURL: URL?
    
    // 输出像素尺寸（匹配屏幕物理像素）
    private var outputPixels: Int {
        Int(size * UIScreen.main.scale)
    }
    
    private static let context = CIContext(options: [
        .useSoftwareRenderer: false,
        .highQualityDownsample: false
    ])
    
    var body: some View {
        Canvas(rendersAsynchronously: false) { ctx, canvasSize in
            guard let cgImage = pixelatedImage else { return }
            // 直接绘制，Canvas 不会做额外插值
            ctx.draw(
                Image(decorative: cgImage, scale: UIScreen.main.scale),
                in: CGRect(origin: .zero, size: canvasSize)
            )
        }
        .frame(width: size, height: size)
        .onChange(of: url) { _, newURL in
            guard newURL != currentURL else { return }
            loadAndPixelate(newURL)
        }
        .onAppear {
            guard url != currentURL else { return }
            loadAndPixelate(url)
        }
    }
    
    private func loadAndPixelate(_ imageURL: URL?) {
        guard let imageURL else {
            pixelatedImage = nil
            currentURL = nil
            return
        }
        
        currentURL = imageURL
        let targetPixels = outputPixels
        let blockSize = pixelScale
        
        Task.detached(priority: .userInitiated) {
            guard let (data, _) = try? await URLSession.shared.data(from: imageURL),
                  let uiImage = UIImage(data: data),
                  let ciImage = CIImage(image: uiImage) else {
                return
            }
            
            // 1. 先缩放到目标输出尺寸
            let scaleX = CGFloat(targetPixels) / ciImage.extent.width
            let scaleY = CGFloat(targetPixels) / ciImage.extent.height
            let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
            
            // 2. CIPixellate — 在目标尺寸上做像素化
            let filter = CIFilter.pixellate()
            filter.inputImage = scaled
            filter.scale = Float(blockSize * UIScreen.main.scale)
            filter.center = CGPoint(x: scaled.extent.midX, y: scaled.extent.midY)
            
            guard let output = filter.outputImage else { return }
            let cropped = output.cropped(to: scaled.extent)
            
            guard let cgImage = Self.context.createCGImage(
                cropped,
                from: scaled.extent
            ) else { return }
            
            await MainActor.run {
                pixelatedImage = cgImage
            }
        }
    }
}
