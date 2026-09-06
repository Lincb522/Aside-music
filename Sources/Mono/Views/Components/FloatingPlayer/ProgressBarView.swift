import SwiftUI

struct ProgressBarView: View {
    @Environment(\.floatingBarColorRevision) private var colorRevision
    var height: CGFloat = 3
    var minFillWidth: CGFloat = 5

    @ObservedObject private var timePublisher = PlaybackTimePublisher.shared

    var body: some View {
        let _ = colorRevision

        GlobalPlaybackProgressBar(
            progress: CGFloat(timePublisher.progress),
            height: height,
            minFillWidth: minFillWidth,
            trackColor: trackColor,
            strokeColor: strokeColor,
            fillColors: progressFillColors
        )
    }

    private var trackColor: Color {
        if MinimalWhiteStyle.isActive {
            return MinimalWhiteStyle.separator
        } else if MangaStyle.isActive {
            return MangaStyle.separator.opacity(0.6)
        } else if PetWhiteStyle.isActive {
            return PetWhiteStyle.ink.opacity(0.12)
        } else if PureWhiteStyle.isActive {
            return PureWhiteStyle.separator.opacity(0.7)
        } else if MujiStyle.isActive {
            return MujiStyle.separator.opacity(0.55)
        } else if NeumorphicStyle.isActive {
            return NeumorphicStyle.surfacePressed.opacity(0.9)
        } else if SequoiaStyle.isActive {
            return SequoiaStyle.separator.opacity(0.58)
        } else if LiquidGlassStyle.isActive {
            return LiquidGlassStyle.separator.opacity(0.72)
        } else if SignalStyle.isActive {
            return SignalStyle.separator.opacity(0.52)
        } else if CapsuleStyle.isActive {
            return CapsuleStyle.separator.opacity(0.58)
        }
        return Color.monoTextPrimary.opacity(0.06)
    }

    private var strokeColor: Color? {
        if PetWhiteStyle.isActive {
            return PetWhiteStyle.surfaceRaised.opacity(0.78)
        }
        return nil
    }

    private var progressFillColors: [Color] {
        if MinimalWhiteStyle.isActive {
            return [MinimalWhiteStyle.accent, MinimalWhiteStyle.accent]
        } else if MangaStyle.isActive {
            return [MangaStyle.ink, MangaComicPalette.toneMid]
        } else if PetWhiteStyle.isActive {
            return [PetWhiteStyle.dogOrange, PetWhiteStyle.dogEar, PetWhiteStyle.blush.opacity(0.94)]
        } else if PureWhiteStyle.isActive {
            return [PureWhiteStyle.accent, PureWhiteStyle.paperBlue, PureWhiteStyle.inkSoft.opacity(0.42)]
        } else if MujiStyle.isActive {
            return [MujiStyle.clay, MujiStyle.indigo.opacity(0.86)]
        } else if NeumorphicStyle.isActive {
            return [NeumorphicStyle.accent, NeumorphicStyle.sage]
        } else if SequoiaStyle.isActive {
            return [SequoiaStyle.accent, SequoiaStyle.aqua]
        } else if LiquidGlassStyle.isActive {
            return [LiquidGlassStyle.accent, LiquidGlassStyle.cyan, LiquidGlassStyle.violet]
        } else if SignalStyle.isActive {
            return [SignalStyle.accent, SignalStyle.mint]
        } else if CapsuleStyle.isActive {
            return CapsuleStyle.accentGradient
        }
        return [Color.monoAccent.opacity(0.62), Color.monoAccent.opacity(0.92)]
    }
}
