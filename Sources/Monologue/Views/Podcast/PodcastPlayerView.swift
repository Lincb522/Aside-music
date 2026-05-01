import SwiftUI

struct PodcastPlayerView: View {
    let radioId: Int
    @State private var viewModel: PodcastPlayerViewModel
    @ObservedObject private var player = PlayerManager.shared
    @ObservedObject private var timePublisher = PlaybackTimePublisher.shared
    @ObservedObject private var subManager = SubscriptionManager.shared
    @ObservedObject private var settings = SettingsManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showEpisodeList = false
    @State private var showSpeedSheet = false
    @State private var showTimerSheet = false
    @State private var showPlaylist = false

    init(radioId: Int) {
        self.radioId = radioId
        _viewModel = State(initialValue: PodcastPlayerViewModel(radioId: radioId))
    }

    var body: some View {
        let _ = settings.globalThemeRevision

        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            if viewModel.isLoading && viewModel.radioDetail == nil {
                loadingState
            } else if let error = viewModel.errorMessage, viewModel.radioDetail == nil {
                errorState(error)
            } else {
                mainContent
            }
        }
        .onAppear {
            viewModel.fetchDetail()
        }
        .monologueSheet(isPresented: $showEpisodeList, preset: .standard){
            PodcastEpisodeListSheet(viewModel: viewModel)

        }
        .monologueSheet(isPresented: $showSpeedSheet, preset: .compact){
            PodcastSpeedSheet()

        }
        .monologueSheet(isPresented: $showTimerSheet, preset: .standard){
            PodcastTimerSheet()
        }
        .monologueSheet(isPresented: $showPlaylist, preset: .standard){
            PodcastPlaylistPopupView()
        }
    }

    // MARK: - Loading

    private var loadingState: some View {
        VStack(spacing: 16) {
            topBar
                .padding(.top, DeviceLayout.headerTopPadding)
            Spacer()
            MonologueLoadingView(text: "LOADING")
            Spacer()
        }
    }

    // MARK: - Error

    private func errorState(_ error: String) -> some View {
        VStack(spacing: 16) {
            topBar
                .padding(.top, DeviceLayout.headerTopPadding)
            Spacer()
            MonologueIcon(icon: .warning, size: 40, color: .monologueTextSecondary)
            Text(error)
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(.monologueTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button(String(localized: "radio_retry")) {
                viewModel.fetchDetail()
            }
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .foregroundColor(.monologueIconForeground)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(Color.monologueIconBackground)
            .clipShape(Capsule())
            Spacer()
        }
    }

    // MARK: - Main

    private var mainContent: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.top, DeviceLayout.headerTopPadding)

            Spacer()

            coverSection
                .padding(.horizontal, 48)

            Spacer().frame(height: 32)

            programInfoSection
                .padding(.horizontal, 32)

            Spacer().frame(height: 24)

            PodcastEpisodeBar(
                currentIndex: viewModel.currentProgramIndex,
                currentEpisodeNumber: viewModel.currentEpisodeNumber,
                totalCount: viewModel.totalProgramCount
            )
            .padding(.horizontal, 40)

            Spacer().frame(height: 32)

            PodcastControlsBar(
                isPlaying: viewModel.isRadioPlaying,
                isLoading: viewModel.isRadioLoading,
                onPrevious: { viewModel.previousProgram() },
                onSeekBack: { viewModel.seekBackward() },
                onPlayPause: { viewModel.handlePlayPause() },
                onSeekForward: { viewModel.seekForward() },
                onNext: { viewModel.nextProgram() }
            )

            Spacer().frame(height: 28)

            PodcastToolbar(
                onSpeedTap: { showSpeedSheet = true },
                onTimerTap: { showTimerSheet = true },
                onPlaylistTap: { showPlaylist = true }
            )

            Spacer().frame(height: 40)
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            MonologueBackButton(style: .dismiss)

            Spacer()

            if let radio = viewModel.radioDetail {
                Text(radio.name)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.monologueTextSecondary)
                    .lineLimit(1)
            }

            Spacer()

            if let radio = viewModel.radioDetail {
                // Ensure SwiftUI depends on the @Published array directly to trigger view reload correctly
                let isSubscribed = subManager.localSubscribedRadios.contains { $0.id == radio.id }
                
                Button(action: {
                    withAnimation {
                        subManager.toggleRadioSubscription(radio)
                    }
                }) {
                    MonologueIcon(
                        icon: isSubscribed ? .liked : .like,
                        size: 18,
                        color: isSubscribed ? .monologueAccent : .monologueTextPrimary,
                        lineWidth: 1.4
                    )
                    .frame(width: 40, height: 40)
                }
                .buttonStyle(MonologueBouncingButtonStyle())
            }

            Button(action: { showEpisodeList = true }) {
                MonologueIcon(icon: .list, size: 18, color: .monologueTextPrimary, lineWidth: 1.4)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(MonologueBouncingButtonStyle())
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Cover

    private var coverSection: some View {
        Group {
            if let coverURL = viewModel.currentProgram?.programCoverUrl ?? viewModel.radioDetail?.coverUrl {
                CachedAsyncImage(url: coverURL) {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.monologueTextSecondary.opacity(0.08))
                }
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(alignment: .bottom) {
                    coverProgressOverlay
                }
                .shadow(color: .black.opacity(0.15), radius: 24, x: 0, y: 12)
            } else {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.monologueTextSecondary.opacity(0.08))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(
                        MonologueIcon(icon: .radio, size: 56, color: .monologueTextSecondary.opacity(0.3), lineWidth: 1.2)
                    )
                    .overlay(alignment: .bottom) {
                        coverProgressOverlay
                    }
            }
        }
    }

    // MARK: - Program Info

    private var programInfoSection: some View {
        VStack(spacing: 6) {
            if let program = viewModel.currentProgram {
                Text(program.name ?? String(localized: "radio_unknown_program"))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.monologueTextPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                HStack(spacing: 8) {
                    if let radio = viewModel.radioDetail {
                        Text(radio.name)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(.monologueTextSecondary)
                    }
                    Circle()
                        .fill(Color.monologueTextSecondary.opacity(0.3))
                        .frame(width: 3, height: 3)
                    Text(String(format: String(localized: "radio_episode_format"), viewModel.currentEpisodeNumber, viewModel.totalProgramCount))
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.monologueTextSecondary)
                    if !program.durationText.isEmpty {
                        Circle()
                            .fill(Color.monologueTextSecondary.opacity(0.3))
                            .frame(width: 3, height: 3)
                        HStack(spacing: 3) {
                            MonologueIcon(icon: .clock, size: 11, color: .monologueTextSecondary)
                            Text(program.durationText)
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(.monologueTextSecondary)
                        }
                    }
                }
            } else if viewModel.isLoading {
                Text("radio_tuning")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.monologueTextSecondary)
            } else {
                Text("radio_no_programs")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.monologueTextSecondary)
            }
        }
    }

    private var coverProgressOverlay: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                let progress = CGFloat(timePublisher.progress)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.22))

                    Capsule()
                        .fill(.white.opacity(0.92))
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 4)

            HStack {
                Text(formatTime(timePublisher.currentTime))
                Spacer()
                Text(formatTime(timePublisher.duration))
            }
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(.white.opacity(0.92))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.16), .black.opacity(0.42)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite else { return "0:00" }
        let total = max(Int(seconds), 0)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

}
