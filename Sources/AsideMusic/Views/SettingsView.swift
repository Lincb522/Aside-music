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
    @State private var cacheSize: String = "计算中..."
    // 用于强制刷新视图的标识符
    @State private var viewRefreshID = UUID()

    var body: some View {
        NavigationStack {
            ZStack {
                AsideBackground()
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        headerSection
                            .padding(.top, DeviceLayout.headerTopPadding)

                        appearanceSection

                        playbackSection

                        cacheSection

                        otherSection

                        aboutSection

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationBarHidden(true)
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
            Button(action: { dismiss() }) {
                ZStack {
                    Circle()
                        .fill(Color.asideCardBackground)
                        .frame(width: 40, height: 40)
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)

                    AsideIcon(icon: .back, size: 16, color: .asideTextPrimary)
                }
            }
            .buttonStyle(AsideBouncingButtonStyle())

            Spacer()

            Text("设置")
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
        SettingsSection(title: "外观") {
            VStack(spacing: 0) {
                SettingsThemeRow(
                    icon: .sparkle,
                    title: "主题模式",
                    selection: $settings.themeMode
                )

                Divider()
                    .padding(.leading, 56)

                SettingsToggleRow(
                    icon: .sparkle,
                    title: "液态玻璃效果",
                    subtitle: "iOS 26 风格的高级视觉效果",
                    isOn: $settings.liquidGlassEnabled
                )
            }
        }
    }

    // MARK: - 播放设置

    @State private var showPlaybackQualitySheet = false
    @State private var showDownloadQualitySheet = false

    private var playbackSection: some View {
        SettingsSection(title: "播放") {
            VStack(spacing: 0) {
                SettingsNavigationRow(
                    icon: .soundQuality,
                    title: "默认播放音质",
                    value: defaultPlaybackQualityText
                ) {
                    showPlaybackQualitySheet = true
                }

                Divider()
                    .padding(.leading, 56)

                SettingsNavigationRow(
                    icon: .download,
                    title: "默认下载音质",
                    value: defaultDownloadQualityText
                ) {
                    showDownloadQualitySheet = true
                }

                Divider()
                    .padding(.leading, 56)

                SettingsToggleRow(
                    icon: .play,
                    title: "自动播放下一首",
                    subtitle: nil,
                    isOn: $settings.autoPlayNext
                )

                Divider()
                    .padding(.leading, 56)

                SettingsToggleRow(
                    icon: .musicNote,
                    title: "解灰",
                    subtitle: "自动从第三方源获取灰色歌曲播放链接",
                    isOn: $settings.unblockEnabled
                )
                .onChange(of: settings.unblockEnabled) { _, newValue in
                    APIService.shared.setUnblockEnabled(newValue)
                }

                Divider()
                    .padding(.leading, 56)

                SettingsToggleRow(
                    icon: .download,
                    title: "边听边存",
                    subtitle: "播放歌曲时自动下载保存到本地",
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
                        Text("均衡器")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.asideTextPrimary)
                        Spacer()
                        Text(EQManager.shared.isEnabled ? (EQManager.shared.currentPreset?.name ?? "自定义") : "关闭")
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
                        Text("音频实验室")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.asideTextPrimary)
                        Spacer()
                        Text(AudioLabManager.shared.isSmartEffectsEnabled ? "智能" : "关闭")
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
                isUnblocked: false,
                onSelectNetease: { quality in
                    settings.defaultPlaybackQuality = quality.rawValue
                    showPlaybackQualitySheet = false
                },
                onSelectKugou: { _ in }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showDownloadQualitySheet) {
            SoundQualitySheet(
                currentQuality: SoundQuality(rawValue: settings.defaultDownloadQuality) ?? .standard,
                currentKugouQuality: .high,
                isUnblocked: false,
                onSelectNetease: { quality in
                    settings.defaultDownloadQuality = quality.rawValue
                    showDownloadQualitySheet = false
                },
                onSelectKugou: { _ in }
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
        SettingsSection(title: "存储") {
            NavigationLink(destination: StorageManageView()) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.asideIconBackground)
                            .frame(width: 32, height: 32)
                        AsideIcon(icon: .storage, size: 16, color: .asideIconForeground)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("存储管理")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.asideTextPrimary)
                        Text("管理缓存、下载和用户数据")
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
        SettingsSection(title: "下载") {
            NavigationLink(destination: DownloadManageView()) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.asideIconBackground)
                            .frame(width: 32, height: 32)
                        AsideIcon(icon: .download, size: 16, color: .asideIconForeground)
                    }
                    
                    Text("下载管理")
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

    // MARK: - 其他设置

    private var otherSection: some View {
        SettingsSection(title: "其他") {
            SettingsToggleRow(
                icon: .haptic,
                title: "触感反馈",
                subtitle: "操作时的震动反馈",
                isOn: $settings.hapticFeedback
            )
        }
    }

    // MARK: - 关于

    private var aboutSection: some View {
        SettingsSection(title: "关于") {
            VStack(spacing: 0) {
                SettingsInfoRow(
                    icon: .info,
                    title: "版本",
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
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.asideGlassOverlay)
                    )
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                    .allowsHitTesting(false)

                content
            }
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
                .tint(Color(light: .black, dark: Color(hex: "555555")))
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
        ("system", "自动", .halfCircle),
        ("light", "浅色", .sun),
        ("dark", "深色", .moon)
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
