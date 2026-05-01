import SwiftUI

struct ThemedPageBackground: View {
    var useRenderLayer = true

    @ObservedObject private var settings = SettingsManager.shared
    @Environment(\.themeRenderContext) private var renderContext

    var body: some View {
        if useRenderLayer && renderContext.providesGlobalBackdrop {
            Color.clear
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        } else {
            ZStack {
                if useRenderLayer {
                    ThemeRenderBackdrop(theme: renderTheme, revision: renderRevision)
                } else {
                    if MangaStyle.isActive {
                        MangaRootBackdrop()
                    } else if MujiStyle.isActive {
                        MujiRootBackdrop()
                    } else if NeumorphicStyle.isActive {
                        NeumorphicRenderBackdrop()
                    } else if SequoiaStyle.isActive {
                        SequoiaRootBackdrop()
                    } else if MaterialStyle.isActive {
                        MaterialRootBackdrop()
                    } else if ClayStyle.isActive {
                        ClayRootBackdrop()
                    } else if SignalStyle.isActive {
                        SignalRenderBackdrop()
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
    }

    private var renderTheme: GlobalThemeId {
        useRenderLayer && renderContext.isHosted ? renderContext.theme : settings.globalThemeId
    }

    private var backgroundIdentity: String {
        if useRenderLayer, renderContext.isHosted {
            return "theme-background-\(renderContext.backdropIdentity)"
        }
        return "theme-background-\(settings.globalThemeId.rawValue)-\(settings.globalThemeRevision)-\(settings.activeColorScheme == .dark ? "dark" : "light")"
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
        } else if MujiStyle.isActive {
            MujiPageHeader(
                eyebrow: eyebrow,
                title: title,
                subtitle: subtitle
            ) {
                HStack(spacing: 10) {
                    accessory
                    MujiIconBadge(icon: icon, tint: MujiStyle.clay, size: 44)
                }
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
        } else if MaterialStyle.isActive {
            MaterialPageHeader(
                eyebrow: eyebrow,
                title: title,
                subtitle: subtitle
            ) {
                HStack(spacing: 10) {
                    accessory
                    MaterialIconBadge(icon: icon, tint: MaterialStyle.primary, size: 46)
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

    private var isThemed: Bool {
        MangaStyle.isActive || MujiStyle.isActive || NeumorphicStyle.isActive || SequoiaStyle.isActive || MaterialStyle.isActive || ClayStyle.isActive || SignalStyle.isActive
    }

    func body(content: Content) -> some View {
        content
            .navigationTitle(isThemed ? "" : title)
            .safeAreaInset(edge: .top, spacing: 0) {
                if isThemed {
                    ThemedPageHeader(
                        eyebrow: eyebrow,
                        title: title,
                        subtitle: subtitle,
                        icon: icon
                    )
                    .padding(.bottom, 2)
                }
            }
    }
}

private struct ThemedPageSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat
    let elevated: Bool
    let mangaTint: Color

    func body(content: Content) -> some View {
        if MangaStyle.isActive {
            content
                .background(MangaCardBackground(cornerRadius: cornerRadius, elevated: elevated, tint: mangaTint))
                .themeRenderSurfaceLayer()
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
        } else if MaterialStyle.isActive {
            content
                .background(
                    MaterialSurfaceBackground(
                        cornerRadius: min(max(cornerRadius, 18), 28),
                        elevated: elevated,
                        pressed: !elevated,
                        role: elevated ? .elevated : .container
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
        } else {
            content
                .monologueGlass(cornerRadius: cornerRadius)
        }
    }
}

enum ThemedPageStyle {
    static var isActive: Bool {
        MangaStyle.isActive || MujiStyle.isActive || NeumorphicStyle.isActive || SequoiaStyle.isActive || MaterialStyle.isActive || ClayStyle.isActive || SignalStyle.isActive
    }

    static var listSpacing: CGFloat {
        if MangaStyle.isActive { return 10 }
        if MujiStyle.isActive { return 8 }
        if NeumorphicStyle.isActive { return 10 }
        if SequoiaStyle.isActive { return 6 }
        if MaterialStyle.isActive { return 8 }
        if ClayStyle.isActive { return 10 }
        if SignalStyle.isActive { return 9 }
        return 0
    }

    static var looseListSpacing: CGFloat {
        if MangaStyle.isActive { return 14 }
        if MujiStyle.isActive { return 12 }
        if NeumorphicStyle.isActive { return 14 }
        if SequoiaStyle.isActive { return 10 }
        if MaterialStyle.isActive { return 12 }
        if ClayStyle.isActive { return 14 }
        if SignalStyle.isActive { return 13 }
        return 12
    }

    static var horizontalInset: CGFloat {
        isActive ? 24 : 0
    }

    static var sectionInset: CGFloat {
        24
    }

    static var surfaceCornerRadius: CGFloat {
        if MangaStyle.isActive { return 18 }
        if MujiStyle.isActive { return 14 }
        if NeumorphicStyle.isActive { return 22 }
        if SequoiaStyle.isActive { return 20 }
        if MaterialStyle.isActive { return 24 }
        if ClayStyle.isActive { return 24 }
        if SignalStyle.isActive { return 26 }
        return 18
    }

    static var compactSurfaceCornerRadius: CGFloat {
        if MangaStyle.isActive { return 14 }
        if MujiStyle.isActive { return 12 }
        if NeumorphicStyle.isActive { return 18 }
        if SequoiaStyle.isActive { return 11 }
        if MaterialStyle.isActive { return 16 }
        if ClayStyle.isActive { return 18 }
        if SignalStyle.isActive { return 18 }
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
