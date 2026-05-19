import SwiftUI

enum NeumorphicStyle {
    static var isActive: Bool {
        UserDefaults.standard.string(forKey: "globalThemeId") == GlobalThemeId.neumorphic.rawValue
    }

    static var base: Color {
        ThemeColorCustomization.backgroundBase(for: .neumorphic, fallback: Color(light: Color(hex: "E9EDF0"), dark: Color(hex: "202429")), fallbackHex: "E9EDF0")
    }

    static let baseWarm = Color(light: Color(hex: "F2EEE8"), dark: Color(hex: "292722"))
    static let surface = Color(light: Color(hex: "EEF2F4"), dark: Color(hex: "252A30"))
    static let surfaceRaised = Color(light: Color(hex: "F8FAFA"), dark: Color(hex: "2D333A"))
    static let surfacePressed = Color(light: Color(hex: "DDE3E7"), dark: Color(hex: "1B1F24"))
    static let ink = Color(light: Color(hex: "263038"), dark: Color(hex: "F0F4F3"))
    static let inkSoft = Color(light: Color(hex: "65717A"), dark: Color(hex: "B9C2C2"))
    static let inkMuted = Color(light: Color(hex: "8A969E"), dark: Color(hex: "899397"))
    static var accent: Color {
        ThemeColorCustomization.accentColor(for: .neumorphic, fallback: Color(light: Color(hex: "4F8E86"), dark: Color(hex: "7AB9B0")), fallbackHex: "4F8E86")
    }

    static let sage = Color(light: Color(hex: "7D9475"), dark: Color(hex: "9EBA91"))
    static let warm = Color(light: Color(hex: "C59A66"), dark: Color(hex: "D2AC78"))
    static let red = Color(light: Color(hex: "C65A58"), dark: Color(hex: "E07A78"))
    static let separator = Color(light: Color(hex: "C9D0D4"), dark: Color(hex: "3A4149"))
    static let steel = Color(light: Color(hex: "4F8E86"), dark: Color(hex: "7AB9B0"))

    static let cardRadius: CGFloat = 24
    static let compactRadius: CGFloat = 18
    static let buttonRadius: CGFloat = 18

    static func titleFont(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func bodyFont(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func labelFont(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func darkShadow(_ scheme: ColorScheme, intensity: Double = 1) -> Color {
        scheme == .dark
            ? Color.black.opacity(0.44 * intensity)
            : Color(hex: "AAB3BA").opacity(0.46 * intensity)
    }

    static func lightShadow(_ scheme: ColorScheme, intensity: Double = 1) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.055 * intensity)
            : Color.white.opacity(0.94 * intensity)
    }
}

struct NeumorphicRootBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            ThemeCustomDiffuseBackground(
                theme: .neumorphic,
                fallbackHexes: colorScheme == .dark ? ["202429", "292722"] : ["E9EDF0", "F2EEE8"],
                accentFallbackHexes: ["4F8E86", "7D9475"],
                opacity: colorScheme == .dark ? 0.82 : 1
            )

            NeumorphicDiffuseGradient()

            NeumorphicReliefTexture(opacity: colorScheme == .dark ? 0.035 : 0.055)
        }
        .transaction { transaction in
            transaction.animation = nil
            transaction.disablesAnimations = true
        }
        .accessibilityHidden(true)
        .ignoresSafeArea()
    }
}

struct NeumorphicDiffuseGradient: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    NeumorphicStyle.accent.opacity(colorScheme == .dark ? 0.18 : 0.13),
                    .clear,
                    .clear,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                colors: [
                    .clear,
                    NeumorphicStyle.warm.opacity(colorScheme == .dark ? 0.14 : 0.11),
                    .clear,
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )

            LinearGradient(
                colors: [
                    .clear,
                    .clear,
                    NeumorphicStyle.sage.opacity(colorScheme == .dark ? 0.16 : 0.12),
                ],
                startPoint: .bottomLeading,
                endPoint: .topTrailing
            )
        }
        .transaction { transaction in
            transaction.animation = nil
            transaction.disablesAnimations = true
        }
        .allowsHitTesting(false)
    }
}

struct NeumorphicReliefTexture: View {
    var opacity: Double = 0.12

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.white.opacity(opacity),
                    .clear,
                    Color.black.opacity(opacity * 0.16),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                colors: [
                    .clear,
                    Color.white.opacity(opacity * 0.42),
                    .clear,
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        .transaction { transaction in
            transaction.animation = nil
            transaction.disablesAnimations = true
        }
        .allowsHitTesting(false)
    }
}

struct NeumorphicSurfaceBackground: View {
    var cornerRadius: CGFloat = NeumorphicStyle.cardRadius
    var elevated: Bool = true
    var pressed: Bool = false
    var tint: Color? = nil
    var lightweight: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let darkShadowRadius: CGFloat = lightweight ? (elevated ? 5 : 2) : (elevated ? 7 : 3)
        let darkOffset: CGFloat = lightweight ? (elevated ? 3 : 1.5) : (elevated ? 4 : 2)
        let darkIntensity: Double = lightweight ? (elevated ? 0.42 : 0.2) : (elevated ? 0.48 : 0.24)
        let fillGradient = LinearGradient(
            colors: [
                (tint ?? (pressed ? NeumorphicStyle.surfacePressed : NeumorphicStyle.surfaceRaised)).opacity(pressed ? 0.96 : 1),
                (tint ?? NeumorphicStyle.surface).opacity(0.96),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        let strokeGradient = LinearGradient(
            colors: [
                NeumorphicStyle.lightShadow(colorScheme, intensity: colorScheme == .dark ? 0.7 : 0.82),
                NeumorphicStyle.darkShadow(colorScheme, intensity: 0.22),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        let strokeWidth: CGFloat = lightweight ? (pressed ? 0.85 : 0.65) : (pressed ? 1.2 : 0.8)

        if lightweight {
            shape
                .fill(fillGradient)
                .overlay(
                    shape.stroke(strokeGradient, lineWidth: strokeWidth)
                )
                .shadow(
                    color: pressed ? .clear : NeumorphicStyle.darkShadow(colorScheme, intensity: darkIntensity),
                    radius: darkShadowRadius,
                    x: darkOffset,
                    y: darkOffset
                )
                .overlay {
                    if elevated && !pressed {
                        shape
                            .stroke(
                                NeumorphicStyle.lightShadow(colorScheme, intensity: colorScheme == .dark ? 0.22 : 0.42),
                                lineWidth: 0.7
                            )
                            .offset(x: -0.8, y: -0.8)
                            .clipShape(shape)
                    }
                }
                .transaction { transaction in
                    transaction.animation = nil
                    transaction.disablesAnimations = true
                }
                .themeRenderRowLayer()
        } else {
            shape
                .fill(fillGradient)
                .overlay(
                    shape.stroke(strokeGradient, lineWidth: strokeWidth)
                )
                .shadow(
                    color: pressed ? .clear : NeumorphicStyle.darkShadow(colorScheme, intensity: darkIntensity),
                    radius: darkShadowRadius,
                    x: darkOffset,
                    y: darkOffset
                )
                .overlay {
                    if pressed && !lightweight {
                        shape
                            .stroke(NeumorphicStyle.darkShadow(colorScheme, intensity: 0.36), lineWidth: 0.8)
                            .offset(x: 1.3, y: 1.3)
                            .clipShape(shape)
                        shape
                            .stroke(NeumorphicStyle.lightShadow(colorScheme, intensity: 0.58), lineWidth: 0.8)
                            .offset(x: -1.3, y: -1.3)
                            .clipShape(shape)
                    } else if elevated {
                        shape
                            .stroke(
                                NeumorphicStyle.lightShadow(colorScheme, intensity: colorScheme == .dark ? 0.28 : 0.5),
                                lineWidth: 0.8
                            )
                            .offset(x: -0.9, y: -0.9)
                            .clipShape(shape)
                    }
                }
                .transaction { transaction in
                    transaction.animation = nil
                    transaction.disablesAnimations = true
                }
                .themeRenderLayer(lightweight ? .row : .surface)
        }
    }
}

struct NeumorphicIconBadge: View {
    let icon: MonologueIcon.IconType
    var tint: Color = NeumorphicStyle.accent
    var size: CGFloat = 46
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        let _ = settings.globalThemeRevision
        NeumorphicSurfaceBackground(cornerRadius: size * 0.32, elevated: true, tint: NeumorphicStyle.surfaceRaised, lightweight: true)
            .frame(width: size, height: size)
            .overlay(
                MonologueIcon(
                    icon: icon,
                    size: size * 0.42,
                    color: ThemeColorCustomization.visibleTintColor(tint, darkFallback: NeumorphicStyle.ink),
                    lineWidth: 1.55
                )
            )
            .themeRenderInteractiveLayer()
    }
}

struct NeumorphicPill: View {
    let text: String
    var tint: Color = NeumorphicStyle.accent
    var icon: MonologueIcon.IconType?
    var selected: Bool = false
    var compact: Bool = false
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        let _ = settings.globalThemeRevision
        HStack(spacing: icon == nil ? 0 : 7) {
            if let icon {
                MonologueIcon(icon: icon, size: compact ? 11 : 13, color: foreground, lineWidth: 1.55)
            }

            Text(text)
                .font(NeumorphicStyle.labelFont(compact ? 10 : 12, weight: selected ? .semibold : .medium))
                .foregroundStyle(foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, compact ? 9 : 12)
        .padding(.vertical, compact ? 5 : 8)
        .background(
            NeumorphicSurfaceBackground(
                cornerRadius: compact ? 12 : 15,
                elevated: selected,
                pressed: !selected,
                tint: selected ? tint.opacity(0.22) : NeumorphicStyle.surface,
                lightweight: true
            )
        )
        .themeRenderInteractiveLayer()
    }

    private var foreground: Color {
        selected ? tint : NeumorphicStyle.inkSoft
    }
}

struct NeumorphicPlayPill: View {
    let title: String
    var icon: MonologueIcon.IconType = .play
    var tint: Color = NeumorphicStyle.accent
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        let _ = settings.globalThemeRevision
        HStack(spacing: 7) {
            MonologueIcon(icon: icon, size: 13, color: foreground, lineWidth: 1.7)
            Text(title)
                .font(NeumorphicStyle.labelFont(12, weight: .semibold))
                .foregroundStyle(foreground)
                .lineLimit(1)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(tint)
        )
        .shadow(color: tint.opacity(0.24), radius: 10, x: 0, y: 5)
        .themeRenderInteractiveLayer()
    }

    private var foreground: Color {
        ThemeColorCustomization.readableForegroundColor(
            on: tint,
            light: Color(hex: "172026"),
            dark: Color.white
        )
    }
}

struct NeumorphicActionButton<Content: View>: View {
    var size: CGFloat = 42
    var action: () -> Void
    var content: Content

    init(size: CGFloat = 42, action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.size = size
        self.action = action
        self.content = content()
    }

    var body: some View {
        Button(action: action) {
            content
                .frame(width: size, height: size)
                .background(NeumorphicSurfaceBackground(cornerRadius: size * 0.36, elevated: true, lightweight: true))
                .contentShape(RoundedRectangle(cornerRadius: size * 0.36, style: .continuous))
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))
        .themeRenderInteractiveLayer()
    }
}

struct NeumorphicSectionTitle: View {
    let title: String
    var detail: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            NeumorphicIconBadge(icon: .sparkle, tint: NeumorphicStyle.warm, size: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(NeumorphicStyle.titleFont(18, weight: .semibold))
                    .foregroundStyle(NeumorphicStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(NeumorphicStyle.labelFont(11))
                        .foregroundStyle(NeumorphicStyle.inkMuted)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(NeumorphicStyle.labelFont(11, weight: .semibold))
                        .foregroundStyle(NeumorphicStyle.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(NeumorphicSurfaceBackground(cornerRadius: 14, elevated: false, lightweight: true))
                }
                .buttonStyle(.plain)
                .themeRenderInteractiveLayer()
            }
        }
        .themeRenderSurfaceLayer()
    }
}

struct NeumorphicPageHeader<Accessory: View>: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    @ViewBuilder let accessory: Accessory

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(eyebrow.uppercased())
                    .font(NeumorphicStyle.labelFont(10, weight: .semibold))
                    .foregroundStyle(NeumorphicStyle.accent)
                    .tracking(1.2)

                Text(title)
                    .font(NeumorphicStyle.titleFont(29, weight: .semibold))
                    .foregroundStyle(NeumorphicStyle.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(NeumorphicStyle.bodyFont(12))
                        .foregroundStyle(NeumorphicStyle.inkSoft)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
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

extension NeumorphicPageHeader where Accessory == EmptyView {
    init(eyebrow: String, title: String, subtitle: String) {
        self.init(eyebrow: eyebrow, title: title, subtitle: subtitle) {
            EmptyView()
        }
    }
}

extension View {
    @ViewBuilder
    func neumorphicSurfaceIfNeeded() -> some View {
        if NeumorphicStyle.isActive {
            background(ThemeRenderBackdrop(theme: .neumorphic))
        } else {
            self
        }
    }

    func neumorphicStagger(_ appeared: Bool, order: Int) -> some View {
        opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
            .scaleEffect(appeared ? 1 : 0.985)
            .animation(.spring(response: 0.5, dampingFraction: 0.86).delay(Double(order) * 0.055), value: appeared)
    }
}

/// 玻璃质感新拟物背景（用于悬浮栏等需要半透明效果的场景）
struct NeumorphicGlassSurfaceBackground: View {
    var cornerRadius: CGFloat = NeumorphicStyle.cardRadius
    var elevated: Bool = true

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        shape
            .fill(NeumorphicStyle.surface.opacity(colorScheme == .dark ? 0.92 : 0.94))
            .overlay(
                shape.stroke(
                    LinearGradient(
                        colors: [
                            NeumorphicStyle.lightShadow(colorScheme, intensity: colorScheme == .dark ? 0.5 : 0.7),
                            NeumorphicStyle.darkShadow(colorScheme, intensity: 0.18),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
            )
            .shadow(
                color: NeumorphicStyle.darkShadow(colorScheme, intensity: elevated ? 0.38 : 0.18),
                radius: elevated ? 12 : 5,
                x: elevated ? 4 : 2,
                y: elevated ? 4 : 2
            )
    }
}
