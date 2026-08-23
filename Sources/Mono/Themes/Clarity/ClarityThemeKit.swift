import SwiftUI

// THESIS: “通透”是一整块被音乐封面染色的空气层，拒绝换色主题和碎片化玻璃卡片。
// OWN-WORLD: 雾白底、黑色高对比控件、青紫桃色边缘折射、厚白光沿与柔软悬浮深度。
// STORY: 封面先改变环境，内容与操作再从同一块半透明膜面中浮起。
// FIRST VIEWPORT: 顶部留白承接问候，中央连续音乐窗整合主视觉、捷径与歌曲，底栏像一块抬起的白色镜片。
// FORM: 用户参考图锁定的软性透明硬件界面；seed=clarity-airfield-v2。
// FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, and DESIGN.md

enum ClarityStyle {
    static var isActive: Bool {
        GlobalThemeId.persistedOrDefault == .clarity
    }

    static var baseAccent: Color {
        ThemeColorCustomization.accentColor(
            for: .clarity,
            fallback: Color(light: Color(hex: "2478D8"), dark: Color(hex: "80C7FF")),
            fallbackHex: "2478D8"
        )
    }

    /// Every interactive emphasis reads the unified runtime snapshot. The
    /// provider itself uses `baseAccent` to avoid feeding a resolved artwork
    /// color back into the next engine pass.
    static var accent: Color {
        guard UnifiedColorRuntime.themeId == .clarity,
              let resolved = UnifiedColorRuntime.colors?.accent else {
            return baseAccent
        }
        return resolved
    }

    static var base: Color {
        Color(
            light: ThemeColorCustomization.backgroundBase(
                for: .clarity,
                fallback: Color(hex: "F2F4F4"),
                fallbackHex: "F2F4F4"
            ),
            dark: Color(hex: "091017")
        )
    }

    static let membrane = Color(light: Color.white.opacity(0.58), dark: Color(hex: "17232C").opacity(0.58))
    static let membraneStrong = Color(light: Color.white.opacity(0.76), dark: Color(hex: "21313D").opacity(0.74))
    static let membraneQuiet = Color(light: Color.white.opacity(0.34), dark: Color(hex: "101B24").opacity(0.38))
    static let ink = Color(light: Color(hex: "0B0D0F"), dark: Color(hex: "F7FAFC"))
    static let inkSoft = Color(light: Color(hex: "4F575D"), dark: Color(hex: "CAD3D9"))
    static let inkFaint = Color(light: Color(hex: "818A91"), dark: Color(hex: "8D9BA5"))
    static let line = Color(light: Color(hex: "66717A").opacity(0.12), dark: Color.white.opacity(0.10))
    static let cyan = Color(light: Color(hex: "72DCE8"), dark: Color(hex: "69DDEB"))
    static let lilac = Color(light: Color(hex: "C8BDE9"), dark: Color(hex: "A99ADD"))
    static let blush = Color(light: Color(hex: "F3CFCA"), dark: Color(hex: "CB8D87"))
    static let mint = Color(light: Color(hex: "A4DFD0"), dark: Color(hex: "74CDB7"))
    static let destructive = Color(light: Color(hex: "D84D59"), dark: Color(hex: "FF7B84"))
    static var selection: Color { accent }
    static var onSelection: Color { onAccent }
    static let settingsSectionRadius: CGFloat = 24

    /// Shared infrastructure reads these semantic roles. They are aliases into
    /// the Clarity system, not values inherited from another theme.
    static var surface: Color {
        membrane
    }

    static var surfaceRaised: Color {
        membraneStrong
    }

    static var surfaceQuiet: Color {
        membraneQuiet
    }

    static var edge: Color {
        Color.white.opacity(0.72)
    }

    static var separator: Color {
        line
    }

    static var inkMuted: Color {
        inkFaint
    }

    static var accentGradient: [Color] {
        guard UnifiedColorRuntime.themeId == .clarity,
              let resolved = UnifiedColorRuntime.colors?.accentGradient,
              !resolved.isEmpty else {
            return baseAccentGradient
        }
        return resolved
    }

    static var baseAccentGradient: [Color] {
        ThemeColorCustomization.accentGradientColors(
            for: .clarity,
            fallback: [baseAccent, cyan],
            fallbackHexes: ["2478D8", "72DCE8"]
        )
    }

    static var onAccent: Color {
        if UnifiedColorRuntime.themeId == .clarity,
           let resolved = UnifiedColorRuntime.onAccent {
            return resolved
        }
        return ThemeColorCustomization.readableForegroundColor(on: baseAccent, light: Color(hex: "0D1720"), dark: .white)
    }

    static func title(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func titleFont(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        title(size, weight: weight)
    }

    static func labelFont(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        body(size, weight: weight)
    }
}

enum ClarityBackdropContext {
    case global
    case player
}

struct ClarityBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var settings = SettingsManager.shared
    var context: ClarityBackdropContext = .global

    var body: some View {
        let _ = settings.globalThemeRevision
        let palette = ThemeColorCustomization.backgroundGradientColors(
            for: .clarity,
            fallbackHexes: ["F8F8F7", "EDF1F2", "F1EAF7", "E7F5F5"]
        )
        let first = palette.first ?? ClarityStyle.base
        let second = palette.dropFirst().first ?? first
        let third = palette.dropFirst(2).first ?? ClarityStyle.lilac
        let fourth = palette.dropFirst(3).first ?? ClarityStyle.cyan

        ZStack {
            ClarityStyle.base

            if colorScheme == .dark {
                LinearGradient(
                    colors: [Color(hex: "111A22"), Color(hex: "070D13")],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                ThemeCustomDiffuseBackground(
                    theme: .clarity,
                    fallbackHexes: ["F8F8F7", "EDF1F2", "F1EAF7", "E7F5F5"],
                    accentFallbackHexes: ["2478D8"],
                    opacity: 0.78
                )
            }

            UnifiedColorAmbientLayer(
                strength: coverGradientEnabled ? 0.58 : 0,
                appliesAdditionalBlur: false
            )

            // The former implementation built this same light field from three
            // oversized blurred circles plus four gradient views. A single async
            // Canvas keeps every optical layer while avoiding repeated full-screen
            // blur passes during scrolling and navigation transitions.
            ClarityOpticalField(
                first: first,
                second: second,
                third: colorScheme == .dark ? ClarityStyle.lilac : third,
                fourth: colorScheme == .dark ? ClarityStyle.cyan : fourth,
                blush: colorScheme == .dark ? ClarityStyle.blush : second,
                accent: ClarityStyle.accent,
                dark: colorScheme == .dark
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var coverGradientEnabled: Bool {
        switch context {
        case .global:
            return settings.coverBgGlobal
        case .player:
            return settings.coverBgPlayer
        }
    }
}

/// One GPU render pass for the complete prismatic field. Radial gradients have
/// the same feathered falloff as the old blurred circles, but do not allocate
/// three viewport-sized intermediate textures on every frame.
private struct ClarityOpticalField: View {
    let first: Color
    let second: Color
    let third: Color
    let fourth: Color
    let blush: Color
    let accent: Color
    let dark: Bool

    var body: some View {
        Canvas(opaque: false, rendersAsynchronously: true) { context, size in
            guard size.width > 0, size.height > 0 else { return }
            let bounds = CGRect(origin: .zero, size: size)
            let path = Path(bounds)
            let width = size.width
            let height = size.height

            context.blendMode = dark ? .screen : .softLight
            context.fill(
                path,
                with: .linearGradient(
                    Gradient(colors: [
                        third.opacity(dark ? 0.22 : 0.62),
                        Color.white.opacity(dark ? 0.015 : 0.20),
                        .clear,
                        fourth.opacity(dark ? 0.18 : 0.54),
                    ]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: width, y: height)
                )
            )

            drawRadial(
                in: &context,
                path: path,
                center: CGPoint(x: width * 0.96, y: height * 0.04),
                radius: max(width * 0.92, height * 0.54),
                color: third,
                coreOpacity: dark ? 0.15 : 0.22
            )
            drawRadial(
                in: &context,
                path: path,
                center: CGPoint(x: width * 0.02, y: height * 0.88),
                radius: max(width * 1.02, height * 0.58),
                color: fourth,
                coreOpacity: dark ? 0.14 : 0.20
            )
            drawRadial(
                in: &context,
                path: path,
                center: CGPoint(x: width * 0.92, y: height * 0.56),
                radius: max(width * 0.66, height * 0.40),
                color: blush,
                coreOpacity: dark ? 0.12 : 0.17
            )
            drawRadial(
                in: &context,
                path: path,
                center: CGPoint(x: width, y: 0),
                radius: max(width, height) * 0.48,
                color: accent,
                coreOpacity: dark ? 0.11 : 0.13
            )
            drawRadial(
                in: &context,
                path: path,
                center: CGPoint(x: 0, y: height),
                radius: max(width, height) * 0.60,
                color: second,
                coreOpacity: dark ? 0.16 : 0.24
            )

            context.fill(
                path,
                with: .linearGradient(
                    Gradient(colors: [
                        first.opacity(0.14),
                        .clear,
                        second.opacity(0.10),
                    ]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: width, y: height)
                )
            )
            context.fill(
                path,
                with: .linearGradient(
                    Gradient(colors: [
                        Color.white.opacity(dark ? 0.025 : 0.30),
                        .clear,
                    ]),
                    startPoint: CGPoint(x: width * 0.5, y: 0),
                    endPoint: CGPoint(x: width * 0.5, y: height * 0.54)
                )
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawRadial(
        in context: inout GraphicsContext,
        path: Path,
        center: CGPoint,
        radius: CGFloat,
        color: Color,
        coreOpacity: Double
    ) {
        context.fill(
            path,
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: color.opacity(coreOpacity), location: 0),
                    .init(color: color.opacity(coreOpacity * 0.46), location: 0.38),
                    .init(color: color.opacity(coreOpacity * 0.12), location: 0.72),
                    .init(color: .clear, location: 1),
                ]),
                center: center,
                startRadius: 0,
                endRadius: max(radius, 1)
            )
        )
    }
}

struct ClarityMembrane<S: InsettableShape>: View {
    let shape: S
    var strength: ClarityMembraneStrength = .regular
    var tint: Color = .clear
    var selected = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        shape
            .fill(.thinMaterial)
            .overlay {
                shape.fill(baseFill)
            }
            .overlay {
                shape.fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.12 : 0.42),
                            Color.white.opacity(colorScheme == .dark ? 0.035 : 0.12),
                            Color.clear,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            }
            .overlay {
                shape.fill(tint.opacity(colorScheme == .dark ? 0.11 : 0.075))
            }
            .overlay {
                shape.strokeBorder(edgeGradient, lineWidth: strength == .strong ? 1.35 : 0.9)
            }
            .overlay {
                shape
                    .inset(by: strength == .strong ? 3.5 : 2.5)
                    .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.05 : 0.42), lineWidth: 0.65)
            }
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? shadowOpacity * 2.3 : shadowOpacity),
                radius: shadowRadius,
                x: 0,
                y: shadowRadius * 0.46
            )
    }

    private var baseFill: Color {
        if selected { return Color.white.opacity(colorScheme == .dark ? 0.10 : 0.42) }
        switch strength {
        case .quiet: return ClarityStyle.membraneQuiet
        case .regular: return ClarityStyle.membrane
        case .strong: return ClarityStyle.membraneStrong
        }
    }

    private var edgeGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(colorScheme == .dark ? 0.30 : 1.0),
                Color.white.opacity(colorScheme == .dark ? 0.12 : 0.68),
                ClarityStyle.line.opacity(0.58),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var shadowOpacity: Double {
        switch strength {
        case .quiet: return 0.028
        case .regular: return 0.055
        case .strong: return 0.085
        }
    }

    private var shadowRadius: CGFloat {
        switch strength {
        case .quiet: return 9
        case .regular: return 16
        case .strong: return 24
        }
    }
}

enum ClarityMembraneStrength { case quiet, regular, strong }

struct ClaritySurfaceBackground: View {
    var cornerRadius: CGFloat
    var elevated = false
    var selected = false
    var tint: Color = .clear

    var body: some View {
        ClarityMembrane(
            shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
            strength: elevated ? .strong : .regular,
            tint: tint,
            selected: selected
        )
    }
}

struct ClarityControlBackground: View {
    var body: some View {
        ClarityMembrane(shape: Capsule(), strength: .quiet)
    }
}

/// A single continuous optical body. Screens place content inside this shell
/// instead of stacking unrelated glass cards on the page.
struct ClarityShell<Content: View>: View {
    var cornerRadius: CGFloat = 34
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .background {
                ClarityMembrane(
                    shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
                    strength: .strong
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

/// Settings detail pages remain neutral. Grouping comes from spacing and a
/// quiet material plane rather than decorative colored rules.
struct ClaritySettingsSectionPlane: View {
    @Environment(\.colorScheme) private var colorScheme
    var cornerRadius: CGFloat = ClarityStyle.settingsSectionRadius

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        shape
            .fill(.thinMaterial)
            .overlay(shape.fill(Color.white.opacity(colorScheme == .dark ? 0.035 : 0.22)))
            .overlay {
                shape.stroke(
                    colorScheme == .dark
                        ? Color.white.opacity(0.10)
                        : Color.white.opacity(0.74),
                    lineWidth: 0.8
                )
            }
    }
}

struct ClarityGlowButton: View {
    let icon: MonoIcon.IconType
    var size: CGFloat = 46
    var tint: Color = ClarityStyle.ink
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            MonoIcon(icon: icon, size: size * 0.36, color: tint, lineWidth: 1.6)
                .frame(width: size, height: size)
                .background {
                    Circle()
                        .fill(ClarityStyle.membraneStrong)
                        .overlay(Circle().stroke(Color.white.opacity(0.9), lineWidth: 0.9))
                        .shadow(color: tint.opacity(0.16), radius: 14, y: 8)
                }
        }
        .buttonStyle(ClarityPressStyle())
    }
}

struct ClarityPageHeader<Trailing: View>: View {
    let eyebrow: String?
    let title: String
    let subtitle: String?
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(ClarityStyle.title(24, weight: .semibold))
                    .foregroundStyle(ClarityStyle.ink)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(ClarityStyle.body(12.5))
                        .foregroundStyle(ClarityStyle.inkSoft)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 10)
            trailing()
        }
    }
}

struct ClarityCircleButton: View {
    let icon: MonoIcon.IconType
    var size: CGFloat = 44
    var selected = false
    var tint: Color = ClarityStyle.ink
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            MonoIcon(
                icon: icon,
                size: size * 0.39,
                color: selected ? ClarityStyle.onSelection : tint,
                lineWidth: 1.65
            )
            .frame(width: size, height: size)
            .background {
                if selected {
                    Circle()
                        .fill(ClarityStyle.selection)
                        .shadow(color: Color.black.opacity(0.16), radius: 14, y: 8)
                } else {
                    ClarityMembrane(shape: Circle(), strength: .regular)
                }
            }
            .contentShape(Circle())
        }
        .buttonStyle(ClarityPressStyle())
    }
}

/// The selected state follows the unified color engine and always receives a
/// contrast-safe foreground from the same snapshot.
struct ClaritySelectionLens<S: InsettableShape>: View {
    let shape: S

    var body: some View {
        shape
            .fill(ClarityStyle.selection)
            .overlay {
                shape.strokeBorder(ClarityStyle.onSelection.opacity(0.20), lineWidth: 0.7)
            }
            .shadow(color: ClarityStyle.selection.opacity(0.24), radius: 13, y: 7)
    }
}

struct ClaritySectionHeading: View {
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(ClarityStyle.title(18, weight: .semibold))
                .foregroundStyle(ClarityStyle.ink)

            Spacer(minLength: 8)

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(ClarityStyle.body(12, weight: .semibold))
                        .foregroundStyle(ClarityStyle.inkSoft)
                        .padding(.horizontal, 13)
                        .frame(height: 32)
                        .background(ClarityMembrane(shape: Capsule(), strength: .quiet))
                }
                .buttonStyle(ClarityPressStyle())
            }
        }
    }
}

struct ClarityArtwork: View {
    let url: URL?
    var size: CGFloat
    var radius: CGFloat = 20

    var body: some View {
        Group {
            if let url {
                CachedAsyncImage(url: url.sized(Int(max(size * 3, 600))), width: size, height: size) {
                    placeholder
                }
                .aspectRatio(contentMode: .fill)
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 0.8)
        }
    }

    private var placeholder: some View {
        LinearGradient(
            colors: [ClarityStyle.lilac.opacity(0.72), ClarityStyle.cyan.opacity(0.72)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(MonoIcon(icon: .musicNote, size: size * 0.24, color: ClarityStyle.inkSoft.opacity(0.55), lineWidth: 1.4))
    }
}

struct ClarityPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .brightness(configuration.isPressed ? -0.025 : 0)
            .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

extension View {
    func clarityPage() -> some View {
        background(ClarityBackdrop())
            .tint(ClarityStyle.accent)
            .compatFontDesign(.default)
    }

    /// Applies the Clarity destination surface without blindly injecting another
    /// back button. Most destination pages already own `monoNavigationBackButton`;
    /// only theme-native pages that do not have navigation chrome opt in.
    func clarityDetailChrome(
        preservesImmersiveBackdrop: Bool = false,
        addsBackButton: Bool = false
    ) -> some View {
        modifier(
            ClarityDetailChromeModifier(
                preservesImmersiveBackdrop: preservesImmersiveBackdrop,
                addsBackButton: addsBackButton
            )
        )
    }

    /// Account and authorization pages still use native `List` infrastructure.
    /// Pin them to inset groups so their section masks keep the same rounded
    /// silhouette as the custom settings membranes.
    @ViewBuilder
    func claritySettingsListStyle() -> some View {
        if ClarityStyle.isActive {
            listStyle(.insetGrouped)
        } else {
            self
        }
    }
}

private struct ClarityDetailChromeModifier: ViewModifier {
    let preservesImmersiveBackdrop: Bool
    let addsBackButton: Bool

    func body(content: Content) -> some View {
        let themedContent = content
            .background {
                if !preservesImmersiveBackdrop {
                    ClarityBackdrop()
                }
            }
            .tint(ClarityStyle.accent)
            .compatFontDesign(.default)
            .toolbar(.visible, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)

        if addsBackButton {
            themedContent
                .navigationBarBackButtonHidden(true)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        MonoToolbarBackButton(iconColor: ClarityStyle.ink)
                    }
                }
        } else {
            themedContent
        }
    }
}
