import SwiftUI

struct ThemedPageBackground: View {
    var body: some View {
        if MangaStyle.isActive {
            MangaRootBackdrop()
        } else if MujiStyle.isActive {
            MujiRootBackdrop()
        } else {
            MonologueBackground()
                .ignoresSafeArea()
        }
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

private struct ThemedNavigationChromeModifier: ViewModifier {
    let title: String
    let eyebrow: String
    let subtitle: String
    let icon: MonologueIcon.IconType

    private var isThemed: Bool {
        MangaStyle.isActive || MujiStyle.isActive
    }

    @ViewBuilder
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

    @ViewBuilder
    func body(content: Content) -> some View {
        if MangaStyle.isActive {
            content
                .background(MangaCardBackground(cornerRadius: cornerRadius, elevated: elevated, tint: mangaTint))
        } else if MujiStyle.isActive {
            content
                .background(MujiPaperCardBackground(cornerRadius: min(cornerRadius, 16), elevated: elevated))
        } else {
            content
                .monologueGlass(cornerRadius: cornerRadius)
        }
    }
}

enum ThemedPageStyle {
    static var isActive: Bool {
        MangaStyle.isActive || MujiStyle.isActive
    }

    static var listSpacing: CGFloat {
        MangaStyle.isActive ? 10 : (MujiStyle.isActive ? 8 : 0)
    }

    static var looseListSpacing: CGFloat {
        MangaStyle.isActive ? 14 : (MujiStyle.isActive ? 12 : 12)
    }

    static var horizontalInset: CGFloat {
        isActive ? 24 : 0
    }

    static var sectionInset: CGFloat {
        24
    }

    static var surfaceCornerRadius: CGFloat {
        MangaStyle.isActive ? 18 : (MujiStyle.isActive ? 14 : 18)
    }

    static var compactSurfaceCornerRadius: CGFloat {
        MangaStyle.isActive ? 14 : (MujiStyle.isActive ? 12 : 14)
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
