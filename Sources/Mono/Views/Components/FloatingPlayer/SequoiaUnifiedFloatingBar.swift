import SwiftUI

struct SequoiaUnifiedFloatingBar: View {
    @Binding var currentTab: Tab
    @ObservedObject private var player = FloatingBarPlaybackModel.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 6) {
            if let song = player.currentSong {
                MiniPlayerSection(
                    song: song,
                    isPlaying: player.isPlaying,
                    togglePlayPause: { player.togglePlayPause() }
                )
                .swipeToSkip()
                .background(
                    SequoiaGlassBand(
                        tint: player.isPlaying ? SequoiaStyle.accent : SequoiaStyle.graphite,
                        cornerRadius: 20
                    )
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.975, anchor: .bottom)),
                    removal: .opacity.combined(with: .scale(scale: 0.975, anchor: .bottom))
                ))
            }

            MonoTabBar(selectedIndex: Binding(
                get: { Tab.allCases.firstIndex(of: currentTab) ?? 0 },
                set: { currentTab = Tab.allCases[$0] }
            ))
            .contentShape(Rectangle())
            .simultaneousGesture(tabSwipeGesture)
            .background(
                RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .fill(SequoiaStyle.materialList.opacity(colorScheme == .dark ? 0.72 : 0.56))
                    .overlay(
                        RoundedRectangle(cornerRadius: 19, style: .continuous)
                            .stroke(SequoiaStyle.separator, lineWidth: 0.55)
                    )
            )
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 7)
        .background(SequoiaSurfaceBackground(cornerRadius: 25, elevated: true, role: .floating))
        .overlay(alignment: .top) {
            Capsule()
                .fill(SequoiaStyle.luminousSeparator.opacity(colorScheme == .dark ? 0.22 : 0.7))
                .frame(width: 48, height: 3)
                .offset(y: 5)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            SequoiaStyle.luminousSeparator.opacity(colorScheme == .dark ? 0.18 : 0.52),
                            SequoiaStyle.separator.opacity(0.78),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.65
                )
        )
        .shadow(color: SequoiaStyle.shadow(colorScheme, elevated: true), radius: 18, x: 0, y: 9)
        .animation(MonoAnimation.floatingBar, value: player.currentSong != nil)
        .animation(MonoAnimation.tabSwitch, value: currentTab)
        .themeRenderInteractiveLayer()
    }

    private var tabSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 50, coordinateSpace: .local)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                switchTab(direction: value.translation.width < 0 ? 1 : -1)
            }
    }

    private func switchTab(direction: Int) {
        let allTabs = Tab.allCases
        guard let currentIndex = allTabs.firstIndex(of: currentTab) else { return }
        let nextIndex = currentIndex + direction

        if nextIndex >= 0, nextIndex < allTabs.count {
            withAnimation(MonoAnimation.tabSwitch) {
                currentTab = allTabs[nextIndex]
            }
        }
    }
}
