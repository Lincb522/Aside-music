import SwiftUI
import Combine
@preconcurrency import QQMusicKit

extension LibraryViewModel {
    // MARK: - My Library
    
    /// 退出登录时清除用户相关数据
    func handleLogout() {
        AppLogger.info("LibraryViewModel: 收到退出登录通知，清除数据")
        userPlaylists = []
        kugouUserPlaylists = []
        squarePlaylists = []
        topArtists = []
        topLists = []
        qqSquarePlaylists = []
        qqArtists = []
        qqTopLists = []
        kugouTopLists = []
    }

    func fetchPlaylists(force: Bool = false) {
        // Disk cache restoration must not block the first library frame. Network
        // results always win because cached values are only applied while the
        // corresponding collection is still empty.
        restoreCachedPlaylistsIfNeeded()

        if KCMMusicService.shared.isAuthenticated {
            loadKugouUserPlaylists()
        } else {
            kugouUserPlaylists = []
        }

        guard let uid = apiService.currentUserId else {
            #if DEBUG
            AppLogger.debug("[Library] fetchPlaylists: currentUserId 为 nil，跳过")
            #endif
            GlobalRefreshManager.shared.markLibraryDataReady()
            return
        }

        if !force && !userPlaylists.isEmpty {
            GlobalRefreshManager.shared.markLibraryDataReady()
            return
        }

        #if DEBUG
        print("[Library] fetchPlaylists: uid=\(uid), force=\(force)")
        #endif

        // force 刷新时直接加载歌单，不需要重新验证登录状态
        if force {
            // 服务端数据可能有短暂延迟，等待 0.5 秒再请求
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.loadUserPlaylists(uid: uid)
            }
            return
        }

        apiService.fetchLoginStatus()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    #if DEBUG
                    print("[Library] fetchLoginStatus 失败: \(error)，使用已有 uid=\(uid) 加载歌单")
                    #endif
                    // 即使登录状态检查失败，也尝试用已有 uid 加载歌单
                    self?.loadUserPlaylists(uid: uid)
                }
            }, receiveValue: { [weak self] response in
                if let profile = response.data.profile {
                    self?.apiService.currentUserId = profile.userId
                    self?.loadUserPlaylists(uid: profile.userId)
                } else {
                    #if DEBUG
                    print("[Library] fetchLoginStatus 返回 profile 为 nil，使用已有 uid=\(uid) 加载歌单")
                    #endif
                    // profile 为 nil 但 uid 存在，仍然尝试加载歌单
                    self?.loadUserPlaylists(uid: uid)
                }
            })
            .store(in: &cancellables)
    }

    private func restoreCachedPlaylistsIfNeeded() {
        guard userPlaylists.isEmpty || kugouUserPlaylists.isEmpty else { return }

        Task { [weak self] in
            async let cachedUser = OptimizedCacheManager.shared.getObjectAsync(
                forKey: "user_playlists",
                type: [Playlist].self
            )
            async let cachedKugou = OptimizedCacheManager.shared.getObjectAsync(
                forKey: "kcm_user_playlists",
                type: [Playlist].self
            )
            let (user, kugou) = await (cachedUser, cachedKugou)
            guard let self else { return }

            if self.userPlaylists.isEmpty, let user {
                self.userPlaylists = user.filter { !$0.isKugou }
            }
            if self.kugouUserPlaylists.isEmpty,
               KCMMusicService.shared.isAuthenticated,
               let kugou {
                self.kugouUserPlaylists = kugou
            }
        }
    }

    func loadUserPlaylists(uid: Int) {
        #if DEBUG
        print("[Library] loadUserPlaylists: uid=\(uid)")
        #endif
        apiService.fetchUserPlaylists(uid: uid)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    AppLogger.error("歌单获取失败: \(error)")
                    #if DEBUG
                    print("[Library] ❌ 歌单获取失败: \(error)")
                    #endif
                    self?.retryLoadPlaylistsIfNeeded(uid: uid)
                }
                GlobalRefreshManager.shared.markLibraryDataReady()
            }, receiveValue: { [weak self] playlists in
                #if DEBUG
                print("[Library] ✅ 获取到 \(playlists.count) 个歌单")
                #endif
                self?.playlistRetryCount = 0
                let filtered = playlists.filter { !$0.name.hasPrefix("test_audit") && $0.name != "test_audit_tmp" }
                self?.userPlaylists = filtered
                SubscriptionManager.shared.updatePlaylistSubscriptions(from: playlists, userId: uid)
                OptimizedCacheManager.shared.setObject(filtered, forKey: "user_playlists")
                OptimizedCacheManager.shared.cachePlaylists(playlists)
            })
            .store(in: &cancellables)
    }

    func loadKugouUserPlaylists() {
        apiService.fetchKugouUserPlaylists()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    AppLogger.warning("KCM 个人歌单获取失败: \(error)")
                }
            }, receiveValue: { [weak self] playlists in
                guard let self else { return }
                self.kugouUserPlaylists = playlists
                OptimizedCacheManager.shared.setObject(playlists, forKey: "kcm_user_playlists")
                OptimizedCacheManager.shared.cachePlaylists(playlists)
            })
            .store(in: &cancellables)
    }

    func retryLoadPlaylistsIfNeeded(uid: Int) {
        guard playlistRetryCount < maxPlaylistRetries, userPlaylists.isEmpty else { return }
        playlistRetryCount += 1
        let delay = Double(playlistRetryCount) * 3.0
        #if DEBUG
        print("[Library] 🔄 歌单加载失败，\(delay)秒后第\(playlistRetryCount)次重试")
        #endif
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.loadUserPlaylists(uid: uid)
        }
    }
}
