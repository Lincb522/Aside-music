import SwiftUI

struct PodcastView: View {
    @StateObject private var viewModel = PodcastViewModel()
    @State private var showRadioPlayer = false
    @State private var radioIdToOpen: Int = 0
    @State private var selectedBroadcastChannel: BroadcastChannel?
    @State private var bannerIndex: Int = 0

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
                AsideBackground()

                if viewModel.isLoading && viewModel.personalizedRadios.isEmpty {
                    AsideLoadingView(text: "LOADING")
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 28) {
                            headerSection

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

                            // 付费精品电台
                            if !viewModel.paygiftRadios.isEmpty {
                                paygiftSection
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
                    .refreshable {
                        viewModel.refreshData()
                    }
                }
            }
            .navigationBarHidden(true)
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
            RadioPlayerView(radioId: radioIdToOpen)
        }
        .fullScreenCover(item: $selectedBroadcastChannel) { channel in
            BroadcastPlayerView(channel: channel)
        }
        .onChange(of: radioIdToOpen) { _, newId in
            if newId > 0 {
                showRadioPlayer = true
            }
        }
    }

    // MARK: - 标题栏

    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("podcast_title")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.asideTextPrimary)
                Text("podcast_discover")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.asideTextSecondary)
            }
            Spacer()

            NavigationLink(value: PodcastDestination.search) {
                ZStack {
                    Circle()
                        .fill(Color.asideMilk)
                        .frame(width: 40, height: 40)
                        .glassEffect(.regular, in: .circle)
                    AsideIcon(icon: .magnifyingGlass, size: 18, color: .asideTextPrimary, lineWidth: 1.4)
                }
                .contentShape(Circle())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 24)
        .padding(.top, DeviceLayout.headerTopPadding)
    }

    // MARK: - DJ Banner 轮播

    private var bannerSection: some View {
        TabView(selection: $bannerIndex) {
            ForEach(Array(viewModel.djBanners.enumerated()), id: \.element.id) { index, banner in
                CachedAsyncImage(url: banner.imageUrl) {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.asideCardBackground)
                }
                .aspectRatio(contentMode: .fill)
                .frame(height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 24)
                .tag(index)
                .onTapWithHaptic {
                    if banner.targetId > 0 {
                        radioIdToOpen = banner.targetId
                    }
                }
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .frame(height: 140)
    }

    // MARK: - 分类标签

    private var categoriesSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // 分类浏览入口
                NavigationLink(value: PodcastDestination.categoryBrowse) {
                    HStack(spacing: 6) {
                        AsideIcon(icon: .gridSquare, size: 16, color: .asideTextPrimary, lineWidth: 1.4)
                        Text("podcast_all")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.asideTextPrimary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.asideMilk))
                }
                .buttonStyle(ScaleButtonStyle())

                ForEach(viewModel.categories) { cat in
                    NavigationLink(value: PodcastDestination.category(cat)) {
                        HStack(spacing: 6) {
                            AsideIcon(icon: cat.asideIconType, size: 18, color: .asideTextPrimary, lineWidth: 1.4)
                            Text(cat.name)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(.asideTextPrimary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.asideMilk))
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - 为你推荐（2列网格）

    private var personalizedSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("podcast_for_you")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.asideTextPrimary)

                Spacer()

                NavigationLink(value: PodcastDestination.topList(String(localized: "podcast_hot_radios"), .hot)) {
                    HStack(spacing: 4) {
                        Text("mv_more_section")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                        AsideIcon(icon: .chevronRight, size: 12, color: .asideTextSecondary, lineWidth: 1.2)
                    }
                    .foregroundColor(.asideTextSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)

            let columns = [
                GridItem(.flexible(), spacing: 14),
                GridItem(.flexible(), spacing: 14)
            ]

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(viewModel.personalizedRadios) { radio in
                    radioGridCard(radio: radio)
                        .onTapWithHaptic {
                            radioIdToOpen = radio.id
                        }
                }
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - 今日优选

    private var todayPerferedSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("podcast_today_pick")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.asideTextPrimary)
                .padding(.horizontal, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(viewModel.todayPerfered) { radio in
                        radioCompactCard(radio: radio)
                            .onTapWithHaptic {
                                radioIdToOpen = radio.id
                            }
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }

    // MARK: - 精选电台（列表）

    private var recommendSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("podcast_featured")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.asideTextPrimary)

                Spacer()

                NavigationLink(value: PodcastDestination.topList(String(localized: "podcast_featured"), .toplist)) {
                    HStack(spacing: 4) {
                        Text("mv_more_section")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                        AsideIcon(icon: .chevronRight, size: 12, color: .asideTextSecondary, lineWidth: 1.2)
                    }
                    .foregroundColor(.asideTextSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)

            VStack(spacing: 0) {
                ForEach(viewModel.recommendRadios) { radio in
                    radioListRow(radio: radio)
                        .onTapWithHaptic {
                            radioIdToOpen = radio.id
                        }
                }
            }
        }
    }

    // MARK: - 付费精品电台

    private var paygiftSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("podcast_premium")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.asideTextPrimary)
                .padding(.horizontal, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(viewModel.paygiftRadios) { radio in
                        radioCompactCard(radio: radio)
                            .onTapWithHaptic {
                                radioIdToOpen = radio.id
                            }
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }

    // MARK: - 新人电台榜

    private var newcomerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("podcast_newcomer")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.asideTextPrimary)
                .padding(.horizontal, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(viewModel.newcomerRadios) { radio in
                        radioCompactCard(radio: radio)
                            .onTapWithHaptic {
                                radioIdToOpen = radio.id
                            }
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }

    // MARK: - 节目榜

    private var programToplistSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("podcast_program_toplist")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.asideTextPrimary)
                .padding(.horizontal, 24)

            VStack(spacing: 0) {
                ForEach(Array(viewModel.programToplist.enumerated()), id: \.element.id) { index, program in
                    programListRow(program: program, rank: index + 1)
                        .onTapWithHaptic {
                            if let radioId = program.radio?.id {
                                radioIdToOpen = radioId
                            }
                        }
                }
            }
        }
    }

    // MARK: - 网格卡片

    private func radioGridCard(radio: RadioStation) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 封面
            CachedAsyncImage(url: radio.coverUrl) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.asideCardBackground)
            }
            .aspectRatio(1, contentMode: .fill)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                // 播放按钮叠加
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        AsideIcon(icon: .playCircleFill, size: 30, color: .white, lineWidth: 1.4)
                            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                            .padding(10)
                    }
                }
            )

            // 信息
            VStack(alignment: .leading, spacing: 4) {
                Text(radio.name)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.asideTextPrimary)
                    .lineLimit(2)

                if let dj = radio.dj?.nickname {
                    Text(dj)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.asideTextSecondary)
                        .lineLimit(1)
                }
            }
            .padding(.top, 8)
            .padding(.horizontal, 2)
        }
    }

    // MARK: - 紧凑横滑卡片

    private func radioCompactCard(radio: RadioStation) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            CachedAsyncImage(url: radio.coverUrl) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.asideCardBackground)
            }
            .frame(width: 130, height: 130)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            Text(radio.name)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.asideTextPrimary)
                .lineLimit(2)
                .frame(width: 130, height: 34, alignment: .topLeading)

            if let dj = radio.dj?.nickname {
                Text(dj)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.asideTextSecondary)
                    .lineLimit(1)
                    .frame(width: 130, alignment: .leading)
            } else {
                Text(" ")
                    .font(.system(size: 11, design: .rounded))
                    .frame(width: 130, alignment: .leading)
            }
        }
        .frame(width: 130)
    }

    // MARK: - 列表行

    private func radioListRow(radio: RadioStation) -> some View {
        HStack(spacing: 14) {
            CachedAsyncImage(url: radio.coverUrl) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.asideCardBackground)
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(radio.name)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.asideTextPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let dj = radio.dj?.nickname {
                        Text(dj)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.asideTextSecondary)
                    }
                    if let count = radio.programCount, count > 0 {
                        Text("·")
                            .foregroundColor(.asideTextSecondary)
                        Text(String(format: String(localized: "podcast_episode_count"), count))
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.asideTextSecondary)
                    }
                }
            }

            Spacer()

            AsideIcon(icon: .playCircle, size: 26, color: .asideTextSecondary, lineWidth: 1.4)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    // MARK: - 节目榜行

    private func programListRow(program: RadioProgram, rank: Int) -> some View {
        HStack(spacing: 14) {
            // 排名
            Text("\(rank)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(rank <= 3 ? .asideIconBackground : .asideTextSecondary)
                .frame(width: 28)

            CachedAsyncImage(url: program.programCoverUrl) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.asideCardBackground)
            }
            .frame(width: 50, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(program.name ?? "")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.asideTextPrimary)
                    .lineLimit(1)

                if let radioName = program.radio?.name {
                    Text(radioName)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.asideTextSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let count = program.listenerCount, count > 0 {
                Text(formatCount(count))
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.asideTextSecondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    // MARK: - 广播电台

    private var broadcastSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("podcast_broadcast")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.asideTextPrimary)

                Spacer()

                NavigationLink(value: PodcastDestination.broadcastList) {
                    HStack(spacing: 4) {
                        Text("mv_more_section")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                        AsideIcon(icon: .chevronRight, size: 12, color: .asideTextSecondary, lineWidth: 1.2)
                    }
                    .foregroundColor(.asideTextSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(viewModel.broadcastChannels) { channel in
                        broadcastCard(channel: channel)
                            .onTapWithHaptic {
                                selectedBroadcastChannel = channel
                            }
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }

    private func broadcastCard(channel: BroadcastChannel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 封面
            ZStack {
                if let url = channel.coverImageUrl {
                    CachedAsyncImage(url: url) {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.asideCardBackground)
                    }
                    .aspectRatio(1, contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                } else {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.asideCardBackground)
                        .aspectRatio(1, contentMode: .fill)
                        .overlay(
                            AsideIcon(icon: .radio, size: 30, color: .asideTextSecondary, lineWidth: 1.4)
                        )
                }

                // FM 标识
                VStack {
                    HStack {
                        Text("FM")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.asideAccentBlue.opacity(0.8))
                            .clipShape(Capsule())
                        Spacer()
                    }
                    Spacer()
                }
                .padding(8)
            }
            .frame(width: 120, height: 120)

            // 名称
            Text(channel.displayName)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.asideTextPrimary)
                .lineLimit(2)

            if let program = channel.displayProgram, !program.isEmpty {
                Text(program)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.asideTextSecondary)
                    .lineLimit(1)
            }
        }
        .frame(width: 120)
    }

    // MARK: - 工具方法

    private func formatCount(_ count: Int) -> String {
        if count >= 100_000_000 {
            return String(format: "%.1f亿", Double(count) / 100_000_000)
        } else if count >= 10_000 {
            return String(format: "%.1f万", Double(count) / 10_000)
        }
        return "\(count)"
    }
}
