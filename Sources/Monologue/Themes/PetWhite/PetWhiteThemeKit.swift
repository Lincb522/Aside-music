import SwiftUI
import PawPrintIcons

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum PetWhiteStyle {
    private static let fallbackBase = Color(light: .white, dark: Color(hex: "121315"))
    private static let fallbackSurface = Color(light: Color(hex: "FFFFFF"), dark: Color(hex: "191B1F"))
    private static let fallbackSurfaceRaised = Color(light: Color(hex: "FFFFFF"), dark: Color(hex: "202328"))
    private static let fallbackSurfacePressed = Color(light: Color(hex: "F6F7F8"), dark: Color(hex: "272A30"))
    private static let fallbackDogOrange = Color(light: Color(hex: "F6A93B"), dark: Color(hex: "F3B45B"))
    private static let fallbackDogEar = Color(light: Color(hex: "E08A24"), dark: Color(hex: "C97821"))
    private static let fallbackMint = Color(light: Color(hex: "DDF5EE"), dark: Color(hex: "20463E"))
    private static let fallbackBlush = Color(light: Color(hex: "FF8D7E"), dark: Color(hex: "FFB0A6"))
    private static let fallbackButter = Color(light: Color(hex: "FFF1BF"), dark: Color(hex: "4B4020"))
    private static let fallbackSky = Color(light: Color(hex: "EAF3FF"), dark: Color(hex: "203349"))
    private static let fallbackLilac = Color(light: Color(hex: "F0ECFF"), dark: Color(hex: "332B4F"))

    static var isActive: Bool {
        GlobalThemeId.persistedOrDefault == .petWhite
    }

    static var base: Color {
        ThemeColorCustomization.backgroundBase(
            for: .petWhite,
            fallback: fallbackBase,
            fallbackHex: "FFFFFF"
        )
    }

    static var paper: Color { base }

    static var surface: Color { customBackgroundStop("start", fallback: fallbackSurface, fallbackHex: "FFFFFF") }
    static var surfaceRaised: Color { customBackgroundStop("end", fallback: fallbackSurfaceRaised, fallbackHex: "F7F8FA") }
    static var surfacePressed: Color { customBackgroundStop("stop3", fallback: fallbackSurfacePressed, fallbackHex: "F6F7F8") }
    static let ink = Color(light: Color(hex: "111111"), dark: Color(hex: "FAFAFA"))
    static let inkSoft = Color(light: Color(hex: "4B5563"), dark: Color(hex: "D1D5DB"))
    static let inkMuted = Color(light: Color(hex: "8B95A1"), dark: Color(hex: "9CA3AF"))
    static let stroke = Color(light: Color(hex: "111111"), dark: Color(hex: "F8FAFC"))
    static let separator = Color(light: Color(hex: "E7E9EC"), dark: Color(hex: "343942"))
    static let catWhite = Color(light: Color(hex: "FFFFFF"), dark: Color(hex: "F5F7FA"))
    static var dogOrange: Color {
        ThemeColorCustomization.accentColor(
            for: .petWhite,
            fallback: fallbackDogOrange,
            fallbackHex: "F6A93B"
        )
    }
    static var dogEar: Color { customAccentTone(fallback: fallbackDogEar, fallbackHex: "E08A24") }
    static var mint: Color { customBackgroundStop("stop4", fallback: fallbackMint, fallbackHex: "DDF5EE") }
    static var blush: Color { customAccentTone(fallback: fallbackBlush, fallbackHex: "FF8D7E") }
    static var butter: Color { customBackgroundStop("stop3", fallback: fallbackButter, fallbackHex: "FFF1BF") }
    static var sky: Color { customBackgroundStop("end", fallback: fallbackSky, fallbackHex: "EAF3FF") }
    static var lilac: Color { customBackgroundStop("stop4", fallback: fallbackLilac, fallbackHex: "F0ECFF") }
    static let destructive = Color(light: Color(hex: "E94848"), dark: Color(hex: "FF7474"))

    static var accent: Color {
        dogOrange
    }

    static var onAccent: Color {
        ThemeColorCustomization.readableForegroundColor(
            on: accent,
            light: Color(hex: "111111"),
            dark: Color(hex: "FFFFFF")
        )
    }

    static var accentGradient: [Color] {
        ThemeColorCustomization.accentGradientColors(
            for: .petWhite,
            fallback: [fallbackDogOrange, fallbackMint, fallbackBlush.opacity(0.78)],
            fallbackHexes: ["F6A93B", "DDF5EE", "FF8D7E"]
        )
    }

    static let strokeWidth: CGFloat = 2.2
    static let fineStrokeWidth: CGFloat = 1.4
    static let cardRadius: CGFloat = 20
    static let compactRadius: CGFloat = 14

    static func titleFont(_ size: CGFloat, weight: Font.Weight = .black) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func bodyFont(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func labelFont(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
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
                    .opacity(colorScheme == .dark ? 0.34 : 1)

                PetWhitePawPattern()
                    .opacity(colorScheme == .dark ? 0.30 : 0.78)

                VStack {
                    PetWhiteBackdropRibbon()
                        .padding(.top, 58)
                    Spacer()
                }
                .padding(.horizontal, 22)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
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

        #if canImport(UIKit)
        if let image = UIImage(pawPrintIconId: assetName) {
            Image(uiImage: image)
                .renderingMode(.original)
                .resizable()
                .scaledToFill()
        } else {
            PetWhiteBackdropWash()
        }
        #elseif canImport(AppKit)
        if let image = NSImage.pawPrintIcon(id: assetName) {
            Image(nsImage: image)
                .renderingMode(.original)
                .resizable()
                .scaledToFill()
        } else {
            PetWhiteBackdropWash()
        }
        #else
        PetWhiteBackdropWash()
        #endif
    }
}

private struct PetWhiteBackdropWash: View {
    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 0, style: .continuous)
                    .fill(PetWhiteStyle.sky.opacity(0.52))
                    .frame(height: max(150, proxy.size.height * 0.24))
                    .overlay(alignment: .bottomLeading) {
                        Capsule()
                            .fill(PetWhiteStyle.mint.opacity(0.64))
                            .frame(width: min(proxy.size.width * 0.70, 340), height: 18)
                            .padding(.leading, 22)
                            .padding(.bottom, 20)
                    }

                Spacer(minLength: 0)

                RoundedRectangle(cornerRadius: 0, style: .continuous)
                    .fill(PetWhiteStyle.butter.opacity(0.30))
                    .frame(height: max(96, proxy.size.height * 0.14))
                    .overlay(alignment: .topTrailing) {
                        Capsule()
                            .fill(PetWhiteStyle.dogOrange.opacity(0.24))
                            .frame(width: min(proxy.size.width * 0.48, 240), height: 14)
                            .padding(.top, 18)
                            .padding(.trailing, 24)
                    }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct PetWhiteBackdropRibbon: View {
    var body: some View {
        HStack(spacing: 8) {
            Capsule().fill(PetWhiteStyle.dogOrange.opacity(0.28)).frame(width: 42, height: 7)
            Capsule().fill(PetWhiteStyle.sky.opacity(0.86)).frame(width: 18, height: 7)
            Capsule().fill(PetWhiteStyle.mint.opacity(0.72)).frame(width: 70, height: 7)
            Capsule().fill(PetWhiteStyle.blush.opacity(0.26)).frame(width: 28, height: 7)
            Spacer(minLength: 0)
        }
    }
}

struct PetWhitePawPattern: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Canvas(rendersAsynchronously: true) { context, size in
            let pawColor = PetWhiteStyle.stroke.opacity(colorScheme == .dark ? 0.06 : 0.045)
            let accentColor = PetWhiteStyle.dogOrange.opacity(colorScheme == .dark ? 0.05 : 0.055)
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
        let fillOpacity = settings.petWhiteUsesIllustratedBackground ? (elevated ? 0.82 : 0.76) : 1

        ZStack {
            if elevated {
                shape
                    .fill(PetWhiteStyle.stroke.opacity(colorScheme == .dark ? 0.18 : 0.10))
                    .offset(x: 0, y: 3)
            }

            shape
                .fill(tint.opacity(fillOpacity))
                .overlay(shape.stroke(PetWhiteStyle.stroke, lineWidth: elevated ? PetWhiteStyle.strokeWidth : PetWhiteStyle.fineStrokeWidth))
        }
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
            ? (elevated ? 0.84 : 0.80)
            : (colorScheme == .dark ? 0.90 : 0.96)
        let materialOpacity = colorScheme == .dark ? 0.16 : 0.10

        ZStack {
            if elevated {
                shape
                    .fill(PetWhiteStyle.stroke.opacity(colorScheme == .dark ? 0.16 : 0.09))
                    .offset(y: 3)
            }

            shape
                .fill(.ultraThinMaterial)
                .opacity(materialOpacity)
                .overlay(shape.fill(tint.opacity(tintOpacity)))
                .overlay(
                    shape.fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.03 : 0.10),
                                accent.opacity(colorScheme == .dark ? 0.025 : 0.035),
                                PetWhiteStyle.sky.opacity(colorScheme == .dark ? 0.018 : 0.025),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                )
                .overlay(
                    shape.stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.06 : 0.24),
                                strokeColor.opacity(colorScheme == .dark ? 0.92 : 0.98),
                                PetWhiteStyle.stroke.opacity(colorScheme == .dark ? 0.12 : 0.08),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: lineWidth
                    )
                )
        }
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
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                PetWhitePetPetIcon(size: 76)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        PetWhitePill(text: eyebrow.uppercased(), tint: PetWhiteStyle.mint)
                        PetWhitePackIcon(icon: icon, size: 17, visualScale: 1.12)
                    }

                    Text(title)
                        .font(PetWhiteStyle.titleFont(28, weight: .black))
                        .foregroundStyle(PetWhiteStyle.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)

                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(PetWhiteStyle.bodyFont(13, weight: .semibold))
                            .foregroundStyle(PetWhiteStyle.inkSoft)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 8)

                accessory
            }

            HStack(spacing: 8) {
                Capsule().fill(PetWhiteStyle.dogOrange).frame(width: 28, height: 5)
                Capsule().fill(PetWhiteStyle.mint).frame(width: 48, height: 5)
                Capsule().fill(PetWhiteStyle.sky).frame(width: 34, height: 5)
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
        .padding(.top, DeviceLayout.headerTopPadding + 4)
        .padding(.bottom, 10)
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
    var fallbackColor: Color = PetWhiteStyle.stroke
    var lineWidth: CGFloat?

    var body: some View {
        MonologueIcon(
            icon: icon,
            size: size,
            color: fallbackColor,
            lineWidth: lineWidth ?? max(1.6, size * 0.045)
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
        #if canImport(UIKit)
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
        #elseif canImport(AppKit)
        if let image = NSImage.pawPrintIcon(id: assetName) {
            Image(nsImage: image)
                .renderingMode(.original)
                .interpolation(.high)
                .antialiased(true)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Color.clear
        }
        #else
        Color.clear
        #endif
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
    var fallbackColor: Color = PetWhiteStyle.stroke

    var body: some View {
        chevronImage
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var chevronImage: some View {
        #if canImport(UIKit)
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
        #elseif canImport(AppKit)
        if let image = NSImage.pawPrintIcon(id: direction.assetName) {
            Image(nsImage: image)
                .renderingMode(.original)
                .interpolation(.high)
                .antialiased(true)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            fallbackChevron
        }
        #else
        fallbackChevron
        #endif
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
        #if canImport(UIKit)
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
        #elseif canImport(AppKit)
        if let image = NSImage.pawPrintIcon(id: "petPet") {
            Image(nsImage: image)
                .renderingMode(.original)
                .interpolation(.high)
                .antialiased(true)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            PetWhiteMascotMark(kind: .pair, size: size)
        }
        #else
        PetWhiteMascotMark(kind: .pair, size: size)
        #endif
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
        #if canImport(UIKit)
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
        #elseif canImport(AppKit)
        if let image = NSImage.pawPrintIcon(id: "petPetHero") {
            Image(nsImage: image)
                .renderingMode(.original)
                .interpolation(.high)
                .antialiased(true)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            PetWhitePetPetIcon(size: min(width, height))
        }
        #else
        PetWhitePetPetIcon(size: min(width, height))
        #endif
    }
}

struct PetWhiteIconBadge: View {
    let icon: MonologueIcon.IconType
    var tint: Color = PetWhiteStyle.mint
    var size: CGFloat = 48

    var body: some View {
        RoundedRectangle(cornerRadius: max(12, size * 0.30), style: .continuous)
            .fill(tint)
            .frame(width: size, height: size)
            .overlay(
                PetWhitePackIcon(
                    icon: icon,
                    size: size * 0.64,
                    visualScale: 1.14,
                    lineWidth: max(1.8, size * 0.044)
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: max(12, size * 0.30), style: .continuous)
                    .stroke(PetWhiteStyle.stroke, lineWidth: max(1.5, size * 0.04))
            )
            .overlay(alignment: .topTrailing) {
                PetWhiteProfileHeadIcon(filled: true, size: max(14, size * 0.30))
                    .offset(x: size * 0.10, y: -size * 0.10)
            }
    }
}

struct PetWhiteAssetIconBadge: View {
    let assetName: String
    var tint: Color = PetWhiteStyle.mint
    var size: CGFloat = 48
    var assetScale: CGFloat = 0.72

    var body: some View {
        RoundedRectangle(cornerRadius: max(12, size * 0.30), style: .continuous)
            .fill(tint)
            .frame(width: size, height: size)
            .overlay(
                PetWhiteSelectedLyricToggleIcon(assetName: assetName, size: size * assetScale)
            )
            .overlay(
                RoundedRectangle(cornerRadius: max(12, size * 0.30), style: .continuous)
                    .stroke(PetWhiteStyle.stroke, lineWidth: max(1.5, size * 0.04))
            )
            .overlay(alignment: .topTrailing) {
                PetWhiteProfileHeadIcon(filled: true, size: max(14, size * 0.30))
                    .offset(x: size * 0.10, y: -size * 0.10)
            }
    }
}

struct PetWhitePill: View {
    let text: String
    var tint: Color = PetWhiteStyle.mint

    var body: some View {
        Text(text)
            .font(PetWhiteStyle.labelFont(10, weight: .black))
            .foregroundStyle(PetWhiteStyle.ink)
            .tracking(0.8)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(tint)
                    .overlay(Capsule(style: .continuous).stroke(PetWhiteStyle.separator, lineWidth: 1))
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
        HStack(alignment: .center, spacing: 10) {
            if let assetName {
                PetWhiteAssetIconBadge(assetName: assetName, tint: tint, size: 34)
            } else {
                PetWhiteIconBadge(icon: icon, tint: tint, size: 34)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(PetWhiteStyle.titleFont(18, weight: .black))
                    .foregroundStyle(PetWhiteStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(PetWhiteStyle.labelFont(11, weight: .semibold))
                        .foregroundStyle(PetWhiteStyle.inkSoft)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
            }

            Spacer(minLength: 8)

            if let action {
                Button(action: action) {
                    HStack(spacing: 4) {
                        Text(LocalizedStringKey("view_all"))
                            .font(PetWhiteStyle.labelFont(11, weight: .black))

                        PetWhitePackIcon(icon: .chevronRight, size: 15, visualScale: 1.05)
                    }
                    .foregroundStyle(PetWhiteStyle.stroke)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(PetWhiteStyle.surfaceRaised)
                            .overlay(Capsule(style: .continuous).stroke(PetWhiteStyle.separator, lineWidth: 1))
                    )
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))
            }
        }
    }
}

struct PetWhitePawPrint: View {
    var size: CGFloat = 26
    var tint: Color = PetWhiteStyle.stroke.opacity(0.16)

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
        #if canImport(UIKit)
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
        #elseif canImport(AppKit)
        if let image = NSImage.pawPrintIcon(id: assetName) {
            Image(nsImage: image)
                .renderingMode(.original)
                .interpolation(.high)
                .antialiased(true)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            fallbackHead
        }
        #else
        fallbackHead
        #endif
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
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(isSelected ? tint : PetWhiteStyle.surfaceRaised)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(PetWhiteStyle.stroke.opacity(isSelected ? 1 : 0.48), lineWidth: isSelected ? 1.5 : 1)
            )
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Circle()
                        .fill(PetWhiteStyle.catWhite)
                        .frame(width: 7, height: 7)
                        .overlay(Circle().stroke(PetWhiteStyle.stroke, lineWidth: 1))
                        .padding(6)
                }
            }
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
