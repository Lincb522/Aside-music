import SwiftUI

struct PodcastPlayerView: View {
    let radioId: Int
    @StateObject private var viewModel: PodcastPlayerViewModel
    @ObservedObject private var player = PlayerManager.shared
    @ObservedObject private var timePublisher = PlaybackTimePublisher.shared
    @ObservedObject private var subManager = SubscriptionManager.shared
    @ObservedObject private var settings = SettingsManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showEpisodeList = false
    @State private var showSpeedSheet = false
    @State private var showTimerSheet = false
    @State private var showPlaylist = false
    @State private var isScrubbing = false
    @State private var scrubProgress: Double = 0

    init(radioId: Int) {
        self.radioId = radioId
        _viewModel = StateObject(wrappedValue: PodcastPlayerViewModel(radioId: radioId))
    }

    private var isAside: Bool {
        !ThemedPageStyle.isActive
    }

    var body: some View {
        let _ = settings.globalThemeRevision

        ZStack {
            if MinimalWhiteStyle.isActive {
                MinimalWhiteRootBackdrop()
            } else {
                Color(.systemBackground)
                    .ignoresSafeArea()
            }

            if viewModel.isLoading && viewModel.radioDetail == nil {
                loadingState
            } else if let error = viewModel.errorMessage, viewModel.radioDetail == nil {
                errorState(error)
            } else if isAside {
                asideMainContent
            } else {
                mainContent
            }
        }
        .onAppear {
            viewModel.fetchDetail()
        }
        .monoSheet(isPresented: $showEpisodeList, preset: .standard){
            PodcastEpisodeListSheet(viewModel: viewModel)

        }
        .monoSheet(isPresented: $showSpeedSheet, preset: .compact){
            PodcastSpeedSheet()

        }
        .monoSheet(isPresented: $showTimerSheet, preset: .standard){
            PodcastTimerSheet()
        }
        .monoSheet(isPresented: $showPlaylist, preset: .standard){
            PodcastPlaylistPopupView()
        }
    }

    // MARK: - Loading

    private var loadingState: some View {
        VStack(spacing: 16) {
            Group {
                if isAside {
                    asideTopBar
                } else {
                    topBar
                }
            }
            .padding(.top, DeviceLayout.headerTopPadding)
            Spacer()
            MonoLoadingView(text: MinimalWhiteStyle.isActive ? nil : "LOADING")
            Spacer()
        }
    }

    // MARK: - Error

    private func errorState(_ error: String) -> some View {
        VStack(spacing: 16) {
            Group {
                if isAside {
                    asideTopBar
                } else {
                    topBar
                }
            }
            .padding(.top, DeviceLayout.headerTopPadding)
            Spacer()
            if MinimalWhiteStyle.isActive {
                MinimalWhiteIconBadge(icon: .warning, size: 56)
            } else {
                MonoIcon(icon: .warning, size: 40, color: .monoTextSecondary)
            }
            Text(error)
                .font(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.labelFont(14, weight: .medium) : .system(size: 14, design: .rounded))
                .foregroundColor(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.inkMuted : .monoTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button(String(localized: "radio_retry")) {
                viewModel.fetchDetail()
            }
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .foregroundColor(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.onAccent : .monoIconForeground)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.ink : Color.monoIconBackground)
            .clipShape(Capsule())
            Spacer()
        }
    }

    // MARK: - aside 版式

    private var asideMainContent: some View {
        VStack(spacing: 0) {
            asideTopBar
                .padding(.top, DeviceLayout.headerTopPadding)

            Spacer(minLength: 16)

            asideCoverSection
                .padding(.horizontal, 52)

            Spacer(minLength: 16)

            asideProgramInfo
                .padding(.horizontal, 34)

            Spacer().frame(height: 24)

            asideProgressSection
                .padding(.horizontal, 34)

            Spacer().frame(height: 16)

            PodcastEpisodeBar(
                currentIndex: viewModel.currentProgramIndex,
                currentEpisodeNumber: viewModel.currentEpisodeNumber,
                totalCount: viewModel.totalProgramCount
            )
            .padding(.horizontal, 44)

            Spacer().frame(height: 26)

            PodcastControlsBar(
                isPlaying: viewModel.isRadioPlaying,
                isLoading: viewModel.isRadioLoading,
                onPrevious: { viewModel.previousProgram() },
                onSeekBack: { viewModel.seekBackward() },
                onPlayPause: { viewModel.handlePlayPause() },
                onSeekForward: { viewModel.seekForward() },
                onNext: { viewModel.nextProgram() }
            )

            Spacer().frame(height: 24)

            PodcastToolbar(
                onSpeedTap: { showSpeedSheet = true },
                onTimerTap: { showTimerSheet = true },
                onPlaylistTap: { showPlaylist = true }
            )

            Spacer().frame(height: 38)
        }
    }

    private var asideTopBar: some View {
        HStack(spacing: 12) {
            MonoBackButton(style: .dismiss)

            Spacer(minLength: 0)

            VStack(spacing: 3) {
                Text("PODCAST")
                    .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                    .tracking(2.2)
                    .foregroundColor(.monoTextSecondary.opacity(0.65))

                if let radio = viewModel.radioDetail {
                    Text(radio.name)
                        .font(.rounded(size: 12.5, weight: .semibold))
                        .foregroundColor(.monoTextPrimary.opacity(0.85))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)

            Spacer(minLength: 0)

            if let radio = viewModel.radioDetail {
                let isSubscribed = subManager.localSubscribedRadios.contains { $0.id == radio.id }

                Button(action: {
                    withAnimation {
                        subManager.toggleRadioSubscription(radio)
                    }
                }) {
                    MonoIcon(
                        icon: isSubscribed ? .liked : .like,
                        size: 15,
                        color: isSubscribed ? .monoAccent : .monoTextPrimary,
                        lineWidth: 1.5
                    )
                    .frame(width: 36, height: 36)
                    .overlay(Circle().stroke(Color.monoSeparator.opacity(0.9), lineWidth: 0.8))
                    .contentShape(Circle())
                }
                .buttonStyle(MonoBouncingButtonStyle(scale: 0.92))
            }

            Button(action: { showEpisodeList = true }) {
                MonoIcon(icon: .list, size: 15, color: .monoTextPrimary, lineWidth: 1.5)
                    .frame(width: 36, height: 36)
                    .overlay(Circle().stroke(Color.monoSeparator.opacity(0.9), lineWidth: 0.8))
                    .contentShape(Circle())
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.92))
        }
        .padding(.horizontal, 20)
    }

    private var asideCoverSection: some View {
        Group {
            if let coverURL = viewModel.currentProgram?.programCoverUrl ?? viewModel.radioDetail?.coverUrl {
                CachedAsyncImage(url: coverURL) {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(Color.monoSeparator.opacity(0.35))
                }
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color.monoSeparator.opacity(0.35))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(
                        MonoIcon(icon: .radio, size: 52, color: .monoTextSecondary.opacity(0.35), lineWidth: 1.2)
                    )
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.monoTextPrimary.opacity(0.08), lineWidth: 0.8)
        )
        .shadow(color: .black.opacity(0.14), radius: 26, x: 0, y: 14)
    }

    private var asideProgramInfo: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.monoAccent)
                    .frame(width: 4, height: 4)

                Text(String(format: String(localized: "radio_episode_format"), viewModel.currentEpisodeNumber, viewModel.totalProgramCount))
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .tracking(0.6)
                    .monospacedDigit()
                    .foregroundColor(.monoTextSecondary.opacity(0.85))

                if let program = viewModel.currentProgram, !program.durationText.isEmpty {
                    Circle()
                        .fill(Color.monoTextSecondary.opacity(0.4))
                        .frame(width: 2.5, height: 2.5)

                    Text(program.durationText)
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .tracking(0.6)
                        .monospacedDigit()
                        .foregroundColor(.monoTextSecondary.opacity(0.85))
                }
            }

            Group {
                if let program = viewModel.currentProgram {
                    Text(program.name ?? String(localized: "radio_unknown_program"))
                        .foregroundColor(.monoTextPrimary)
                } else if viewModel.isLoading {
                    Text("radio_tuning")
                        .foregroundColor(.monoTextSecondary)
                } else {
                    Text("radio_no_programs")
                        .foregroundColor(.monoTextSecondary)
                }
            }
            .font(.system(size: 20, weight: .heavy, design: .rounded))
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.8)
        }
    }

    /// aside 进度条：支持拖动跳转
    private var asideProgressSection: some View {
        VStack(spacing: 7) {
            GeometryReader { geo in
                let progress: Double = {
                    if isScrubbing { return scrubProgress }
                    guard timePublisher.duration > 0 else { return 0 }
                    return min(max(timePublisher.currentTime / timePublisher.duration, 0), 1)
                }()

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.monoSeparator.opacity(0.6))

                    Capsule()
                        .fill(Color.monoTextPrimary.opacity(0.85))
                        .frame(width: max(0, geo.size.width * CGFloat(progress)))
                }
                .frame(height: isScrubbing ? 6.5 : 3.5)
                .frame(maxHeight: .infinity, alignment: .center)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isScrubbing = true
                            scrubProgress = min(max(value.location.x / geo.size.width, 0), 1)
                        }
                        .onEnded { value in
                            let target = min(max(value.location.x / geo.size.width, 0), 1)
                            if timePublisher.duration > 0 {
                                player.seek(to: target * timePublisher.duration)
                            }
                            isScrubbing = false
                        }
                )
            }
            .frame(height: 20)
            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isScrubbing)

            HStack {
                Text(formatTime(isScrubbing ? scrubProgress * timePublisher.duration : timePublisher.currentTime))
                Spacer()
                Text(formatTime(timePublisher.duration))
            }
            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
            .foregroundColor(.monoTextSecondary.opacity(0.85))
        }
    }

    // MARK: - Main（其他主题）

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
            MonoBackButton(style: .dismiss)

            Spacer()

            if let radio = viewModel.radioDetail {
                Text(radio.name)
                    .font(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.labelFont(13, weight: .regular) : .system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.inkMuted : .monoTextSecondary)
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
                    MonoIcon(
                        icon: isSubscribed ? .liked : .like,
                        size: 18,
                        color: MinimalWhiteStyle.isActive ? (isSubscribed ? MinimalWhiteStyle.ink : MinimalWhiteStyle.inkMuted) : (isSubscribed ? .monoAccent : .monoTextPrimary),
                        lineWidth: 1.4
                    )
                    .frame(width: 40, height: 40)
                    .background {
                        if MinimalWhiteStyle.isActive {
                            MinimalWhiteCircleBackground(elevated: false, selected: isSubscribed)
                        }
                    }
                }
                .buttonStyle(MonoBouncingButtonStyle())
            }

            Button(action: { showEpisodeList = true }) {
                MonoIcon(icon: .list, size: 18, color: MinimalWhiteStyle.isActive ? MinimalWhiteStyle.inkMuted : .monoTextPrimary, lineWidth: 1.4)
                    .frame(width: 40, height: 40)
                    .background {
                        if MinimalWhiteStyle.isActive {
                            MinimalWhiteCircleBackground(elevated: false)
                        }
                    }
            }
            .buttonStyle(MonoBouncingButtonStyle())
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Cover

    private var coverSection: some View {
        Group {
            if let coverURL = viewModel.currentProgram?.programCoverUrl ?? viewModel.radioDetail?.coverUrl {
                CachedAsyncImage(url: coverURL) {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.controlGlassFill : Color.monoTextSecondary.opacity(0.08))
                }
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(alignment: .bottom) {
                    coverProgressOverlay
                }
                .overlay {
                    if MinimalWhiteStyle.isActive {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(MinimalWhiteStyle.hairline, lineWidth: MinimalWhiteStyle.strokeWidth)
                    }
                }
                .shadow(color: MinimalWhiteStyle.isActive ? MinimalWhiteStyle.ink.opacity(0.06) : .black.opacity(0.15), radius: MinimalWhiteStyle.isActive ? 14 : 24, x: 0, y: MinimalWhiteStyle.isActive ? 6 : 12)
            } else {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.controlGlassFill : Color.monoTextSecondary.opacity(0.08))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(
                        MonoIcon(icon: .radio, size: 56, color: MinimalWhiteStyle.isActive ? MinimalWhiteStyle.inkMuted.opacity(0.6) : .monoTextSecondary.opacity(0.3), lineWidth: 1.2)
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
                    .foregroundColor(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.ink : .monoTextPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                HStack(spacing: 8) {
                    if let radio = viewModel.radioDetail {
                        Text(radio.name)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.inkMuted : .monoTextSecondary)
                    }
                    Circle()
                        .fill(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.hairline : Color.monoTextSecondary.opacity(0.3))
                        .frame(width: 3, height: 3)
                    Text(String(format: String(localized: "radio_episode_format"), viewModel.currentEpisodeNumber, viewModel.totalProgramCount))
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.inkMuted : .monoTextSecondary)
                    if !program.durationText.isEmpty {
                        Circle()
                            .fill(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.hairline : Color.monoTextSecondary.opacity(0.3))
                            .frame(width: 3, height: 3)
                        HStack(spacing: 3) {
                            MonoIcon(icon: .clock, size: 11, color: MinimalWhiteStyle.isActive ? MinimalWhiteStyle.inkMuted : .monoTextSecondary)
                            Text(program.durationText)
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.inkMuted : .monoTextSecondary)
                        }
                    }
                }
            } else if viewModel.isLoading {
                Text("radio_tuning")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.inkMuted : .monoTextSecondary)
            } else {
                Text("radio_no_programs")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.inkMuted : .monoTextSecondary)
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
