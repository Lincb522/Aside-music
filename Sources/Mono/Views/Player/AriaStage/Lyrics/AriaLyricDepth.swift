import SwiftUI

/// 歌词景深：不绘制任何形状化底衬（圆形/方形光区都会在深色封面上留下伪影），
/// 只用三个无边界线索表达前后关系 —— 背景虚化（AriaFluidBackground 随景深加深）、
/// 贴字投影（shadow 只跟随字形 alpha）、低频视差浮动。
private struct AriaLyricSpatialDepthModifier: ViewModifier {
    let palette: AriaPalette
    let intensity: Double
    let time: Double
    let motionEnabled: Bool
    let usesFullStage: Bool
    /// 关闭后仅保留视差浮动，不渲染任何阴影/浮雕层
    let embossEnabled: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ViewBuilder
    func body(content: Content) -> some View {
        let amount = min(max(intensity, 0), 1)
        let depth = pow(amount, 0.72)
        let canMove = motionEnabled && !reduceMotion
        let yaw = canMove ? sin(time / 9.5) * 2.1 * depth : 0
        let pitch = canMove ? cos(time / 12.0) * 1.15 * depth : 0
        let floatOffset = canMove ? sin(time / 7.2) * 2.8 * depth : 0

        if usesFullStage {
            // 整屏滚动/气泡舞台不做逐帧离屏合成，避免大纹理持续消耗 GPU。
            // 新拟物浮雕（轻量版）：上缘亮边 + 下缘近影，投影全部贴字。
            if embossEnabled {
                content
                    .shadow(
                        color: Color.white.opacity(0.20 * depth),
                        radius: CGFloat(1 + depth),
                        y: CGFloat(-(1 + 1.1 * depth))
                    )
                    .shadow(
                        color: Color.black.opacity(0.42 * depth),
                        radius: CGFloat(2 + 2.5 * depth),
                        y: CGFloat(2 + 2 * depth)
                    )
            } else {
                content
            }
        } else {
            embossedContent(content, depth: depth)
                .rotation3DEffect(
                    .degrees(yaw),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.28
                )
                .rotation3DEffect(
                    .degrees(pitch),
                    axis: (x: 1, y: 0, z: 0),
                    perspective: 0.24
                )
                .scaleEffect(1 + CGFloat(depth) * 0.018)
                .offset(y: CGFloat(floatOffset - 2.5 * depth))
        }
    }

    /// 新拟物浮雕：上缘亮边模拟受光、下缘近影给出厚度、
    /// 小半径环境影托底 —— 三层都贴字形，不会在背景上糊出脏块。
    @ViewBuilder
    private func embossedContent(_ content: Content, depth: Double) -> some View {
        if embossEnabled {
            content
                .compositingGroup()
                .shadow(
                    color: Color.white.opacity(0.30 * depth),
                    radius: CGFloat(1 + 1.4 * depth),
                    x: 0,
                    y: CGFloat(-(1.2 + 1.4 * depth))
                )
                .shadow(
                    color: Color.black.opacity(0.55 * depth),
                    radius: CGFloat(2 + 3 * depth),
                    x: 0,
                    y: CGFloat(2 + 3 * depth)
                )
                .shadow(
                    color: Color.black.opacity(0.26 * depth),
                    radius: CGFloat(9 * depth),
                    x: 0,
                    y: CGFloat(6 * depth)
                )
        } else {
            content
        }
    }
}

extension View {
    func ariaLyricSpatialDepth(
        palette: AriaPalette,
        intensity: Double,
        time: Double,
        motionEnabled: Bool,
        usesFullStage: Bool,
        embossEnabled: Bool = true
    ) -> some View {
        modifier(
            AriaLyricSpatialDepthModifier(
                palette: palette,
                intensity: intensity,
                time: time,
                motionEnabled: motionEnabled,
                usesFullStage: usesFullStage,
                embossEnabled: embossEnabled
            )
        )
    }
}
