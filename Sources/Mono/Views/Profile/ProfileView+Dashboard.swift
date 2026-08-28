import Combine
import QQMusicKit
import SwiftUI

extension ProfileView {
    // MARK: - Logged In

    var loggedInContent: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                ThemedProfileBackground()

                ScrollView {
                    LazyVStack(spacing: themedProfileSpacing) {
                        loggedInDashboardContent
                        FloatingBarBottomSpacer()
                    }
                    .iPadContentWidth(700)
                }
                .scrollIndicators(.hidden)
                .themeRenderScrollLayer()
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .profileNavigationDestinations()
        }
    }

    var themedProfileSpacing: CGFloat {
        if MinimalWhiteStyle.isActive { return 24 }
        if MangaStyle.isActive { return 14 }
        if PetWhiteStyle.isActive { return 16 }
        if NeumorphicStyle.isActive { return 18 }
        if CapsuleStyle.isActive { return 16 }
        if SignalStyle.isActive { return 17 }
        if MujiStyle.isActive { return 18 }
        if SequoiaStyle.isActive { return 16 }
        if LiquidGlassStyle.isActive { return 16 }
        return 16
    }

    @ViewBuilder
    var loggedInDashboardContent: some View {
        if MinimalWhiteStyle.isActive {
            minimalWhiteProfileDashboard
        } else if MangaStyle.isActive {
            mangaProfileDashboard
        } else if PetWhiteStyle.isActive {
            petWhiteProfileDashboard
        } else if NeumorphicStyle.isActive {
            neumorphicProfileDashboard
        } else if CapsuleStyle.isActive {
            capsuleProfileDashboard
        } else if SignalStyle.isActive {
            signalProfileDashboard
        } else if MujiStyle.isActive {
            mujiProfileDashboard
        } else if SequoiaStyle.isActive {
            sequoiaProfileDashboard
        } else if LiquidGlassStyle.isActive {
            liquidGlassProfileDashboard
        } else {
            // aside：编辑部风格 —— 刊头眉题 + 身份区 + 发丝数据带 + 索引式目录
            asideProfileMasthead
                .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                .padding(.top, 8)
                .monoPageHeaderCollapse()

            asideStatsBand
                .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                .padding(.top, 2)

            ProfileRecentPlaysHost(variant: .standard)

            asideMenuIndex
                .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

            asideLogoutButton
        }
    }

    // MARK: - aside 我的页

    /// 刊头：眉题行 + 问候语 + 大号昵称 + 引文式签名，全部直接落在页面上
    var asideProfileMasthead: some View {
        let profile = cachedProfile ?? viewModel.userProfile
        let signature = profile?.signature?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Capsule()
                    .fill(Color.monoAccent)
                    .frame(width: 18, height: 3)

                Text("PROFILE")
                    .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                    .tracking(2.4)
                    .foregroundColor(.monoTextSecondary.opacity(0.72))
                    .fixedSize()

                Rectangle()
                    .fill(Color.monoSeparator.opacity(0.5))
                    .frame(height: 0.5)

                NavigationLink(value: ProfileNavigationDestination.settings) {
                    MonoIcon(icon: .settings, size: 19, color: .monoTextPrimary.opacity(0.85), lineWidth: 1.7)
                        .frame(width: 38, height: 38)
                        .background(
                            Circle()
                                .fill(Color.monoIconBackground.opacity(0.1))
                                .overlay(Circle().stroke(Color.monoTextPrimary.opacity(0.12), lineWidth: 0.8))
                        )
                        .contentShape(Circle())
                }
                .buttonStyle(MonoBouncingButtonStyle(scale: 0.9))
            }
            .padding(.bottom, 14)

            HStack(alignment: .center, spacing: 16) {
                Group {
                    if let avatarUrl = profile?.avatarUrl, let url = URL(string: avatarUrl) {
                        CachedAsyncImage(url: url, width: 72, height: 72) {
                            Circle().fill(Color.monoSeparator)
                        }
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 72, height: 72)
                        .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.monoSeparator)
                            .frame(width: 72, height: 72)
                            .overlay(
                                MonoIcon(icon: .profile, size: 30, color: .monoTextSecondary.opacity(0.4))
                            )
                    }
                }
                .overlay(
                    Circle()
                        .stroke(Color.monoTextPrimary.opacity(0.12), lineWidth: 1.2)
                        .padding(-5)
                )

                VStack(alignment: .leading, spacing: 5) {
                    Text(String(localized: LocalizedStringResource(stringLiteral: MonoTimeGreeting.localizedKey)))
                        .font(.rounded(size: 12.5, weight: .semibold))
                        .foregroundColor(.monoTextSecondary.opacity(0.85))

                    HStack(alignment: .firstTextBaseline, spacing: 9) {
                        Text(profile?.nickname ?? NSLocalizedString("default_nickname", comment: ""))
                            .font(.system(size: 27, weight: .heavy, design: .rounded))
                            .foregroundColor(.monoTextPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)

                        if let level = userLevel {
                            Text("LV.\(level)")
                                .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                                .tracking(0.8)
                                .foregroundColor(.monoTextPrimary.opacity(0.72))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2.5)
                                .overlay(
                                    Capsule().stroke(Color.monoTextPrimary.opacity(0.3), lineWidth: 0.8)
                                )
                        }
                    }
                }

                Spacer(minLength: 0)
            }

            if !signature.isEmpty {
                // 签名作引文：左侧短竖线 + 弱化正文
                HStack(alignment: .top, spacing: 10) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.monoAccent.opacity(0.8))
                        .frame(width: 2)
                        .padding(.vertical, 2)

                    Text(signature)
                        .font(.rounded(size: 13))
                        .foregroundColor(.monoTextSecondary)
                        .lineSpacing(3)
                        .lineLimit(2)
                }
                .padding(.top, 16)
                .padding(.leading, 2)
            }
        }
        .padding(.top, 4)
    }

    /// 数据带：上下发丝线之间的裸排大数字，去掉玻璃容器
    var asideStatsBand: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            asideStatCell(
                value: formatNumber(listenSongs ?? 0),
                label: String(localized: "profile_total_songs")
            )

            asideStatCell(
                value: "\(localPlaylistCount)",
                label: String(localized: "profile_local_playlists")
            )

            asideStatCell(
                value: asideWeekListenValue,
                label: String(localized: "profile_week_listen")
            )
        }
        .padding(.vertical, 16)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.monoSeparator.opacity(0.55)).frame(height: 0.5)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.monoSeparator.opacity(0.55)).frame(height: 0.5)
        }
        .task {
            guard await MainTabActivationGate.waitUntilSettled(.profile) else { return }
            refreshWeekListeningDuration()
        }
    }

    func refreshWeekListeningDuration() {
        weekListenSeconds = ListeningStatsService.shared.fetchStats(for: .week).totalDuration
    }

    var asideWeekListenValue: String {
        guard let seconds = weekListenSeconds else { return "—" }
        let hours = Double(seconds) / 3600
        if hours >= 10 { return "\(Int(hours))h" }
        if hours >= 1 { return String(format: "%.1fh", hours) }
        return "\(max(seconds / 60, 0))m"
    }

    func asideStatCell(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundColor(.monoTextPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            HStack(spacing: 5) {
                Circle()
                    .fill(Color.monoAccent)
                    .frame(width: 4, height: 4)

                Text(label)
                    .font(.rounded(size: 10.5, weight: .semibold))
                    .foregroundColor(.monoTextSecondary.opacity(0.85))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 4)
    }

    /// 目录：索引编号 + 发丝分隔的平铺行，不再装玻璃卡片
    var asideMenuIndex: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Capsule()
                    .fill(Color.monoAccent)
                    .frame(width: 3, height: 13)

                Text(String(localized: "profile_settings"))
                    .font(.rounded(size: 15, weight: .bold))
                    .foregroundColor(.monoTextPrimary)

                Spacer(minLength: 0)
            }
            .padding(.bottom, 6)

            Button {
                navigationPath.append(ProfileNavigationDestination.platformAccounts)
            } label: {
                asideMenuRow(
                    index: 1,
                    title: "平台账号管理",
                    trailingText: "4 个平台"
                )
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.98))

            asideMenuHairline

            NavigationLink(destination: ListeningStatsView()) {
                asideMenuRow(index: 2, title: String(localized: "cloud_sync_listening_stats"))
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.98))

            asideMenuHairline

            NavigationLink(destination: CloudDiskView()) {
                asideMenuRow(index: 3, title: NSLocalizedString("profile_cloud_disk", comment: ""))
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.98))
        }
    }

    func asideMenuRow(index: Int, title: String, trailingText: String? = nil) -> some View {
        HStack(spacing: 14) {
            Text(String(format: "%02d", index))
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(1)
                .foregroundColor(.monoTextSecondary.opacity(0.45))
                .monospacedDigit()

            Text(title)
                .font(.rounded(size: 15.5, weight: .semibold))
                .foregroundColor(.monoTextPrimary)

            Spacer(minLength: 0)

            if let trailingText {
                Text(trailingText)
                    .font(.rounded(size: 12.5))
                    .foregroundColor(.monoTextSecondary.opacity(0.85))
            }

            MonoIcon(icon: .chevronRight, size: 12, color: .monoTextSecondary.opacity(0.4))
        }
        .padding(.vertical, 15)
        .padding(.horizontal, 2)
        .contentShape(Rectangle())
    }

    var asideMenuHairline: some View {
        Rectangle()
            .fill(Color.monoSeparator.opacity(0.5))
            .frame(height: 0.5)
            .padding(.leading, 32)
    }

    var asideLogoutButton: some View {
        Button {
            AlertManager.shared.show(
                title: NSLocalizedString("alert_logout_title", comment: ""),
                message: NSLocalizedString("alert_logout_message", comment: ""),
                primaryButtonTitle: NSLocalizedString("alert_logout_confirm", comment: ""),
                secondaryButtonTitle: NSLocalizedString("alert_cancel", comment: "")
            ) {
                performLogout()
            }
        } label: {
            Text(LocalizedStringKey("action_logout"))
                .font(.rounded(size: 12.5, weight: .semibold))
                .tracking(0.6)
                .foregroundColor(.monoTextSecondary.opacity(0.75))
                .padding(.horizontal, 20)
                .padding(.vertical, 9)
                .overlay(
                    Capsule().stroke(Color.monoSeparator.opacity(0.9), lineWidth: 0.8)
                )
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.96))
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
    }

    @ViewBuilder
    var minimalWhiteProfileDashboard: some View {
        minimalWhiteProfileHeader
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
            .padding(.top, DeviceLayout.headerTopPadding + 8)

        minimalWhiteIdentity
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

        minimalWhiteMetrics
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

        ProfileRecentPlaysHost(variant: .standard)

        menuList
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)

        logoutButton
    }

    var minimalWhiteProfileHeader: some View {
        HStack(spacing: 12) {
            Text(String(localized: "tab_profile"))
                .font(MinimalWhiteStyle.titleFont(30, weight: .semibold))
                .foregroundStyle(MinimalWhiteStyle.ink)

            Spacer(minLength: 0)

            NavigationLink(value: ProfileNavigationDestination.settings) {
                MonoIcon(icon: .settings, size: 17, color: MinimalWhiteStyle.ink, lineWidth: 1.7)
                    .frame(width: 40, height: 40)
                    .background(MinimalWhiteCircleBackground(elevated: true, selected: true))
            }
            .buttonStyle(.plain)
        }
        .monoPageHeaderCollapse()
    }

    var minimalWhiteIdentity: some View {
        let profile = cachedProfile ?? viewModel.userProfile
        let signature = profile?.signature?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return HStack(spacing: 16) {
            minimalWhiteAvatar(profile: profile, size: 72)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(profile?.nickname ?? NSLocalizedString("default_nickname", comment: ""))
                        .font(MinimalWhiteStyle.titleFont(22, weight: .semibold))
                        .foregroundStyle(MinimalWhiteStyle.ink)
                        .lineLimit(1)

                    if let userLevel {
                        Text("Lv.\(userLevel)")
                            .font(MinimalWhiteStyle.labelFont(11, weight: .medium))
                            .foregroundStyle(MinimalWhiteStyle.inkSoft)
                    }
                }

                if !signature.isEmpty {
                    Text(signature)
                        .font(MinimalWhiteStyle.bodyFont(13, weight: .regular))
                        .foregroundStyle(MinimalWhiteStyle.inkMuted)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            MinimalWhiteSurfaceBackground(
                cornerRadius: MinimalWhiteStyle.chromeRadius,
                elevated: false,
                tint: MinimalWhiteStyle.glassFill
            )
        )
    }

    @ViewBuilder
    func minimalWhiteAvatar(profile: UserProfile?, size: CGFloat) -> some View {
        if let avatarUrl = profile?.avatarUrl, let url = URL(string: avatarUrl) {
            CachedAsyncImage(url: url, width: size, height: size) {
                Circle().fill(MinimalWhiteStyle.controlGlassFill)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(Circle().stroke(MinimalWhiteStyle.hairline, lineWidth: MinimalWhiteStyle.strokeWidth))
        } else {
            Circle()
                .fill(MinimalWhiteStyle.controlGlassFill)
                .frame(width: size, height: size)
                .overlay(MonoIcon(icon: .profile, size: 25, color: MinimalWhiteStyle.inkMuted))
                .overlay(Circle().stroke(MinimalWhiteStyle.hairline, lineWidth: MinimalWhiteStyle.strokeWidth))
        }
    }

    var minimalWhiteMetrics: some View {
        HStack(spacing: 0) {
            StatCell(value: formatNumber(listenSongs ?? 0), label: String(localized: "profile_total_songs"))
            statDivider
            StatCell(value: "\(localPlaylistCount)", label: String(localized: "profile_local_playlists"))
            statDivider
            StatCell(value: "\(downloadedSongCount)", label: String(localized: "profile_downloads"))
        }
        .padding(.vertical, 16)
        .background(
            MinimalWhiteSurfaceBackground(
                cornerRadius: MinimalWhiteStyle.cardRadius,
                elevated: false,
                tint: MinimalWhiteStyle.glassFill
            )
        )
        .overlay(alignment: .top) {
            Rectangle().fill(MinimalWhiteStyle.hairline).frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(MinimalWhiteStyle.hairline).frame(height: 1)
        }
    }

}
