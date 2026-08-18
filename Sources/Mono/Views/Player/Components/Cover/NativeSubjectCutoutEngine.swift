import CoreImage
import UIKit
import Vision

struct NativeSubjectCutoutComposition {
    let sticker: UIImage
    let backdrop: UIImage
}

private final class NativeSubjectCutoutCompositionBox {
    let value: NativeSubjectCutoutComposition

    init(_ value: NativeSubjectCutoutComposition) {
        self.value = value
    }
}

/// 使用系统 Vision 的前景实例分割为播放器封面提取主体。
/// 结果按封面地址缓存在内存中，切回同一首歌时不重复执行高成本分析。
actor NativeSubjectCutoutEngine {
    static let shared = NativeSubjectCutoutEngine()

    private let context = CIContext(options: [.cacheIntermediates: false])
    private let cache = NSCache<NSString, NativeSubjectCutoutCompositionBox>()

    private init() {
        cache.countLimit = 18
        cache.totalCostLimit = 72 * 1_024 * 1_024
    }

    func cutoutComposition(from image: UIImage, cacheKey: String) -> NativeSubjectCutoutComposition? {
        let key = cacheKey as NSString
        if let cached = cache.object(forKey: key) {
            return cached.value
        }

        guard #available(iOS 17.0, *),
              let cgImage = image.cgImage else {
            return nil
        }

        let result = autoreleasepool {
            makeCutoutComposition(
                cgImage: cgImage,
                orientation: CGImagePropertyOrientation(image.imageOrientation)
            )
        }

        if let result {
            let stickerCost = result.sticker.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
            let backdropCost = result.backdrop.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
            cache.setObject(
                NativeSubjectCutoutCompositionBox(result),
                forKey: key,
                cost: stickerCost + backdropCost
            )
        }
        return result
    }

    func clear() {
        cache.removeAllObjects()
    }

    @available(iOS 17.0, *)
    private func makeCutoutComposition(
        cgImage: CGImage,
        orientation: CGImagePropertyOrientation
    ) -> NativeSubjectCutoutComposition? {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(
            cgImage: cgImage,
            orientation: orientation,
            options: [:]
        )

        do {
            try handler.perform([request])
            guard let observation = request.results?.first,
                  !observation.allInstances.isEmpty else {
                return nil
            }

            let source = CIImage(cgImage: cgImage)
            let extent = source.extent
            guard let maskBuffer = try reliableMask(
                from: observation,
                handler: handler,
                imageExtent: extent
            ) else {
                return nil
            }
            let mask = CIImage(cvPixelBuffer: maskBuffer)
                .cropped(to: extent)

            // 系统蒙版通常紧贴人物边缘。背景消隐时把它略微外扩并柔化，避免
            // 抠像位移后仍露出原封面里的人物轮廓；前景本身仍使用原始软蒙版。
            let erasedSubjectMask = mask
                .clampedToExtent()
                .applyingFilter("CIMorphologyMaximum", parameters: ["inputRadius": 12.0])
                .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 3.5])
                .cropped(to: extent)
            let inverseErasedMask = erasedSubjectMask
                .applyingFilter("CIColorInvert")
                .cropped(to: extent)

            let transparent = CIImage(color: .clear).cropped(to: extent)
            let subject = source.applyingFilter(
                "CIBlendWithMask",
                parameters: [
                    kCIInputBackgroundImageKey: transparent,
                    kCIInputMaskImageKey: mask,
                ]
            )

            // 把系统软蒙版略微外扩，直接烘焙一圈纸白描边；比 SwiftUI
            // 叠加多层阴影更稳定，也避免播放器动画期间增加 GPU 负担。
            let outlineMask = mask
                .clampedToExtent()
                .applyingFilter("CIMorphologyMaximum", parameters: ["inputRadius": 8.0])
                .cropped(to: extent)
            let paperWhite = CIImage(color: CIColor(red: 0.98, green: 0.97, blue: 0.93, alpha: 1))
                .cropped(to: extent)
            let outline = paperWhite.applyingFilter(
                "CIBlendWithMask",
                parameters: [
                    kCIInputBackgroundImageKey: transparent,
                    kCIInputMaskImageKey: outlineMask,
                ]
            )
            let stickerOutput = subject.composited(over: outline).cropped(to: extent)

            // 用整张封面的综合色填补被撕出的区域，而不是继续保留一张模糊的人。
            // 这样既保留封面的原始背景与排版，也让主体后方形成明确的“撕空”。
            let averageColor = source
                .applyingFilter("CIAreaAverage", parameters: [
                    kCIInputExtentKey: CIVector(cgRect: extent),
                ])
                .transformed(by: CGAffineTransform(scaleX: extent.width, y: extent.height))
                .cropped(to: extent)
                .applyingFilter("CIColorControls", parameters: [
                    kCIInputSaturationKey: 0.72,
                    kCIInputBrightnessKey: 0.035,
                ])
            let backdropOutput = source.applyingFilter(
                "CIBlendWithMask",
                parameters: [
                    kCIInputBackgroundImageKey: averageColor,
                    kCIInputMaskImageKey: inverseErasedMask,
                ]
            )
            .cropped(to: extent)

            // 保留原封面画布与主体比例。布局层只通过纸边和阴影强调抠像，
            // 不再把较小主体强制放大到铺满舞台。
            guard let stickerCGImage = context.createCGImage(stickerOutput, from: extent),
                  let backdropCGImage = context.createCGImage(backdropOutput, from: extent) else {
                return nil
            }
            let scale = imageScale(for: cgImage)
            return NativeSubjectCutoutComposition(
                sticker: UIImage(cgImage: stickerCGImage, scale: scale, orientation: .up),
                backdrop: UIImage(cgImage: backdropCGImage, scale: scale, orientation: .up)
            )
        } catch {
            AppLogger.debug(
                "[Cutout] Vision 前景分割失败 error=\(error.localizedDescription)",
                step: "player.cutout.failed"
            )
            return nil
        }
    }

    private func imageScale(for cgImage: CGImage) -> CGFloat {
        let longSide = max(cgImage.width, cgImage.height)
        return longSide >= 1_200 ? 3 : (longSide >= 700 ? 2 : 1)
    }

    @available(iOS 17.0, *)
    private func reliableMask(
        from observation: VNInstanceMaskObservation,
        handler: VNImageRequestHandler,
        imageExtent: CGRect
    ) throws -> CVPixelBuffer? {
        let allMask = try observation.generateScaledMaskForImage(
            forInstances: observation.allInstances,
            from: handler
        )

        // 一至三个前景通常是单人、双人或乐队封面，优先完整保留；实例过多时
        // 容易把文字、装饰和背景一起抠出，改为只选最可信的主体。
        if observation.allInstances.count <= 3,
           let metrics = maskMetrics(in: allMask, imageExtent: imageExtent),
           metrics.isReliable {
            return allMask
        }

        var best: (buffer: CVPixelBuffer, score: CGFloat)?
        for instance in observation.allInstances {
            let buffer = try observation.generateScaledMaskForImage(
                forInstances: IndexSet(integer: instance),
                from: handler
            )
            guard let metrics = maskMetrics(in: buffer, imageExtent: imageExtent),
                  metrics.isReliable else {
                continue
            }
            if best == nil || metrics.score > best!.score {
                best = (buffer, metrics.score)
            }
        }
        return best?.buffer
    }

    private func maskMetrics(
        in pixelBuffer: CVPixelBuffer,
        imageExtent: CGRect
    ) -> ForegroundMaskMetrics? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let format = CVPixelBufferGetPixelFormatType(pixelBuffer)

        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1
        var foregroundSamples = 0
        var totalSamples = 0

        @inline(__always)
        func alpha(atX x: Int, y: Int) -> Float {
            let row = baseAddress.advanced(by: y * bytesPerRow)
            switch format {
            case kCVPixelFormatType_OneComponent8:
                return Float(row.load(fromByteOffset: x, as: UInt8.self)) / 255
            case kCVPixelFormatType_OneComponent16Half:
                let bits = row.load(fromByteOffset: x * MemoryLayout<UInt16>.stride, as: UInt16.self)
                return Float(Float16(bitPattern: bits))
            case kCVPixelFormatType_OneComponent32Float:
                return row.load(fromByteOffset: x * MemoryLayout<Float>.stride, as: Float.self)
            default:
                return 0
            }
        }

        let step = max(1, min(width, height) / 900)
        for y in stride(from: 0, to: height, by: step) {
            for x in stride(from: 0, to: width, by: step) {
                totalSamples += 1
                if alpha(atX: x, y: y) > 0.08 {
                    foregroundSamples += 1
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                }
            }
        }

        guard maxX >= minX, maxY >= minY, foregroundSamples > 0, totalSamples > 0 else {
            return nil
        }
        let scaleX = imageExtent.width / CGFloat(width)
        let scaleY = imageExtent.height / CGFloat(height)
        let rawBounds = CGRect(
            x: imageExtent.minX + CGFloat(minX) * scaleX,
            y: imageExtent.minY + CGFloat(height - 1 - maxY) * scaleY,
            width: CGFloat(maxX - minX + step) * scaleX,
            height: CGFloat(maxY - minY + step) * scaleY
        )
        let padding = max(imageExtent.width, imageExtent.height) * 0.045
        let bounds = rawBounds
            .insetBy(dx: -padding, dy: -padding)
            .intersection(imageExtent)
            .integral
        let normalizedBounds = CGRect(
            x: (bounds.minX - imageExtent.minX) / imageExtent.width,
            y: (bounds.minY - imageExtent.minY) / imageExtent.height,
            width: bounds.width / imageExtent.width,
            height: bounds.height / imageExtent.height
        )
        let coverage = CGFloat(foregroundSamples) / CGFloat(totalSamples)
        let sampledBoundsArea = max(
            1,
            CGFloat(((maxX - minX) / step) + 1) * CGFloat(((maxY - minY) / step) + 1)
        )
        let density = CGFloat(foregroundSamples) / sampledBoundsArea
        return ForegroundMaskMetrics(
            normalizedBounds: normalizedBounds,
            coverage: coverage,
            density: density
        )
    }
}

private struct ForegroundMaskMetrics {
    let normalizedBounds: CGRect
    let coverage: CGFloat
    let density: CGFloat

    var isReliable: Bool {
        coverage >= 0.035
            && coverage <= 0.86
            && normalizedBounds.width >= 0.17
            && normalizedBounds.height >= 0.17
            && density >= 0.2
    }

    var score: CGFloat {
        let idealCoverage = max(0, 1 - abs(coverage - 0.32) / 0.32)
        let center = CGPoint(x: normalizedBounds.midX, y: normalizedBounds.midY)
        let centerDistance = hypot(center.x - 0.5, center.y - 0.5)
        let centerScore = max(0, 1 - centerDistance / 0.72)
        return idealCoverage * 0.48 + centerScore * 0.34 + min(density, 1) * 0.18
    }
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
