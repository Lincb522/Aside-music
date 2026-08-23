import SwiftUI

// MARK: - Cover identity

/// 与最初漫画播放主题一致的粉、黄、蓝印刷色板。
enum MangaComicPalette {
    static let ink = Color(hex: "2D2D3A")
    static let inkSoft = Color(hex: "8888A0")
    static let paper = Color(hex: "FFF8EC")
    static let paperBright = Color(hex: "FFFFFF")
    static let paperWarm = Color(hex: "FDE8F0")
    static let paperShadow = Color(hex: "E8F4FD")
    static let mutedInk = Color(hex: "8888A0")
    static let whiteInk = Color(hex: "FFFFFF")

    static let toneLight = Color(hex: "FFE8F0")
    static let toneMid = Color(hex: "FF8FAB")
    static let toneDeep = Color(hex: "D86782")

    static let red = Color(hex: "FF8FAB")
    static let redDeep = Color(hex: "D86782")
    static let navy = Color(hex: "B8D4F0")
    static let violet = Color(hex: "2E1D25")
    static let gold = Color(hex: "FFE4B5")

    static func displayFont(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black, design: .default)
    }

    static func headlineFont(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black, design: .default)
    }

    static func bodyFont(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

// MARK: - Foundational shapes

/// 带轻微错版感的漫画分格外框。
struct MangaComicPanelShape: Shape {
    var corner: CGFloat = 14

    func path(in rect: CGRect) -> Path {
        let c = min(corner, min(rect.width, rect.height) * 0.22)
        var path = Path()

        path.move(to: CGPoint(x: rect.minX + c + 2, y: rect.minY + 1))
        path.addLine(to: CGPoint(x: rect.maxX - c - 4, y: rect.minY + 2))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - 1, y: rect.minY + c + 3),
            control: CGPoint(x: rect.maxX - 1, y: rect.minY + 1)
        )
        path.addLine(to: CGPoint(x: rect.maxX - 2, y: rect.maxY - c - 2))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - c - 2, y: rect.maxY - 1),
            control: CGPoint(x: rect.maxX - 2, y: rect.maxY - 1)
        )
        path.addLine(to: CGPoint(x: rect.minX + c + 1, y: rect.maxY - 2))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + 1, y: rect.maxY - c - 4),
            control: CGPoint(x: rect.minX + 1, y: rect.maxY - 2)
        )
        path.addLine(to: CGPoint(x: rect.minX + 2, y: rect.minY + c + 2))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + c + 2, y: rect.minY + 1),
            control: CGPoint(x: rect.minX + 2, y: rect.minY + 1)
        )
        path.closeSubpath()
        return path
    }
}

/// 报头斜切纸片：压在墨黑顶栏上的白色斜边。
struct MangaComicMastheadShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.31))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + 1))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - 5))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// 剪纸式切角块：功能钮与标签章使用。
struct MangaComicCutCornerShape: Shape {
    var cut: CGFloat = 9

    func path(in rect: CGRect) -> Path {
        let c = min(cut, min(rect.width, rect.height) * 0.18)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + c, y: rect.minY + 1))
        path.addLine(to: CGPoint(x: rect.maxX - c * 0.55, y: rect.minY + 2))
        path.addLine(to: CGPoint(x: rect.maxX - 1, y: rect.minY + c))
        path.addLine(to: CGPoint(x: rect.maxX - 2, y: rect.maxY - c * 0.6))
        path.addLine(to: CGPoint(x: rect.maxX - c, y: rect.maxY - 1))
        path.addLine(to: CGPoint(x: rect.minX + c * 0.55, y: rect.maxY - 2))
        path.addLine(to: CGPoint(x: rect.minX + 1, y: rect.maxY - c))
        path.addLine(to: CGPoint(x: rect.minX + 2, y: rect.minY + c * 0.6))
        path.closeSubpath()
        return path
    }
}

/// 手工剪贴的标题缎带，左端带折角。
struct MangaComicRibbonShape: Shape {
    func path(in rect: CGRect) -> Path {
        let tail = min(13, rect.height * 0.34)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + tail, y: rect.minY + 2))
        path.addLine(to: CGPoint(x: rect.maxX - 4, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - 7))
        path.addLine(to: CGPoint(x: rect.minX + tail, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + tail + 3, y: rect.maxY - 9))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - 8))
        path.addLine(to: CGPoint(x: rect.minX + 8, y: rect.maxY * 0.52))
        path.closeSubpath()
        return path
    }
}

struct MangaComicBurstShape: Shape {
    var points: Int = 14
    var innerRatio: CGFloat = 0.62

    func path(in rect: CGRect) -> Path {
        guard points > 2 else { return Path() }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) * 0.5
        let inner = outer * innerRatio
        let count = points * 2
        var path = Path()

        for index in 0 ..< count {
            let angle = -CGFloat.pi / 2 + CGFloat(index) * (.pi * 2 / CGFloat(count))
            let radius = index.isMultiple(of: 2) ? outer : inner
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

/// 呐喊气泡：长短不一的尖锐锯齿，比 burst 更狂放。
struct MangaShoutBubbleShape: Shape {
    var spikes: Int = 12

    func path(in rect: CGRect) -> Path {
        guard spikes > 2 else { return Path() }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let base = min(rect.width, rect.height) * 0.5
        var path = Path()

        for index in 0 ..< spikes * 2 {
            let angle = -CGFloat.pi / 2 + CGFloat(index) * (.pi / CGFloat(spikes))
            // 外尖长短交替且带抖动，模拟手绘爆炸框的不匀
            let jitter = CGFloat(((index * 37) % 11) - 5) * 0.012
            let radius = index.isMultiple(of: 2)
                ? base * (1 + jitter)
                : base * (0.68 + jitter * 0.5)
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

/// 对白气泡：圆胖主体 + 指向一侧的小尾巴。
struct MangaSpeechBubbleShape: Shape {
    var tailOnLeading: Bool = true

    func path(in rect: CGRect) -> Path {
        let tailSize = min(rect.height * 0.26, 12)
        let bodyRect = CGRect(
            x: rect.minX,
            y: rect.minY,
            width: rect.width,
            height: rect.height - tailSize * 0.72
        )
        var path = Path(roundedRect: bodyRect, cornerRadius: min(bodyRect.height * 0.42, 16))

        let tailBase = tailOnLeading
            ? bodyRect.minX + bodyRect.width * 0.22
            : bodyRect.maxX - bodyRect.width * 0.22
        var tail = Path()
        tail.move(to: CGPoint(x: tailBase - tailSize * 0.7, y: bodyRect.maxY - 2))
        tail.addLine(to: CGPoint(x: tailBase + tailSize * 0.5, y: bodyRect.maxY - 1.4))
        tail.addLine(to: CGPoint(
            x: tailBase + (tailOnLeading ? -tailSize * 0.62 : tailSize * 0.62),
            y: rect.maxY
        ))
        tail.closeSubpath()
        path.addPath(tail)
        return path
    }
}

struct MangaComicFourPointStar: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.midY), control: CGPoint(x: rect.midX + rect.width * 0.12, y: rect.midY - rect.height * 0.12))
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY), control: CGPoint(x: rect.midX + rect.width * 0.12, y: rect.midY + rect.height * 0.12))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.midY), control: CGPoint(x: rect.midX - rect.width * 0.12, y: rect.midY + rect.height * 0.12))
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY), control: CGPoint(x: rect.midX - rect.width * 0.12, y: rect.midY - rect.height * 0.12))
        path.closeSubpath()
        return path
    }
}

struct MangaComicLightningShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.48, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.57))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.39, y: rect.minY + rect.height * 0.55))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.2, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.32))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.58, y: rect.minY + rect.height * 0.38))
        path.closeSubpath()
        return path
    }
}

// MARK: - 网点纸（screentone）

/// 经典 45° 网点纸：黑白漫画的中间调全部靠它。
/// angle 旋转点阵，vignette 让点径沿对角线衰减形成渐变 tone。
struct MangaScreentone: View {
    var color: Color = MangaComicPalette.ink
    var opacity: Double = 0.5
    var gap: CGFloat = 7
    var maxDot: CGFloat = 1.6
    var angle: Double = 45
    /// 点径渐变方向：从该角向外由大变小；nil = 均匀网点
    var fadeFrom: UnitPoint? = nil

    var body: some View {
        Canvas { context, size in
            let theta = CGFloat(angle) * .pi / 180
            let ux = cos(theta), uy = sin(theta)
            let vx = -uy, vy = ux
            let diagonal = hypot(size.width, size.height)
            let fadeAnchor = fadeFrom.map {
                CGPoint(x: $0.x * size.width, y: $0.y * size.height)
            }

            // 逆变换屏幕四角到点阵坐标系，收紧行列范围，
            // 迭代量与屏幕可见点数同级，避免全角度方形扫描的浪费
            let corners: [CGPoint] = [
                .zero, CGPoint(x: size.width, y: 0),
                CGPoint(x: 0, y: size.height), CGPoint(x: size.width, y: size.height),
            ]
            var uMin = CGFloat.infinity, uMax = -CGFloat.infinity
            var vMin = CGFloat.infinity, vMax = -CGFloat.infinity
            for corner in corners {
                let u = corner.x * ux + corner.y * uy
                let v = corner.x * vx + corner.y * vy
                uMin = min(uMin, u); uMax = max(uMax, u)
                vMin = min(vMin, v); vMax = max(vMax, v)
            }
            let iRange = Int(floor(uMin / gap)) - 1 ... Int(ceil(uMax / gap)) + 1
            let jRange = Int(floor(vMin / gap)) - 1 ... Int(ceil(vMax / gap)) + 1

            for i in iRange {
                for j in jRange {
                    let px = CGFloat(i) * gap * ux + CGFloat(j) * gap * vx
                    let py = CGFloat(i) * gap * uy + CGFloat(j) * gap * vy
                    guard px >= -gap, px <= size.width + gap,
                          py >= -gap, py <= size.height + gap else { continue }

                    var radius = maxDot
                    if let anchor = fadeAnchor {
                        let distance = hypot(px - anchor.x, py - anchor.y)
                        let ratio = max(0, 1 - distance / (diagonal * 0.72))
                        radius = maxDot * (0.25 + ratio * 0.75)
                    }
                    guard radius > 0.3 else { continue }

                    context.fill(
                        Path(ellipseIn: CGRect(x: px - radius / 2, y: py - radius / 2, width: radius, height: radius)),
                        with: .color(color.opacity(opacity))
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - 排线（hatching）

/// 手绘排线：一组带轻微抖动的平行线，可叠加成交叉排线表现暗部。
struct MangaHatching: View {
    var color: Color = MangaComicPalette.ink
    var opacity: Double = 0.4
    var gap: CGFloat = 5
    var angle: Double = -45
    var lineWidth: CGFloat = 0.8
    /// 第二组交叉线（暗部交叉排线）
    var cross: Bool = false

    var body: some View {
        Canvas { context, size in
            func strokes(at degrees: CGFloat, alpha: Double) {
                let theta = degrees * .pi / 180
                let ux = cos(theta), uy = sin(theta)
                let vx = -uy, vy = ux
                let diagonal = hypot(size.width, size.height)
                let steps = Int(diagonal / gap) + 2
                let origin = CGPoint(x: size.width / 2, y: size.height / 2)

                for i in -steps ... steps {
                    let cx = origin.x + CGFloat(i) * gap * vx
                    let cy = origin.y + CGFloat(i) * gap * vy
                    // 手绘感：线条中点带微小弯曲，端点长短不一
                    let wobble = CGFloat((i * 31) % 7) - 3
                    let half = diagonal / 2 - CGFloat(abs(i) % 5) * gap * 0.8
                    var line = Path()
                    line.move(to: CGPoint(x: cx - ux * half, y: cy - uy * half))
                    line.addQuadCurve(
                        to: CGPoint(x: cx + ux * half, y: cy + uy * half),
                        control: CGPoint(x: cx + vx * wobble, y: cy + vy * wobble)
                    )
                    context.stroke(
                        line,
                        with: .color(color.opacity(alpha)),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                }
            }
            strokes(at: CGFloat(angle), alpha: opacity)
            if cross {
                strokes(at: CGFloat(angle) + 90, alpha: opacity * 0.7)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - 集中线（focus lines）

/// 集中线：从焦点向外放射的细长三角，渲染「注目！」的瞬间。
/// 粗细与长短均不规则，模拟手绘集中线的笔压。
struct MangaFocusLines: View {
    var color: Color = MangaComicPalette.ink
    var opacity: Double = 0.5
    /// 焦点（归一化坐标）
    var focus: UnitPoint = .center
    /// 中心留白半径（焦点处空出的圆形区域）
    var clearRadius: CGFloat = 60

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: focus.x * size.width, y: focus.y * size.height)
            let outer = hypot(size.width, size.height) * 0.62
            let count = 46

            for index in 0 ..< count {
                let angle = CGFloat(index) * (.pi * 2 / CGFloat(count))
                let jitter = CGFloat(((index * 53) % 17) - 8) * 0.004
                let innerR = clearRadius + CGFloat((index * 29) % 23)
                let outerR = outer - CGFloat((index * 41) % 31) * 2.2
                guard outerR > innerR + 20 else { continue }

                let halfWidth = (0.9 + CGFloat(index % 3) * 0.5) / max(innerR, 1)
                var ray = Path()
                ray.move(to: CGPoint(
                    x: center.x + cos(angle - halfWidth + jitter) * innerR,
                    y: center.y + sin(angle - halfWidth + jitter) * innerR
                ))
                ray.addLine(to: CGPoint(
                    x: center.x + cos(angle + jitter) * outerR,
                    y: center.y + sin(angle + jitter) * outerR
                ))
                ray.addLine(to: CGPoint(
                    x: center.x + cos(angle + halfWidth + jitter) * innerR,
                    y: center.y + sin(angle + halfWidth + jitter) * innerR
                ))
                ray.closeSubpath()
                context.fill(ray, with: .color(color.opacity(opacity * (index % 4 == 0 ? 1 : 0.55))))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - 墨渍（ink splatter）

/// 蘸水笔甩出的墨点：主墨团 + 卫星小点 + 拖尾飞白。
struct MangaInkSplatter: View {
    var color: Color = MangaComicPalette.ink
    var opacity: Double = 0.85
    /// 归一化落点
    var position: UnitPoint
    var scale: CGFloat = 1

    var body: some View {
        Canvas { context, size in
            let anchor = CGPoint(x: position.x * size.width, y: position.y * size.height)
            // 主墨团：不规则多边形近似
            var blob = Path()
            let blobR: CGFloat = 4.5 * scale
            for index in 0 ..< 9 {
                let angle = CGFloat(index) * (.pi * 2 / 9)
                let radius = blobR * (0.75 + CGFloat((index * 13) % 5) * 0.14)
                let point = CGPoint(x: anchor.x + cos(angle) * radius, y: anchor.y + sin(angle) * radius)
                if index == 0 { blob.move(to: point) } else { blob.addLine(to: point) }
            }
            blob.closeSubpath()
            context.fill(blob, with: .color(color.opacity(opacity)))

            // 卫星墨点
            for index in 0 ..< 7 {
                let angle = CGFloat(index) * (.pi * 2 / 7) + 0.4
                let distance = blobR * (2 + CGFloat((index * 7) % 4))
                let dotR = (0.7 + CGFloat(index % 3) * 0.45) * scale
                context.fill(
                    Path(ellipseIn: CGRect(
                        x: anchor.x + cos(angle) * distance - dotR,
                        y: anchor.y + sin(angle) * distance - dotR,
                        width: dotR * 2,
                        height: dotR * 2
                    )),
                    with: .color(color.opacity(opacity * 0.8))
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - 毛笔分隔线（brush divider）

/// 一笔带压感的横扫：两端枯笔、中段饱满，用于区块分隔。
struct MangaBrushDivider: View {
    var color: Color = MangaComicPalette.ink
    var opacity: Double = 0.85

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            var stroke = Path()
            stroke.move(to: CGPoint(x: 0, y: h * 0.5))
            stroke.addQuadCurve(
                to: CGPoint(x: w * 0.5, y: h * 0.42),
                control: CGPoint(x: w * 0.24, y: h * 0.28)
            )
            stroke.addQuadCurve(
                to: CGPoint(x: w, y: h * 0.62),
                control: CGPoint(x: w * 0.78, y: h * 0.55)
            )
            context.stroke(
                stroke,
                with: .color(color.opacity(opacity)),
                style: StrokeStyle(lineWidth: h * 0.52, lineCap: .round)
            )
            // 枯笔飞白：中段补一笔更浅的
            var dry = Path()
            dry.move(to: CGPoint(x: w * 0.18, y: h * 0.58))
            dry.addQuadCurve(
                to: CGPoint(x: w * 0.82, y: h * 0.5),
                control: CGPoint(x: w * 0.5, y: h * 0.38)
            )
            context.stroke(
                dry,
                with: .color(color.opacity(opacity * 0.35)),
                style: StrokeStyle(lineWidth: h * 0.2, lineCap: .round)
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Print textures

/// 纸面纤维杂点：短细划痕 + 针眼墨点。
struct MangaComicPaperTexture: View {
    var ink: Color = MangaComicPalette.ink
    var opacity: Double = 0.12

    var body: some View {
        Canvas { context, size in
            let fleckCount = max(70, Int(size.width * size.height / 1300))
            for index in 0 ..< fleckCount {
                let x = CGFloat((index * 83 + 17) % 997) / 997 * size.width
                let y = CGFloat((index * 137 + 29) % 991) / 991 * size.height
                let length = CGFloat(index % 4 + 1) * 1.25
                var mark = Path()
                mark.move(to: CGPoint(x: x, y: y))
                mark.addLine(to: CGPoint(x: x + length, y: y - length * 0.42))
                context.stroke(mark, with: .color(ink.opacity(opacity * (index.isMultiple(of: 5) ? 1 : 0.55))), lineWidth: index.isMultiple(of: 7) ? 1.4 : 0.75)
            }

            for index in 0 ..< 38 {
                let x = CGFloat((index * 113 + 41) % 977) / 977 * size.width
                let y = CGFloat((index * 191 + 11) % 983) / 983 * size.height
                let side = CGFloat(index % 3 + 1) * 0.8
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: side, height: side)),
                    with: .color(ink.opacity(opacity * 0.7))
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct MangaComicHalftone: View {
    var color: Color = MangaComicPalette.ink
    var opacity: Double = 0.13
    var gap: CGFloat = 8

    var body: some View {
        Canvas { context, size in
            var row = 0
            var y: CGFloat = gap / 2
            while y < size.height + gap {
                var x: CGFloat = row.isMultiple(of: 2) ? gap / 2 : gap
                while x < size.width + gap {
                    let progress = min(1, max(0, (x + y) / max(1, size.width + size.height)))
                    let side = 1.2 + (1 - progress) * 1.6
                    context.fill(
                        Path(ellipseIn: CGRect(x: x - side / 2, y: y - side / 2, width: side, height: side)),
                        with: .color(color.opacity(opacity))
                    )
                    x += gap
                }
                row += 1
                y += gap
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// 速度线：从右上焦点向左下甩出的粗细不均排线。
struct MangaComicSpeedLines: View {
    var color: Color = MangaComicPalette.ink
    var opacity: Double = 0.18

    var body: some View {
        Canvas { context, size in
            let origin = CGPoint(x: size.width * 0.82, y: size.height * 0.28)
            for index in 0 ..< 24 {
                let edgeProgress = CGFloat(index) / 23
                let target: CGPoint
                if index.isMultiple(of: 2) {
                    target = CGPoint(x: 0, y: edgeProgress * size.height)
                } else {
                    target = CGPoint(x: edgeProgress * size.width, y: size.height)
                }
                var line = Path()
                let inset = CGFloat(index % 4) * 8
                line.move(to: CGPoint(x: origin.x + (target.x - origin.x) * 0.16 + inset, y: origin.y + (target.y - origin.y) * 0.16))
                line.addLine(to: target)
                context.stroke(line, with: .color(color.opacity(opacity * (index.isMultiple(of: 3) ? 1 : 0.48))), lineWidth: index.isMultiple(of: 5) ? 1.5 : 0.7)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// 头像背后的爆炸框：纸色爆炸 + 墨描边 + 内圈网点，Canvas 手绘以适配纸底。
struct MangaComicAvatarBurst: View {
    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            let burst = MangaShoutBubbleShape(spikes: 11)

            context.fill(burst.path(in: rect), with: .color(MangaComicPalette.paper))
            context.stroke(burst.path(in: rect), with: .color(MangaComicPalette.ink), lineWidth: 2.6)

            // 内圈短线：手绘爆炸框的排线阴影
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let inner = min(size.width, size.height) * 0.36
            let outer = min(size.width, size.height) * 0.46
            for index in 0 ..< 16 {
                let angle = CGFloat(index) * (.pi * 2 / 16) + 0.2
                var tick = Path()
                tick.move(to: CGPoint(x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner))
                tick.addLine(to: CGPoint(x: center.x + cos(angle) * outer, y: center.y + sin(angle) * outer))
                context.stroke(tick, with: .color(MangaComicPalette.ink.opacity(0.5)), lineWidth: 0.9)
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

// MARK: - 拟声装饰（SFX mark）

/// 手绘描边「♪」：黑白漫画里的拟声词位置，用音符贴合音乐场景。
/// 空心描边 + 网点灰错位，像贴在分格角上的手绘字。
struct MangaSFXNote: View {
    var size: CGFloat = 34
    var rotation: Double = -8
    var filled: Bool = false

    var body: some View {
        ZStack {
            Text("♪")
                .font(.system(size: size, weight: .black))
                .foregroundStyle(filled ? MangaComicPalette.ink : MangaComicPalette.toneLight)
                .offset(x: size * 0.06, y: size * 0.06)

            Text("♪")
                .font(.system(size: size, weight: .black))
                .foregroundStyle(filled ? MangaComicPalette.paper : MangaComicPalette.ink)
        }
        .rotationEffect(.degrees(rotation))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Reusable cover components

struct MangaComicPanel<Content: View>: View {
    var fill: Color = MangaComicPalette.paper
    var corner: CGFloat = 14
    var shadow: CGFloat = 4
    var innerBorder = true
    @ViewBuilder let content: () -> Content

    var body: some View {
        let shape = MangaComicPanelShape(corner: corner)

        ZStack {
            shape
                .fill(MangaComicPalette.ink)
                .offset(x: shadow, y: shadow)

            shape.fill(fill)

            content()
                .clipShape(shape)

            MangaComicPaperTexture(opacity: fill == MangaComicPalette.ink ? 0.02 : 0.08)
                .clipShape(shape)

            shape.stroke(MangaComicPalette.ink, lineWidth: 3.2)

            if innerBorder {
                shape
                    .stroke(fill == MangaComicPalette.ink ? MangaComicPalette.paper : MangaComicPalette.ink, lineWidth: 1.15)
                    .padding(6)
            }
        }
    }
}

struct MangaComicRibbon: View {
    let text: String
    var fill: Color = MangaComicPalette.ink
    var foreground: Color = MangaComicPalette.whiteInk
    var scale: CGFloat = 1

    var body: some View {
        Text(text)
            .font(MangaComicPalette.headlineFont(15 * scale))
            .foregroundStyle(foreground)
            .lineLimit(1)
            .padding(.leading, 18 * scale)
            .padding(.trailing, 14 * scale)
            .padding(.vertical, 7 * scale)
            .background(MangaComicRibbonShape().fill(fill))
            .overlay(MangaComicRibbonShape().stroke(MangaComicPalette.ink, lineWidth: 2.2))
            .background(
                MangaComicRibbonShape()
                    .fill(MangaComicPalette.toneMid)
                    .offset(x: 2.5, y: 2.5)
            )
            .rotationEffect(.degrees(-2), anchor: .leading)
    }
}

/// 章节头：墨黑方块话数 + 大黑标题 + 排线延伸 + 反白「查看全部」。
struct MangaComicSectionHeader: View {
    let title: String
    var number: Int = 0
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            if number > 0 {
                Text(String(format: "%02d", number))
                    .font(MangaComicPalette.headlineFont(15))
                    .foregroundStyle(MangaComicPalette.whiteInk)
                    .monospacedDigit()
                    .frame(width: 34, height: 34)
                    .background(MangaComicCutCornerShape(cut: 6).fill(MangaComicPalette.ink))
                    .overlay(MangaComicCutCornerShape(cut: 6).stroke(MangaComicPalette.ink, lineWidth: 1.6))
                    .background(MangaComicCutCornerShape(cut: 6).fill(MangaComicPalette.toneMid).offset(x: 2, y: 2))
                    .rotationEffect(.degrees(-2))
            }

            Text(title)
                .font(MangaComicPalette.displayFont(23))
                .foregroundStyle(MangaComicPalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            MangaHatching(opacity: 0.55, gap: 4.5, angle: 0, lineWidth: 1.1)
                .frame(height: 7)
                .frame(maxWidth: .infinity)
                .mask(
                    LinearGradient(
                        colors: [.black, .black.opacity(0.25)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            if let actionTitle, let action {
                Button(action: action) {
                    HStack(spacing: 4) {
                        Text(actionTitle)
                            .font(MangaComicPalette.headlineFont(12))
                        MonoIcon(icon: .chevronRight, size: 9, color: MangaComicPalette.whiteInk, lineWidth: 2)
                    }
                    .foregroundStyle(MangaComicPalette.whiteInk)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(MangaComicCutCornerShape(cut: 7).fill(MangaComicPalette.ink))
                    .overlay(MangaComicCutCornerShape(cut: 7).stroke(MangaComicPalette.ink, lineWidth: 2))
                    .background(MangaComicCutCornerShape(cut: 7).fill(MangaComicPalette.toneMid).offset(x: 2, y: 2))
                }
                .buttonStyle(MangaComicPressButtonStyle())
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(minHeight: 52)
    }
}

struct MangaComicRoundControl: View {
    let icon: MonoIcon.IconType
    var fill: Color = MangaComicPalette.ink
    var foreground: Color = MangaComicPalette.whiteInk
    var size: CGFloat = 46

    var body: some View {
        ZStack {
            Circle()
                .fill(MangaComicPalette.toneMid)
                .offset(x: 2.5, y: 2.5)
            Circle().fill(fill)
            Circle().stroke(MangaComicPalette.ink, lineWidth: 2.7)
            Circle().stroke(foreground.opacity(0.65), lineWidth: 1).padding(5)
            MonoIcon(icon: icon, size: size * 0.34, color: foreground, lineWidth: 2.4)
        }
        .frame(width: size, height: size)
    }
}

struct MangaComicPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .rotationEffect(.degrees(configuration.isPressed ? -0.4 : 0))
            .animation(.spring(response: 0.22, dampingFraction: 0.62), value: configuration.isPressed)
    }
}
