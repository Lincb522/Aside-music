import Combine
import QQMusicKit
import SwiftUI
import UniformTypeIdentifiers

struct PlaylistSquareView: View {
    @ObservedObject var viewModel: LibraryViewModel
    typealias Theme = PlaylistDetailView.Theme
    @Namespace private var categoryNS

    private struct MosaicRow: Identifiable {
        let id: Int
        let playlists: [Playlist]
        let isWide: Bool
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                MusicSourcePicker(source: $viewModel.squareSource, usesPlatformTint: false)
                Spacer()
            }
            .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
            .padding(.top, 4)
            .onChange(of: viewModel.squareSource) { _, newSource in
                viewModel.fetchSquareForSelectedSource()
            }

            if viewModel.squareSource == .ncm {
                ncmContent
            } else if viewModel.squareSource == .kugou {
                kugouContent
            } else if viewModel.squareSource == .appleMusic {
                appleMusicContent
            } else {
                qqContent
            }
        }
        .background(Color.clear)
    }

    // MARK: - NCM Content

    private var ncmContent: some View {
        VStack(spacing: 0) {
            categoryBar

            ScrollView {
                if viewModel.isLoadingSquare && viewModel.squarePlaylists.isEmpty {
                    LibraryLoadingStateView()
                } else {
                    LazyVStack(spacing: 14) {
                        ForEach(buildRows(from: viewModel.squarePlaylists)) { row in
                            if row.isWide, let playlist = row.playlists.first {
                                NavigationLink(value: LibraryViewModel.NavigationDestination.playlist(playlist)) {
                                    CinematicCard(playlist: playlist, height: 220)
                                }
                                .buttonStyle(CinematicPressStyle())
                                .modifier(CinematicStaggerIn(order: row.id))
                                .onAppear { loadMoreIfLast(playlist) }
                            } else {
                                HStack(spacing: 12) {
                                    ForEach(row.playlists) { p in
                                        NavigationLink(value: LibraryViewModel.NavigationDestination.playlist(p)) {
                                            CinematicCard(playlist: p, height: 175)
                                        }
                                        .buttonStyle(CinematicPressStyle())
                                        .onAppear { loadMoreIfLast(p) }
                                    }
                                }
                                .modifier(CinematicStaggerIn(order: row.id))
                            }
                        }

                        if viewModel.isLoadingMoreSquare && viewModel.hasMoreSquarePlaylists {
                            LibraryInlineLoadingView()
                        }
                        if !viewModel.hasMoreSquarePlaylists && !viewModel.squarePlaylists.isEmpty {
                            NoMoreDataView()
                        }
                    }
                    .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
                    .padding(.top, 8)
                }

                FloatingBarBottomSpacer()
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
            .scrollContentBackground(.hidden)
        }
    }

    // MARK: - Apple Music Content

    private var kugouContent: some View {
        VStack(spacing: 0) {
            kugouCategoryBar

            ScrollView {
                if viewModel.isLoadingKugouSquare && viewModel.kugouSquarePlaylists.isEmpty {
                    LibraryLoadingStateView()
                } else if viewModel.kugouSquarePlaylists.isEmpty {
                    VStack(spacing: 16) {
                        MonoIcon(icon: .musicNoteList, size: 50, color: Theme.secondaryText.opacity(0.5))
                        Text("暂无KCM推荐歌单")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.secondaryText)
                    }
                    .padding(.top, 50)
                } else {
                    LazyVStack(spacing: 14) {
                        ForEach(buildRows(from: viewModel.kugouSquarePlaylists)) { row in
                            if row.isWide, let playlist = row.playlists.first {
                                NavigationLink(value: LibraryViewModel.NavigationDestination.playlist(playlist)) {
                                    CinematicCard(playlist: playlist, height: 220)
                                }
                                .buttonStyle(CinematicPressStyle())
                                .onAppear { loadMoreKugouIfLast(playlist) }
                            } else {
                                HStack(spacing: 12) {
                                    ForEach(row.playlists) { playlist in
                                        NavigationLink(value: LibraryViewModel.NavigationDestination.playlist(playlist)) {
                                            CinematicCard(playlist: playlist, height: 175)
                                        }
                                        .buttonStyle(CinematicPressStyle())
                                        .onAppear { loadMoreKugouIfLast(playlist) }
                                    }
                                }
                            }
                        }
                        if viewModel.isLoadingMoreKugouSquare {
                            LibraryInlineLoadingView()
                        }
                    }
                    .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
                    .padding(.top, 8)
                }
                FloatingBarBottomSpacer()
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
            .scrollContentBackground(.hidden)
        }
        .task { viewModel.fetchKugouSquareData() }
    }

    private var kugouCategoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(viewModel.kugouPlaylistCategories) { category in
                    let selected = viewModel.selectedKugouCategoryID == category.id
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                            viewModel.selectKugouCategory(category)
                        }
                    } label: {
                        Text(category.name)
                            .font(categoryFont(selected: selected))
                            .foregroundColor(categoryForeground(selected: selected, neumorphicTint: MusicSource.kugou.themedBadgeColor))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background {
                                if selected {
                                    Capsule().fill(Color.monoIconBackground)
                                } else {
                                    Capsule().fill(Color.monoGlassTint)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
            .padding(.vertical, 14)
        }
        .themeRenderScrollLayer()
    }

    // MARK: - Apple Music Content

    private var appleMusicContent: some View {
        ScrollView {
            if viewModel.isLoadingAppleMusicSquare && viewModel.appleMusicSquarePlaylists.isEmpty {
                LibraryLoadingStateView()
            } else {
                LazyVStack(spacing: 14) {
                    ForEach(buildRows(from: viewModel.appleMusicSquarePlaylists)) { row in
                        if row.isWide, let playlist = row.playlists.first {
                            NavigationLink(value: LibraryViewModel.NavigationDestination.playlist(playlist)) {
                                CinematicCard(playlist: playlist, height: 220)
                            }
                            .buttonStyle(CinematicPressStyle())
                            .onAppear { loadMoreAppleMusicIfLast(playlist) }
                        } else {
                            HStack(spacing: 14) {
                                ForEach(row.playlists) { playlist in
                                    NavigationLink(value: LibraryViewModel.NavigationDestination.playlist(playlist)) {
                                        CinematicCard(playlist: playlist, height: 175)
                                    }
                                    .buttonStyle(CinematicPressStyle())
                                    .onAppear { loadMoreAppleMusicIfLast(playlist) }
                                }
                            }
                        }
                    }

                    if viewModel.isLoadingMoreAppleMusicSquare {
                        LibraryInlineLoadingView()
                    } else if viewModel.hasMoreAppleMusicSquare && !viewModel.appleMusicSquarePlaylists.isEmpty {
                        loadMoreButton { viewModel.loadMoreAppleMusicSquarePlaylists() }
                    }
                }
                .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
                .padding(.top, 12)
                .padding(.bottom, 120)
            }
        }
        .scrollIndicators(.hidden)
        .themeRenderScrollLayer()
        .task {
            viewModel.fetchAppleMusicSquareData()
        }
    }

    // MARK: - QQ Content

    private var qqContent: some View {
        VStack(spacing: 0) {
            qqCategoryBar

            ScrollView {
                if viewModel.isLoadingQQSquare && viewModel.qqSquarePlaylists.isEmpty {
                    LibraryLoadingStateView()
                } else if viewModel.qqSquarePlaylists.isEmpty {
                    if NeumorphicStyle.isActive {
                        NeumorphicLibraryEmptyState(
                            icon: .musicNoteList,
                            title: String(localized: "暂无QCM推荐歌单"),
                            tint: MusicSource.qqmusic.themedBadgeColor
                        )
                        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                        .padding(.top, 24)
                    } else {
                        VStack(spacing: 16) {
                            MonoIcon(icon: .musicNoteList, size: 50, color: Theme.secondaryText.opacity(0.5))
                            Text("暂无QCM推荐歌单")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(Theme.secondaryText)
                        }
                        .padding(.top, 50)
                    }
                } else {
                    LazyVStack(spacing: 14) {
                        ForEach(buildRows(from: viewModel.qqSquarePlaylists)) { row in
                            if row.isWide, let playlist = row.playlists.first {
                                NavigationLink(value: LibraryViewModel.NavigationDestination.playlist(playlist)) {
                                    CinematicCard(playlist: playlist, height: 220)
                                }
                                .buttonStyle(CinematicPressStyle())
                                .modifier(CinematicStaggerIn(order: row.id))
                                .onAppear { loadMoreQQIfLast(playlist) }
                            } else {
                                HStack(spacing: 12) {
                                    ForEach(row.playlists) { p in
                                        NavigationLink(value: LibraryViewModel.NavigationDestination.playlist(p)) {
                                            CinematicCard(playlist: p, height: 175)
                                        }
                                        .buttonStyle(CinematicPressStyle())
                                        .onAppear { loadMoreQQIfLast(p) }
                                    }
                                }
                                .modifier(CinematicStaggerIn(order: row.id))
                            }
                        }

                        if viewModel.isLoadingMoreQQSquare && viewModel.hasMoreQQSquare {
                            LibraryInlineLoadingView()
                        }
                        if !viewModel.hasMoreQQSquare && !viewModel.qqSquarePlaylists.isEmpty {
                            NoMoreDataView()
                        }
                    }
                    .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
                    .padding(.top, 8)
                }

                FloatingBarBottomSpacer()
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
            .scrollContentBackground(.hidden)
            .refreshable {
                viewModel.refreshQQSquare()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    // MARK: - QQ Category Bar

    private static let hiddenQQCategories: Set<String> = [String(localized: "filter_all"), String(localized: "ai歌单"), String(localized: "私藏"), String(localized: "音乐人在听"), "chill vibes", String(localized: "ai 歌单")]

    private var filteredQQCategories: [(id: Int, name: String)] {
        viewModel.qqPlaylistCategories.filter { !Self.hiddenQQCategories.contains($0.name.lowercased()) }
    }

    private var qqCategoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(filteredQQCategories, id: \.id) { cat in
                    let selected = viewModel.selectedQQCategoryId == cat.id
                    Button {
                        guard !selected else { return }
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                            viewModel.selectQQCategory(id: cat.id, name: cat.name)
                        }
                    } label: {
                        Text(cat.name)
                            .font(categoryFont(selected: selected))
                            .foregroundColor(categoryForeground(selected: selected, neumorphicTint: MusicSource.qqmusic.themedBadgeColor))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background {
                                if NeumorphicStyle.isActive {
                                    NeumorphicSurfaceBackground(
                                        cornerRadius: 16,
                                        elevated: selected,
                                        pressed: !selected,
                                        tint: selected ? MusicSource.qqmusic.themedBadgeColor.opacity(0.16) : NeumorphicStyle.surface,
                                        lightweight: true
                                    )
                                } else if selected, !MujiStyle.isActive {
                                    Capsule()
                                        .fill(Color.monoIconBackground)
                                        .matchedGeometryEffect(id: "qqCatPill", in: categoryNS)
                                }
                            }
                            .background {
                                if !NeumorphicStyle.isActive, !MujiStyle.isActive {
                                    Capsule().fill(selected ? Color.clear : Color.monoGlassTint)
                                }
                            }
                            .overlay(alignment: .bottom) {
                                if MujiStyle.isActive {
                                    Rectangle()
                                        .fill(selected ? MujiStyle.clay : Color.clear)
                                        .frame(width: 18, height: 1.2)
                                        .padding(.bottom, 3)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
            .padding(.vertical, 14)
        }
        .themeRenderScrollLayer()
    }

    // MARK: - Animated Category Selector

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(viewModel.playlistCategories, id: \.idString) { cat in
                    let selected = viewModel.selectedCategory == cat.name
                    Button {
                        guard !selected else { return }
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                            viewModel.selectedCategory = cat.name
                            viewModel.loadSquarePlaylists(cat: cat.name, reset: true)
                        }
                    } label: {
                        Text(cat.name)
                            .font(categoryFont(selected: selected))
                            .foregroundColor(categoryForeground(selected: selected, neumorphicTint: MusicSource.netease.themedBadgeColor))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background {
                                if NeumorphicStyle.isActive {
                                    NeumorphicSurfaceBackground(
                                        cornerRadius: 16,
                                        elevated: selected,
                                        pressed: !selected,
                                        tint: selected ? MusicSource.netease.themedBadgeColor.opacity(0.16) : NeumorphicStyle.surface,
                                        lightweight: true
                                    )
                                } else if selected, !MujiStyle.isActive {
                                    Capsule()
                                        .fill(Color.monoIconBackground)
                                        .matchedGeometryEffect(id: "squareCatPill", in: categoryNS)
                                }
                            }
                            .background {
                                if !NeumorphicStyle.isActive, !MujiStyle.isActive {
                                    Capsule().fill(selected ? Color.clear : Color.monoGlassTint)
                                }
                            }
                            .overlay(alignment: .bottom) {
                                if MujiStyle.isActive {
                                    Rectangle()
                                        .fill(selected ? MujiStyle.clay : Color.clear)
                                        .frame(width: 18, height: 1.2)
                                        .padding(.bottom, 3)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
            .padding(.vertical, 14)
        }
        .themeRenderScrollLayer()
    }

    private func categoryFont(selected: Bool) -> Font {
        if NeumorphicStyle.isActive {
            return NeumorphicStyle.labelFont(12, weight: selected ? .semibold : .medium)
        }
        if MujiStyle.isActive {
            return MujiStyle.labelFont(12, weight: selected ? .semibold : .regular)
        }
        return .system(size: 13, weight: selected ? .semibold : .medium, design: .rounded)
    }

    private func categoryForeground(selected: Bool, neumorphicTint: Color) -> Color {
        if NeumorphicStyle.isActive {
            return selected ? neumorphicTint : NeumorphicStyle.inkSoft
        }
        if MujiStyle.isActive {
            return selected ? MujiStyle.ink : MujiStyle.inkMuted
        }
        return selected ? .monoIconForeground : .monoTextPrimary
    }

    // MARK: - Mosaic Layout (Hero → Duo → Duo → repeat)

    private func buildRows(from items: [Playlist]) -> [MosaicRow] {
        var rows: [MosaicRow] = []
        var i = 0
        while i < items.count {
            if rows.count % 3 == 0 {
                rows.append(.init(id: rows.count, playlists: [items[i]], isWide: true))
                i += 1
            } else if i + 1 < items.count {
                rows.append(.init(id: rows.count, playlists: [items[i], items[i + 1]], isWide: false))
                i += 2
            } else {
                rows.append(.init(id: rows.count, playlists: [items[i]], isWide: true))
                i += 1
            }
        }
        return rows
    }

    private func loadMoreIfLast(_ playlist: Playlist) {
        if playlist.id == viewModel.squarePlaylists.last?.id {
            viewModel.loadMoreSquarePlaylists()
        }
    }

    private func loadMoreQQIfLast(_ playlist: Playlist) {
        if playlist.id == viewModel.qqSquarePlaylists.last?.id {
            viewModel.loadMoreQQSquarePlaylists()
        }
    }

    private func loadMoreAppleMusicIfLast(_ playlist: Playlist) {
        if playlist.id == viewModel.appleMusicSquarePlaylists.last?.id {
            viewModel.loadMoreAppleMusicSquarePlaylists()
        }
    }

    private func loadMoreKugouIfLast(_ playlist: Playlist) {
        if playlist.id == viewModel.kugouSquarePlaylists.last?.id {
            viewModel.loadMoreKugouSquarePlaylists()
        }
    }

    private func loadMoreButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(LocalizedStringKey("查看更多"))
                .font(categoryFont(selected: true))
                .foregroundColor(.monoIconForeground)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background {
                    if NeumorphicStyle.isActive {
                        NeumorphicSurfaceBackground(
                            cornerRadius: 18,
                            elevated: true,
                            tint: MusicSource.appleMusic.themedBadgeColor.opacity(0.14),
                            lightweight: true
                        )
                    } else if MujiStyle.isActive {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(MujiStyle.wash(MujiStyle.clay, strength: 0.82))
                    } else {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.monoIconBackground)
                    }
                }
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.96))
    }
}

// MARK: - Cinematic Full-Bleed Card

struct CinematicCard: View {
    let playlist: Playlist
    let height: CGFloat

    var body: some View {
        if NeumorphicStyle.isActive {
            cardCore
                .padding(8)
                .background(NeumorphicSurfaceBackground(cornerRadius: 26, elevated: true))
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        } else {
            cardCore
                .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
        }
    }

    private var cardCore: some View {
        ZStack(alignment: .bottomLeading) {
            GeometryReader { proxy in
                CachedAsyncImage(
                    url: playlist.coverUrl,
                    width: proxy.size.width,
                    height: height
                ) {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.monoSeparator)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: proxy.size.width, height: height)
                .clipped()
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.3),
                    .init(color: .black.opacity(0.25), location: 0.55),
                    .init(color: .black.opacity(0.82), location: 1.0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack {
                HStack {
                    PlatformBadgeLabel(
                        text: playlist.sourceShortName,
                        source: playlist.source ?? .netease,
                        fontSize: 10
                    )
                    Spacer()
                }
                Spacer()
            }
            .padding(12)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(playlist.name)
                        .font(.system(size: height > 200 ? 18 : 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .shadow(color: .black.opacity(0.5), radius: 4)

                    if let count = playlist.playCount, count > 0 {
                        HStack(spacing: 4) {
                            MonoIcon(icon: .play, size: 8, color: .white.opacity(0.75), lineWidth: 1.8)
                            Text(cinematicFormatCount(count))
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(.white.opacity(0.75))
                    }
                }

                Spacer()

                if height > 200 {
                    MonoIcon(icon: .play, size: 15, color: .white, lineWidth: 2)
                        .padding(13)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

func cinematicFormatCount(_ count: Int) -> String {
    let lang = Locale.current.language.languageCode?.identifier
    if lang == "zh" {
        if count >= 100_000_000 { return String(format: NSLocalizedString("count_hundred_million", comment: ""), Double(count) / 100_000_000) }
        if count >= 10000 { return String(format: NSLocalizedString("count_ten_thousand", comment: ""), Double(count) / 10000) }
    } else {
        if count >= 1_000_000_000 { return String(format: "%.1fB", Double(count) / 1_000_000_000) }
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1000 { return String(format: "%.1fK", Double(count) / 1000) }
    }
    return "\(count)"
}

// MARK: - Staggered Entrance Animation

struct CinematicStaggerIn: ViewModifier {
    let order: Int
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 28)
            .scaleEffect(visible ? 1 : 0.92, anchor: .bottom)
            .onAppear {
                guard !visible else { return }
                let delay = order < 8 ? Double(order) * 0.065 : 0.03
                withAnimation(.spring(response: 0.55, dampingFraction: 0.8).delay(delay)) {
                    visible = true
                }
            }
    }
}

// MARK: - Cinematic Press Style

struct CinematicPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
