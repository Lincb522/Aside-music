import Foundation
import Combine

/// 电台详情 ViewModel，管理电台信息和节目列表的加载
class RadioDetailViewModel: ObservableObject {
    @Published var radioDetail: RadioStation?
    @Published var programs: [RadioProgram] = []
    @Published var isLoading = true
    @Published var isLoadingMore = false
    @Published var hasMore = true
    @Published var errorMessage: String?

    let radioId: Int
    private var offset = 0
    private let limit = 30
    private var cancellables = Set<AnyCancellable>()
    private let apiService = APIService.shared

    init(radioId: Int) {
        self.radioId = radioId
    }

    /// 加载电台详情
    func fetchDetail() {
        isLoading = true
        errorMessage = nil

        apiService.fetchDJDetail(id: radioId)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.errorMessage = "加载失败：\(error.localizedDescription)"
                    self?.isLoading = false
                }
            }, receiveValue: { [weak self] station in
                self?.radioDetail = station
                self?.fetchPrograms()
            })
            .store(in: &cancellables)
    }

    /// 加载节目列表
    func fetchPrograms() {
        offset = 0
        programs = []

        apiService.fetchDJPrograms(radioId: radioId, limit: limit, offset: offset)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = "节目加载失败：\(error.localizedDescription)"
                }
            }, receiveValue: { [weak self] progs in
                guard let self = self else { return }
                self.programs = progs
                self.offset = progs.count
                self.hasMore = progs.count >= self.limit
            })
            .store(in: &cancellables)
    }

    /// 分页加载更多节目
    func loadMorePrograms() {
        guard !isLoadingMore, hasMore else { return }
        isLoadingMore = true

        apiService.fetchDJPrograms(radioId: radioId, limit: limit, offset: offset)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoadingMore = false
                if case .failure(let error) = completion {
                    print("[RadioDetailVM] 加载更多失败: \(error)")
                }
            }, receiveValue: { [weak self] progs in
                guard let self = self else { return }
                let existingIds = Set(self.programs.map { $0.id })
                let newProgs = progs.filter { !existingIds.contains($0.id) }
                self.programs.append(contentsOf: newProgs)
                self.offset += progs.count
                self.hasMore = progs.count >= self.limit
            })
            .store(in: &cancellables)
    }

    /// 将节目列表转换为 Song 数组用于播放，注入节目封面
    func songsFromPrograms() -> [Song] {
        return programs.compactMap { program -> Song? in
            guard var song = program.mainSong else { return nil }
            // 如果歌曲没有专辑封面（nil 或空字符串），使用节目封面或电台封面
            if song.al?.picUrl == nil || (song.al?.picUrl?.isEmpty ?? true) {
                song.podcastCoverUrl = program.coverUrl ?? radioDetail?.picUrl
            }
            return song
        }
    }
}
