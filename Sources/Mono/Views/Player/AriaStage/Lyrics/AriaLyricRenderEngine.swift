//  Unified lyric render scheduler and GPU composition policy.
//
//  The engine deliberately keeps SwiftUI/CoreText responsible for glyph
//  shaping, custom fonts and accessibility. Native text layers stay native so
//  they are not re-rasterized into a large texture on every timeline tick.
//  Only effects whose look depends on overlapping masks/blends use a dedicated
//  Metal-backed drawing surface; full-stage effects flatten the active row only.

import SwiftUI

enum AriaLyricRenderEngine {
    struct Frame {
        let time: Double
        let activeIndex: Int
        let activeLine: AriaLine?
    }

    static func frame(lines: [AriaLine], time: Double) -> Frame {
        let index = AriaLyricEngine.activeLineIndex(in: lines, at: time)
        return Frame(
            time: time,
            activeIndex: index,
            activeLine: lines.indices.contains(index) ? lines[index] : nil
        )
    }

    /// Preserve the existing visual cadence while keeping every lyric effect
    /// behind one scheduler. Future tuning no longer needs per-view clocks.
    static func framesPerSecond(
        effect: AriaLyricEffect,
        material: AriaLyricMaterialStyle,
        tier: AriaPerformanceGovernor.Tier,
        isPlaying: Bool,
        enabledStageEffectCount: Int
    ) -> Int {
        guard isPlaying else { return 12 }
        return 60
    }

    static func usesCompactGPUSurface(
        effect: AriaLyricEffect,
        material: AriaLyricMaterialStyle
    ) -> Bool {
        // 回响与折光依赖多层混合/遮罩，单独合成收益明确。其他文字效果
        // 保留为原生文字图层，避免动态歌词每帧重新光栅化整块纹理。
        // 非原色材质本身已有 GPU 合成层，不再嵌套第二块离屏纹理。
        material == .solid && (effect == .echo || effect == .refraction)
    }
}

extension View {
    /// One GPU-backed surface for compact effects. The non-linear color mode
    /// preserves the existing palette and blend appearance.
    func ariaLyricRenderSurface(
        effect: AriaLyricEffect,
        material: AriaLyricMaterialStyle
    ) -> some View {
        modifier(
            AriaLyricRenderSurfaceModifier(
                effect: effect,
                material: material
            )
        )
    }

    /// Full-stage effects use this only on the active animated sentence/card.
    func ariaLyricActiveRowSurface(enabled: Bool = true) -> some View {
        modifier(AriaLyricActiveRowSurfaceModifier(enabled: enabled))
    }
}

private struct AriaLyricRenderSurfaceModifier: ViewModifier {
    let effect: AriaLyricEffect
    let material: AriaLyricMaterialStyle

    @ViewBuilder
    func body(content: Content) -> some View {
        if AriaLyricRenderEngine.usesCompactGPUSurface(
            effect: effect,
            material: material
        ) {
            content.drawingGroup(opaque: false, colorMode: .nonLinear)
        } else {
            content
        }
    }
}

private struct AriaLyricActiveRowSurfaceModifier: ViewModifier {
    let enabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled {
            content.drawingGroup(opaque: false, colorMode: .nonLinear)
        } else {
            content
        }
    }
}
