//
//  SettingsView.swift
//  Monologue
//
//  设置界面
//

import SwiftUI

private func settingsText(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

private func settingsFormat(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: settingsText(key), locale: Locale.current, arguments: arguments)
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var systemColorScheme
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var onlineAccess = OnlineAccessManager.shared
    @ObservedObject private var playlistCloudSync = LocalPlaylistCloudSyncManager.shared
    @State private var cacheSize: String = String(localized: "settings_calculating")
    @State private var viewRefreshID = UUID()
    @AppStorage("qqDevMode") private var qqDevMode = false
    @State private var apiTokenInput: String = SecureConfig.apiToken ?? ""
    @State private var tokenSaved = false
    @State private var isHeaderCardExpanded = false

    var body: some View {
        ZStack {
            MonologueBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    settingsHeaderCard
                        .padding(.top, 8)

                    themeSection

                    navigationCardsSection

                    if qqDevMode {
                        otherSection
                    }

                    Spacer(minLength: 100)
                }
                .padding(.horizontal, DeviceLayout.isPad ? 32 : 24)
                .iPadContentWidth(700)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(String(localized: "settings_title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear {
            updateCacheSize()
            apiTokenInput = SecureConfig.apiToken ?? ""
            isHeaderCardExpanded = false
        }
        .preferredColorScheme(settings.preferredColorScheme)
        .onChange(of: settings.themeMode) { _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                viewRefreshID = UUID()
            }
        }
        .onChange(of: systemColorScheme) { _, _ in
            if settings.themeMode == "system" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    viewRefreshID = UUID()
                }
            }
        }
        .id(viewRefreshID)
    }

    // MARK: - 日夜模式

    private var themeSection: some View {
        SettingsSection(title: String(localized: "settings_appearance")) {
            SettingsThemeRow(
                icon: .sparkle,
                title: String(localized: "settings_theme_mode"),
                selection: $settings.themeMode
            )
        }
    }

    // MARK: - 导航入口卡片

    private var navigationCardsSection: some View {
        VStack(spacing: 14) {
            SettingsLinkRow(
                icon: .sparkle,
                title: settingsText("settings_navigation_appearance_title"),
                subtitle: settingsText("settings_navigation_appearance_subtitle"),
                destination: AppearanceSettingsView(),
                verticalPadding: 16
            )
            .monologueGlass(cornerRadius: 22)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)

            SettingsLinkRow(
                icon: .soundQuality,
                title: settingsText("settings_navigation_playback_title"),
                subtitle: settingsText("settings_navigation_playback_subtitle"),
                destination: PlaybackSettingsView(),
                verticalPadding: 16
            )
            .monologueGlass(cornerRadius: 22)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)

            SettingsLinkRow(
                icon: .cloud,
                title: settingsText("settings_navigation_cloud_sync_title"),
                subtitle: hasToken ? playlistSyncStatusText : settingsText("settings_navigation_cloud_sync_disabled"),
                destination: CloudSyncSettingsView(),
                verticalPadding: 16
            )
            .monologueGlass(cornerRadius: 22)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
        }
    }


    // MARK: - 存储管理

    private var cacheSection: some View {
        SettingsSection(title: String(localized: "settings_storage")) {
            SettingsLinkRow(
                icon: .storage,
                title: String(localized: "settings_storage_manage"),
                subtitle: String(localized: "settings_storage_manage_desc"),
                value: cacheSize,
                destination: StorageManageView()
            )
        }
    }

    // MARK: - 下载管理

    private var downloadSection: some View {
        SettingsSection(title: String(localized: "settings_download_manage")) {
            SettingsLinkRow(
                icon: .download,
                title: String(localized: "settings_download_manage"),
                destination: DownloadManageView()
            )
        }
    }

    // MARK: - 设置顶部卡片

    private var hasToken: Bool {
        !(SecureConfig.apiToken ?? "").isEmpty
    }

    private var maskedToken: String {
        let token = SecureConfig.apiToken ?? ""
        guard token.count > 2 else { return String(repeating: "•", count: 8) }
        return String(token.prefix(2)) + String(repeating: "•", count: token.count - 2)
    }

    private var headerActionButtonWidth: CGFloat {
        DeviceLayout.isPad ? 96 : 90
    }

    private var headerFooterText: String {
        if hasToken {
            return settingsText("settings_header_footer_authorized")
        }
        return settingsText("settings_header_footer_unauthorized")
    }

    private var headerFooterIconName: String {
        hasToken ? "heart.fill" : "info.circle.fill"
    }

    private var headerFooterIconColor: Color {
        hasToken ? .pink : .monologueAccent
    }

    private var headerFooterTextColor: Color {
        hasToken ? .monologueTextSecondary.opacity(0.72) : .monologueTextSecondary.opacity(0.56)
    }

    private var headerStatusButtonBackground: Color {
        if tokenSaved || hasToken {
            return Color.green.opacity(0.12)
        }
        return Color.monologueSeparator.opacity(0.5)
    }

    private var playlistSyncStatusText: String {
        if let message = playlistCloudSync.lastStatusMessage, !message.isEmpty {
            if let date = playlistCloudSync.lastSyncedAt {
                return "\(message) · \(date.formatted(date: .abbreviated, time: .shortened))"
            }
            return message
        }
        return settingsText("playlist_sync_idle")
    }

    private var settingsHeaderCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image("WeChatAvatar")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: .black.opacity(0.08), radius: 3, y: 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text("ZIJIU522")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.monologueTextPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)

                    HStack(spacing: 5) {
                        MonologueIcon(icon: .comment, size: 12, color: .green)
                        Text(settingsText("settings_developer_status"))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.monologueTextSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .layoutPriority(1)

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 6) {
                    NavigationLink(destination: AboutView()) {
                        Text(String(localized: "settings_about"))
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.monologueTextSecondary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.monologueSeparator.opacity(0.5)))
                    }
                    .frame(width: headerActionButtonWidth)
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.92))

                    Button {
                        apiTokenInput = SecureConfig.apiToken ?? apiTokenInput
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
                            isHeaderCardExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            MonologueIcon(
                                icon: hasToken ? .lock : .unlock,
                                size: 10,
                                color: tokenStatusColor
                            )

                            Text(tokenStatusText)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .minimumScaleFactor(0.84)

                            Image(systemName: isHeaderCardExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(tokenStatusColor)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(headerStatusButtonBackground)
                        )
                    }
                    .frame(width: headerActionButtonWidth)
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.92))
                }
                .layoutPriority(2)
            }

            if isHeaderCardExpanded {
                VStack(spacing: 16) {
                    HStack(spacing: 10) {
                        Button {
                            PlatformPasteboard.copy("Fallin-Out0122")
                            HapticManager.shared.success()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                wechatCopied = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation { wechatCopied = false }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                MonologueIcon(icon: wechatCopied ? .checkmark : .save, size: 13, color: wechatCopied ? .green : .monologueTextPrimary)
                                Text(wechatCopied ? settingsText("settings_contact_copied") : "Fallin-Out0122")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                            }
                            .foregroundColor(wechatCopied ? .green : .monologueTextPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(wechatCopied ? Color.green.opacity(0.1) : Color.monologueSeparator.opacity(0.4))
                            )
                        }
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))

                        Button {
                            PlatformPasteboard.copy("Fallin-Out0122")
                            HapticManager.shared.success()
                            if let url = URL(string: "weixin://dl/contacts") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                MonologueIcon(icon: .send, size: 13, color: .white)
                                Text(settingsText("settings_open_wechat"))
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(red: 0.07, green: 0.73, blue: 0.37), Color(red: 0.05, green: 0.6, blue: 0.32)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                        }
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            MonologueIcon(icon: hasToken ? .lock : .unlock, size: 14, color: hasToken ? .green : .monologueAccent)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(settingsText("access_token_title"))
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundColor(.monologueTextPrimary)

                                if hasToken {
                                    if OnlineAccessManager.shared.lastTokenStatus == .expired {
                                        Text("当前已过期：" + maskedToken)
                                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                                            .foregroundColor(.red.opacity(0.8))
                                    } else {
                                        Text(settingsFormat("settings_token_authorized_format", maskedToken))
                                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                                            .foregroundColor(.monologueTextSecondary)
                                    }
                                } else {
                                    Text(settingsText("settings_token_hint"))
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .foregroundColor(.monologueTextSecondary.opacity(0.7))
                                }
                            }

                            Spacer()
                        }

                        HStack(spacing: 10) {
                            HStack(spacing: 8) {
                                MonologueIcon(icon: .unlock, size: 14, color: .monologueAccent)
                                TextField(settingsText("access_token_input_placeholder"), text: $apiTokenInput)
                                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                                    .monologueTextInputBehavior()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.monologueSeparator.opacity(0.22))
                            )

                            Button {
                                let trimmed = apiTokenInput.trimmingCharacters(in: .whitespacesAndNewlines)
                                apiTokenInput = trimmed

                                Task {
                                    let status = await onlineAccess.submitToken(trimmed)

                                    await MainActor.run {
                                        switch status {
                                        case .valid, .validationDisabled:
                                            HapticManager.shared.success()
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) {
                                                tokenSaved = !trimmed.isEmpty
                                                isHeaderCardExpanded = trimmed.isEmpty
                                            }

                                            if tokenSaved {
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                                    withAnimation { tokenSaved = false }
                                                }
                                            }
                                        case .missing:
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) {
                                                tokenSaved = false
                                                isHeaderCardExpanded = true
                                            }
                                        case .invalid:
                                            AlertManager.shared.show(
                                                title: settingsText("access_invalid_title"),
                                                message: settingsText("access_invalid_message"),
                                                primaryButtonTitle: settingsText("common_ok"),
                                                primaryAction: {}
                                            )
                                        case .expired:
                                            AlertManager.shared.show(
                                                title: String(localized: "Token 已过期"),
                                                message: String(localized: "您输入的 Token 已经过期，请获取新的 Token 或者重新授权。"),
                                                primaryButtonTitle: settingsText("common_ok"),
                                                primaryAction: {}
                                            )
                                        case .deviceMismatch:
                                            AlertManager.shared.show(
                                                title: String(localized: "设备不匹配"),
                                                message: String(localized: "此 Token 已绑定到其他设备，无法在当前设备使用。"),
                                                primaryButtonTitle: settingsText("common_ok"),
                                                primaryAction: {}
                                            )
                                        case .networkError:
                                            AlertManager.shared.show(
                                                title: settingsText("access_network_error_title"),
                                                message: settingsText("access_network_error_message"),
                                                primaryButtonTitle: settingsText("common_ok"),
                                                primaryAction: {}
                                            )
                                        }
                                    }
                                }
                            } label: {
                                Text(settingsText("common_save"))
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(Color(light: .white, dark: .black))
                                    .frame(width: 44, height: 36)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(Color.monologueAccent)
                                    )
                            }
                            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.92))
                        }

                    }

                }
                .padding(.top, 16)
                .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            }

            HStack(spacing: 6) {
                Image(systemName: headerFooterIconName)
                    .font(.system(size: 10))
                    .foregroundColor(headerFooterIconColor)

                Text(headerFooterText)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(headerFooterTextColor)
                    .lineLimit(2)
                    .minimumScaleFactor(0.84)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.top, isHeaderCardExpanded ? 14 : 12)
            .transition(.opacity)
        }
        .padding(16)
        .monologueGlass(cornerRadius: 22)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var otherSection: some View {
        SettingsSection(title: String(localized: "settings_other")) {
            VStack(spacing: 0) {
                SettingsLinkRow(
                    icon: .logDebug,
                    title: String(localized: "settings_debug_log"),
                    subtitle: String(localized: "settings_debug_log_desc"),
                    value: "\(AppLogger.getAllLogs().count)",
                    destination: DebugLogView()
                )
            }
        }
    }

    @State private var wechatCopied = false

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
    
    private var tokenStatusText: String {
        if tokenSaved {
            return settingsText("settings_token_saved")
        }
        if hasToken {
            if OnlineAccessManager.shared.lastTokenStatus == .expired {
                return String(localized: "已过期")
            }
            return settingsText("settings_token_authorized")
        }
        return settingsText("settings_token_unauthorized")
    }
    
    private var tokenStatusColor: Color {
        if tokenSaved || hasToken {
            if OnlineAccessManager.shared.lastTokenStatus == .expired {
                return .red
            }
            return .green
        }
        return .monologueTextSecondary
    }

    // MARK: - Actions

    private func updateCacheSize() {
        Task { @MainActor in
            let fm = FileManager.default
            var total: Int64 = 0

            guard let cacheBase = fm.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
            let cacheDir = cacheBase.appendingPathComponent("MonologueCache")
            if let files = try? fm.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.totalFileAllocatedSizeKey], options: .skipsHiddenFiles) {
                for f in files {
                    total += Int64((try? f.resourceValues(forKeys: [.totalFileAllocatedSizeKey]))?.totalFileAllocatedSize ?? 0)
                }
            }

            if let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                let dbPath = appSupport.appendingPathComponent("default.store").path
                for ext in ["", ".wal", ".shm"] {
                    let p = ext.isEmpty ? dbPath : dbPath + ext
                    if let attrs = try? fm.attributesOfItem(atPath: p), let s = attrs[.size] as? Int64 { total += s }
                }
            }

            total += DownloadManager.shared.totalDownloadSize()

            cacheSize = ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
        }
    }

    private func clearCache() {
        OptimizedCacheManager.shared.clearAll()
        CacheManager.shared.clearAll()
        CachedAsyncImage<EmptyView>.clearMemoryCache()
        URLCache.shared.removeAllCachedResponses()
        updateCacheSize()
    }
}

// MARK: - Settings Icon Badge

struct SettingsIconBadge: View {
    let icon: MonologueIcon.IconType

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.monologueIconBackground)
                .frame(width: 30, height: 30)
            MonologueIcon(icon: icon, size: 14, color: .monologueIconForeground)
        }
    }
}

// MARK: - Settings Section

struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.leading, 14)
                .tracking(0.4)

            VStack(spacing: 0) {
                content
            }
            .monologueGlass(cornerRadius: 20)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
}

// MARK: - Settings Rows

struct SettingsSwitchToggleStyle: ToggleStyle {
    @Environment(\.colorScheme) private var colorScheme

    private var offTrackColor: Color {
        Color(light: Color.black.opacity(0.12), dark: Color.white.opacity(0.2))
    }

    private var offStrokeColor: Color {
        Color(light: Color.black.opacity(0.08), dark: Color.white.opacity(0.14))
    }

    private func knobColor(isOn: Bool) -> Color {
        if isOn {
            return colorScheme == .dark ? .black : .white
        }
        return .white
    }

    private func strokeColor(isOn: Bool) -> Color {
        if isOn {
            return Color.monologueToggleTint.opacity(colorScheme == .dark ? 0.24 : 0.08)
        }
        return offStrokeColor
    }

    var trackSize: CGSize { CGSize(width: 52, height: 32) }

    func makeBody(configuration: Configuration) -> some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.84)) {
                configuration.isOn.toggle()
            }
        } label: {
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule()
                    .fill(configuration.isOn ? Color.monologueToggleTint : offTrackColor)
                    .overlay {
                        Capsule()
                            .stroke(strokeColor(isOn: configuration.isOn), lineWidth: 1)
                    }
                    .frame(width: trackSize.width, height: trackSize.height)

                Circle()
                    .fill(knobColor(isOn: configuration.isOn))
                    .frame(width: 28, height: 28)
                    .padding(2)
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.32 : 0.12), radius: 6, x: 0, y: 2)
            }
        }
        .buttonStyle(.plain)
    }
}

struct SettingsToggleRow: View {
    let icon: MonologueIcon.IconType
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            SettingsIconBadge(icon: icon)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.monologueTextPrimary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(SettingsSwitchToggleStyle())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }
}

struct SettingsNavigationRow: View {
    let icon: MonologueIcon.IconType
    let title: String
    var subtitle: String? = nil
    var subtitleColor: Color? = nil
    var value: String? = nil
    let action: () -> Void

    init(icon: MonologueIcon.IconType, title: String, value: String, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.value = value
        self.action = action
    }

    init(icon: MonologueIcon.IconType, title: String, subtitle: String? = nil, subtitleColor: Color? = nil, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.subtitleColor = subtitleColor
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                SettingsIconBadge(icon: icon)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.monologueTextPrimary)

                    if let subtitle {
                        if let subtitleColor {
                            Text(subtitle)
                                .font(.system(size: 11, weight: .regular, design: .rounded))
                                .foregroundColor(subtitleColor)
                        } else {
                            Text(subtitle)
                                .font(.system(size: 11, weight: .regular, design: .rounded))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Spacer()

                if let value {
                    Text(value)
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                MonologueIcon(icon: .chevronRight, size: 11, color: .secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
        }
        .buttonStyle(.plain)
    }
}

struct SettingsLinkRow<Destination: View>: View {
    let icon: MonologueIcon.IconType
    let title: String
    var subtitle: String? = nil
    var value: String? = nil
    let destination: Destination
    /// 相对默认行略增高入口卡片（设置主页「外观/播放」等）
    var verticalPadding: CGFloat = 11

    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 12) {
                SettingsIconBadge(icon: icon)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.monologueTextPrimary)

                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                if let value {
                    Text(value)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                MonologueIcon(icon: .chevronRight, size: 11, color: .secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, verticalPadding)
        }
        .buttonStyle(.plain)
    }
}

struct SettingsInfoRow: View {
    let icon: MonologueIcon.IconType
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            SettingsIconBadge(icon: icon)

            Text(title)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.monologueTextPrimary)

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }
}

struct SettingsButtonRow: View {
    let icon: MonologueIcon.IconType
    let title: String
    var titleColor: Color = .monologueTextPrimary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                SettingsIconBadge(icon: icon)

                Text(title)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(titleColor)

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 主题选择行

struct SettingsThemeRow: View {
    let icon: MonologueIcon.IconType
    let title: String
    @Binding var selection: String

    @Environment(\.colorScheme) private var systemColorScheme

    private var isDark: Bool {
        switch selection {
        case "dark": return true
        case "light": return false
        default: return systemColorScheme == .dark
        }
    }

    private var isAuto: Bool { selection == "system" }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                SettingsIconBadge(icon: icon)

                Text(String(localized: "settings_theme_auto"))
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.monologueTextPrimary)

                Spacer()

                Toggle("", isOn: Binding(
                    get: { isAuto },
                    set: { newValue in
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                            selection = newValue ? "system" : (systemColorScheme == .dark ? "dark" : "light")
                        }
                    }
                ))
                .labelsHidden()
                .toggleStyle(SettingsSwitchToggleStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)

            if !isAuto {
                Divider()
                    .opacity(0.4)
                    .padding(.leading, 62)

                HStack(spacing: 14) {
                    SettingsIconBadge(icon: isDark ? .moon : .sun)

                    Text(isDark ? String(localized: "settings_theme_dark") : String(localized: "settings_theme_light"))
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.monologueTextPrimary)

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { isDark },
                        set: { newValue in
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                                selection = newValue ? "dark" : "light"
                            }
                        }
                    ))
                    .labelsHidden()
                    .toggleStyle(SettingsSwitchToggleStyle())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            }
        }
    }

}

// MARK: - 悬浮栏样式选择行

struct SettingsFloatingBarRow: View {
    let icon: MonologueIcon.IconType
    let title: String
    @Binding var selection: FloatingBarStyle

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                SettingsIconBadge(icon: icon)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.monologueTextPrimary)

                    Text(selection.description)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(.tertiary)
                }

                Spacer()
            }

            HStack(spacing: 8) {
                ForEach(FloatingBarStyle.allCases) { style in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selection = style
                        }
                    } label: {
                        VStack(spacing: 5) {
                            MonologueIcon(
                                icon: style.iconType,
                                size: 20,
                                color: selection == style ? .monologueIconForeground : .monologueTextSecondary
                            )
                            Text(style.displayName)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(selection == style
                                      ? Color.monologueIconBackground
                                      : Color.monologueSeparator.opacity(0.6))
                        )
                        .foregroundColor(selection == style
                                         ? Color.monologueIconForeground
                                         : Color.monologueTextSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

// MARK: - 一言类型选择行

struct SettingsHitokotoTypeRow: View {
    let icon: MonologueIcon.IconType
    let title: String
    @Binding var selection: String
    @State private var isExpanded = false

    private static let types: [(key: String, label: String)] = [
        ("", String(localized: "随机")),
        ("i", String(localized: "诗词")),
        ("d", String(localized: "文学")),
        ("k", String(localized: "哲学")),
        ("h", String(localized: "影视")),
        ("j", "ncm"),
        ("a", String(localized: "动画")),
        ("c", String(localized: "游戏")),
        ("e", String(localized: "原创")),
        ("l", String(localized: "抖机灵")),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 14) {
                    SettingsIconBadge(icon: icon)

                    Text(title)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.monologueTextPrimary)

                    Spacer()

                    Text(Self.types.first { $0.key == selection }?.label ?? String(localized: "随机"))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.monologueTextSecondary.opacity(0.8))
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                SettingsHitokotoFlowLayout(spacing: 8) {
                    ForEach(Self.types, id: \.key) { type in
                        Button {
                            withAnimation(.spring(response: 0.26, dampingFraction: 0.88)) {
                                selection = type.key
                                isExpanded = false
                            }
                        } label: {
                            Text(type.label)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(selection == type.key
                                              ? Color.monologueIconBackground
                                              : Color.monologueSeparator.opacity(0.6))
                                )
                                .foregroundColor(selection == type.key
                                                 ? Color.monologueIconForeground
                                                 : Color.monologueTextSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 12)
                .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

private struct SettingsHitokotoFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
