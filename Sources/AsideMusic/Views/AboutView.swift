import SwiftUI

/// 关于页面 — 精致的 Liquid Glass 风格
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var logoVisible = false
    @State private var cardsVisible = false
    @State private var tapCount = 0

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        ZStack {
            AsideBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    // 顶栏
                    headerBar
                        .padding(.top, DeviceLayout.headerTopPadding)

                    // App Icon + 名称 + 版本
                    appIdentity
                        .opacity(logoVisible ? 1 : 0)
                        .scaleEffect(logoVisible ? 1 : 0.85)

                    // 一句话介绍
                    Text("你的私人音乐宇宙")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.asideTextSecondary)
                        .opacity(logoVisible ? 1 : 0)

                    // 功能特性
                    featuresSection
                        .opacity(cardsVisible ? 1 : 0)
                        .offset(y: cardsVisible ? 0 : 16)

                    // 开发信息
                    developerSection
                        .opacity(cardsVisible ? 1 : 0)
                        .offset(y: cardsVisible ? 0 : 16)

                    // 致谢
                    acknowledgementsSection
                        .opacity(cardsVisible ? 1 : 0)
                        .offset(y: cardsVisible ? 0 : 16)

                    // 底部
                    footerSection
                        .opacity(cardsVisible ? 1 : 0)

                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.7).delay(0.1)) {
                logoVisible = true
            }
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.3)) {
                cardsVisible = true
            }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            AsideBackButton(style: .dismiss)
            Spacer()
            Text("关于")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.asideTextPrimary)
            Spacer()
            Circle()
                .fill(Color.clear)
                .frame(width: 40, height: 40)
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
                                Color.asideAccent.opacity(0.15),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 30,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)

                // Logo 图片 — 尝试加载 App Icon
                if let uiImage = UIImage(named: "AppIcon") ?? UIImage(named: "AppIcon60x60") {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                } else {
                    // Fallback: 渐变图标
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "667EEA"), Color(hex: "764BA2")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .overlay(
                            Text("A")
                                .font(.system(size: 48, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                        )
                        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                }
            }
            .onTapGesture {
                tapCount += 1
                HapticStyle.light.trigger()
            }

            // App 名称
            Text("Aside Music")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.asideTextPrimary, .asideTextPrimary.opacity(0.7)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            // 版本号
            Text("Version \(appVersion)")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(.asideTextSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.asideTextSecondary.opacity(0.08)))
        }
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("特性", icon: .sparkle)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                featureCard(icon: .musicNote, title: "多源聚合", subtitle: "NCM · QQ音乐")
                featureCard(icon: .headphones, title: "无损音质", subtitle: "Hi-Res · FLAC")
                featureCard(icon: .radio, title: "私人FM", subtitle: "智能推荐")
                featureCard(icon: .playerTheme, title: "视觉盛宴", subtitle: "Liquid Glass")
            }
        }
    }

    private func featureCard(icon: AsideIcon.IconType, title: String, subtitle: String) -> some View {
        VStack(spacing: 8) {
            AsideIcon(icon: icon, size: 26, color: .asideAccent)
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.asideTextPrimary)
            Text(subtitle)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.asideTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }

    // MARK: - Developer

    private var developerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("开发者", icon: .profile)

            VStack(spacing: 0) {
                infoRow(icon: .profile, label: "开发者", value: "zijiu522")

                Divider().padding(.leading, 56)

                infoRow(icon: .sparkle, label: "设计语言", value: "Liquid Glass")

                Divider().padding(.leading, 56)

                infoRow(icon: .catTech, label: "框架", value: "SwiftUI · Combine")

                Divider().padding(.leading, 56)

                infoRow(icon: .musicNote, label: "数据源", value: "NCM · QQ Music API")
            }
            .glassEffect(.regular, in: .rect(cornerRadius: 16))
        }
    }

    private func infoRow(icon: AsideIcon.IconType, label: String, value: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.asideIconBackground)
                    .frame(width: 32, height: 32)
                AsideIcon(icon: icon, size: 16, color: .asideIconForeground)
            }

            Text(label)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.asideTextPrimary)

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(.asideTextSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Acknowledgements

    private var acknowledgementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("致谢", icon: .like)

            VStack(spacing: 0) {
                thankRow(name: "NeteaseCloudMusicApi", desc: "网易云音乐 API")
                Divider().padding(.leading, 16)
                thankRow(name: "QQMusicApi", desc: "QQ 音乐 API")
                Divider().padding(.leading, 16)
                thankRow(name: "Hitokoto", desc: "一言 · 每日一句")
                Divider().padding(.leading, 16)
                thankRow(name: "Apple", desc: "SwiftUI · Liquid Glass")
            }
            .glassEffect(.regular, in: .rect(cornerRadius: 16))
        }
    }

    private func thankRow(name: String, desc: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.asideTextPrimary)
                Text(desc)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(.asideTextSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Text("Made with")
                AsideIcon(icon: .liked, size: 14, color: .asideAccent)
                Text("in SwiftUI")
            }
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundColor(.asideTextSecondary)


            Text("© 2024-2026 Aside Music. All Rights Reserved.")
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundColor(.asideTextSecondary.opacity(0.6))

            if tapCount >= 7 {
                Text("你发现了彩蛋！你是一个有好奇心的人。")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.asideAccent)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.top, 20)
        .animation(.spring, value: tapCount)
    }

    // MARK: - Helpers

    private func sectionTitle(_ text: String, icon: AsideIcon.IconType) -> some View {
        HStack(spacing: 8) {
            AsideIcon(icon: icon, size: 16, color: .asideAccent)
            Text(text)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.asideTextPrimary)
        }
        .padding(.leading, 4)
    }
}
