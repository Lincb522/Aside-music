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

    var viewModel: HomeViewModel {
        HomeViewModel.shared
    }

    var playerManager: PlayerManager {
        PlayerManager.shared
    }

    @AppStorage("isLoggedIn") var isAppLoggedIn = false
    /// Keep the visible root branch stable while UIKit is moving the Profile
    /// navigation controller between tab hosts. Login changes received while
    /// off-screen are committed only after Profile becomes the settled tab.
    @State var displayedLoginState = UserDefaults.standard.bool(forKey: "isLoggedIn")

    @State var cachedProfile: UserProfile?
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
            if displayedLoginState != isAppLoggedIn {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    displayedLoginState = isAppLoggedIn
                }
            }
            downloadedSongCount = DownloadManager.shared.downloadedSongIds.count
            localPlaylistCount = LocalPlaylistManager.shared.playlists.count
            restoreQQSessionIfNeeded()
            if displayedLoginState {
                refreshWeekListeningDuration()
                if let profile = viewModel.userProfile, profile.userId != cachedProfile?.userId {
                    cachedProfile = profile
                }
                guard !hasAppeared else {
                    GlobalRefreshManager.shared.markProfileDataReady()
                    return
                }
                hasAppeared = true
                try? await Task.sleep(nanoseconds: 100_000_000)
                guard !Task.isCancelled,
                      MainTabActivationGate.isSettled(.profile) else { return }
                cachedProfile = viewModel.userProfile
                GlobalRefreshManager.shared.markProfileDataReady()
                fetchUserExtra()
                // 移除网易云历史记录抓取，统一使用播放器本地历史
            } else {
                GlobalRefreshManager.shared.markProfileDataReady()
            }
        }
        .onChange(of: isAppLoggedIn) { _, newValue in
            guard MainTabActivationGate.isSettled(.profile),
                  displayedLoginState != newValue else { return }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                displayedLoginState = newValue
            }
        }
        .onReceive(GlobalRefreshManager.shared.refreshProfilePublisher) { _ in
            guard MainTabActivationGate.isSettled(.profile) else {
                GlobalRefreshManager.shared.markProfileDataReady()
                return
            }
            if displayedLoginState {
                cachedProfile = viewModel.userProfile
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled else { return }
                GlobalRefreshManager.shared.markProfileDataReady()
            }
        }
        .onReceive(viewModel.$userProfile) { profile in
            if MainTabActivationGate.isSettled(.profile), profile != nil {
                cachedProfile = profile
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
        guard let uid = APIService.shared.currentUserId else { return }
        APIService.shared.fetchUserDetail(uid: uid)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in },
                  receiveValue: { [self] response in
                      userLevel = response.level
                      listenSongs = response.listenSongs
                  })
            .store(in: &ProfileCancellableStore.shared.cancellables)
    }

    func formatNumber(_ value: Int) -> String {
        if value >= 10000 {
            return String(format: "%.1fw", Double(value) / 10000)
        }
        return "\(value)"
    }
}
