import SwiftUI

struct ClarityProfileView: View {
    @ObservedObject private var home = HomeViewModel.shared

    var body: some View {
        NavigationStack {
            ZStack {
                ClarityBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        titleBar
                        LoginIdentitySwitcher()
                        identityPlane
                        destinationGrid
                        settingsPlane
                        FloatingBarBottomSpacer()
                    }
                    .padding(.top, DeviceLayout.headerTopPadding + 8)
                    .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
                    .frame(maxWidth: 680)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
                .themeRenderScrollLayer()
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .task {
            guard await MainTabActivationGate.waitUntilSettled(.profile) else { return }
            await LoginIdentityManager.shared.refreshAvailableIdentities()
            home.ensureHomeDataLoaded(reason: "clarity profile")
        }
    }

    private var titleBar: some View {
        HStack {
            Text(String(localized: "tabbar_profile"))
                .font(ClarityStyle.title(25, weight: .semibold))
                .foregroundStyle(ClarityStyle.ink)
            Spacer()
            NavigationLink(destination: SettingsView().monoNavigationBackButton(iconColor: ClarityStyle.ink)) {
                MonoIcon(icon: .settings, size: 19, color: ClarityStyle.ink, lineWidth: 1.55)
                    .frame(width: 44, height: 44)
                    .background(ClarityMembrane(shape: Circle(), strength: .regular))
            }
            .buttonStyle(ClarityPressStyle())
        }
        .padding(.horizontal, 4)
        .monoPageHeaderCollapse()
    }

    private var identityPlane: some View {
        ClarityShell(cornerRadius: 36) {
            VStack(spacing: 18) {
                identity
                if home.displayedIdentitySource == .netease {
                    metrics
                }
            }
            .padding(20)
        }
    }

    private var destinationGrid: some View {
        HStack(spacing: 12) {
            NavigationLink(destination: ListeningStatsView().clarityDetailChrome()) {
                destinationCard(
                    icon: .chart,
                    title: String(localized: "listening_stats"),
                    tint: ClarityStyle.accent
                )
            }

            NavigationLink(destination: PlatformAccountManagementView().clarityDetailChrome()) {
                destinationCard(
                    icon: .personCircle,
                    title: String(localized: "platform_account_management"),
                    tint: ClarityStyle.accent
                )
            }
        }
        .buttonStyle(ClarityPressStyle())
    }

    private var settingsPlane: some View {
        NavigationLink(destination: SettingsView().monoNavigationBackButton(iconColor: ClarityStyle.ink)) {
            actionRow(icon: .settings, title: String(localized: "settings_title"))
                .padding(.horizontal, 18)
                .background {
                    ClarityMembrane(
                        shape: RoundedRectangle(cornerRadius: 26, style: .continuous),
                        strength: .regular
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .buttonStyle(ClarityPressStyle())
    }

    private var identity: some View {
        HStack(spacing: 17) {
            avatar
            VStack(alignment: .leading, spacing: 6) {
                Text(identityTitle)
                    .font(ClarityStyle.title(22, weight: .semibold))
                    .foregroundStyle(ClarityStyle.ink)
                Text(identitySubtitle)
                    .font(ClarityStyle.body(12.5))
                    .foregroundStyle(ClarityStyle.inkSoft)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
    }

    private var authenticatedIdentitySource: MusicSource? {
        guard let source = home.displayedIdentitySource,
              LoginIdentityManager.shared.isLoggedIn(to: source) else { return nil }
        return source
    }

    private var identityTitle: String {
        home.displayedIdentityProfile?.nickname
            ?? authenticatedIdentitySource?.displayName
            ?? String(localized: "clarity_profile_guest")
    }

    private var identitySubtitle: String {
        home.displayedIdentityProfile?.signature
            ?? authenticatedIdentitySource.map { _ in String(localized: "login_identity_current") }
            ?? String(localized: "clarity_profile_signature")
    }

    private var avatar: some View {
        Group {
            if let raw = home.displayedIdentityProfile?.avatarUrl, let url = URL(string: raw) {
                CachedAsyncImage(url: url.sized(400), width: 82, height: 82) { avatarPlaceholder }
                    .aspectRatio(contentMode: .fill)
            } else {
                avatarPlaceholder
            }
        }
        .frame(width: 82, height: 82)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white.opacity(0.92), lineWidth: 1.25))
        .shadow(color: Color.black.opacity(0.10), radius: 18, y: 10)
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(ClarityStyle.membraneStrong)
            .overlay(MonoIcon(icon: .profile, size: 28, color: ClarityStyle.inkSoft, lineWidth: 1.4))
    }

    private var metrics: some View {
        HStack(spacing: 8) {
            metric(value: home.displayedIdentityProfile?.follows ?? 0, label: String(localized: "clarity_profile_follows"))
            metric(value: home.displayedIdentityProfile?.followeds ?? 0, label: String(localized: "clarity_profile_followers"))
            metric(value: home.displayedIdentityProfile?.eventCount ?? 0, label: String(localized: "clarity_profile_events"))
        }
    }

    private func metric(value: Int, label: String) -> some View {
        VStack(spacing: 5) {
            Text("\(value)")
                .font(ClarityStyle.title(20, weight: .semibold))
                .foregroundStyle(ClarityStyle.ink)
            Text(label)
                .font(ClarityStyle.body(10.5, weight: .medium))
                .foregroundStyle(ClarityStyle.inkFaint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background {
            ClarityMembrane(
                shape: RoundedRectangle(cornerRadius: 18, style: .continuous),
                strength: .quiet
            )
        }
    }

    private func destinationCard(icon: MonoIcon.IconType, title: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                MonoIcon(icon: icon, size: 19, color: ClarityStyle.ink, lineWidth: 1.5)
                    .frame(width: 42, height: 42)
                    .background(ClarityMembrane(shape: Circle(), strength: .quiet, tint: tint))
                Spacer(minLength: 8)
                MonoIcon(icon: .chevronRight, size: 12, color: ClarityStyle.inkFaint, lineWidth: 1.4)
            }

            Text(title)
                .font(ClarityStyle.body(13, weight: .semibold))
                .foregroundStyle(ClarityStyle.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .background {
            ClarityMembrane(
                shape: RoundedRectangle(cornerRadius: 28, style: .continuous),
                strength: .strong,
                tint: tint.opacity(0.18)
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func actionRow(icon: MonoIcon.IconType, title: String) -> some View {
        HStack(spacing: 12) {
            MonoIcon(icon: icon, size: 18, color: ClarityStyle.ink, lineWidth: 1.5)
                .frame(width: 36, height: 52)
            Text(title)
                .font(ClarityStyle.body(13.5, weight: .semibold))
                .foregroundStyle(ClarityStyle.ink)
            Spacer()
            MonoIcon(icon: .chevronRight, size: 13, color: ClarityStyle.inkFaint, lineWidth: 1.4)
        }
    }
}
