//
//  SettingsView.swift
//  AsideMusic
//
//  设置界面
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = SettingsManager.shared
    @State private var cacheSize: String = "计算中..."

    var body: some View {
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
        .onAppear {
            updateCacheSize()
        }
        .preferredColorScheme(settings.preferredColorScheme)
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

    @State private var showUnblockSourceManage = false

    private var playbackSection: some View {
        SettingsSection(title: "播放") {
            VStack(spacing: 0) {
                SettingsNavigationRow(
                    icon: .soundQuality,
                    title: "音质",
                    value: soundQualityText
                ) {
                    // TODO: 音质选择
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
                    icon: .unlock,
                    title: "解灰",
                    subtitle: "灰色歌曲自动匹配其他音源",
                    isOn: $settings.unblockEnabled
                )

                Divider()
                    .padding(.leading, 56)

                SettingsNavigationRow(
                    icon: .cloud,
                    title: "第三方源管理",
                    value: unblockSourceSummary
                ) {
                    showUnblockSourceManage = true
                }
            }
        }
        .fullScreenCover(isPresented: $showUnblockSourceManage) {
            UnblockSourceManageView()
        }
    }

    private var unblockSourceSummary: String {
        let count = UnblockSourceManager.shared.enabledCount
        let total = UnblockSourceManager.shared.sources.count
        if total == 0 { return "未添加" }
        return "\(count)/\(total) 启用"
    }

    private var soundQualityText: String {
        switch settings.soundQuality {
        case "low": return "流畅"
        case "standard": return "标准"
        case "high": return "高品质"
        case "lossless": return "无损"
        default: return "标准"
        }
    }

    // MARK: - 缓存设置

    private var cacheSection: some View {
        SettingsSection(title: "缓存") {
            VStack(spacing: 0) {
                SettingsInfoRow(
                    icon: .storage,
                    title: "缓存大小",
                    value: cacheSize
                )

                Divider()
                    .padding(.leading, 56)

                SettingsButtonRow(
                    icon: .trash,
                    title: "清除缓存",
                    titleColor: .red
                ) {
                    clearCache()
                }
            }
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
            cacheSize = OptimizedCacheManager.shared.getCacheSize()
        }
    }

    private func clearCache() {
        AlertManager.shared.show(
            title: "清除缓存",
            message: "确定要清除所有缓存吗？这不会影响您的账号数据。",
            primaryButtonTitle: "清除",
            secondaryButtonTitle: "取消"
        ) {
            Task { @MainActor in
                OptimizedCacheManager.shared.clearAll()
                updateCacheSize()
                AlertManager.shared.dismiss()
            }
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
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.asideTextSecondary)
                .padding(.leading, 4)

            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.asideCardBackground)
                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
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

    private let options: [(key: String, label: String, systemImage: String)] = [
        ("system", "自动", "circle.lefthalf.filled"),
        ("light", "浅色", "sun.max.fill"),
        ("dark", "深色", "moon.fill")
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
                            Image(systemName: option.systemImage)
                                .font(.system(size: 12, weight: .medium))
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
