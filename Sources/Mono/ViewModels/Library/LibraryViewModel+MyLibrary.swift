import SwiftUI
import Combine
@preconcurrency import QQMusicKit

extension LibraryViewModel {
    // MARK: - My Library
    
    func handleNCMLogout() {
        guard !apiService.isLoggedIn else { return }
        AppLogger.info("LibraryViewModel: NCM 退出，清除 NCM 用户歌单")
        playlistRetryCount = 0
        userPlaylists = []
        SubscriptionManager.shared.resetRemoteNCMState()
    }

    func handleKCMSessionDidChange() {
        kugouUserPlaylists = []
        let service = KCMMusicService.shared
        let session = service.sessionSnapshot
        guard session.isAuthenticated,
              service.isCurrentSession(session) else { return }
        restoreCachedPlaylistsIfNeeded()
        loadKugouUserPlaylists(session: session)
    }

    func fetchPlaylists(force: Bool = false) {
        // Disk cache restoration must not block the first library frame. Network
        // results always win because cached values are only applied while the
        // corresponding collection is still empty.
        restoreCachedPlaylistsIfNeeded()

        let kcmService = KCMMusicService.shared
        let kcmSession = kcmService.sessionSnapshot
        if kcmSession.isAuthenticated {
            loadKugouUserPlaylists(session: kcmSession)
        } else if kcmService.isCurrentSession(kcmSession) {
            kugouUserPlaylists = []
        }

        let ncmSession = apiService.ncmSessionSnapshot
        guard apiService.isLoggedIn, let uid = ncmSession.userID else {
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
                guard let self,
                      self.apiService.isCurrentNCMSession(ncmSession) else { return }
                self.loadUserPlaylists(uid: uid, session: ncmSession)
            }
            return
        }

        apiService.fetchLoginStatus()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    guard let self,
                          self.apiService.isCurrentNCMSession(ncmSession) else { return }
                    #if DEBUG
                    print("[Library] fetchLoginStatus 失败: \(error)，使用已有 uid=\(uid) 加载歌单")
                    #endif
                    // 即使登录状态检查失败，也尝试用已有 uid 加载歌单
                    self.loadUserPlaylists(uid: uid, session: ncmSession)
                }
            }, receiveValue: { [weak self] response in
                guard let self,
                      self.apiService.isCurrentNCMSession(ncmSession) else { return }
                if let profile = response.data.profile {
                    guard profile.userId == uid else { return }
                    self.loadUserPlaylists(uid: uid, session: ncmSession)
                } else {
                    #if DEBUG
                    print("[Library] fetchLoginStatus 返回 profile 为 nil，使用已有 uid=\(uid) 加载歌单")
                    #endif
                    // profile 为 nil 但 uid 存在，仍然尝试加载歌单
                    self.loadUserPlaylists(uid: uid, session: ncmSession)
                }
            })
            .store(in: &cancellables)
    }

    private func restoreCachedPlaylistsIfNeeded() {
        guard userPlaylists.isEmpty || kugouUserPlaylists.isEmpty else { return }
        let ncmSession = apiService.ncmSessionSnapshot
        let kcmSession = KCMMusicService.shared.sessionSnapshot

        Task { [weak self] in
            async let cachedUser = OptimizedCacheManager.shared.getObjectAsync(
                forKey: "user_playlists",
                type: [Playlist].self
            )
            let kugou: [Playlist]?
            if let userID = kcmSession.userID {
                kugou = await OptimizedCacheManager.shared.getObjectAsync(
                    forKey: "kcm_user_playlists_\(userID)",
                    type: [Playlist].self
                )
            } else {
                kugou = nil
            }
            let user = await cachedUser
            guard let self else { return }

            if self.apiService.isCurrentNCMSession(ncmSession),
               ncmSession.userID != nil,
               self.apiService.isLoggedIn,
               self.userPlaylists.isEmpty,
               let user {
                self.userPlaylists = user.filter { !$0.isKugou }
            }
            if self.kugouUserPlaylists.isEmpty,
               kcmSession.isAuthenticated,
               KCMMusicService.shared.isCurrentSession(kcmSession),
               let kugou {
                guard KCMMusicService.shared.isCurrentSession(kcmSession) else { return }
                self.kugouUserPlaylists = kugou
            }
        }
    }

    func loadUserPlaylists(uid: Int, session: APIService.NCMSessionSnapshot) {
        guard session.userID == uid,
              apiService.isCurrentNCMSession(session),
              apiService.isLoggedIn else { return }
        #if DEBUG
        print("[Library] loadUserPlaylists: uid=\(uid)")
        #endif
        apiService.fetchUserPlaylists(uid: uid)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self,
                      self.apiService.isCurrentNCMSession(session) else { return }
                if case .failure(let error) = completion {
                    AppLogger.error("歌单获取失败: \(error)")
                    #if DEBUG
                    print("[Library] ❌ 歌单获取失败: \(error)")
                    #endif
                    self.retryLoadPlaylistsIfNeeded(uid: uid, session: session)
                }
                GlobalRefreshManager.shared.markLibraryDataReady()
            }, receiveValue: { [weak self] playlists in
                guard let self,
                      self.apiService.isCurrentNCMSession(session) else { return }
                #if DEBUG
                print("[Library] ✅ 获取到 \(playlists.count) 个歌单")
                #endif
                self.playlistRetryCount = 0
                let filtered = playlists.filter { !$0.name.hasPrefix("test_audit") && $0.name != "test_audit_tmp" }
                self.userPlaylists = filtered
                SubscriptionManager.shared.updatePlaylistSubscriptions(from: playlists, userId: uid)
                OptimizedCacheManager.shared.setObject(filtered, forKey: "user_playlists")
                OptimizedCacheManager.shared.cachePlaylists(playlists)
            })
            .store(in: &cancellables)
    }

    func loadKugouUserPlaylists() {
        loadKugouUserPlaylists(session: KCMMusicService.shared.sessionSnapshot)
    }

    private func loadKugouUserPlaylists(session: KCMMusicService.SessionSnapshot) {
        let service = KCMMusicService.shared
        guard session.isAuthenticated,
              let userID = session.userID,
              service.isCurrentSession(session) else { return }
        apiService.fetchKugouUserPlaylists()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                guard service.isCurrentSession(session) else { return }
                if case .failure(let error) = completion {
                    AppLogger.warning("KCM 个人歌单获取失败: \(error)")
                }
            }, receiveValue: { [weak self] playlists in
                guard let self,
                      service.isCurrentSession(session) else { return }
                self.kugouUserPlaylists = playlists
                guard service.isCurrentSession(session) else { return }
                OptimizedCacheManager.shared.setObject(
                    playlists,
                    forKey: "kcm_user_playlists_\(userID)"
                )
                guard service.isCurrentSession(session) else { return }
                OptimizedCacheManager.shared.cachePlaylists(playlists)
            })
            .store(in: &cancellables)
    }

    func retryLoadPlaylistsIfNeeded(
        uid: Int,
        session: APIService.NCMSessionSnapshot
    ) {
        guard session.userID == uid,
              apiService.isCurrentNCMSession(session) else { return }
        guard playlistRetryCount < maxPlaylistRetries, userPlaylists.isEmpty else { return }
        playlistRetryCount += 1
        let delay = Double(playlistRetryCount) * 3.0
        #if DEBUG
        print("[Library] 🔄 歌单加载失败，\(delay)秒后第\(playlistRetryCount)次重试")
        #endif
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self,
                  self.apiService.isCurrentNCMSession(session) else { return }
            self.loadUserPlaylists(uid: uid, session: session)
        }
    }
}
