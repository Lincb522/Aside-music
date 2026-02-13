import SwiftUI
import Combine

// MARK: - ViewModel

@MainActor
class DailyRecommendViewModel: ObservableObject {
    @Published var songs: [Song] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    @Published var historyDates: [String] = []
    @Published var showHistorySheet = false
    @Published var isLoadingHistory = false

    @Published var showStyleMenu = false

    private var cancellables = Set<AnyCancellable>()
    private let api = APIService.shared
    private let styleManager = StyleManager.shared

    init() {
        refreshContent()

        styleManager.$currentStyle
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] style in
                AppLogger.debug("DailyRecommendViewModel - Style changed to: \(style?.finalName ?? "Default")")
                self?.refreshContent()
            }
            .store(in: &cancellables)
    }

    func refreshContent() {
        if let style = styleManager.currentStyle {
            loadStyleSongs(style: style)
        } else {
            loadStandardRecommend()
        }
    }

    func loadStandardRecommend() {
        isLoading = true
        errorMessage = nil

        api.fetchDailySongs(cachePolicy: .staleWhileRevalidate, ttl: 3600)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                    self?.isLoading = false
                }
            }, receiveValue: { [weak self] songs in
                self?.songs = songs
                self?.isLoading = false
            })
            .store(in: &cancellables)
    }

    private func loadStyleSongs(style: APIService.StyleTag) {
        isLoading = true
        errorMessage = nil

        AppLogger.debug("Loading songs for style: \(style.finalName) (ID: \(style.finalId))")
        api.fetchStyleSongs(tagId: style.finalId)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    AppLogger.error("Style Songs Error: \(error)")
                    self?.errorMessage = "Songs Error: \(error.localizedDescription)"
                    self?.isLoading = false
                }
            }, receiveValue: { [weak self] songs in
                AppLogger.debug("Received \(songs.count) songs for style \(style.finalName)")
                self?.songs = songs
                self?.isLoading = false
            })
            .store(in: &cancellables)
    }

    @Published var noHistoryMessage: String?

    func loadHistoryDates() {
        isLoadingHistory = true
        noHistoryMessage = nil
        AppLogger.debug("Loading history recommend dates...")
        api.fetchHistoryRecommendDates()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoadingHistory = false
                if case .failure(let error) = completion {
                    AppLogger.error("History dates load error: \(error)")
                    self?.noHistoryMessage = "加载失败，请稍后重试"
                }
            }, receiveValue: { [weak self] dates in
                AppLogger.debug("Received history dates: \(dates)")
                self?.historyDates = dates
                self?.isLoadingHistory = false
                if !dates.isEmpty {
                    AppLogger.debug("Setting showHistorySheet = true")
                    self?.showHistorySheet = true
                    AppLogger.debug("showHistorySheet is now: \(self?.showHistorySheet ?? false)")
                } else {
                    AppLogger.debug("History dates is empty")
                    self?.noHistoryMessage = "暂无历史推荐记录，明天再来看看吧"
                }
            })
            .store(in: &cancellables)
    }
}

// MARK: - View

struct DailyRecommendView: View {
    @StateObject private var viewModel = DailyRecommendViewModel()
    @ObservedObject private var styleManager = StyleManager.shared
    @Namespace private var animationNamespace
    @State private var selectedArtistId: Int?
    @State private var showArtistDetail = false
    @State private var selectedSongForDetail: Song?
    @State private var showSongDetail = false
    @State private var selectedAlbumId: Int?
    @State private var showAlbumDetail = false

    typealias Theme = PlaylistDetailView.Theme

    var body: some View {
        ZStack(alignment: .top) {
            AsideBackground()

            mainContent

            Group {
                if viewModel.showStyleMenu {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                viewModel.showStyleMenu = false
                            }
                        }
                        .zIndex(1)
                }

                if viewModel.showStyleMenu {
                    StyleSelectionMorphView(
                        styleManager: styleManager,
                        isPresented: $viewModel.showStyleMenu,
                        namespace: animationNamespace
                    )
                    .zIndex(2)
                }
            }
        }
        .sheet(isPresented: $viewModel.showHistorySheet) {
            DailyHistoryView(dates: viewModel.historyDates)
        }
        .alert("历史推荐", isPresented: Binding(
            get: { viewModel.noHistoryMessage != nil },
            set: { if !$0 { viewModel.noHistoryMessage = nil } }
        )) {
            Button("好的", role: .cancel) {
                viewModel.noHistoryMessage = nil
            }
        } message: {
            Text(viewModel.noHistoryMessage ?? "")
        }
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $showArtistDetail) {
            if let artistId = selectedArtistId {
                ArtistDetailView(artistId: artistId)
            }
        }
        .navigationDestination(isPresented: $showSongDetail) {
            if let song = selectedSongForDetail {
                SongDetailView(song: song)
            }
        }
        .navigationDestination(isPresented: $showAlbumDetail) {
            if let albumId = selectedAlbumId {
                AlbumDetailView(albumId: albumId, albumName: nil, albumCoverUrl: nil)
            }
        }
        .onChange(of: viewModel.showStyleMenu) { _, isShown in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                PlayerManager.shared.isTabBarHidden = isShown
            }
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            headerSection

            if viewModel.isLoading && viewModel.songs.isEmpty {
                Spacer()
                VStack {
                    AsideLoadingView(text: "LOADING...")
                }
                Spacer()
            } else if let error = viewModel.errorMessage {
                errorView(msg: error)
            } else {
                songList
            }
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                AsideBackButton()
                Spacer()
            }

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text(dayString)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.text)

                        Text("/ \(monthString)")
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.secondaryText)
                            .padding(.bottom, 4)
                    }

                    if !viewModel.showStyleMenu {
                        HStack(spacing: 10) {
                            Button(action: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    viewModel.showStyleMenu = true
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Text(styleManager.currentStyle == nil ? "每日推荐" : styleManager.currentStyleName)
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundColor(Theme.secondaryText)
                                        .matchedGeometryEffect(id: "filter_text", in: animationNamespace)

                                    AsideIcon(icon: .chevronRight, size: 12, color: Theme.secondaryText)
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.asideSeparator)
                                        .matchedGeometryEffect(id: "filter_bg", in: animationNamespace)
                                )
                            }

                            Button(action: {
                                viewModel.loadHistoryDates()
                            }) {
                                HStack(spacing: 6) {
                                    AsideIcon(icon: .history, size: 14, color: Theme.secondaryText)
                                    Text("历史")
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                }
                                .foregroundColor(Theme.secondaryText)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.asideSeparator)
                                )
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    } else {
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: 32)
                            .frame(width: 200, alignment: .leading)
                    }
                }

                Spacer()

                if !viewModel.songs.isEmpty {
                    Button(action: {
                        if let first = viewModel.songs.first {
                            PlayerManager.shared.play(song: first, in: viewModel.songs)
                        }
                    }) {
                        AsideIcon(icon: .playCircle, size: 44, color: Theme.accent)
                            .shadow(color: Theme.accent.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                }
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 24)
        .padding(.top, DeviceLayout.headerTopPadding)
        .padding(.bottom, 10)
    }

    private var songList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(Array(viewModel.songs.enumerated()), id: \.element.id) { index, song in
                    SongListRow(song: song, index: index, onArtistTap: { artistId in
                        selectedArtistId = artistId
                        showArtistDetail = true
                    }, onDetailTap: { detailSong in
                        selectedSongForDetail = detailSong
                        showSongDetail = true
                    }, onAlbumTap: { albumId in
                        selectedAlbumId = albumId
                        showAlbumDetail = true
                    })
                        .asButton {
                            PlayerManager.shared.play(song: song, in: viewModel.songs)
                        }
                }
            }
            .padding(.bottom, 120)
        }
    }

    private func errorView(msg: String) -> some View {
        VStack {
            Spacer()
            AsideIcon(icon: .warning, size: 48, color: .asideTextSecondary)
            Text(msg)
                .foregroundColor(.asideTextSecondary)
                .padding()
            Button("Retry") {
                viewModel.loadStandardRecommend()
            }
            Spacer()
        }
    }

    private var dayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd"
        return formatter.string(from: Date())
    }

    private var monthString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM"
        return formatter.string(from: Date())
    }
}

// MARK: - History View

struct DailyHistoryView: View {
    let dates: [String]
    @Environment(\.dismiss) var dismiss
    @State private var selectedDate: String?
    @State private var songs: [Song] = []
    @State private var isLoading = false
    @State private var loadTask: Task<Void, Never>?

    typealias Theme = PlaylistDetailView.Theme

    var body: some View {
        ZStack {
            AsideBackground()

            VStack(spacing: 0) {
                headerSection

                dateSelector
                    .padding(.top, 8)

                if isLoading {
                    Spacer()
                    AsideLoadingView(text: "LOADING")
                    Spacer()
                } else if songs.isEmpty {
                    emptyState
                } else {
                    songList
                }
            }
        }
        .onAppear {
            AppLogger.debug("DailyHistoryView appeared with \(dates.count) dates: \(dates)")
            if let first = dates.first {
                loadSongs(for: first)
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Button(action: { dismiss() }) {
                AsideIcon(icon: .close, size: 20, color: Theme.text)
                    .padding(10)
                    .background(Color.asideCardBackground.opacity(0.6))
                    .clipShape(Circle())
            }

            Spacer()

            VStack(spacing: 2) {
                Text("历史日推")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.text)

                Text("回顾往日推荐")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(Theme.secondaryText)
            }

            Spacer()

            if !songs.isEmpty {
                Button(action: {
                    if let first = songs.first {
                        PlayerManager.shared.play(song: first, in: songs)
                    }
                }) {
                    AsideIcon(icon: .playCircle, size: 36, color: Theme.accent)
                }
            } else {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 40, height: 40)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Date Selector

    private var dateSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(dates, id: \.self) { date in
                    dateButton(for: date)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
    }

    private func dateButton(for date: String) -> some View {
        let isSelected = selectedDate == date
        let displayDate = formatDateShort(date)

        return Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                loadSongs(for: date)
            }
        }) {
            Text(displayDate)
                .font(.system(size: 14, weight: isSelected ? .bold : .medium, design: .rounded))
                .foregroundColor(isSelected ? .asideIconForeground : .asideTextPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.asideIconBackground.opacity(0.85) : Color.asideCardBackground)
                        .overlay(
                            Capsule()
                                .stroke(Color.asideSeparator, lineWidth: isSelected ? 0 : 1)
                        )
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Content

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            AsideIcon(icon: .clock, size: 48, color: .asideTextSecondary.opacity(0.5))

            Text("选择日期查看历史推荐")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.asideTextSecondary)

            Spacer()
        }
    }

    private var songList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                if let date = selectedDate {
                    HStack {
                        Text(formatFullDate(date))
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.secondaryText)

                        Spacer()

                        Text("\(songs.count) 首歌曲")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.secondaryText.opacity(0.7))
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                }

                ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                    SongListRow(song: song, index: index)
                        .asButton {
                            PlayerManager.shared.play(song: song, in: songs)
                        }
                }
            }
            .padding(.bottom, 100)
        }
    }

    // MARK: - Helpers

    private func loadSongs(for date: String) {
        selectedDate = date
        isLoading = true
        songs = []
        loadTask?.cancel()

        AppLogger.debug("Loading history songs for date: \(date)")
        loadTask = Task {
            do {
                let loadedSongs = try await APIService.shared.fetchHistoryRecommendSongs(date: date).async()
                guard !Task.isCancelled else { return }
                AppLogger.debug("Received \(loadedSongs.count) history songs")
                songs = loadedSongs
            } catch {
                guard !Task.isCancelled else { return }
                AppLogger.error("History songs load error: \(error)")
            }
            isLoading = false
        }
    }

    private func formatDateShort(_ dateString: String) -> String {
        let components = dateString.split(separator: "-")
        if components.count >= 3 {
            return "\(components[1])/\(components[2])"
        }
        return dateString
    }

    private func formatDate(_ dateString: String) -> (day: String, month: String) {
        let components = dateString.split(separator: "-")
        if components.count >= 3 {
            let day = String(components[2])
            let monthNum = Int(components[1]) ?? 1
            let months = ["", "一月", "二月", "三月", "四月", "五月", "六月",
                         "七月", "八月", "九月", "十月", "十一月", "十二月"]
            let month = months[min(monthNum, 12)]
            return (day, month)
        }
        return (dateString, "")
    }

    private func formatFullDate(_ dateString: String) -> String {
        let components = dateString.split(separator: "-")
        if components.count >= 3 {
            return "\(components[0])年\(components[1])月\(components[2])日 推荐"
        }
        return dateString
    }
}
