import SwiftUI
import PawPrintIcons
import UIKit

/// 黏土玩具（Clay Toy）× 新拟物：整块奶油黏土，部件不是「贴上去的卡片」，
/// 而是从同一块黏土上凸起（双向大范围软阴影）或压凹（真内阴影）出来的形体。
/// 表面与背景同色系，形体全靠光影；马卡龙糖果色只出现在小块黏土和强调件上。
enum PetWhiteStyle {
    private static let fallbackBase = Color(light: Color(hex: "F3ECDF"), dark: Color(hex: "221D16"))
    private static let fallbackSurface = Color(light: Color(hex: "F5EEE2"), dark: Color(hex: "262019"))
    private static let fallbackSurfaceRaised = Color(light: Color(hex: "F7F0E4"), dark: Color(hex: "2A241C"))
    private static let fallbackSurfacePressed = Color(light: Color(hex: "EAE1D0"), dark: Color(hex: "1D1811"))
    private static let fallbackDogOrange = Color(light: Color(hex: "F59D54"), dark: Color(hex: "EBA660"))
    private static let fallbackDogEar = Color(light: Color(hex: "DE7E3B"), dark: Color(hex: "D08E48"))
    private static let fallbackMint = Color(light: Color(hex: "BEE5CE"), dark: Color(hex: "2E4A3F"))
    private static let fallbackBlush = Color(light: Color(hex: "F6ACA1"), dark: Color(hex: "DD9A85"))
    private static let fallbackButter = Color(light: Color(hex: "F9E4AE"), dark: Color(hex: "4A3E24"))
    private static let fallbackSky = Color(light: Color(hex: "C3DDF3"), dark: Color(hex: "2C3E50"))
    private static let fallbackLilac = Color(light: Color(hex: "DCD1F1"), dark: Color(hex: "3B3350"))

    static var isActive: Bool {
        GlobalThemeId.persistedOrDefault == .petWhite
    }

    static var base: Color {
        ThemeColorCustomization.backgroundBase(
            for: .petWhite,
            fallback: fallbackBase,
            fallbackHex: "FBF8F2"
        )
    }

    static var paper: Color { base }

    static var surface: Color { customBackgroundStop("start", fallback: fallbackSurface, fallbackHex: "FFFFFF") }
    static var surfaceRaised: Color { customBackgroundStop("end", fallback: fallbackSurfaceRaised, fallbackHex: "FFFDF9") }
    static var surfacePressed: Color { customBackgroundStop("stop3", fallback: fallbackSurfacePressed, fallbackHex: "F3EEE5") }
    static let ink = Color(light: Color(hex: "4A4136"), dark: Color(hex: "F1EAE0"))
    static let inkSoft = Color(light: Color(hex: "746A5C"), dark: Color(hex: "C4BBAC"))
    static let inkMuted = Color(light: Color(hex: "998E7E"), dark: Color(hex: "94897A"))
    /// 黏土语言几乎不用描边，边缘靠双向阴影塑形；此色仅作极淡的收边。文字/图标请用 `ink`。
    static let stroke = Color(light: Color(hex: "EFE8DA"), dark: Color(hex: "3B3529"))
    static let separator = Color(light: Color(hex: "EDE5D6"), dark: Color(hex: "332D24"))
    static let catWhite = Color(light: Color(hex: "FFFFFF"), dark: Color(hex: "F5F1E8"))
    /// 右下暗阴影：黏土从底面凸起时压出的暖棕落影（新拟物双向阴影的暗半）。
    static let shadowInk = Color(light: Color(hex: "C4AD8B"), dark: .black)
    /// 左上亮阴影：黏土受光面的奶白柔光（新拟物双向阴影的亮半）。
    static let clayLightShadow = Color(light: Color.white, dark: Color.white.opacity(0.05))
    /// 顶部高光：黏土表面的柔和反光带。
    static let glazeHighlight = Color(light: Color.white.opacity(0.7), dark: Color.white.opacity(0.05))
    /// 凹陷内壁的暗色（内阴影用，比落影更深一点）。
    static let clayCaveShadow = Color(light: Color(hex: "A98F68"), dark: .black)
    static var dogOrange: Color {
        ThemeColorCustomization.accentColor(
            for: .petWhite,
            fallback: fallbackDogOrange,
            fallbackHex: "EC9E44"
        )
    }
    static var dogEar: Color { customAccentTone(fallback: fallbackDogEar, fallbackHex: "CF8630") }
    static var mint: Color { customBackgroundStop("stop4", fallback: fallbackMint, fallbackHex: "DDEEE4") }
    static var blush: Color { customAccentTone(fallback: fallbackBlush, fallbackHex: "F0B4A6") }
    static var butter: Color { customBackgroundStop("stop3", fallback: fallbackButter, fallbackHex: "F6EBCC") }
    static var sky: Color { customBackgroundStop("end", fallback: fallbackSky, fallbackHex: "E0EAF4") }
    static var lilac: Color { customBackgroundStop("stop4", fallback: fallbackLilac, fallbackHex: "EAE5F4") }
    static let destructive = Color(light: Color(hex: "D95F4E"), dark: Color(hex: "F08A7A"))

    static var accent: Color {
        dogOrange
    }

    static var onAccent: Color {
        ThemeColorCustomization.readableForegroundColor(
            on: accent,
            light: Color(hex: "3D362D"),
            dark: Color(hex: "FFFFFF")
        )
    }

    static var accentGradient: [Color] {
        ThemeColorCustomization.accentGradientColors(
            for: .petWhite,
            fallback: [fallbackDogOrange, fallbackMint, fallbackBlush.opacity(0.78)],
            fallbackHexes: ["EC9E44", "DDEEE4", "F0B4A6"]
        )
    }

    static let strokeWidth: CGFloat = 1
    static let fineStrokeWidth: CGFloat = 0.75
    /// 黏土块：厚圆角家族。
    static let cardRadius: CGFloat = 28
    static let compactRadius: CGFloat = 18

    /// 黏土玩具字重：比瓷器版厚一点点，圆润但不喊话。
    private static func clayWeight(_ weight: Font.Weight) -> Font.Weight {
        switch weight {
        case .black, .heavy: return .bold
        default: return weight
        }
    }

    static func titleFont(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: clayWeight(weight), design: .rounded)
    }

    static func bodyFont(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: clayWeight(weight), design: .rounded)
    }

    static func labelFont(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: clayWeight(weight), design: .rounded)
    }

    static func tabTint(_ index: Int) -> Color {
        switch index {
        case 0: return dogOrange
        case 1: return mint
        case 2: return sky
        default: return blush.opacity(0.86)
        }
    }

    private static func customBackgroundStop(_ suffix: String, fallback: Color, fallbackHex: String) -> Color {
        guard ThemeColorCustomization.customColorsEnabled else { return fallback }
        let resolvedSuffix = ThemeColorCustomization.mode(for: .petWhite, role: .background) == .solid ? "solid" : suffix
        return Color(hex: ThemeColorCustomization.hex(.petWhite, .background, resolvedSuffix, fallback: fallbackHex))
    }

    private static func customAccentTone(fallback: Color, fallbackHex: String) -> Color {
        guard ThemeColorCustomization.customColorsEnabled else { return fallback }
        if ThemeColorCustomization.hasStoredAccent(for: .petWhite) {
            return ThemeColorCustomization.accentColor(for: .petWhite, fallback: fallback, fallbackHex: fallbackHex)
        }
        return fallback
    }
}

struct PetWhiteRootBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        let _ = settings.globalThemeRevision

        ZStack {
            PetWhiteStyle.paper

            if settings.petWhiteUsesIllustratedBackground {
                PetWhiteIllustratedBackdrop()

                Color.white
                    .opacity(colorScheme == .dark ? 0.02 : 0.10)
            } else {
                PetWhiteBackdropWash()
                    .opacity(colorScheme == .dark ? 0.30 : 1)

                PetWhitePawPattern()
                    .opacity(colorScheme == .dark ? 0.24 : 0.55)
            }
        }
        .ignoresSafeArea()
    }
}

private struct PetWhiteIllustratedBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            illustratedImage
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var illustratedImage: some View {
        let assetName = colorScheme == .dark ? "pawThemeBackgroundDark" : "pawThemeBackground"

        if let image = UIImage(pawPrintIconId: assetName) {
            Image(uiImage: image)
                .renderingMode(.original)
                .resizable()
                .scaledToFill()
        } else {
            PetWhiteBackdropWash()
        }
    }
}

private struct PetWhiteBackdropWash: View {
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height

            // 新拟物黏土底：形体交给光影，底色只留极淡的暖光呼吸，
            // 左上一点奶白受光、右下一点暖棕收暗，加两抹几乎不可见的糖果晕。
            ZStack {
                Circle()
                    .fill(PetWhiteStyle.clayLightShadow.opacity(0.5))
                    .frame(width: w * 1.1)
                    .position(x: w * 0.02, y: -h * 0.02)
                    .blur(radius: 90)

                Circle()
                    .fill(PetWhiteStyle.shadowInk.opacity(0.16))
                    .frame(width: w * 1.0)
                    .position(x: w * 1.02, y: h * 1.02)
                    .blur(radius: 100)

                Circle()
                    .fill(PetWhiteStyle.butter.opacity(0.18))
                    .frame(width: w * 0.7)
                    .position(x: w * 0.88, y: h * 0.12)
                    .blur(radius: 80)

                Circle()
                    .fill(PetWhiteStyle.sky.opacity(0.12))
                    .frame(width: w * 0.6)
                    .position(x: w * 0.10, y: h * 0.72)
                    .blur(radius: 80)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct PetWhitePawPattern: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Canvas(rendersAsynchronously: true) { context, size in
            let pawColor = PetWhiteStyle.ink.opacity(colorScheme == .dark ? 0.05 : 0.035)
            let accentColor = PetWhiteStyle.dogOrange.opacity(colorScheme == .dark ? 0.04 : 0.045)
            let stepX: CGFloat = 118
            let stepY: CGFloat = 146

            var row = 0
            var y: CGFloat = 18
            while y < size.height + stepY {
                var x: CGFloat = row.isMultiple(of: 2) ? 20 : 76
                while x < size.width + stepX {
                    context.drawLayer { layer in
                        layer.translateBy(x: x, y: y)
                        layer.rotate(by: .degrees(row.isMultiple(of: 2) ? -10 : 12))
                        drawPaw(in: &layer, color: row.isMultiple(of: 3) ? accentColor : pawColor)
                    }
                    x += stepX
                }
                row += 1
                y += stepY
            }
        }
        .blendMode(colorScheme == .dark ? .screen : .multiply)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawPaw(in context: inout GraphicsContext, color: Color) {
        context.fill(Path(ellipseIn: CGRect(x: 8, y: 14, width: 18, height: 13)), with: .color(color))

        [
            CGRect(x: 0, y: 7, width: 7, height: 9),
            CGRect(x: 8, y: 1, width: 7, height: 9),
            CGRect(x: 18, y: 1, width: 7, height: 9),
            CGRect(x: 27, y: 7, width: 7, height: 9),
        ].forEach { rect in
            context.fill(Path(ellipseIn: rect), with: .color(color))
        }
    }
}

/// 新拟物内阴影：把形体「压进」黏土里。
/// 用暗描边（左上）+ 亮描边（右下）各自模糊后裁剪进形状，模拟真实凹陷。
struct PetWhiteClayInnerShadow<S: Shape>: View {
    var shape: S
    var depth: CGFloat = 3

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            shape
                .stroke(PetWhiteStyle.clayCaveShadow.opacity(colorScheme == .dark ? 0.85 : 0.55), lineWidth: depth)
                .blur(radius: depth * 1.1)
                .offset(x: depth * 0.8, y: depth * 0.8)

            shape
                .stroke(PetWhiteStyle.clayLightShadow.opacity(colorScheme == .dark ? 0.10 : 0.95), lineWidth: depth)
                .blur(radius: depth * 1.1)
                .offset(x: -depth * 0.8, y: -depth * 0.8)
        }
        .clipShape(shape)
        .allowsHitTesting(false)
    }
}

struct PetWhiteSurfaceBackground: View {
    var cornerRadius: CGFloat = PetWhiteStyle.cardRadius
    var elevated = true
    var tint: Color = PetWhiteStyle.surfaceRaised
    var accent: Color = PetWhiteStyle.mint

    @ObservedObject private var settings = SettingsManager.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let _ = settings.globalThemeRevision
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let fillOpacity = settings.petWhiteUsesIllustratedBackground ? (elevated ? 0.90 : 0.84) : 1

        shape
            // 与底同色系的黏土面：左上偏亮、右下微暗，形体来自光照而非色差
            .fill(
                LinearGradient(
                    colors: [
                        tint.opacity(fillOpacity),
                        PetWhiteStyle.surface.opacity(fillOpacity * 0.97),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            // 受光棱线：左上边缘一道细亮边，像黏土转角接住光
            .overlay(
                shape
                    .stroke(
                        LinearGradient(
                            colors: [
                                PetWhiteStyle.clayLightShadow.opacity(colorScheme == .dark ? 0.10 : 0.9),
                                PetWhiteStyle.shadowInk.opacity(colorScheme == .dark ? 0.5 : 0.16),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: elevated ? 1.1 : 0.8
                    )
                    .allowsHitTesting(false)
            )
            // 新拟物双向大范围软阴影：左上亮 / 右下暗，凸起是「挤」出来的
            .shadow(
                color: PetWhiteStyle.clayLightShadow.opacity(colorScheme == .dark ? 0.04 : (elevated ? 0.95 : 0.75)),
                radius: elevated ? 12 : 7,
                x: elevated ? -8 : -5,
                y: elevated ? -8 : -5
            )
            .shadow(
                color: PetWhiteStyle.shadowInk.opacity(colorScheme == .dark ? 0.6 : (elevated ? 0.55 : 0.38)),
                radius: elevated ? 14 : 8,
                x: elevated ? 9 : 6,
                y: elevated ? 10 : 6
            )
    }
}

struct PetWhiteFrostedFloatingSurface<SurfaceShape: Shape>: View {
    var shape: SurfaceShape
    var tint: Color = PetWhiteStyle.surfaceRaised
    var accent: Color = PetWhiteStyle.mint
    var strokeColor: Color = PetWhiteStyle.stroke
    var lineWidth: CGFloat = PetWhiteStyle.fineStrokeWidth
    var elevated = true

    @ObservedObject private var settings = SettingsManager.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let _ = settings.globalThemeRevision
        let tintOpacity = settings.petWhiteUsesIllustratedBackground
            ? (elevated ? 0.90 : 0.86)
            : (colorScheme == .dark ? 0.96 : 0.98)
        let materialOpacity = colorScheme == .dark ? 0.18 : 0.10

        shape
            .fill(.ultraThinMaterial)
            .opacity(materialOpacity)
            .overlay(
                shape.fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(tintOpacity),
                            PetWhiteStyle.surface.opacity(tintOpacity * 0.97),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            )
            .overlay(
                shape
                    .stroke(
                        LinearGradient(
                            colors: [
                                PetWhiteStyle.clayLightShadow.opacity(colorScheme == .dark ? 0.10 : 0.9),
                                PetWhiteStyle.shadowInk.opacity(colorScheme == .dark ? 0.5 : 0.16),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.1
                    )
            )
            .shadow(
                color: PetWhiteStyle.clayLightShadow.opacity(colorScheme == .dark ? 0.04 : 0.95),
                radius: elevated ? 12 : 7,
                x: -8,
                y: -8
            )
            .shadow(
                color: PetWhiteStyle.shadowInk.opacity(colorScheme == .dark ? 0.6 : (elevated ? 0.55 : 0.4)),
                radius: elevated ? 15 : 9,
                x: 9,
                y: 10
            )
    }
}

struct PetWhitePageHeader<Accessory: View>: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let icon: MonologueIcon.IconType
    let accessory: Accessory

    init(
        eyebrow: String,
        title: String,
        subtitle: String = "",
        icon: MonologueIcon.IconType = .catLife,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.accessory = accessory()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            PetWhitePetPetIcon(size: 64)

            VStack(alignment: .leading, spacing: 5) {
                Text(eyebrow.uppercased())
                    .font(PetWhiteStyle.labelFont(11, weight: .semibold))
                    .tracking(1.6)
                    .foregroundStyle(PetWhiteStyle.dogEar)

                Text(title)
                    .font(PetWhiteStyle.titleFont(30, weight: .bold))
                    .foregroundStyle(PetWhiteStyle.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(PetWhiteStyle.bodyFont(13))
                        .foregroundStyle(PetWhiteStyle.inkSoft)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)

            accessory
        }
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
        .padding(.top, DeviceLayout.headerTopPadding + 6)
        .padding(.bottom, 14)
    }
}

extension PetWhitePageHeader where Accessory == EmptyView {
    init(
        eyebrow: String,
        title: String,
        subtitle: String = "",
        icon: MonologueIcon.IconType = .catLife
    ) {
        self.init(eyebrow: eyebrow, title: title, subtitle: subtitle, icon: icon) {
            EmptyView()
        }
    }
}

struct PetWhitePackIcon: View {
    let icon: MonologueIcon.IconType
    var size: CGFloat = 24
    var visualScale: CGFloat = 1
    var fallbackColor: Color = PetWhiteStyle.ink
    var lineWidth: CGFloat?

    var body: some View {
        MonologueIcon(
            icon: icon,
            size: size,
            color: fallbackColor,
            lineWidth: lineWidth ?? max(1.5, size * 0.042)
        )
        .scaleEffect(visualScale)
        .accessibilityHidden(true)
    }
}

struct PetWhiteSpinningCoverDisc: View {
    let coverURL: URL?
    var size: CGFloat
    var isPlaying: Bool
    var strokeWidth: CGFloat = 1.4

    @State private var rotationAngle: Double = 0
    @State private var lastTickDate: Date?

    var body: some View {
        TimelineView(AppFrameRate.animationTimeline(maximumFramesPerSecond: 30, paused: !isPlaying)) { timeline in
            disc
                .rotationEffect(.degrees(rotationAngle))
                .onChange(of: timeline.date) { _, newDate in
                    guard isPlaying else {
                        lastTickDate = nil
                        return
                    }

                    if let lastTickDate {
                        rotationAngle += newDate.timeIntervalSince(lastTickDate) * 42
                    }
                    lastTickDate = newDate
                }
        }
        .frame(width: size, height: size)
        .onChange(of: isPlaying) { _, playing in
            if !playing {
                lastTickDate = nil
            }
        }
        .accessibilityHidden(true)
    }

    private var disc: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "171615"))

            Circle()
                .stroke(PetWhiteStyle.surfaceRaised.opacity(0.24), lineWidth: max(0.5, size * 0.018))
                .padding(size * 0.13)

            Circle()
                .stroke(PetWhiteStyle.butter.opacity(0.20), lineWidth: max(0.45, size * 0.014))
                .padding(size * 0.24)

            coverImage
                .frame(width: size * 0.54, height: size * 0.54)
                .clipShape(Circle())

            Circle()
                .fill(PetWhiteStyle.surfaceRaised)
                .frame(width: size * 0.14, height: size * 0.14)
                .overlay(Circle().stroke(PetWhiteStyle.stroke, lineWidth: max(0.7, strokeWidth * 0.62)))
        }
        .overlay(Circle().stroke(PetWhiteStyle.stroke, lineWidth: strokeWidth))
        .clipShape(Circle())
    }

    @ViewBuilder
    private var coverImage: some View {
        if let coverURL {
            CachedAsyncImage(url: coverURL, width: size * 0.54, height: size * 0.54) {
                coverPlaceholder
            }
            .aspectRatio(contentMode: .fill)
        } else {
            coverPlaceholder
        }
    }

    private var coverPlaceholder: some View {
        Circle()
            .fill(PetWhiteStyle.surfacePressed)
            .overlay(
                MonologueIcon(icon: .musicNote, size: size * 0.20, color: PetWhiteStyle.inkMuted, lineWidth: 1.6)
            )
    }
}

struct PetWhiteSelectedLyricToggleIcon: View {
    let assetName: String
    var size: CGFloat = 22

    var body: some View {
        assetImage
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var assetImage: some View {
        if let image = UIImage(pawPrintIconId: assetName) {
            Image(uiImage: image)
                .renderingMode(.original)
                .interpolation(.high)
                .antialiased(true)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Color.clear
        }
    }
}

struct PetWhiteChevronIcon: View {
    enum Direction {
        case up
        case down

        var assetName: String {
            switch self {
            case .up: return "chevronUp"
            case .down: return "chevronDown"
            }
        }

        var fallbackIcon: MonologueIcon.IconType {
            switch self {
            case .up: return .chevronUp
            case .down: return .chevronDown
            }
        }
    }

    let direction: Direction
    var size: CGFloat = 18
    var fallbackColor: Color = PetWhiteStyle.ink

    var body: some View {
        chevronImage
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var chevronImage: some View {
        if let image = UIImage(pawPrintIconId: direction.assetName) {
            Image(uiImage: image)
                .renderingMode(.original)
                .interpolation(.high)
                .antialiased(true)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            fallbackChevron
        }
    }

    private var fallbackChevron: some View {
        MonologueIcon(icon: direction.fallbackIcon, size: size, color: fallbackColor)
    }
}

struct PetWhiteDisclosureChevron: View {
    let isExpanded: Bool
    var size: CGFloat = 11
    var petWhiteSize: CGFloat?
    var color: Color = .monologueTextSecondary.opacity(0.8)
    var lineWidth: CGFloat = 1.7

    var body: some View {
        if PetWhiteStyle.isActive {
            PetWhiteChevronIcon(
                direction: isExpanded ? .up : .down,
                size: petWhiteSize ?? max(17, size * 1.7),
                fallbackColor: color
            )
            .animation(.interactiveSpring(response: 0.32, dampingFraction: 0.93, blendDuration: 0.04), value: isExpanded)
        } else {
            MonologueIcon(icon: .chevronRight, size: size, color: color, lineWidth: lineWidth)
                .rotationEffect(.degrees(isExpanded ? -90 : 90))
                .animation(.interactiveSpring(response: 0.32, dampingFraction: 0.93, blendDuration: 0.04), value: isExpanded)
        }
    }
}

struct PetWhiteFloatingSignature: View {
    var compact = false
    var tint: Color = PetWhiteStyle.mint

    var body: some View {
        HStack(spacing: compact ? 4 : 6) {
            Capsule()
                .fill(PetWhiteStyle.dogOrange)
                .frame(width: compact ? 20 : 28, height: compact ? 3 : 4)

            Capsule()
                .fill(tint)
                .frame(width: compact ? 12 : 18, height: compact ? 3 : 4)

            PetWhiteProfileHeadIcon(filled: true, size: compact ? 13 : 16)
        }
        .padding(.horizontal, compact ? 7 : 9)
        .padding(.vertical, compact ? 4 : 5)
        .background(
            Capsule(style: .continuous)
                .fill(PetWhiteStyle.surfaceRaised)
                .overlay(Capsule(style: .continuous).stroke(PetWhiteStyle.separator, lineWidth: 1))
        )
        .accessibilityHidden(true)
    }
}

struct PetWhiteFloatingMascotDot: View {
    var filled = false
    var tint: Color = PetWhiteStyle.mint
    var size: CGFloat = 22

    var body: some View {
        Circle()
            .fill(tint)
            .frame(width: size, height: size)
            .overlay(
                PetWhiteProfileHeadIcon(filled: filled, size: size * 0.72)
            )
            .overlay(Circle().stroke(PetWhiteStyle.stroke, lineWidth: max(1.2, size * 0.06)))
            .accessibilityHidden(true)
    }
}

struct PetWhiteFloatingBowTie: View {
    var body: some View {
        HStack(spacing: -1) {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(PetWhiteStyle.dogOrange)
                .frame(width: 20, height: 9)
                .rotationEffect(.degrees(-8))

            Circle()
                .fill(PetWhiteStyle.surfaceRaised)
                .frame(width: 10, height: 10)
                .overlay(Circle().stroke(PetWhiteStyle.stroke, lineWidth: 1.1))

            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(PetWhiteStyle.mint)
                .frame(width: 20, height: 9)
                .rotationEffect(.degrees(8))
        }
        .overlay(
            Capsule(style: .continuous)
                .stroke(PetWhiteStyle.stroke, lineWidth: 1.1)
        )
        .accessibilityHidden(true)
    }
}

struct PetWhitePetPetIcon: View {
    var size: CGFloat = 78

    var body: some View {
        petPetImage
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var petPetImage: some View {
        if let image = UIImage(pawPrintIconId: "petPet") {
            Image(uiImage: image)
                .renderingMode(.original)
                .interpolation(.high)
                .antialiased(true)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            PetWhiteMascotMark(kind: .pair, size: size)
        }
    }
}

struct PetWhitePetPetHeroIcon: View {
    var width: CGFloat = 132

    private var height: CGFloat {
        width * 2 / 3
    }

    var body: some View {
        petPetHeroImage
            .frame(width: width, height: height)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var petPetHeroImage: some View {
        if let image = UIImage(pawPrintIconId: "petPetHero") {
            Image(uiImage: image)
                .renderingMode(.original)
                .interpolation(.high)
                .antialiased(true)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            PetWhitePetPetIcon(size: min(width, height))
        }
    }
}

/// 小黏土块：与底同料的凸起（或糖果色强调件），
/// `pressedLook = true` 时切换为真内阴影的凹陷态 —— 像用指头把它按进黏土里。
struct PetWhiteClayPuck<S: Shape>: View {
    var shape: S
    var tint: Color = PetWhiteStyle.mint
    var pressedLook = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if pressedLook {
            // 凹陷态：填色压暗一档 + 内阴影，无外阴影
            shape
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(colorScheme == .dark ? 0.8 : 0.9),
                            tint,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(PetWhiteClayInnerShadow(shape: shape, depth: 2.6))
        } else {
            // 凸起态：左上亮右下暗的双向阴影 + 受光棱线
            shape
                .fill(
                    LinearGradient(
                        colors: [
                            tint,
                            tint.opacity(colorScheme == .dark ? 0.88 : 0.94),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    shape
                        .stroke(
                            LinearGradient(
                                colors: [
                                    PetWhiteStyle.clayLightShadow.opacity(colorScheme == .dark ? 0.08 : 0.8),
                                    PetWhiteStyle.shadowInk.opacity(colorScheme == .dark ? 0.4 : 0.14),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.9
                        )
                        .allowsHitTesting(false)
                )
                .shadow(
                    color: PetWhiteStyle.clayLightShadow.opacity(colorScheme == .dark ? 0.04 : 0.9),
                    radius: 5, x: -4, y: -4
                )
                .shadow(
                    color: PetWhiteStyle.shadowInk.opacity(colorScheme == .dark ? 0.5 : 0.45),
                    radius: 6, x: 4, y: 5
                )
        }
    }
}

struct PetWhiteIconBadge: View {
    let icon: MonologueIcon.IconType
    var tint: Color = PetWhiteStyle.mint
    var size: CGFloat = 48

    var body: some View {
        PetWhiteClayPuck(
            shape: RoundedRectangle(cornerRadius: max(13, size * 0.36), style: .continuous),
            tint: tint
        )
        .frame(width: size, height: size)
        .overlay(
            PetWhitePackIcon(
                icon: icon,
                size: size * 0.5,
                visualScale: 1.04,
                lineWidth: max(1.6, size * 0.038)
            )
        )
    }
}

struct PetWhiteAssetIconBadge: View {
    let assetName: String
    var tint: Color = PetWhiteStyle.mint
    var size: CGFloat = 48
    var assetScale: CGFloat = 0.72

    var body: some View {
        PetWhiteClayPuck(
            shape: RoundedRectangle(cornerRadius: max(13, size * 0.36), style: .continuous),
            tint: tint
        )
        .frame(width: size, height: size)
        .overlay(
            PetWhiteSelectedLyricToggleIcon(assetName: assetName, size: size * assetScale)
        )
    }
}

struct PetWhitePill: View {
    let text: String
    var tint: Color = PetWhiteStyle.mint

    var body: some View {
        Text(text)
            .font(PetWhiteStyle.labelFont(10, weight: .bold))
            .foregroundStyle(PetWhiteStyle.ink)
            .tracking(0.8)
            .lineLimit(1)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(
                PetWhiteClayPuck(shape: Capsule(style: .continuous), tint: tint)
            )
    }
}

struct PetWhiteSectionTitle: View {
    let title: String
    var detail: String?
    var icon: MonologueIcon.IconType = .catLife
    var assetName: String?
    var tint: Color = PetWhiteStyle.mint
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(PetWhiteStyle.titleFont(20, weight: .bold))
                    .foregroundStyle(PetWhiteStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(PetWhiteStyle.labelFont(11))
                        .foregroundStyle(PetWhiteStyle.inkMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
            }

            Spacer(minLength: 8)

            if let action {
                Button(action: action) {
                    HStack(spacing: 3) {
                        Text(LocalizedStringKey("view_all"))
                            .font(PetWhiteStyle.labelFont(12, weight: .semibold))

                        PetWhitePackIcon(icon: .chevronRight, size: 12, visualScale: 1, fallbackColor: PetWhiteStyle.dogEar)
                    }
                    .foregroundStyle(PetWhiteStyle.dogEar)
                }
                .buttonStyle(PetWhiteSquishyButtonStyle(scale: 0.92))
            }
        }
    }
}

struct PetWhitePawPrint: View {
    var size: CGFloat = 26
    var tint: Color = PetWhiteStyle.ink.opacity(0.10)

    var body: some View {
        ZStack {
            Ellipse()
                .fill(tint)
                .frame(width: size * 0.48, height: size * 0.34)
                .offset(y: size * 0.16)

            ForEach(0..<4, id: \.self) { index in
                Ellipse()
                    .fill(tint)
                    .frame(width: size * 0.22, height: size * 0.27)
                    .offset(x: toeOffset(index).x, y: toeOffset(index).y)
            }
        }
        .frame(width: size, height: size)
    }

    private func toeOffset(_ index: Int) -> CGPoint {
        let positions = [
            CGPoint(x: -0.34, y: -0.04),
            CGPoint(x: -0.12, y: -0.24),
            CGPoint(x: 0.12, y: -0.24),
            CGPoint(x: 0.34, y: -0.04),
        ]
        return CGPoint(x: positions[index].x * size, y: positions[index].y * size)
    }
}

struct PetWhiteMascotMark: View {
    enum Kind {
        case cat
        case dog
        case pair
    }

    let kind: Kind
    var size: CGFloat = 54

    var body: some View {
        switch kind {
        case .cat:
            PetWhiteProfileHeadIcon(filled: false, size: size)
        case .dog:
            PetWhiteProfileHeadIcon(filled: true, size: size)
        case .pair:
            ZStack {
                PetWhiteProfileHeadIcon(filled: true, size: size * 0.78)
                    .offset(x: size * 0.24, y: -size * 0.02)
                PetWhiteProfileHeadIcon(filled: false, size: size * 0.80)
                    .offset(x: -size * 0.18, y: size * 0.08)
            }
            .frame(width: size * 1.22, height: size)
        }
    }
}

struct PetWhiteProfileHeadIcon: View {
    var filled = false
    var size: CGFloat = 48

    private var assetName: String {
        filled ? "profileFilledHead" : "profileHead"
    }

    var body: some View {
        headImage
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var headImage: some View {
        if let image = UIImage(pawPrintIconId: assetName) {
            Image(uiImage: image)
                .renderingMode(.original)
                .interpolation(.high)
                .antialiased(true)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            fallbackHead
        }
    }

    private var fallbackHead: some View {
        Circle()
            .fill(filled ? PetWhiteStyle.dogOrange.opacity(0.74) : PetWhiteStyle.catWhite)
            .overlay(Circle().stroke(PetWhiteStyle.stroke, lineWidth: max(1.7, size * 0.04)))
    }
}

struct PetWhiteDockSelectionBackground: View {
    var tint: Color = PetWhiteStyle.mint
    var isSelected: Bool = true
    var cornerRadius: CGFloat = 17

    var body: some View {
        if isSelected {
            // 选中 = 压进黏土里：内凹感（无外阴影、微暗、顶部反光收掉）
            PetWhiteClayPuck(
                shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
                tint: tint,
                pressedLook: true
            )
        } else {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.clear)
        }
    }
}

extension View {
    /// 新拟物双向软阴影：左上奶白受光 + 右下暖棕落影。
    /// 用于封面、头像等没有走 `PetWhiteSurfaceBackground` 的独立黏土件。
    func petWhiteClayShadow(elevated: Bool = true, colorScheme: ColorScheme = .light) -> some View {
        self
            .shadow(
                color: PetWhiteStyle.clayLightShadow.opacity(colorScheme == .dark ? 0.04 : (elevated ? 0.95 : 0.75)),
                radius: elevated ? 10 : 6,
                x: elevated ? -7 : -4,
                y: elevated ? -7 : -4
            )
            .shadow(
                color: PetWhiteStyle.shadowInk.opacity(colorScheme == .dark ? 0.55 : (elevated ? 0.5 : 0.36)),
                radius: elevated ? 13 : 7,
                x: elevated ? 8 : 5,
                y: elevated ? 9 : 6
            )
    }
}

/// 黏土按压手感：按下明显缩小并微微下沉，松手 Q 弹回来。
struct PetWhiteSquishyButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.9

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .offset(y: configuration.isPressed ? 1.5 : 0)
            .animation(
                configuration.isPressed
                    ? .spring(response: 0.18, dampingFraction: 0.7)
                    : .spring(response: 0.32, dampingFraction: 0.5),
                value: configuration.isPressed
            )
    }
}

extension View {
    @ViewBuilder
    func petWhiteNestedPage() -> some View {
        if PetWhiteStyle.isActive {
            self
                .background(PetWhiteRootBackdrop())
                .tint(PetWhiteStyle.accent)
                .toolbarBackground(.hidden, for: .navigationBar)
        } else {
            self
        }
    }
}
