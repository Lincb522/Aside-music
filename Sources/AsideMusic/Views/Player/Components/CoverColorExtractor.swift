import SwiftUI
import UIKit

/// 从封面图片提取主色调
@Observable
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
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let image = UIImage(data: data) else { return }
                let colors = image.extractColors()
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.6)) {
                        self.dominantColor = colors.dominant
                        self.secondaryColor = colors.secondary
                        self.isDark = colors.isDark
                    }
                }
            } catch {
                // 提取失败，保持默认
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
        
        var totalR: CGFloat = 0, totalG: CGFloat = 0, totalB: CGFloat = 0
        var count: CGFloat = 0
        
        // 采样中心区域（避免边缘噪声）
        let startX = Int(size.width * 0.2)
        let endX = Int(size.width * 0.8)
        let startY = Int(size.height * 0.2)
        let endY = Int(size.height * 0.8)
        
        for y in startY..<endY {
            for x in startX..<endX {
                let offset = (y * Int(size.width) + x) * bytesPerPixel
                guard offset + 2 < totalPixels * bytesPerPixel else { continue }
                let r = CGFloat(ptr[offset]) / 255.0
                let g = CGFloat(ptr[offset + 1]) / 255.0
                let b = CGFloat(ptr[offset + 2]) / 255.0
                totalR += r; totalG += g; totalB += b
                count += 1
            }
        }
        
        guard count > 0 else {
            return ExtractedColors(dominant: .gray, secondary: .gray, isDark: true)
        }
        
        let avgR = totalR / count
        let avgG = totalG / count
        let avgB = totalB / count
        
        // 计算亮度
        let luminance = 0.299 * avgR + 0.587 * avgG + 0.114 * avgB
        let isDark = luminance < 0.5
        
        // 增加饱和度让颜色更鲜明
        let dominant = Color(red: avgR, green: avgG, blue: avgB)
        let secondary = Color(red: avgR * 0.7, green: avgG * 0.7, blue: avgB * 0.7)
        
        return ExtractedColors(dominant: dominant, secondary: secondary, isDark: isDark)
    }
}
