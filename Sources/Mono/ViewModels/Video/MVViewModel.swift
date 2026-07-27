// MV 系统 ViewModel

import Foundation
import Combine

struct UnifiedMVItem: Identifiable, Hashable {
    let source: MusicSource
    let platformID: String
    let title: String
    let artistName: String
    let coverURL: String?
    let durationText: String
    let playCountText: String
    let ncmID: Int?
    let qqVID: String?
    let kcmMV: KCMMV?

    var id: String { "\(source.rawValue):\(platformID)" }

    init(_ mv: MV) {
        source = .netease
        platformID = String(mv.id)
        title = mv.displayName
        artistName = mv.artistName ?? String(localized: "mv_unknown_artist")
        coverURL = mv.coverUrl
        durationText = mv.durationText
        playCountText = mv.playCountText
        ncmID = mv.id
        qqVID = nil
        kcmMV = nil
    }

    init(_ mv: QQMV) {
        source = .qqmusic
        platformID = mv.vid
        title = mv.name
        artistName = mv.singerName ?? String(localized: "mv_unknown_artist")
        coverURL = mv.coverUrl
        durationText = mv.durationText
        playCountText = mv.playCountText
        ncmID = nil
        qqVID = mv.vid
        kcmMV = nil
    }

    init(_ mv: KCMMV) {
        source = .kugou
        platformID = mv.hash
        title = mv.name
        artistName = mv.artistName ?? String(localized: "mv_unknown_artist")
        coverURL = mv.coverURL
        durationText = mv.durationText
        playCountText = mv.playCountText
        ncmID = nil
        qqVID = nil
        kcmMV = mv
    }
}

// MARK: - MV 发现页 ViewModel

@MainActor
class MVDiscoverViewModel: ObservableObject {
    @Published var latestMVs: [MV] = []
    @Published var topMVs: [MV] = []
    @Published var exclusiveMVs: [MV] = []
    @Published var mlogItems: [MlogItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var unifiedItems: [MusicSource: [UnifiedMVItem]] = [:]
    @Published private(set) var unifiedErrors: [MusicSource: String] = [:]
    @Published private(set) var unifiedLoadingSources: Set<MusicSource> = []
    @Published private(set) var unifiedHasMore: [MusicSource: Bool] = [:]

    private var cancellables = Set<AnyCancellable>()
    private let api = APIService.shared
    private var unifiedCancellables = Set<AnyCancellable>()
    private var unifiedPages: [MusicSource: Int] = [:]

    var isUnifiedLoading: Bool { !unifiedLoadingSources.isEmpty }

    func items(for source: MusicSource) -> [UnifiedMVItem] {
        unifiedItems[source] ?? []
    }

    func fetchUnified(refresh: Bool = false) {
        if refresh {
            unifiedCancellables.removeAll()
            unifiedItems = [:]
            unifiedErrors = [:]
            unifiedLoadingSources = []
            unifiedPages = [:]
            unifiedHasMore = [:]
        }
        for source in [MusicSource.netease, .qqmusic, .kugou] where items(for: source).isEmpty {
            fetchUnified(source: source, page: 1, appending: false)
        }
    }

    func loadMoreUnified(source: MusicSource) {
        guard unifiedHasMore[source] == true,
              !unifiedLoadingSources.contains(source) else { return }
        fetchUnified(source: source, page: (unifiedPages[source] ?? 1) + 1, appending: true)
    }

    private func fetchUnified(source: MusicSource, page: Int, appending: Bool) {
        guard !unifiedLoadingSources.contains(source) else { return }
        unifiedLoadingSources.insert(source)
        unifiedErrors[source] = nil

        switch source {
        case .netease:
            api.fetchAllMVs(limit: 20, offset: (page - 1) * 20)
                .map { $0.map(UnifiedMVItem.init) }
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: unifiedCompletion(source: source), receiveValue: { [weak self] items in
                    self?.acceptUnified(items, source: source, page: page, pageSize: 20, appending: appending)
                })
                .store(in: &unifiedCancellables)
        case .qqmusic:
            api.fetchQQMVList(page: page, num: 20)
                .map { $0.map(UnifiedMVItem.init) }
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: unifiedCompletion(source: source), receiveValue: { [weak self] items in
                    self?.acceptUnified(items, source: source, page: page, pageSize: 20, appending: appending)
                })
                .store(in: &unifiedCancellables)
        case .kugou:
            api.searchKugouMVs(keyword: "热门", page: page, pageSize: 20)
                .map { ($0.mvs.map(UnifiedMVItem.init), $0.hasMore) }
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: unifiedCompletion(source: source), receiveValue: { [weak self] result in
                    self?.acceptUnified(result.0, source: source, page: page, pageSize: 20, appending: appending, hasMore: result.1)
                })
                .store(in: &unifiedCancellables)
        case .qishui, .appleMusic, .local:
            unifiedLoadingSources.remove(source)
        }
    }

    private func unifiedCompletion(source: MusicSource) -> (Subscribers.Completion<Error>) -> Void {
        { [weak self] completion in
            self?.unifiedLoadingSources.remove(source)
            if case .failure(let error) = completion {
                self?.unifiedErrors[source] = error.localizedDescription
                self?.unifiedHasMore[source] = false
            }
        }
    }

    private func acceptUnified(
        _ items: [UnifiedMVItem],
        source: MusicSource,
        page: Int,
        pageSize: Int,
        appending: Bool,
        hasMore: Bool? = nil
    ) {
        if appending {
            let existingIDs = Set((unifiedItems[source] ?? []).map(\.id))
            unifiedItems[source, default: []].append(contentsOf: items.filter { !existingIDs.contains($0.id) })
        } else {
            unifiedItems[source] = items
        }
        unifiedPages[source] = page
        unifiedHasMore[source] = hasMore ?? (items.count >= pageSize)
        unifiedLoadingSources.remove(source)
    }

    func fetchAll() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        let latest = api.fetchLatestMVs(limit: 7)
        let top = api.fetchTopMVs(limit: 6)
        let exclusive = api.fetchExclusiveMVs(limit: 6)

        Publishers.Zip3(latest, top, exclusive)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] latest, top, exclusive in
                self?.latestMVs = latest
                self?.topMVs = top
                self?.exclusiveMVs = exclusive
                self?.fetchMlog()
            }
            .store(in: &cancellables)
    }

    /// 加载 Mlog 推荐（基于当前播放歌曲或最新 MV 关联歌曲）
    func fetchMlog() {
        // 优先用当前播放歌曲，没有则用 songid=0 获取通用推荐
        let songId = PlayerManager.shared.currentSong?.id ?? 0
        api.fetchMlogMusicRcmd(songid: songId, limit: 10)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    AppLogger.debug("Mlog 加载失败: \(error)")
                }
            }, receiveValue: { [weak self] items in
                self?.mlogItems = items
            })
            .store(in: &cancellables)
    }
}

// MARK: - MV 列表 ViewModel（分页加载）

class MVListViewModel: ObservableObject {
    enum ListType {
        case latest
        case top
        case exclusive
        case all
        case artist(Int)
    }

    @Published var mvs: [MV] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var hasMore = true

    let listType: ListType
    private var offset = 0
    private let pageSize = 20
    private var cancellables = Set<AnyCancellable>()
    private let api = APIService.shared

    init(listType: ListType) {
        self.listType = listType
    }

    func fetchInitial() {
        guard !isLoading else { return }
        isLoading = true
        offset = 0
        loadPage()
    }

    func loadMore() {
        guard !isLoadingMore && hasMore else { return }
        isLoadingMore = true
        loadPage()
    }

    private func loadPage() {
        let publisher: AnyPublisher<[MV], Error>

        switch listType {
        case .latest:
            publisher = api.fetchLatestMVs(area: String(localized: "filter_all"), limit: pageSize)
        case .top:
            publisher = api.fetchTopMVs(limit: pageSize, offset: offset)
        case .exclusive:
            publisher = api.fetchExclusiveMVs(limit: pageSize, offset: offset)
        case .all:
            publisher = api.fetchAllMVs(limit: pageSize, offset: offset)
        case .artist(let id):
            publisher = api.fetchArtistMVs(id: id, limit: pageSize, offset: offset)
        }

        publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                self?.isLoadingMore = false
            } receiveValue: { [weak self] newMVs in
                guard let self else { return }
                if self.offset == 0 {
                    self.mvs = newMVs
                } else {
                    self.mvs.append(contentsOf: newMVs)
                }
                self.hasMore = newMVs.count >= self.pageSize
                self.offset += newMVs.count
            }
            .store(in: &cancellables)
    }
}


// MARK: - MV 播放器 ViewModel

class MVPlayerViewModel: ObservableObject {
    @Published var detail: MVDetail?
    @Published var detailInfo: MVDetailInfo?
    @Published var videoUrl: String?
    @Published var simiMVs: [MV] = []
    @Published var relatedMVs: [MV] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isSubscribed = false

    let mvId: Int
    private var cancellables = Set<AnyCancellable>()
    private let api = APIService.shared

    init(mvId: Int) {
        self.mvId = mvId
    }

    func fetchData() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        // 独立获取详情（不受 URL 失败影响）
        api.fetchMVDetail(id: mvId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    AppLogger.error("[MVPlayer] detail 获取失败: \(error)")
                    self?.isLoading = false
                    self?.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] detail in
                AppLogger.info("[MVPlayer] detail 获取成功: name=\(detail.name ?? "nil"), artist=\(detail.displayArtistName)")
                self?.detail = detail
                self?.isLoading = false
                self?.fetchSimiMVs()
                self?.fetchDetailInfo()
                self?.fetchRelatedVideos()
            }
            .store(in: &cancellables)

        // 独立获取播放链接，失败自动降级分辨率
        api.fetchMVUrl(id: mvId, resolution: 1080)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case .failure = completion {
                    self?.tryLowerResolution()
                }
            } receiveValue: { [weak self] url in
                self?.videoUrl = url
            }
            .store(in: &cancellables)
    }

    /// 获取互动数据（点赞数、评论数等）
    private func fetchDetailInfo() {
        api.fetchMVDetailInfo(id: mvId)
            .receive(on: DispatchQueue.main)
            .sink { _ in } receiveValue: { [weak self] info in
                self?.detailInfo = info
                self?.isSubscribed = info.liked ?? false
            }
            .store(in: &cancellables)
    }

    /// 收藏/取消收藏
    func toggleSubscribe() {
        let newState = !isSubscribed
        isSubscribed = newState // 乐观更新

        api.subscribeMV(id: mvId, subscribe: newState)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case .failure = completion {
                    // 回滚
                    self?.isSubscribed = !newState
                }
            } receiveValue: { _ in }
            .store(in: &cancellables)
    }

    private func tryLowerResolution() {
        let resolutions = [720, 480, 240]
        tryResolution(resolutions: resolutions, index: 0)
    }

    private func tryResolution(resolutions: [Int], index: Int) {
        guard index < resolutions.count else { return }
        api.fetchMVUrl(id: mvId, resolution: resolutions[index])
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case .failure = completion {
                    self?.tryResolution(resolutions: resolutions, index: index + 1)
                }
            } receiveValue: { [weak self] url in
                self?.videoUrl = url
                self?.errorMessage = nil
            }
            .store(in: &cancellables)
    }

    private func fetchSimiMVs() {
        api.fetchSimiMVs(id: mvId)
            .receive(on: DispatchQueue.main)
            .sink { _ in } receiveValue: { [weak self] mvs in
                self?.simiMVs = mvs
            }
            .store(in: &cancellables)
    }

    /// 获取相关视频推荐
    private func fetchRelatedVideos() {
        api.fetchRelatedVideos(id: String(mvId))
            .receive(on: DispatchQueue.main)
            .sink { _ in } receiveValue: { [weak self] mvs in
                self?.relatedMVs = mvs
            }
            .store(in: &cancellables)
    }
}

// MARK: - 已收藏 MV 列表 ViewModel

class MVSublistViewModel: ObservableObject {
    @Published var items: [MVSubItem] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var hasMore = true

    private var offset = 0
    private let pageSize = 25
    private var cancellables = Set<AnyCancellable>()
    private let api = APIService.shared

    func fetchInitial() {
        guard !isLoading else { return }
        isLoading = true
        offset = 0
        items = []
        loadPage()
    }

    func loadMore() {
        guard !isLoadingMore && hasMore else { return }
        isLoadingMore = true
        loadPage()
    }

    private func loadPage() {
        api.fetchMVSublist(limit: pageSize, offset: offset)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                self?.isLoadingMore = false
            } receiveValue: { [weak self] newItems in
                guard let self else { return }
                if self.offset == 0 {
                    self.items = newItems
                } else {
                    self.items.append(contentsOf: newItems)
                }
                self.hasMore = newItems.count >= self.pageSize
                self.offset += newItems.count
            }
            .store(in: &cancellables)
    }
}
