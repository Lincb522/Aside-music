import Combine
import SwiftUI

struct PodcastView: View {
    @ObservedObject var viewModel = PodcastViewModel.shared
    @State var showRadioPlayer = false
    @State var radioIdToOpen: Int = 0
    @State var selectedBroadcastChannel: BroadcastChannel?
    @State var bannerWebURL: URL?
    @ObservedObject var settings = SettingsManager.shared

    enum PodcastDestination: Hashable {
        case category(RadioCategory)
        case radioDetail(Int)
        case search
        case topList(String, TopRadioListView.ListType)
        case categoryBrowse
        case broadcastList

        static func == (lhs: PodcastDestination, rhs: PodcastDestination) -> Bool {
            switch (lhs, rhs) {
            case let (.category(a), .category(b)): return a == b
            case let (.radioDetail(a), .radioDetail(b)): return a == b
            case (.search, .search): return true
            case let (.topList(a, _), .topList(b, _)): return a == b
            case (.categoryBrowse, .categoryBrowse): return true
            case (.broadcastList, .broadcastList): return true
            default: return false
            }
        }

        func hash(into hasher: inout Hasher) {
            switch self {
            case let .category(cat): hasher.combine("category"); hasher.combine(cat)
            case let .radioDetail(id): hasher.combine("radio"); hasher.combine(id)
            case .search: hasher.combine("search")
            case let .topList(title, _): hasher.combine("topList"); hasher.combine(title)
            case .categoryBrowse: hasher.combine("categoryBrowse")
            case .broadcastList: hasher.combine("broadcastList")
            }
        }
    }

    var body: some View {
        let _ = settings.globalThemeRevision

        NavigationStack {
            ZStack {
                ThemedPageBackground(useRenderLayer: true)

                if viewModel.isLoading && viewModel.personalizedRadios.isEmpty {
                    MonoLoadingView(text: MinimalWhiteStyle.isActive ? "" : "LOADING")
                } else {
                    if MinimalWhiteStyle.isActive {
                        minimalWhitePodcastScroll
                    } else {
                        ScrollView {
                        LazyVStack(alignment: .leading, spacing: 28) {
                            if MangaStyle.isActive {
                                mangaPodcastHeader
                            } else if PetWhiteStyle.isActive {
                                petWhitePodcastHeader
                                petWhitePodcastSummary
                            } else if MujiStyle.isActive {
                                mujiPodcastHeader
                                mujiPodcastSummary
                            } else if NeumorphicStyle.isActive {
                                neumorphicPodcastHeader
                                neumorphicPodcastSummary
                            } else if SignalStyle.isActive {
                                SignalPageHeader(
                                    eyebrow: "",
                                    title: String(localized: "tabbar_podcast"),
                                    subtitle: ""
                                )
                            } else if SequoiaStyle.isActive {
                                sequoiaPodcastHeader
                                sequoiaPodcastSummary
                            } else if LiquidGlassStyle.isActive {
                                liquidGlassPodcastHeader
                                liquidGlassPodcastConstellation
                            } else if !ThemedPageStyle.isActive {
                                asidePodcastHeader
                            }

                            PodcastHistorySection(onOpenRadio: openRadioPlayer)

                            // DJ Banner 轮播
                            if !viewModel.djBanners.isEmpty {
                                bannerSection
                            }

                            // 分类标签（横向滚动胶囊）
                            if !viewModel.categories.isEmpty {
                                categoriesSection
                            }

                            // 为你推荐（大卡片，2列网格）
                            if !viewModel.personalizedRadios.isEmpty {
                                personalizedSection
                            }

                            // 今日优选
                            if !viewModel.todayPerfered.isEmpty {
                                todayPerferedSection
                            }

                            // 精选电台（列表样式）
                            if !viewModel.recommendRadios.isEmpty {
                                recommendSection
                            }

                            // 新人电台榜
                            if !viewModel.newcomerRadios.isEmpty {
                                newcomerSection
                            }

                            // 上新佳作
                            if !viewModel.newestPrograms.isEmpty {
                                newestSection
                            }

                            // 音乐播客榜
                            if !viewModel.chartPrograms.isEmpty {
                                chartSection
                            }

                            // 节目榜
                            if !viewModel.programToplist.isEmpty {
                                programToplistSection
                            }

                            // 广播电台（地区 FM）
                            if !viewModel.broadcastChannels.isEmpty {
                                broadcastSection
                            }
                        }
                        .padding(.bottom, 120)
                        }
                        .scrollIndicators(.hidden)
                        .themeRenderScrollLayer()
                        .refreshable {
                            viewModel.refreshData()
                        }
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(for: PodcastDestination.self) { destination in
                podcastDestinationView(for: destination)
                    .petWhiteNestedPage()
            }
        }
        .task {
            await viewModel.ensureDataLoadedAfterTabTransition(reason: "podcast appear")
        }
        .fullScreenCover(isPresented: $showRadioPlayer, onDismiss: {
            radioIdToOpen = 0
        }) {
            PodcastPlayerView(radioId: radioIdToOpen)
        }
        .fullScreenCover(item: $selectedBroadcastChannel) { channel in
            BroadcastPlayerView(channel: channel)
        }
        .fullScreenCover(item: $bannerWebURL) { url in
            MonoWebView(url: url, title: nil)
        }
        .onChange(of: radioIdToOpen) { _, newId in
            if newId > 0 {
                showRadioPlayer = true
            }
        }
    }

    func openRadioPlayer(_ radioId: Int) {
        guard radioId > 0 else { return }
        radioIdToOpen = radioId
        showRadioPlayer = true
    }

    var minimalWhitePodcastScroll: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 30) {
                minimalWhitePodcastHeader

                if !viewModel.categories.isEmpty {
                    categoriesSection
                }

                PodcastHistorySection(onOpenRadio: openRadioPlayer)

                if !viewModel.personalizedRadios.isEmpty {
                    personalizedSection
                }

                if !viewModel.todayPerfered.isEmpty {
                    todayPerferedSection
                }

                if !viewModel.recommendRadios.isEmpty {
                    recommendSection
                }

                if !viewModel.newestPrograms.isEmpty {
                    newestSection
                }

                if !viewModel.chartPrograms.isEmpty {
                    chartSection
                }

                if !viewModel.programToplist.isEmpty {
                    programToplistSection
                }

                if !viewModel.broadcastChannels.isEmpty {
                    broadcastSection
                }

                if !viewModel.djBanners.isEmpty {
                    bannerSection
                }

                FloatingBarBottomSpacer()
            }
            .padding(.top, DeviceLayout.headerTopPadding + 8)
        }
        .scrollIndicators(.hidden)
        .themeRenderScrollLayer()
        .refreshable { viewModel.refreshData() }
    }

    var minimalWhitePodcastHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            Text(String(localized: "tabbar_podcast"))
                .font(MinimalWhiteStyle.titleFont(30, weight: .semibold))
                .foregroundStyle(MinimalWhiteStyle.ink)

            Spacer(minLength: 12)

            NavigationLink(value: PodcastDestination.categoryBrowse) {
                MonoIcon(icon: .gridSquare, size: 17, color: MinimalWhiteStyle.inkSoft, lineWidth: 1.6)
                    .frame(width: 40, height: 40)
                    .background(MinimalWhiteCircleBackground(elevated: true))
            }
            .buttonStyle(.plain)

            NavigationLink(value: PodcastDestination.search) {
                MonoIcon(icon: .magnifyingGlass, size: 17, color: MinimalWhiteStyle.ink, lineWidth: 1.7)
                    .frame(width: 40, height: 40)
                    .background(MinimalWhiteCircleBackground(elevated: true, selected: true))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, padH)
        .monoPageHeaderCollapse()
    }

    /// aside 刊头：眉题行 + 大标题 + 搜索入口
    var asidePodcastHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Capsule()
                    .fill(Color.monoAccent)
                    .frame(width: 18, height: 3)

                Text("PODCAST")
                    .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                    .tracking(2.4)
                    .foregroundColor(.monoTextSecondary.opacity(0.72))
                    .fixedSize()

                Rectangle()
                    .fill(Color.monoSeparator.opacity(0.5))
                    .frame(height: 0.5)
            }
            .padding(.bottom, 16)

            HStack(alignment: .center, spacing: 12) {
                Text(String(localized: "tabbar_podcast"))
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundColor(.monoTextPrimary)

                Spacer(minLength: 12)

                NavigationLink(value: PodcastDestination.search) {
                    MonoIcon(icon: .search, size: 15, color: .monoTextPrimary, lineWidth: 1.7)
                        .frame(width: 36, height: 36)
                        .overlay(Circle().stroke(Color.monoSeparator.opacity(0.9), lineWidth: 0.8))
                        .contentShape(Circle())
                }
                .buttonStyle(MonoBouncingButtonStyle(scale: 0.92))
            }
        }
        .padding(.horizontal, padH)
        .padding(.top, DeviceLayout.headerTopPadding + 6)
        .monoPageHeaderCollapse()
    }

    @ViewBuilder
    func podcastDestinationView(for destination: PodcastDestination) -> some View {
        switch destination {
        case let .category(cat):
            CategoryRadioView(category: cat)
        case let .radioDetail(radioId):
            RadioDetailView(radioId: radioId)
        case .search:
            PodcastSearchView()
        case let .topList(title, listType):
            TopRadioListView(title: title, listType: listType)
        case .categoryBrowse:
            RadioCategoryBrowseView()
        case .broadcastList:
            BroadcastListView()
        }
    }

}
