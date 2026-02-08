import SwiftUI
import Combine

/// 全局收藏管理器 — 管理歌单收藏和播客订阅
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    /// 已订阅的播客列表
    @Published var subscribedRadios: [RadioStation] = []
    /// 已订阅的播客 ID 集合（快速查询）
    @Published var subscribedRadioIds: Set<Int> = []
    /// 已收藏的歌单 ID 集合
    @Published var subscribedPlaylistIds: Set<Int> = []

    @Published var isLoadingRadios = false

    private var cancellables = Set<AnyCancellable>()
    private let apiService = APIService.shared

    private init() {
        if apiService.isLoggedIn {
            fetchSubscribedRadios()
        }
    }

    // MARK: - 播客订阅

    /// 获取用户订阅的播客
    func fetchSubscribedRadios() {
        guard apiService.isLoggedIn else { return }
        isLoadingRadios = true

        apiService.fetchDJSublist(limit: 200, offset: 0)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoadingRadios = false
                if case .failure(let error) = completion {
                    print("获取订阅播客失败: \(error)")
                }
            }, receiveValue: { [weak self] radios in
                self?.subscribedRadios = radios
                self?.subscribedRadioIds = Set(radios.map { $0.id })
            })
            .store(in: &cancellables)
    }

    /// 检查播客是否已订阅
    func isRadioSubscribed(_ id: Int) -> Bool {
        subscribedRadioIds.contains(id)
    }

    /// 订阅/取消订阅播客
    func toggleRadioSubscription(_ radio: RadioStation) {
        guard apiService.isLoggedIn else { return }

        let isCurrently = isRadioSubscribed(radio.id)
        let targetState = !isCurrently

        // 乐观更新
        if targetState {
            subscribedRadioIds.insert(radio.id)
            subscribedRadios.insert(radio, at: 0)
        } else {
            subscribedRadioIds.remove(radio.id)
            subscribedRadios.removeAll { $0.id == radio.id }
        }

        apiService.subscribeDJ(rid: radio.id, subscribe: targetState)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure = completion {
                    // 回滚
                    if targetState {
                        self?.subscribedRadioIds.remove(radio.id)
                        self?.subscribedRadios.removeAll { $0.id == radio.id }
                    } else {
                        self?.subscribedRadioIds.insert(radio.id)
                        self?.subscribedRadios.insert(radio, at: 0)
                    }
                }
            }, receiveValue: { _ in })
            .store(in: &cancellables)
    }

    // MARK: - 歌单收藏

    /// 检查歌单是否已收藏（通过用户歌单列表判断）
    func isPlaylistSubscribed(_ id: Int) -> Bool {
        subscribedPlaylistIds.contains(id)
    }

    /// 从用户歌单列表中提取收藏的歌单 ID
    func updatePlaylistSubscriptions(from playlists: [Playlist], userId: Int?) {
        guard let uid = userId else { return }
        // 不是自己创建的歌单 = 收藏的歌单
        let subscribed = playlists.filter { $0.creator?.userId != uid }
        subscribedPlaylistIds = Set(subscribed.map { $0.id })
    }

    /// 收藏/取消收藏歌单
    func togglePlaylistSubscription(id: Int) {
        guard apiService.isLoggedIn else { return }

        let isCurrently = isPlaylistSubscribed(id)
        let targetState = !isCurrently

        // 乐观更新
        if targetState {
            subscribedPlaylistIds.insert(id)
        } else {
            subscribedPlaylistIds.remove(id)
        }

        apiService.subscribePlaylist(id: id, subscribe: targetState)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure = completion {
                    // 回滚
                    if targetState {
                        self?.subscribedPlaylistIds.remove(id)
                    } else {
                        self?.subscribedPlaylistIds.insert(id)
                    }
                }
            }, receiveValue: { response in
                if response.code == 200 {
                    // 收藏/取消收藏成功，刷新歌单列表
                    Task { @MainActor in
                        GlobalRefreshManager.shared.refreshLibraryPublisher.send(true)
                    }
                }
            })
            .store(in: &cancellables)
    }

    /// 删除用户创建的歌单（真实 API 调用）
    func deletePlaylist(id: Int, completion: @escaping (Bool) -> Void) {
        guard apiService.isLoggedIn else {
            completion(false)
            return
        }

        apiService.deletePlaylist(id: id)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { result in
                if case .failure(let error) = result {
                    print("删除歌单失败: \(error)")
                    completion(false)
                }
            }, receiveValue: { response in
                completion(response.code == 200)
            })
            .store(in: &cancellables)
    }

    /// 取消收藏歌单（真实 API 调用）
    func unsubscribePlaylist(id: Int, completion: @escaping (Bool) -> Void) {
        guard apiService.isLoggedIn else {
            completion(false)
            return
        }

        subscribedPlaylistIds.remove(id)

        apiService.subscribePlaylist(id: id, subscribe: false)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] result in
                if case .failure(let error) = result {
                    print("取消收藏歌单失败: \(error)")
                    self?.subscribedPlaylistIds.insert(id)
                    completion(false)
                }
            }, receiveValue: { response in
                completion(response.code == 200)
            })
            .store(in: &cancellables)
    }

    /// 取消订阅播客（真实 API 调用）
    func unsubscribeRadio(_ radio: RadioStation, completion: @escaping (Bool) -> Void) {
        guard apiService.isLoggedIn else {
            completion(false)
            return
        }

        // 乐观更新
        subscribedRadioIds.remove(radio.id)
        subscribedRadios.removeAll { $0.id == radio.id }

        apiService.subscribeDJ(rid: radio.id, subscribe: false)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] result in
                if case .failure(let error) = result {
                    print("取消订阅播客失败: \(error)")
                    // 回滚
                    self?.subscribedRadioIds.insert(radio.id)
                    self?.subscribedRadios.insert(radio, at: 0)
                    completion(false)
                }
            }, receiveValue: { response in
                completion(response.code == 200)
            })
            .store(in: &cancellables)
    }

    /// 刷新所有订阅数据
    func refresh() {
        if apiService.isLoggedIn {
            fetchSubscribedRadios()
        } else {
            subscribedRadios = []
            subscribedRadioIds = []
            subscribedPlaylistIds = []
        }
    }
}
