import SwiftUI
import Combine
@preconcurrency import QQMusicKit

extension LibraryViewModel {
    // MARK: - My Library
    
    func handleNCMLogout() {
        guard !apiService.isLoggedIn else { return }
        AppLogger.info("LibraryViewModel: NCM 退出，清除 NCM 用户歌单")
        playlistStatusRequest.cancel()
        userPlaylistRequest.cancel()
        playlistCacheRequest.cancel()
        playlistRetryCount = 0
        userPlaylists = []
        SubscriptionManager.shared.resetRemoteNCMState()
    }

    func handleKCMSessionDidChange() {
        kugouUserPlaylistRequest.cancel()
        playlistCacheRequest.cancel()
        kugouUserPlaylists = []
        let service = KCMMusicService.shared
        let session = service.sessionSnapshot
        guard session.isAuthenticated,
              service.isCurrentSession(session) else { return }
        restoreCachedPlaylistsIfNeeded()
        loadKugouUserPlaylists(session: session)
    }

    func fetchPlaylists(force: Bool = false) {
        // Restore off the first-frame path and reject cache values superseded
        // by network results or local edits.
        restoreCachedPlaylistsIfNeeded()

        let kcmService = KCMMusicService.shared
        let kcmSession = kcmService.sessionSnapshot
        if kcmSession.isAuthenticated {
            loadKugouUserPlaylists(session: kcmSession, force: force)
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

        if playlistRequestSession != ncmSession {
            playlistStatusRequest.cancel()
            userPlaylistRequest.cancel()
            playlistRequestSession = ncmSession
            playlistRetryCount = 0
        }
        if !force && (playlistStatusRequest.isRunning || userPlaylistRequest.isRunning) { return }
        if force {
            playlistStatusRequest.cancel()
            userPlaylistRequest.cancel()
            playlistRetryCount = 0
        }

        if !force && !userPlaylists.isEmpty {
            GlobalRefreshManager.shared.markLibraryDataReady()
            return
        }

        #if DEBUG
        print("[Library] fetchPlaylists: uid=\(uid), force=\(force)")
        #endif

        let statusRequest = playlistStatusRequest.begin()
        // force 刷新时直接加载歌单，不需要重新验证登录状态
        if force {
            // 服务端数据可能有短暂延迟，等待 0.5 秒再请求
            playlistStatusRequest.task = Task { @MainActor [weak self] in
                do { try await Task.sleep(nanoseconds: 500_000_000) } catch { return }
                guard let self, !Task.isCancelled,
                      self.playlistStatusRequest.isCurrent(statusRequest),
                      self.apiService.isCurrentNCMSession(ncmSession) else { return }
                self.playlistStatusRequest.finish(statusRequest)
                self.loadUserPlaylists(uid: uid, session: ncmSession)
            }
            return
        }

        playlistStatusRequest.cancellable = apiService.fetchLoginStatus()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    guard let self,
                          self.playlistStatusRequest.isCurrent(statusRequest),
                          self.apiService.isCurrentNCMSession(ncmSession) else { return }
                    self.playlistStatusRequest.finish(statusRequest)
                    #if DEBUG
                    print("[Library] fetchLoginStatus 失败: \(error)，使用已有 uid=\(uid) 加载歌单")
                    #endif
                    // 即使登录状态检查失败，也尝试用已有 uid 加载歌单
                    self.loadUserPlaylists(uid: uid, session: ncmSession)
                }
            }, receiveValue: { [weak self] response in
                guard let self,
                      self.playlistStatusRequest.isCurrent(statusRequest),
                      self.apiService.isCurrentNCMSession(ncmSession) else { return }
                self.playlistStatusRequest.finish(statusRequest)
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

    }

    private func restoreCachedPlaylistsIfNeeded() {
        let ncmSession = apiService.ncmSessionSnapshot
        let kcmSession = KCMMusicService.shared.sessionSnapshot
        let restoreNCM = userPlaylists.isEmpty && apiService.isLoggedIn && ncmSession.userID != nil
        let restoreKCM = kugouUserPlaylists.isEmpty && kcmSession.isAuthenticated
        guard restoreNCM || restoreKCM else { return }
        if playlistCacheRequest.isRunning,
           playlistCacheNCMSession == ncmSession,
           playlistCacheKCMSession == kcmSession { return }
        playlistCacheNCMSession = ncmSession
        playlistCacheKCMSession = kcmSession
        let userRevision = userPlaylistRevision
        let kugouRevision = kugouUserPlaylistRevision
        let request = playlistCacheRequest.begin()

        playlistCacheRequest.task = Task { @MainActor [weak self] in
            guard !Task.isCancelled else { return }
            async let cachedUser: [Playlist]? = restoreNCM
                ? OptimizedCacheManager.shared.getObjectAsync(forKey: "user_playlists", type: [Playlist].self)
                : nil
            let kugou: [Playlist]?
            if restoreKCM, let userID = kcmSession.userID {
                kugou = await OptimizedCacheManager.shared.getObjectAsync(
                    forKey: "kcm_user_playlists_\(userID)", type: [Playlist].self
                )
            } else {
                kugou = nil
            }
            let user = await cachedUser
            guard let self, !Task.isCancelled, self.playlistCacheRequest.isCurrent(request) else { return }
            self.playlistCacheRequest.finish(request)

            // A newer network result, including an empty list, takes precedence.
            if self.userPlaylistRevision == userRevision,
               self.apiService.isCurrentNCMSession(ncmSession),
               self.apiService.isLoggedIn,
               self.userPlaylists.isEmpty,
               let user {
                self.userPlaylists = user.filter { !$0.isKugou }
            }
            if self.kugouUserPlaylistRevision == kugouRevision,
               self.kugouUserPlaylists.isEmpty,
               kcmSession.isAuthenticated,
               KCMMusicService.shared.isCurrentSession(kcmSession),
               let kugou {
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
        let request = userPlaylistRequest.begin()
        userPlaylistRequest.cancellable = apiService.fetchUserPlaylists(uid: uid)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self, self.userPlaylistRequest.isCurrent(request),
                      self.apiService.isCurrentNCMSession(session) else { return }
                self.userPlaylistRequest.finish(request)
                if case .failure(let error) = completion {
                    AppLogger.error("歌单获取失败: \(error)")
                    #if DEBUG
                    print("[Library] ❌ 歌单获取失败: \(error)")
                    #endif
                    self.retryLoadPlaylistsIfNeeded(uid: uid, session: session)
                }
                GlobalRefreshManager.shared.markLibraryDataReady()
            }, receiveValue: { [weak self] playlists in
                guard let self, self.userPlaylistRequest.isCurrent(request),
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

    }

    func loadKugouUserPlaylists(force: Bool = false) {
        loadKugouUserPlaylists(session: KCMMusicService.shared.sessionSnapshot, force: force)
    }

    private func loadKugouUserPlaylists(session: KCMMusicService.SessionSnapshot, force: Bool = true) {
        let service = KCMMusicService.shared
        guard session.isAuthenticated,
              let userID = session.userID,
              service.isCurrentSession(session) else { return }
        if kugouPlaylistRequestSession != session {
            kugouUserPlaylistRequest.cancel()
            kugouPlaylistRequestSession = session
        }
        if !force, kugouUserPlaylistRequest.isRunning { return }
        guard force || kugouUserPlaylists.isEmpty else { return }
        let request = kugouUserPlaylistRequest.begin()
        kugouUserPlaylistRequest.cancellable = apiService.fetchKugouUserPlaylists()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self, self.kugouUserPlaylistRequest.isCurrent(request),
                      service.isCurrentSession(session) else { return }
                self.kugouUserPlaylistRequest.finish(request)
                if case .failure(let error) = completion {
                    AppLogger.warning("KCM 个人歌单获取失败: \(error)")
                }
            }, receiveValue: { [weak self] playlists in
                guard let self, self.kugouUserPlaylistRequest.isCurrent(request),
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
        let request = userPlaylistRequest.begin()
        userPlaylistRequest.task = Task { @MainActor [weak self] in
            do { try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) } catch { return }
            guard let self, !Task.isCancelled, self.userPlaylistRequest.isCurrent(request),
                  self.apiService.isCurrentNCMSession(session) else { return }
            self.loadUserPlaylists(uid: uid, session: session)
        }
    }
}
