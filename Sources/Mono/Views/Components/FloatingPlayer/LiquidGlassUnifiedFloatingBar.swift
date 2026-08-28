import SwiftUI

struct LiquidGlassUnifiedFloatingBar: View {
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
                    LiquidGlassPrismBand(
                        tint: player.isPlaying ? LiquidGlassStyle.accent : LiquidGlassStyle.inkMuted,
                        cornerRadius: 21
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
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LiquidGlassStyle.glassList.opacity(colorScheme == .dark ? 0.72 : 0.58))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(LiquidGlassStyle.luminousEdge.opacity(colorScheme == .dark ? 0.18 : 0.46), lineWidth: 0.6)
                    )
            )
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 7)
        .background(LiquidGlassSurfaceBackground(cornerRadius: 27, elevated: true, role: .floating))
        .overlay(alignment: .top) {
            LiquidGlassHairline(tint: LiquidGlassStyle.accent.opacity(colorScheme == .dark ? 0.28 : 0.5))
                .frame(width: 72)
                .offset(y: 6)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 27, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            LiquidGlassStyle.luminousEdge.opacity(colorScheme == .dark ? 0.2 : 0.58),
                            LiquidGlassStyle.separator.opacity(0.82),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.7
                )
        )
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
