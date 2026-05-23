import SwiftUI

/// 关于页面 — 精致的 Liquid Glass 风格
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var settings = SettingsManager.shared
    @State private var logoVisible = false
    @State private var cardsVisible = false
    @State private var tapCount = 0
    @AppStorage("qqDevMode") private var qqDevMode = false

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private var logoPlateColors: [Color] {
        settings.appBrandStyle
            .logoPlateColors(for: settings.appBrandAppearance)
            .map(Color.init(hex:))
    }

    private var logoAuraColor: Color {
        Color(hex: settings.appBrandStyle.logoGlowColor(for: settings.appBrandAppearance))
    }

    private var aboutText: Color {
        if SequoiaStyle.isActive { return SequoiaStyle.ink }
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        return .monologueTextPrimary
    }

    private var aboutSecondaryText: Color {
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        return .monologueTextSecondary
    }

    private var aboutMutedText: Color {
        if SequoiaStyle.isActive { return SequoiaStyle.inkMuted }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkMuted }
        return .monologueTextSecondary.opacity(0.58)
    }

    private var aboutAccent: Color {
        if SequoiaStyle.isActive { return SequoiaStyle.accent }
        if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
        return .monologueAccent
    }

    var body: some View {
        ZStack {
            ThemedPageBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    SettingsScrollablePageHeader(
                        title: String(localized: "关于"),
                        eyebrow: "ABOUT",
                        icon: .infoCircle
                    )

                    // App Icon + 名称 + 版本
                    VStack(spacing: 32) {
                        appIdentity
                            .opacity(logoVisible ? 1 : 0)
                            .scaleEffect(logoVisible ? 1 : 0.85)

                        // 一句话介绍
                        aboutTaglineBlock
                            .opacity(logoVisible ? 1 : 0)

                        // 快捷访问
                        quickActionsSection
                            .opacity(cardsVisible ? 1 : 0)
                            .offset(y: cardsVisible ? 0 : 16)

                        // 功能特性
                        featuresSection
                            .opacity(cardsVisible ? 1 : 0)
                            .offset(y: cardsVisible ? 0 : 16)

                        // 开发信息
                        developerSection
                            .opacity(cardsVisible ? 1 : 0)
                            .offset(y: cardsVisible ? 0 : 16)

                        // 底部
                        footerSection
                            .opacity(cardsVisible ? 1 : 0)

                        FloatingBarBottomSpacer()
                    }
                    .padding(.horizontal, DeviceLayout.settingsSectionHorizontalPadding)
                    .iPadContentWidth(700)
                }
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.7).delay(0.1)) {
                logoVisible = true
            }
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.3)) {
                cardsVisible = true
            }
        }
    }

    // MARK: - Developer Mode

    private func showDevModePrompt() {
        if qqDevMode {
            AlertManager.shared.show(
                title: String(localized: "dev_mode_title"),
                message: String(localized: "dev_mode_disable"),
                primaryButtonTitle: String(localized: "dev_mode_confirm"),
                secondaryButtonTitle: String(localized: "dev_mode_cancel"),
                primaryAction: {
                    qqDevMode = false
                    HapticManager.shared.success()
                }
            )
        } else {
            AlertManager.shared.showInput(
                title: String(localized: "dev_mode_title"),
                message: String(localized: "dev_mode_enable"),
                placeholder: String(localized: "dev_mode_password"),
                isSecure: true,
                primaryButtonTitle: String(localized: "dev_mode_confirm"),
                secondaryButtonTitle: String(localized: "dev_mode_cancel"),
                onConfirm: { password in
                    if password == "yqq977522" {
                        qqDevMode = true
                        HapticManager.shared.success()
                    } else {
                        HapticManager.shared.error()
                    }
                }
            )
        }
    }

    // MARK: - App Identity

    private var appIdentity: some View {
        VStack(spacing: 16) {
            // App Logo
            ZStack {
                // 背景光晕
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                logoAuraColor.opacity(settings.appBrandAppearance == .dark ? 0.2 : 0.15),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 30,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)

                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: SequoiaStyle.isActive ? [SequoiaStyle.materialRaised, SequoiaStyle.materialList] : (NeumorphicStyle.isActive ? [NeumorphicStyle.surfaceRaised, NeumorphicStyle.surface] : logoPlateColors),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 112, height: 112)
                    .overlay {
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(
                                Color.white.opacity(
                                    settings.appBrandStyle.logoPlateStrokeOpacity(for: settings.appBrandAppearance)
                                ),
                                lineWidth: 1
                            )
                    }
                    .overlay {
                        Image(settings.appLogoAssetName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 92, height: 92)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .shadow(color: .black.opacity(NeumorphicStyle.isActive ? 0.08 : 0.15), radius: 20, x: 0, y: 10)
                    .background {
                        if SequoiaStyle.isActive {
                            SequoiaSurfaceBackground(cornerRadius: 26, elevated: true)
                                .frame(width: 112, height: 112)
                        } else if NeumorphicStyle.isActive {
                            NeumorphicSurfaceBackground(cornerRadius: 26, elevated: true)
                                .frame(width: 112, height: 112)
                        }
                    }
            }
            .onTapGesture {
                tapCount += 1
                HapticStyle.light.trigger()
            }

            // App 名称
            MonoWordmarkImage(height: 34, preferredColorScheme: colorScheme)

            // 版本号（彩蛋入口）
            Text("Version \(appVersion)")
                .font(NeumorphicStyle.isActive ? .system(size: 13, weight: .semibold, design: .monospaced) : .system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(SequoiaStyle.isActive ? SequoiaStyle.accent : (NeumorphicStyle.isActive ? NeumorphicStyle.accent : .monologueTextSecondary))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Capsule().fill(SequoiaStyle.isActive ? SequoiaStyle.selectedWash : (NeumorphicStyle.isActive ? NeumorphicStyle.accent.opacity(0.12) : Color.monologueTextSecondary.opacity(0.08))))
                .onTapGesture {
                    tapCount += 1
                    if tapCount >= 5 {
                        tapCount = 0
                        showDevModePrompt()
                    }
                }
        }
    }

    private var aboutTaglineBlock: some View {
        VStack(spacing: 6) {
            Text(LocalizedStringKey("welcome_slogan"))
                .font(SequoiaStyle.isActive ? SequoiaStyle.bodyFont(15, weight: .medium) : (NeumorphicStyle.isActive ? NeumorphicStyle.bodyFont(15, weight: .medium) : .system(size: 15, weight: .medium, design: .rounded)))
                .foregroundColor(aboutSecondaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.86)

            Text(LocalizedStringKey("welcome_slogan_short"))
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(aboutMutedText)
                .tracking(1.45)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(String(localized: "快捷访问"), icon: .sparkle)

            VStack(spacing: 0) {
                quickActionRow(
                    icon: .infoCircle,
                    title: String(localized: "官方网站"),
                    subtitle: "mono.zijiu522.cn",
                    urlString: "https://mono.zijiu522.cn"
                )

                Divider().padding(.leading, 56)

                quickActionRow(
                    icon: .history,
                    title: String(localized: "更新日志"),
                    subtitle: "mono.zijiu522.cn/updates",
                    urlString: "http://mono.zijiu522.cn/updates"
                )
            }
            .themedPageSurface(cornerRadius: NeumorphicStyle.isActive ? 20 : 20, elevated: false)
        }
    }

    private func quickActionRow(
        icon: MonologueIcon.IconType,
        title: String,
        subtitle: String,
        urlString: String
    ) -> some View {
        Button {
            guard let url = URL(string: urlString) else { return }
            HapticManager.shared.light()
            PlatformApplication.openURL(url)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill((SequoiaStyle.isActive || NeumorphicStyle.isActive) ? aboutAccent.opacity(0.16) : Color.monologueIconBackground)
                        .frame(width: 32, height: 32)
                    MonologueIcon(icon: icon, size: 16, color: SequoiaStyle.isActive ? aboutAccent : (NeumorphicStyle.isActive ? NeumorphicStyle.accent : .monologueIconForeground))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(SequoiaStyle.isActive ? SequoiaStyle.bodyFont(15, weight: .medium) : (NeumorphicStyle.isActive ? NeumorphicStyle.bodyFont(15, weight: .medium) : .system(size: 15, weight: .semibold, design: .rounded)))
                        .foregroundColor(aboutText)

                    Text(subtitle)
                        .font(SequoiaStyle.isActive ? SequoiaStyle.labelFont(12, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(12, weight: .medium) : .system(size: 12, weight: .medium, design: .rounded)))
                        .foregroundColor(aboutSecondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                Spacer(minLength: 8)

                MonologueIcon(icon: .chevronRight, size: 14, color: aboutMutedText, lineWidth: 1.7)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.985, opacity: 0.9))
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(String(localized: "特性"), icon: .sparkle)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                featureCard(icon: .musicNote, title: String(localized: "本地导入"), subtitle: String(localized: "文件 · 文件夹"))
                featureCard(icon: .headphones, title: String(localized: "离线播放"), subtitle: "Hi-Res · FLAC")
                featureCard(icon: .list, title: String(localized: "播放管理"), subtitle: String(localized: "队列 · 收藏"))
                featureCard(icon: .playerTheme, title: String(localized: "视觉盛宴"), subtitle: "Liquid Glass")
            }
        }
    }

    private func featureCard(icon: MonologueIcon.IconType, title: String, subtitle: String) -> some View {
        VStack(spacing: 8) {
            MonologueIcon(icon: icon, size: 26, color: aboutAccent)
            Text(title)
                .font(SequoiaStyle.isActive ? SequoiaStyle.bodyFont(14, weight: .semibold) : (NeumorphicStyle.isActive ? NeumorphicStyle.bodyFont(14, weight: .semibold) : .system(size: 14, weight: .bold, design: .rounded)))
                .foregroundColor(aboutText)
            Text(subtitle)
                .font(SequoiaStyle.isActive ? SequoiaStyle.labelFont(11) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(11, weight: .medium) : .system(size: 11, weight: .medium, design: .rounded)))
                .foregroundColor(aboutSecondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .themedPageSurface(cornerRadius: NeumorphicStyle.isActive ? 20 : 20, elevated: false)
    }

    // MARK: - Developer

    private var developerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Developer", icon: .profile)

            VStack(spacing: 0) {
                infoRow(icon: .personCircle, label: "Developer", value: "ZIJIU522")

                Divider().padding(.leading, 56)

                infoRow(icon: .playerTheme, label: "Design", value: "Liquid Glass")

                Divider().padding(.leading, 56)

                infoRow(icon: .layers, label: "Framework", value: "SwiftUI · Combine")

                Divider().padding(.leading, 56)

            infoRow(icon: .audioWave, label: "Engine", value: "FFmpeg · SwiftUI")
            }
            .themedPageSurface(cornerRadius: NeumorphicStyle.isActive ? 20 : 20, elevated: false)
        }
    }

    private func infoRow(icon: MonologueIcon.IconType, label: String, value: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill((SequoiaStyle.isActive || NeumorphicStyle.isActive) ? aboutAccent.opacity(0.16) : Color.monologueIconBackground)
                    .frame(width: 32, height: 32)
                MonologueIcon(icon: icon, size: 16, color: SequoiaStyle.isActive ? aboutAccent : (NeumorphicStyle.isActive ? NeumorphicStyle.accent : .monologueIconForeground))
            }

            Text(label)
                .font(SequoiaStyle.isActive ? SequoiaStyle.bodyFont(15, weight: .medium) : (NeumorphicStyle.isActive ? NeumorphicStyle.bodyFont(15, weight: .medium) : .system(size: 15, weight: .medium, design: .rounded)))
                .foregroundColor(aboutText)

            Spacer()

            Text(value)
                .font(SequoiaStyle.isActive ? SequoiaStyle.labelFont(14, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(14, weight: .medium) : .system(size: 14, weight: .regular, design: .rounded)))
                .foregroundColor(aboutSecondaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Text("Made with")
                MonologueIcon(icon: .liked, size: 14, color: aboutAccent)
                Text("in SwiftUI")
            }
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundColor(aboutSecondaryText)

            Text("仅供学习交流 · 请支持正版音乐")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(aboutMutedText.opacity(0.86))

            Text("© 2024-2026 mono. All Rights Reserved.")
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundColor(aboutMutedText)

            if tapCount >= 7 {
                Text("你发现了彩蛋！你是一个有好奇心的人。")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(aboutAccent)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.top, 20)
        .animation(.spring, value: tapCount)
    }

    // MARK: - Helpers

    private func sectionTitle(_ text: String, icon: MonologueIcon.IconType) -> some View {
        HStack(spacing: 8) {
            MonologueIcon(icon: icon, size: 16, color: aboutAccent)
            Text(text)
                .font(SequoiaStyle.isActive ? SequoiaStyle.titleFont(16, weight: .semibold) : (NeumorphicStyle.isActive ? NeumorphicStyle.titleFont(16, weight: .semibold) : .system(size: 16, weight: .bold, design: .rounded)))
                .foregroundColor(aboutText)
        }
        .padding(.leading, 4)
    }
}
