import SwiftUI
import QQMusicKit

struct PlatformAccountManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var qqSession = QQUserSession.shared
    @ObservedObject private var appleMusicService = AppleMusicService.shared

    @State private var showNeteaseLogin = false
    @State private var showQQAccount = false
    @State private var kugouCookie = ""
    @State private var isKugouAuthenticated = KCMMusicService.shared.isAuthenticated
    @State private var isRequestingAppleMusic = false
    @State private var isProcessingKugouVIP = false
    @State private var kugouStatusMessage: String?

    private var isNeteaseAuthenticated: Bool { APIService.shared.isLoggedIn }

    var body: some View {
        List {
            Section("平台账号") {
                accountRow(
                    source: .netease,
                    name: "NCM",
                    isAuthorized: isNeteaseAuthenticated,
                    actionTitle: isNeteaseAuthenticated ? nil : "授权"
                ) {
                    showNeteaseLogin = true
                }

                accountRow(
                    source: .qqmusic,
                    name: "QCM",
                    isAuthorized: qqSession.isLoggedIn,
                    actionTitle: "管理"
                ) {
                    showQQAccount = true
                }

                accountRow(
                    source: .kugou,
                    name: "KCM",
                    isAuthorized: isKugouAuthenticated,
                    actionTitle: nil,
                    action: {}
                )

                accountRow(
                    source: .appleMusic,
                    name: "Apple Music",
                    isAuthorized: appleMusicService.isAuthorized,
                    actionTitle: appleMusicService.isAuthorized ? nil : "授权"
                ) {
                    requestAppleMusicAuthorization()
                }
                .disabled(isRequestingAppleMusic)
            }

            Section("KCM 授权") {
                SecureField("Cookie", text: $kugouCookie)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button("保存 KCM 授权") {
                    KCMMusicService.shared.applyCookie(kugouCookie)
                    isKugouAuthenticated = KCMMusicService.shared.isAuthenticated
                    kugouCookie = ""
                    kugouStatusMessage = isKugouAuthenticated ? "KCM 授权已保存" : "KCM Cookie 无效"
                }

                if isKugouAuthenticated {
                    Button("退出 KCM", role: .destructive) {
                        KCMMusicService.shared.logout()
                        isKugouAuthenticated = false
                        kugouStatusMessage = nil
                    }
                }
            }

            Section("KCM 概念版会员") {
                Button("领取今日会员") {
                    runKugouVIPAction { try await KCMMusicService.shared.claimDailyLiteVIP() }
                }
                .disabled(!isKugouAuthenticated || isProcessingKugouVIP)

                Button("升级畅听会员") {
                    runKugouVIPAction { try await KCMMusicService.shared.upgradeDailyLiteVIP() }
                }
                .disabled(!isKugouAuthenticated || isProcessingKugouVIP)

                if isProcessingKugouVIP {
                    ProgressView()
                }
                if let kugouStatusMessage {
                    Text(kugouStatusMessage)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(ThemedPageBackground())
        .navigationTitle("平台账号管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    MonologueIcon(icon: .xmark, size: 16)
                }
            }
        }
        .fullScreenCover(isPresented: $showNeteaseLogin) {
            LoginView()
        }
        .monologueSheet(isPresented: $showQQAccount, preset: .large) {
            NavigationStack { QQAccountView() }
        }
    }

    private func accountRow(
        source: MusicSource,
        name: String,
        isAuthorized: Bool,
        actionTitle: String?,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            PlatformBadgeLabel(text: source.shortName, source: source, fontSize: 10)
            Text(name)
            Spacer()
            Text(isAuthorized ? "已授权" : "未授权")
                .font(.caption)
                .foregroundStyle(isAuthorized ? source.themedBadgeColor : .secondary)
            if let actionTitle {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderless)
            }
        }
    }

    private func requestAppleMusicAuthorization() {
        guard !isRequestingAppleMusic else { return }
        isRequestingAppleMusic = true
        Task { @MainActor in
            _ = await appleMusicService.requestAuthorizationIfNeeded()
            isRequestingAppleMusic = false
        }
    }

    private func runKugouVIPAction(_ operation: @escaping () async throws -> Bool) {
        guard !isProcessingKugouVIP else { return }
        isProcessingKugouVIP = true
        kugouStatusMessage = nil
        Task { @MainActor in
            do {
                let succeeded = try await operation()
                kugouStatusMessage = succeeded ? "操作成功" : "操作未完成"
            } catch {
                kugouStatusMessage = error.localizedDescription
            }
            isProcessingKugouVIP = false
        }
    }
}
