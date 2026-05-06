import SwiftUI

enum ClayStyle {
    static var isActive: Bool {
        false
    }

    static var base: Color {
        ThemeColorCustomization.backgroundBase(
            for: .clay,
            fallback: Color(light: Color(hex: "F7EAD8"), dark: Color(hex: "F7EAD8")),
            fallbackHex: "F7EAD8"
        )
    }

    static var accent: Color {
        ThemeColorCustomization.accentColor(
            for: .clay,
            fallback: Color(light: Color(hex: "35BFE6"), dark: Color(hex: "35BFE6")),
            fallbackHex: "35BFE6"
        )
    }

    static let butter = Color(light: Color(hex: "FFC94A"), dark: Color(hex: "FFC94A"))
    static let mint = Color(light: Color(hex: "74DDB8"), dark: Color(hex: "74DDB8"))
    static let sky = Color(light: Color(hex: "7BD8F3"), dark: Color(hex: "7BD8F3"))
    static let grape = Color(light: Color(hex: "A8A2FF"), dark: Color(hex: "A8A2FF"))
    static let berry = Color(light: Color(hex: "FF7F91"), dark: Color(hex: "FF7F91"))
    static let peach = Color(light: Color(hex: "FFAD72"), dark: Color(hex: "FFAD72"))
    static let cream = Color(light: Color(hex: "FFF7EC"), dark: Color(hex: "FFF7EC"))
    static let creamRaised = Color(light: Color(hex: "FFE6BF"), dark: Color(hex: "FFE6BF"))
    static let creamPressed = Color(light: Color(hex: "EED4B1"), dark: Color(hex: "EED4B1"))
    static let ink = Color(light: Color(hex: "30435A"), dark: Color(hex: "30435A"))
    static let inkSoft = Color(light: Color(hex: "607087"), dark: Color(hex: "607087"))
    static let inkMuted = Color(light: Color(hex: "8C98A8"), dark: Color(hex: "8C98A8"))
    static let separator = Color(light: Color(hex: "E7CDAA"), dark: Color(hex: "E7CDAA"))
    static let red = Color(light: Color(hex: "FF6F7E"), dark: Color(hex: "FF6F7E"))

    static let cardRadius: CGFloat = 28
    static let compactRadius: CGFloat = 20
    static let buttonRadius: CGFloat = 18

    static func titleFont(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func bodyFont(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func labelFont(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func shadowColor(_ scheme: ColorScheme, intensity: Double = 1) -> Color {
        Color(hex: "B88F68").opacity((scheme == .dark ? 0.2 : 0.24) * intensity)
    }

    static func highlightColor(_ scheme: ColorScheme, intensity: Double = 1) -> Color {
        Color.white.opacity((scheme == .dark ? 0.08 : 0.12) * intensity)
    }
}

struct ClayRootBackdrop: View {
    var body: some View {
        ZStack {
            ThemeCustomDiffuseBackground(
                theme: .clay,
                fallbackHexes: ["F7EAD8", "DDF3FA"],
                accentFallbackHexes: ["35BFE6", "FF7F91", "FFC94A"],
                opacity: 1
            )

            ClaySoftBlob(color: ClayStyle.sky, x: 0.12, y: 0.08, size: 0.5, opacity: 0.22)
            ClaySoftBlob(color: ClayStyle.grape, x: 0.94, y: 0.22, size: 0.42, opacity: 0.16)
            ClaySoftBlob(color: ClayStyle.berry, x: 0.05, y: 0.82, size: 0.5, opacity: 0.15)
            ClayPuddle(color: Color(hex: "DDBE95").opacity(0.2), y: 0.98)
            ClayPuddle(color: Color.white.opacity(0.22), y: 0.02, flipped: true)

            ClayGrainTexture(opacity: 0.045)
        }
        .transaction { transaction in
            transaction.animation = nil
            transaction.disablesAnimations = true
        }
        .accessibilityHidden(true)
        .ignoresSafeArea()
    }
}

private struct ClaySoftBlob: View {
    let color: Color
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let opacity: Double

    var body: some View {
        GeometryReader { proxy in
            Circle()
                .fill(color.opacity(opacity))
                .frame(width: proxy.size.width * size, height: proxy.size.width * size)
                .position(x: proxy.size.width * x, y: proxy.size.height * y)
                .blur(radius: 44)
        }
        .allowsHitTesting(false)
    }
}

private struct ClayGrainTexture: View {
    var opacity: Double

    var body: some View {
        Canvas { context, size in
            for index in 0 ..< 28 {
                let x = size.width * CGFloat((index * 29) % 100) / 100
                let y = size.height * CGFloat((index * 47) % 100) / 100
                let rect = CGRect(x: x, y: y, width: CGFloat(20 + (index % 4) * 12), height: 1.2)
                context.fill(
                    Path(roundedRect: rect, cornerRadius: 0.6),
                    with: .color(ClayStyle.inkMuted.opacity(opacity * (index.isMultiple(of: 3) ? 1.4 : 0.8)))
                )
            }
        }
        .allowsHitTesting(false)
    }
}

private struct ClayPuddle: View {
    var color: Color
    var y: CGFloat
    var flipped = false

    var body: some View {
        GeometryReader { proxy in
            ClayPuddleShape(flipped: flipped)
                .fill(color)
                .frame(width: proxy.size.width * 1.12, height: proxy.size.height * 0.28)
                .position(x: proxy.size.width * 0.5, y: proxy.size.height * y)
                .blur(radius: 3)
        }
        .allowsHitTesting(false)
    }
}

private struct ClayPuddleShape: Shape {
    var flipped: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let top = flipped ? rect.maxY : rect.minY
        let bottom = flipped ? rect.minY : rect.maxY
        path.move(to: CGPoint(x: rect.minX, y: top + (flipped ? -rect.height * 0.12 : rect.height * 0.12)))
        path.addCurve(
            to: CGPoint(x: rect.maxX * 0.34, y: top + (flipped ? -rect.height * 0.22 : rect.height * 0.22)),
            control1: CGPoint(x: rect.maxX * 0.11, y: top + (flipped ? -rect.height * 0.02 : rect.height * 0.02)),
            control2: CGPoint(x: rect.maxX * 0.22, y: top + (flipped ? -rect.height * 0.33 : rect.height * 0.33))
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX * 0.72, y: top + (flipped ? -rect.height * 0.1 : rect.height * 0.1)),
            control1: CGPoint(x: rect.maxX * 0.46, y: top + (flipped ? -rect.height * 0.08 : rect.height * 0.08)),
            control2: CGPoint(x: rect.maxX * 0.58, y: top + (flipped ? -rect.height * 0.34 : rect.height * 0.34))
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: top + (flipped ? -rect.height * 0.2 : rect.height * 0.2)),
            control1: CGPoint(x: rect.maxX * 0.82, y: top + (flipped ? -rect.height * 0.02 : rect.height * 0.02)),
            control2: CGPoint(x: rect.maxX * 0.92, y: top + (flipped ? -rect.height * 0.26 : rect.height * 0.26))
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: bottom))
        path.addLine(to: CGPoint(x: rect.minX, y: bottom))
        path.closeSubpath()
        return path
    }
}

struct ClaySurfaceBackground: View {
    var cornerRadius: CGFloat = ClayStyle.cardRadius
    var tint: Color? = nil
    var elevated = true
    var pressed = false
    var compact = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let base = tint ?? (pressed ? ClayStyle.creamPressed : ClayStyle.creamRaised)
        let depth: CGFloat = pressed ? 1 : (compact ? 4 : (elevated ? 9 : 6))
        let radius: CGFloat = compact ? 7 : (elevated ? 15 : 9)

        ZStack {
            shape
                .fill(shadowFill(for: base))
                .offset(x: compact ? 2 : 3.5, y: depth)
                .blur(radius: pressed ? 0.2 : 0.6)

            shape
                .fill(base.opacity(pressed ? 0.88 : 1))
                .overlay(
                    shape.stroke(
                        ClayStyle.separator.opacity(colorScheme == .dark ? 0.34 : 0.42),
                        lineWidth: compact ? 0.7 : 1
                    )
                )
        }
        .padding(.bottom, pressed ? 0 : depth)
        .shadow(
            color: pressed ? .clear : ClayStyle.shadowColor(colorScheme, intensity: elevated ? 0.72 : 0.36),
            radius: radius,
            x: compact ? 2 : 5,
            y: compact ? 5 : 12
        )
        .overlay {
                if pressed {
                    shape
                        .stroke(ClayStyle.shadowColor(colorScheme, intensity: 0.5), lineWidth: 0.9)
                        .offset(x: 1.1, y: 1.1)
                        .clipShape(shape)
                }
            }
            .themeRenderSurfaceLayer(isEnabled: elevated && !compact)
    }

    private func shadowFill(for base: Color) -> Color {
        if colorScheme == .dark {
            return Color(hex: "C9A77F").opacity(0.36)
        }
        return Color(hex: "D9B98E").opacity(0.42)
    }
}

struct ClayIconBubble: View {
    let icon: MonologueIcon.IconType
    var tint: Color = ClayStyle.accent
    var size: CGFloat = 44

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.42, style: .continuous)
            .fill(Color.clear)
            .frame(width: size, height: size)
            .background(
                ClaySurfaceBackground(
                    cornerRadius: size * 0.42,
                    tint: tint.opacity(0.95),
                    elevated: true,
                    compact: true
                )
            )
            .overlay(
                MonologueIcon(icon: icon, size: size * 0.43, color: ClayStyle.ink, lineWidth: 1.75)
            )
            .clipShape(RoundedRectangle(cornerRadius: size * 0.42, style: .continuous))
            .themeRenderInteractiveLayer()
    }
}

struct ClayPill: View {
    let text: String
    var icon: MonologueIcon.IconType?
    var tint: Color = ClayStyle.accent
    var selected = false

    var body: some View {
        HStack(spacing: icon == nil ? 0 : 6) {
            if let icon {
                MonologueIcon(icon: icon, size: 12, color: foreground, lineWidth: 1.65)
            }

            Text(text)
                .font(ClayStyle.labelFont(11, weight: .semibold))
                .foregroundStyle(foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            ClaySurfaceBackground(
                cornerRadius: 17,
                tint: selected ? tint.opacity(0.95) : ClayStyle.cream.opacity(0.92),
                elevated: selected,
                pressed: !selected,
                compact: true
            )
        )
        .themeRenderInteractiveLayer()
    }

    private var foreground: Color {
        selected ? ClayStyle.ink : ClayStyle.inkSoft
    }
}

struct ClaySectionHeader<Action: View>: View {
    let title: String
    let icon: MonologueIcon.IconType
    var tint: Color = ClayStyle.accent
    @ViewBuilder let action: Action

    var body: some View {
        HStack(spacing: 10) {
            ClayIconBubble(icon: icon, tint: tint, size: 34)

            Text(title)
                .font(ClayStyle.titleFont(18, weight: .bold))
                .foregroundStyle(ClayStyle.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Spacer(minLength: 8)
            action
        }
    }
}

extension ClaySectionHeader where Action == EmptyView {
    init(title: String, icon: MonologueIcon.IconType, tint: Color = ClayStyle.accent) {
        self.init(title: title, icon: icon, tint: tint) {
            EmptyView()
        }
    }
}

struct ClayPageHeader<Accessory: View>: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    @ViewBuilder let accessory: Accessory

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(eyebrow.uppercased())
                    .font(ClayStyle.labelFont(10, weight: .bold))
                    .foregroundStyle(ClayStyle.accent)
                    .tracking(1.1)

                Text(title)
                    .font(ClayStyle.titleFont(25, weight: .bold))
                    .foregroundStyle(ClayStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            Spacer(minLength: 8)
            accessory
        }
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
        .padding(.top, DeviceLayout.headerTopPadding + 8)
        .padding(.bottom, subtitle.isEmpty ? 8 : 10)
    }
}

extension ClayPageHeader where Accessory == EmptyView {
    init(eyebrow: String, title: String, subtitle: String = "") {
        self.init(eyebrow: eyebrow, title: title, subtitle: subtitle) {
            EmptyView()
        }
    }
}

extension View {
    func clayStagger(_ appeared: Bool, order: Int) -> some View {
        opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
            .scaleEffect(appeared ? 1 : 0.985)
            .animation(.spring(response: 0.44, dampingFraction: 0.82).delay(Double(order) * 0.045), value: appeared)
    }
}
