import Combine
import QQMusicKit
import SwiftUI

struct SequoiaProfileRecentCard: View {
    let song: Song
    let isPlaying: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                CachedAsyncImage(url: song.coverUrl, width: 112, height: 112) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(SequoiaStyle.materialList)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 112, height: 112)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(SequoiaStyle.luminousSeparator.opacity(0.52), lineWidth: 0.65)
                )

                if isPlaying {
                    SequoiaPill(text: "ON", tint: SequoiaStyle.accent, selected: true, compact: true)
                        .padding(7)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(song.name)
                    .font(SequoiaStyle.labelFont(13, weight: .semibold))
                    .foregroundStyle(SequoiaStyle.ink)
                    .lineLimit(1)

                Text(song.artistName)
                    .font(SequoiaStyle.labelFont(11, weight: .regular))
                    .foregroundStyle(SequoiaStyle.inkSoft)
                    .lineLimit(1)
            }
            .frame(width: 112, alignment: .leading)
        }
        .padding(8)
        .background(SequoiaSurfaceBackground(cornerRadius: 22, elevated: false, role: .list))
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct SignalProfileRecentCard: View {
    let song: Song
    let isPlaying: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                CachedAsyncImage(url: song.coverUrl, width: 112, height: 112) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(SignalStyle.controlPressed)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 112, height: 112)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(SignalStyle.separator.opacity(0.68), lineWidth: 0.8)
                )

                if isPlaying {
                    SignalPill(text: "ON", tint: SignalStyle.olive, selected: true, compact: true)
                        .padding(7)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(song.name)
                    .font(SignalStyle.labelFont(13, weight: .bold))
                    .foregroundStyle(SignalStyle.ink)
                    .lineLimit(1)

                Text(song.artistName)
                    .font(SignalStyle.labelFont(11, weight: .medium))
                    .foregroundStyle(SignalStyle.inkSoft)
                    .lineLimit(1)
            }
            .frame(width: 112, alignment: .leading)
        }
        .padding(8)
        .background(SignalSurfaceBackground(cornerRadius: 22, elevated: true, fill: SignalStyle.paper))
    }
}
