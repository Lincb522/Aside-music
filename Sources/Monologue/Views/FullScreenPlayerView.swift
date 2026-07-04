import SwiftUI

/// 全屏播放器 - 路由层，根据主题切换不同布局
struct FullScreenPlayerView: View {
    @ObservedObject var player = PlayerManager.shared
    
    @ObservedObject private var themeManager = PlayerThemeManager.shared
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var cinemaController = CinemaModeController.shared
    @Environment(\.colorScheme) private var envColorScheme

    var body: some View {
        ZStack {
            Group {
                if SettingsManager.shared.coverBgPlayer && !MinimalWhiteStyle.isActive {
                    PlaylistColorBackground(coverUrl: player.currentSong?.coverUrl?.sized(200))
                } else {
                    ThemedPageBackground()
                }
            }
            .ignoresSafeArea()

            Group {
                if MinimalWhiteStyle.isActive {
                    ClassicPlayerLayout()
                } else {
                    switch themeManager.currentTheme {
                case .classic:
                    if PetWhiteStyle.isActive {
                        PawcelainPlayerLayout()
                    } else {
                        ClassicPlayerLayout()
                    }
                case .vinyl:
                    VinylPlayerLayout()
                case .lyricFocus:
                    MinimalPlayerLayout()
                case .card:
                    CardPlayerLayout()
                case .neumorphic:
                    NeumorphicPlayerLayout()
                case .poster:
                    PosterPlayerLayout()
                        .compatFontDesign(nil)
                case .motoPager:
                    MotoPagerLayout()
                case .typewriter:
                    TypewriterPlayerLayout()
                case .pixel:
                    PixelPlayerLayout()
                        .compatFontDesign(nil)
                case .aqua:
                    AquaPlayerLayout()
                case .breathing:
                    BreathingPlayerLayout()
                case .cassette:
                    CassettePlayerLayout()
                case .radio:
                    RadioPlayerLayout()
                case .immersiveLyric:
                    ImmersiveLyricPlayerLayout()
                case .mangaChat:
                    MangaChatPlayerLayout()
                case .folk:
                    FolkPlayerLayout()
                case .game2048:
                    Game2048PlayerLayout()
                case .cinema:
                    // 沉浸模式已从主题体系移出（经右上角三点菜单进入），旧存档回退经典布局
                    ClassicPlayerLayout()
                    }
                }
            }
            .environment(\.colorScheme, MinimalWhiteStyle.isActive ? settings.nativeColorScheme : (themeManager.currentTheme.hasCustomBackground ? settings.nativeColorScheme : envColorScheme))


        }
        .monologueEdgeSwipeToDismiss()
        .fullScreenCover(isPresented: $cinemaController.isPresented) {
            AriaStageView()
        }
    }

    // MARK: - 播放器进度条组件（供默认播放器及共享布局复用）

    struct WaveformProgressBar: View {
        @Binding var currentTime: Double
        let duration: Double
        var color: Color = .monologueTextPrimary
        /// 未播放部分的不透明度（默认 0.2，越低越融入背景）
        var trackOpacity: Double = 0.2
        var isAnimating: Bool = true
        let onSeek: (Double) -> Void
        let onCommit: (Double) -> Void

        var body: some View {
            let progress = duration > 0 ? CGFloat(min(max(currentTime / duration, 0), 1)) : 0

            GlobalWaveformPlaybackProgressBar(
                progress: progress,
                isPlaying: isAnimating,
                color: color,
                trackOpacity: trackOpacity,
                fillColors: progressFillColors,
                onSeek: { p in onSeek(Double(p) * duration) },
                onCommit: { p in onCommit(Double(p) * duration) }
            )
        }

        private var progressFillColors: [Color] {
            if MinimalWhiteStyle.isActive { return [MinimalWhiteStyle.accent, MinimalWhiteStyle.accent] }
            if MangaStyle.isActive { return [MangaStyle.accentPink, MangaStyle.labelYellow] }
            if MujiStyle.isActive { return [MujiStyle.clay, MujiStyle.indigo.opacity(0.86)] }
            if NeumorphicStyle.isActive { return [NeumorphicStyle.accent, NeumorphicStyle.sage] }
            if CapsuleStyle.isActive { return CapsuleStyle.accentGradient }
            if SequoiaStyle.isActive { return [SequoiaStyle.accent, SequoiaStyle.aqua] }
            if LiquidGlassStyle.isActive { return [LiquidGlassStyle.accent, LiquidGlassStyle.cyan, LiquidGlassStyle.violet] }
            if ClayStyle.isActive { return [ClayStyle.sky, ClayStyle.peach] }
            if SignalStyle.isActive { return [SignalStyle.accent, SignalStyle.mint] }
            if BentoStyle.isActive { return [BentoStyle.tomato, BentoStyle.mustard] }
            return [color.opacity(0.66), color.opacity(0.96)]
        }
        
    }
}
