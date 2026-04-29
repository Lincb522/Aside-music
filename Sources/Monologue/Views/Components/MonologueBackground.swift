import SwiftUI

// MARK: - 返回按钮组件
struct MonologueBackButton: View {
    enum Style {
        case back   // < 返回
        case dismiss // 下拉关闭
    }

    var style: Style = .back
    var isDarkBackground: Bool = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var iconColor: Color {
        isDarkBackground ? .white : .primary
    }

    var body: some View {
        Button(action: {
            dismiss()
        }) {
            MonologueIcon(
                icon: style == .back ? .back : .chevronRight,
                size: 20,
                color: iconColor
            )
            .rotationEffect(style == .dismiss ? .degrees(90) : .zero)
            .frame(width: 40, height: 40)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 弥散背景组件
struct MonologueBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var player = PlayerManager.shared
    @ObservedObject private var settings = SettingsManager.shared
    @State private var themeManager = GlobalThemeManager.shared

    private var useCoverBg: Bool {
        settings.coverBgGlobal && player.currentSong != nil
    }

    /// 当前全局主题 ID
    private var themeId: GlobalThemeId {
        themeManager.currentThemeId
    }

    var body: some View {
        ZStack {
            // 根据全局主题决定底层背景
            themeAwareBackground
                .opacity(useCoverBg ? 0 : 1)

            if let coverUrl = player.currentSong?.coverUrl?.sized(200),
               settings.coverBgGlobal {
                PlaylistColorBackground(
                    coverUrl: coverUrl,
                    onBrightnessChanged: { isDark in
                        if settings.globalCoverIsDark != isDark {
                            settings.globalCoverIsDark = isDark
                        }
                    }
                )
                .opacity(useCoverBg ? 1 : 0)
                .transition(.opacity)
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.45), value: useCoverBg)
        .onChange(of: useCoverBg) { _, active in
            if !active && settings.globalCoverIsDark {
                settings.globalCoverIsDark = false
            }
        }
    }

    // MARK: - 主题感知的默认背景

    @ViewBuilder
    private var themeAwareBackground: some View {
        switch themeId {
        case .muji:
            mujiBackground
        case .manga:
            mangaBackground
        case .neumorphic:
            neumorphicBackground
        case .default:
            defaultBackground
        }
    }

    // MARK: - 无印良品背景

    private var mujiBackground: some View {
        ZStack {
            MujiRootBackdrop()

            Canvas { context, size in
                let w = size.width
                let h = size.height
                if colorScheme == .dark {
                    fillGlow(context, center: CGPoint(x: w * 0.16, y: h * 0.1), radius: w * 0.48,
                             color: MujiStyle.clay, opacity: 0.12)
                    fillGlow(context, center: CGPoint(x: w * 0.82, y: h * 0.38), radius: w * 0.42,
                             color: MujiStyle.tea, opacity: 0.12)
                } else {
                    fillGlow(context, center: CGPoint(x: w * 0.16, y: h * 0.06), radius: w * 0.5,
                             color: MujiStyle.straw, opacity: 0.16)
                    fillGlow(context, center: CGPoint(x: w * 0.82, y: h * 0.44), radius: w * 0.42,
                             color: MujiStyle.tea, opacity: 0.1)
                    fillGlow(context, center: CGPoint(x: w * 0.44, y: h * 0.8), radius: w * 0.48,
                             color: MujiStyle.indigo, opacity: 0.055)
                }
            }
            .padding(-80)
            .blur(radius: 58)
            .ignoresSafeArea()
            .drawingGroup()
        }
    }

    // MARK: - 漫画风背景

    private var mangaBackground: some View {
        MangaRootBackdrop()
    }

    // MARK: - 新拟物背景

    private var neumorphicBackground: some View {
        ThemeRenderBackdrop(theme: .neumorphic)
    }

    // MARK: - 默认背景

    @ViewBuilder
    private var defaultBackground: some View {
        if ThemeColorCustomization.usesCustomBackground(for: .default) {
            ThemeCustomDiffuseBackground(
                theme: .default,
                fallbackHexes: [
                    ThemeColorCustomization.defaultBackgroundStartHex(for: .default),
                    ThemeColorCustomization.defaultBackgroundEndHex(for: .default),
                ],
                accentFallbackHexes: [ThemeColorCustomization.defaultAccentHex(for: .default)],
                opacity: 0.92
            )
            .ignoresSafeArea()
        } else {
            defaultSystemBackground
        }
    }

    private var defaultSystemBackground: some View {
        ZStack {
            (colorScheme == .dark ? Color(hex: "050507") : Color(hex: "F8F9FB"))
                .ignoresSafeArea()

            Canvas { context, size in
                let w = size.width
                let h = size.height

                if colorScheme == .dark {
                    fillGlow(context, center: CGPoint(x: w * 0.15, y: h * 0.1), radius: w * 0.7,
                             color: Color(hex: "1A2D4A"), opacity: 0.8)
                    fillGlow(context, center: CGPoint(x: w * 0.82, y: h * 0.08), radius: w * 0.6,
                             color: Color(hex: "0F2B33"), opacity: 0.7)
                    fillGlow(context, center: CGPoint(x: w * 0.35, y: h * 0.45), radius: w * 0.5,
                             color: Color(hex: "2A1F10"), opacity: 0.5)
                    fillGlow(context, center: CGPoint(x: w * 0.7, y: h * 0.6), radius: w * 0.45,
                             color: Color(hex: "1A0F2E"), opacity: 0.4)
                } else {
                    fillGlow(context, center: CGPoint(x: w * 0.1, y: h * 0.06), radius: w * 0.55,
                             color: Color(hex: "C4D2E8"), opacity: 0.45)
                    fillGlow(context, center: CGPoint(x: w * 0.85, y: h * 0.05), radius: w * 0.5,
                             color: Color(hex: "CEDAEA"), opacity: 0.35)
                    fillGlow(context, center: CGPoint(x: w * 0.35, y: h * 0.35), radius: w * 0.4,
                             color: Color(hex: "D6D0E6"), opacity: 0.3)
                    fillGlow(context, center: CGPoint(x: w * 0.65, y: h * 0.65), radius: w * 0.5,
                             color: Color(hex: "D8E0EC"), opacity: 0.25)
                }
            }
            .padding(-80)
            .blur(radius: 60)
            .ignoresSafeArea()
            .drawingGroup()

            VStack {
                ParallaxMountainHeader(height: 300)
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .white, location: 0),
                                .init(color: .white, location: 0.25),
                                .init(color: .white.opacity(0.5), location: 0.5),
                                .init(color: .white.opacity(0.15), location: 0.75),
                                .init(color: .clear, location: 1.0),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .opacity(colorScheme == .dark ? 0.85 : 0.35)
                    .blendMode(.normal)
                Spacer()
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }

    private func fillGlow(_ ctx: GraphicsContext, center: CGPoint, radius: CGFloat, color: Color, opacity: Double) {
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        ctx.fill(Path(ellipseIn: rect), with: .radialGradient(
            Gradient(colors: [color.opacity(opacity), color.opacity(opacity * 0.3), color.opacity(0)]),
            center: center, startRadius: 0, endRadius: radius
        ))
    }
}

// MARK: - Liquid Glass 叠加层
struct LiquidGlassOverlay: View {
    var body: some View {
        Rectangle()
            .fill(Color.monologueGlassTint)
            .monologueGlass(cornerRadius: 16)
            .opacity(0.3)
    }
}

// MARK: - Liquid Glass 卡片
struct MonologueLiquidGlassCard<Content: View>: View {
    let cornerRadius: CGFloat
    let useMetal: Bool
    let content: Content

    init(
        cornerRadius: CGFloat = 20,
        useMetal: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.useMetal = useMetal
        self.content = content()
    }

    var body: some View {
        if MangaStyle.isActive {
            content
                .background(MangaCardBackground(cornerRadius: min(cornerRadius, 18), elevated: true))
        } else if MujiStyle.isActive {
            content
                .background(MujiPaperCardBackground(cornerRadius: min(cornerRadius, 16), elevated: true))
        } else if NeumorphicStyle.isActive {
            content
                .background(NeumorphicSurfaceBackground(cornerRadius: min(max(cornerRadius, 18), 28), elevated: true))
        } else {
            content
                .background(
                    SwiftUIGlassBackground(cornerRadius: cornerRadius)
                )
                .clipShape(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
                .shadow(
                    color: .black.opacity(0.08),
                    radius: 10,
                    x: 0,
                    y: 5
                )
        }
    }
}

// MARK: - SwiftUI 毛玻璃回退方案
struct SwiftUIGlassBackground: View {
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let isDark = colorScheme == .dark
        ZStack {
            if MangaStyle.isActive {
                MangaCardBackground(cornerRadius: min(cornerRadius, 18), elevated: true)
            } else if MujiStyle.isActive {
                MujiPaperCardBackground(cornerRadius: min(cornerRadius, 16), elevated: true)
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.monologueGlassTint)
                    .monologueGlass(cornerRadius: cornerRadius)

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(isDark ? Color.white.opacity(0.06) : Color.white.opacity(0.4))

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: isDark
                                ? [
                                    Color.white.opacity(0.15),
                                    Color.white.opacity(0.06),
                                    Color.white.opacity(0.03),
                                    Color.white.opacity(0.08)
                                ]
                                : [
                                    Color.white.opacity(0.6),
                                    Color.white.opacity(0.2),
                                    Color.white.opacity(0.1),
                                    Color.white.opacity(0.3)
                                ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isDark ? 0.5 : 1
                    )

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(isDark ? 0.04 : 0.15),
                                Color.clear
                            ],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: 200
                        )
                    )
            }
        }
    }
}

// MARK: - View 修饰器
extension View {
    func monologueBackground() -> some View {
        self.background(MonologueBackground())
    }
}
