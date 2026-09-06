import SwiftUI

struct DefaultPageTitle: View {
    let title: String
    var isRoot = false
    var color: Color = .monoTextPrimary
    @ScaledMetric(relativeTo: .title2) private var rootSize: CGFloat = 26
    @ScaledMetric(relativeTo: .headline) private var detailSize: CGFloat = 19

    var body: some View {
        Text(title)
            // Keep the navigation title within one toolbar row; larger text remains available on long press.
            .font(.system(size: min(isRoot ? rootSize : detailSize, isRoot ? 34 : 25), weight: .semibold, design: .rounded))
            .foregroundStyle(color)
            .lineLimit(1)
            .accessibilityAddTraits(.isHeader)
            .accessibilityShowsLargeContentViewer {
                Text(title)
            }
    }
}

struct DefaultHeaderActionLabel: View {
    let icon: MonoIcon.IconType
    let title: String
    var color: Color = .monoTextPrimary

    var body: some View {
        MonoIcon(icon: icon, size: 18, color: color, lineWidth: 1.7)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .accessibilityLabel(title)
            .accessibilityShowsLargeContentViewer {
                Text(title)
            }
    }
}

private struct DefaultRootPageTitleModifier: ViewModifier {
    let title: String

    @ViewBuilder
    func body(content: Content) -> some View {
        if GlobalThemeId.persistedOrDefault == .default {
            content
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(.visible, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        DefaultPageTitle(title: title, isRoot: true)
                    }
                }
        } else {
            content.toolbar(.hidden, for: .navigationBar)
        }
    }
}

extension View {
    func defaultRootPageTitle(_ title: String) -> some View {
        modifier(DefaultRootPageTitleModifier(title: title))
    }

    @ViewBuilder
    func defaultNavigationPageTitle(_ title: String) -> some View {
        if GlobalThemeId.persistedOrDefault == .default {
            monoNavigationBackButton(title: title)
        } else {
            self
        }
    }
}
