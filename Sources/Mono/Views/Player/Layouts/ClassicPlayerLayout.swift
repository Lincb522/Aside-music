import SwiftUI
import FFmpegSwiftSDK

enum ClassicPlayerPresentation {
    case aside
    case muji
    case capsule
    case minimalWhite
}

/// 经典播放器布局 - 完全还原原始 FullScreenPlayerView 布局，仅增加主题切换按钮
struct ClassicPlayerLayout: View {
    let presentation: ClassicPlayerPresentation

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @ObservedObject var player = PlayerManager.shared
    @ObservedObject var downloadStatus = DownloadedSongStatusModel.shared
    @ObservedObject var settings = SettingsManager.shared
    @StateObject var asideCoverColors = CoverColorExtractor()

    @State var isDraggingSlider = false
    @State var dragTimeValue: Double = 0
    @State var showPlaylist = false
    @State var showQualitySheet = false
    @State var showLyrics = false
    @State var showComments = false
    @State var showEQSettings = false
    @State var showThemePicker = false
    @State var showMoreMenu = false
    @State var showArtistDetail = false
    @State var showDownloadSheet = false

    init(presentation: ClassicPlayerPresentation = .aside) {
        self.presentation = presentation
    }

    var usesMinimalWhiteStyle: Bool { presentation == .minimalWhite }
    var usesMujiStyle: Bool { presentation == .muji }
    var usesCapsuleStyle: Bool { presentation == .capsule }
    var usesMangaStyle: Bool { false }
    var usesNeumorphicStyle: Bool { false }
    var usesSequoiaStyle: Bool { false }
    var usesClayStyle: Bool { false }
    var isThemedClassic: Bool { presentation != .aside }

    var contentColor: Color {
        if usesMinimalWhiteStyle { return MinimalWhiteStyle.ink }
        if usesMangaStyle { return MangaStyle.ink }
        if usesMujiStyle { return MujiStyle.ink }
        if usesNeumorphicStyle { return NeumorphicStyle.ink }
        if usesCapsuleStyle { return CapsuleStyle.ink }
        if usesSequoiaStyle { return SequoiaStyle.ink }
        if usesClayStyle { return ClayStyle.ink }
        return .primary
    }

    var secondaryContentColor: Color {
        if usesMinimalWhiteStyle { return MinimalWhiteStyle.inkMuted }
        if usesMangaStyle { return MangaStyle.inkSub }
        if usesMujiStyle { return MujiStyle.inkSoft }
        if usesNeumorphicStyle { return NeumorphicStyle.inkSoft }
        if usesCapsuleStyle { return CapsuleStyle.inkSoft }
        if usesSequoiaStyle { return SequoiaStyle.inkSoft }
        if usesClayStyle { return ClayStyle.inkSoft }
        return .secondary
    }

    var asideCoverAccent: Color {
        guard player.currentSong != nil else { return .monoIconBackground }
        return asideCoverColors.dominantColor
    }

    var asideCoverAccentForeground: Color {
        ThemeColorCustomization.readableForegroundColor(
            on: asideCoverAccent,
            light: Color(hex: "111318"),
            dark: .white
        )
    }

    var progressColor: Color {
        if usesMinimalWhiteStyle { return MinimalWhiteStyle.ink }
        if usesMangaStyle { return MangaStyle.accentPink }
        if usesMujiStyle { return MujiStyle.clay }
        if usesNeumorphicStyle { return NeumorphicStyle.accent }
        if usesCapsuleStyle { return CapsuleStyle.accent }
        if usesSequoiaStyle { return SequoiaStyle.accent }
        if usesClayStyle { return ClayStyle.accent }
        return contentColor.opacity(0.7)
    }

    var classicArtworkCornerRadius: CGFloat {
        if usesMinimalWhiteStyle { return 12 }
        if usesMangaStyle { return 12 }
        if usesMujiStyle { return 22 }
        if usesNeumorphicStyle { return 22 }
        if usesCapsuleStyle { return 28 }
        if usesSequoiaStyle { return 24 }
        if usesClayStyle { return 30 }
        return isThemedClassic ? 24 : 14
    }

    func classicTitleFont(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        if usesMinimalWhiteStyle { return MinimalWhiteStyle.titleFont(size, weight: weight) }
        if usesMangaStyle { return MangaStyle.titleFont(size, weight: .black) }
        if usesMujiStyle { return MujiStyle.titleFont(size, weight: weight == .bold ? .medium : weight) }
        if usesNeumorphicStyle { return NeumorphicStyle.titleFont(size, weight: weight == .bold ? .semibold : weight) }
        if usesCapsuleStyle { return CapsuleStyle.titleFont(size, weight: weight == .bold ? .bold : weight) }
        if usesSequoiaStyle { return SequoiaStyle.titleFont(size, weight: weight == .bold ? .semibold : weight) }
        if usesClayStyle { return ClayStyle.titleFont(size, weight: weight == .bold ? .bold : weight) }
        return .rounded(size: size, weight: weight)
    }

    func classicBodyFont(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        if usesMinimalWhiteStyle { return MinimalWhiteStyle.bodyFont(size, weight: weight) }
        if usesMangaStyle { return MangaStyle.bodyFont(size, weight: weight == .regular ? .bold : weight) }
        if usesMujiStyle { return MujiStyle.bodyFont(size, weight: weight == .bold ? .medium : weight) }
        if usesNeumorphicStyle { return NeumorphicStyle.bodyFont(size, weight: weight) }
        if usesCapsuleStyle { return CapsuleStyle.bodyFont(size, weight: weight) }
        if usesSequoiaStyle { return SequoiaStyle.bodyFont(size, weight: weight == .bold ? .semibold : weight) }
        if usesClayStyle { return ClayStyle.bodyFont(size, weight: weight) }
        return .rounded(size: size, weight: weight)
    }

    var body: some View {
        let _ = settings.globalThemeRevision

        GeometryReader { geometry in
            ZStack {
                if isThemedClassic {
                    classicThemeBackdrop
                }

                if showLyrics && !isThemedClassic {
                    Rectangle()
                        .fill(Color.monoGlassTint)
                        .monoGlass(cornerRadius: 16)
                        .ignoresSafeArea()
                        .transition(.opacity)
                }

                if usesMangaStyle {
                    mangaPlayerContent(geometry: geometry)
                } else if usesMujiStyle {
                    mujiPlayerContent(geometry: geometry)
                } else if usesNeumorphicStyle {
                    neumorphicPlayerContent(geometry: geometry)
                } else if usesCapsuleStyle {
                    capsulePlayerContent(geometry: geometry)
                } else if usesClayStyle {
                    clayPlayerContent(geometry: geometry)
                } else if isThemedClassic {
                    classicPlayerContent(geometry: geometry)
                } else {
                    asideDefaultPlayerContent(geometry: geometry)
                }
            }
            .playerMoreMenuOverlay { anchorFrame in
                if showMoreMenu {
                    PlayerMoreMenu(
                        isPresented: $showMoreMenu,
                        anchorFrame: anchorFrame,
                        onEQ: { showEQSettings = true },
                        onTheme: { showThemePicker = true }
                    )
                }
            }
        }
        .monoSheet(isPresented: $showPlaylist, preset: .standard){
            PlaylistPopupView()

        }
        .onAppear {
            refreshAsideCoverAccent()
        }
        .onChange(of: player.currentSong?.coverUrl?.absoluteString) { _, _ in
            refreshAsideCoverAccent()
        }
        .onChange(of: isThemedClassic) { _, themed in
            if !themed {
                refreshAsideCoverAccent()
            }
        }
        .monoSheet(isPresented: $showQualitySheet, preset: .standard){
            SoundQualitySheet(
                currentQuality: player.soundQuality,
                currentQQQuality: player.qqMusicQuality,
                isQQMusic: player.currentSong?.isQQMusic == true,
                onSelectNetease: { quality in
                    player.switchQuality(quality)
                    showQualitySheet = false
                },
                onSelectQQ: { quality in
                    player.switchQQMusicQuality(quality)
                    showQualitySheet = false
                },
                songMid: player.currentSong?.qqMid,
                songId: player.currentSong?.id,
                isQishui: player.currentSong?.isQishui == true,
                qishuiTrackId: player.currentSong?.qishuiTrackId,
                onSelectQishui: { info in player.switchQishuiQuality(info); showQualitySheet = false }
            )

        }
        .fullScreenCover(isPresented: $showEQSettings) {
            NavigationStack { MonoAudioCenterView() }

        }
        .monoSheet(isPresented: $showThemePicker, preset: .themePicker){
            PlayerThemePickerSheet()

        }
        .monoSheet(isPresented: $showComments, preset: .large){
            if let song = player.currentSong {
                CommentView(song: song)

            }
        }
        .monoSheet(isPresented: $showArtistDetail, preset: .detail){
            if let song = player.currentSong {
                NavigationStack {
                    if song.isQQMusic, let mid = song.qqArtistMid {
                        QQMusicDetailView(detailType: .artist(mid: mid, name: song.artistName, coverUrl: nil))
                    } else if let artistId = song.ar?.first?.id {
                        ArtistDetailView(artistId: artistId)
                    }
                }

            }
        }
        .monoSheet(isPresented: $showDownloadSheet, preset: .compact){
            if let song = player.currentSong {
                DownloadQualitySheet(song: song) {
                    showDownloadSheet = false
                }

            }
        }
    }

}
