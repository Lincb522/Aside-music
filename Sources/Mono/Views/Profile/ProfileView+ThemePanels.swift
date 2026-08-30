import Combine
import QQMusicKit
import SwiftUI

extension ProfileView {
    var liquidGlassProfileHeaderBar: some View {
        HStack(spacing: 13) {
            LiquidGlassDropletMark(tint: LiquidGlassStyle.accent)

            VStack(alignment: .leading, spacing: 3) {
                Text("PROFILE")
                    .font(LiquidGlassStyle.labelFont(10, weight: .semibold))
                    .foregroundStyle(LiquidGlassStyle.inkMuted)

                Text(String(localized: "tab_profile"))
                    .font(LiquidGlassStyle.titleFont(25, weight: .semibold))
                    .foregroundStyle(LiquidGlassStyle.ink)
            }

            Spacer(minLength: 8)

            NavigationLink(value: ProfileNavigationDestination.settings) {
                LiquidGlassIconBadge(icon: .settings, tint: LiquidGlassStyle.accent, size: 44)
                    .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.94))
        }
        .padding(14)
        .background(LiquidGlassChromeBar(cornerRadius: 24))
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
        .padding(.top, 8)
        .monoPageHeaderCollapse()
    }

    var liquidGlassProfileHeroPanel: some View {
        let profile = displayedProfile
        let signature = profile?.signature?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return HStack(alignment: .center, spacing: 15) {
            liquidGlassAvatar(profile: profile, size: 82)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 7) {
                    Text(profile?.nickname ?? NSLocalizedString("default_nickname", comment: ""))
                        .font(LiquidGlassStyle.titleFont(23, weight: .semibold))
                        .foregroundStyle(LiquidGlassStyle.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)

                    if loginIdentity.activeSource == .netease, let level = userLevel {
                        LiquidGlassPill(text: "Lv.\(level)", tint: LiquidGlassStyle.accent, selected: true, compact: true)
                    }
                }

                Text(signature.isEmpty ? String(localized: "profile_login_hint") : signature)
                    .font(LiquidGlassStyle.labelFont(12, weight: .regular))
                    .foregroundStyle(LiquidGlassStyle.inkSoft)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    LiquidGlassPill(text: identityPrimaryMetricValue, icon: identityPrimaryMetricIcon, tint: LiquidGlassStyle.cyan, compact: true)
                    LiquidGlassPill(text: "\(localPlaylistCount)", icon: .musicNoteList, tint: LiquidGlassStyle.mint, compact: true)
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(LiquidGlassPrismBand(tint: LiquidGlassStyle.accent, cornerRadius: 28))
    }

    @ViewBuilder
    func liquidGlassAvatar(profile: UserProfile?, size: CGFloat) -> some View {
        if let avatarUrl = profile?.avatarUrl, let url = URL(string: avatarUrl) {
            CachedAsyncImage(url: url, width: size, height: size) {
                RoundedRectangle(cornerRadius: size * 0.31, style: .continuous)
                    .fill(LiquidGlassStyle.glassList)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.31, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: size * 0.31, style: .continuous).stroke(LiquidGlassStyle.luminousEdge.opacity(0.45), lineWidth: 0.7))
        } else {
            RoundedRectangle(cornerRadius: size * 0.31, style: .continuous)
                .fill(LiquidGlassStyle.glassList)
                .frame(width: size, height: size)
                .background(LiquidGlassSurfaceBackground(cornerRadius: size * 0.31, elevated: true, role: .selected))
                .overlay(MonoIcon(icon: .profileFilled, size: size * 0.36, color: LiquidGlassStyle.accent, lineWidth: 1.55))
        }
    }

    var sequoiaProfileHeroPanel: some View {
        let profile = displayedProfile
        let signature = profile?.signature?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return ZStack(alignment: .bottomTrailing) {
            SequoiaGlassBand(tint: SequoiaStyle.accent, cornerRadius: 26)

            HStack(spacing: 15) {
                sequoiaProfileAvatar(profile: profile, size: 82)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 7) {
                        Text(profile?.nickname ?? NSLocalizedString("default_nickname", comment: ""))
                            .font(SequoiaStyle.titleFont(22, weight: .semibold))
                            .foregroundStyle(SequoiaStyle.ink)
                            .lineLimit(1)

                        if loginIdentity.activeSource == .netease, let level = userLevel {
                            SequoiaPill(text: "Lv.\(level)", tint: SequoiaStyle.accent, selected: true, compact: true)
                        }
                    }

                    Text(signature.isEmpty ? String(localized: "Mono") : signature)
                        .font(SequoiaStyle.labelFont(12, weight: .regular))
                        .foregroundStyle(SequoiaStyle.inkSoft)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        SequoiaPill(
                            text: String(format: String(localized: "profile_recent_count"), playerManager.history.count),
                            icon: .clock,
                            tint: SequoiaStyle.aqua,
                            selected: false,
                            compact: true
                        )
                        SequoiaMeter(tint: SequoiaStyle.aqua, count: 8)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(15)
        }
        .frame(minHeight: 116)
    }

    @ViewBuilder
    func sequoiaProfileAvatar(profile: UserProfile?, size: CGFloat) -> some View {
        if let avatarUrl = profile?.avatarUrl, let url = URL(string: avatarUrl) {
            CachedAsyncImage(url: url, width: size, height: size) {
                Circle().fill(SequoiaStyle.materialList)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(Circle().stroke(SequoiaStyle.luminousSeparator.opacity(0.62), lineWidth: 1))
            .shadow(color: SequoiaStyle.accent.opacity(0.14), radius: 10, y: 5)
        } else {
            Circle()
                .fill(SequoiaStyle.materialList)
                .frame(width: size, height: size)
                .overlay(MonoIcon(icon: .profile, size: size * 0.38, color: SequoiaStyle.inkMuted, lineWidth: 1.55))
                .overlay(Circle().stroke(SequoiaStyle.separator, lineWidth: 0.7))
        }
    }

    var signalProfileHeroPanel: some View {
        let profile = displayedProfile

        return VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .center, spacing: 14) {
                signalAvatar(profile: profile, size: 78)

                VStack(alignment: .leading, spacing: 7) {
                    Text(profile?.nickname ?? NSLocalizedString("default_nickname", comment: ""))
                        .font(SignalStyle.titleFont(24, weight: .bold))
                        .foregroundStyle(SignalStyle.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)

                    Text(profile?.signature?.isEmpty == false ? profile?.signature ?? "" : String(localized: "profile_login_hint"))
                        .font(SignalStyle.labelFont(12, weight: .medium))
                        .foregroundStyle(SignalStyle.inkSoft)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        if loginIdentity.activeSource == .netease, let userLevel {
                            SignalPill(text: "Lv.\(userLevel)", tint: SignalStyle.accent, selected: true, compact: true)
                        }
                        SignalPill(text: identityPrimaryMetricValue, tint: SignalStyle.olive, icon: identityPrimaryMetricIcon, compact: true)
                    }
                }

                Spacer(minLength: 0)
            }

            SignalProfilePulseStrip(tint: SignalStyle.accent)
        }
        .padding(16)
        .background(SignalSurfaceBackground(cornerRadius: 30, elevated: true, fill: SignalStyle.device))
    }

    @ViewBuilder
    func signalAvatar(profile: UserProfile?, size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                .fill(SignalStyle.controlPressed)
                .frame(width: size, height: size)
                .background(SignalSurfaceBackground(cornerRadius: size * 0.32, elevated: true, fill: SignalStyle.deviceRaised))

            if let avatarUrl = profile?.avatarUrl, let url = URL(string: avatarUrl) {
                CachedAsyncImage(url: url, width: size - 14, height: size - 14) {
                    RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                        .fill(SignalStyle.controlPressed)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: size - 14, height: size - 14)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
            } else {
                MonoIcon(icon: .profileFilled, size: size * 0.36, color: SignalStyle.accent, lineWidth: 1.75)
            }
        }
    }

}
