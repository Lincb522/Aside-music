import Combine
import QQMusicKit
import SwiftUI

struct ThemedProfileBackground: View {
    var body: some View {
        ThemedPageBackground(useRenderLayer: true)
    }
}

enum ProfileNavigationDestination: Hashable {
    case settings
    case platformAccounts
    case loginNCM
}

enum ProfileCacheOwner: Equatable {
    case netease(APIService.NCMSessionSnapshot)
    case qqmusic(QQUserSession.SessionSnapshot)
    case kugou(KCMMusicService.SessionSnapshot)

    var userID: Int? {
        switch self {
        case .netease(let session): session.userID
        case .qqmusic(let session): session.musicID
        case .kugou(let session): session.userID
        }
    }
}

extension View {
    func profileNavigationDestinations() -> some View {
        navigationDestination(for: ProfileNavigationDestination.self) { destination in
            switch destination {
            case .settings:
                SettingsView()
            case .platformAccounts:
                PlatformAccountManagementView()
            case .loginNCM:
                PlatformLoginView(initialPlatform: .ncm)
            }
        }
    }
}

struct ProfileView: View {
    @ObservedObject var settings = SettingsManager.shared
    @ObservedObject var qqSession = QQUserSession.shared
    @ObservedObject var loginIdentity = LoginIdentityManager.shared

    var viewModel: HomeViewModel {
        HomeViewModel.shared
    }

    var playerManager: PlayerManager {
        PlayerManager.shared
    }

    var displayedProfile: UserProfile? {
        let currentProfile = loginIdentity.displayedProfile(ncmProfile: viewModel.userProfile)
        guard currentProfile == nil,
              let owner = currentProfileOwner,
              cachedProfileOwner == owner,
              cachedProfile?.userId == owner.userID else { return currentProfile }
        return cachedProfile
    }

    var currentProfileOwner: ProfileCacheOwner? {
        switch loginIdentity.activeSource {
        case .netease:
            let service = APIService.shared
            let session = service.ncmSessionSnapshot
            guard service.isLoggedIn,
                  session.userID != nil,
                  service.isCurrentNCMSession(session) else { return nil }
            return .netease(session)
        case .qqmusic:
            let session = qqSession.sessionSnapshot
            guard session.isLoggedIn, session.musicID != nil else { return nil }
            return .qqmusic(session)
        case .kugou:
            let service = KCMMusicService.shared
            let session = service.sessionSnapshot
            guard session.isAuthenticated,
                  session.userID != nil,
                  service.isCurrentSession(session) else { return nil }
            return .kugou(session)
        case .qishui, .appleMusic, .local, nil:
            return nil
        }
    }

    var identityPrimaryMetricValue: String {
        guard loginIdentity.activeSource == .netease else {
            return loginIdentity.activeSource?.shortName ?? "—"
        }
        return listenSongs.map { formatNumber($0) } ?? "—"
    }

    var identityPrimaryMetricLabel: String {
        loginIdentity.activeSource == .netease
            ? String(localized: "profile_total_songs")
            : String(localized: "login_identity_current")
    }

    var identityPrimaryMetricIcon: MonoIcon.IconType {
        loginIdentity.activeSource == .netease ? .headphones : .personCircle
    }

    @AppStorage("isLoggedIn") var isAppLoggedIn = false
    /// Keep the visible root branch stable while UIKit is moving the Profile
    /// navigation controller between tab hosts. Login changes received while
    /// off-screen are committed only after Profile becomes the settled tab.
    @State var displayedLoginState = LoginIdentityManager.shared.hasActiveIdentity

    @State var cachedProfile: UserProfile?
    @State var cachedProfileOwner: ProfileCacheOwner?
    @State var hasAppeared = false
    @State var hasRequestedQQSessionRestore = false
    @State var navigationPath = NavigationPath()

    @State var userLevel: Int?
    @State var listenSongs: Int?
    /// aside 数据带的本周收听秒数（来自听歌统计日志）
    @State var weekListenSeconds: Int?

    @State var downloadedSongCount = DownloadManager.shared.downloadedSongIds.count
    @State var localPlaylistCount = LocalPlaylistManager.shared.playlists.count

    var body: some View {
        let _ = settings.globalThemeRevision

        Group {
            if displayedLoginState {
                loggedInContent
            } else {
                notLoggedInContent
            }
        }
        .task {
            guard await MainTabActivationGate.waitUntilSettled(.profile) else { return }
            let hasActiveIdentity = loginIdentity.hasActiveIdentity
            if displayedLoginState != hasActiveIdentity {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    displayedLoginState = hasActiveIdentity
                }
            }
            downloadedSongCount = DownloadManager.shared.downloadedSongIds.count
            localPlaylistCount = LocalPlaylistManager.shared.playlists.count
            restoreQQSessionIfNeeded()
            await loginIdentity.refreshAvailableIdentities()
            syncDisplayedIdentityProfile()
            if displayedLoginState {
                refreshWeekListeningDuration()
                if let profile = loginIdentity.displayedProfile(ncmProfile: viewModel.userProfile),
                   profile.userId != cachedProfile?.userId
                    || cachedProfileOwner != currentProfileOwner {
                    cacheDisplayedProfile(profile)
                }
                guard !hasAppeared else {
                    GlobalRefreshManager.shared.markProfileDataReady()
                    return
                }
                hasAppeared = true
                try? await Task.sleep(nanoseconds: 100_000_000)
                guard !Task.isCancelled,
                      MainTabActivationGate.isSettled(.profile) else { return }
                cacheDisplayedProfile(
                    loginIdentity.displayedProfile(ncmProfile: viewModel.userProfile)
                )
                GlobalRefreshManager.shared.markProfileDataReady()
                if loginIdentity.activeSource == .netease {
                    fetchUserExtra()
                } else {
                    userLevel = nil
                    listenSongs = nil
                }
                // 移除网易云历史记录抓取，统一使用播放器本地历史
            } else {
                GlobalRefreshManager.shared.markProfileDataReady()
            }
        }
        .onChange(of: isAppLoggedIn) { _, _ in
            guard MainTabActivationGate.isSettled(.profile),
                  displayedLoginState != loginIdentity.hasActiveIdentity else { return }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                displayedLoginState = loginIdentity.hasActiveIdentity
            }
        }
        .onReceive(loginIdentity.$activeSource) { _ in
            guard MainTabActivationGate.isSettled(.profile) else { return }
            syncDisplayedIdentityProfile()
        }
        .onReceive(loginIdentity.$profileRevision.dropFirst()) { _ in
            guard MainTabActivationGate.isSettled(.profile) else { return }
            syncDisplayedIdentityProfile()
        }
        .onReceive(NotificationCenter.default.publisher(for: .mainTabDidSettle)) { notification in
            guard notification.object as? Tab == .profile,
                  MainTabActivationGate.isSettled(.profile) else { return }
            syncDisplayedIdentityProfile()
        }
        .onReceive(GlobalRefreshManager.shared.refreshProfilePublisher) { _ in
            guard MainTabActivationGate.isSettled(.profile) else {
                GlobalRefreshManager.shared.markProfileDataReady()
                return
            }
            if displayedLoginState {
                cacheDisplayedProfile(
                    loginIdentity.displayedProfile(ncmProfile: viewModel.userProfile)
                )
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled else { return }
                GlobalRefreshManager.shared.markProfileDataReady()
            }
        }
        .onReceive(viewModel.$userProfile) { profile in
            if MainTabActivationGate.isSettled(.profile),
               loginIdentity.activeSource == .netease,
               profile != nil {
                cacheDisplayedProfile(loginIdentity.displayedProfile(ncmProfile: profile))
            }
        }
        .onReceive(DownloadManager.shared.$downloadedSongIds.map(\.count).removeDuplicates()) { count in
            guard MainTabActivationGate.isSettled(.profile) else { return }
            downloadedSongCount = count
        }
        .onReceive(LocalPlaylistManager.shared.$playlists.map(\.count).removeDuplicates()) { count in
            guard MainTabActivationGate.isSettled(.profile) else { return }
            localPlaylistCount = count
        }
    }

    // MARK: - Data Fetching

    func fetchUserExtra() {
        guard loginIdentity.activeSource == .netease else { return }
        let apiService = APIService.shared
        let session = apiService.ncmSessionSnapshot
        guard apiService.isLoggedIn, let uid = session.userID else { return }
        apiService.fetchUserDetail(uid: uid)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in },
                  receiveValue: { [self] response in
                      guard loginIdentity.activeSource == .netease,
                            apiService.isCurrentNCMSession(session),
                            response.profile.userId == uid else { return }
                      userLevel = response.level
                      listenSongs = response.listenSongs
                  })
            .store(in: &ProfileCancellableStore.shared.cancellables)
    }

    func syncDisplayedIdentityProfile() {
        let hasActiveIdentity = loginIdentity.hasActiveIdentity
        if displayedLoginState != hasActiveIdentity {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                displayedLoginState = hasActiveIdentity
            }
        }

        cacheDisplayedProfile(
            loginIdentity.displayedProfile(ncmProfile: viewModel.userProfile)
        )
        hasAppeared = false

        if loginIdentity.activeSource == .netease {
            fetchUserExtra()
        } else {
            userLevel = nil
            listenSongs = nil
        }
    }

    func cacheDisplayedProfile(_ profile: UserProfile?) {
        guard let profile,
              let owner = currentProfileOwner,
              profile.userId == owner.userID else {
            cachedProfile = nil
            cachedProfileOwner = nil
            return
        }
        cachedProfile = profile
        cachedProfileOwner = owner
    }

    func formatNumber(_ value: Int) -> String {
        if value >= 10000 {
            return String(format: "%.1fw", Double(value) / 10000)
        }
        return "\(value)"
    }
}
