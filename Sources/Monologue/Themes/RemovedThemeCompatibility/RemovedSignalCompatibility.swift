import SwiftUI

enum SignalStyle {
    static var isActive: Bool {
        false
    }

    static var base: Color {
        ThemeColorCustomization.backgroundBase(
            for: .signal,
            fallback: Color(light: Color(hex: "EEF5F8"), dark: Color(hex: "071116")),
            fallbackHex: "EEF5F8"
        )
    }

    static var accent: Color {
        ThemeColorCustomization.accentColor(
            for: .signal,
            fallback: Color(light: Color(hex: "2F80ED"), dark: Color(hex: "68E3FF")),
            fallbackHex: "2F80ED"
        )
    }

    static let baseWarm = Color(light: Color(hex: "F7F2EA"), dark: Color(hex: "101A1A"))
    static let surface = Color(light: Color(hex: "F8FCFF"), dark: Color(hex: "111D23"))
    static let surfaceRaised = Color(light: Color(hex: "FFFFFF"), dark: Color(hex: "17262D"))
    static let surfaceInset = Color(light: Color(hex: "DDEBF0"), dark: Color(hex: "091419"))
    static let control = Color(light: Color(hex: "E7F1F5"), dark: Color(hex: "122129"))
    static let controlPressed = Color(light: Color(hex: "D5E4EA"), dark: Color(hex: "0A171D"))
    static let paper = Color(light: Color(hex: "FBFEFF"), dark: Color(hex: "132128"))
    static let screen = Color(light: Color(hex: "E8F5F7"), dark: Color(hex: "08151B"))
    static let separator = Color(light: Color(hex: "BFD2DA"), dark: Color(hex: "2B414B"))
    static let ink = Color(light: Color(hex: "102B36"), dark: Color(hex: "F2FBFF"))
    static let inkSoft = Color(light: Color(hex: "506A74"), dark: Color(hex: "B8CBD2"))
    static let inkMuted = Color(light: Color(hex: "8298A0"), dark: Color(hex: "7D939A"))
    static let onAccent = Color(light: Color.white, dark: Color(hex: "04151A"))
    static let red = Color(light: Color(hex: "D45F68"), dark: Color(hex: "FF9AA0"))
    static let aqua = Color(light: Color(hex: "22C7E8"), dark: Color(hex: "78ECFF"))
    static let mint = Color(light: Color(hex: "00A98F"), dark: Color(hex: "5AF0C9"))
    static let moss = Color(light: Color(hex: "719F6A"), dark: Color(hex: "A3D990"))
    static let clay = Color(light: Color(hex: "E19A5E"), dark: Color(hex: "F4B980"))
    static let lavender = Color(light: Color(hex: "7F7BE8"), dark: Color(hex: "B8B5FF"))
    static let amber = Color(light: Color(hex: "C8962C"), dark: Color(hex: "F0C75F"))

    static let device = surface
    static let deviceRaised = surfaceRaised
    static let paperInk = ink
    static let paperMeta = inkSoft
    static let olive = moss
    static let rust = clay
    static let violet = lavender

    static let cardRadius: CGFloat = 26
    static let compactRadius: CGFloat = 18
    static let buttonRadius: CGFloat = 16

    static func titleFont(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func bodyFont(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func labelFont(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func monoFont(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static func darkShadow(_ scheme: ColorScheme, intensity: Double = 1) -> Color {
        scheme == .dark
            ? Color.black.opacity(0.44 * intensity)
            : Color(hex: "6F8994").opacity(0.2 * intensity)
    }

    static func lightShadow(_ scheme: ColorScheme, intensity: Double = 1) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.055 * intensity)
            : Color.white.opacity(0.88 * intensity)
    }

    static func hardShadow(_ scheme: ColorScheme, intensity: Double = 1) -> Color {
        darkShadow(scheme, intensity: intensity * 0.58)
    }
}

struct SignalRootBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            ThemeCustomDiffuseBackground(
                theme: .signal,
                fallbackHexes: colorScheme == .dark ? ["071116", "101A1A"] : ["EEF5F8", "F7F2EA"],
                accentFallbackHexes: ["2F80ED", "00A98F", "E19A5E"],
                opacity: colorScheme == .dark ? 0.8 : 0.98
            )

            SignalAmbientTexture(opacity: colorScheme == .dark ? 0.17 : 0.22)

            LinearGradient(
                colors: [
                    Color.white.opacity(colorScheme == .dark ? 0.02 : 0.35),
                    .clear,
                    SignalStyle.accent.opacity(colorScheme == .dark ? 0.1 : 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .transaction { transaction in
            transaction.animation = nil
            transaction.disablesAnimations = true
        }
        .accessibilityHidden(true)
        .ignoresSafeArea()
    }
}

struct SignalRenderBackdrop: View {
    var body: some View {
        SignalRootBackdrop()
            .transaction { transaction in
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
    }
}

struct SignalAmbientTexture: View {
    var opacity: Double = 0.2

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                Circle()
                    .fill(SignalStyle.aqua.opacity(opacity))
                    .frame(width: size.width * 0.72, height: size.width * 0.72)
                    .blur(radius: 42)
                    .offset(x: -size.width * 0.34, y: -size.height * 0.26)

                Circle()
                    .fill(SignalStyle.mint.opacity(opacity * 0.78))
                    .frame(width: size.width * 0.62, height: size.width * 0.62)
                    .blur(radius: 48)
                    .offset(x: size.width * 0.38, y: -size.height * 0.06)

                Circle()
                    .fill(SignalStyle.clay.opacity(opacity * 0.62))
                    .frame(width: size.width * 0.52, height: size.width * 0.52)
                    .blur(radius: 54)
                    .offset(x: size.width * 0.02, y: size.height * 0.38)

                ForEach(0..<6, id: \.self) { index in
                    Capsule()
                        .fill((index.isMultiple(of: 2) ? SignalStyle.accent : SignalStyle.inkMuted).opacity(opacity * 0.22))
                        .frame(width: size.width * (0.22 + CGFloat(index) * 0.025), height: 3)
                        .rotationEffect(.degrees(-18))
                        .offset(
                            x: size.width * (-0.34 + CGFloat(index) * 0.15),
                            y: size.height * (-0.12 + CGFloat(index) * 0.15)
                        )
                }
            }
            .frame(width: size.width, height: size.height)
        }
        .blendMode(.softLight)
        .allowsHitTesting(false)
    }
}

struct SignalSoftPulseTexture: View {
    var opacity: Double = 0.14
    var lineOpacity: Double = 0.1

    var body: some View {
        SignalAmbientTexture(opacity: opacity + lineOpacity * 0.35)
    }
}

struct SignalGridTexture: View {
    var opacity: Double = 0.1
    var gap: CGFloat = 22

    var body: some View {
        SignalAmbientTexture(opacity: opacity)
            .opacity(max(0.2, min(0.62, gap / 36)))
    }
}

struct SignalScanlineTexture: View {
    var opacity: Double = 0.1
    var gap: CGFloat = 6

    var body: some View {
        SignalAmbientTexture(opacity: opacity)
            .opacity(max(0.18, min(0.5, gap / 16)))
    }
}

struct SignalSurfaceBackground: View {
    var cornerRadius: CGFloat = SignalStyle.cardRadius
    var elevated: Bool = true
    var pressed: Bool = false
    var fill: Color? = nil
    var stroke: Color? = nil

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let base = fill ?? (pressed ? SignalStyle.controlPressed : SignalStyle.surface)
        let line = stroke ?? SignalStyle.separator.opacity(colorScheme == .dark ? 0.5 : 0.62)

        shape
            .fill(
                LinearGradient(
                    colors: [
                        (pressed ? SignalStyle.surfaceInset : SignalStyle.surfaceRaised).opacity(colorScheme == .dark ? 0.7 : 0.98),
                        base.opacity(colorScheme == .dark ? 0.92 : 0.98)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(shape.stroke(line, lineWidth: pressed ? 0.8 : 0.7))
            .overlay(alignment: .topLeading) {
                if elevated && !pressed {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [SignalStyle.accent.opacity(0.72), SignalStyle.mint.opacity(0.46)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 48, height: 4)
                        .padding(.top, 13)
                        .padding(.leading, 15)
                }
            }
            .shadow(
                color: pressed ? .clear : SignalStyle.darkShadow(colorScheme, intensity: elevated ? 0.68 : 0.24),
                radius: elevated ? 18 : 5,
                x: elevated ? 8 : 2,
                y: elevated ? 10 : 3
            )
            .shadow(
                color: pressed ? .clear : SignalStyle.lightShadow(colorScheme, intensity: elevated ? 0.72 : 0.3),
                radius: elevated ? 12 : 4,
                x: elevated ? -6 : -2,
                y: elevated ? -6 : -2
            )
            .overlay {
                if pressed {
                    shape
                        .stroke(SignalStyle.darkShadow(colorScheme, intensity: 0.28), lineWidth: 0.8)
                        .offset(x: 1, y: 1)
                        .clipShape(shape)
                    shape
                        .stroke(SignalStyle.lightShadow(colorScheme, intensity: 0.38), lineWidth: 0.8)
                        .offset(x: -1, y: -1)
                        .clipShape(shape)
                }
            }
            .transaction { transaction in
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
    }
}

struct SignalScreenBackground: View {
    var cornerRadius: CGFloat = 18

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        shape
            .fill(
                LinearGradient(
                    colors: [
                        SignalStyle.screen.opacity(colorScheme == .dark ? 0.98 : 0.94),
                        SignalStyle.surfaceInset.opacity(colorScheme == .dark ? 0.72 : 0.86)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(shape.stroke(SignalStyle.accent.opacity(0.2), lineWidth: 0.8))
            .overlay(alignment: .topLeading) {
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        Capsule()
                            .fill((index == 0 ? SignalStyle.accent : SignalStyle.inkMuted).opacity(index == 0 ? 0.8 : 0.28))
                            .frame(width: index == 0 ? 22 : 8, height: 4)
                    }
                }
                .padding(12)
            }
            .shadow(color: SignalStyle.darkShadow(colorScheme, intensity: 0.2), radius: 4, x: 2, y: 2)
            .shadow(color: SignalStyle.lightShadow(colorScheme, intensity: 0.24), radius: 4, x: -2, y: -2)
    }
}

struct SignalIconBadge: View {
    let icon: MonologueIcon.IconType
    var tint: Color = SignalStyle.accent
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            SignalSurfaceBackground(cornerRadius: size * 0.36, elevated: true, fill: SignalStyle.surfaceRaised)

            RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
                .fill(tint.opacity(0.13))
                .frame(width: size * 0.62, height: size * 0.62)

            MonologueIcon(icon: icon, size: size * 0.4, color: tint, lineWidth: 1.65)
        }
        .frame(width: size, height: size)
        .themeRenderInteractiveLayer()
    }
}

struct SignalPill: View {
    let text: String
    var tint: Color = SignalStyle.accent
    var icon: MonologueIcon.IconType?
    var selected: Bool = false
    var compact: Bool = false

    var body: some View {
        HStack(spacing: icon == nil ? 0 : 6) {
            if let icon {
                MonologueIcon(icon: icon, size: compact ? 10 : 12, color: foreground, lineWidth: 1.6)
            }

            Text(text)
                .font(SignalStyle.labelFont(compact ? 10 : 11, weight: selected ? .bold : .semibold))
                .foregroundStyle(foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, compact ? 9 : 12)
        .padding(.vertical, compact ? 5 : 7)
        .background(
            Capsule(style: .continuous)
                .fill(selected ? tint.opacity(0.16) : SignalStyle.control.opacity(0.82))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(selected ? tint.opacity(0.38) : SignalStyle.separator.opacity(0.52), lineWidth: 0.7)
        )
        .themeRenderInteractiveLayer()
    }

    private var foreground: Color {
        selected ? tint : SignalStyle.inkSoft
    }
}

struct SignalPlayPill: View {
    let title: String
    var icon: MonologueIcon.IconType = .play
    var tint: Color = SignalStyle.accent

    var body: some View {
        HStack(spacing: 7) {
            MonologueIcon(icon: icon, size: 12, color: SignalStyle.onAccent, lineWidth: 1.8)
            Text(title)
                .font(SignalStyle.labelFont(11, weight: .bold))
                .foregroundStyle(SignalStyle.onAccent)
                .lineLimit(1)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
        .background(
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [tint, SignalStyle.mint.opacity(0.94)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(Capsule(style: .continuous).stroke(Color.white.opacity(0.24), lineWidth: 0.8))
        .shadow(color: tint.opacity(0.22), radius: 14, x: 0, y: 8)
        .themeRenderInteractiveLayer()
    }
}

struct SignalActionButton<Content: View>: View {
    var size: CGFloat = 42
    var action: () -> Void
    @ViewBuilder let content: Content

    init(size: CGFloat = 42, action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.size = size
        self.action = action
        self.content = content()
    }

    var body: some View {
        Button(action: action) {
            content
                .frame(width: size, height: size)
                .background(SignalSurfaceBackground(cornerRadius: size * 0.36, elevated: true, fill: SignalStyle.surfaceRaised))
                .contentShape(RoundedRectangle(cornerRadius: size * 0.36, style: .continuous))
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))
        .themeRenderInteractiveLayer()
    }
}

struct SignalSectionTitle: View {
    let title: String
    var detail: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            SignalPulseDot(tint: SignalStyle.accent, size: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(SignalStyle.titleFont(18, weight: .bold))
                    .foregroundStyle(SignalStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(SignalStyle.labelFont(10, weight: .medium))
                        .foregroundStyle(SignalStyle.inkMuted)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            if let actionTitle, let action {
                Button(action: action) {
                    SignalPill(text: actionTitle, tint: SignalStyle.accent, icon: .chevronRight, compact: true)
                }
                .buttonStyle(.plain)
                .themeRenderInteractiveLayer()
            }
        }
        .themeRenderSurfaceLayer()
    }
}

struct SignalPulseDot: View {
    var tint: Color = SignalStyle.accent
    var size: CGFloat = 18

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                .fill(tint.opacity(0.14))
                .frame(width: size, height: size)
            Capsule()
                .fill(tint)
                .frame(width: size * 0.42, height: size * 0.42)
        }
        .background(SignalSurfaceBackground(cornerRadius: size * 0.35, elevated: false, pressed: true, fill: SignalStyle.control))
    }
}

struct SignalPageHeader<Accessory: View>: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    @ViewBuilder let accessory: Accessory

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                Text(eyebrow.uppercased())
                    .font(SignalStyle.monoFont(10, weight: .bold))
                    .foregroundStyle(SignalStyle.accent)

                Text(title)
                    .font(SignalStyle.titleFont(27, weight: .bold))
                    .foregroundStyle(SignalStyle.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(SignalStyle.labelFont(12, weight: .medium))
                        .foregroundStyle(SignalStyle.inkSoft)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)
            accessory
        }
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
        .padding(.top, DeviceLayout.headerTopPadding + 8)
        .padding(.bottom, 12)
        .themeRenderSurfaceLayer()
    }
}

extension SignalPageHeader where Accessory == EmptyView {
    init(eyebrow: String, title: String, subtitle: String) {
        self.init(eyebrow: eyebrow, title: title, subtitle: subtitle) {
            EmptyView()
        }
    }
}

extension View {
    func signalStagger(_ appeared: Bool, order: Int) -> some View {
        opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
            .animation(.easeOut(duration: 0.24).delay(Double(order) * 0.026), value: appeared)
    }
}
