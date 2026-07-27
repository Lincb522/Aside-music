import SwiftUI

@MainActor
struct PlatformAccountSwitchingView: View {
    var body: some View {
        ZStack {
            DeveloperDiagnosticBackdrop()

            ScrollView {
                VStack(spacing: SettingsPageLayout.deepSectionSpacing) {
                    DeveloperDiagnosticHeader(
                        title: "平台切号管理",
                        status: "QCM · KCM",
                        icon: .personCircle,
                        tint: .cyan
                    )

                    SettingsSection(title: "平台") {
                        NavigationLink {
                            QCMAccountSwitchingView()
                        } label: {
                            developerPlatformRow(source: .qqmusic, title: "QCM", value: "凭证")
                        }
                        .buttonStyle(.plain)

                        developerDivider

                        NavigationLink {
                            KCMAccountSwitchingView()
                        } label: {
                            developerPlatformRow(source: .kugou, title: "KCM", value: "账号池")
                        }
                        .buttonStyle(.plain)
                    }

                    FloatingBarBottomSpacer()
                }
                .padding(.horizontal, DeviceLayout.settingsSectionHorizontalPadding)
                .padding(.bottom, 44)
                .iPadContentWidth(SettingsPageLayout.contentWidth)
            }
            .scrollIndicators(.hidden)
        }
        .developerDiagnosticPageChrome()
    }

    private var developerDivider: some View {
        Divider()
            .overlay(Color.white.opacity(0.08))
            .padding(.leading, 58)
    }

    private func developerPlatformRow(
        source: MusicSource,
        title: String,
        value: String
    ) -> some View {
        HStack(spacing: 12) {
            PlatformBadgeLabel(text: title, source: source, fontSize: 9)
                .frame(width: 34, height: 34)

            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            Spacer(minLength: 8)

            Text(value)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))

            MonoIcon(icon: .chevronRight, size: 12, color: .white.opacity(0.35))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

@MainActor
private struct QCMAccountSwitchingView: View {
    @State private var credentials: [QCMStoredCredential] = []
    @State private var isLoading = false
    @State private var processingID: String?
    @State private var errorMessage: String?
    @State private var isShowingError = false

    var body: some View {
        ZStack {
            DeveloperDiagnosticBackdrop()

            ScrollView {
                VStack(spacing: SettingsPageLayout.deepSectionSpacing) {
                    DeveloperDiagnosticHeader(
                        title: "QCM 切号",
                        status: "\(credentials.count) 个凭证",
                        icon: .personCircle,
                        tint: .cyan
                    )

                    accountSections

                    FloatingBarBottomSpacer()
                }
                .padding(.horizontal, DeviceLayout.settingsSectionHorizontalPadding)
                .padding(.bottom, 44)
                .iPadContentWidth(SettingsPageLayout.contentWidth)
            }
            .scrollIndicators(.hidden)
            .refreshable { await load() }
        }
        .developerDiagnosticPageChrome()
        .task { await load() }
        .alert("操作失败", isPresented: $isShowingError) {
            Button("好", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var accountSections: some View {
        if isLoading && credentials.isEmpty {
            DeveloperSwitchingStateSection(title: "账号", text: "正在加载")
        } else if credentials.isEmpty {
            DeveloperSwitchingStateSection(title: "账号", text: "暂无凭证")
        } else {
            ForEach([QCMMembershipLevel.svip, .vip, .standard], id: \.self) { level in
                let items = credentials.filter { $0.membershipLevel == level }
                if !items.isEmpty {
                    SettingsSection(title: "\(level.displayName) · \(items.count)") {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, credential in
                            DeveloperSwitchingAccountRow(
                                source: .qqmusic,
                                avatarURL: credential.avatarURL,
                                title: credential.nickname ?? credential.id,
                                subtitle: qcmSubtitle(credential),
                                isActive: credential.isActive,
                                isProcessing: processingID == credential.id,
                                onActivate: { activate(credential) }
                            )
                            .contextMenu {
                                Button("刷新") { refresh(credential) }
                            }

                            if index < items.count - 1 {
                                DeveloperSwitchingDivider()
                            }
                        }
                    }
                }
            }
        }
    }

    private func qcmSubtitle(_ credential: QCMStoredCredential) -> String {
        if let musicID = credential.musicId {
            return "\(credential.loginProvider.displayName) · Music ID \(musicID)"
        }
        return credential.loginProvider.displayName
    }

    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            credentials = try await APIService.shared.fetchQCMStoredCredentials()
        } catch {
            showError(error)
        }
    }

    private func activate(_ credential: QCMStoredCredential) {
        perform(credential) {
            try await APIService.shared.activateQCMStoredCredential(credentialID: credential.id)
        }
    }

    private func refresh(_ credential: QCMStoredCredential) {
        perform(credential) {
            try await APIService.shared.refreshQCMStoredCredential(credentialID: credential.id)
        }
    }

    private func perform(
        _ credential: QCMStoredCredential,
        operation: @escaping () async throws -> [QCMStoredCredential]
    ) {
        guard processingID == nil else { return }
        processingID = credential.id
        Task { @MainActor in
            defer { processingID = nil }
            do {
                credentials = try await operation()
                HapticManager.shared.success()
            } catch {
                showError(error)
            }
        }
    }

    private func showError(_ error: Error) {
        errorMessage = error.localizedDescription
        isShowingError = true
    }
}

@MainActor
private struct KCMAccountSwitchingView: View {
    @State private var accounts: [KCMStoredAccount] = []
    @State private var poolEnabled = false
    @State private var confirmedPoolEnabled = false
    @State private var isLoading = false
    @State private var processingID: String?
    @State private var errorMessage: String?
    @State private var isShowingError = false

    var body: some View {
        ZStack {
            DeveloperDiagnosticBackdrop()

            ScrollView {
                VStack(spacing: SettingsPageLayout.deepSectionSpacing) {
                    DeveloperDiagnosticHeader(
                        title: "KCM 切号",
                        status: "\(accounts.count) 个账号",
                        icon: .personCircle,
                        tint: .orange
                    )

                    SettingsSection(title: "账号池") {
                        HStack(spacing: 12) {
                            MonoIcon(icon: .cloud, size: 16, color: .orange)
                                .frame(width: 34, height: 34)
                                .background(Color.orange.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

                            Text("启用账号池")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)

                            Spacer()

                            Toggle("", isOn: $poolEnabled)
                                .labelsHidden()
                                .tint(.orange)
                                .disabled(processingID != nil)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .onChange(of: poolEnabled) { enabled in
                            guard enabled != confirmedPoolEnabled else { return }
                            updatePoolEnabled(enabled)
                        }
                    }

                    accountSections

                    FloatingBarBottomSpacer()
                }
                .padding(.horizontal, DeviceLayout.settingsSectionHorizontalPadding)
                .padding(.bottom, 44)
                .iPadContentWidth(SettingsPageLayout.contentWidth)
            }
            .scrollIndicators(.hidden)
            .refreshable { await load() }
        }
        .developerDiagnosticPageChrome()
        .task { await load() }
        .alert("操作失败", isPresented: $isShowingError) {
            Button("好", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var accountSections: some View {
        if isLoading && accounts.isEmpty {
            DeveloperSwitchingStateSection(title: "账号", text: "正在加载")
        } else if accounts.isEmpty {
            DeveloperSwitchingStateSection(title: "账号", text: "暂无账号")
        } else {
            ForEach([KCMMembershipLevel.full, .trial, .none], id: \.self) { level in
                let members = accounts.filter { $0.membershipLevel == level }
                if !members.isEmpty {
                    SettingsSection(title: "\(level.displayName) · \(members.count)") {
                        ForEach(Array(members.enumerated()), id: \.element.id) { index, account in
                            DeveloperSwitchingAccountRow(
                                source: .kugou,
                                avatarURL: account.avatarUrl.flatMap(URL.init(string:)),
                                title: account.nickname ?? "KCM",
                                subtitle: "ID \(account.userId)",
                                isActive: account.isActive,
                                isProcessing: processingID == account.id,
                                onActivate: { activate(account) }
                            )

                            if index < members.count - 1 {
                                DeveloperSwitchingDivider()
                            }
                        }
                    }
                }
            }
        }
    }

    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            if let state = try await APIService.shared.fetchKCMAccountPoolState() {
                apply(state)
            }
        } catch {
            showError(error)
        }
    }

    private func activate(_ account: KCMStoredAccount) {
        guard processingID == nil else { return }
        processingID = account.id
        Task { @MainActor in
            defer { processingID = nil }
            do {
                if let state = try await APIService.shared.activateKCMAccountPoolAccount(accountID: account.id) {
                    apply(state)
                }
                HapticManager.shared.success()
            } catch {
                showError(error)
            }
        }
    }

    private func updatePoolEnabled(_ enabled: Bool) {
        guard processingID == nil else { return }
        let previous = confirmedPoolEnabled
        processingID = "pool"
        Task { @MainActor in
            defer { processingID = nil }
            do {
                if let state = try await APIService.shared.setKCMAccountPoolEnabled(enabled) {
                    apply(state)
                } else {
                    confirmedPoolEnabled = enabled
                }
                HapticManager.shared.success()
            } catch {
                poolEnabled = previous
                showError(error)
            }
        }
    }

    private func apply(_ state: KCMAccountPoolState) {
        confirmedPoolEnabled = state.enabled
        poolEnabled = state.enabled
        accounts = state.accounts
    }

    private func showError(_ error: Error) {
        errorMessage = error.localizedDescription
        isShowingError = true
    }
}

private struct DeveloperSwitchingAccountRow: View {
    let source: MusicSource
    let avatarURL: URL?
    let title: String
    let subtitle: String
    let isActive: Bool
    let isProcessing: Bool
    let onActivate: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            CachedAsyncImage(url: avatarURL) {
                Circle()
                    .fill(source.themedBadgeColor.opacity(0.14))
                    .overlay {
                        MonoIcon(icon: .personCircle, size: 18, color: .white.opacity(0.42))
                    }
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 42, height: 42)
            .clipShape(Circle())
            .overlay(alignment: .bottomTrailing) {
                PlatformBadgeLabel(text: source.shortName, source: source, fontSize: 6.5)
                    .offset(x: 3, y: 2)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if isProcessing {
                ProgressView()
                    .tint(.white)
            } else if isActive {
                Label("当前", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.green)
            } else {
                Button("切换", action: onActivate)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(source.themedBadgeColor.opacity(0.2))
                    .clipShape(Capsule())
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

private struct DeveloperSwitchingDivider: View {
    var body: some View {
        Divider()
            .overlay(Color.white.opacity(0.08))
            .padding(.leading, 70)
    }
}

private struct DeveloperSwitchingStateSection: View {
    let title: String
    let text: String

    var body: some View {
        SettingsSection(title: title) {
            HStack(spacing: 10) {
                if text == "正在加载" {
                    ProgressView()
                        .tint(.white)
                }
                Text(text)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }
}
