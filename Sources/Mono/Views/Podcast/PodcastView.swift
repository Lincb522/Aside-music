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

    private enum FeedSection: Hashable {
        case header
        case headerSupplement
        case history
        case banner
        case categories
        case personalized
        case todayPreferred
        case recommended
        case newcomer
        case newest
        case chart
        case programToplist
        case broadcast
        case bottomSpacer
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
                                ForEach(standardFeedSections, id: \.self) { section in
                                    feedView(for: section)
                                }
                            }
                            .padding(.bottom, 120)
                            .iPadContentWidth(1180)
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

    private var standardFeedSections: [FeedSection] {
        var sections: [FeedSection] = []

        sections.append(contentsOf: standardFeedHeaderSections)
        sections.append(.history)
        if !viewModel.djBanners.isEmpty {
            sections.append(.banner)
        }
        if !viewModel.categories.isEmpty {
            sections.append(.categories)
        }
        if !viewModel.personalizedRadios.isEmpty {
            sections.append(.personalized)
        }
        if !viewModel.todayPerfered.isEmpty {
            sections.append(.todayPreferred)
        }
        if !viewModel.recommendRadios.isEmpty {
            sections.append(.recommended)
        }
        if !viewModel.newcomerRadios.isEmpty {
            sections.append(.newcomer)
        }
        if !viewModel.newestPrograms.isEmpty {
            sections.append(.newest)
        }
        if !viewModel.chartPrograms.isEmpty {
            sections.append(.chart)
        }
        if !viewModel.programToplist.isEmpty {
            sections.append(.programToplist)
        }
        if !viewModel.broadcastChannels.isEmpty {
            sections.append(.broadcast)
        }

        return sections
    }

    private var minimalWhiteFeedSections: [FeedSection] {
        var sections: [FeedSection] = [.header]

        if !viewModel.categories.isEmpty {
            sections.append(.categories)
        }
        sections.append(.history)
        if !viewModel.personalizedRadios.isEmpty {
            sections.append(.personalized)
        }
        if !viewModel.todayPerfered.isEmpty {
            sections.append(.todayPreferred)
        }
        if !viewModel.recommendRadios.isEmpty {
            sections.append(.recommended)
        }
        if !viewModel.newestPrograms.isEmpty {
            sections.append(.newest)
        }
        if !viewModel.chartPrograms.isEmpty {
            sections.append(.chart)
        }
        if !viewModel.programToplist.isEmpty {
            sections.append(.programToplist)
        }
        if !viewModel.broadcastChannels.isEmpty {
            sections.append(.broadcast)
        }
        if !viewModel.djBanners.isEmpty {
            sections.append(.banner)
        }
        sections.append(.bottomSpacer)

        return sections
    }

    private var standardFeedHeaderSections: [FeedSection] {
        if MangaStyle.isActive {
            return [.header]
        }
        if PetWhiteStyle.isActive || MujiStyle.isActive || NeumorphicStyle.isActive {
            return [.header, .headerSupplement]
        }
        if SignalStyle.isActive {
            return [.header]
        }
        if SequoiaStyle.isActive || LiquidGlassStyle.isActive {
            return [.header, .headerSupplement]
        }
        if !ThemedPageStyle.isActive {
            return [.header]
        }
        return []
    }

    private func feedView(for section: FeedSection) -> AnyView {
        switch section {
        case .header:
            return feedHeader
        case .headerSupplement:
            return feedHeaderSupplement
        case .history:
            return AnyView(PodcastHistorySection(onOpenRadio: openRadioPlayer))
        case .banner:
            return AnyView(bannerSection)
        case .categories:
            return AnyView(categoriesSection)
        case .personalized:
            return AnyView(personalizedSection)
        case .todayPreferred:
            return AnyView(todayPerferedSection)
        case .recommended:
            return AnyView(recommendSection)
        case .newcomer:
            return AnyView(newcomerSection)
        case .newest:
            return AnyView(newestSection)
        case .chart:
            return AnyView(chartSection)
        case .programToplist:
            return AnyView(programToplistSection)
        case .broadcast:
            return AnyView(broadcastSection)
        case .bottomSpacer:
            return AnyView(FloatingBarBottomSpacer())
        }
    }

    private var feedHeader: AnyView {
        if MinimalWhiteStyle.isActive {
            return AnyView(minimalWhitePodcastHeader)
        }
        if MangaStyle.isActive {
            return AnyView(mangaPodcastHeader)
        }
        if PetWhiteStyle.isActive {
            return AnyView(petWhitePodcastHeader)
        }
        if MujiStyle.isActive {
            return AnyView(mujiPodcastHeader)
        }
        if NeumorphicStyle.isActive {
            return AnyView(neumorphicPodcastHeader)
        }
        if SignalStyle.isActive {
            return AnyView(signalPodcastHeader)
        }
        if SequoiaStyle.isActive {
            return AnyView(sequoiaPodcastHeader)
        }
        if LiquidGlassStyle.isActive {
            return AnyView(liquidGlassPodcastHeader)
        }
        if !ThemedPageStyle.isActive {
            return AnyView(asidePodcastHeader)
        }
        return AnyView(EmptyView())
    }

    private var feedHeaderSupplement: AnyView {
        if PetWhiteStyle.isActive {
            return AnyView(petWhitePodcastSummary)
        }
        if MujiStyle.isActive {
            return AnyView(mujiPodcastSummary)
        }
        if NeumorphicStyle.isActive {
            return AnyView(neumorphicPodcastSummary)
        }
        if SequoiaStyle.isActive {
            return AnyView(sequoiaPodcastSummary)
        }
        if LiquidGlassStyle.isActive {
            return AnyView(liquidGlassPodcastConstellation)
        }
        return AnyView(EmptyView())
    }

    func openRadioPlayer(_ radioId: Int) {
        guard radioId > 0 else { return }
        radioIdToOpen = radioId
        showRadioPlayer = true
    }

    var minimalWhitePodcastScroll: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 30) {
                ForEach(minimalWhiteFeedSections, id: \.self) { section in
                    feedView(for: section)
                }
            }
            .padding(.top, DeviceLayout.headerTopPadding + 8)
            .iPadContentWidth(1180)
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

    func podcastDestinationView(for destination: PodcastDestination) -> AnyView {
        switch destination {
        case let .category(cat):
            return AnyView(CategoryRadioView(category: cat))
        case let .radioDetail(radioId):
            return AnyView(RadioDetailView(radioId: radioId))
        case .search:
            return AnyView(PodcastSearchView())
        case let .topList(title, listType):
            return AnyView(TopRadioListView(title: title, listType: listType))
        case .categoryBrowse:
            return AnyView(RadioCategoryBrowseView())
        case .broadcastList:
            return AnyView(BroadcastListView())
        }
    }

}
