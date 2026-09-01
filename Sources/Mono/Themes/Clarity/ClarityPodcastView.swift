import SwiftUI

/// 通透主题独立播客首页。
/// 封面、分类、节目、电台榜与广播均由本页布局，不复用标准播客页骨架。
struct ClarityPodcastView: View {
    @StateObject private var model = PodcastViewModel.shared
    @ObservedObject private var player = PlayerManager.shared

    @State private var radioIDToOpen = 0
    @State private var showsRadioPlayer = false
    @State private var selectedBroadcast: BroadcastChannel?
    @State private var bannerWebURL: URL?

    private enum Destination: Hashable {
        case category(RadioCategory)
        case radio(Int)
        case search
        case categoryBrowse
        case topList(String, TopRadioListView.ListType)
        case broadcastList

        static func == (lhs: Destination, rhs: Destination) -> Bool {
            switch (lhs, rhs) {
            case let (.category(a), .category(b)): a == b
            case let (.radio(a), .radio(b)): a == b
            case (.search, .search), (.categoryBrowse, .categoryBrowse), (.broadcastList, .broadcastList): true
            case let (.topList(a, _), .topList(b, _)): a == b
            default: false
            }
        }

        func hash(into hasher: inout Hasher) {
            switch self {
            case let .category(category):
                hasher.combine("category")
                hasher.combine(category)
            case let .radio(id):
                hasher.combine("radio")
                hasher.combine(id)
            case .search:
                hasher.combine("search")
            case .categoryBrowse:
                hasher.combine("categoryBrowse")
            case let .topList(title, _):
                hasher.combine("topList")
                hasher.combine(title)
            case .broadcastList:
                hasher.combine("broadcastList")
            }
        }
    }

    private enum FeedSection: Hashable {
        case header
        case feature
        case history
        case forYou
        case today
        case featured
        case latest
        case chart
        case newcomer
        case programToplist
        case premium
        case banner
        case broadcast
        case bottomSpacer
    }

    var body: some View {
        GeometryReader { geometry in
            let metrics = LayoutMetrics(width: geometry.size.width, height: geometry.size.height)

            NavigationStack {
                ZStack {
                    ClarityBackdrop()

                    if model.isLoading && !model.hasDisplayableContent {
                        MonoLoadingView(text: "")
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: metrics.sectionSpacing) {
                                ForEach(feedSections, id: \.self) { section in
                                    feedView(for: section, metrics: metrics)
                                }
                            }
                            .frame(maxWidth: metrics.maximumContentWidth)
                            .frame(maxWidth: .infinity)
                            .padding(.top, metrics.topInset)
                            .padding(.bottom, 18)
                        }
                        .scrollIndicators(.hidden)
                        .themeRenderScrollLayer()
                        .refreshable { model.refreshData() }
                    }
                }
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: Destination.self) { destination in
                    destinationView(destination)
                        .clarityDetailChrome()
                }
            }
        }
        .task {
            await model.ensureDataLoadedAfterTabTransition(reason: "clarity podcast")
        }
        .fullScreenCover(isPresented: $showsRadioPlayer, onDismiss: { radioIDToOpen = 0 }) {
            PodcastPlayerView(radioId: radioIDToOpen)
        }
        .fullScreenCover(item: $selectedBroadcast) { channel in
            BroadcastPlayerView(channel: channel)
        }
        .fullScreenCover(item: $bannerWebURL) { url in
            MonoWebView(url: url, title: nil)
        }
        .onChange(of: radioIDToOpen) { _, id in
            if id > 0 { showsRadioPlayer = true }
        }
    }

    // MARK: - Header and feature

    private func header(metrics: LayoutMetrics) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "tabbar_podcast"))
                    .font(ClarityStyle.title(metrics.titleSize, weight: .semibold))
                    .foregroundStyle(ClarityStyle.ink)
                Text(String(localized: "podcast_discover_subtitle"))
                    .font(ClarityStyle.body(metrics.bodySize))
                    .foregroundStyle(ClarityStyle.inkSoft)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            NavigationLink(value: Destination.categoryBrowse) {
                MonoIcon(icon: .gridSquare, size: 16, color: ClarityStyle.ink, lineWidth: 1.5)
                    .frame(width: metrics.headerButton, height: metrics.headerButton)
                    .background(ClarityMembrane(shape: Circle(), strength: .quiet))
            }
            .buttonStyle(ClarityPressStyle())

            NavigationLink(value: Destination.search) {
                MonoIcon(icon: .search, size: 16, color: ClarityStyle.ink, lineWidth: 1.55)
                    .frame(width: metrics.headerButton, height: metrics.headerButton)
                    .background(ClarityMembrane(shape: Circle(), strength: .regular))
            }
            .buttonStyle(ClarityPressStyle())
        }
        .padding(.horizontal, metrics.horizontalInset)
        .monoPageHeaderCollapse()
    }

    private var leadRadio: RadioStation? {
        model.todayPerfered.first
            ?? model.personalizedRadios.first
            ?? model.hotRadios.first
            ?? model.recommendRadios.first
    }

    private var feedSections: [FeedSection] {
        var sections: [FeedSection] = [.header]
        if leadRadio != nil {
            sections.append(.feature)
        }
        sections.append(contentsOf: [
            .history,
            .forYou,
            .today,
            .featured,
            .latest,
            .chart,
            .newcomer,
            .programToplist,
            .premium,
            .banner,
            .broadcast,
            .bottomSpacer,
        ])
        return sections
    }

    private func feedView(for section: FeedSection, metrics: LayoutMetrics) -> AnyView {
        switch section {
        case .header:
            return AnyView(header(metrics: metrics))
        case .feature:
            guard let leadRadio else { return AnyView(EmptyView()) }
            return AnyView(featureShell(leadRadio, metrics: metrics))
        case .history:
            return AnyView(historySection(metrics: metrics))
        case .forYou:
            if !model.rcmdPrograms.isEmpty {
                return AnyView(
                    creativeRail(
                        title: String(localized: "podcast_for_you"),
                        items: model.rcmdPrograms,
                        metrics: metrics
                    )
                )
            }
            return AnyView(
                radioRail(
                    title: String(localized: "podcast_for_you"),
                    radios: model.personalizedRadios,
                    metrics: metrics
                )
            )
        case .today:
            return AnyView(
                radioRail(
                    title: String(localized: "podcast_today_pick"),
                    radios: model.todayPerfered,
                    metrics: metrics
                )
            )
        case .featured:
            return AnyView(
                radioRail(
                    title: String(localized: "podcast_featured"),
                    radios: model.recommendRadios,
                    metrics: metrics
                )
            )
        case .latest:
            return AnyView(
                creativeRail(
                    title: String(localized: "podcast_latest_voices"),
                    items: model.newestPrograms,
                    metrics: metrics
                )
            )
        case .chart:
            return AnyView(creativeChart(metrics: metrics))
        case .newcomer:
            return AnyView(newcomerSection(metrics: metrics))
        case .programToplist:
            return AnyView(programToplist(metrics: metrics))
        case .premium:
            return AnyView(
                radioRail(
                    title: String(localized: "podcast_premium"),
                    radios: model.paygiftRadios,
                    metrics: metrics
                )
            )
        case .banner:
            return AnyView(bannerRail(metrics: metrics))
        case .broadcast:
            return AnyView(broadcastSection(metrics: metrics))
        case .bottomSpacer:
            return AnyView(FloatingBarBottomSpacer())
        }
    }

    private func featureShell(_ radio: RadioStation, metrics: LayoutMetrics) -> some View {
        ClarityShell(cornerRadius: metrics.shellRadius) {
            VStack(spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    // The artwork is flush with the shell. The shell owns the
                    // outer top corners so no second rounded layer can peek out
                    // along the sides or beneath the cover.
                    fillArtwork(url: radio.coverUrl, radius: 0)
                        .frame(height: metrics.heroHeight)

                    LinearGradient(
                        colors: [.clear, Color.black.opacity(0.08), Color.black.opacity(0.76)],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    NavigationLink(value: Destination.radio(radio.id)) {
                        Color.clear
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    HStack(alignment: .bottom, spacing: 14) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(radio.category ?? String(localized: "podcast_today_pick"))
                                .font(ClarityStyle.body(9.5, weight: .semibold))
                                .tracking(0.8)
                                .opacity(0.76)
                            Text(radio.name)
                                .font(ClarityStyle.title(metrics.featureTitleSize, weight: .semibold))
                                .lineLimit(2)
                            if let nickname = radio.dj?.nickname, !nickname.isEmpty {
                                Text(nickname)
                                    .font(ClarityStyle.body(11.5, weight: .medium))
                                    .opacity(0.78)
                                    .lineLimit(1)
                            }
                        }

                        Spacer(minLength: 8)

                        Button { openRadio(radio.id) } label: {
                            MonoIcon(icon: .play, size: 17, color: ClarityStyle.ink, lineWidth: 1.7)
                                .frame(width: 48, height: 48)
                                .background(Circle().fill(Color.white.opacity(0.94)))
                        }
                        .buttonStyle(ClarityPressStyle())
                    }
                    .foregroundStyle(.white)
                    .padding(metrics.heroContentInset)
                }
                .frame(maxWidth: .infinity)
                .frame(height: metrics.heroHeight)
                .clipped()

                categoryStrip(metrics: metrics)
                    .padding(.horizontal, metrics.shellInnerInset)
                    .padding(.bottom, metrics.shellInnerInset)
            }
        }
        .padding(.horizontal, metrics.horizontalInset)
    }

    private func categoryStrip(metrics: LayoutMetrics) -> some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: metrics.categorySpacing) {
                NavigationLink(value: Destination.categoryBrowse) {
                    categoryItem(
                        icon: .gridSquare,
                        title: String(localized: "podcast_all"),
                        metrics: metrics,
                        highlighted: true
                    )
                }
                .buttonStyle(ClarityPressStyle())

                ForEach(model.categories) { category in
                    NavigationLink(value: Destination.category(category)) {
                        categoryItem(
                            icon: category.monoIconType,
                            title: category.name,
                            metrics: metrics,
                            highlighted: false
                        )
                    }
                    .buttonStyle(ClarityPressStyle())
                }
            }
            .padding(.horizontal, 2)
        }
        .scrollIndicators(.hidden)
        .frame(height: metrics.categoryBandHeight)
        .padding(.top, 10)
    }

    private func categoryItem(
        icon: MonoIcon.IconType,
        title: String,
        metrics: LayoutMetrics,
        highlighted: Bool
    ) -> some View {
        VStack(spacing: 6) {
            MonoIcon(
                icon: icon,
                size: 16,
                color: highlighted ? ClarityStyle.onSelection : ClarityStyle.ink,
                lineWidth: 1.45
            )
            .frame(width: metrics.categoryIconSize, height: metrics.categoryIconSize)
            .background {
                if highlighted {
                    ClaritySelectionLens(shape: Circle())
                } else {
                    ClarityMembrane(shape: Circle(), strength: .quiet)
                }
            }

            Text(title)
                .font(ClarityStyle.body(9.5, weight: highlighted ? .semibold : .regular))
                .foregroundStyle(ClarityStyle.inkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(width: metrics.categoryItemWidth)
    }

    // MARK: - History

    @ViewBuilder
    private func historySection(metrics: LayoutMetrics) -> some View {
        let history = uniqueHistory
        if !history.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(String(localized: "profile_recently_played"), metrics: metrics)

                ScrollView(.horizontal) {
                    LazyHStack(spacing: 12) {
                        ForEach(history.prefix(10)) { song in
                            Button {
                                player.play(song: song, in: history)
                            } label: {
                                HStack(spacing: 10) {
                                    ClarityArtwork(url: song.coverUrl, size: 48, radius: 15)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(song.name)
                                            .font(ClarityStyle.body(12.5, weight: .semibold))
                                            .foregroundStyle(ClarityStyle.ink)
                                            .lineLimit(1)
                                        Text(song.artistName)
                                            .font(ClarityStyle.body(10.5))
                                            .foregroundStyle(ClarityStyle.inkFaint)
                                            .lineLimit(1)
                                    }
                                }
                                .frame(width: metrics.historyCardWidth, alignment: .leading)
                                .padding(9)
                                .background(
                                    ClarityMembrane(
                                        shape: RoundedRectangle(cornerRadius: 20, style: .continuous),
                                        strength: .quiet
                                    )
                                )
                            }
                            .buttonStyle(ClarityPressStyle())
                        }
                    }
                    .padding(.horizontal, metrics.horizontalInset)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private var uniqueHistory: [Song] {
        var seen = Set<String>()
        return player.podcastHistory.filter { song in
            let key = "\(song.musicSource.rawValue):\(song.id)"
            return seen.insert(key).inserted
        }
    }

    // MARK: - Radio rails

    @ViewBuilder
    private func radioRail(title: String, radios: [RadioStation], metrics: LayoutMetrics) -> some View {
        if !radios.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(title, metrics: metrics)

                ScrollView(.horizontal) {
                    LazyHStack(spacing: metrics.railSpacing) {
                        ForEach(radios.prefix(12)) { radio in
                            NavigationLink(value: Destination.radio(radio.id)) {
                                radioCard(radio, metrics: metrics)
                            }
                            .buttonStyle(ClarityPressStyle())
                        }
                    }
                    .padding(.horizontal, metrics.horizontalInset)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private func radioCard(_ radio: RadioStation, metrics: LayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            ClarityArtwork(
                url: radio.coverUrl,
                size: metrics.railCardSize,
                radius: metrics.cardRadius
            )
            .overlay(alignment: .bottomTrailing) {
                MonoIcon(icon: .play, size: 12, color: ClarityStyle.ink, lineWidth: 1.65)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.white.opacity(0.9)))
                    .padding(8)
            }

            Text(radio.name)
                .font(ClarityStyle.body(12.5, weight: .semibold))
                .foregroundStyle(ClarityStyle.ink)
                .lineLimit(2, reservesSpace: true)
                .frame(height: 34, alignment: .topLeading)

            Text(radio.dj?.nickname ?? radio.category ?? "")
                .font(ClarityStyle.body(10.5))
                .foregroundStyle(ClarityStyle.inkFaint)
                .lineLimit(1)
        }
        .frame(width: metrics.railCardSize, alignment: .leading)
    }

    // MARK: - Program rails and charts

    @ViewBuilder
    private func creativeRail(title: String, items: [PodcastCreative], metrics: LayoutMetrics) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(title, metrics: metrics)

                ScrollView(.horizontal) {
                    LazyHStack(spacing: metrics.railSpacing) {
                        ForEach(Array(items.prefix(12).enumerated()), id: \.offset) { _, creative in
                            Button {
                                if let id = creativeRadioID(creative) { openRadio(id) }
                            } label: {
                                creativeCard(creative, metrics: metrics)
                            }
                            .buttonStyle(ClarityPressStyle())
                        }
                    }
                    .padding(.horizontal, metrics.horizontalInset)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private func creativeCard(_ creative: PodcastCreative, metrics: LayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            ClarityArtwork(
                url: creativeCoverURL(creative),
                size: metrics.railCardSize,
                radius: metrics.cardRadius
            )

            Text(creativeTitle(creative))
                .font(ClarityStyle.body(12.5, weight: .semibold))
                .foregroundStyle(ClarityStyle.ink)
                .lineLimit(2, reservesSpace: true)
                .frame(height: 34, alignment: .topLeading)

            Text(creativeSubtitle(creative))
                .font(ClarityStyle.body(10.5))
                .foregroundStyle(ClarityStyle.inkFaint)
                .lineLimit(1)
        }
        .frame(width: metrics.railCardSize, alignment: .leading)
    }

    @ViewBuilder
    private func creativeChart(metrics: LayoutMetrics) -> some View {
        if !model.chartPrograms.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(String(localized: "podcast_music_chart"), metrics: metrics)

                ClarityShell(cornerRadius: 28) {
                    VStack(spacing: 0) {
                        ForEach(Array(model.chartPrograms.prefix(5).enumerated()), id: \.offset) { index, creative in
                            Button {
                                if let id = creativeRadioID(creative) { openRadio(id) }
                            } label: {
                                programRow(
                                    rank: index + 1,
                                    cover: creativeCoverURL(creative),
                                    title: creativeTitle(creative),
                                    subtitle: creativeSubtitle(creative),
                                    metrics: metrics
                                )
                            }
                            .buttonStyle(ClarityPressStyle())
                            if index < min(model.chartPrograms.count, 5) - 1 {
                                rowDivider
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .padding(.horizontal, metrics.horizontalInset)
            }
        }
    }

    @ViewBuilder
    private func newcomerSection(metrics: LayoutMetrics) -> some View {
        if !model.newcomerRadios.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(
                    String(localized: "podcast_newcomer"),
                    metrics: metrics,
                    destination: .topList(String(localized: "podcast_newcomer"), .toplist)
                )

                ClarityShell(cornerRadius: 28) {
                    VStack(spacing: 0) {
                        ForEach(Array(model.newcomerRadios.prefix(5).enumerated()), id: \.element.id) { index, radio in
                            NavigationLink(value: Destination.radio(radio.id)) {
                                programRow(
                                    rank: index + 1,
                                    cover: radio.coverUrl,
                                    title: radio.name,
                                    subtitle: radio.dj?.nickname ?? radio.category ?? "",
                                    metrics: metrics
                                )
                            }
                            .buttonStyle(ClarityPressStyle())
                            if index < min(model.newcomerRadios.count, 5) - 1 { rowDivider }
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .padding(.horizontal, metrics.horizontalInset)
            }
        }
    }

    @ViewBuilder
    private func programToplist(metrics: LayoutMetrics) -> some View {
        if !model.programToplist.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(
                    String(localized: "podcast_program_toplist"),
                    metrics: metrics,
                    destination: .topList(String(localized: "podcast_program_toplist"), .toplist)
                )

                ClarityShell(cornerRadius: 28) {
                    VStack(spacing: 0) {
                        ForEach(Array(model.programToplist.prefix(5).enumerated()), id: \.element.id) { index, program in
                            Button {
                                if let id = program.radio?.id { openRadio(id) }
                            } label: {
                                programRow(
                                    rank: index + 1,
                                    cover: program.programCoverUrl,
                                    title: program.name ?? String(localized: "podcast_title"),
                                    subtitle: program.radio?.name ?? program.durationText,
                                    metrics: metrics
                                )
                            }
                            .buttonStyle(ClarityPressStyle())
                            if index < min(model.programToplist.count, 5) - 1 { rowDivider }
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .padding(.horizontal, metrics.horizontalInset)
            }
        }
    }

    private func programRow(
        rank: Int,
        cover: URL?,
        title: String,
        subtitle: String,
        metrics: LayoutMetrics
    ) -> some View {
        HStack(spacing: 11) {
            Text(String(format: "%02d", rank))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(rank <= 3 ? ClarityStyle.accent : ClarityStyle.inkFaint)
                .frame(width: 25)

            ClarityArtwork(url: cover, size: metrics.listArtworkSize, radius: 14)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(ClarityStyle.body(12.5, weight: .semibold))
                    .foregroundStyle(ClarityStyle.ink)
                    .lineLimit(1)
                Text(subtitle)
                    .font(ClarityStyle.body(10.5))
                    .foregroundStyle(ClarityStyle.inkFaint)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)
            MonoIcon(icon: .chevronRight, size: 11, color: ClarityStyle.inkFaint, lineWidth: 1.35)
        }
        .padding(.horizontal, 3)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(ClarityStyle.line)
            .frame(height: 1)
            .padding(.leading, 92)
    }

    // MARK: - Banners and broadcast

    @ViewBuilder
    private func bannerRail(metrics: LayoutMetrics) -> some View {
        if !model.djBanners.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(String(localized: "podcast_discover_more"), metrics: metrics)

                ScrollView(.horizontal) {
                    LazyHStack(spacing: 12) {
                        ForEach(model.djBanners) { banner in
                            Button { handleBannerTap(banner) } label: {
                                ZStack(alignment: .bottomLeading) {
                                    fillArtwork(url: banner.imageUrl, radius: 24)
                                        .frame(width: metrics.bannerWidth, height: metrics.bannerHeight)
                                    LinearGradient(
                                        colors: [.clear, Color.black.opacity(0.56)],
                                        startPoint: .center,
                                        endPoint: .bottom
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                                    Text(banner.typeTitle ?? String(localized: "podcast_title"))
                                        .font(ClarityStyle.body(12, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                        .padding(14)
                                }
                                .frame(width: metrics.bannerWidth, height: metrics.bannerHeight)
                                .clipped()
                            }
                            .buttonStyle(ClarityPressStyle())
                        }
                    }
                    .padding(.horizontal, metrics.horizontalInset)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    @ViewBuilder
    private func broadcastSection(metrics: LayoutMetrics) -> some View {
        if !model.broadcastChannels.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(
                    String(localized: "podcast_broadcast"),
                    metrics: metrics,
                    destination: .broadcastList
                )

                ScrollView(.horizontal) {
                    LazyHStack(spacing: 12) {
                        ForEach(model.broadcastChannels) { channel in
                            Button { selectedBroadcast = channel } label: {
                                VStack(alignment: .leading, spacing: 7) {
                                    ZStack(alignment: .topLeading) {
                                        ClarityArtwork(
                                            url: channel.coverImageUrl,
                                            size: metrics.broadcastCardSize,
                                            radius: metrics.cardRadius
                                        )
                                        Text("FM")
                                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 7)
                                            .frame(height: 22)
                                            .background(Capsule().fill(Color.black.opacity(0.36)))
                                            .padding(8)
                                    }
                                    Text(channel.displayName)
                                        .font(ClarityStyle.body(12.5, weight: .semibold))
                                        .foregroundStyle(ClarityStyle.ink)
                                        .lineLimit(1)
                                    Text(channel.displayProgram ?? "")
                                        .font(ClarityStyle.body(10.5))
                                        .foregroundStyle(ClarityStyle.inkFaint)
                                        .lineLimit(1)
                                }
                                .frame(width: metrics.broadcastCardSize, alignment: .leading)
                            }
                            .buttonStyle(ClarityPressStyle())
                        }
                    }
                    .padding(.horizontal, metrics.horizontalInset)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    // MARK: - Shared helpers

    private func sectionHeader(
        _ title: String,
        metrics: LayoutMetrics,
        destination: Destination? = nil
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .font(ClarityStyle.title(metrics.sectionTitleSize, weight: .semibold))
                .foregroundStyle(ClarityStyle.ink)
            Spacer(minLength: 8)
            if let destination {
                NavigationLink(value: destination) {
                    HStack(spacing: 4) {
                        Text(String(localized: "view_all"))
                            .font(ClarityStyle.body(10.5, weight: .medium))
                        MonoIcon(icon: .chevronRight, size: 9, color: ClarityStyle.inkFaint, lineWidth: 1.3)
                    }
                    .foregroundStyle(ClarityStyle.inkFaint)
                }
                .buttonStyle(ClarityPressStyle())
            }
        }
        .padding(.horizontal, metrics.horizontalInset)
    }

    private func fillArtwork(url: URL?, radius: CGFloat) -> some View {
        CachedAsyncImage(url: url) {
            LinearGradient(
                colors: [ClarityStyle.lilac.opacity(0.62), ClarityStyle.cyan.opacity(0.68)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(MonoIcon(icon: .podcast, size: 30, color: ClarityStyle.inkFaint, lineWidth: 1.35))
        }
        .aspectRatio(contentMode: .fill)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    private func creativeTitle(_ creative: PodcastCreative) -> String {
        creative.uiElement?.mainTitle?.title
            ?? creative.creativeExtInfoVO?.djProgram?.name
            ?? String(localized: "podcast_title")
    }

    private func creativeSubtitle(_ creative: PodcastCreative) -> String {
        creative.creativeExtInfoVO?.djProgram?.radio?.name
            ?? creative.creativeExtInfoVO?.djProgram?.dj?.nickname
            ?? creative.creativeExtInfoVO?.radio?.dj?.nickname
            ?? ""
    }

    private func creativeCoverURL(_ creative: PodcastCreative) -> URL? {
        if let raw = creative.uiElement?.image?.imageUrl { return URL(string: raw) }
        if let raw = creative.creativeExtInfoVO?.djProgram?.coverUrl { return URL(string: raw) }
        return creative.creativeExtInfoVO?.djProgram?.mainSong?.coverUrl
            ?? creative.creativeExtInfoVO?.radio?.coverUrl
    }

    private func creativeRadioID(_ creative: PodcastCreative) -> Int? {
        creative.creativeExtInfoVO?.djProgram?.radio?.id
            ?? creative.creativeExtInfoVO?.radio?.id
    }

    private func openRadio(_ id: Int) {
        guard id > 0 else { return }
        radioIDToOpen = id
    }

    private func handleBannerTap(_ banner: Banner) {
        HapticStyle.light.trigger()
        switch banner.targetType {
        case 1:
            Task {
                if let songs = try? await APIService.shared.fetchSongDetails(ids: [banner.targetId]).async(),
                   let song = songs.first
                {
                    await MainActor.run { player.play(song: song, in: [song]) }
                }
            }
        case 60001:
            Task {
                guard let response = try? await APIService.shared.ncm.djProgramDetail(id: banner.targetId),
                      let program = response.body["program"] as? [String: Any],
                      let radio = program["radio"] as? [String: Any],
                      let id = radio["id"] as? Int else { return }
                await MainActor.run { openRadio(id) }
            }
        default:
            if banner.targetId > 0 {
                openRadio(banner.targetId)
            } else if let raw = banner.url, let url = URL(string: raw) {
                bannerWebURL = url
            }
        }
    }

    @ViewBuilder
    private func destinationView(_ destination: Destination) -> some View {
        switch destination {
        case let .category(category):
            CategoryRadioView(category: category)
        case let .radio(id):
            RadioDetailView(radioId: id)
        case .search:
            PodcastSearchView()
        case .categoryBrowse:
            RadioCategoryBrowseView()
        case let .topList(title, type):
            TopRadioListView(title: title, listType: type)
        case .broadcastList:
            BroadcastListView()
        }
    }
}

private extension ClarityPodcastView {
    struct LayoutMetrics {
        let width: CGFloat
        let height: CGFloat

        var horizontalInset: CGFloat {
            width >= 768 ? 28 : (width <= 360 ? 14 : 16)
        }

        var maximumContentWidth: CGFloat {
            width >= 768 ? 720 : width
        }

        var topInset: CGFloat {
            height <= 700 ? 6 : 10
        }

        var sectionSpacing: CGFloat {
            height <= 700 ? 22 : 26
        }

        var shellInnerInset: CGFloat {
            width <= 360 ? 10 : 12
        }

        var shellRadius: CGFloat {
            width <= 360 ? 28 : 32
        }

        var cardRadius: CGFloat {
            width <= 360 ? 20 : 23
        }

        var titleSize: CGFloat {
            width <= 360 ? 22 : 24
        }

        var bodySize: CGFloat {
            width <= 360 ? 11 : 12
        }

        var sectionTitleSize: CGFloat {
            width <= 360 ? 17 : 18
        }

        var featureTitleSize: CGFloat {
            width <= 360 ? 18 : 21
        }

        var headerButton: CGFloat {
            width <= 360 ? 40 : 44
        }

        var heroContentInset: CGFloat {
            width <= 360 ? 17 : 20
        }

        var heroHeight: CGFloat {
            let contentWidth = min(width, maximumContentWidth) - horizontalInset * 2 - shellInnerInset * 2
            return min(max(contentWidth * 0.64, 210), width >= 768 ? 330 : 286)
        }

        var categorySpacing: CGFloat {
            width <= 360 ? 4 : 7
        }

        var categoryIconSize: CGFloat {
            width <= 360 ? 40 : 44
        }

        var categoryItemWidth: CGFloat {
            width <= 360 ? 55 : 60
        }

        var categoryBandHeight: CGFloat {
            width <= 360 ? 70 : 75
        }

        var railSpacing: CGFloat {
            width <= 360 ? 12 : 14
        }

        var railCardSize: CGFloat {
            min(max((min(width, maximumContentWidth) - horizontalInset * 2) * 0.39, 126), width >= 768 ? 176 : 154)
        }

        var historyCardWidth: CGFloat {
            min(max(width * 0.56, 190), 244)
        }

        var listArtworkSize: CGFloat {
            width <= 360 ? 48 : 52
        }

        var bannerWidth: CGFloat {
            min(max(width * 0.74, 250), 420)
        }

        var bannerHeight: CGFloat {
            bannerWidth * 0.45
        }

        var broadcastCardSize: CGFloat {
            min(max(width * 0.36, 122), 158)
        }
    }
}
