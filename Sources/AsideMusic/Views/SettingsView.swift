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
            // 背景
            AsideBackground()
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // 顶部导航
                    headerSection
                        .padding(.top, DeviceLayout.headerTopPadding)
                    
                    // 外观设置
                    appearanceSection
                    
                    // 播放设置
                    playbackSection
                    
                    // 缓存设置
                    cacheSection
                    
                    // 其他设置
                    otherSection
                    
                    // 关于
                    aboutSection
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
            }
        }
        .onAppear {
            updateCacheSize()
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack {
            Button(action: { dismiss() }) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 40, height: 40)
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    
                    AsideIcon(icon: .back, size: 16, color: .black)
                }
            }
            .buttonStyle(AsideBouncingButtonStyle())
            
            Spacer()
            
            Text("设置")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.black)
            
            Spacer()
            
            // 占位，保持标题居中
            Circle()
                .fill(Color.clear)
                .frame(width: 40, height: 40)
        }
    }
    
    // MARK: - 外观设置
    
    private var appearanceSection: some View {
        SettingsSection(title: "外观") {
            SettingsToggleRow(
                icon: .sparkle,
                title: "液态玻璃效果",
                subtitle: "iOS 26 风格的高级视觉效果",
                isOn: $settings.liquidGlassEnabled
            )
        }
    }
    
    // MARK: - 播放设置
    
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
            }
        }
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
                .foregroundColor(.gray)
                .padding(.leading, 4)
            
            ZStack {
                // 背景层 - 白色背景
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                    .allowsHitTesting(false)
                
                // 内容层 - 允许交互
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
                    .fill(Color.black)
                    .frame(width: 32, height: 32)
                
                AsideIcon(icon: icon, size: 16, color: .white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.black)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.black)
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
                        .fill(Color.black)
                        .frame(width: 32, height: 32)
                    
                    AsideIcon(icon: icon, size: 16, color: .white)
                }
                
                Text(title)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.black)
                
                Spacer()
                
                Text(value)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(.gray)
                
                AsideIcon(icon: .chevronRight, size: 12, color: .gray)
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
                    .fill(Color.black)
                    .frame(width: 32, height: 32)
                
                AsideIcon(icon: icon, size: 16, color: .white)
            }
            
            Text(title)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.black)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

struct SettingsButtonRow: View {
    let icon: AsideIcon.IconType
    let title: String
    var titleColor: Color = .black
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(titleColor == .red ? Color.red : Color.black)
                        .frame(width: 32, height: 32)
                    
                    AsideIcon(icon: icon, size: 16, color: .white)
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
