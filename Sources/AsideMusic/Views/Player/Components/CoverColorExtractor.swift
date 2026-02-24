import SwiftUI
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// 从封面图片提取主色调
@MainActor @Observable
final class CoverColorExtractor {
    var dominantColor: Color = .gray
    var secondaryColor: Color = .gray.opacity(0.6)
    var isDark: Bool = true
    
    private var lastURL: String?
    
    /// 从 URL 异步提取颜色
    func extract(from urlString: String?) {
        guard let urlString, !urlString.isEmpty, urlString != lastURL else { return }
        lastURL = urlString
        
        guard let url = URL(string: urlString) else { return }
        
        Task {
            let colors = await Task.detached(priority: .userInitiated) {
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    guard let image = UIImage(data: data) else { return nil as UIImage.ExtractedColors? }
                    return image.extractColors()
                } catch {
                    return nil
                }
            }.value
            
            if let colors {
                withAnimation(.easeOut(duration: 0.6)) {
                    self.dominantColor = colors.dominant
                    self.secondaryColor = colors.secondary
                    self.isDark = colors.isDark
                }
            }
        }
    }
    
    /// 重置颜色
    func reset() {
        lastURL = nil
        dominantColor = .gray
        secondaryColor = .gray.opacity(0.6)
        isDark = true
    }
}

// MARK: - UIImage 颜色提取扩展
extension UIImage {
    struct ExtractedColors {
        let dominant: Color
        let secondary: Color
        let isDark: Bool
    }
    
    func extractColors() -> ExtractedColors {
        return extractWithCoreImage()
    }

    /// 使用 CoreImage CIAreaAverage 原生滤镜提取颜色
    private func extractWithCoreImage() -> ExtractedColors {
        guard let cgImage = self.cgImage else {
            return ExtractedColors(dominant: .gray, secondary: .gray, isDark: true)
        }
        
        let ciImage = CIImage(cgImage: cgImage)
        let context = CIContext(options: [.useSoftwareRenderer: false])
        let extent = ciImage.extent
        let w = extent.width
        let h = extent.height
        
        // 中心区域取主色（避免边缘噪声）
        let centerRect = CGRect(
            x: w * 0.15, y: h * 0.15,
            width: w * 0.7, height: h * 0.7
        )
        
        // 上半部分取次要色
        let topRect = CGRect(
            x: w * 0.1, y: h * 0.5,
            width: w * 0.8, height: h * 0.4
        )
        
        let dominant = areaAverageColor(ciImage: ciImage, rect: centerRect, context: context)
        let secondary = areaAverageColor(ciImage: ciImage, rect: topRect, context: context)
        
        let luminance = 0.299 * dominant.r + 0.587 * dominant.g + 0.114 * dominant.b
        let isDark = luminance < 0.5
        
        let domColor = boostSaturation(r: dominant.r, g: dominant.g, b: dominant.b, factor: 1.3)
        let secColor = boostSaturation(r: secondary.r, g: secondary.g, b: secondary.b, factor: 1.2)
        
        return ExtractedColors(dominant: domColor, secondary: secColor, isDark: isDark)
    }
    
    private struct RGBComponents {
        let r: CGFloat, g: CGFloat, b: CGFloat
    }
    
    /// CIAreaAverage 原生滤镜 — 硬件加速的区域平均色
    private func areaAverageColor(ciImage: CIImage, rect: CGRect, context: CIContext) -> RGBComponents {
        let filter = CIFilter.areaAverage()
        filter.inputImage = ciImage
        filter.extent = rect
        
        guard let outputImage = filter.outputImage else {
            return RGBComponents(r: 0.5, g: 0.5, b: 0.5)
        }
        
        // 输出是 1x1 像素，读取 RGBA
        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(outputImage,
                      toBitmap: &pixel,
                      rowBytes: 4,
                      bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                      format: .RGBA8,
                      colorSpace: CGColorSpaceCreateDeviceRGB())
        
        return RGBComponents(
            r: CGFloat(pixel[0]) / 255.0,
            g: CGFloat(pixel[1]) / 255.0,
            b: CGFloat(pixel[2]) / 255.0
        )
    }
    
    private func boostSaturation(r: CGFloat, g: CGFloat, b: CGFloat, factor: CGFloat) -> Color {
        let maxC = max(r, g, b)
        let minC = min(r, g, b)
        guard maxC > minC, maxC > 0 else {
            return Color(red: r, green: g, blue: b)
        }
        let gray = (r + g + b) / 3.0
        let newR = min(1.0, gray + (r - gray) * factor)
        let newG = min(1.0, gray + (g - gray) * factor)
        let newB = min(1.0, gray + (b - gray) * factor)
        return Color(red: max(0, newR), green: max(0, newG), blue: max(0, newB))
    }
}
