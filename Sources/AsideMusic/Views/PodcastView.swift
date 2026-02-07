import SwiftUI

struct PodcastView: View {
    @StateObject private var viewModel = PodcastViewModel()
    @State private var showRadioPlayer = false
    @State private var radioIdToOpen: Int = 0

    enum PodcastDestination: Hashable {
        case category(RadioCategory)
        case radioDetail(Int)
        case search
        case topList(String, TopRadioListView.ListType)
        case categoryBrowse

        static func == (lhs: PodcastDestination, rhs: PodcastDestination) -> Bool {
            switch (lhs, rhs) {
            case (.category(let a), .category(let b)): return a == b
            case (.radioDetail(let a), .radioDetail(let b)): return a == b
            case (.search, .search): return true
            case (.topList(let a, _), .topList(let b, _)): return a == b
            case (.categoryBrowse, .categoryBrowse): return true
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
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AsideBackground()

                if viewModel.isLoading && viewModel.personalizedRadios.isEmpty {
                    AsideLoadingView(text: "加载中...")
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 28) {
                            headerSection

                            // 分类标签（横向滚动胶囊）
                            if !viewModel.categories.isEmpty {
                                categoriesSection
                            }

                            // 为你推荐（大卡片，2列网格）
                            if !viewModel.personalizedRadios.isEmpty {
                                personalizedSection
                            }

                            // 精选电台（列表样式）
                            if !viewModel.recommendRadios.isEmpty {
                                recommendSection
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
                Text("播客")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.asideTextPrimary)
                Text("发现好声音")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.asideTextSecondary)
            }
            Spacer()

            NavigationLink(value: PodcastDestination.search) {
                AsideIcon(icon: .magnifyingGlass, size: 18, color: .asideTextPrimary, lineWidth: 1.4)
                    .frame(width: 40, height: 40)
                    .background(Color.asideCardBackground)
                    .clipShape(Circle())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 24)
        .padding(.top, DeviceLayout.headerTopPadding)
    }

    // MARK: - 分类标签

    private var categoriesSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // 分类浏览入口
                NavigationLink(value: PodcastDestination.categoryBrowse) {
                    HStack(spacing: 6) {
                        AsideIcon(icon: .gridSquare, size: 16, color: .asideTextPrimary, lineWidth: 1.4)
                        Text("全部")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.asideTextPrimary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.asideCardBackground)
                    .clipShape(Capsule())
                }
                .buttonStyle(ScaleButtonStyle())

                ForEach(viewModel.categories) { cat in
                    NavigationLink(value: PodcastDestination.category(cat)) {
                        HStack(spacing: 6) {
                            // 本地白色图标，浅色模式反色为黑色
                            if let img = UIImage(named: "cat_\(cat.id)") {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 22, height: 22)
                                    .clipShape(Circle())
                                    .modifier(LightModeInvertModifier())
                            } else if let iconUrl = cat.iconUrl {
                                CachedAsyncImage(url: iconUrl) {
                                    Circle().fill(Color.clear)
                                }
                                .frame(width: 22, height: 22)
                                .clipShape(Circle())
                                .modifier(LightModeInvertModifier())
                            }
                            Text(cat.name)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(.asideTextPrimary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.asideCardBackground)
                        .clipShape(Capsule())
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
                Text("为你推荐")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.asideTextPrimary)

                Spacer()

                NavigationLink(value: PodcastDestination.topList("热门电台", .hot)) {
                    HStack(spacing: 4) {
                        Text("更多")
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
                        .onTapGesture {
                            radioIdToOpen = radio.id
                        }
                }
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - 精选电台（列表）

    private var recommendSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("精选电台")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.asideTextPrimary)

                Spacer()

                NavigationLink(value: PodcastDestination.topList("电台排行", .toplist)) {
                    HStack(spacing: 4) {
                        Text("更多")
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
                        .onTapGesture {
                            radioIdToOpen = radio.id
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
                        Text("\(count)期")
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
}
