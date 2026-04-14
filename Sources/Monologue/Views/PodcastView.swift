import SwiftUI

struct PodcastView: View {
    @State private var viewModel = PodcastViewModel()
    @State private var showRadioPlayer = false
    @State private var radioIdToOpen: Int = 0
    @State private var selectedBroadcastChannel: BroadcastChannel?
    @State private var bannerWebURL: URL?
    @ObservedObject private var playerManager = PlayerManager.shared

    enum PodcastDestination: Hashable {
        case category(RadioCategory)
        case radioDetail(Int)
        case search
        case topList(String, TopRadioListView.ListType)
        case categoryBrowse
        case broadcastList

        static func == (lhs: PodcastDestination, rhs: PodcastDestination) -> Bool {
            switch (lhs, rhs) {
            case (.category(let a), .category(let b)): return a == b
            case (.radioDetail(let a), .radioDetail(let b)): return a == b
            case (.search, .search): return true
            case (.topList(let a, _), .topList(let b, _)): return a == b
            case (.categoryBrowse, .categoryBrowse): return true
            case (.broadcastList, .broadcastList): return true
            default: return false
            }
        }

        func hash(into hasher: inout Hasher) {
            switch self {
            case .category(let cat): hasher.combine("category"); hasher.combine(cat)
            case .radioDetail(let id): hasher.combine("radio"); hasher.combine(id)
            case .search: hasher.combine("search")
            case .topList(let title, _): hasher.combine("topList"); hasher.combine(title)
            case .categoryBrowse: hasher.combine("categoryBrowse")
            case .broadcastList: hasher.combine("broadcastList")
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MonologueBackground()

                if viewModel.isLoading && viewModel.personalizedRadios.isEmpty {
                    MonologueLoadingView(text: "LOADING")
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 28) {
                            // 历史记录（如果存在）
                            if !playerManager.podcastHistory.isEmpty {
                                podcastHistorySection
                            }
                            
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
                    .refreshable {
                        viewModel.refreshData()
                    }
                }
            }
            .navigationTitle(LocalizedStringKey("tabbar_podcast"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: PodcastDestination.search) {
                        MonologueIcon(icon: .search, size: 16)
                            .padding(2)
                    }
                }
            }
            .navigationDestination(for: PodcastDestination.self) { destination in
                switch destination {
                case .category(let cat):
                    CategoryRadioView(category: cat)
                case .radioDetail(let radioId):
                    RadioDetailView(radioId: radioId)
                case .search:
                    PodcastSearchView()
                case .topList(let title, let listType):
                    TopRadioListView(title: title, listType: listType)
                case .categoryBrowse:
                    RadioCategoryBrowseView()
                case .broadcastList:
                    BroadcastListView()
                }
            }
        }
        .onAppear {
            if viewModel.personalizedRadios.isEmpty {
                viewModel.fetchData()
            }
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

    // MARK: - DJ Banner 轮播

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
                       let rid = radio["id"] as? Int {
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
            HStack(spacing: 10) {
                NavigationLink(value: PodcastDestination.categoryBrowse) {
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
                .buttonStyle(MonologueBouncingButtonStyle())

                ForEach(viewModel.categories) { cat in
                    NavigationLink(value: PodcastDestination.category(cat)) {
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
    }

    // MARK: - 布局常量

    private var padH: CGFloat { DeviceLayout.viewHorizontalPadding }
    private var compactCardSize: CGFloat { DeviceLayout.isPad ? 170 : 130 }
    private var broadcastCardSize: CGFloat { DeviceLayout.isPad ? 160 : 120 }

    // MARK: - 为你推荐（自适应网格）

    private var personalizedSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("podcast_for_you")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.monologueTextPrimary)

                Spacer()

                NavigationLink(value: PodcastDestination.topList(String(localized: "podcast_hot_radios"), .hot)) {
                    HStack(spacing: 4) {
                        Text("mv_more_section")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                        MonologueIcon(icon: .chevronRight, size: 12, color: .monologueTextSecondary, lineWidth: 1.2)
                    }
                    .foregroundColor(.monologueTextSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, padH)

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
            HStack {
                Text("podcast_today_pick")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.monologueTextPrimary)

                Spacer()

                NavigationLink(value: PodcastDestination.topList(String(localized: "podcast_today_pick"), .hot)) {
                    HStack(spacing: 4) {
                        Text("mv_more_section")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                        MonologueIcon(icon: .chevronRight, size: 12, color: .monologueTextSecondary, lineWidth: 1.2)
                    }
                    .foregroundColor(.monologueTextSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, padH)

            ScrollView(.horizontal) {
                HStack(spacing: 14) {
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
        }
    }

    private func todayPickCard(radio: RadioStation) -> some View {
        let cardWidth: CGFloat = DeviceLayout.isPad ? 340 : 280
        let cardHeight: CGFloat = DeviceLayout.isPad ? 110 : 96
        let cr: CGFloat = DeviceLayout.isPad ? 18 : 16
        return HStack(spacing: 0) {
            CachedAsyncImage(url: radio.coverUrl) {
                RoundedRectangle(cornerRadius: 0)
                    .fill(Color.monologueGlassTint)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: cardHeight, height: cardHeight)
            .clipped()

            VStack(alignment: .leading, spacing: 6) {
                Text(radio.name)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.monologueTextPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if let dj = radio.dj?.nickname {
                    Text(dj)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.monologueTextSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                HStack(spacing: 6) {
                    if let count = radio.programCount, count > 0 {
                        Text(String(format: String(localized: "podcast_episode_count"), count))
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(.monologueTextSecondary)
                    }
                    Spacer()
                    MonologueIcon(icon: .play, size: 12, color: .monologueIconForeground, lineWidth: 2)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.monologueIconBackground))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: cardWidth, height: cardHeight)
        .background(Color.monologueGlassTint)
        .clipShape(RoundedRectangle(cornerRadius: cr, style: .continuous))
        .monologueGlass(cornerRadius: cr)
    }

    // MARK: - 精选电台（列表）

    private var recommendSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("podcast_featured")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.monologueTextPrimary)

                Spacer()

                NavigationLink(value: PodcastDestination.topList(String(localized: "podcast_featured"), .toplist)) {
                    HStack(spacing: 4) {
                        Text("mv_more_section")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                        MonologueIcon(icon: .chevronRight, size: 12, color: .monologueTextSecondary, lineWidth: 1.2)
                    }
                    .foregroundColor(.monologueTextSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, padH)

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

    // MARK: - 新人电台榜

    private var newcomerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("podcast_newcomer")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.monologueTextPrimary)

                Spacer()

                NavigationLink(value: PodcastDestination.topList(String(localized: "podcast_newcomer"), .toplist)) {
                    HStack(spacing: 4) {
                        Text("mv_more_section")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                        MonologueIcon(icon: .chevronRight, size: 12, color: .monologueTextSecondary, lineWidth: 1.2)
                    }
                    .foregroundColor(.monologueTextSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, padH)

            ScrollView(.horizontal) {
                HStack(spacing: 14) {
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
        }
    }

    private func rankedCompactCard(radio: RadioStation, rank: Int) -> some View {
        let s = compactCardSize
        let cr: CGFloat = DeviceLayout.isPad ? 18 : 16
        return VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                CachedAsyncImage(url: radio.coverUrl) {
                    RoundedRectangle(cornerRadius: cr)
                        .fill(Color.monologueGlassTint)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: s, height: s)
                .clipShape(RoundedRectangle(cornerRadius: cr, style: .continuous))

                Text("\(rank)")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundColor(rank <= 3 ? .monologueIconForeground : .monologueTextPrimary)
                    .frame(width: 26, height: 26)
                    .background(
                        Circle().fill(rank <= 3 ? Color.monologueIconBackground : Color.monologueGlassTint)
                    )
                    .monologueGlassCircle()
                    .padding(8)
            }

            Text(radio.name)
                .font(.system(size: DeviceLayout.isPad ? 14 : 13, weight: .medium, design: .rounded))
                .foregroundColor(.monologueTextPrimary)
                .lineLimit(2)
                .frame(width: s, height: 34, alignment: .topLeading)

            if let dj = radio.dj?.nickname {
                Text(dj)
                    .font(.system(size: DeviceLayout.isPad ? 12 : 11, design: .rounded))
                    .foregroundColor(.monologueTextSecondary)
                    .lineLimit(1)
                    .frame(width: s, alignment: .leading)
            } else {
                Text(" ")
                    .font(.system(size: 11, design: .rounded))
                    .frame(width: s, alignment: .leading)
            }
        }
        .frame(width: s)
    }

    // MARK: - 节目榜

    private var programToplistSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("podcast_program_toplist")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.monologueTextPrimary)

                Spacer()

                NavigationLink(value: PodcastDestination.topList(String(localized: "podcast_program_toplist"), .toplist)) {
                    HStack(spacing: 4) {
                        Text("mv_more_section")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                        MonologueIcon(icon: .chevronRight, size: 12, color: .monologueTextSecondary, lineWidth: 1.2)
                    }
                    .foregroundColor(.monologueTextSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, padH)

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

    private func radioGridCard(radio: RadioStation) -> some View {
        let cr: CGFloat = DeviceLayout.isPad ? 18 : 16
        return VStack(alignment: .leading, spacing: 0) {
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
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.monologueTextPrimary)
                    .lineLimit(2)
                    .frame(height: 36, alignment: .topLeading)

                Text(radio.dj?.nickname ?? " ")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.monologueTextSecondary)
                    .lineLimit(1)
            }
            .padding(.top, 8)
            .padding(.horizontal, 2)
        }
    }

    // MARK: - 列表行

    private func radioListRow(radio: RadioStation) -> some View {
        let rowImg: CGFloat = DeviceLayout.isPad ? 72 : 60
        let cr: CGFloat = 16
        return HStack(spacing: 14) {
            CachedAsyncImage(url: radio.coverUrl) {
                RoundedRectangle(cornerRadius: cr)
                    .fill(Color.monologueGlassTint)
            }
            .frame(width: rowImg, height: rowImg)
            .clipShape(RoundedRectangle(cornerRadius: cr, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(radio.name)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.monologueTextPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let dj = radio.dj?.nickname {
                        Text(dj)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.monologueTextSecondary)
                    }
                    if let count = radio.programCount, count > 0 {
                        Text("·")
                            .foregroundColor(.monologueTextSecondary)
                        Text(String(format: String(localized: "podcast_episode_count"), count))
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.monologueTextSecondary)
                    }
                }
            }

            Spacer()

            MonologueIcon(icon: .play, size: 12, color: .monologueIconForeground, lineWidth: 2)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Color.monologueIconBackground))
        }
        .padding(.horizontal, padH)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    // MARK: - 节目榜行

    private func programListRow(program: RadioProgram, rank: Int) -> some View {
        let isTop3 = rank <= 3
        let coverSize: CGFloat = DeviceLayout.isPad ? 60 : 50
        let cr: CGFloat = 14
        return HStack(spacing: 14) {
            Text("\(rank)")
                .font(.system(size: isTop3 ? 20 : 16, weight: .heavy, design: .rounded))
                .foregroundColor(isTop3 ? .monologueIconBackground : .monologueTextSecondary)
                .frame(width: 28)

            CachedAsyncImage(url: program.programCoverUrl) {
                RoundedRectangle(cornerRadius: cr)
                    .fill(Color.monologueGlassTint)
            }
            .frame(width: coverSize, height: coverSize)
            .clipShape(RoundedRectangle(cornerRadius: cr, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(program.name ?? "")
                    .font(.system(size: isTop3 ? 15 : 14, weight: isTop3 ? .semibold : .medium, design: .rounded))
                    .foregroundColor(.monologueTextPrimary)
                    .lineLimit(1)

                if let radioName = program.radio?.name {
                    Text(radioName)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.monologueTextSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let count = program.listenerCount, count > 0 {
                HStack(spacing: 3) {
                    MonologueIcon(icon: .headphones, size: 11, color: .monologueTextSecondary, lineWidth: 1.2)
                    Text(formatCount(count))
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.monologueTextSecondary)
                }
            }
        }
        .padding(.horizontal, padH)
        .padding(.vertical, isTop3 ? 10 : 8)
        .contentShape(Rectangle())
    }

    // MARK: - 广播电台
    
    private var podcastHistorySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(LocalizedStringKey("profile_recently_played"))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.monologueTextPrimary)

                Spacer()
                
                NavigationLink(destination: RecentPlayHistoryView(songs: playerManager.podcastHistory)) {
                    HStack(spacing: 4) {
                        Text(LocalizedStringKey("view_all"))
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                        MonologueIcon(icon: .chevronRight, size: 12, color: .monologueTextSecondary, lineWidth: 1.2)
                    }
                    .foregroundColor(.monologueTextSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, padH)

            ScrollView(.horizontal) {
                HStack(spacing: 14) {
                    ForEach(playerManager.podcastHistory.prefix(10)) { song in
                        SongCard(song: song) {
                            playerManager.playPodcast(song: song, in: playerManager.podcastHistory, radioId: song.album?.id ?? 0)
                        }
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
        }
    }

    private var broadcastSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("podcast_broadcast")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.monologueTextPrimary)

                Spacer()

                NavigationLink(value: PodcastDestination.broadcastList) {
                    HStack(spacing: 4) {
                        Text("mv_more_section")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                        MonologueIcon(icon: .chevronRight, size: 12, color: .monologueTextSecondary, lineWidth: 1.2)
                    }
                    .foregroundColor(.monologueTextSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, padH)

            ScrollView(.horizontal) {
                HStack(spacing: 14) {
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
        }
    }

    private func broadcastCard(channel: BroadcastChannel) -> some View {
        let bcSize = broadcastCardSize
        let bcCR: CGFloat = DeviceLayout.isPad ? 18 : 16
        return VStack(alignment: .leading, spacing: 8) {
            ZStack {
                if let url = channel.coverImageUrl {
                    CachedAsyncImage(url: url) {
                        RoundedRectangle(cornerRadius: bcCR)
                            .fill(Color.monologueGlassTint)
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: bcSize, height: bcSize)
                    .clipShape(RoundedRectangle(cornerRadius: bcCR, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: bcCR, style: .continuous)
                        .fill(Color.monologueGlassTint)
                        .frame(width: bcSize, height: bcSize)
                        .overlay(
                            MonologueIcon(icon: .radio, size: 30, color: .monologueTextSecondary, lineWidth: 1.4)
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
                    .font(.system(size: DeviceLayout.isPad ? 14 : 13, weight: .medium, design: .rounded))
                    .foregroundColor(.monologueTextPrimary)
                    .lineLimit(2)
                    .frame(height: DeviceLayout.isPad ? 36 : 34, alignment: .topLeading)

                Text(channel.displayProgram ?? " ")
                    .font(.system(size: DeviceLayout.isPad ? 12 : 11, design: .rounded))
                    .foregroundColor(.monologueTextSecondary)
                    .lineLimit(1)
            }
        }
        .frame(width: bcSize)
    }

    // MARK: - 工具方法

    private func formatCount(_ count: Int) -> String {
        if count >= 100_000_000 {
            return String(format: String(localized: "%.1f亿"), Double(count) / 100_000_000)
        } else if count >= 10_000 {
            return String(format: String(localized: "%.1f万"), Double(count) / 10_000)
        }
        return "\(count)"
    }
}
