import SwiftUI

// ============================================================
//  Folia 背景层移植（folia-major VisualizerShell 的舞台底座）
//  源：src/components/visualizer/FluidBackground.tsx
//      src/components/visualizer/GeometricBackground.tsx
//
//  - 流体背景：封面放大 1.5 倍 + 40pt 高斯模糊铺满全屏，
//    上叠 primary→transparent→secondary 对角渐变增强文字可读性
//  - 几何背景：15 个几何漂浮体（圆/方/三角/十字星，随机描边或填充）
//    做 30~60s 的慢速漂移 + 整周旋转，尺寸按分频能量伸缩
//    （圆→bass、方→energy、三角→mid、十字→treble）；
//    另有 20 颗上升微粒（accent 色，循环上浮 + 淡入淡出）
// ============================================================

// MARK: - 沉浸舞台风格选项

enum CinemaLyricStyle: String, CaseIterable {
    case folia      // folia 经典流光：三态散点词
    case cadenza    // folia 心象：英雄词词云 + 光束
    case partita    // folia 云阶：分行阶梯排布
    case tilt       // folia 倾诉：斜体强调分句
    case fume       // folia 浮名：整页文章 + 镜头追焦
    case cappella   // folia 群唱：聊天气泡叙事
    case monet      // folia 莫奈：海报布局 + 音频条
    case flash      // VJ 快闪：字素爆闪

    var label: String {
        switch self {
        case .folia: return "经典流光"
        case .cadenza: return "心象"
        case .partita: return "云阶"
        case .tilt: return "倾诉"
        case .fume: return "浮名"
        case .cappella: return "群唱"
        case .monet: return "莫奈"
        case .flash: return "VJ 快闪"
        }
    }

    /// 整幅舞台模式（原版 fume/cappella/monet 独占整个画布，不与粒子封面同屏）
    var isFullStage: Bool {
        switch self {
        case .fume, .cappella, .monet: return true
        default: return false
        }
    }

    var caption: String {
        switch self {
        case .folia: return "散点词布局 · 逐字辉光 · folia 移植"
        case .cadenza: return "英雄词词云 · 词底光束 · folia 移植"
        case .partita: return "阶梯分行 · 词穿行结构 · folia 移植"
        case .tilt: return "斜体强调 · 分句渐显 · folia 移植"
        case .fume: return "整页文章 · 镜头追焦印字 · folia 移植"
        case .cappella: return "聊天气泡 · 逐字打字叙事 · folia 移植"
        case .monet: return "海报排版 · 封面肖像 + 律动条 · folia 移植"
        case .flash: return "节拍爆闪 · RGB 分离 · 动力学排版"
        }
    }
}

enum CinemaBackgroundStyle: String, CaseIterable {
    case galaxy     // 星河粒子（Mineradio 移植）
    case fluid      // folia 流体弥散
    case geometric  // folia 流体 + 几何漂浮

    var label: String {
        switch self {
        case .galaxy: return "星河粒子"
        case .fluid: return "流体弥散"
        case .geometric: return "几何漂浮"
        }
    }

    var caption: String {
        switch self {
        case .galaxy: return "音频驱动星河 · Mineradio 移植"
        case .fluid: return "封面弥散流体 · folia 移植"
        case .geometric: return "流体 + 分频几何体 · folia 移植"
        }
    }
}

// MARK: - 流体背景（FluidBackground.tsx）

struct FoliaFluidBackground: View {
    let coverUrl: URL?
    let palette: VJPalette

    var body: some View {
        // aspect-fill 图片会把自身布局尺寸撑到溢出（横屏下方形封面按宽度铺满后
        // 高度溢出一倍多），进而把整个背景 ZStack 撑变形；必须用 GeometryReader
        // 显式钉死尺寸再裁切，让溢出只发生在绘制层
        GeometryReader { geo in
            ZStack {
                Color.black

                if let coverUrl {
                    CachedAsyncImage(url: coverUrl) {
                        Color.black
                    }
                    // 原版：object-cover + blur(40px) scale(1.5)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .scaleEffect(1.5)
                    .blur(radius: 40)
                } else {
                    palette.base.opacity(0.15)
                }

                // 对角渐变叠层（原版 to bottom right: primary → transparent → secondary，
                // opacity 0.4 + overlay 混合）
                LinearGradient(
                    colors: [
                        palette.accent.opacity(0.40),
                        .clear,
                        palette.base.opacity(0.34)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blendMode(.overlay)

                // 轻压暗保证前景可读：折过头弥散色就全没了（之前 0.42 把整层压成黑泥）
                Color.black.opacity(0.24)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .compositingGroup()
            .clipped()
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 几何背景（GeometricBackground.tsx）

struct FoliaGeometricBackground: View {
    let pulse: CinemaAudioPulse
    let palette: VJPalette
    let isPlaying: Bool
    /// 同一首歌图形布局稳定（原版 seed）
    let seed: Double

    private struct Shape {
        enum Kind: Int { case circle, square, triangle, cross }
        let kind: Kind
        let x: Double          // 0~1
        let y: Double          // 0~1
        let size: Double       // pt
        let duration: Double   // 漂移周期 s
        let delay: Double
        let opacity: Double
        let reverse: Bool
        let filled: Bool
        let rotation0: Double  // 初始角
    }

    private struct Mote {
        let size: Double
        let x: Double
        let y: Double
        let opacity: Double
        let duration: Double
        let delay: Double
    }

    private let shapes: [Shape]
    private let motes: [Mote]

    init(pulse: CinemaAudioPulse, palette: VJPalette, isPlaying: Bool, seed: Double) {
        self.pulse = pulse
        self.palette = palette
        self.isPlaying = isPlaying
        self.seed = seed

        func rand(_ i: Double) -> Double { FoliaLayoutBuilder.rand(seed, i) }

        // 原版：15 个图形，size 40~140，opacity 0.11~0.19，duration 30~60s
        self.shapes = (0..<15).map { i in
            let b = Double(i) * 13.7
            return Shape(
                kind: Shape.Kind(rawValue: Int(rand(b + 1) * 4) % 4) ?? .circle,
                x: rand(b + 2),
                y: rand(b + 3),
                size: 40 + rand(b + 4) * 100,
                duration: 30 + rand(b + 5) * 30,
                delay: rand(b + 6) * 5,
                // 原版 0.11~0.19 是桌面端数值，手机屏上叠在弥散层里几乎不可见，抬一档
                opacity: 0.16 + rand(b + 7) * 0.12,
                reverse: rand(b + 8) > 0.5,
                filled: rand(b + 9) < 0.3,
                rotation0: rand(b + 10) * 360
            )
        }

        // 原版：20 颗上升微粒，size 1~5，duration 15~35s
        self.motes = (0..<20).map { i in
            let b = 400 + Double(i) * 7.3
            return Mote(
                size: 1 + rand(b + 1) * 4,
                x: rand(b + 2),
                y: rand(b + 3),
                opacity: rand(b + 4) * 0.3,
                duration: 15 + rand(b + 5) * 20,
                delay: rand(b + 6) * 10
            )
        }
    }

    var body: some View {
        TimelineView(AppFrameRate.animationTimeline(
            maximumFramesPerSecond: isPlaying ? 30 : 15,
            paused: false
        )) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let snap = pulse.snapshot()

            Canvas { context, size in
                drawShapes(context: &context, size: size, t: t, snap: snap)
                drawMotes(context: &context, size: size, t: t)
            }
            .opacity(0.9)
        }
        .allowsHitTesting(false)
    }

    /// 分频伸缩（原版 useBandScale：spring([10,200]→[0.95,1.45])，
    /// 我们的 band 已是 0~1 平滑包络，直接线性映射）
    private func bandScale(for kind: Shape.Kind, snap: CinemaAudioPulse.Snapshot) -> Double {
        let band: Double
        switch kind {
        case .circle: band = snap.bass
        case .square: band = snap.energy
        case .triangle: band = snap.mid
        case .cross: band = snap.treble
        }
        return 0.95 + min(1, band) * 0.5
    }

    private func drawShapes(context: inout GraphicsContext, size: CGSize, t: Double, snap: CinemaAudioPulse.Snapshot) {
        let shapeColor = palette.base

        for s in shapes {
            // 漂移（原版 keyframes y ±30 / x ∓15 / rotate 360°，linear 循环）
            let phase = ((t + s.delay).truncatingRemainder(dividingBy: s.duration)) / s.duration
            let wave = sin(phase * 2 * .pi)
            let dy = (s.reverse ? -30.0 : 30.0) * wave
            let dx = (s.reverse ? 15.0 : -15.0) * wave
            let rotation = s.rotation0 + phase * 360
            let scale = bandScale(for: s.kind, snap: snap)

            let side = s.size * scale
            let cx = s.x * size.width + dx
            let cy = s.y * size.height + dy
            let rect = CGRect(x: -side / 2, y: -side / 2, width: side, height: side)

            var layer = context
            layer.translateBy(x: cx, y: cy)
            layer.rotate(by: .degrees(rotation))
            layer.opacity = s.opacity

            switch s.kind {
            case .circle:
                let path = Path(ellipseIn: rect)
                if s.filled {
                    layer.fill(path, with: .color(shapeColor))
                } else {
                    layer.stroke(path, with: .color(shapeColor), lineWidth: 1.4)
                }
            case .square:
                let path = Path(rect)
                if s.filled {
                    layer.fill(path, with: .color(shapeColor))
                } else {
                    layer.stroke(path, with: .color(shapeColor), lineWidth: 1.4)
                }
            case .triangle:
                // clip-path: polygon(50% 0%, 0% 100%, 100% 100%)
                var path = Path()
                path.move(to: CGPoint(x: 0, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                path.closeSubpath()
                layer.fill(path, with: .color(shapeColor))
            case .cross:
                // clip-path 十二点十字星
                let pts: [(Double, Double)] = [
                    (0.2, 0.0), (0.0, 0.2), (0.3, 0.5), (0.0, 0.8), (0.2, 1.0), (0.5, 0.7),
                    (0.8, 1.0), (1.0, 0.8), (0.7, 0.5), (1.0, 0.2), (0.8, 0.0), (0.5, 0.3)
                ]
                var path = Path()
                for (i, p) in pts.enumerated() {
                    let point = CGPoint(x: rect.minX + p.0 * side, y: rect.minY + p.1 * side)
                    if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
                }
                path.closeSubpath()
                layer.fill(path, with: .color(shapeColor))
            }
        }
    }

    private func drawMotes(context: inout GraphicsContext, size: CGSize, t: Double) {
        for m in motes {
            // 原版：y 0→-100、opacity 0→peak→0，linear 循环
            let phase = ((t + m.delay).truncatingRemainder(dividingBy: m.duration)) / m.duration
            let rise = -100.0 * phase
            let fade = phase < 0.5 ? phase * 2 : (1 - phase) * 2
            let alpha = m.opacity * fade
            guard alpha > 0.004 else { continue }

            let rect = CGRect(
                x: m.x * size.width - m.size / 2,
                y: m.y * size.height + rise - m.size / 2,
                width: m.size,
                height: m.size
            )
            context.opacity = alpha
            context.fill(Path(ellipseIn: rect), with: .color(palette.accent))
        }
        context.opacity = 1
    }
}

// MARK: - 沉浸舞台设置面板

struct CinemaStageSettingsSheet: View {
    @AppStorage("cinemaLyricStyle") private var lyricStyleRaw = CinemaLyricStyle.folia.rawValue
    @AppStorage("cinemaBackgroundStyle") private var backgroundStyleRaw = CinemaBackgroundStyle.galaxy.rawValue

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                Text("沉浸舞台")
                    .font(.rounded(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 6)

                section(title: "歌词效果") {
                    ForEach(CinemaLyricStyle.allCases, id: \.rawValue) { style in
                        optionRow(
                            label: style.label,
                            caption: style.caption,
                            selected: lyricStyleRaw == style.rawValue
                        ) {
                            lyricStyleRaw = style.rawValue
                        }
                    }
                }

                section(title: "背景效果") {
                    ForEach(CinemaBackgroundStyle.allCases, id: \.rawValue) { style in
                        optionRow(
                            label: style.label,
                            caption: style.caption,
                            selected: backgroundStyleRaw == style.rawValue
                        ) {
                            backgroundStyleRaw = style.rawValue
                        }
                    }
                    Text("绑定视频背景时优先播放视频")
                        .font(.rounded(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.top, 2)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        // 面板文字为白色，底色必须固定深色：monologueSheet 的表面色跟随主题，
        // 浅色主题下是白底，会变成"白字白底"什么都看不见
        .background(
            LinearGradient(
                colors: [Color(red: 0.07, green: 0.07, blue: 0.09), Color(red: 0.10, green: 0.10, blue: 0.13)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private func section(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.rounded(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
            content()
        }
    }

    private func optionRow(label: String, caption: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { action() }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(label)
                        .font(.rounded(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Text(caption)
                        .font(.rounded(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.45))
                }
                Spacer()
                if selected {
                    MonologueIcon(icon: .checkmark, size: 17, color: .monologueAccent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(selected ? 0.10 : 0.045))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(selected ? Color.monologueAccent.opacity(0.55) : Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(MonologueBouncingButtonStyle())
    }
}
