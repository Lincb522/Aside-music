import Combine
import SwiftUI

struct PodcastView: View {
    @State private var viewModel = PodcastViewModel.shared
    @State private var showRadioPlayer = false
    @State private var radioIdToOpen: Int = 0
    @State private var selectedBroadcastChannel: BroadcastChannel?
    @State private var bannerWebURL: URL?
    @ObservedObject private var settings = SettingsManager.shared

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
                    MonologueLoadingView(text: "LOADING")
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
                            } else if SequoiaStyle.isActive {
                                sequoiaPodcastHeader
                                sequoiaPodcastSummary
                            } else if LiquidGlassStyle.isActive {
                                liquidGlassPodcastHeader
                                liquidGlassPodcastConstellation
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
            .navigationTitle(ThemedPageStyle.isActive ? "" : String(localized: "tabbar_podcast"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                if !ThemedPageStyle.isActive {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink(value: PodcastDestination.search) {
                            MonologueIcon(icon: .search, size: 16)
                                .padding(2)
                        }
                    }
                }
            }
            .navigationDestination(for: PodcastDestination.self) { destination in
                podcastDestinationView(for: destination)
                    .petWhiteNestedPage()
            }
        }
        .onAppear {
            viewModel.ensureDataLoaded(reason: "podcast appear")
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
            MonologueWebView(url: url, title: nil)
        }
        .onChange(of: radioIdToOpen) { _, newId in
            if newId > 0 {
                showRadioPlayer = true
            }
        }
    }

    private func openRadioPlayer(_ radioId: Int) {
        guard radioId > 0 else { return }
        radioIdToOpen = radioId
        showRadioPlayer = true
    }

    @ViewBuilder
    private func podcastDestinationView(for destination: PodcastDestination) -> some View {
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

    // MARK: - DJ Banner 轮播

    private var mangaPodcastHeader: some View {
        MangaPageHeader(
            eyebrow: "RADIO",
            title: String(localized: "tabbar_podcast"),
            subtitle: ""
        ) {
            NavigationLink(value: PodcastDestination.search) {
                MangaIconBadge(icon: .magnifyingGlass, size: 48, tint: MangaStyle.bubbleBlue)
            }
            .buttonStyle(.plain)
        }
    }

    private var petWhitePodcastHeader: some View {
        PetWhitePageHeader(
            eyebrow: "PODCAST",
            title: String(localized: "tabbar_podcast"),
            subtitle: String(localized: "global_theme_pet_white_name")
        ) {
            NavigationLink(value: PodcastDestination.search) {
                PetWhiteIconBadge(icon: .magnifyingGlass, tint: PetWhiteStyle.sky, size: 48)
            }
            .buttonStyle(.plain)
        }
    }

    private var petWhitePodcastSummary: some View {
        HStack(spacing: 10) {
            petWhitePodcastMetric(value: "\(viewModel.personalizedRadios.count)", label: String(localized: "podcast_for_you"), tint: PetWhiteStyle.dogOrange, icon: .podcast)
            petWhitePodcastMetric(value: "\(viewModel.categories.count)", label: String(localized: "podcast_all"), tint: PetWhiteStyle.mint, icon: .gridSquare)
            petWhitePodcastMetric(value: "\(viewModel.broadcastChannels.count)", label: String(localized: "podcast_broadcast"), tint: PetWhiteStyle.sky, icon: .radio)
        }
        .padding(12)
        .background(PetWhiteSurfaceBackground(cornerRadius: 24, elevated: true, tint: PetWhiteStyle.surfaceRaised, accent: PetWhiteStyle.mint))
        .padding(.horizontal, padH)
    }

    private func petWhitePodcastMetric(value: String, label: String, tint: Color, icon: MonologueIcon.IconType) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            PetWhiteIconBadge(icon: icon, tint: tint, size: 34)

            Text(value)
                .font(PetWhiteStyle.titleFont(18, weight: .black))
                .foregroundStyle(PetWhiteStyle.ink)
                .lineLimit(1)

            Text(label)
                .font(PetWhiteStyle.labelFont(10, weight: .black))
                .foregroundStyle(PetWhiteStyle.inkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(PetWhiteSurfaceBackground(cornerRadius: 18, elevated: false, tint: PetWhiteStyle.surfacePressed, accent: tint))
    }

    private var mujiPodcastHeader: some View {
        MujiPageHeader(
            eyebrow: "radio archive",
            title: String(localized: "tabbar_podcast"),
            subtitle: ""
        ) {
            NavigationLink(value: PodcastDestination.search) {
                MujiIconBadge(icon: .search, tint: MujiStyle.indigo, size: 48)
            }
            .buttonStyle(.plain)
        }
    }

    private var mujiPodcastSummary: some View {
        HStack(spacing: 10) {
            MujiMetricTile(value: "\(viewModel.personalizedRadios.count)", label: String(localized: "podcast_for_you"), tint: MujiStyle.clay)
            MujiMetricTile(value: "\(viewModel.categories.count)", label: String(localized: "podcast_all"), tint: MujiStyle.tea)
            MujiMetricTile(value: "\(viewModel.broadcastChannels.count)", label: String(localized: "podcast_broadcast"), tint: MujiStyle.indigo)
        }
        .padding(14)
        .background(MujiPaperCardBackground(cornerRadius: 12, elevated: true))
        .padding(.horizontal, padH)
    }

    private var neumorphicPodcastHeader: some View {
        NeumorphicPageHeader(
            eyebrow: "RADIO",
            title: String(localized: "tabbar_podcast"),
            subtitle: ""
        ) {
            NavigationLink(value: PodcastDestination.search) {
                NeumorphicIconBadge(icon: .magnifyingGlass, tint: NeumorphicStyle.accent, size: 48)
            }
            .buttonStyle(.plain)
        }
    }

    private var neumorphicPodcastSummary: some View {
        HStack(spacing: 10) {
            NeumorphicPill(text: "\(viewModel.personalizedRadios.count)", tint: NeumorphicStyle.accent, icon: .podcast, selected: true)
            NeumorphicPill(text: "\(viewModel.categories.count)", tint: NeumorphicStyle.sage, icon: .gridSquare, selected: true)
            NeumorphicPill(text: "\(viewModel.broadcastChannels.count)", tint: NeumorphicStyle.warm, icon: .radio, selected: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(NeumorphicSurfaceBackground(cornerRadius: 20, elevated: true))
        .padding(.horizontal, padH)
    }

    private var sequoiaPodcastHeader: some View {
        SequoiaPageHeader(
            eyebrow: "RADIO",
            title: String(localized: "tabbar_podcast"),
            subtitle: ""
        ) {
            NavigationLink(value: PodcastDestination.search) {
                SequoiaControlButton(icon: .magnifyingGlass, tint: SequoiaStyle.accent, size: 44, selected: true)
            }
            .buttonStyle(.plain)
        }
    }

    private var sequoiaPodcastSummary: some View {
        HStack(spacing: 8) {
            SequoiaPill(text: "\(viewModel.personalizedRadios.count)", icon: .podcast, tint: SequoiaStyle.accent, selected: true, compact: true)
            SequoiaPill(text: "\(viewModel.categories.count)", icon: .gridSquare, tint: SequoiaStyle.aqua, selected: true, compact: true)
            SequoiaPill(text: "\(viewModel.broadcastChannels.count)", icon: .radio, tint: SequoiaStyle.violet, selected: true, compact: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, padH)
    }

    private var liquidGlassPodcastHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            LiquidGlassDropletMark(tint: LiquidGlassStyle.violet)

            VStack(alignment: .leading, spacing: 4) {
                Text("PODCAST")
                    .font(LiquidGlassStyle.labelFont(10, weight: .semibold))
                    .foregroundStyle(LiquidGlassStyle.inkMuted)
                    .tracking(1.4)

                Text(String(localized: "tabbar_podcast"))
                    .font(LiquidGlassStyle.titleFont(27, weight: .semibold))
                    .foregroundStyle(LiquidGlassStyle.ink)
            }

            Spacer(minLength: 0)

            NavigationLink(value: PodcastDestination.search) {
                LiquidGlassControlButton(icon: .magnifyingGlass, tint: LiquidGlassStyle.violet, size: 44, selected: true)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, padH)
        .padding(.top, DeviceLayout.headerTopPadding + 8)
    }

    private var liquidGlassPodcastConstellation: some View {
        HStack(spacing: 10) {
            liquidGlassPodcastMetric(
                icon: .podcast,
                value: "\(viewModel.personalizedRadios.count)",
                label: String(localized: "podcast_for_you"),
                tint: LiquidGlassStyle.violet
            )
            liquidGlassPodcastMetric(
                icon: .gridSquare,
                value: "\(viewModel.categories.count)",
                label: String(localized: "podcast_all"),
                tint: LiquidGlassStyle.cyan
            )
            liquidGlassPodcastMetric(
                icon: .radio,
                value: "\(viewModel.broadcastChannels.count)",
                label: String(localized: "podcast_broadcast"),
                tint: LiquidGlassStyle.mint
            )
        }
        .padding(12)
        .background(LiquidGlassPrismBand(tint: LiquidGlassStyle.violet, cornerRadius: 28))
        .padding(.horizontal, padH)
    }

    private func liquidGlassPodcastMetric(
        icon: MonologueIcon.IconType,
        value: String,
        label: String,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                MonologueIcon(icon: icon, size: 15, color: tint, lineWidth: 1.6)

                Text(value)
                    .font(LiquidGlassStyle.titleFont(19, weight: .semibold))
                    .foregroundStyle(LiquidGlassStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Text(label)
                .font(LiquidGlassStyle.labelFont(10.5, weight: .medium))
                .foregroundStyle(LiquidGlassStyle.inkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 11)
        .background(LiquidGlassSurfaceBackground(cornerRadius: 20, elevated: false, pressed: true, role: .list))
    }

    @ViewBuilder
    private func podcastSectionHeader(
        title: String,
        detail: String? = nil,
        destination: PodcastDestination? = nil
    ) -> some View {
        if MangaStyle.isActive {
            HStack(alignment: .center, spacing: 12) {
                MangaSectionMark(kind: .star, tint: MangaStyle.labelYellow)

                Text(title)
                    .font(MangaStyle.titleFont(18, weight: .black))
                    .foregroundStyle(MangaStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer(minLength: 0)

                if let destination {
                    NavigationLink(value: destination) {
                        MangaLabel(text: String(localized: "view_all"), tint: MangaStyle.decoBlue, small: true)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, padH)
        } else if PetWhiteStyle.isActive {
            HStack(alignment: .center, spacing: 10) {
                PetWhiteIconBadge(icon: .podcast, tint: PetWhiteStyle.mint, size: 34)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(PetWhiteStyle.titleFont(18, weight: .black))
                        .foregroundStyle(PetWhiteStyle.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    if let detail, !detail.isEmpty {
                        Text(detail)
                            .font(PetWhiteStyle.labelFont(11, weight: .semibold))
                            .foregroundStyle(PetWhiteStyle.inkSoft)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                if let destination {
                    NavigationLink(value: destination) {
                        HStack(spacing: 4) {
                            Text(String(localized: "view_all"))
                                .font(PetWhiteStyle.labelFont(11, weight: .black))
                            PetWhitePackIcon(icon: .chevronRight, size: 15, visualScale: 1.05)
                        }
                        .foregroundStyle(PetWhiteStyle.ink)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(PetWhiteStyle.surfaceRaised)
                                .overlay(Capsule(style: .continuous).stroke(PetWhiteStyle.separator, lineWidth: 1))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, padH)
        } else if MujiStyle.isActive {
            HStack(alignment: .bottom, spacing: 14) {
                MujiSectionTitle(title: title, detail: detail)

                Spacer(minLength: 0)

                if let destination {
                    NavigationLink(value: destination) {
                        MujiPill(text: String(localized: "view_all"), tint: MujiStyle.tea)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, padH)
        } else if NeumorphicStyle.isActive {
            HStack(alignment: .center, spacing: 12) {
                NeumorphicIconBadge(icon: .podcast, tint: NeumorphicStyle.warm, size: 34)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(NeumorphicStyle.titleFont(18, weight: .semibold))
                        .foregroundStyle(NeumorphicStyle.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    if let detail, !detail.isEmpty {
                        Text(detail)
                            .font(NeumorphicStyle.labelFont(11, weight: .medium))
                            .foregroundStyle(NeumorphicStyle.inkMuted)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                if let destination {
                    NavigationLink(value: destination) {
                        NeumorphicPill(text: String(localized: "view_all"), tint: NeumorphicStyle.accent, icon: .chevronRight, selected: true, compact: true)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, padH)
        } else if SequoiaStyle.isActive {
            HStack(alignment: .center, spacing: 10) {
                SequoiaIconBadge(icon: .podcast, tint: SequoiaStyle.aqua, size: 32)

                Text(title)
                    .font(SequoiaStyle.titleFont(17, weight: .semibold))
                    .foregroundStyle(SequoiaStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .layoutPriority(1)

                Spacer(minLength: 8)

                if let destination {
                    NavigationLink(value: destination) {
                        SequoiaPill(
                            text: String(localized: "view_all"),
                            icon: .chevronRight,
                            tint: SequoiaStyle.accent,
                            selected: true,
                            compact: true
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, padH)
        } else if LiquidGlassStyle.isActive {
            HStack(alignment: .center, spacing: 10) {
                LiquidGlassDropletMark(tint: LiquidGlassStyle.violet)
                    .frame(width: 22, height: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(LiquidGlassStyle.titleFont(18, weight: .semibold))
                        .foregroundStyle(LiquidGlassStyle.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    if let detail, !detail.isEmpty {
                        Text(detail)
                            .font(LiquidGlassStyle.labelFont(11, weight: .regular))
                            .foregroundStyle(LiquidGlassStyle.inkMuted)
                            .lineLimit(1)
                    }
                }
                .layoutPriority(1)

                Spacer(minLength: 8)

                if let destination {
                    NavigationLink(value: destination) {
                        LiquidGlassPill(
                            text: String(localized: "view_all"),
                            icon: .chevronRight,
                            tint: LiquidGlassStyle.violet,
                            selected: true,
                            compact: true
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, padH)
        } else {
            HStack {
                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.monologueTextPrimary)

                Spacer()

                if let destination {
                    NavigationLink(value: destination) {
                        HStack(spacing: 4) {
                            Text("mv_more_section")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                            MonologueIcon(icon: .chevronRight, size: 12, color: .monologueTextSecondary, lineWidth: 1.2)
                        }
                        .foregroundColor(.monologueTextSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, padH)
        }
    }

    private var bannerSection: some View {
        HomeBannerSection(
            banners: viewModel.djBanners,
            onTap: handleBannerTap
        )
    }

    /// 处理 DJ Banner 点击 — 根据 targetType 跳转
    private func handleBannerTap(_ banner: Banner) {
        HapticStyle.light.trigger()
        switch banner.targetType {
        case 1:
            Task {
                do {
                    let songs = try await APIService.shared.fetchSongDetails(ids: [banner.targetId]).async()
                    if let song = songs.first {
                        await MainActor.run {
                            PlayerManager.shared.play(song: song, in: [song])
                        }
                    }
                } catch {
                    AppLogger.error("Banner 歌曲加载失败: \(error)")
                }
            }
        case 60001:
            // DJ 节目 — 通过节目详情获取所属电台 ID
            Task {
                do {
                    let response = try await APIService.shared.ncm.djProgramDetail(id: banner.targetId)
                    if let program = response.body["program"] as? [String: Any],
                       let radio = program["radio"] as? [String: Any],
                       let rid = radio["id"] as? Int
                    {
                        await MainActor.run {
                            radioIdToOpen = rid
                        }
                    }
                } catch {
                    AppLogger.error("Banner 节目详情加载失败: \(error)")
                }
            }
        default:
            if banner.targetId > 0 {
                radioIdToOpen = banner.targetId
            } else if let urlStr = banner.url, let url = URL(string: urlStr) {
                bannerWebURL = url
            }
        }
    }

    // MARK: - 分类标签

    private var categoriesSection: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 10) {
                NavigationLink(value: PodcastDestination.categoryBrowse) {
                    if MangaStyle.isActive {
                        HStack(spacing: 6) {
                            MonologueIcon(icon: .gridSquare, size: 15, color: MangaStyle.strokeInk, lineWidth: 1.8)
                            Text(String(localized: "podcast_all"))
                                .font(MangaStyle.labelFont(12, weight: .black))
                        }
                        .foregroundStyle(MangaStyle.strokeInk)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(MangaStyle.labelYellow))
                        .overlay(Capsule().stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.fineStrokeWidth))
                        .background(Capsule().fill(MangaStyle.strokeInk).offset(x: 2, y: 2))
                    } else if PetWhiteStyle.isActive {
                        petWhiteCategoryPill(
                            title: String(localized: "podcast_all"),
                            icon: .gridSquare,
                            tint: PetWhiteStyle.dogOrange,
                            selected: true
                        )
                    } else if MujiStyle.isActive {
                        MujiActionPill(
                            title: String(localized: "podcast_all"),
                            icon: .gridSquare,
                            selected: true,
                            tint: MujiStyle.clay
                        )
                    } else if NeumorphicStyle.isActive {
                        NeumorphicPill(
                            text: String(localized: "podcast_all"),
                            tint: NeumorphicStyle.accent,
                            icon: .gridSquare,
                            selected: true
                        )
                    } else if SequoiaStyle.isActive {
                        SequoiaPill(
                            text: String(localized: "podcast_all"),
                            icon: .gridSquare,
                            tint: SequoiaStyle.accent,
                            selected: true
                        )
                    } else if LiquidGlassStyle.isActive {
                        LiquidGlassPill(
                            text: String(localized: "podcast_all"),
                            icon: .gridSquare,
                            tint: LiquidGlassStyle.violet,
                            selected: true
                        )
                    } else {
                        HStack(spacing: 6) {
                            MonologueIcon(icon: .gridSquare, size: 16, color: .monologueIconForeground, lineWidth: 1.4)
                            Text("podcast_all")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.monologueIconForeground)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.monologueIconBackground))
                    }
                }
                .buttonStyle(MonologueBouncingButtonStyle())

                ForEach(viewModel.categories) { cat in
                    NavigationLink(value: PodcastDestination.category(cat)) {
                        if MangaStyle.isActive {
                            HStack(spacing: 6) {
                                MonologueIcon(icon: cat.monologueIconType, size: 16, color: MangaStyle.ink, lineWidth: 1.8)
                                Text(cat.name)
                                    .font(MangaStyle.labelFont(12, weight: .bold))
                            }
                            .foregroundStyle(MangaStyle.ink)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(MangaStyle.bubbleWhite))
                            .overlay(Capsule().stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.fineStrokeWidth))
                        } else if PetWhiteStyle.isActive {
                            petWhiteCategoryPill(
                                title: cat.name,
                                icon: cat.monologueIconType,
                                tint: PetWhiteStyle.mint
                            )
                        } else if MujiStyle.isActive {
                            MujiActionPill(
                                title: cat.name,
                                icon: cat.monologueIconType,
                                tint: MujiStyle.tea
                            )
                        } else if NeumorphicStyle.isActive {
                        NeumorphicPill(
                            text: cat.name,
                            tint: NeumorphicStyle.sage,
                            icon: cat.monologueIconType
                        )
                    } else if SequoiaStyle.isActive {
                        SequoiaPill(
                            text: cat.name,
                            icon: cat.monologueIconType,
                            tint: SequoiaStyle.aqua
                        )
                    } else if LiquidGlassStyle.isActive {
                        LiquidGlassPill(
                            text: cat.name,
                            icon: cat.monologueIconType,
                            tint: LiquidGlassStyle.cyan
                        )
                    } else {
                        HStack(spacing: 6) {
                            MonologueIcon(icon: cat.monologueIconType, size: 18, color: .monologueTextPrimary, lineWidth: 1.4)
                                Text(cat.name)
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundColor(.monologueTextPrimary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(Color.monologueGlassTint))
                        }
                    }
                    .buttonStyle(MonologueBouncingButtonStyle())
                    .scrollTransition(.animated(.spring(response: 0.35))) { content, phase in
                        content
                            .scaleEffect(phase.isIdentity ? 1 : 0.93)
                            .opacity(phase.isIdentity ? 1 : 0.5)
                    }
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, padH)
        }
        .scrollTargetBehavior(.viewAligned(limitBehavior: .never))
        .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
    }

    private func petWhiteCategoryPill(
        title: String,
        icon: MonologueIcon.IconType,
        tint: Color,
        selected: Bool = false
    ) -> some View {
        HStack(spacing: 7) {
            PetWhitePackIcon(icon: icon, size: selected ? 17 : 16, visualScale: 1.04)

            Text(title)
                .font(PetWhiteStyle.labelFont(12, weight: .black))
                .foregroundStyle(PetWhiteStyle.ink)
                .lineLimit(1)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .background(
            Capsule(style: .continuous)
                .fill(selected ? tint : PetWhiteStyle.surfaceRaised)
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(selected ? PetWhiteStyle.stroke : PetWhiteStyle.separator, lineWidth: selected ? 1.4 : 1)
                )
        )
    }

    // MARK: - 布局常量

    private var padH: CGFloat {
        DeviceLayout.viewHorizontalPadding
    }

    private var compactCardSize: CGFloat {
        DeviceLayout.isPad ? 170 : 130
    }

    private var broadcastCardSize: CGFloat {
        DeviceLayout.isPad ? 160 : 120
    }

    // MARK: - 为你推荐（自适应网格）

    private var personalizedSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            podcastSectionHeader(
                title: String(localized: "podcast_for_you"),
                destination: PodcastDestination.topList(String(localized: "podcast_hot_radios"), .hot)
            )

            let columns: [GridItem] = DeviceLayout.isPad
                ? Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)
                : [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

            LazyVGrid(columns: columns, spacing: DeviceLayout.isPad ? 16 : 14) {
                ForEach(viewModel.personalizedRadios) { radio in
                    Button {
                        HapticStyle.light.trigger()
                        radioIdToOpen = radio.id
                    } label: {
                        radioGridCard(radio: radio)
                    }
                    .buttonStyle(MonologueBouncingButtonStyle())
                }
            }
            .padding(.horizontal, padH)
        }
    }

    // MARK: - 今日优选

    private var todayPerferedSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            podcastSectionHeader(
                title: String(localized: "podcast_today_pick"),
                destination: PodcastDestination.topList(String(localized: "podcast_today_pick"), .hot)
            )

            ScrollView(.horizontal) {
                LazyHStack(spacing: 14) {
                    ForEach(viewModel.todayPerfered) { radio in
                        Button {
                            HapticStyle.light.trigger()
                            radioIdToOpen = radio.id
                        } label: {
                            todayPickCard(radio: radio)
                        }
                        .buttonStyle(MonologueBouncingButtonStyle())
                        .scrollTransition(.animated(.spring(response: 0.35))) { content, phase in
                            content
                                .scaleEffect(phase.isIdentity ? 1 : 0.93)
                                .opacity(phase.isIdentity ? 1 : 0.5)
                                .offset(y: phase.isIdentity ? 0 : phase.value * 8)
                        }
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, padH)
            }
            .scrollTargetBehavior(.viewAligned(limitBehavior: .never))
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
    }

    private func todayPickCard(radio: RadioStation) -> AnyView {
        if PetWhiteStyle.isActive {
            return AnyView(petWhiteTodayPickCard(radio: radio))
        }

        let cardWidth: CGFloat = DeviceLayout.isPad ? 340 : 280
        let cardHeight: CGFloat = DeviceLayout.isPad ? 110 : 96
        let cr: CGFloat = MangaStyle.isActive ? 12 : (MujiStyle.isActive ? 10 : ((NeumorphicStyle.isActive || SequoiaStyle.isActive) ? 18 : (DeviceLayout.isPad ? 18 : 16)))
        let titleFont: Font
        if MangaStyle.isActive {
            titleFont = MangaStyle.bodyFont(15, weight: .black)
        } else if MujiStyle.isActive {
            titleFont = MujiStyle.bodyFont(15, weight: .regular)
        } else if NeumorphicStyle.isActive {
            titleFont = NeumorphicStyle.bodyFont(15, weight: .semibold)
        } else if SequoiaStyle.isActive {
            titleFont = SequoiaStyle.bodyFont(15, weight: .semibold)
        } else {
            titleFont = .system(size: 15, weight: .semibold, design: .rounded)
        }

        let subtitleFont: Font
        if MangaStyle.isActive {
            subtitleFont = MangaStyle.bodyFont(12, weight: .bold)
        } else if MujiStyle.isActive {
            subtitleFont = MujiStyle.labelFont(12, weight: .regular)
        } else if NeumorphicStyle.isActive {
            subtitleFont = NeumorphicStyle.labelFont(12, weight: .medium)
        } else if SequoiaStyle.isActive {
            subtitleFont = SequoiaStyle.labelFont(12, weight: .regular)
        } else {
            subtitleFont = .system(size: 12, design: .rounded)
        }

        let metadataFont: Font = SequoiaStyle.isActive
            ? SequoiaStyle.labelFont(11, weight: .regular)
            : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(11, weight: .medium) : .system(size: 11, design: .rounded))
        let primaryColor: Color = SequoiaStyle.isActive ? SequoiaStyle.ink : (NeumorphicStyle.isActive ? NeumorphicStyle.ink : .monologueTextPrimary)
        let secondaryColor: Color = SequoiaStyle.isActive ? SequoiaStyle.inkSoft : (NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : .monologueTextSecondary)
        let placeholderFill: Color = SequoiaStyle.isActive ? SequoiaStyle.materialList : (NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.monologueGlassTint)
        let playForeground: Color = (NeumorphicStyle.isActive || SequoiaStyle.isActive) ? (SequoiaStyle.isActive ? SequoiaStyle.onAccent : Color(light: .white, dark: .black)) : .monologueIconForeground
        let playBackground: Color = SequoiaStyle.isActive ? SequoiaStyle.accent : (NeumorphicStyle.isActive ? NeumorphicStyle.accent : Color.monologueIconBackground)
        let cardFill: Color = SequoiaStyle.isActive ? .clear : (NeumorphicStyle.isActive ? NeumorphicStyle.surface : Color.monologueGlassTint)

        return AnyView(HStack(spacing: 0) {
            CachedAsyncImage(url: radio.coverUrl) {
                RoundedRectangle(cornerRadius: 0)
                    .fill(placeholderFill)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: cardHeight, height: cardHeight)
            .clipped()

            VStack(alignment: .leading, spacing: 6) {
                Text(radio.name)
                    .font(titleFont)
                    .foregroundColor(primaryColor)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if let dj = radio.dj?.nickname {
                    Text(dj)
                        .font(subtitleFont)
                        .foregroundColor(secondaryColor)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                HStack(spacing: 6) {
                    if let count = radio.programCount, count > 0 {
                        Text(String(format: String(localized: "podcast_episode_count"), count))
                            .font(metadataFont)
                            .foregroundColor(secondaryColor)
                    }
                    Spacer()
                    MonologueIcon(icon: .play, size: 12, color: playForeground, lineWidth: 2)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(playBackground))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: cardWidth, height: cardHeight)
        .background(cardFill)
        .clipShape(RoundedRectangle(cornerRadius: cr, style: .continuous))
        .themedPageSurface(cornerRadius: cr, elevated: false))
    }

    private func petWhiteTodayPickCard(radio: RadioStation) -> some View {
        HStack(spacing: 12) {
            CachedAsyncImage(url: radio.coverUrl) {
                PetWhiteMascotMark(kind: .dog, size: 52)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(PetWhiteStyle.surfacePressed)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: DeviceLayout.isPad ? 92 : 82, height: DeviceLayout.isPad ? 92 : 82)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(PetWhiteStyle.stroke, lineWidth: 1.4)
            )

            VStack(alignment: .leading, spacing: 6) {
                PetWhitePill(text: "PICK", tint: PetWhiteStyle.butter)

                Text(radio.name)
                    .font(PetWhiteStyle.titleFont(16, weight: .black))
                    .foregroundStyle(PetWhiteStyle.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(radio.dj?.nickname ?? radio.category ?? " ")
                    .font(PetWhiteStyle.labelFont(11, weight: .semibold))
                    .foregroundStyle(PetWhiteStyle.inkSoft)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            PetWhitePackIcon(icon: .play, size: 18, visualScale: 1.08)
                .frame(width: 34, height: 34)
                .background(PetWhiteStyle.dogOrange, in: Circle())
                .overlay(Circle().stroke(PetWhiteStyle.stroke, lineWidth: 1.2))
        }
        .padding(12)
        .frame(width: DeviceLayout.isPad ? 348 : 292, height: DeviceLayout.isPad ? 116 : 106)
        .background(PetWhiteSurfaceBackground(cornerRadius: 26, elevated: true, tint: PetWhiteStyle.surfaceRaised, accent: PetWhiteStyle.butter))
    }

    // MARK: - 精选电台（列表）

    private var recommendSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            podcastSectionHeader(
                title: String(localized: "podcast_featured"),
                destination: PodcastDestination.topList(String(localized: "podcast_featured"), .toplist)
            )

            VStack(spacing: 0) {
                ForEach(Array(viewModel.recommendRadios.enumerated()), id: \.element.id) { index, radio in
                    Button {
                        HapticStyle.light.trigger()
                        radioIdToOpen = radio.id
                    } label: {
                        radioListRow(radio: radio)
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))

                    if index < viewModel.recommendRadios.count - 1 {
                        Divider()
                            .foregroundColor(.monologueSeparator)
                            .padding(.leading, padH + (DeviceLayout.isPad ? 86 : 76))
                            .padding(.trailing, padH)
                    }
                }
            }
        }
    }

    // MARK: - 上新佳作

    private var newestSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            podcastSectionHeader(title: String(localized: "上新佳作"))

            ScrollView(.horizontal) {
                LazyHStack(spacing: 14) {
                    ForEach(Array(viewModel.newestPrograms.enumerated()), id: \.offset) { _, program in
                        Button {
                            HapticStyle.light.trigger()
                            if let radioId = program.creativeExtInfoVO?.djProgram?.radio?.id {
                                radioIdToOpen = radioId
                            } else if let radioId = program.creativeExtInfoVO?.radio?.id {
                                radioIdToOpen = radioId
                            }
                        } label: {
                            creativeCompactCard(creative: program)
                        }
                        .buttonStyle(MonologueBouncingButtonStyle())
                        .scrollTransition(.animated(.spring(response: 0.35))) { content, phase in
                            content
                                .scaleEffect(phase.isIdentity ? 1 : 0.93)
                                .opacity(phase.isIdentity ? 1 : 0.8)
                        }
                    }
                }
                .padding(.horizontal, padH)
            }
            .themeRenderScrollLayer()
            .scrollTargetBehavior(.viewAligned)
            .scrollClipDisabled()
        }
    }

    // MARK: - 音乐播客榜

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            podcastSectionHeader(title: String(localized: "音乐播客榜"))

            ScrollView(.horizontal) {
                LazyHStack(spacing: 14) {
                    ForEach(Array(viewModel.chartPrograms.enumerated()), id: \.offset) { index, program in
                        Button {
                            HapticStyle.light.trigger()
                            if let radioId = program.creativeExtInfoVO?.djProgram?.radio?.id {
                                radioIdToOpen = radioId
                            } else if let radioId = program.creativeExtInfoVO?.radio?.id {
                                radioIdToOpen = radioId
                            }
                        } label: {
                            creativeCompactCard(creative: program, rank: index + 1)
                        }
                        .buttonStyle(MonologueBouncingButtonStyle())
                        .scrollTransition(.animated(.spring(response: 0.35))) { content, phase in
                            content
                                .scaleEffect(phase.isIdentity ? 1 : 0.93)
                                .opacity(phase.isIdentity ? 1 : 0.8)
                        }
                    }
                }
                .padding(.horizontal, padH)
            }
            .themeRenderScrollLayer()
            .scrollTargetBehavior(.viewAligned)
            .scrollClipDisabled()
        }
    }

    private func creativeCompactCard(creative: PodcastCreative, rank: Int? = nil) -> AnyView {
        if PetWhiteStyle.isActive {
            return AnyView(petWhiteCreativeCompactCard(creative: creative, rank: rank))
        }

        let s = compactCardSize
        let cr: CGFloat = MangaStyle.isActive ? 10 : (MujiStyle.isActive ? 8 : ((NeumorphicStyle.isActive || SequoiaStyle.isActive) ? 16 : (DeviceLayout.isPad ? 18 : 16)))

        let title = creative.uiElement?.mainTitle?.title ?? creative.creativeExtInfoVO?.djProgram?.name ?? "(无标题)"
        let subTitle = creative.creativeExtInfoVO?.djProgram?.radio?.name ?? creative.creativeExtInfoVO?.djProgram?.dj?.nickname ?? " "
        var coverUrl: URL? = nil
        if let urlStr = creative.uiElement?.image?.imageUrl {
            coverUrl = URL(string: urlStr)
        } else if let urlStr = creative.creativeExtInfoVO?.djProgram?.coverUrl {
            coverUrl = URL(string: urlStr)
        } else if let urlStr = creative.creativeExtInfoVO?.djProgram?.mainSong?.coverUrl?.absoluteString {
            coverUrl = URL(string: urlStr)
        }

        let placeholderFill: Color = SequoiaStyle.isActive ? SequoiaStyle.materialList : (NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.monologueGlassTint)
        let titleFont: Font
        if MangaStyle.isActive {
            titleFont = MangaStyle.bodyFont(DeviceLayout.isPad ? 14 : 13, weight: .black)
        } else if MujiStyle.isActive {
            titleFont = MujiStyle.bodyFont(DeviceLayout.isPad ? 14 : 13, weight: .regular)
        } else if NeumorphicStyle.isActive {
            titleFont = NeumorphicStyle.bodyFont(DeviceLayout.isPad ? 14 : 13, weight: .semibold)
        } else if SequoiaStyle.isActive {
            titleFont = SequoiaStyle.bodyFont(DeviceLayout.isPad ? 14 : 13, weight: .semibold)
        } else {
            titleFont = .system(size: DeviceLayout.isPad ? 14 : 13, weight: .medium, design: .rounded)
        }
        let subtitleFont: Font
        if MangaStyle.isActive {
            subtitleFont = MangaStyle.bodyFont(DeviceLayout.isPad ? 12 : 11, weight: .bold)
        } else if MujiStyle.isActive {
            subtitleFont = MujiStyle.labelFont(DeviceLayout.isPad ? 12 : 11, weight: .regular)
        } else if NeumorphicStyle.isActive {
            subtitleFont = NeumorphicStyle.labelFont(DeviceLayout.isPad ? 12 : 11, weight: .medium)
        } else if SequoiaStyle.isActive {
            subtitleFont = SequoiaStyle.labelFont(DeviceLayout.isPad ? 12 : 11, weight: .regular)
        } else {
            subtitleFont = .system(size: DeviceLayout.isPad ? 12 : 11, design: .rounded)
        }
        let titleColor: Color = SequoiaStyle.isActive ? SequoiaStyle.ink : (NeumorphicStyle.isActive ? NeumorphicStyle.ink : .monologueTextPrimary)
        let subtitleColor: Color = SequoiaStyle.isActive ? SequoiaStyle.inkSoft : (NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : .monologueTextSecondary)
        let isRankTop = (rank ?? 4) <= 3
        let rankForeground: Color = SequoiaStyle.isActive
            ? (isRankTop ? SequoiaStyle.onAccent : SequoiaStyle.ink)
            : (isRankTop ? .monologueIconForeground : .monologueTextPrimary)
        let rankBackground: Color = SequoiaStyle.isActive
            ? (isRankTop ? SequoiaStyle.accent : SequoiaStyle.materialList)
            : (isRankTop ? Color.monologueIconBackground : Color.monologueGlassTint)

        return AnyView(VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                CachedAsyncImage(url: coverUrl) {
                    RoundedRectangle(cornerRadius: cr)
                        .fill(placeholderFill)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: s, height: s)
                .clipShape(RoundedRectangle(cornerRadius: cr, style: .continuous))

                if let rank = rank {
                    Text("\(rank)")
                        .font(SequoiaStyle.isActive ? SequoiaStyle.labelFont(12, weight: .semibold) : .system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundColor(rankForeground)
                        .frame(width: 26, height: 26)
                        .background(
                            Circle().fill(NeumorphicStyle.isActive ? (rank <= 3 ? NeumorphicStyle.accent : NeumorphicStyle.surfacePressed) : rankBackground)
                        )
                        .monologueGlassCircle()
                        .padding(8)
                }
            }

            Text(title)
                .font(titleFont)
                .foregroundColor(titleColor)
                .lineLimit(2)
                .frame(width: s, height: 34, alignment: .topLeading)

            Text(subTitle)
                .font(subtitleFont)
                .foregroundColor(subtitleColor)
                .lineLimit(1)
                .frame(width: s, alignment: .leading)
        }
        .frame(width: s)
        .padding(ThemedPageStyle.isActive ? 8 : 0)
        .background {
            if MangaStyle.isActive {
                MangaCardBackground(cornerRadius: 12)
            } else if MujiStyle.isActive {
                MujiPaperCardBackground(cornerRadius: 10)
            } else if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(cornerRadius: 18, elevated: true)
            } else if SequoiaStyle.isActive {
                SequoiaSurfaceBackground(cornerRadius: 18, elevated: false, role: .list)
            }
        })
    }

    private func petWhiteCreativeCompactCard(creative: PodcastCreative, rank: Int? = nil) -> some View {
        let s = compactCardSize
        let title = creative.uiElement?.mainTitle?.title ?? creative.creativeExtInfoVO?.djProgram?.name ?? "Paw Pick"
        let subTitle = creative.creativeExtInfoVO?.djProgram?.radio?.name ?? creative.creativeExtInfoVO?.djProgram?.dj?.nickname ?? " "
        let coverUrl: URL? = {
            if let urlStr = creative.uiElement?.image?.imageUrl {
                return URL(string: urlStr)
            }
            if let urlStr = creative.creativeExtInfoVO?.djProgram?.coverUrl {
                return URL(string: urlStr)
            }
            if let urlStr = creative.creativeExtInfoVO?.djProgram?.mainSong?.coverUrl?.absoluteString {
                return URL(string: urlStr)
            }
            return nil
        }()

        return VStack(alignment: .leading, spacing: 8) {
            CachedAsyncImage(url: coverUrl) {
                PetWhiteMascotMark(kind: rank.map { $0.isMultiple(of: 2) ? .cat : .dog } ?? .pair, size: 50)
                    .frame(width: s, height: s)
                    .background(PetWhiteStyle.surfacePressed)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: s, height: s)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(PetWhiteStyle.stroke, lineWidth: 1.4)
            )
            .overlay(alignment: .topTrailing) {
                if let rank {
                    Text("\(rank)")
                        .font(PetWhiteStyle.labelFont(11, weight: .black))
                        .foregroundStyle(PetWhiteStyle.ink)
                        .frame(width: 24, height: 24)
                        .background(PetWhiteStyle.butter, in: Circle())
                        .overlay(Circle().stroke(PetWhiteStyle.stroke, lineWidth: 1.1))
                        .padding(8)
                }
            }

            Text(title)
                .font(PetWhiteStyle.bodyFont(DeviceLayout.isPad ? 14 : 13, weight: .black))
                .foregroundStyle(PetWhiteStyle.ink)
                .lineLimit(2)
                .frame(width: s, height: 34, alignment: .topLeading)

            Text(subTitle)
                .font(PetWhiteStyle.labelFont(11, weight: .semibold))
                .foregroundStyle(PetWhiteStyle.inkSoft)
                .lineLimit(1)
                .frame(width: s, alignment: .leading)
        }
        .frame(width: s)
        .padding(9)
        .background(PetWhiteSurfaceBackground(cornerRadius: 26, elevated: true, tint: PetWhiteStyle.surfaceRaised, accent: rank.map { $0 <= 3 ? PetWhiteStyle.dogOrange : PetWhiteStyle.sky } ?? PetWhiteStyle.mint))
    }

    // MARK: - 新人电台榜

    private var newcomerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            podcastSectionHeader(
                title: String(localized: "podcast_newcomer"),
                destination: PodcastDestination.topList(String(localized: "podcast_newcomer"), .toplist)
            )

            ScrollView(.horizontal) {
                LazyHStack(spacing: 14) {
                    ForEach(Array(viewModel.newcomerRadios.enumerated()), id: \.element.id) { index, radio in
                        Button {
                            HapticStyle.light.trigger()
                            radioIdToOpen = radio.id
                        } label: {
                            rankedCompactCard(radio: radio, rank: index + 1)
                        }
                        .buttonStyle(MonologueBouncingButtonStyle())
                        .scrollTransition(.animated(.spring(response: 0.35))) { content, phase in
                            content
                                .scaleEffect(phase.isIdentity ? 1 : 0.93)
                                .opacity(phase.isIdentity ? 1 : 0.5)
                                .offset(y: phase.isIdentity ? 0 : phase.value * 8)
                        }
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, padH)
            }
            .scrollTargetBehavior(.viewAligned(limitBehavior: .never))
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
    }

    private func rankedCompactCard(radio: RadioStation, rank: Int) -> AnyView {
        if PetWhiteStyle.isActive {
            return AnyView(petWhiteRankedCompactCard(radio: radio, rank: rank))
        }

        let s = compactCardSize
        let cr: CGFloat = MangaStyle.isActive ? 10 : (MujiStyle.isActive ? 8 : ((NeumorphicStyle.isActive || SequoiaStyle.isActive) ? 16 : (DeviceLayout.isPad ? 18 : 16)))
        let placeholderFill: Color = SequoiaStyle.isActive ? SequoiaStyle.materialList : (NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.monologueGlassTint)
        let titleFont: Font = SequoiaStyle.isActive
            ? SequoiaStyle.bodyFont(DeviceLayout.isPad ? 14 : 13, weight: .semibold)
            : (MangaStyle.isActive ? MangaStyle.bodyFont(DeviceLayout.isPad ? 14 : 13, weight: .black) : (MujiStyle.isActive ? MujiStyle.bodyFont(DeviceLayout.isPad ? 14 : 13, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.bodyFont(DeviceLayout.isPad ? 14 : 13, weight: .semibold) : .system(size: DeviceLayout.isPad ? 14 : 13, weight: .medium, design: .rounded))))
        let subtitleFont: Font = SequoiaStyle.isActive
            ? SequoiaStyle.labelFont(DeviceLayout.isPad ? 12 : 11, weight: .regular)
            : (MangaStyle.isActive ? MangaStyle.bodyFont(DeviceLayout.isPad ? 12 : 11, weight: .bold) : (MujiStyle.isActive ? MujiStyle.labelFont(DeviceLayout.isPad ? 12 : 11, weight: .regular) : .system(size: DeviceLayout.isPad ? 12 : 11, design: .rounded)))
        let titleColor: Color = SequoiaStyle.isActive ? SequoiaStyle.ink : (NeumorphicStyle.isActive ? NeumorphicStyle.ink : .monologueTextPrimary)
        let subtitleColor: Color = SequoiaStyle.isActive ? SequoiaStyle.inkSoft : (NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : .monologueTextSecondary)
        let rankForeground: Color = SequoiaStyle.isActive ? (rank <= 3 ? SequoiaStyle.onAccent : SequoiaStyle.ink) : (rank <= 3 ? .monologueIconForeground : .monologueTextPrimary)
        let rankBackground: Color = SequoiaStyle.isActive ? (rank <= 3 ? SequoiaStyle.accent : SequoiaStyle.materialList) : (rank <= 3 ? Color.monologueIconBackground : Color.monologueGlassTint)
        return AnyView(VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                CachedAsyncImage(url: radio.coverUrl) {
                    RoundedRectangle(cornerRadius: cr)
                        .fill(placeholderFill)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: s, height: s)
                .clipShape(RoundedRectangle(cornerRadius: cr, style: .continuous))

                Text("\(rank)")
                    .font(SequoiaStyle.isActive ? SequoiaStyle.labelFont(12, weight: .semibold) : .system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundColor(rankForeground)
                    .frame(width: 26, height: 26)
                    .background(
                        Circle().fill(NeumorphicStyle.isActive ? (rank <= 3 ? NeumorphicStyle.accent : NeumorphicStyle.surfacePressed) : rankBackground)
                    )
                    .monologueGlassCircle()
                    .padding(8)
            }

            Text(radio.name)
                .font(titleFont)
                .foregroundColor(titleColor)
                .lineLimit(2)
                .frame(width: s, height: 34, alignment: .topLeading)

            if let dj = radio.dj?.nickname {
                Text(dj)
                    .font(subtitleFont)
                    .foregroundColor(subtitleColor)
                    .lineLimit(1)
                    .frame(width: s, alignment: .leading)
            } else {
                Text(" ")
                    .font(.system(size: 11, design: .rounded))
                    .frame(width: s, alignment: .leading)
            }
        }
        .frame(width: s)
        .padding(ThemedPageStyle.isActive ? 8 : 0)
        .background {
            if MangaStyle.isActive {
                MangaCardBackground(cornerRadius: 12)
            } else if MujiStyle.isActive {
                MujiPaperCardBackground(cornerRadius: 10)
            } else if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(cornerRadius: 18, elevated: true)
            } else if SequoiaStyle.isActive {
                SequoiaSurfaceBackground(cornerRadius: 18, elevated: false, role: .list)
            }
        })
    }

    private func petWhiteRankedCompactCard(radio: RadioStation, rank: Int) -> some View {
        let size = compactCardSize

        return VStack(alignment: .leading, spacing: 9) {
            ZStack(alignment: .topLeading) {
                CachedAsyncImage(url: radio.coverUrl) {
                    PetWhiteMascotMark(kind: rank.isMultiple(of: 2) ? .cat : .dog, size: 54)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(PetWhiteStyle.surfacePressed)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 23, style: .continuous)
                        .stroke(PetWhiteStyle.stroke, lineWidth: 1.4)
                )

                Text("\(rank)")
                    .font(PetWhiteStyle.labelFont(12, weight: .black))
                    .foregroundStyle(PetWhiteStyle.ink)
                    .frame(width: 28, height: 28)
                    .background(rank <= 3 ? PetWhiteStyle.dogOrange : PetWhiteStyle.surfaceRaised, in: Circle())
                    .overlay(Circle().stroke(PetWhiteStyle.stroke, lineWidth: 1.1))
                    .padding(8)
            }

            Text(radio.name)
                .font(PetWhiteStyle.bodyFont(DeviceLayout.isPad ? 14 : 13, weight: .black))
                .foregroundStyle(PetWhiteStyle.ink)
                .lineLimit(2)
                .frame(width: size, height: 36, alignment: .topLeading)

            Text(radio.dj?.nickname ?? radio.category ?? " ")
                .font(PetWhiteStyle.labelFont(11, weight: .semibold))
                .foregroundStyle(PetWhiteStyle.inkSoft)
                .lineLimit(1)
                .frame(width: size, alignment: .leading)
        }
        .frame(width: size)
        .padding(9)
        .background(PetWhiteSurfaceBackground(cornerRadius: 26, elevated: true, tint: PetWhiteStyle.surfaceRaised, accent: rank <= 3 ? PetWhiteStyle.dogOrange : PetWhiteStyle.sky))
    }

    // MARK: - 节目榜

    private var programToplistSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            podcastSectionHeader(
                title: String(localized: "podcast_program_toplist"),
                destination: PodcastDestination.topList(String(localized: "podcast_program_toplist"), .toplist)
            )

            VStack(spacing: 0) {
                ForEach(Array(viewModel.programToplist.enumerated()), id: \.element.id) { index, program in
                    Button {
                        HapticStyle.light.trigger()
                        if let radioId = program.radio?.id {
                            radioIdToOpen = radioId
                        }
                    } label: {
                        programListRow(program: program, rank: index + 1)
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))

                    if index < viewModel.programToplist.count - 1 {
                        Divider()
                            .foregroundColor(.monologueSeparator)
                            .padding(.leading, padH + 28 + 14 + (DeviceLayout.isPad ? 60 : 50))
                            .padding(.trailing, padH)
                    }
                }
            }
        }
    }

    // MARK: - 网格卡片

    @ViewBuilder
    private func radioGridCard(radio: RadioStation) -> some View {
        if PetWhiteStyle.isActive {
            petWhiteRadioGridCard(radio: radio)
        } else if SequoiaStyle.isActive {
            sequoiaRadioGridCard(radio: radio)
        } else if NeumorphicStyle.isActive {
            neumorphicRadioGridCard(radio: radio)
        } else {
            let cr: CGFloat = MujiStyle.isActive ? 8 : (DeviceLayout.isPad ? 18 : 16)
            let cardPadding: CGFloat = MujiStyle.isActive ? 9 : 0

            VStack(alignment: .leading, spacing: 0) {
                GeometryReader { _ in
                    CachedAsyncImage(url: radio.coverUrl) {
                        RoundedRectangle(cornerRadius: cr)
                            .fill(Color.monologueGlassTint)
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: cr))
                }
                .aspectRatio(1, contentMode: .fit)
                .overlay(
                    LinearGradient(
                        colors: [.clear, .clear, .black.opacity(0.35)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: cr))
                )
                .overlay(alignment: .bottomTrailing) {
                    MonologueIcon(icon: .play, size: 14, color: .white, lineWidth: 2)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.black.opacity(0.15)))
                        .monologueGlassCircle()
                        .padding(8)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(radio.name)
                        .font(MujiStyle.isActive ? MujiStyle.bodyFont(14, weight: .regular) : .system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.monologueTextPrimary)
                        .lineLimit(2, reservesSpace: true)
                        .minimumScaleFactor(0.86)
                        .allowsTightening(true)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, minHeight: 36, alignment: .topLeading)

                    Text(radio.dj?.nickname ?? " ")
                        .font(MujiStyle.isActive ? MujiStyle.labelFont(12, weight: .regular) : .system(size: 12, design: .rounded))
                        .foregroundColor(.monologueTextSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                        .allowsTightening(true)
                }
                .padding(.top, 8)
                .padding(.horizontal, 2)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .padding(cardPadding)
            .background {
                if MujiStyle.isActive {
                    MujiPaperCardBackground(cornerRadius: 11)
                }
            }
        }
    }

    private func petWhiteRadioGridCard(radio: RadioStation) -> some View {
        let coverRadius: CGFloat = DeviceLayout.isPad ? 24 : 22
        let metadata = radio.dj?.nickname ?? radio.category ?? " "

        return VStack(alignment: .leading, spacing: 9) {
            ZStack(alignment: .bottomTrailing) {
                CachedAsyncImage(url: radio.coverUrl) {
                    PetWhiteMascotMark(kind: .cat, size: 58)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(PetWhiteStyle.surfacePressed)
                }
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: coverRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: coverRadius, style: .continuous)
                        .stroke(PetWhiteStyle.stroke, lineWidth: 1.5)
                )

                PetWhitePackIcon(icon: .play, size: 15, visualScale: 1.08)
                    .frame(width: 34, height: 34)
                    .background(PetWhiteStyle.butter, in: Circle())
                    .overlay(Circle().stroke(PetWhiteStyle.stroke, lineWidth: 1.2))
                    .padding(8)
            }
            .aspectRatio(1, contentMode: .fit)

            VStack(alignment: .leading, spacing: 5) {
                Text(radio.name)
                    .font(PetWhiteStyle.bodyFont(DeviceLayout.isPad ? 15 : 14, weight: .black))
                    .foregroundStyle(PetWhiteStyle.ink)
                    .lineLimit(2, reservesSpace: true)
                    .minimumScaleFactor(0.82)

                Text(metadata)
                    .font(PetWhiteStyle.labelFont(11, weight: .semibold))
                    .foregroundStyle(PetWhiteStyle.inkSoft)
                    .lineLimit(1)
            }
        }
        .padding(10)
        .background(PetWhiteSurfaceBackground(cornerRadius: 28, elevated: true, tint: PetWhiteStyle.surfaceRaised, accent: PetWhiteStyle.mint))
    }

    private func sequoiaRadioGridCard(radio: RadioStation) -> some View {
        let outerRadius: CGFloat = DeviceLayout.isPad ? 20 : 18
        let coverRadius: CGFloat = DeviceLayout.isPad ? 16 : 14
        let titleHeight: CGFloat = DeviceLayout.isPad ? 38 : 36
        let metadata = radio.dj?.nickname ?? radio.category ?? " "

        return VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                GeometryReader { proxy in
                    CachedAsyncImage(url: radio.coverUrl) {
                        RoundedRectangle(cornerRadius: coverRadius, style: .continuous)
                            .fill(SequoiaStyle.materialList)
                            .overlay(
                                MonologueIcon(
                                    icon: .podcast,
                                    size: 28,
                                    color: SequoiaStyle.inkMuted.opacity(0.42),
                                    lineWidth: 1.45
                                )
                            )
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipShape(RoundedRectangle(cornerRadius: coverRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: coverRadius, style: .continuous)
                            .stroke(SequoiaStyle.separator.opacity(0.78), lineWidth: 0.6)
                    )
                }

                MonologueIcon(icon: .play, size: 12, color: SequoiaStyle.onAccent, lineWidth: 1.85)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(SequoiaStyle.accent))
                    .shadow(color: SequoiaStyle.accent.opacity(0.18), radius: 8, x: 0, y: 4)
                    .padding(8)
            }
            .aspectRatio(1, contentMode: .fit)

            VStack(alignment: .leading, spacing: 5) {
                Text(radio.name)
                    .font(SequoiaStyle.bodyFont(DeviceLayout.isPad ? 15 : 14, weight: .semibold))
                    .foregroundStyle(SequoiaStyle.ink)
                    .lineLimit(2, reservesSpace: true)
                    .minimumScaleFactor(0.82)
                    .allowsTightening(true)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, minHeight: titleHeight, alignment: .topLeading)

                Text(metadata)
                    .font(SequoiaStyle.labelFont(11, weight: .regular))
                    .foregroundStyle(SequoiaStyle.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.84)
                    .allowsTightening(true)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .padding(8)
        .background(
            SequoiaSurfaceBackground(
                cornerRadius: outerRadius,
                elevated: false,
                role: .list
            )
        )
        .contentShape(RoundedRectangle(cornerRadius: outerRadius, style: .continuous))
        .themeRenderInteractiveLayer()
    }

    private func neumorphicRadioGridCard(radio: RadioStation) -> some View {
        let outerRadius: CGFloat = DeviceLayout.isPad ? 20 : 18
        let coverRadius: CGFloat = DeviceLayout.isPad ? 16 : 14
        let titleHeight: CGFloat = DeviceLayout.isPad ? 45 : 43
        let metadata = radio.dj?.nickname ?? radio.category ?? " "

        return VStack(alignment: .leading, spacing: 7) {
            ZStack(alignment: .bottomTrailing) {
                NeumorphicSurfaceBackground(
                    cornerRadius: coverRadius + 4,
                    elevated: false,
                    pressed: true,
                    tint: NeumorphicStyle.surfacePressed,
                    lightweight: true
                )

                GeometryReader { proxy in
                    let side = max(0, min(proxy.size.width, proxy.size.height) - 9)

                    CachedAsyncImage(url: radio.coverUrl) {
                        RoundedRectangle(cornerRadius: coverRadius, style: .continuous)
                            .fill(NeumorphicStyle.surfacePressed)
                            .overlay(
                                MonologueIcon(
                                    icon: .podcast,
                                    size: 30,
                                    color: NeumorphicStyle.inkMuted.opacity(0.42),
                                    lineWidth: 1.45
                                )
                            )
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: side, height: side)
                    .clipShape(RoundedRectangle(cornerRadius: coverRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: coverRadius, style: .continuous)
                            .stroke(NeumorphicStyle.separator.opacity(0.46), lineWidth: 0.8)
                    )
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                }
                .padding(0)

                MonologueIcon(
                    icon: .play,
                    size: 13,
                    color: Color(light: .white, dark: .black),
                    lineWidth: 2
                )
                .frame(width: 34, height: 34)
                .background(Circle().fill(NeumorphicStyle.accent))
                .shadow(color: NeumorphicStyle.accent.opacity(0.2), radius: 7, x: 0, y: 4)
                .padding(8)
            }
            .aspectRatio(0.96, contentMode: .fit)

            VStack(alignment: .leading, spacing: 5) {
                Text(radio.name)
                    .font(NeumorphicStyle.bodyFont(DeviceLayout.isPad ? 14 : 13, weight: .semibold))
                    .foregroundStyle(NeumorphicStyle.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.74)
                    .allowsTightening(true)
                    .multilineTextAlignment(.leading)
                    .frame(height: titleHeight, alignment: .topLeading)
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                Text(metadata)
                    .font(NeumorphicStyle.labelFont(11, weight: .medium))
                    .foregroundStyle(NeumorphicStyle.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.84)
                    .allowsTightening(true)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .padding(8)
        .background(
            NeumorphicSurfaceBackground(
                cornerRadius: outerRadius,
                elevated: true,
                tint: NeumorphicStyle.surfaceRaised
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
                .stroke(NeumorphicStyle.separator.opacity(0.18), lineWidth: 0.7)
        )
        .contentShape(RoundedRectangle(cornerRadius: outerRadius, style: .continuous))
        .themeRenderInteractiveLayer()
    }

    // MARK: - 列表行

    private func radioListRow(radio: RadioStation) -> AnyView {
        if PetWhiteStyle.isActive {
            return AnyView(petWhiteRadioListRow(radio: radio))
        }

        let rowImg: CGFloat = DeviceLayout.isPad ? 72 : 60
        let themedInset = MujiStyle.isActive || NeumorphicStyle.isActive || SequoiaStyle.isActive
        let cr: CGFloat = MujiStyle.isActive ? 8 : ((NeumorphicStyle.isActive || SequoiaStyle.isActive) ? 16 : 16)
        let placeholderFill: Color = SequoiaStyle.isActive ? SequoiaStyle.materialList : (NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.monologueGlassTint)
        let titleFont: Font
        if MujiStyle.isActive {
            titleFont = MujiStyle.bodyFont(15, weight: .regular)
        } else if NeumorphicStyle.isActive {
            titleFont = NeumorphicStyle.bodyFont(15, weight: .semibold)
        } else if SequoiaStyle.isActive {
            titleFont = SequoiaStyle.bodyFont(15, weight: .semibold)
        } else {
            titleFont = .system(size: 15, weight: .medium, design: .rounded)
        }
        let secondaryFont: Font = SequoiaStyle.isActive ? SequoiaStyle.labelFont(12, weight: .regular) : .system(size: 12, design: .rounded)
        let primaryColor: Color = SequoiaStyle.isActive ? SequoiaStyle.ink : (NeumorphicStyle.isActive ? NeumorphicStyle.ink : .monologueTextPrimary)
        let secondaryColor: Color = SequoiaStyle.isActive ? SequoiaStyle.inkSoft : (NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : .monologueTextSecondary)
        let playForeground: Color = SequoiaStyle.isActive ? SequoiaStyle.onAccent : (NeumorphicStyle.isActive ? Color(light: .white, dark: .black) : .monologueIconForeground)
        let playBackground: Color = SequoiaStyle.isActive ? SequoiaStyle.accent : (NeumorphicStyle.isActive ? NeumorphicStyle.accent : Color.monologueIconBackground)

        return AnyView(HStack(spacing: 14) {
            CachedAsyncImage(url: radio.coverUrl) {
                RoundedRectangle(cornerRadius: cr)
                    .fill(placeholderFill)
            }
            .frame(width: rowImg, height: rowImg)
            .clipShape(RoundedRectangle(cornerRadius: cr, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(radio.name)
                    .font(titleFont)
                    .foregroundColor(primaryColor)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let dj = radio.dj?.nickname {
                        Text(dj)
                            .font(secondaryFont)
                            .foregroundColor(secondaryColor)
                    }
                    if let count = radio.programCount, count > 0 {
                        Text("·")
                            .foregroundColor(secondaryColor)
                        Text(String(format: String(localized: "podcast_episode_count"), count))
                            .font(secondaryFont)
                            .foregroundColor(secondaryColor)
                    }
                }
            }

            Spacer()

            MonologueIcon(icon: .play, size: 12, color: playForeground, lineWidth: 2)
                .frame(width: 30, height: 30)
                .background(Circle().fill(playBackground))
        }
        .padding(.horizontal, themedInset ? 14 : padH)
        .padding(.vertical, themedInset ? 12 : 10)
        .background {
            if MujiStyle.isActive {
                MujiPaperCardBackground(cornerRadius: 10)
            } else if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(cornerRadius: 18, elevated: false)
            } else if SequoiaStyle.isActive {
                SequoiaSurfaceBackground(cornerRadius: 18, elevated: false, role: .list)
            }
        }
        .padding(.horizontal, themedInset ? padH : 0)
        .padding(.vertical, themedInset ? 5 : 0)
        .contentShape(Rectangle()))
    }

    private func petWhiteRadioListRow(radio: RadioStation) -> some View {
        HStack(spacing: 12) {
            CachedAsyncImage(url: radio.coverUrl) {
                PetWhiteMascotMark(kind: .dog, size: 46)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(PetWhiteStyle.surfacePressed)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: DeviceLayout.isPad ? 66 : 58, height: DeviceLayout.isPad ? 66 : 58)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(PetWhiteStyle.stroke, lineWidth: 1.3)
            )

            VStack(alignment: .leading, spacing: 5) {
                Text(radio.name)
                    .font(PetWhiteStyle.bodyFont(15, weight: .black))
                    .foregroundStyle(PetWhiteStyle.ink)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(radio.dj?.nickname ?? radio.category ?? " ")
                        .font(PetWhiteStyle.labelFont(11, weight: .semibold))
                        .foregroundStyle(PetWhiteStyle.inkSoft)
                        .lineLimit(1)

                    if let count = radio.programCount, count > 0 {
                        Text(String(format: String(localized: "podcast_episode_count"), count))
                            .font(PetWhiteStyle.labelFont(11, weight: .semibold))
                            .foregroundStyle(PetWhiteStyle.inkMuted)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 8)

            PetWhitePackIcon(icon: .play, size: 16, visualScale: 1.08)
                .frame(width: 32, height: 32)
                .background(PetWhiteStyle.mint, in: Circle())
                .overlay(Circle().stroke(PetWhiteStyle.stroke, lineWidth: 1.1))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(PetWhiteSurfaceBackground(cornerRadius: 22, elevated: false, tint: PetWhiteStyle.surfaceRaised, accent: PetWhiteStyle.mint))
        .padding(.horizontal, padH)
    }

    // MARK: - 节目榜行

    private func programListRow(program: RadioProgram, rank: Int) -> AnyView {
        if PetWhiteStyle.isActive {
            return AnyView(petWhiteProgramListRow(program: program, rank: rank))
        }

        let isTop3 = rank <= 3
        let coverSize: CGFloat = DeviceLayout.isPad ? 60 : 50
        let themedInset = MujiStyle.isActive || NeumorphicStyle.isActive || SequoiaStyle.isActive
        let cr: CGFloat = MujiStyle.isActive ? 8 : ((NeumorphicStyle.isActive || SequoiaStyle.isActive) ? 15 : 14)
        let placeholderFill: Color = SequoiaStyle.isActive ? SequoiaStyle.materialList : (NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.monologueGlassTint)
        let rankFont: Font = SequoiaStyle.isActive
            ? SequoiaStyle.titleFont(isTop3 ? 19 : 16, weight: .semibold)
            : (NeumorphicStyle.isActive ? NeumorphicStyle.titleFont(isTop3 ? 20 : 16, weight: .semibold) : .system(size: isTop3 ? 20 : 16, weight: .heavy, design: .rounded))
        let titleFont: Font
        if MujiStyle.isActive {
            titleFont = MujiStyle.bodyFont(isTop3 ? 15 : 14, weight: isTop3 ? .medium : .regular)
        } else if NeumorphicStyle.isActive {
            titleFont = NeumorphicStyle.bodyFont(isTop3 ? 15 : 14, weight: isTop3 ? .semibold : .medium)
        } else if SequoiaStyle.isActive {
            titleFont = SequoiaStyle.bodyFont(isTop3 ? 15 : 14, weight: isTop3 ? .semibold : .medium)
        } else {
            titleFont = .system(size: isTop3 ? 15 : 14, weight: isTop3 ? .semibold : .medium, design: .rounded)
        }
        let subtitleFont: Font = SequoiaStyle.isActive ? SequoiaStyle.labelFont(12, weight: .regular) : .system(size: 12, design: .rounded)
        let primaryColor: Color = SequoiaStyle.isActive ? SequoiaStyle.ink : (NeumorphicStyle.isActive ? NeumorphicStyle.ink : .monologueTextPrimary)
        let secondaryColor: Color = SequoiaStyle.isActive ? SequoiaStyle.inkSoft : (NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : .monologueTextSecondary)
        let rankColor: Color = isTop3 ? (SequoiaStyle.isActive ? SequoiaStyle.accent : (NeumorphicStyle.isActive ? NeumorphicStyle.accent : .monologueIconBackground)) : (SequoiaStyle.isActive ? SequoiaStyle.inkMuted : (NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : .monologueTextSecondary))

        return AnyView(HStack(spacing: 14) {
            Text("\(rank)")
                .font(rankFont)
                .foregroundColor(rankColor)
                .frame(width: 28)

            CachedAsyncImage(url: program.programCoverUrl) {
                RoundedRectangle(cornerRadius: cr)
                    .fill(placeholderFill)
            }
            .frame(width: coverSize, height: coverSize)
            .clipShape(RoundedRectangle(cornerRadius: cr, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(program.name ?? "")
                    .font(titleFont)
                    .foregroundColor(primaryColor)
                    .lineLimit(1)

                if let radioName = program.radio?.name {
                    Text(radioName)
                        .font(subtitleFont)
                        .foregroundColor(secondaryColor)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let count = program.listenerCount, count > 0 {
                HStack(spacing: 3) {
                    MonologueIcon(icon: .headphones, size: 11, color: secondaryColor, lineWidth: 1.2)
                    Text(formatCount(count))
                        .font(SequoiaStyle.isActive ? SequoiaStyle.labelFont(11, weight: .regular) : .system(size: 11, design: .rounded))
                        .foregroundColor(secondaryColor)
                }
            }
        }
        .padding(.horizontal, themedInset ? 14 : padH)
        .padding(.vertical, themedInset ? 12 : (isTop3 ? 10 : 8))
        .background {
            if MujiStyle.isActive {
                MujiPaperCardBackground(cornerRadius: 10)
            } else if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(cornerRadius: 18, elevated: isTop3)
            } else if SequoiaStyle.isActive {
                SequoiaSurfaceBackground(cornerRadius: 18, elevated: isTop3, role: isTop3 ? .selected : .list)
            }
        }
        .padding(.horizontal, themedInset ? padH : 0)
        .padding(.vertical, themedInset ? 5 : 0)
        .contentShape(Rectangle()))
    }

    private func petWhiteProgramListRow(program: RadioProgram, rank: Int) -> some View {
        let isTop3 = rank <= 3

        return HStack(spacing: 12) {
            Text("\(rank)")
                .font(PetWhiteStyle.titleFont(isTop3 ? 20 : 16, weight: .black))
                .foregroundStyle(isTop3 ? PetWhiteStyle.dogOrange : PetWhiteStyle.inkMuted)
                .frame(width: 30)

            CachedAsyncImage(url: program.programCoverUrl) {
                PetWhiteMascotMark(kind: isTop3 ? .dog : .cat, size: 42)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(PetWhiteStyle.surfacePressed)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 54, height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(PetWhiteStyle.stroke, lineWidth: 1.2)
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(program.name ?? "")
                    .font(PetWhiteStyle.bodyFont(14, weight: .black))
                    .foregroundStyle(PetWhiteStyle.ink)
                    .lineLimit(1)

                Text(program.radio?.name ?? " ")
                    .font(PetWhiteStyle.labelFont(11, weight: .semibold))
                    .foregroundStyle(PetWhiteStyle.inkSoft)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if let count = program.listenerCount, count > 0 {
                HStack(spacing: 4) {
                    PetWhitePackIcon(icon: .headphones, size: 13, visualScale: 1.04)
                    Text(formatCount(count))
                        .font(PetWhiteStyle.labelFont(11, weight: .black))
                }
                .foregroundStyle(PetWhiteStyle.inkSoft)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .padding(.horizontal, padH)
        .background(PetWhiteSurfaceBackground(cornerRadius: 22, elevated: isTop3, tint: PetWhiteStyle.surfaceRaised, accent: isTop3 ? PetWhiteStyle.butter : PetWhiteStyle.sky))
    }

    // MARK: - 广播电台

    private var broadcastSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            podcastSectionHeader(
                title: String(localized: "podcast_broadcast"),
                destination: .broadcastList
            )

            ScrollView(.horizontal) {
                LazyHStack(spacing: 14) {
                    ForEach(viewModel.broadcastChannels) { channel in
                        Button {
                            HapticStyle.light.trigger()
                            selectedBroadcastChannel = channel
                        } label: {
                            broadcastCard(channel: channel)
                        }
                        .buttonStyle(MonologueBouncingButtonStyle())
                        .scrollTransition(.animated(.spring(response: 0.35))) { content, phase in
                            content
                                .scaleEffect(phase.isIdentity ? 1 : 0.93)
                                .opacity(phase.isIdentity ? 1 : 0.5)
                                .offset(y: phase.isIdentity ? 0 : phase.value * 8)
                        }
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, padH)
            }
            .scrollTargetBehavior(.viewAligned(limitBehavior: .never))
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
    }

    private func broadcastCard(channel: BroadcastChannel) -> some View {
        let bcSize = broadcastCardSize
        let bcCR: CGFloat = MujiStyle.isActive ? 8 : ((NeumorphicStyle.isActive || SequoiaStyle.isActive) ? 18 : (DeviceLayout.isPad ? 18 : 16))
        let placeholderFill: Color = SequoiaStyle.isActive ? SequoiaStyle.materialList : (NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.monologueGlassTint)
        let iconColor: Color = SequoiaStyle.isActive ? SequoiaStyle.aqua : (NeumorphicStyle.isActive ? NeumorphicStyle.sage : .monologueTextSecondary)
        let titleFont: Font = SequoiaStyle.isActive ? SequoiaStyle.bodyFont(DeviceLayout.isPad ? 14 : 13, weight: .semibold) : (MujiStyle.isActive ? MujiStyle.bodyFont(DeviceLayout.isPad ? 14 : 13, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.bodyFont(DeviceLayout.isPad ? 14 : 13, weight: .semibold) : .system(size: DeviceLayout.isPad ? 14 : 13, weight: .medium, design: .rounded)))
        let subtitleFont: Font = SequoiaStyle.isActive ? SequoiaStyle.labelFont(DeviceLayout.isPad ? 12 : 11, weight: .regular) : (MujiStyle.isActive ? MujiStyle.labelFont(DeviceLayout.isPad ? 12 : 11, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(DeviceLayout.isPad ? 12 : 11, weight: .medium) : .system(size: DeviceLayout.isPad ? 12 : 11, design: .rounded)))
        let titleColor: Color = SequoiaStyle.isActive ? SequoiaStyle.ink : (NeumorphicStyle.isActive ? NeumorphicStyle.ink : .monologueTextPrimary)
        let subtitleColor: Color = SequoiaStyle.isActive ? SequoiaStyle.inkSoft : (NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : .monologueTextSecondary)

        return VStack(alignment: .leading, spacing: 8) {
            ZStack {
                if let url = channel.coverImageUrl {
                    CachedAsyncImage(url: url) {
                        RoundedRectangle(cornerRadius: bcCR)
                            .fill(placeholderFill)
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: bcSize, height: bcSize)
                    .clipShape(RoundedRectangle(cornerRadius: bcCR, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: bcCR, style: .continuous)
                        .fill(placeholderFill)
                        .frame(width: bcSize, height: bcSize)
                        .overlay(
                            MonologueIcon(icon: .radio, size: 30, color: iconColor, lineWidth: 1.4)
                        )
                }

                VStack {
                    HStack {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.monologueAccentRed)
                                .frame(width: 6, height: 6)
                            Text("FM")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.black.opacity(0.15)))
                        .monologueGlassCapsule()

                        Spacer()
                    }
                    Spacer()
                }
                .padding(8)
            }
            .frame(width: bcSize, height: bcSize)

            VStack(alignment: .leading, spacing: 4) {
                Text(channel.displayName)
                    .font(titleFont)
                    .foregroundColor(titleColor)
                    .lineLimit(2)
                    .frame(height: DeviceLayout.isPad ? 36 : 34, alignment: .topLeading)

                Text(channel.displayProgram ?? " ")
                    .font(subtitleFont)
                    .foregroundColor(subtitleColor)
                    .lineLimit(1)
            }
        }
        .frame(width: bcSize)
        .padding(MujiStyle.isActive ? 8 : 0)
        .background {
            if MujiStyle.isActive {
                MujiPaperCardBackground(cornerRadius: 10)
            } else if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(cornerRadius: 18, elevated: true)
            } else if SequoiaStyle.isActive {
                SequoiaSurfaceBackground(cornerRadius: 18, elevated: false, role: .list)
            }
        }
    }

    // MARK: - 工具方法

    private func formatCount(_ count: Int) -> String {
        if count >= 100_000_000 {
            return String(format: String(localized: "%.1f亿"), Double(count) / 100_000_000)
        } else if count >= 10000 {
            return String(format: String(localized: "%.1f万"), Double(count) / 10000)
        }
        return "\(count)"
    }
}

private struct PodcastHistorySection: View {
    let onOpenRadio: (Int) -> Void

    @State private var history: [Song]
    @State private var currentSongID: Int?
    @State private var isPlaying: Bool

    private let player = PlayerManager.shared

    init(onOpenRadio: @escaping (Int) -> Void) {
        self.onOpenRadio = onOpenRadio
        _history = State(initialValue: Self.uniqued(PlayerManager.shared.podcastHistory))
        _currentSongID = State(initialValue: PlayerManager.shared.currentSong?.id)
        _isPlaying = State(initialValue: PlayerManager.shared.isPlaying)
    }

    var body: some View {
        Group {
            if !history.isEmpty {
                content
            }
        }
        .onReceive(PlayerManager.shared.$podcastHistory.map { Self.uniqued($0) }) { history in
            self.history = history
        }
        .onReceive(PlayerManager.shared.$currentSong.map { $0?.id }.removeDuplicates()) { currentSongID in
            self.currentSongID = currentSongID
        }
        .onReceive(PlayerManager.shared.$isPlaying.removeDuplicates()) { isPlaying in
            self.isPlaying = isPlaying
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            historyHeader

            ScrollView(.horizontal) {
                HStack(spacing: 14) {
                    ForEach(history.prefix(10)) { song in
                        historyCard(song: song)
                            .scrollTransition(.animated(.spring(response: 0.35))) { content, phase in
                                content
                                    .scaleEffect(phase.isIdentity ? 1 : 0.93)
                                    .opacity(phase.isIdentity ? 1 : 0.5)
                                    .offset(y: phase.isIdentity ? 0 : phase.value * 8)
                            }
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, padH)
            }
            .scrollTargetBehavior(.viewAligned(limitBehavior: .never))
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
    }

    @ViewBuilder
    private var historyHeader: some View {
        if MujiStyle.isActive {
            HStack(alignment: .bottom, spacing: 14) {
                MujiSectionTitle(title: String(localized: "profile_recently_played"))

                Spacer(minLength: 0)

                Button(action: clearHistory) {
                    MujiPill(text: String(localized: "storage_clear"), tint: MujiStyle.red)
                }
                .buttonStyle(.plain)

                NavigationLink(destination: RecentPlayHistoryView(songs: history)) {
                    MujiPill(text: String(localized: "view_all"), tint: MujiStyle.tea)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, padH)
        } else if NeumorphicStyle.isActive {
            HStack(alignment: .center, spacing: 14) {
                NeumorphicSectionTitle(title: String(localized: "profile_recently_played"))

                Spacer(minLength: 0)

                Button(action: clearHistory) {
                    NeumorphicPill(text: String(localized: "storage_clear"), tint: NeumorphicStyle.red, icon: .trash, compact: true)
                }
                .buttonStyle(.plain)

                NavigationLink(destination: RecentPlayHistoryView(songs: history)) {
                    NeumorphicPill(text: String(localized: "view_all"), tint: NeumorphicStyle.accent, icon: .chevronRight, selected: true, compact: true)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, padH)
        } else if SequoiaStyle.isActive {
            HStack(alignment: .center, spacing: 10) {
                SequoiaIconBadge(icon: .history, tint: SequoiaStyle.green, size: 32)

                Text(LocalizedStringKey("profile_recently_played"))
                    .font(SequoiaStyle.titleFont(17, weight: .semibold))
                    .foregroundStyle(SequoiaStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer(minLength: 8)

                Button(action: clearHistory) {
                    SequoiaPill(text: String(localized: "storage_clear"), icon: .trash, tint: SequoiaStyle.red, compact: true)
                }
                .buttonStyle(.plain)

                NavigationLink(destination: RecentPlayHistoryView(songs: history)) {
                    SequoiaPill(text: String(localized: "view_all"), icon: .chevronRight, tint: SequoiaStyle.accent, selected: true, compact: true)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, padH)
        } else {
            HStack {
                Text(LocalizedStringKey("profile_recently_played"))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.monologueTextPrimary)

                Spacer()

                HStack(spacing: 12) {
                    Button(action: clearHistory) {
                        HStack(spacing: 4) {
                            MonologueIcon(icon: .trash, size: 12, color: .monologueTextSecondary, lineWidth: 1.2)
                            Text(LocalizedStringKey("storage_clear"))
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                        }
                        .foregroundColor(.monologueTextSecondary)
                    }
                    .buttonStyle(.plain)

                    NavigationLink(destination: RecentPlayHistoryView(songs: history)) {
                        HStack(spacing: 4) {
                            Text(LocalizedStringKey("view_all"))
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                            MonologueIcon(icon: .chevronRight, size: 12, color: .monologueTextSecondary, lineWidth: 1.2)
                        }
                        .foregroundColor(.monologueTextSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, padH)
        }
    }

    private func historyCard(song: Song) -> some View {
        let cardWidth: CGFloat = DeviceLayout.isPad ? 220 : 180
        let cardHeight: CGFloat = DeviceLayout.isPad ? 64 : 56
        let cr: CGFloat = MujiStyle.isActive ? 8 : ((NeumorphicStyle.isActive || SequoiaStyle.isActive) ? 16 : 12)
        let isCurrent = currentSongID == song.id
        let placeholderFill: Color = SequoiaStyle.isActive ? SequoiaStyle.materialList : (NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.monologueGlassTint)
        let titleFont: Font = SequoiaStyle.isActive ? SequoiaStyle.bodyFont(13, weight: .semibold) : (MujiStyle.isActive ? MujiStyle.bodyFont(13, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.bodyFont(13, weight: .semibold) : .system(size: 13, weight: .bold, design: .rounded)))
        let subtitleFont: Font = SequoiaStyle.isActive ? SequoiaStyle.labelFont(11, weight: .regular) : (MujiStyle.isActive ? MujiStyle.labelFont(11, weight: .regular) : .system(size: 11, design: .rounded))
        let titleColor: Color
        if isCurrent {
            titleColor = SequoiaStyle.isActive ? SequoiaStyle.accent : (NeumorphicStyle.isActive ? NeumorphicStyle.accent : .monologueAccent)
        } else {
            titleColor = SequoiaStyle.isActive ? SequoiaStyle.ink : (NeumorphicStyle.isActive ? NeumorphicStyle.ink : .monologueTextPrimary)
        }
        let subtitleColor: Color = SequoiaStyle.isActive ? SequoiaStyle.inkSoft : (NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : .monologueTextSecondary)
        let cardFill: Color = SequoiaStyle.isActive ? .clear : (NeumorphicStyle.isActive ? NeumorphicStyle.surface : Color.monologueGlassTint)

        return Button {
            HapticStyle.light.trigger()
            let rid = song.podcastRadioId ?? song.album?.id ?? 0
            player.playPodcast(song: song, in: player.podcastHistory, radioId: rid)
            if rid > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    onOpenRadio(rid)
                }
            }
        } label: {
            HStack(spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
                    CachedAsyncImage(url: song.coverUrl) {
                        RoundedRectangle(cornerRadius: cr)
                            .fill(placeholderFill)
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: cardHeight, height: cardHeight)
                    .clipShape(RoundedRectangle(cornerRadius: cr, style: .continuous))

                    if isCurrent {
                        PlayingVisualizerView(isAnimating: isPlaying, color: .white)
                            .frame(width: 10)
                            .padding(4)
                            .background(Circle().fill(.black.opacity(0.4)))
                            .padding(4)
                            .clipShape(Circle())
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(song.name)
                        .font(titleFont)
                        .foregroundColor(titleColor)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    let subtitle = song.podcastRadioName ?? song.ar?.first?.name ?? ""
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(subtitleFont)
                            .foregroundColor(subtitleColor)
                            .lineLimit(1)
                            .multilineTextAlignment(.leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.trailing, 12)
            .frame(width: cardWidth, height: cardHeight)
            .background(cardFill)
            .clipShape(RoundedRectangle(cornerRadius: cr, style: .continuous))
            .themedPageSurface(cornerRadius: cr, elevated: isCurrent)
        }
        .buttonStyle(MonologueBouncingButtonStyle())
    }

    private var padH: CGFloat {
        DeviceLayout.viewHorizontalPadding
    }

    private func clearHistory() {
        HapticStyle.light.trigger()
        player.clearPodcastHistory()
    }

    private static func uniqued(_ songs: [Song]) -> [Song] {
        var seenIds = Set<Int>()
        var result = [Song]()
        for song in songs where !seenIds.contains(song.id) {
            seenIds.insert(song.id)
            result.append(song)
        }
        return result
    }
}
