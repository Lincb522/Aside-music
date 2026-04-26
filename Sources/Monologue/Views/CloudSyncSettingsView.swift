import SwiftUI

struct CloudSyncSettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var onlineAccess = OnlineAccessManager.shared
    @ObservedObject private var playlistCloudSync = LocalPlaylistCloudSyncManager.shared

    @State private var showClearCloudConfirm = false

    var body: some View {
        ZStack {
            ThemedSettingsBackground()

            ScrollView {
                VStack(spacing: 20) {
                    syncSection
                    actionSection
                    FloatingBarBottomSpacer()
                }
                .padding(.horizontal, DeviceLayout.isPad ? 32 : 24)
                .iPadContentWidth(700)
            }
            .scrollIndicators(.hidden)
        }
        .themedNavigationChrome(title: String(localized: "settings_navigation_cloud_sync_title"), eyebrow: "SYNC", icon: .cloud)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onChange(of: settings.playlistSyncAutoEnabled) { _, enabled in
            guard enabled else { return }
            playlistCloudSync.resumeAutomaticSync()
        }
        .confirmationDialog(
            String(localized: "playlist_sync_clear_cloud_button"),
            isPresented: $showClearCloudConfirm
        ) {
            Button(String(localized: "playlist_sync_clear_cloud_confirm"), role: .destructive) {
                Task {
                    do {
                        try await playlistCloudSync.clearCloudSnapshot()
                    } catch {
                        showFailure(error)
                    }
                }
            }
        } message: {
            Text(String(localized: "playlist_sync_clear_cloud_message"))
        }
    }

    private var syncSection: some View {
        SettingsSection(title: String(localized: "settings_navigation_cloud_sync_title")) {
            VStack(spacing: 0) {
                SettingsToggleRow(
                    icon: .cloud,
                    title: String(localized: "playlist_sync_auto_toggle_title"),
                    subtitle: String(localized: "playlist_sync_auto_toggle_desc"),
                    isOn: $settings.playlistSyncAutoEnabled
                )

                Divider()
                    .opacity(0.4)
                    .padding(.leading, 62)

                SettingsToggleRow(
                    icon: .trash,
                    title: String(localized: "playlist_sync_delete_remote_toggle_title"),
                    subtitle: String(localized: "playlist_sync_delete_remote_toggle_desc"),
                    isOn: $settings.playlistSyncDeleteCloudSnapshot
                )

                Divider()
                    .opacity(0.4)
                    .padding(.leading, 62)

                SettingsInfoRow(
                    icon: playlistCloudSync.isSyncing ? .sparkle : .cloud,
                    title: String(localized: "playlist_sync_status_title"),
                    value: playlistSyncStatusText
                )
            }
        }
    }

    private var actionSection: some View {
        SettingsSection(title: String(localized: "playlist_sync_actions_title")) {
            VStack(spacing: 0) {
                actionRow(
                    icon: .save,
                    title: String(localized: "playlist_sync_upload_button"),
                    action: {
                        Task {
                            do {
                                _ = try await playlistCloudSync.syncToCloud()
                            } catch {
                                showFailure(error)
                            }
                        }
                    }
                )

                Divider()
                    .opacity(0.4)
                    .padding(.leading, 62)

                actionRow(
                    icon: .download,
                    title: String(localized: "playlist_sync_restore_button"),
                    action: {
                        Task {
                            do {
                                _ = try await playlistCloudSync.restoreFromCloud()
                            } catch {
                                showFailure(error)
                            }
                        }
                    }
                )

                Divider()
                    .opacity(0.4)
                    .padding(.leading, 62)

                actionRow(
                    icon: .trash,
                    title: String(localized: "playlist_sync_clear_cloud_button"),
                    isDestructive: true,
                    action: {
                        showClearCloudConfirm = true
                    }
                )
            }
            .disabled(!onlineAccess.canUseOnlineFeatures || playlistCloudSync.isSyncing)
            .opacity((!onlineAccess.canUseOnlineFeatures || playlistCloudSync.isSyncing) ? 0.55 : 1)
        }
    }

    private func actionRow(
        icon: MonologueIcon.IconType,
        title: String,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        SettingsButtonRow(
            icon: icon,
            title: title,
            titleColor: isDestructive ? .red : .monologueTextPrimary,
            action: action
        )
    }

    private var playlistSyncStatusText: String {
        if let message = playlistCloudSync.lastStatusMessage, !message.isEmpty {
            if let date = playlistCloudSync.lastSyncedAt {
                return "\(message) · \(date.formatted(date: .abbreviated, time: .shortened))"
            }
            return message
        }
        return String(localized: "playlist_sync_idle")
    }

    private func showFailure(_ error: Error) {
        AlertManager.shared.show(
            title: String(localized: "playlist_sync_failed_title"),
            message: String(
                format: String(localized: "playlist_sync_failed_format"),
                locale: Locale.current,
                error.localizedDescription
            ),
            primaryButtonTitle: String(localized: "common_ok"),
            primaryAction: {}
        )
    }
}
