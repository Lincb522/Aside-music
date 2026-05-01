import SwiftUI

enum SequoiaStyle {
    static var isActive: Bool {
        UserDefaults.standard.string(forKey: "globalThemeId") == GlobalThemeId.sequoia.rawValue
    }

    static var base: Color {
        ThemeColorCustomization.backgroundBase(
            for: .sequoia,
            fallback: Color(light: Color(hex: "F4F7FB"), dark: Color(hex: "070A10")),
            fallbackHex: "F4F7FB"
        )
    }

    static let canvasTop = Color(light: Color(hex: "FCFEFF"), dark: Color(hex: "151922"))
    static let canvasMiddle = Color(light: Color(hex: "EEF4F8"), dark: Color(hex: "0E121A"))
    static let canvasBottom = Color(light: Color(hex: "E3EBF2"), dark: Color(hex: "06080D"))

    static let material = Color(light: Color.white.opacity(0.34), dark: Color(hex: "171B23").opacity(0.58))
    static let materialRaised = Color(light: Color.white.opacity(0.62), dark: Color(hex: "212732").opacity(0.7))
    static let materialPressed = Color(light: Color(hex: "DDE6EF").opacity(0.58), dark: Color(hex: "0C1017").opacity(0.78))
    static let materialChrome = Color(light: Color.white.opacity(0.42), dark: Color(hex: "171C25").opacity(0.66))
    static let materialSidebar = Color(light: Color(hex: "F8FBFD").opacity(0.58), dark: Color(hex: "141A22").opacity(0.66))
    static let materialList = Color(light: Color.white.opacity(0.28), dark: Color(hex: "10151E").opacity(0.48))
    static let materialFloating = Color(light: Color.white.opacity(0.74), dark: Color(hex: "202632").opacity(0.78))
    static let selectedWash = Color(light: Color(hex: "DCEEFF").opacity(0.7), dark: Color(hex: "14314C").opacity(0.74))

    static var glass: Color { materialList }
    static var glassRaised: Color { materialRaised }
    static var glassPressed: Color { materialPressed }

    static let ink = Color(light: Color(hex: "111821"), dark: Color(hex: "F5F8FC"))
    static let inkSoft = Color(light: Color(hex: "55616E"), dark: Color(hex: "BAC4CF"))
    static let inkMuted = Color(light: Color(hex: "8794A2"), dark: Color(hex: "7F8B99"))
    static var onAccent: Color {
        ThemeColorCustomization.readableForegroundColor(
            on: accent,
            light: Color(hex: "061016"),
            dark: Color.white
        )
    }

    static var accent: Color {
        ThemeColorCustomization.accentColor(
            for: .sequoia,
            fallback: Color(light: Color(hex: "0A84FF"), dark: Color(hex: "64D2FF")),
            fallbackHex: "0A84FF"
        )
    }

    static let aqua = Color(light: Color(hex: "26AFCF"), dark: Color(hex: "69D9F2"))
    static let violet = Color(light: Color(hex: "6E68E8"), dark: Color(hex: "AAA2FF"))
    static let green = Color(light: Color(hex: "2E9F73"), dark: Color(hex: "80D8AC"))
    static let yellow = Color(light: Color(hex: "B98631"), dark: Color(hex: "E8BD62"))
    static let red = Color(light: Color(hex: "D94D52"), dark: Color(hex: "FF7278"))
    static let graphite = Color(light: Color(hex: "637083"), dark: Color(hex: "A9B3C0"))

    static let separator = Color(light: Color(hex: "64748A").opacity(0.22), dark: Color.white.opacity(0.1))
    static let strongSeparator = Color(light: Color(hex: "506174").opacity(0.28), dark: Color.white.opacity(0.17))
    static let luminousSeparator = Color(light: Color.white.opacity(0.78), dark: Color.white.opacity(0.1))

    static let cardRadius: CGFloat = 18
    static let compactRadius: CGFloat = 11
    static let buttonRadius: CGFloat = 12
    static let toolbarRadius: CGFloat = 22

    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: ThemeColorCustomization.accentGradientColors(
                for: .sequoia,
                fallback: [accent, aqua],
                fallbackHexes: ["0A84FF", "26AFCF"]
            ),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var auroraGradient: LinearGradient {
        LinearGradient(
            colors: [
                accent.opacity(0.95),
                aqua.opacity(0.78),
                violet.opacity(0.64),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func titleFont(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func bodyFont(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func labelFont(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func shadow(_ scheme: ColorScheme, elevated: Bool = true) -> Color {
        scheme == .dark
            ? Color.black.opacity(elevated ? 0.34 : 0.2)
            : Color(hex: "304760").opacity(elevated ? 0.105 : 0.045)
    }

    static func highlight(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.065) : Color.white.opacity(0.84)
    }
}

enum SequoiaMaterialRole {
    case content
    case chrome
    case sidebar
    case list
    case floating
    case selected
}

struct SequoiaRootBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            ThemeCustomDiffuseBackground(
                theme: .sequoia,
                fallbackHexes: colorScheme == .dark ? ["070A10", "111720"] : ["F4F7FB", "E3EBF2"],
                accentFallbackHexes: ["0A84FF", "26AFCF", "6E68E8"],
                opacity: colorScheme == .dark ? 0.68 : 0.82
            )

            LinearGradient(
                colors: [
                    SequoiaStyle.canvasTop.opacity(colorScheme == .dark ? 0.82 : 0.97),
                    SequoiaStyle.canvasMiddle.opacity(colorScheme == .dark ? 0.72 : 0.86),
                    SequoiaStyle.canvasBottom.opacity(colorScheme == .dark ? 0.94 : 0.94),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            SequoiaSystemVeil()
            SequoiaHairlineTexture(opacity: colorScheme == .dark ? 0.014 : 0.02)
            SequoiaEdgeShade()
        }
        .transaction { transaction in
            transaction.animation = nil
            transaction.disablesAnimations = true
        }
        .accessibilityHidden(true)
        .ignoresSafeArea()
    }
}

private struct SequoiaSystemVeil: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack {
                LinearGradient(
                    colors: [
                        SequoiaStyle.accent.opacity(colorScheme == .dark ? 0.12 : 0.08),
                        .clear,
                        SequoiaStyle.aqua.opacity(colorScheme == .dark ? 0.08 : 0.055),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RoundedRectangle(cornerRadius: 48, style: .continuous)
                    .fill(Color.white.opacity(colorScheme == .dark ? 0.024 : 0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 48, style: .continuous)
                            .stroke(SequoiaStyle.luminousSeparator.opacity(colorScheme == .dark ? 0.18 : 0.36), lineWidth: 0.6)
                    )
                    .frame(width: width * 0.86, height: max(96, height * 0.15))
                    .rotationEffect(.degrees(-7))
                    .offset(x: -width * 0.2, y: -height * 0.06)

                RoundedRectangle(cornerRadius: 56, style: .continuous)
                    .fill(SequoiaStyle.materialSidebar.opacity(colorScheme == .dark ? 0.28 : 0.42))
                    .overlay(
                        RoundedRectangle(cornerRadius: 56, style: .continuous)
                            .stroke(SequoiaStyle.separator.opacity(0.54), lineWidth: 0.55)
                    )
                    .frame(width: width * 0.76, height: max(118, height * 0.19))
                    .rotationEffect(.degrees(10))
                    .offset(x: width * 0.28, y: height * 0.54)
            }
            .blendMode(colorScheme == .dark ? .plusLighter : .softLight)
        }
        .allowsHitTesting(false)
    }
}

private struct SequoiaEdgeShade: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: [
                Color.black.opacity(colorScheme == .dark ? 0.18 : 0.035),
                .clear,
                Color.black.opacity(colorScheme == .dark ? 0.32 : 0.06),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .allowsHitTesting(false)
    }
}

private struct SequoiaHairlineTexture: View {
    var opacity: Double = 0.02

    var body: some View {
        Canvas(rendersAsynchronously: true) { context, size in
            let lineColor = SequoiaStyle.inkMuted.opacity(opacity)
            for index in stride(from: 0, through: Int(size.height) + 28, by: 24) {
                var path = Path()
                let y = CGFloat(index)
                path.move(to: CGPoint(x: -18, y: y))
                path.addLine(to: CGPoint(x: size.width + 18, y: y + CGFloat((index % 4) - 1)))
                context.stroke(path, with: .color(lineColor), lineWidth: 0.45)
            }

            let glint = Color.white.opacity(opacity * 1.7)
            for index in stride(from: 0, through: Int(size.width) + 44, by: 46) {
                var path = Path()
                let x = CGFloat(index)
                path.move(to: CGPoint(x: x, y: -20))
                path.addLine(to: CGPoint(x: x + 18, y: size.height + 20))
                context.stroke(path, with: .color(glint.opacity(0.34)), lineWidth: 0.35)
            }
        }
        .blendMode(.softLight)
        .allowsHitTesting(false)
    }
}

struct SequoiaSurfaceBackground: View {
    var cornerRadius: CGFloat = SequoiaStyle.cardRadius
    var elevated: Bool = true
    var pressed: Bool = false
    var fill: Color?
    var role: SequoiaMaterialRole = .content

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let fillColor = fill ?? defaultFill

        ZStack {
            shape
                .fill(.ultraThinMaterial)

            shape
                .fill(fillColor.opacity(surfaceOpacity))

            shape
                .fill(
                    LinearGradient(
                        colors: [
                            SequoiaStyle.highlight(colorScheme).opacity(pressed ? 0.18 : 0.36),
                            .clear,
                            SequoiaStyle.accent.opacity(role == .selected ? 0.08 : 0.025),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if role == .floating || role == .chrome {
                shape
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.035 : 0.22),
                                .clear,
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        }
        .overlay(
            shape.strokeBorder(strokeGradient, lineWidth: role == .floating ? 0.75 : 0.58)
        )
        .shadow(
            color: pressed ? .clear : SequoiaStyle.shadow(colorScheme, elevated: elevated),
            radius: elevated ? (role == .floating ? 18 : 11) : 3,
            x: 0,
            y: elevated ? (role == .floating ? 10 : 5) : 1
        )
        .compositingGroup()
        .transaction { transaction in
            transaction.animation = nil
        }
        .themeRenderSurfaceLayer(isEnabled: elevated)
    }

    private var surfaceOpacity: Double {
        if pressed { return colorScheme == .dark ? 0.9 : 0.72 }
        switch role {
        case .floating:
            return colorScheme == .dark ? 0.9 : 0.86
        case .chrome:
            return colorScheme == .dark ? 0.8 : 0.72
        case .sidebar:
            return colorScheme == .dark ? 0.72 : 0.64
        case .selected:
            return colorScheme == .dark ? 0.82 : 0.76
        case .list:
            return colorScheme == .dark ? 0.66 : 0.58
        case .content:
            return colorScheme == .dark ? 0.72 : 0.64
        }
    }

    private var defaultFill: Color {
        if pressed { return SequoiaStyle.materialPressed }
        switch role {
        case .chrome:
            return SequoiaStyle.materialChrome
        case .sidebar:
            return SequoiaStyle.materialSidebar
        case .list:
            return SequoiaStyle.materialList
        case .floating:
            return SequoiaStyle.materialFloating
        case .selected:
            return SequoiaStyle.selectedWash
        case .content:
            return elevated ? SequoiaStyle.materialRaised : SequoiaStyle.material
        }
    }

    private var strokeGradient: LinearGradient {
        LinearGradient(
            colors: [
                SequoiaStyle.luminousSeparator.opacity(colorScheme == .dark ? 0.24 : 0.58),
                SequoiaStyle.separator.opacity(role == .list ? 0.68 : 0.92),
                SequoiaStyle.strongSeparator.opacity(colorScheme == .dark ? 0.36 : 0.22),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct SequoiaChromeBar: View {
    var cornerRadius: CGFloat = SequoiaStyle.toolbarRadius

    var body: some View {
        SequoiaSurfaceBackground(
            cornerRadius: cornerRadius,
            elevated: true,
            role: .chrome
        )
    }
}

struct SequoiaGlassBand: View {
    var tint: Color = SequoiaStyle.accent
    var cornerRadius: CGFloat = 22

    var body: some View {
        ZStack {
            SequoiaSurfaceBackground(cornerRadius: cornerRadius, elevated: true, role: .chrome)

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(0.16),
                            SequoiaStyle.aqua.opacity(0.075),
                            .clear,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(SequoiaStyle.separator, lineWidth: 0.55)
                )
        }
    }
}

struct SequoiaIconBadge: View {
    let icon: MonologueIcon.IconType
    var tint: Color = SequoiaStyle.accent
    var size: CGFloat = 40
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        let _ = settings.globalThemeRevision
        MonologueIcon(icon: icon, size: size * 0.43, color: tint, lineWidth: 1.55)
            .frame(width: size, height: size)
            .background(
                SequoiaSurfaceBackground(
                    cornerRadius: max(10, size * 0.31),
                    elevated: false,
                    fill: tint.opacity(0.11),
                    role: .selected
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: max(10, size * 0.31), style: .continuous)
                    .stroke(tint.opacity(0.18), lineWidth: 0.55)
            )
            .themeRenderInteractiveLayer()
    }
}

struct SequoiaControlButton: View {
    let icon: MonologueIcon.IconType
    var tint: Color = SequoiaStyle.inkSoft
    var size: CGFloat = 38
    var selected: Bool = false
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        let _ = settings.globalThemeRevision
        MonologueIcon(
            icon: icon,
            size: size * 0.42,
            color: selected ? SequoiaStyle.accent : tint,
            lineWidth: 1.65
        )
        .frame(width: size, height: size)
        .background(
            SequoiaSurfaceBackground(
                cornerRadius: size * 0.36,
                elevated: selected,
                pressed: !selected,
                fill: selected ? SequoiaStyle.selectedWash : nil,
                role: selected ? .selected : .list
            )
        )
        .themeRenderInteractiveLayer()
    }
}

struct SequoiaPill: View {
    let text: String
    var icon: MonologueIcon.IconType?
    var tint: Color = SequoiaStyle.accent
    var selected = false
    var compact = false
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        let _ = settings.globalThemeRevision
        HStack(spacing: compact ? 4 : 6) {
            if let icon {
                MonologueIcon(icon: icon, size: compact ? 10 : 12, color: foreground, lineWidth: 1.45)
            }
            Text(text)
                .font(SequoiaStyle.labelFont(compact ? 10.5 : 12, weight: selected ? .semibold : .medium))
                .foregroundStyle(foreground)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, compact ? 8 : 10)
        .padding(.vertical, compact ? 4 : 6)
        .background(
            Capsule()
                .fill(selected ? tint.opacity(0.92) : SequoiaStyle.materialList.opacity(0.62))
                .overlay(
                    Capsule()
                        .stroke(selected ? tint.opacity(0.22) : SequoiaStyle.separator, lineWidth: 0.5)
                )
        )
    }

    private var foreground: Color {
        selected
            ? ThemeColorCustomization.readableForegroundColor(on: tint, light: Color(hex: "061016"), dark: Color.white)
            : SequoiaStyle.inkSoft
    }
}

struct SequoiaPageHeader<Accessory: View>: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    @ViewBuilder let accessory: Accessory

    var body: some View {
        HStack(alignment: .center, spacing: 13) {
            VStack(spacing: 4) {
                Capsule()
                    .fill(SequoiaStyle.accentGradient)
                    .frame(width: 3.5, height: 26)
                Capsule()
                    .fill(SequoiaStyle.separator)
                    .frame(width: 3.5, height: 9)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(eyebrow)
                    .font(SequoiaStyle.labelFont(10, weight: .semibold))
                    .foregroundStyle(SequoiaStyle.inkMuted)

                Text(title)
                    .font(SequoiaStyle.titleFont(25, weight: .semibold))
                    .foregroundStyle(SequoiaStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(SequoiaStyle.labelFont(12, weight: .regular))
                        .foregroundStyle(SequoiaStyle.inkSoft)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 10)

            accessory
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(SequoiaChromeBar(cornerRadius: 21))
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
        .padding(.top, DeviceLayout.headerTopPadding + 4)
        .padding(.bottom, 8)
    }
}

extension SequoiaPageHeader where Accessory == EmptyView {
    init(eyebrow: String, title: String, subtitle: String) {
        self.init(eyebrow: eyebrow, title: title, subtitle: subtitle) {
            EmptyView()
        }
    }
}

struct SequoiaSection<Accessory: View, Content: View>: View {
    let title: String
    let subtitle: String?
    let tint: Color
    let accessory: Accessory
    let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        tint: Color = SequoiaStyle.accent,
        @ViewBuilder accessory: () -> Accessory,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.tint = tint
        self.accessory = accessory()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                SequoiaIconBadge(icon: .sparkle, tint: tint, size: 31)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(SequoiaStyle.titleFont(17, weight: .semibold))
                        .foregroundStyle(SequoiaStyle.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(SequoiaStyle.labelFont(11, weight: .regular))
                            .foregroundStyle(SequoiaStyle.inkMuted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }
                }

                Spacer(minLength: 8)
                accessory
            }

            SequoiaHairline(tint: tint.opacity(0.3))

            content
        }
    }
}

extension SequoiaSection where Accessory == EmptyView {
    init(
        title: String,
        subtitle: String? = nil,
        tint: Color = SequoiaStyle.accent,
        @ViewBuilder content: () -> Content
    ) {
        self.init(title: title, subtitle: subtitle, tint: tint) {
            EmptyView()
        } content: {
            content()
        }
    }
}

struct SequoiaHairline: View {
    var tint: Color = SequoiaStyle.separator

    var body: some View {
        LinearGradient(
            colors: [.clear, tint, SequoiaStyle.luminousSeparator.opacity(0.32), tint, .clear],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: 0.6)
        .allowsHitTesting(false)
    }
}

struct SequoiaListGroup<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(
            SequoiaSurfaceBackground(
                cornerRadius: 17,
                elevated: false,
                role: .list
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .themeRenderRowLayer()
    }
}

struct SequoiaMeter: View {
    var tint: Color = SequoiaStyle.accent
    var count: Int = 7

    var body: some View {
        HStack(alignment: .bottom, spacing: 2.5) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index < count - 2 ? tint.opacity(0.76) : SequoiaStyle.inkMuted.opacity(0.2))
                    .frame(width: 3, height: CGFloat(7 + (index % 4) * 3))
            }
        }
        .frame(height: 18, alignment: .bottom)
        .accessibilityHidden(true)
    }
}

struct SequoiaStatePanel: View {
    let title: String
    var subtitle: String?
    var icon: MonologueIcon.IconType = .musicNote
    var tint: Color = SequoiaStyle.accent
    var showsProgress = false

    var body: some View {
        VStack(spacing: 10) {
            SequoiaIconBadge(icon: icon, tint: tint, size: 50)

            Text(title)
                .font(SequoiaStyle.titleFont(17, weight: .semibold))
                .foregroundStyle(SequoiaStyle.ink)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(SequoiaStyle.labelFont(12, weight: .regular))
                    .foregroundStyle(SequoiaStyle.inkSoft)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.78)
            }

            if showsProgress {
                ProgressView()
                    .tint(tint)
                    .scaleEffect(0.82)
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(SequoiaSurfaceBackground(cornerRadius: 22, elevated: true, role: .chrome))
    }
}

extension View {
    func sequoiaStagger(_ appeared: Bool, order: Int) -> some View {
        opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
            .animation(
                .spring(response: 0.36, dampingFraction: 0.9).delay(Double(order) * 0.035),
                value: appeared
            )
    }
}
