//
//  SettingsView.swift
//  AsideMusic
//
//  设置界面
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var systemColorScheme
    @ObservedObject private var settings = SettingsManager.shared
    @State private var cacheSize: String = String(localized: "settings_calculating")
    // 用于强制刷新视图的标识符
    @State private var viewRefreshID = UUID()

    var body: some View {
        NavigationStack {
            ZStack {
                AsideBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                            .padding(.top, DeviceLayout.headerTopPadding)

                        appearanceSection

                        playbackSection

                        cacheSection
                        
                        qqMusicSection

                        otherSection

                        aboutSection

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                updateCacheSize()
            }
            .preferredColorScheme(settings.preferredColorScheme)
            // 监听主题变化，强制刷新视图
            .onChange(of: settings.themeMode) { _, _ in
                // 延迟一帧后刷新，确保 UIKit 层面的样式已应用
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    viewRefreshID = UUID()
                }
            }
            // 监听系统颜色方案变化（自动模式时需要）
            .onChange(of: systemColorScheme) { _, _ in
                if settings.themeMode == "system" {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        viewRefreshID = UUID()
                    }
                }
            }
        }
        .id(viewRefreshID)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            AsideBackButton(style: .dismiss)

            Spacer()

            Text(String(localized: "settings_title"))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.asideTextPrimary)

            Spacer()

            Circle()
                .fill(Color.clear)
                .frame(width: 40, height: 40)
        }
    }

    // MARK: - 外观设置

    private var appearanceSection: some View {
        SettingsSection(title: String(localized: "settings_appearance")) {
            VStack(spacing: 0) {
                SettingsThemeRow(
                    icon: .sparkle,
                    title: String(localized: "settings_theme_mode"),
                    selection: $settings.themeMode
                )

                Divider()
                    .padding(.leading, 56)

                // 液态玻璃功能暂时禁用
                // SettingsToggleRow(
                //     icon: .sparkle,
                //     title: String(localized: "settings_liquid_glass"),
                //     subtitle: String(localized: "settings_liquid_glass_desc"),
                //     isOn: $settings.liquidGlassEnabled
                // )
                //
                // Divider()
                //     .padding(.leading, 56)
                
                SettingsFloatingBarRow(
                    icon: .layers,
                    title: String(localized: "settings_floating_bar"),
                    selection: Binding(
                        get: { settings.floatingBarStyle },
                        set: { settings.floatingBarStyle = $0 }
                    )
                )
            }
        }
    }

    // MARK: - 播放设置

    @State private var showPlaybackQualitySheet = false
    @State private var showDownloadQualitySheet = false

    private var playbackSection: some View {
        SettingsSection(title: String(localized: "settings_playback")) {
            VStack(spacing: 0) {
                SettingsNavigationRow(
                    icon: .soundQuality,
                    title: String(localized: "settings_playback_quality"),
                    value: defaultPlaybackQualityText
                ) {
                    showPlaybackQualitySheet = true
                }

                Divider()
                    .padding(.leading, 56)

                SettingsNavigationRow(
                    icon: .download,
                    title: String(localized: "settings_download_quality"),
                    value: defaultDownloadQualityText
                ) {
                    showDownloadQualitySheet = true
                }

                Divider()
                    .padding(.leading, 56)

                SettingsToggleRow(
                    icon: .play,
                    title: String(localized: "settings_auto_play_next"),
                    subtitle: nil,
                    isOn: $settings.autoPlayNext
                )

                Divider()
                    .padding(.leading, 56)

                SettingsToggleRow(
                    icon: .musicNote,
                    title: String(localized: "settings_unblock"),
                    subtitle: String(localized: "settings_unblock_desc"),
                    isOn: $settings.unblockEnabled
                )
                .onChange(of: settings.unblockEnabled) { _, newValue in
                    APIService.shared.setUnblockEnabled(newValue)
                }

                Divider()
                    .padding(.leading, 56)

                SettingsToggleRow(
                    icon: .download,
                    title: String(localized: "settings_cache_play"),
                    subtitle: String(localized: "settings_cache_play_desc"),
                    isOn: $settings.listenAndSave
                )

                Divider()
                    .padding(.leading, 56)

                NavigationLink(destination: EQSettingsView()) {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.asideIconBackground)
                                .frame(width: 32, height: 32)
                            AsideIcon(icon: .waveform, size: 16, color: .asideIconForeground)
                        }
                        Text(String(localized: "settings_equalizer"))
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.asideTextPrimary)
                        Spacer()
                        Text(EQManager.shared.isEnabled ? (EQManager.shared.currentPreset?.name ?? String(localized: "settings_off")) : String(localized: "settings_off"))
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundColor(.asideTextSecondary)
                        AsideIcon(icon: .chevronRight, size: 12, color: .asideTextSecondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)

                Divider()
                    .padding(.leading, 56)

                NavigationLink(destination: AudioLabView()) {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.asideAccent.opacity(0.15))
                                .frame(width: 32, height: 32)
                            AsideIcon(icon: .sparkle, size: 16, color: .asideAccent)
                        }
                        Text(String(localized: "settings_audio_lab"))
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.asideTextPrimary)
                        Spacer()
                        Text(AudioLabManager.shared.isSmartEffectsEnabled ? String(localized: "settings_smart") : String(localized: "settings_off"))
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundColor(.asideTextSecondary)
                        AsideIcon(icon: .chevronRight, size: 12, color: .asideTextSecondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)

                
            }
        }
        .sheet(isPresented: $showPlaybackQualitySheet) {
            SoundQualitySheet(
                currentQuality: SoundQuality(rawValue: settings.defaultPlaybackQuality) ?? .standard,
                currentKugouQuality: .high,
                currentQQQuality: .mp3_320,
                isUnblocked: false,
                isQQMusic: false,
                onSelectNetease: { quality in
                    settings.defaultPlaybackQuality = quality.rawValue
                    showPlaybackQualitySheet = false
                },
                onSelectKugou: { _ in },
                onSelectQQ: { _ in }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showDownloadQualitySheet) {
            SoundQualitySheet(
                currentQuality: SoundQuality(rawValue: settings.defaultDownloadQuality) ?? .standard,
                currentKugouQuality: .high,
                currentQQQuality: .mp3_320,
                isUnblocked: false,
                isQQMusic: false,
                onSelectNetease: { quality in
                    settings.defaultDownloadQuality = quality.rawValue
                    showDownloadQualitySheet = false
                },
                onSelectKugou: { _ in },
                onSelectQQ: { _ in }
            )
            .presentationDetents([.medium, .large])
        }
    }

    private var defaultPlaybackQualityText: String {
        (SoundQuality(rawValue: settings.defaultPlaybackQuality) ?? .standard).displayName
    }

    private var defaultDownloadQualityText: String {
        (SoundQuality(rawValue: settings.defaultDownloadQuality) ?? .standard).displayName
    }

    // MARK: - 存储管理

    private var cacheSection: some View {
        SettingsSection(title: String(localized: "settings_storage")) {
            NavigationLink(destination: StorageManageView()) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.asideIconBackground)
                            .frame(width: 32, height: 32)
                        AsideIcon(icon: .storage, size: 16, color: .asideIconForeground)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "settings_storage_manage"))
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.asideTextPrimary)
                        Text(String(localized: "settings_storage_manage_desc"))
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.asideTextSecondary)
                    }
                    
                    Spacer()
                    
                    Text(cacheSize)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.asideTextSecondary)
                    
                    AsideIcon(icon: .chevronRight, size: 12, color: .asideTextSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 下载管理

    private var downloadSection: some View {
        SettingsSection(title: String(localized: "settings_download_manage")) {
            NavigationLink(destination: DownloadManageView()) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.asideIconBackground)
                            .frame(width: 32, height: 32)
                        AsideIcon(icon: .download, size: 16, color: .asideIconForeground)
                    }
                    
                    Text(String(localized: "settings_download_manage"))
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.asideTextPrimary)
                    
                    Spacer()
                    
                    AsideIcon(icon: .chevronRight, size: 12, color: .asideTextSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - QQ 音乐设置
    
    @State private var showQQAccount = false
    @State private var isQQLoggedIn = UserDefaults.standard.bool(forKey: AppConfig.StorageKeys.qqMusicLoggedIn)
    
    private var qqMusicSection: some View {
        SettingsSection(title: String(localized: "settings_qq_music")) {
            VStack(spacing: 0) {
                Button(action: { showQQAccount = true }) {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.asideIconBackground)
                                .frame(width: 32, height: 32)
                            AsideIcon(icon: .profile, size: 16, color: .asideIconForeground)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(localized: "settings_qq_account"))
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(.asideTextPrimary)
                            Text(isQQLoggedIn ? String(localized: "settings_qq_logged_in") : String(localized: "settings_qq_not_logged_in"))
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(isQQLoggedIn ? .green : .asideTextSecondary)
                        }
                        
                        Spacer()
                        
                        AsideIcon(icon: .chevronRight, size: 12, color: .asideTextSecondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
            }
        }
        .fullScreenCover(isPresented: $showQQAccount) {
            NavigationStack {
                QQAccountView()
            }
        }
        .onAppear {
            Task {
                do {
                    let status = try await APIService.shared.qqClient.authStatus()
                    await MainActor.run {
                        isQQLoggedIn = status.loggedIn
                        UserDefaults.standard.set(status.loggedIn, forKey: AppConfig.StorageKeys.qqMusicLoggedIn)
                    }
                } catch {}
            }
        }
        .onChange(of: showQQAccount) { _, showing in
            if !showing {
                isQQLoggedIn = UserDefaults.standard.bool(forKey: AppConfig.StorageKeys.qqMusicLoggedIn)
            }
        }
    }

    // MARK: - 其他设置

    private var otherSection: some View {
        SettingsSection(title: String(localized: "settings_other")) {
            VStack(spacing: 0) {
                SettingsToggleRow(
                    icon: .haptic,
                    title: String(localized: "settings_haptic"),
                    subtitle: String(localized: "settings_haptic_desc"),
                    isOn: $settings.hapticFeedback
                )
                
                Divider()
                    .padding(.leading, 56)
                
                NavigationLink(destination: DebugLogView()) {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.asideIconBackground)
                                .frame(width: 32, height: 32)
                            AsideIcon(icon: .logDebug, size: 16, color: .asideIconForeground)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(localized: "settings_debug_log"))
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(.asideTextPrimary)
                            Text(String(localized: "settings_debug_log_desc"))
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(.asideTextSecondary)
                        }
                        
                        Spacer()
                        
                        Text("\(AppLogger.getAllLogs().count)")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundColor(.asideTextSecondary)
                        
                        AsideIcon(icon: .chevronRight, size: 12, color: .asideTextSecondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 关于

    private var aboutSection: some View {
        SettingsSection(title: String(localized: "settings_about")) {
            VStack(spacing: 0) {
                SettingsInfoRow(
                    icon: .info,
                    title: String(localized: "settings_version"),
                    value: appVersion
                )
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    // MARK: - Actions

    private func updateCacheSize() {
        Task { @MainActor in
            // 计算总存储占用
            let fm = FileManager.default
            var total: Int64 = 0
            
            // 磁盘缓存
            let cacheDir = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("AsideMusicCache")
            if let files = try? fm.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.totalFileAllocatedSizeKey], options: .skipsHiddenFiles) {
                for f in files {
                    total += Int64((try? f.resourceValues(forKeys: [.totalFileAllocatedSizeKey]))?.totalFileAllocatedSize ?? 0)
                }
            }
            
            // 数据库
            if let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                let dbPath = appSupport.appendingPathComponent("default.store").path
                for ext in ["", ".wal", ".shm"] {
                    let p = ext.isEmpty ? dbPath : dbPath + ext
                    if let attrs = try? fm.attributesOfItem(atPath: p), let s = attrs[.size] as? Int64 { total += s }
                }
            }
            
            // 下载
            total += DownloadManager.shared.totalDownloadSize()
            
            cacheSize = ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
        }
    }

    private func clearCache() {
        // 已迁移到 StorageManageView
        OptimizedCacheManager.shared.clearAll()
        updateCacheSize()
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
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.asideTextSecondary)
                .padding(.leading, 4)

            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.asideGlassTint)
                    .glassEffect(.regular, in: .rect(cornerRadius: 16))
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                    .allowsHitTesting(false)

                content
            }
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

// MARK: - Settings Rows

struct SettingsToggleRow: View {
    let icon: AsideIcon.IconType
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.asideIconBackground)
                    .frame(width: 32, height: 32)

                AsideIcon(icon: icon, size: 16, color: .asideIconForeground)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.asideTextPrimary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.asideTextSecondary)
                }
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Color(light: .black, dark: .white))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

struct SettingsNavigationRow: View {
    let icon: AsideIcon.IconType
    let title: String
    let value: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.asideIconBackground)
                        .frame(width: 32, height: 32)

                    AsideIcon(icon: icon, size: 16, color: .asideIconForeground)
                }

                Text(title)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.asideTextPrimary)

                Spacer()

                Text(value)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(.asideTextSecondary)

                AsideIcon(icon: .chevronRight, size: 12, color: .asideTextSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }
}

struct SettingsInfoRow: View {
    let icon: AsideIcon.IconType
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.asideIconBackground)
                    .frame(width: 32, height: 32)

                AsideIcon(icon: icon, size: 16, color: .asideIconForeground)
            }

            Text(title)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.asideTextPrimary)

            Spacer()

            Text(value)
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundColor(.asideTextSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

struct SettingsButtonRow: View {
    let icon: AsideIcon.IconType
    let title: String
    var titleColor: Color = .asideTextPrimary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(titleColor == .red ? Color.red : Color.asideIconBackground)
                        .frame(width: 32, height: 32)

                    AsideIcon(icon: icon, size: 16, color: .asideIconForeground)
                }

                Text(title)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(titleColor)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 主题选择行

struct SettingsThemeRow: View {
    let icon: AsideIcon.IconType
    let title: String
    @Binding var selection: String

    private let options: [(key: String, label: String, iconType: AsideIcon.IconType)] = [
        ("system", String(localized: "settings_theme_auto"), .halfCircle),
        ("light", String(localized: "settings_theme_light"), .sun),
        ("dark", String(localized: "settings_theme_dark"), .moon)
    ]

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.asideIconBackground)
                        .frame(width: 32, height: 32)

                    AsideIcon(icon: icon, size: 16, color: .asideIconForeground)
                }

                Text(title)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.asideTextPrimary)

                Spacer()
            }

            HStack(spacing: 8) {
                ForEach(options, id: \.key) { option in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selection = option.key
                        }
                    } label: {
                        HStack(spacing: 6) {
                            AsideIcon(icon: option.iconType, size: 12, color: selection == option.key ? .asideIconForeground : .asideTextSecondary)
                            Text(option.label)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(selection == option.key
                                      ? Color.asideIconBackground
                                      : Color.asideSeparator)
                        )
                        .foregroundColor(selection == option.key
                                         ? Color.asideIconForeground
                                         : Color.asideTextSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - 悬浮栏样式选择行

struct SettingsFloatingBarRow: View {
    let icon: AsideIcon.IconType
    let title: String
    @Binding var selection: FloatingBarStyle

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.asideIconBackground)
                        .frame(width: 32, height: 32)

                    AsideIcon(icon: icon, size: 16, color: .asideIconForeground)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.asideTextPrimary)
                    
                    Text(selection.description)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.asideTextSecondary)
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
                        VStack(spacing: 4) {
                            AsideIcon(
                                icon: style.iconType,
                                size: 20,
                                color: selection == style ? .asideIconForeground : .asideTextSecondary
                            )
                            Text(style.displayName)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(selection == style
                                      ? Color.asideIconBackground
                                      : Color.asideSeparator)
                        )
                        .foregroundColor(selection == style
                                         ? Color.asideIconForeground
                                         : Color.asideTextSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
