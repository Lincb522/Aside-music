import SwiftUI

enum MinimalWhiteStyle {
    static var isActive: Bool {
        GlobalThemeId.persistedOrDefault == .minimalWhite
    }

    static var base: Color { Color(light: .white, dark: Color(hex: "0E0E11")) }
    static var paper: Color { base }
    static var surface: Color { Color(light: .white, dark: Color(hex: "121216")) }
    static var surfaceRaised: Color { Color(light: Color.white.opacity(0.94), dark: Color(hex: "17171C").opacity(0.94)) }
    static var surfaceTint: Color { Color(light: Color(hex: "FBFBFC"), dark: Color(hex: "141419")) }
    static var glassFill: Color { Color(light: Color.white.opacity(0.72), dark: Color(hex: "17171C").opacity(0.72)) }
    static var glassStrongFill: Color { Color(light: Color.white.opacity(0.88), dark: Color(hex: "1A1A20").opacity(0.9)) }
    static var controlFill: Color { Color(light: Color(hex: "F6F6F7"), dark: Color(hex: "1D1D23")) }
    static var controlGlassFill: Color { Color(light: Color.white.opacity(0.78), dark: Color(hex: "1D1D23").opacity(0.78)) }
    static var selectedFill: Color { Color(light: Color(hex: "EFEFF1"), dark: Color(hex: "27272E")) }
    static var ink: Color { Color(light: Color(hex: "111114"), dark: Color(hex: "F4F4F6")) }
    static var inkSoft: Color { Color(light: Color(hex: "3F3F46"), dark: Color(hex: "C4C4CC")) }
    static var inkMuted: Color { Color(light: Color(hex: "73737C"), dark: Color(hex: "8C8C95")) }
    static var separator: Color { Color(light: Color(hex: "DEDEE3"), dark: Color(hex: "34343C")) }
    static var hairline: Color { Color(light: Color(hex: "EFEFF2"), dark: Color(hex: "232329")) }
    static var luminousEdge: Color { Color(light: Color.white.opacity(0.86), dark: Color.white.opacity(0.08)) }
    static var accent: Color { ink }
    static var onAccent: Color { Color(light: .white, dark: Color(hex: "111114")) }
    static var destructive: Color { Color(light: Color(hex: "DC2626"), dark: Color(hex: "F87171")) }
    static var accentGradient: [Color] { [accent, inkSoft] }
    /// 阴影专用墨色：夜间模式下 ink 变为浅色，阴影需始终基于深色。
    static var shadowInk: Color { Color(light: Color(hex: "111114"), dark: .black) }

    static let strokeWidth: CGFloat = 0.65
    static let cardRadius: CGFloat = 16
    static let compactRadius: CGFloat = 11
    static let chromeRadius: CGFloat = 20
    static let pageHorizontalPadding: CGFloat = 24
    static let sectionSpacing: CGFloat = 30

    static func titleFont(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func bodyFont(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func labelFont(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}

struct MinimalWhiteRootBackdrop: View {
    var body: some View {
        ZStack {
            MinimalWhiteStyle.paper

            VStack(spacing: 0) {
                Rectangle()
                    .fill(MinimalWhiteStyle.surfaceTint)
                    .frame(height: 1)
                Spacer(minLength: 0)
            }
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }
}

struct MinimalWhiteSurfaceBackground: View {
    var cornerRadius: CGFloat = MinimalWhiteStyle.cardRadius
    var elevated = false
    var tint: Color = MinimalWhiteStyle.surfaceRaised
    var glass = true

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        ZStack {
            if glass {
                shape
                    .fill(.ultraThinMaterial)
            }

            shape
                .fill(tint)

            shape
                .fill(
                    LinearGradient(
                        colors: [
                            MinimalWhiteStyle.luminousEdge.opacity(elevated ? 0.66 : 0.42),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blendMode(.plusLighter)
                .opacity(glass ? 1 : 0)

            shape
                .stroke(
                    elevated ? MinimalWhiteStyle.separator : MinimalWhiteStyle.hairline,
                    lineWidth: MinimalWhiteStyle.strokeWidth
                )
        }
        .shadow(
            color: MinimalWhiteStyle.shadowInk.opacity(elevated ? 0.075 : 0.024),
            radius: elevated ? 16 : 5,
            x: 0,
            y: elevated ? 8 : 2
        )
    }
}

struct MinimalWhiteCapsuleBackground: View {
    var elevated = false
    var selected = false

    var body: some View {
        Capsule(style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                Capsule(style: .continuous)
                    .fill(selected ? MinimalWhiteStyle.selectedFill.opacity(0.92) : MinimalWhiteStyle.glassFill)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(selected ? MinimalWhiteStyle.separator : MinimalWhiteStyle.hairline, lineWidth: MinimalWhiteStyle.strokeWidth)
            )
            .shadow(
                color: MinimalWhiteStyle.shadowInk.opacity(elevated ? 0.06 : 0.018),
                radius: elevated ? 10 : 3,
                x: 0,
                y: elevated ? 5 : 1
            )
    }
}

struct MinimalWhiteCircleBackground: View {
    var elevated = false
    var selected = false

    var body: some View {
        Circle()
            .fill(.ultraThinMaterial)
            .overlay(
                Circle()
                    .fill(selected ? MinimalWhiteStyle.selectedFill.opacity(0.94) : MinimalWhiteStyle.controlGlassFill)
            )
            .overlay(
                Circle()
                    .stroke(selected ? MinimalWhiteStyle.separator : MinimalWhiteStyle.hairline, lineWidth: MinimalWhiteStyle.strokeWidth)
            )
            .shadow(
                color: MinimalWhiteStyle.shadowInk.opacity(elevated ? 0.065 : 0.02),
                radius: elevated ? 10 : 3,
                x: 0,
                y: elevated ? 5 : 1
            )
    }
}

struct MinimalWhitePageHeader<Accessory: View>: View {
    let title: String
    let accessory: Accessory

    init(
        eyebrow: String,
        title: String,
        subtitle: String = "",
        icon: MonologueIcon.IconType = .sparkle,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.title = title
        self.accessory = accessory()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(MinimalWhiteStyle.titleFont(30, weight: .semibold))
                .foregroundStyle(MinimalWhiteStyle.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.9)

            Spacer(minLength: 0)

            accessory
        }
        .padding(.horizontal, DeviceLayout.settingsHeaderHorizontalPadding)
        .padding(.top, DeviceLayout.headerTopPadding + 8)
        .padding(.bottom, 10)
        .iPadContentWidth(700)
    }
}

extension MinimalWhitePageHeader where Accessory == EmptyView {
    init(
        eyebrow: String,
        title: String,
        subtitle: String = "",
        icon: MonologueIcon.IconType = .sparkle
    ) {
        self.init(eyebrow: eyebrow, title: title, subtitle: subtitle, icon: icon) {
            EmptyView()
        }
    }
}

struct MinimalWhiteIconBadge: View {
    let icon: MonologueIcon.IconType
    var size: CGFloat = 44
    var selected = false

    var body: some View {
        let radius = max(10, size * 0.25)

        ZStack {
            MinimalWhiteSurfaceBackground(
                cornerRadius: radius,
                elevated: selected,
                tint: selected ? MinimalWhiteStyle.selectedFill.opacity(0.92) : MinimalWhiteStyle.controlGlassFill
            )

            MonologueIcon(
                icon: icon,
                size: size * 0.4,
                color: selected ? MinimalWhiteStyle.ink : MinimalWhiteStyle.inkSoft,
                lineWidth: max(1.3, size * 0.035)
            )
        }
        .frame(width: size, height: size)
    }
}

struct MinimalWhiteHeaderButton: View {
    let icon: MonologueIcon.IconType
    var selected = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            MonologueIcon(
                icon: icon,
                size: 17,
                color: selected ? MinimalWhiteStyle.ink : MinimalWhiteStyle.inkSoft,
                lineWidth: 1.7
            )
            .frame(width: 40, height: 40)
            .background(MinimalWhiteCircleBackground(elevated: true, selected: selected))
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

struct MinimalWhiteSectionTitle<Action: View>: View {
    let title: String
    let action: Action

    init(title: String, @ViewBuilder action: () -> Action) {
        self.title = title
        self.action = action()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(MinimalWhiteStyle.titleFont(20, weight: .semibold))
                .foregroundStyle(MinimalWhiteStyle.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.86)

            Spacer(minLength: 8)

            action
        }
    }
}

extension MinimalWhiteSectionTitle where Action == EmptyView {
    init(title: String) {
        self.init(title: title) { EmptyView() }
    }
}

struct MinimalWhiteDisclosureGlyph: View {
    var body: some View {
        MonologueIcon(icon: .chevronRight, size: 11, color: MinimalWhiteStyle.inkMuted, lineWidth: 1.6)
            .frame(width: 30, height: 30)
            .background(MinimalWhiteCircleBackground(elevated: false))
    }
}

struct MinimalWhiteMetricCell: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 5) {
            Text(value)
                .font(MinimalWhiteStyle.titleFont(18, weight: .semibold))
                .foregroundStyle(MinimalWhiteStyle.ink)
                .lineLimit(1)

            Text(label)
                .font(MinimalWhiteStyle.labelFont(11, weight: .regular))
                .foregroundStyle(MinimalWhiteStyle.inkMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
    }
}

extension View {
    func minimalWhiteGlassSurface(
        cornerRadius: CGFloat = MinimalWhiteStyle.cardRadius,
        elevated: Bool = false,
        tint: Color = MinimalWhiteStyle.glassFill
    ) -> some View {
        background(
            MinimalWhiteSurfaceBackground(
                cornerRadius: cornerRadius,
                elevated: elevated,
                tint: tint
            )
        )
    }

    func minimalWhiteHairline(_ alignment: Alignment = .bottom) -> some View {
        overlay(alignment: alignment) {
            Rectangle()
                .fill(MinimalWhiteStyle.hairline)
                .frame(height: 1)
        }
    }
}
