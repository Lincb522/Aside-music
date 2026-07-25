import SwiftUI

// MARK: - 山景视差动态背景

struct ParallaxMountainHeader: View {
    var scrollOffset: CGFloat = 0
    var height: CGFloat = 380

    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }
    private var drift: CGFloat { max(0, 60 - scrollOffset) }

    var body: some View {
        ZStack {
            // 静态层：天空 + 天体 + 山（不需要 TimelineView）
            Canvas { ctx, sz in
                if isDark {
                    drawNightSky(ctx: ctx, size: sz)
                    drawStarsStatic(ctx: ctx, size: sz)
                    drawMoon(ctx: ctx, size: sz)
                    drawMoonClouds(ctx: ctx, size: sz)
                } else {
                    drawDaySky(ctx: ctx, size: sz)
                    drawSun(ctx: ctx, size: sz)
                }
            }
            .drawingGroup()

            // 动态层：飘动的云（SwiftUI View，GPU 加速模糊）
            CloudLayer(isDark: isDark, height: height)

            // 静态层：山（盖在云上面的远景山不盖，近景山盖住云底部）
            Canvas { ctx, sz in
                if isDark {
                    drawNightMountains(ctx: ctx, size: sz)
                } else {
                    drawDayMountains(ctx: ctx, size: sz)
                }
            }
            .drawingGroup()
        }
        .frame(height: height)
        .clipped()
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 白天天空
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func drawDaySky(ctx: GraphicsContext, size: CGSize) {
        let rect = CGRect(origin: .zero, size: size)
        ctx.fill(Path(rect), with: .linearGradient(
            Gradient(stops: [
                .init(color: Color(hex: "8EAEC4"), location: 0),
                .init(color: Color(hex: "A4BECE"), location: 0.15),
                .init(color: Color(hex: "B8CCD8"), location: 0.3),
                .init(color: Color(hex: "C8D6E0"), location: 0.45),
                .init(color: Color(hex: "D4DEE8"), location: 0.58),
                .init(color: Color(hex: "DEE4EC"), location: 0.7),
                .init(color: Color(hex: "E8ECF2"), location: 0.82),
                .init(color: Color(hex: "F0F2F6"), location: 0.92),
                .init(color: Color(hex: "F8F9FB"), location: 1.0),
            ]),
            startPoint: CGPoint(x: size.width / 2, y: 0),
            endPoint: CGPoint(x: size.width / 2, y: size.height)
        ))
    }

    private func drawSun(ctx: GraphicsContext, size: CGSize) {
        let r: CGFloat = size.width * 0.038
        let cx = size.width * 0.65
        let cy = size.height * 0.25 - drift * 0.04

        for i in stride(from: 10, through: 1, by: -1) {
            let s = CGFloat(i)
            let alpha = 0.025 * (11 - s) / 10
            let gr = r * s
            let p = Path(ellipseIn: CGRect(x: cx - gr, y: cy - gr, width: gr * 2, height: gr * 2))
            ctx.fill(p, with: .color(Color(hex: "E8E0D0").opacity(alpha)))
        }

        let sunPath = Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
        ctx.fill(sunPath, with: .radialGradient(
            Gradient(colors: [Color(hex: "FFFEF8"), Color(hex: "FFF6E8"), Color(hex: "FFECD0")]),
            center: CGPoint(x: cx, y: cy), startRadius: 0, endRadius: r
        ))
    }

    private func drawDayMountains(ctx: GraphicsContext, size: CGSize) {
        let w = size.width, h = size.height
        smoothFill(ctx: ctx, w: w, h: h, color: Color(hex: "A8B8CA").opacity(0.5), offsetY: -drift * 0.06, points: [
            (-0.15, 0.60), (-0.04, 0.55), (0.06, 0.50), (0.14, 0.43),
            (0.22, 0.47), (0.32, 0.50), (0.44, 0.46), (0.52, 0.42), (0.58, 0.39),
            (0.65, 0.42), (0.76, 0.46), (0.88, 0.43), (0.96, 0.46),
            (1.06, 0.48), (1.16, 0.54),
        ])
        smoothFill(ctx: ctx, w: w, h: h, color: Color(hex: "8098AE").opacity(0.7), offsetY: -drift * 0.14, points: [
            (-0.12, 0.72), (-0.02, 0.68), (0.08, 0.62), (0.16, 0.55),
            (0.21, 0.52), (0.28, 0.56), (0.38, 0.62), (0.50, 0.60),
            (0.60, 0.56), (0.66, 0.58), (0.76, 0.62), (0.86, 0.60), (0.94, 0.63),
            (1.04, 0.62), (1.14, 0.68),
        ])
        smoothFill(ctx: ctx, w: w, h: h, color: Color(hex: "607890").opacity(0.8), offsetY: -drift * 0.24, points: [
            (-0.10, 0.85), (0.02, 0.82), (0.12, 0.78), (0.24, 0.76),
            (0.38, 0.79), (0.52, 0.76), (0.64, 0.74), (0.72, 0.76),
            (0.84, 0.78), (0.96, 0.76), (1.08, 0.80), (1.14, 0.84),
        ])
        smoothFill(ctx: ctx, w: w, h: h, color: Color(hex: "4A6580").opacity(0.85), offsetY: -drift * 0.32, points: [
            (-0.08, 0.94), (0.10, 0.90), (0.28, 0.88),
            (0.46, 0.90), (0.62, 0.87), (0.80, 0.89), (0.96, 0.88), (1.10, 0.92),
        ])
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 夜间天空
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func drawNightSky(ctx: GraphicsContext, size: CGSize) {
        let rect = CGRect(origin: .zero, size: size)
        ctx.fill(Path(rect), with: .linearGradient(
            Gradient(stops: [
                .init(color: Color(hex: "04060E"), location: 0),
                .init(color: Color(hex: "08102A"), location: 0.25),
                .init(color: Color(hex: "101838"), location: 0.45),
                .init(color: Color(hex: "182048"), location: 0.6),
                .init(color: Color(hex: "1A1E40"), location: 0.75),
                .init(color: Color(hex: "10132A"), location: 0.88),
                .init(color: Color(hex: "050507"), location: 1.0),
            ]),
            startPoint: CGPoint(x: size.width / 2, y: 0),
            endPoint: CGPoint(x: size.width / 2, y: size.height)
        ))
    }

    private func drawStarsStatic(ctx: GraphicsContext, size: CGSize) {
        let dy = drift * 0.02

        let brightStars: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (0.06, 0.06, 1.8, 0.9),  (0.18, 0.12, 1.6, 0.85),
            (0.32, 0.04, 1.7, 0.8),  (0.48, 0.08, 1.5, 0.75),
            (0.62, 0.03, 1.8, 0.9),  (0.78, 0.10, 1.6, 0.85),
            (0.92, 0.06, 1.5, 0.8),  (0.14, 0.20, 1.4, 0.7),
            (0.42, 0.18, 1.5, 0.75), (0.70, 0.16, 1.4, 0.7),
        ]
        for (rx, ry, r, a) in brightStars {
            let x = rx * size.width
            let y = ry * size.height - dy
            let glow = Path(ellipseIn: CGRect(x: x - r * 3, y: y - r * 3, width: r * 6, height: r * 6))
            ctx.fill(glow, with: .color(.white.opacity(a * 0.06)))
            let dot = Path(ellipseIn: CGRect(x: x - r * 0.5, y: y - r * 0.5, width: r, height: r))
            ctx.fill(dot, with: .color(.white.opacity(a)))
        }

        let dimStars: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (0.03, 0.14, 0.7, 0.3), (0.10, 0.03, 0.6, 0.25),
            (0.16, 0.08, 0.8, 0.35), (0.24, 0.16, 0.6, 0.2),
            (0.28, 0.02, 0.7, 0.3), (0.36, 0.12, 0.5, 0.25),
            (0.40, 0.22, 0.6, 0.2), (0.45, 0.14, 0.7, 0.3),
            (0.52, 0.05, 0.6, 0.2), (0.56, 0.20, 0.5, 0.25),
            (0.60, 0.10, 0.7, 0.3), (0.66, 0.22, 0.5, 0.2),
            (0.74, 0.06, 0.6, 0.25), (0.82, 0.18, 0.7, 0.3),
            (0.86, 0.03, 0.5, 0.2), (0.90, 0.14, 0.6, 0.25),
            (0.96, 0.10, 0.5, 0.2), (0.22, 0.24, 0.5, 0.15),
            (0.54, 0.26, 0.5, 0.15), (0.84, 0.24, 0.5, 0.15),
        ]
        for (rx, ry, r, a) in dimStars {
            let x = rx * size.width
            let y = ry * size.height - dy
            let dot = Path(ellipseIn: CGRect(x: x - r * 0.5, y: y - r * 0.5, width: r, height: r))
            ctx.fill(dot, with: .color(.white.opacity(a)))
        }
    }

    private func drawMoon(ctx: GraphicsContext, size: CGSize) {
        let r: CGFloat = size.width * 0.038
        let cx = size.width * 0.63
        let cy = size.height * 0.24 - drift * 0.04

        let glowLayers: [(CGFloat, Double)] = [
            (5.0, 0.010), (3.5, 0.016), (2.2, 0.025), (1.5, 0.04),
        ]
        for (scale, alpha) in glowLayers {
            let gr = r * scale
            let p = Path(ellipseIn: CGRect(x: cx - gr, y: cy - gr, width: gr * 2, height: gr * 2))
            ctx.fill(p, with: .color(Color(hex: "B8C8E8").opacity(alpha)))
        }

        ctx.drawLayer { layer in
            let moonBody = Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
            layer.fill(moonBody, with: .linearGradient(
                Gradient(colors: [Color(hex: "E8ECF8"), Color(hex: "D0CEE0")]),
                startPoint: CGPoint(x: cx - r, y: cy - r),
                endPoint: CGPoint(x: cx + r * 0.6, y: cy + r * 0.8)
            ))
            let cutR = r * 0.82
            let cutPath = Path(ellipseIn: CGRect(
                x: cx + r * 0.5 - cutR, y: cy - r * 0.2 - cutR,
                width: cutR * 2, height: cutR * 2
            ))
            var eraser = layer
            eraser.blendMode = .destinationOut
            eraser.fill(cutPath, with: .color(.white))
        }

        ctx.drawLayer { layer in
            let outerR = r * 1.04
            layer.fill(Path(ellipseIn: CGRect(x: cx - outerR, y: cy - outerR, width: outerR * 2, height: outerR * 2)),
                       with: .color(Color(hex: "D0D8F0").opacity(0.12)))
            let innerR = r * 0.96
            var eraser = layer
            eraser.blendMode = .destinationOut
            eraser.fill(Path(ellipseIn: CGRect(x: cx - innerR, y: cy - innerR, width: innerR * 2, height: innerR * 2)),
                       with: .color(.white))
            let cutR2 = r * 0.86
            eraser.fill(Path(ellipseIn: CGRect(
                x: cx + r * 0.5 - cutR2, y: cy - r * 0.2 - cutR2,
                width: cutR2 * 2, height: cutR2 * 2
            )), with: .color(.white))
        }
    }

    private func drawMoonClouds(ctx: GraphicsContext, size: CGSize) {
        let w = size.width
        let moonCy = size.height * 0.24 - drift * 0.04
        let color = Color(hex: "B8C8E8")

        // 横贯天空的丝状云带，用绝对坐标定位，不依附月亮
        // (y 位置, 透明度, 厚度, 模糊)
        // 每条云带由多个横向拉长的扁椭圆沿水平方向错落排列
        struct Band {
            var y: CGFloat          // 相对于 moonCy 的偏移
            var alpha: Double
            var blur: CGFloat
            // 每个片段: (x中心比例 0~1 相对屏幕宽度, 宽度比例, 高度pt)
            var segments: [(CGFloat, CGFloat, CGFloat)]
        }

        let bands: [Band] = [
            Band(y: 12, alpha: 0.10, blur: 3, segments: [
                (0.45, 0.22, 3), (0.55, 0.20, 2.5), (0.65, 0.24, 3.5),
                (0.76, 0.18, 2.5), (0.85, 0.15, 2), (0.92, 0.12, 1.5),
            ]),
            Band(y: -6, alpha: 0.07, blur: 2.5, segments: [
                (0.60, 0.16, 2.5), (0.70, 0.20, 3), (0.82, 0.15, 2),
                (0.90, 0.12, 1.5),
            ]),
            Band(y: 22, alpha: 0.06, blur: 3, segments: [
                (0.50, 0.18, 2.5), (0.62, 0.22, 3), (0.74, 0.16, 2),
                (0.84, 0.14, 1.5),
            ]),
        ]

        for band in bands {
            let cy = moonCy + band.y

            ctx.drawLayer { layer in
                layer.addFilter(.blur(radius: band.blur))

                for (xRatio, widthRatio, h) in band.segments {
                    let cx = w * xRatio
                    let segW = w * widthRatio
                    let rect = CGRect(x: cx - segW / 2, y: cy - h / 2, width: segW, height: h)
                    layer.fill(Path(ellipseIn: rect), with: .color(color.opacity(band.alpha)))
                }
            }
        }
    }

    private func drawNightMountains(ctx: GraphicsContext, size: CGSize) {
        let w = size.width, h = size.height
        smoothFill(ctx: ctx, w: w, h: h, color: Color(hex: "141E48"), offsetY: -drift * 0.06, points: [
            (-0.15, 0.60), (-0.04, 0.55), (0.06, 0.50), (0.14, 0.43),
            (0.22, 0.47), (0.32, 0.50), (0.44, 0.46), (0.52, 0.42), (0.58, 0.39),
            (0.65, 0.42), (0.76, 0.46), (0.88, 0.43), (0.96, 0.46),
            (1.06, 0.48), (1.16, 0.54),
        ])
        smoothFill(ctx: ctx, w: w, h: h, color: Color(hex: "0C1430"), offsetY: -drift * 0.14, points: [
            (-0.12, 0.72), (-0.02, 0.68), (0.08, 0.62), (0.16, 0.55),
            (0.21, 0.52), (0.28, 0.56), (0.38, 0.62), (0.50, 0.60),
            (0.60, 0.56), (0.66, 0.58), (0.76, 0.62), (0.86, 0.60), (0.94, 0.63),
            (1.04, 0.62), (1.14, 0.68),
        ])
        smoothFill(ctx: ctx, w: w, h: h, color: Color(hex: "080C20"), offsetY: -drift * 0.24, points: [
            (-0.10, 0.85), (0.02, 0.82), (0.12, 0.78), (0.24, 0.76),
            (0.38, 0.79), (0.52, 0.76), (0.64, 0.74), (0.72, 0.76),
            (0.84, 0.78), (0.96, 0.76), (1.08, 0.80), (1.14, 0.84),
        ])
        smoothFill(ctx: ctx, w: w, h: h, color: Color(hex: "040610"), offsetY: -drift * 0.32, points: [
            (-0.08, 0.94), (0.10, 0.90), (0.28, 0.88),
            (0.46, 0.90), (0.62, 0.87), (0.80, 0.89), (0.96, 0.88), (1.10, 0.92),
        ])
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Catmull-Rom Fill
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func smoothFill(
        ctx: GraphicsContext, w: CGFloat, h: CGFloat,
        color: Color, offsetY: CGFloat,
        points: [(CGFloat, CGFloat)]
    ) {
        let pts = points.map { CGPoint(x: $0.0 * w, y: $0.1 * h + offsetY) }
        var path = Path()

        let leftEdge = min(pts[0].x, -4) - 4
        let rightEdge = max(pts[pts.count - 1].x, w + 4) + 4

        path.move(to: CGPoint(x: leftEdge, y: h + 4))
        path.addLine(to: CGPoint(x: pts[0].x, y: pts[0].y))

        for i in 0..<pts.count - 1 {
            let p0 = i > 0 ? pts[i - 1] : pts[i]
            let p1 = pts[i]
            let p2 = pts[i + 1]
            let p3 = (i + 2 < pts.count) ? pts[i + 2] : p2
            let cp1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let cp2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            path.addCurve(to: p2, control1: cp1, control2: cp2)
        }

        path.addLine(to: CGPoint(x: rightEdge, y: h + 4))
        path.closeSubpath()
        ctx.fill(path, with: .color(color))
    }
}

// MARK: - 云层（独立 View，SwiftUI 动画驱动，不用 TimelineView）

private struct CloudLayer: View {
    let isDark: Bool
    let height: CGFloat

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width

            ZStack {
                singleCloud(w: w, y: height * 0.08, scale: 1.1, x: w * 0.6, opacity: isDark ? 0.05 : 0.20, blur: 18)
                singleCloud(w: w, y: height * 0.18, scale: 0.75, x: w * 0.35, opacity: isDark ? 0.04 : 0.15, blur: 14)
                singleCloud(w: w, y: height * 0.05, scale: 1.3, x: w * 0.15, opacity: isDark ? 0.045 : 0.18, blur: 20)
                singleCloud(w: w, y: height * 0.26, scale: 0.6, x: w * 0.8, opacity: isDark ? 0.03 : 0.12, blur: 12)
            }
        }
        .frame(height: height)
        .drawingGroup()
    }

    private func singleCloud(w: CGFloat, y: CGFloat, scale: CGFloat, x: CGFloat, opacity: Double, blur: CGFloat) -> some View {
        let cloudW = w * 0.14 * scale
        let cloudH = cloudW * 0.5
        let color = isDark ? Color(hex: "8090B8") : Color.white

        return ZStack {
            Ellipse().fill(color.opacity(opacity * 0.7)).frame(width: cloudW * 0.6, height: cloudH * 0.6).offset(x: -cloudW * 0.25, y: cloudH * 0.08)
            Ellipse().fill(color.opacity(opacity)).frame(width: cloudW * 0.8, height: cloudH * 0.85).offset(x: -cloudW * 0.05, y: -cloudH * 0.05)
            Ellipse().fill(color.opacity(opacity)).frame(width: cloudW, height: cloudH)
            Ellipse().fill(color.opacity(opacity * 0.9)).frame(width: cloudW * 0.7, height: cloudH * 0.75).offset(x: cloudW * 0.22, y: cloudH * 0.02)
            Ellipse().fill(color.opacity(opacity * 0.6)).frame(width: cloudW * 0.5, height: cloudH * 0.5).offset(x: cloudW * 0.38, y: cloudH * 0.1)
        }
        .blur(radius: blur)
        .position(x: x, y: y)
    }
}

// MARK: - Parallax Fade Modifier

struct ParallaxFadeModifier: ViewModifier {
    let height: CGFloat

    func body(content: Content) -> some View {
        content.mask(
            VStack(spacing: 0) {
                Color.white
                LinearGradient(
                    colors: [.white, .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: height)
            }
        )
    }
}

extension View {
    func parallaxFade(height: CGFloat = 60) -> some View {
        modifier(ParallaxFadeModifier(height: height))
    }
}
