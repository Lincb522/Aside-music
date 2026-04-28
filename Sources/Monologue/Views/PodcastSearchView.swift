import SwiftUI

/// 播客搜索页面
struct PodcastSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = PodcastSearchViewModel()
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        ZStack {
            ThemedPageBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 搜索栏
                searchBar
                    .padding(.top, 8)

                if viewModel.searchText.isEmpty {
                    // 热门电台推荐
                    hotRadiosSection
                } else if viewModel.isSearching && viewModel.results.isEmpty {
                    Spacer()
                    MonologueLoadingView(text: "SEARCHING")
                    Spacer()
                } else if !viewModel.searchText.isEmpty && viewModel.results.isEmpty && !viewModel.isSearching {
                    Spacer()
                    emptyResultView
                    Spacer()
                } else {
                    // 搜索结果
                    searchResultsList
                }
            }
        }
        .themedNavigationChrome(title: String(localized: "podcast_title"), eyebrow: "PODCAST", icon: .magnifyingGlass)
        .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear {
            viewModel.fetchHotRadios()
        }
    }

    // MARK: - 搜索栏

    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                MonologueIcon(icon: .magnifyingGlass, size: 15, color: NeumorphicStyle.isActive ? NeumorphicStyle.accent : .monologueTextSecondary, lineWidth: 1.4)

                TextField(String(localized: "podcast_search_placeholder"), text: $viewModel.searchText)
                    .font(NeumorphicStyle.isActive ? NeumorphicStyle.bodyFont(15, weight: .medium) : .system(size: 15, design: .rounded))
                    .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.ink : .monologueTextPrimary)
                    .monologueTextInputBehavior()
                    .focused($isSearchFocused)
                    .submitLabel(.search)

                if !viewModel.searchText.isEmpty {
                    Button(action: { viewModel.searchText = "" }) {
                        MonologueIcon(icon: .xmarkCircle, size: 14, color: NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : .monologueTextSecondary, lineWidth: 1.2)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, NeumorphicStyle.isActive ? 11 : 10)
            .themedPageSurface(cornerRadius: NeumorphicStyle.isActive ? 18 : 12, elevated: false)
            .clipShape(RoundedRectangle(cornerRadius: NeumorphicStyle.isActive ? 18 : 12, style: .continuous))

            Button(String(localized: "podcast_search_cancel")) {
                dismiss()
            }
            .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(15, weight: .semibold) : .system(size: 15, weight: .medium, design: .rounded))
            .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.accent : .monologueTextPrimary)
        }
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
        .padding(.bottom, 12)
    }

    // MARK: - 热门电台

    private var hotRadiosSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("podcast_hot_radios")
                    .font(MangaStyle.isActive ? MangaStyle.comicFont(18, weight: .bold) : (MujiStyle.isActive ? MujiStyle.titleFont(17, weight: .medium) : (NeumorphicStyle.isActive ? NeumorphicStyle.titleFont(18, weight: .semibold) : .system(size: 18, weight: .bold, design: .rounded))))
                    .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.ink : .monologueTextPrimary)
                    .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

                if viewModel.isLoadingHot {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding(.top, 40)
                } else {
                    LazyVStack(spacing: ThemedPageStyle.listSpacing) {
                        ForEach(viewModel.hotRadios) { radio in
                            NavigationLink(value: PodcastView.PodcastDestination.radioDetail(radio.id)) {
                                radioRow(radio: radio)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, ThemedPageStyle.horizontalInset)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - 搜索结果

    private var searchResultsList: some View {
        ScrollView {
            LazyVStack(spacing: ThemedPageStyle.listSpacing) {
                ForEach(viewModel.results) { radio in
                    NavigationLink(value: PodcastView.PodcastDestination.radioDetail(radio.id)) {
                        radioRow(radio: radio)
                    }
                    .buttonStyle(.plain)

                    // 滚动到底部加载更多
                    if radio.id == viewModel.results.last?.id && viewModel.hasMore {
                        Color.clear.frame(height: 1)
                            .onAppear { viewModel.loadMoreResults() }
                    }
                }

                if viewModel.isLoadingMore {
                    ProgressView()
                        .padding(.vertical, 16)
                }

                if !viewModel.hasMore && !viewModel.results.isEmpty {
                    NoMoreDataView()
                }
            }
            .padding(.horizontal, ThemedPageStyle.horizontalInset)
            .padding(.top, ThemedPageStyle.isActive ? 4 : 0)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - 空结果

    private var emptyResultView: some View {
        VStack(spacing: 12) {
            MonologueIcon(icon: .magnifyingGlass, size: 36, color: .monologueTextSecondary.opacity(0.5))
            Text("podcast_no_results")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.monologueTextSecondary)
        }
    }

    // MARK: - 电台行

    private func radioRow(radio: RadioStation) -> some View {
        HStack(spacing: 14) {
            CachedAsyncImage(url: radio.coverUrl) {
                RoundedRectangle(cornerRadius: coverRadius, style: .continuous)
                    .fill(NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.monologueGlassTint)
                    .monologueGlass(cornerRadius: coverRadius)
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: coverRadius, style: .continuous))
            .overlay(coverStroke)

            VStack(alignment: .leading, spacing: 4) {
                Text(radio.name)
                    .font(NeumorphicStyle.isActive ? NeumorphicStyle.bodyFont(15, weight: .semibold) : .system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.ink : .monologueTextPrimary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let dj = radio.dj?.nickname {
                        Text(dj)
                            .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(12, weight: .medium) : .system(size: 12, design: .rounded))
                            .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : .monologueTextSecondary)
                            .lineLimit(1)
                    }
                    if let count = radio.programCount, count > 0 {
                        Text(String(format: String(localized: "podcast_episode_count"), count))
                            .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(12, weight: .medium) : .system(size: 12, design: .rounded))
                            .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : .monologueTextSecondary)
                    }
                }
            }

            Spacer()

            MonologueIcon(icon: .chevronRight, size: 12, color: NeumorphicStyle.isActive ? NeumorphicStyle.accent : .monologueTextSecondary, lineWidth: 1.2)
        }
        .padding(.horizontal, ThemedPageStyle.isActive ? 16 : DeviceLayout.homeHorizontalPadding)
        .padding(.vertical, 12)
        .themedOnlyPageSurface(cornerRadius: ThemedPageStyle.compactSurfaceCornerRadius, elevated: false)
        .contentShape(Rectangle())
    }

    private var coverRadius: CGFloat {
        NeumorphicStyle.isActive ? 14 : 10
    }

    @ViewBuilder
    private var coverStroke: some View {
        if NeumorphicStyle.isActive {
            RoundedRectangle(cornerRadius: coverRadius, style: .continuous)
                .stroke(NeumorphicStyle.separator.opacity(0.5), lineWidth: 0.7)
        }
    }
}
