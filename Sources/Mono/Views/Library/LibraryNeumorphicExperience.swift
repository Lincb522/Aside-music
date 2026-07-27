import Combine
import QQMusicKit
import SwiftUI
import UniformTypeIdentifiers

struct NeumorphicLibraryExperience: View {
    @ObservedObject var viewModel: LibraryViewModel
    @Binding var tabIndex: Int
    @State private var dragOffset: CGFloat = 0
    @State private var headerCollapseProgress: CGFloat = 0
    @State private var headerDragStart: CGFloat?

    private let tabs = LibraryViewModel.LibraryTab.allCases

    var body: some View {
        ZStack {
            ThemedPageBackground(useRenderLayer: true)

            VStack(spacing: 0) {
                LibraryCollapsingHeader(progress: $headerCollapseProgress, collapseDistance: headerCollapseDistance) {
                    headerConsole
                }

                GeometryReader { geo in
                    let width = max(geo.size.width, 1)

                    HStack(spacing: 0) {
                        MyPlaylistsContainerView(viewModel: viewModel)
                            .frame(width: width)
                        PlaylistSquareView(viewModel: viewModel)
                            .frame(width: width)
                        ArtistLibraryView(viewModel: viewModel)
                            .frame(width: width)
                        ChartsLibraryView(viewModel: viewModel)
                            .frame(width: width)
                    }
                    .frame(width: width * CGFloat(tabs.count), alignment: .leading)
                    .offset(x: -CGFloat(tabIndex) * width + dragOffset)
                    .animation(.spring(response: 0.3, dampingFraction: 0.9), value: tabIndex)
                    .gesture(pagingGesture(width: width))
                    .simultaneousGesture(headerScrollGesture)
                    .transaction { transaction in
                        transaction.disablesAnimations = width <= 1
                    }
                }
                .clipped()
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .onAppear(perform: clampTabIndex)
        .onChange(of: tabIndex) { _, _ in
            clampTabIndex()
        }
    }

    private var headerConsole: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                NeumorphicIconBadge(icon: .library, tint: activeTabTint, size: 40)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 7) {
                        Text("LIBRARY")
                            .font(NeumorphicStyle.labelFont(9, weight: .semibold))
                            .foregroundStyle(activeTabTint)
                            .tracking(1.1)

                        Capsule()
                            .fill(NeumorphicStyle.separator.opacity(0.76))
                            .frame(width: 18, height: 1)
                    }

                    Text(String(localized: "tabbar_library"))
                        .font(NeumorphicStyle.titleFont(20, weight: .semibold))
                        .foregroundStyle(NeumorphicStyle.ink)
                        .lineLimit(1)
                }

                Spacer(minLength: 10)

                Text(activeTabLabel)
                    .font(NeumorphicStyle.labelFont(10, weight: .semibold))
                    .foregroundStyle(activeTabTint)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(activeTabTint.opacity(0.13))
                    )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(NeumorphicSurfaceBackground(cornerRadius: 22, elevated: true))
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
            .padding(.top, DeviceLayout.headerTopPadding + 8)

            HStack(spacing: 7) {
                ForEach(Array(tabs.enumerated()), id: \.element) { index, tab in
                    neumorphicTabButton(tab: tab, index: index)
                }
            }
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
        }
        .padding(.bottom, 8)
    }

    private var headerCollapseDistance: CGFloat { 168 }

    private var headerScrollGesture: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .local)
            .onChanged { value in
                guard abs(value.translation.height) > abs(value.translation.width) else { return }
                if headerDragStart == nil {
                    headerDragStart = headerCollapseProgress
                }
                let start = headerDragStart ?? headerCollapseProgress
                let next = start - value.translation.height / max(headerCollapseDistance, 1)
                headerCollapseProgress = min(max(next, 0), 1)
            }
            .onEnded { value in
                guard headerDragStart != nil else { return }
                let projected = headerCollapseProgress - value.predictedEndTranslation.height / max(headerCollapseDistance, 1) * 0.14
                headerDragStart = nil
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                    headerCollapseProgress = projected > 0.42 ? 1 : 0
                }
            }
    }

    private func neumorphicTabButton(tab: LibraryViewModel.LibraryTab, index: Int) -> some View {
        let selected = tabIndex == index
        let tint = tabTint(tab)

        return Button {
            switchToTab(tab, index: index)
        } label: {
            HStack(spacing: 5) {
                MonoIcon(
                    icon: tabIcon(tab),
                    size: 12,
                    color: selected ? tint : NeumorphicStyle.inkSoft,
                    lineWidth: 1.55
                )

                Text(tab.localizedKey)
                    .font(NeumorphicStyle.labelFont(10, weight: selected ? .semibold : .medium))
                    .foregroundStyle(selected ? NeumorphicStyle.ink : NeumorphicStyle.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .background(
                NeumorphicSurfaceBackground(
                    cornerRadius: 13,
                    elevated: selected,
                    pressed: !selected,
                    tint: selected ? tint.opacity(0.17) : NeumorphicStyle.surface,
                    lightweight: true
                )
            )
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.96))
    }

    private var activeTabLabel: String {
        guard tabs.indices.contains(tabIndex) else { return "COLLECTION" }
        switch tabs[tabIndex] {
        case .my: return "COLLECTION"
        case .square: return "DISCOVER"
        case .artists: return "ARTISTS"
        case .charts: return "CHARTS"
        }
    }

    private var activeTabTint: Color {
        guard tabs.indices.contains(tabIndex) else { return NeumorphicStyle.accent }
        return tabTint(tabs[tabIndex])
    }

    private func tabIcon(_ tab: LibraryViewModel.LibraryTab) -> MonoIcon.IconType {
        switch tab {
        case .my: return .library
        case .square: return .musicNoteList
        case .artists: return .profile
        case .charts: return .chart
        }
    }

    private func tabTint(_ tab: LibraryViewModel.LibraryTab) -> Color {
        switch tab {
        case .my: return NeumorphicStyle.accent
        case .square: return NeumorphicStyle.warm
        case .artists: return NeumorphicStyle.sage
        case .charts: return NeumorphicStyle.red
        }
    }

    private func switchToTab(_ tab: LibraryViewModel.LibraryTab, index: Int) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            tabIndex = index
            viewModel.currentTab = tab
        }
    }

    private func clampTabIndex() {
        guard !tabs.indices.contains(tabIndex) else { return }
        tabIndex = 0
        viewModel.currentTab = tabs[0]
    }

    private func pagingGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onChanged { value in
                if abs(value.translation.width) > abs(value.translation.height) {
                    dragOffset = value.translation.width
                }
            }
            .onEnded { value in
                let threshold: CGFloat = width * 0.2
                var newIndex = tabIndex
                if value.translation.width < -threshold || value.predictedEndTranslation.width < -width * 0.4 {
                    newIndex = min(tabIndex + 1, tabs.count - 1)
                } else if value.translation.width > threshold || value.predictedEndTranslation.width > width * 0.4 {
                    newIndex = max(tabIndex - 1, 0)
                }
                dragOffset = 0
                switchToTab(tabs[newIndex], index: newIndex)
            }
    }
}

// MARK: - Subviews
