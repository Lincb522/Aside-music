import SwiftUI

private struct MonologuePageHeaderCollapseModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *), !reduceMotion {
            content
                .scrollTransition(
                    .animated(.spring(response: 0.32, dampingFraction: 0.86)),
                    axis: .vertical
                ) { content, phase in
                    content
                        .scaleEffect(phase.isIdentity ? 1 : 0.92, anchor: .top)
                        .opacity(phase.isIdentity ? 1 : 0.18)
                        .offset(y: phase.isIdentity ? 0 : -12)
                }
        } else {
            content
        }
    }
}

extension View {
    /// Applies the same restrained shrink/fade used by the library header when
    /// a page header leaves the top edge of its vertical scroll container.
    func monologuePageHeaderCollapse() -> some View {
        modifier(MonologuePageHeaderCollapseModifier())
    }
}

struct ThemedPageBackground: View {
    var useRenderLayer = true

    @ObservedObject private var settings = SettingsManager.shared
    @Environment(\.themeRenderContext) private var renderContext
    @Environment(\.monologueSheetContext) private var monologueSheetContext

    var body: some View {
        if monologueSheetContext != nil {
            // Sheet 内：背景上抛给 monologueSheet 容器铺满整个面板（含顶部把手区），
            // 原位置只留占位，避免把手区露出一截默认毛玻璃。
            Color.clear
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .monologueSheetSurface(id: backgroundIdentity) {
                    backdropContent
                }
        } else if useRenderLayer && renderContext.providesGlobalBackdrop {
            Color.clear
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        } else {
            backdropContent
        }
    }

    private var backdropContent: some View {
        ZStack {
            if useRenderLayer {
                ThemeRenderBackdrop(theme: renderTheme, revision: renderRevision)
            } else {
                if MangaStyle.isActive {
                    MangaRootBackdrop()
                } else if PetWhiteStyle.isActive {
                    PetWhiteRootBackdrop()
                } else if MinimalWhiteStyle.isActive {
                    MinimalWhiteRootBackdrop()
                } else if PureWhiteStyle.isActive {
                    PureWhiteRootBackdrop()
                } else if MujiStyle.isActive {
                    MujiRootBackdrop()
                } else if NeumorphicStyle.isActive {
                    NeumorphicRenderBackdrop()
                } else if CapsuleStyle.isActive {
                    CapsuleRootBackdrop()
                } else if SequoiaStyle.isActive {
                    SequoiaRootBackdrop()
                } else if LiquidGlassStyle.isActive {
                    LiquidGlassRootBackdrop()
                } else if ClayStyle.isActive {
                    ClayRootBackdrop()
                } else if SignalStyle.isActive {
                    SignalRenderBackdrop()
                } else if BentoStyle.isActive {
                    BentoRootBackdrop()
                } else {
                    MonologueBackground()
                        .ignoresSafeArea()
                }
            }
        }
        .id(backgroundIdentity)
        .transaction { transaction in
            transaction.animation = nil
            transaction.disablesAnimations = true
        }
    }

    private var renderTheme: GlobalThemeId {
        useRenderLayer && renderContext.isHosted ? renderContext.theme : settings.globalThemeId
    }

    private var backgroundIdentity: String {
        if useRenderLayer, renderContext.isHosted {
            return "theme-background-\(renderContext.backdropIdentity)"
        }
        return "theme-background-\(settings.globalThemeId.rawValue)-\(settings.activeColorScheme == .dark ? "dark" : "light")"
    }

    private var renderRevision: Int {
        useRenderLayer && renderContext.isHosted ? renderContext.revision : settings.globalThemeRevision
    }
}

struct ThemedPageHeader<Accessory: View>: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let icon: MonologueIcon.IconType
    let accessory: Accessory

    init(
        eyebrow: String,
        title: String,
        subtitle: String = "",
        icon: MonologueIcon.IconType = .sparkle,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.accessory = accessory()
    }

    var body: some View {
        if MangaStyle.isActive {
            MangaPageHeader(
                eyebrow: eyebrow,
                title: title,
                subtitle: subtitle
            ) {
                HStack(spacing: 10) {
                    accessory
                    MangaIconBadge(icon: icon, size: 46, tint: MangaStyle.labelYellow)
                }
            }
        } else if PetWhiteStyle.isActive {
            PetWhitePageHeader(
                eyebrow: eyebrow,
                title: title,
                subtitle: subtitle
            ) {
                accessory
            }
        } else if MinimalWhiteStyle.isActive {
            MinimalWhitePageHeader(
                eyebrow: eyebrow,
                title: title,
                subtitle: subtitle,
                icon: icon
            ) {
                accessory
            }
        } else if PureWhiteStyle.isActive {
            // PureWhitePageHeader 自带左侧图标徽章，这里只透传 accessory，
            // 避免同一枚徽章在头部两端重复出现
            PureWhitePageHeader(
                eyebrow: eyebrow,
                title: title,
                subtitle: subtitle,
                icon: icon
            ) {
                accessory
            }
        } else if MujiStyle.isActive {
            // 杂志刊头不需要装饰性图标章，只透传功能性 accessory
            MujiPageHeader(
                eyebrow: eyebrow,
                title: title,
                subtitle: subtitle
            ) {
                accessory
            }
        } else if NeumorphicStyle.isActive {
            NeumorphicPageHeader(
                eyebrow: eyebrow,
                title: title,
                subtitle: subtitle
            ) {
                HStack(spacing: 10) {
                    accessory
                    NeumorphicIconBadge(icon: icon, tint: NeumorphicStyle.accent, size: 46)
                }
            }
        } else if CapsuleStyle.isActive {
            CapsulePageHeader(
                eyebrow: eyebrow,
                title: title,
                subtitle: subtitle
            ) {
                HStack(spacing: 10) {
                    accessory
                    CapsuleIconBadge(icon: icon, tint: CapsuleStyle.accent, size: 46)
                }
            }
        } else if SequoiaStyle.isActive {
            SequoiaPageHeader(
                eyebrow: eyebrow,
                title: title,
                subtitle: subtitle
            ) {
                HStack(spacing: 10) {
                    accessory
                    SequoiaIconBadge(icon: icon, tint: SequoiaStyle.accent, size: 46)
                }
            }
        } else if LiquidGlassStyle.isActive {
            LiquidGlassPageHeader(
                eyebrow: eyebrow,
                title: title,
                subtitle: subtitle
            ) {
                HStack(spacing: 10) {
                    accessory
                    LiquidGlassIconBadge(icon: icon, tint: LiquidGlassStyle.accent, size: 46)
                }
            }
        } else if ClayStyle.isActive {
            ClayPageHeader(
                eyebrow: eyebrow,
                title: title,
                subtitle: subtitle
            ) {
                HStack(spacing: 10) {
                    accessory
                    ClayIconBubble(icon: icon, tint: ClayStyle.accent, size: 46)
                }
            }
        } else if SignalStyle.isActive {
            SignalPageHeader(
                eyebrow: eyebrow,
                title: title,
                subtitle: subtitle
            ) {
                HStack(spacing: 10) {
                    accessory
                    SignalIconBadge(icon: icon, tint: SignalStyle.accent, size: 46)
                }
            }
        } else if BentoStyle.isActive {
            BentoPageHeader(
                eyebrow: eyebrow,
                title: title,
                subtitle: subtitle
            ) {
                HStack(spacing: 10) {
                    accessory
                    BentoIconBadge(icon: icon, foreground: BentoStyle.tomato, size: 46)
                }
            }
        } else {
            EmptyView()
        }
    }
}

extension ThemedPageHeader where Accessory == EmptyView {
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

/// 二级页面紧凑头部：把标题放进导航栏 principal 位置，与返回按钮同排，
/// 替代原先"返回按钮一排 + 大标题又一排"的高头部。
private struct ThemedInlineNavigationTitleModifier: ViewModifier {
    let title: String
    @ObservedObject private var settings = SettingsManager.shared

    func body(content: Content) -> some View {
        let _ = settings.globalThemeRevision

        content
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(inlineTitleFont)
                        .foregroundColor(inlineTitleColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
    }

    private var inlineTitleFont: Font {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.titleFont(17, weight: .semibold) }
        if MangaStyle.isActive { return MangaStyle.titleFont(17, weight: .black) }
        if MujiStyle.isActive { return MujiStyle.titleFont(17, weight: .medium) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.titleFont(17, weight: .semibold) }
        if SignalStyle.isActive { return SignalStyle.titleFont(17, weight: .bold) }
        if CapsuleStyle.isActive { return CapsuleStyle.bodyFont(17, weight: .bold) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(17, weight: .semibold) }
        if PetWhiteStyle.isActive { return PetWhiteStyle.bodyFont(17, weight: .black) }
        return .system(size: 17, weight: .semibold, design: .rounded)
    }

    private var inlineTitleColor: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.ink }
        if MangaStyle.isActive { return MangaStyle.ink }
        if MujiStyle.isActive { return MujiStyle.ink }
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        if SignalStyle.isActive { return SignalStyle.ink }
        if CapsuleStyle.isActive { return CapsuleStyle.ink }
        if SequoiaStyle.isActive { return SequoiaStyle.ink }
        if PetWhiteStyle.isActive { return PetWhiteStyle.ink }
        return .monologueTextPrimary
    }
}

extension View {
    /// 二级页面标题与返回按钮同排（导航栏内联标题），头部不再单独占一大块
    func themedInlineNavigationTitle(_ title: String) -> some View {
        modifier(ThemedInlineNavigationTitleModifier(title: title))
    }
}

struct SettingsScrollablePageHeader: View {
    let title: String
    let eyebrow: String
    let subtitle: String
    let icon: MonologueIcon.IconType

    init(
        title: String,
        eyebrow: String,
        subtitle: String = "",
        icon: MonologueIcon.IconType = .sparkle
    ) {
        self.title = title
        self.eyebrow = eyebrow
        self.subtitle = subtitle
        self.icon = icon
    }

    var body: some View {
        if ThemedPageStyle.isActive {
            ThemedPageHeader(
                eyebrow: eyebrow,
                title: title,
                subtitle: subtitle,
                icon: icon
            )
            .padding(.horizontal, settingsHeaderHorizontalInset)
            .padding(.bottom, -2)
        } else {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.monologueIconBackground.opacity(0.14))
                        .frame(width: 46, height: 46)
                    MonologueIcon(icon: icon, size: 20, color: .monologueTextPrimary, lineWidth: 1.7)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(eyebrow)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.monologueTextSecondary)
                        .tracking(1.2)

                    Text(title)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.monologueTextPrimary)

                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.monologueTextSecondary)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, DeviceLayout.settingsHeaderHorizontalPadding)
            .padding(.top, 12)
            .padding(.bottom, 4)
            .iPadContentWidth(700)
            .monologuePageHeaderCollapse()
        }
    }

    private var settingsHeaderHorizontalInset: CGFloat {
        DeviceLayout.settingsHeaderHorizontalPadding - DeviceLayout.homeHorizontalPadding
    }
}

private struct ThemedNavigationChromeModifier: ViewModifier {
    let title: String
    let eyebrow: String
    let subtitle: String
    let icon: MonologueIcon.IconType
    @Environment(\.monologueSheetContext) private var monologueSheetContext

    private var isThemed: Bool {
        MinimalWhiteStyle.isActive || MangaStyle.isActive || PetWhiteStyle.isActive || PureWhiteStyle.isActive || MujiStyle.isActive || NeumorphicStyle.isActive || CapsuleStyle.isActive || SequoiaStyle.isActive || LiquidGlassStyle.isActive || ClayStyle.isActive || SignalStyle.isActive || BentoStyle.isActive
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        // 标题放进导航栏与返回按钮同排，不再渲染独占一大块的页头
        if isThemed && monologueSheetContext == nil {
            content
                .themedInlineNavigationTitle(title)
        } else {
            content
                .navigationTitle(isThemed ? "" : title)
        }
    }
}

private struct ThemedPageSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat
    let elevated: Bool
    let mangaTint: Color

    func body(content: Content) -> some View {
        if MinimalWhiteStyle.isActive {
            content
                .background(
                    MinimalWhiteSurfaceBackground(
                        cornerRadius: min(max(cornerRadius, 8), elevated ? MinimalWhiteStyle.chromeRadius : MinimalWhiteStyle.cardRadius),
                        elevated: elevated,
                        tint: elevated ? MinimalWhiteStyle.glassStrongFill : MinimalWhiteStyle.glassFill
                    )
                )
                .themeRenderSurfaceLayer(isEnabled: elevated)
        } else if MangaStyle.isActive {
            content
                .background(MangaCardBackground(cornerRadius: cornerRadius, elevated: elevated, tint: mangaTint))
                .themeRenderSurfaceLayer()
        } else if PetWhiteStyle.isActive {
            content
                .background(
                    PetWhiteSurfaceBackground(
                        cornerRadius: min(max(cornerRadius, 16), 28),
                        elevated: elevated,
                        tint: elevated ? PetWhiteStyle.surfaceRaised : PetWhiteStyle.surfacePressed,
                        accent: elevated ? PetWhiteStyle.mint : PetWhiteStyle.butter
                    )
                )
                .themeRenderSurfaceLayer(isEnabled: elevated)
        } else if PureWhiteStyle.isActive {
            content
                .background(
                    PureWhiteSurfaceBackground(
                        cornerRadius: min(max(cornerRadius, 16), 28),
                        elevated: elevated,
                        tint: elevated ? PureWhiteStyle.surfaceRaised.opacity(0.96) : PureWhiteStyle.surface.opacity(0.9)
                    )
                )
                .themeRenderSurfaceLayer(isEnabled: elevated)
        } else if MujiStyle.isActive {
            content
                .background(MujiPaperCardBackground(cornerRadius: min(cornerRadius, 16), elevated: elevated))
                .themeRenderSurfaceLayer()
        } else if NeumorphicStyle.isActive {
            content
                .background(
                    NeumorphicSurfaceBackground(
                        cornerRadius: min(max(cornerRadius, 18), 28),
                        elevated: elevated,
                        lightweight: !elevated
                    )
                )
                .themeRenderSurfaceLayer(isEnabled: elevated)
        } else if CapsuleStyle.isActive {
            content
                .background(
                    CapsuleSurfaceBackground(
                        cornerRadius: min(max(cornerRadius, 20), 30),
                        elevated: elevated,
                        tint: elevated ? CapsuleStyle.surfaceRaised.opacity(0.92) : CapsuleStyle.surface.opacity(0.84)
                    )
                )
                .themeRenderSurfaceLayer(isEnabled: elevated)
        } else if SequoiaStyle.isActive {
            content
                .background(
                    SequoiaSurfaceBackground(
                        cornerRadius: min(max(cornerRadius, 16), 24),
                        elevated: elevated,
                        pressed: !elevated,
                        role: elevated ? .chrome : .list
                    )
                )
                .themeRenderSurfaceLayer(isEnabled: elevated)
        } else if LiquidGlassStyle.isActive {
            content
                .background(
                    LiquidGlassSurfaceBackground(
                        cornerRadius: min(max(cornerRadius, 18), 28),
                        elevated: elevated,
                        pressed: !elevated,
                        role: elevated ? .chrome : .list
                    )
                )
                .themeRenderSurfaceLayer(isEnabled: elevated)
        } else if ClayStyle.isActive {
            content
                .background(
                    ClaySurfaceBackground(
                        cornerRadius: min(max(cornerRadius, 20), 30),
                        elevated: elevated,
                        pressed: !elevated,
                        compact: !elevated
                    )
                )
                .themeRenderSurfaceLayer(isEnabled: elevated)
        } else if SignalStyle.isActive {
            content
                .background(
                    SignalSurfaceBackground(
                        cornerRadius: min(max(cornerRadius, 18), 30),
                        elevated: elevated,
                        pressed: !elevated,
                        fill: elevated ? SignalStyle.device : SignalStyle.paper
                    )
                )
                .themeRenderSurfaceLayer(isEnabled: elevated)
        } else if BentoStyle.isActive {
            content
                .background(
                    RoundedRectangle(cornerRadius: min(max(cornerRadius, 16), 28), style: .continuous)
                        .fill(elevated ? BentoStyle.surfaceRaised : BentoStyle.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: min(max(cornerRadius, 16), 28), style: .continuous)
                                .stroke(BentoStyle.hairline.opacity(0.58), lineWidth: 0.7)
                        )
                        .shadow(color: BentoStyle.ink.opacity(elevated ? 0.08 : 0.035), radius: elevated ? 14 : 6, x: 0, y: elevated ? 7 : 3)
                )
                .themeRenderSurfaceLayer(isEnabled: elevated)
        } else {
            content
                .monologueGlass(cornerRadius: cornerRadius)
        }
    }
}

enum ThemedPageStyle {
    static var isActive: Bool {
        MinimalWhiteStyle.isActive || MangaStyle.isActive || PetWhiteStyle.isActive || PureWhiteStyle.isActive || MujiStyle.isActive || NeumorphicStyle.isActive || CapsuleStyle.isActive || SequoiaStyle.isActive || LiquidGlassStyle.isActive || ClayStyle.isActive || SignalStyle.isActive || BentoStyle.isActive
    }

    static var listSpacing: CGFloat {
        if MinimalWhiteStyle.isActive { return 6 }
        if MangaStyle.isActive { return 10 }
        if PetWhiteStyle.isActive { return 10 }
        if PureWhiteStyle.isActive { return 10 }
        if MujiStyle.isActive { return 8 }
        if NeumorphicStyle.isActive { return 10 }
        if CapsuleStyle.isActive { return 9 }
        if SequoiaStyle.isActive { return 6 }
        if LiquidGlassStyle.isActive { return 8 }
        if ClayStyle.isActive { return 10 }
        if SignalStyle.isActive { return 9 }
        if BentoStyle.isActive { return 10 }
        return 0
    }

    static var looseListSpacing: CGFloat {
        if MinimalWhiteStyle.isActive { return 12 }
        if MangaStyle.isActive { return 14 }
        if PetWhiteStyle.isActive { return 14 }
        if PureWhiteStyle.isActive { return 14 }
        if MujiStyle.isActive { return 12 }
        if NeumorphicStyle.isActive { return 14 }
        if CapsuleStyle.isActive { return 13 }
        if SequoiaStyle.isActive { return 10 }
        if LiquidGlassStyle.isActive { return 12 }
        if ClayStyle.isActive { return 14 }
        if SignalStyle.isActive { return 13 }
        if BentoStyle.isActive { return 14 }
        return 12
    }

    static var horizontalInset: CGFloat {
        isActive ? 24 : 0
    }

    static var sectionInset: CGFloat {
        24
    }

    static var surfaceCornerRadius: CGFloat {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.chromeRadius }
        if MangaStyle.isActive { return 18 }
        if PetWhiteStyle.isActive { return 22 }
        if PureWhiteStyle.isActive { return 22 }
        if MujiStyle.isActive { return 14 }
        if NeumorphicStyle.isActive { return 22 }
        if CapsuleStyle.isActive { return 24 }
        if SequoiaStyle.isActive { return 20 }
        if LiquidGlassStyle.isActive { return 22 }
        if ClayStyle.isActive { return 24 }
        if SignalStyle.isActive { return 26 }
        if BentoStyle.isActive { return 24 }
        return 18
    }

    static var compactSurfaceCornerRadius: CGFloat {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.compactRadius }
        if MangaStyle.isActive { return 14 }
        if PetWhiteStyle.isActive { return 16 }
        if PureWhiteStyle.isActive { return 16 }
        if MujiStyle.isActive { return 12 }
        if NeumorphicStyle.isActive { return 18 }
        if CapsuleStyle.isActive { return 18 }
        if SequoiaStyle.isActive { return 11 }
        if LiquidGlassStyle.isActive { return 16 }
        if ClayStyle.isActive { return 18 }
        if SignalStyle.isActive { return 18 }
        if BentoStyle.isActive { return 18 }
        return 14
    }
}

extension View {
    func themedNavigationChrome(
        title: String,
        eyebrow: String,
        subtitle: String = "",
        icon: MonologueIcon.IconType = .sparkle
    ) -> some View {
        modifier(
            ThemedNavigationChromeModifier(
                title: title,
                eyebrow: eyebrow,
                subtitle: subtitle,
                icon: icon
            )
        )
    }

    func themedPageSurface(
        cornerRadius: CGFloat = 18,
        elevated: Bool = true,
        mangaTint: Color = MangaStyle.bubbleWhite
    ) -> some View {
        modifier(ThemedPageSurfaceModifier(cornerRadius: cornerRadius, elevated: elevated, mangaTint: mangaTint))
    }

    @ViewBuilder
    func themedOnlyPageSurface(
        cornerRadius: CGFloat = ThemedPageStyle.surfaceCornerRadius,
        elevated: Bool = true,
        mangaTint: Color = MangaStyle.bubbleWhite
    ) -> some View {
        if ThemedPageStyle.isActive {
            themedPageSurface(cornerRadius: cornerRadius, elevated: elevated, mangaTint: mangaTint)
        } else {
            self
        }
    }
}
