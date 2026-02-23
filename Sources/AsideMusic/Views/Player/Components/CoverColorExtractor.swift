import SwiftUI
import UIKit

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
        // 缩小图片以提高性能
        let size = CGSize(width: 50, height: 50)
        UIGraphicsBeginImageContextWithOptions(size, false, 1)
        draw(in: CGRect(origin: .zero, size: size))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        guard let cgImage = resized?.cgImage,
              let data = cgImage.dataProvider?.data,
              let ptr = CFDataGetBytePtr(data) else {
            return ExtractedColors(dominant: .gray, secondary: .gray, isDark: true)
        }
        
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let totalPixels = Int(size.width) * Int(size.height)
        
        // 采样中心区域（避免边缘噪声）
        let startX = Int(size.width * 0.2)
        let endX = Int(size.width * 0.8)
        let startY = Int(size.height * 0.2)
        let endY = Int(size.height * 0.8)
        
        // 收集所有采样像素，按饱和度加权
        var weightedR: CGFloat = 0, weightedG: CGFloat = 0, weightedB: CGFloat = 0
        var totalWeight: CGFloat = 0
        var totalR: CGFloat = 0, totalG: CGFloat = 0, totalB: CGFloat = 0
        var count: CGFloat = 0
        
        for y in startY..<endY {
            for x in startX..<endX {
                let offset = (y * Int(size.width) + x) * bytesPerPixel
                guard offset + 2 < totalPixels * bytesPerPixel else { continue }
                let r = CGFloat(ptr[offset]) / 255.0
                let g = CGFloat(ptr[offset + 1]) / 255.0
                let b = CGFloat(ptr[offset + 2]) / 255.0
                
                totalR += r; totalG += g; totalB += b
                count += 1
                
                // 饱和度越高的像素权重越大，提取更鲜明的颜色
                let maxC = max(r, g, b)
                let minC = min(r, g, b)
                let saturation = maxC > 0 ? (maxC - minC) / maxC : 0
                let weight = 0.2 + saturation * 2.0 // 基础权重 + 饱和度加成
                
                weightedR += r * weight
                weightedG += g * weight
                weightedB += b * weight
                totalWeight += weight
            }
        }
        
        guard count > 0, totalWeight > 0 else {
            return ExtractedColors(dominant: .gray, secondary: .gray, isDark: true)
        }
        
        // 用加权平均得到更鲜明的主色
        let avgR = weightedR / totalWeight
        let avgG = weightedG / totalWeight
        let avgB = weightedB / totalWeight
        
        // 计算亮度（用普通平均值）
        let plainR = totalR / count
        let plainG = totalG / count
        let plainB = totalB / count
        let luminance = 0.299 * plainR + 0.587 * plainG + 0.114 * plainB
        let isDark = luminance < 0.5
        
        // 轻微提升饱和度让颜色更鲜明
        let dominant = boostSaturation(r: avgR, g: avgG, b: avgB, factor: 1.3)
        let secondary = boostSaturation(r: avgR * 0.8, g: avgG * 0.8, b: avgB * 0.8, factor: 1.2)
        
        return ExtractedColors(dominant: dominant, secondary: secondary, isDark: isDark)
    }
    
    /// 提升颜色饱和度
    private func boostSaturation(r: CGFloat, g: CGFloat, b: CGFloat, factor: CGFloat) -> Color {
        let maxC = max(r, g, b)
        let minC = min(r, g, b)
        guard maxC > minC, maxC > 0 else {
            return Color(red: r, green: g, blue: b)
        }
        // 将每个通道向最大值方向拉伸
        let gray = (r + g + b) / 3.0
        let newR = min(1.0, gray + (r - gray) * factor)
        let newG = min(1.0, gray + (g - gray) * factor)
        let newB = min(1.0, gray + (b - gray) * factor)
        return Color(red: max(0, newR), green: max(0, newG), blue: max(0, newB))
    }
}
