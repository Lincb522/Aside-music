import SwiftUI
import Combine

struct LyricsView: View {
    let song: Song
    var onBackgroundTap: (() -> Void)?
    var adaptivePrimaryColor: Color? = nil
    var adaptiveSecondaryColor: Color? = nil
    var enforcesAdaptiveContrast = false
    @ObservedObject var player = PlayerManager.shared
    @ObservedObject private var viewModel = LyricViewModel.shared
    @StateObject private var coverColors = CoverColorExtractor()
    
    @State private var isUserScrolling = false
    @State private var userScrollTimer: Timer?
    
    @AppStorage("showTranslation") var showTranslation: Bool = true
    @AppStorage("enableKaraoke") var enableKaraoke: Bool = false
    @AppStorage(KaraokeWordStyle.storageKey) private var karaokeStyleRaw = KaraokeWordStyle.defaultStyle.rawValue
    @AppStorage("lyricColorMode") private var lyricColorMode: String = "default"
    @AppStorage("lyricSolidColorHex") private var lyricSolidColorHex: String = "007AFF"
    @AppStorage("lyricGradientStartHex") private var lyricGradientStartHex: String = "FF6B6B"
    @AppStorage("lyricGradientEndHex") private var lyricGradientEndHex: String = "4ECDC4"
    @AppStorage("lyricsForceUppercaseEnglish") private var forceUppercaseEnglish = false
    @AppStorage("playerDisplayFont") private var playerFontSelectionRaw = MonoPlayerFont.followThemeRawValue
    @AppStorage("playerCustomFontID") private var playerCustomFontID = ""
    @AppStorage("playerFontScale") private var playerFontScale = 1.0
    
    var body: some View {
        VStack {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(
                            CircularProgressViewStyle(
                                tint: adaptivePrimaryColor ?? .monoTextPrimary
                            )
                        )
                } else if !viewModel.hasLyrics {
                    Text("No Lyrics Available")
                        .font(.rounded(size: 18, weight: .medium))
                        .foregroundColor(
                            (adaptivePrimaryColor ?? .monoTextPrimary).opacity(0.6)
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onBackgroundTap?()
                        }
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 24) {
                                Color.clear.frame(height: 200)

                                ForEach(Array(viewModel.lyrics.enumerated()), id: \.element.id) { index, line in
                                    Button(action: {
                                        HapticManager.shared.light()
                                        PlayerManager.shared.seek(to: line.time)
                                    }) {
                                        renderedLyricLine(line, at: index)
                                        .frame(maxWidth: .infinity)
                                        .padding(.horizontal, 32)
                                        .animation(.easeInOut(duration: 0.3), value: viewModel.currentLineIndex)
                                    }
                                    .buttonStyle(.plain)
                                    .id(index)
                                }

                                Color.clear.frame(height: 300)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .scrollIndicators(.hidden)
                        .simultaneousGesture(
                            DragGesture().onChanged { _ in
                                isUserScrolling = true
                                resetScrollTimer()
                            }
                        )
                        .onChange(of: viewModel.currentLineIndex) { _, newIndex in
                            if !isUserScrolling {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                    proxy.scrollTo(newIndex, anchor: .center)
                                }
                            }
                        }
                        .onTapGesture {
                            isUserScrolling = false
                            onBackgroundTap?()
                        }
                        .onAppear {
                            isUserScrolling = false
                            proxy.monoRestoreLyricPosition(isCancelled: { isUserScrolling }) {
                                viewModel.currentLineIndex
                            }
                        }
                        .mask(
                            LinearGradient(
                                gradient: Gradient(stops: [
                                    .init(color: .clear, location: 0),
                                    .init(color: .black, location: 0.15),
                                    .init(color: .black, location: 0.85),
                                    .init(color: .clear, location: 1.0)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                }
            }
        .task(id: song.coverUrl?.absoluteString) {
            coverColors.extract(
                from: song.coverUrl?.sized(200).absoluteString
            )
        }
    }

    @ViewBuilder
    private func renderedLyricLine(_ line: LyricLine, at index: Int) -> some View {
        let isCurrent = index == viewModel.currentLineIndex
        if isCurrent {
            PlaybackTimeReader { currentTime, _ in
                if enableKaraoke && player.isPlaying {
                    TimelineView(
                        AppFrameRate.throttledTimeline(maximumFramesPerSecond: 60)
                    ) { _ in
                        karaokeLine(
                            line,
                            isCurrent: true,
                            currentTime: livePlaybackTime(publishedTime: currentTime)
                        )
                    }
                } else {
                    karaokeLine(line, isCurrent: true, currentTime: currentTime)
                }
            }
        } else {
            karaokeLine(line, isCurrent: false, currentTime: 0)
        }
    }

    private func karaokeLine(
        _ line: LyricLine,
        isCurrent: Bool,
        currentTime: TimeInterval
    ) -> some View {
        KaraokeLineView(
            line: line,
            isCurrent: isCurrent,
            currentTime: currentTime,
            progress: isCurrent ? viewModel.currentLineProgress : 0,
            showTranslation: showTranslation,
            enableKaraoke: enableKaraoke,
            lyricColorMode: lyricColorMode,
            lyricSolidColorHex: lyricSolidColorHex,
            lyricGradientStartHex: lyricGradientStartHex,
            lyricGradientEndHex: lyricGradientEndHex,
            lyricAutoPalette: coverColors.palette,
            forceUppercaseEnglish: forceUppercaseEnglish,
            playerFontSelectionRaw: playerFontSelectionRaw,
            playerCustomFontID: playerCustomFontID,
            playerFontScale: playerFontScale,
            karaokeStyle: KaraokeWordStyle.resolve(karaokeStyleRaw),
            adaptivePrimaryColor: adaptivePrimaryColor,
            adaptiveSecondaryColor: adaptiveSecondaryColor,
            enforcesAdaptiveContrast: enforcesAdaptiveContrast
        )
    }

    private func livePlaybackTime(publishedTime: TimeInterval) -> TimeInterval {
        LyricKaraokeTimeline.playbackTime(
            streamPlayerTime: player.streamPlayer.currentTime,
            publishedTime: publishedTime,
            isAppleMusic: player.currentSong?.isAppleMusic == true,
            appleMusicPlayerTime: player.appleMusicPlayback.renderingPlaybackTime
        )
    }
    
    private func resetScrollTimer() {
        userScrollTimer?.invalidate()
        userScrollTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            Task { @MainActor in
                withAnimation {
                    isUserScrolling = false
                }
            }
        }
    }
}
