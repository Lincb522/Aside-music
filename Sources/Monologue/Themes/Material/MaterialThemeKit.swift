import SwiftUI

enum MaterialStyle {
    static var isActive: Bool {
        UserDefaults.standard.string(forKey: "globalThemeId") == GlobalThemeId.material.rawValue
    }

    static var base: Color {
        ThemeColorCustomization.backgroundBase(
            for: .material,
            fallback: Color(light: Color(hex: "FFFBFE"), dark: Color(hex: "141218")),
            fallbackHex: "FFFBFE"
        )
    }

    static let surface = Color(light: Color(hex: "FFFBFE"), dark: Color(hex: "211F26"))
    static let surfaceDim = Color(light: Color(hex: "DED8E1"), dark: Color(hex: "141218"))
    static let surfaceContainerLowest = Color(light: Color.white, dark: Color(hex: "0F0D13"))
    static let surfaceContainerLow = Color(light: Color(hex: "F7F2FA"), dark: Color(hex: "1D1B20"))
    static let surfaceContainer = Color(light: Color(hex: "F3EDF7"), dark: Color(hex: "211F26"))
    static let surfaceContainerHigh = Color(light: Color(hex: "ECE6F0"), dark: Color(hex: "2B2930"))
    static let surfaceContainerHighest = Color(light: Color(hex: "E6E0E9"), dark: Color(hex: "36343B"))

    static let ink = Color(light: Color(hex: "1D1B20"), dark: Color(hex: "E6E0E9"))
    static let inkSoft = Color(light: Color(hex: "49454F"), dark: Color(hex: "CAC4D0"))
    static let inkMuted = Color(light: Color(hex: "79747E"), dark: Color(hex: "938F99"))
    static let outline = Color(light: Color(hex: "79747E").opacity(0.34), dark: Color(hex: "938F99").opacity(0.34))
    static let outlineStrong = Color(light: Color(hex: "79747E").opacity(0.58), dark: Color(hex: "938F99").opacity(0.48))

    static var primary: Color {
        ThemeColorCustomization.accentColor(
            for: .material,
            fallback: Color(light: Color(hex: "6750A4"), dark: Color(hex: "D0BCFF")),
            fallbackHex: "6750A4"
        )
    }

    static let secondary = Color(light: Color(hex: "625B71"), dark: Color(hex: "CCC2DC"))
    static let tertiary = Color(light: Color(hex: "7D5260"), dark: Color(hex: "EFB8C8"))
    static let green = Color(light: Color(hex: "3F7D58"), dark: Color(hex: "9ED9B6"))
    static let blue = Color(light: Color(hex: "3E6E9E"), dark: Color(hex: "A8C7FA"))
    static let orange = Color(light: Color(hex: "9B642E"), dark: Color(hex: "F4BE7B"))
    static let error = Color(light: Color(hex: "BA1A1A"), dark: Color(hex: "FFB4AB"))

    static var onPrimary: Color {
        ThemeColorCustomization.readableForegroundColor(
            on: primary,
            light: Color(hex: "1D1B20"),
            dark: Color.white
        )
    }

    static let cardRadius: CGFloat = 24
    static let compactRadius: CGFloat = 16
    static let chipRadius: CGFloat = 12
    static let buttonRadius: CGFloat = 20
    static let sheetRadius: CGFloat = 30

    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: ThemeColorCustomization.accentGradientColors(
                for: .material,
                fallback: [primary, tertiary],
                fallbackHexes: ["6750A4", "7D5260"]
            ),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func titleFont(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func bodyFont(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func labelFont(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func elevationShadow(_ scheme: ColorScheme, level: Int = 1) -> Color {
        let opacity: Double
        switch level {
        case 3...: opacity = scheme == .dark ? 0.34 : 0.16
        case 2: opacity = scheme == .dark ? 0.26 : 0.11
        default: opacity = scheme == .dark ? 0.18 : 0.07
        }
        return Color.black.opacity(opacity)
    }
}

enum MaterialSurfaceRole {
    case page
    case surface
    case container
    case elevated
    case tonal
    case selected
    case floating
}

struct MaterialRootBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            ThemeCustomDiffuseBackground(
                theme: .material,
                fallbackHexes: colorScheme == .dark
                    ? ["141218", "211F26", "1D1B2E", "1A2522"]
                    : ["FFFBFE", "F7F2FA", "EEF4FF", "FFF2F6"],
                accentFallbackHexes: ["6750A4", "7D5260", "3E6E9E"],
                opacity: colorScheme == .dark ? 0.56 : 0.7
            )

            LinearGradient(
                colors: [
                    MaterialStyle.surface.opacity(colorScheme == .dark ? 0.86 : 0.92),
                    MaterialStyle.surfaceContainerLow.opacity(colorScheme == .dark ? 0.78 : 0.76),
                    MaterialStyle.surfaceDim.opacity(colorScheme == .dark ? 0.58 : 0.24),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            MaterialAmbientShapes()
        }
        .transaction { transaction in
            transaction.animation = nil
            transaction.disablesAnimations = true
        }
        .accessibilityHidden(true)
        .ignoresSafeArea()
    }
}

private struct MaterialAmbientShapes: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack {
                RoundedRectangle(cornerRadius: 64, style: .continuous)
                    .fill(MaterialStyle.primary.opacity(colorScheme == .dark ? 0.1 : 0.075))
                    .frame(width: width * 0.72, height: max(140, height * 0.2))
                    .rotationEffect(.degrees(-9))
                    .offset(x: -width * 0.25, y: -height * 0.06)

                RoundedRectangle(cornerRadius: 72, style: .continuous)
                    .fill(MaterialStyle.tertiary.opacity(colorScheme == .dark ? 0.11 : 0.09))
                    .frame(width: width * 0.72, height: max(150, height * 0.22))
                    .rotationEffect(.degrees(12))
                    .offset(x: width * 0.34, y: height * 0.54)

                Capsule()
                    .fill(MaterialStyle.blue.opacity(colorScheme == .dark ? 0.08 : 0.055))
                    .frame(width: width * 0.42, height: max(52, height * 0.06))
                    .rotationEffect(.degrees(-18))
                    .offset(x: width * 0.28, y: height * 0.12)
            }
            .blendMode(colorScheme == .dark ? .plusLighter : .softLight)
        }
        .allowsHitTesting(false)
    }
}

struct MaterialSurfaceBackground: View {
    var cornerRadius: CGFloat = MaterialStyle.cardRadius
    var elevated: Bool = false
    var pressed: Bool = false
    var role: MaterialSurfaceRole = .surface

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let fill = fillColor

        ZStack {
            shape
                .fill(fill)

            if role == .tonal || role == .selected || role == .floating {
                shape
                    .fill(
                        LinearGradient(
                            colors: [
                                MaterialStyle.primary.opacity(colorScheme == .dark ? 0.16 : 0.1),
                                .clear,
                                MaterialStyle.tertiary.opacity(colorScheme == .dark ? 0.1 : 0.07),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            shape
                .strokeBorder(borderColor, lineWidth: role == .selected ? 1.2 : 0.75)
        }
        .shadow(
            color: elevated ? MaterialStyle.elevationShadow(colorScheme, level: role == .floating ? 3 : 1) : .clear,
            radius: elevated ? (role == .floating ? 18 : 10) : 0,
            x: 0,
            y: elevated ? (role == .floating ? 8 : 4) : 0
        )
    }

    private var fillColor: Color {
        switch role {
        case .page:
            return MaterialStyle.surface.opacity(0.8)
        case .surface:
            return MaterialStyle.surfaceContainerLow.opacity(0.96)
        case .container:
            return MaterialStyle.surfaceContainer.opacity(0.98)
        case .elevated:
            return MaterialStyle.surfaceContainerHigh.opacity(0.98)
        case .tonal:
            return MaterialStyle.surfaceContainer.opacity(0.96)
        case .selected:
            return MaterialStyle.surfaceContainerHigh.opacity(0.98)
        case .floating:
            return MaterialStyle.surfaceContainerHighest.opacity(0.94)
        }
    }

    private var borderColor: Color {
        switch role {
        case .selected:
            return MaterialStyle.primary.opacity(0.34)
        case .floating:
            return MaterialStyle.outlineStrong.opacity(0.42)
        default:
            return MaterialStyle.outline.opacity(0.6)
        }
    }
}

struct MaterialIconBadge: View {
    var icon: MonologueIcon.IconType
    var tint: Color = MaterialStyle.primary
    var size: CGFloat = 46

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.34, style: .continuous)
                .fill(tint.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.34, style: .continuous)
                        .stroke(tint.opacity(0.18), lineWidth: 0.8)
                )

            MonologueIcon(icon: icon, size: size * 0.43, color: tint, lineWidth: 1.7)
        }
        .frame(width: size, height: size)
    }
}

struct MaterialPill: View {
    let title: String
    var icon: MonologueIcon.IconType?
    var isSelected = false
    var tint: Color = MaterialStyle.primary

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                MonologueIcon(icon: icon, size: 13, color: foreground, lineWidth: 1.7)
            }
            Text(title)
                .font(MaterialStyle.labelFont(12, weight: .semibold))
                .foregroundColor(foreground)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(isSelected ? tint.opacity(0.14) : MaterialStyle.surfaceContainer.opacity(0.86))
                .overlay(Capsule().stroke(isSelected ? tint.opacity(0.4) : MaterialStyle.outline, lineWidth: 0.8))
        )
    }

    private var foreground: Color {
        isSelected ? tint : MaterialStyle.inkSoft
    }
}

struct MaterialPageHeader<Accessory: View>: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let accessory: Accessory

    init(
        eyebrow: String,
        title: String,
        subtitle: String = "",
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.accessory = accessory()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                if !eyebrow.isEmpty {
                    Text(eyebrow.uppercased())
                        .font(MaterialStyle.labelFont(11, weight: .bold))
                        .foregroundColor(MaterialStyle.primary)
                        .tracking(0.8)
                        .lineLimit(1)
                }

                Text(title)
                    .font(MaterialStyle.titleFont(27, weight: .bold))
                    .foregroundColor(MaterialStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(MaterialStyle.bodyFont(13, weight: .medium))
                        .foregroundColor(MaterialStyle.inkMuted)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 10)
            accessory
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(MaterialSurfaceBackground(cornerRadius: 26, elevated: false, role: .tonal))
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
        .padding(.top, DeviceLayout.headerTopPadding + 6)
        .padding(.bottom, 8)
    }
}

struct MaterialControlButton: View {
    let icon: MonologueIcon.IconType
    var isSelected = false
    var tint: Color = MaterialStyle.primary
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            MonologueIcon(icon: icon, size: 18, color: isSelected ? MaterialStyle.onPrimary : tint, lineWidth: 1.8)
                .frame(width: 42, height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(isSelected ? tint : MaterialStyle.surfaceContainerHigh)
                        .overlay(
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .stroke(isSelected ? Color.clear : MaterialStyle.outline, lineWidth: 0.8)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}
