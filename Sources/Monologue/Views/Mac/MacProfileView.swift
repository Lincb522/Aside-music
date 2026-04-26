#if os(macOS)
import SwiftUI

struct MacProfileView: View {
    @ObservedObject private var viewModel = HomeViewModel.shared
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    @ObservedObject private var player = PlayerManager.shared

    @State private var showLoginView = false
    @State private var recentSongs: [Song] = []
    @State private var hasAppeared = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            ThemedPageBackground().ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    if isLoggedIn {
                        loggedInContent
                    } else {
                        notLoggedInContent
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 12)
                .padding(.bottom, 80)
            }
            .scrollIndicators(.hidden)
        }
        .sheet(isPresented: $showLoginView) {
            LoginView()
                .frame(minWidth: 400, minHeight: 500)
        }
        .onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
            fetchRecentSongs()
        }
    }

    // MARK: - Logged In

    private var loggedInContent: some View {
        VStack(spacing: 28) {
            profileHeader

            if !recentSongs.isEmpty {
                recentSection
            }

            menuGrid
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        HStack(spacing: 20) {
            if let avatarUrl = viewModel.userProfile?.avatarUrl, let url = URL(string: avatarUrl) {
                CachedAsyncImage(url: url) {
                    Circle().fill(Color.primary.opacity(0.06))
                }
                .aspectRatio(1, contentMode: .fill)
                .frame(width: 72, height: 72)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            } else {
                Circle()
                    .fill(Color.primary.opacity(0.06))
                    .frame(width: 72, height: 72)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.tertiary)
                    )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(viewModel.userProfile?.nickname ?? "User")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                if let sig = viewModel.userProfile?.signature, !sig.isEmpty {
                    Text(sig)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            NavigationLink(destination: SettingsView()) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.primary.opacity(0.06)))
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.white.opacity(0.7))
        )
    }

    // MARK: - Recent

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(String(localized: "recently_played"))
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)

                Spacer()
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 8) {
                ForEach(Array(recentSongs.prefix(6).enumerated()), id: \.element.id) { idx, song in
                    MacSongRow(song: song, index: idx + 1) {
                        player.play(song: song, in: recentSongs)
                    }
                }
            }
        }
    }

    // MARK: - Menu

    private var menuGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 3), spacing: 14) {
            MacMenuCard(icon: "arrow.down.circle.fill", title: String(localized: "download_manage"), gradient: [Color(hex: "667eea"), Color(hex: "764ba2")]) {
                // TODO: open download manage
            }
            MacMenuCard(icon: "externaldrive.fill", title: String(localized: "storage_manage"), gradient: [Color(hex: "f093fb"), Color(hex: "f5576c")]) {
                // TODO: open storage manage
            }
            MacMenuCard(icon: "cloud.fill", title: String(localized: "cloud_disk"), gradient: [Color(hex: "4facfe"), Color(hex: "00f2fe")]) {
                // TODO: open cloud disk
            }
        }
    }

    // MARK: - Not Logged In

    private var notLoggedInContent: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 80)

            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text(String(localized: "not_logged_in_title"))
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)

            Button(action: { showLoginView = true }) {
                Text(String(localized: "login_button"))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.primary))
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    private func fetchRecentSongs() {
        Task {
            if let songs = try? await APIService.shared.fetchRecentSongs().async() {
                await MainActor.run { recentSongs = songs }
            }
        }
    }
}

// MARK: - Menu Card

struct MacMenuCard: View {
    let icon: String
    let title: String
    let gradient: [Color]
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)

                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .scaleEffect(isHovered ? 1.03 : 1.0)
            .shadow(color: gradient.first!.opacity(isHovered ? 0.3 : 0.15), radius: isHovered ? 10 : 5, y: isHovered ? 4 : 2)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
#endif
