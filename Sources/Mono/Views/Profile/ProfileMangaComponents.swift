import Combine
import QQMusicKit
import SwiftUI

struct MangaProfileInfoPill: View {
    let text: String
    let tint: Color

    var body: some View {
        // 印刷角标:矩形色块 + 墨线 + 可读前景
        Text(text)
            .font(MangaStyle.labelFont(10, weight: .black))
            .foregroundStyle(
                ThemeColorCustomization.readableForegroundColor(on: tint, light: MangaStyle.strokeInk, dark: MangaStyle.onStrokeInk)
            )
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3.5)
            .background(
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .fill(tint)
            )
    }
}

struct MangaProfileActionRow: View {
    let icon: MonoIcon.IconType
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            MonoIcon(
                icon: icon,
                size: 16,
                color: ThemeColorCustomization.readableForegroundColor(on: tint, light: MangaStyle.strokeInk, dark: MangaStyle.onStrokeInk),
                lineWidth: 1.8
            )
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: MangaStyle.buttonRadius, style: .continuous)
                        .fill(tint)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(MangaStyle.comicFont(14, weight: .black))
                    .foregroundStyle(MangaStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text(value)
                    .font(MangaStyle.comicFont(11, weight: .bold))
                    .foregroundStyle(MangaStyle.inkSub)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 8)

            MonoIcon(icon: .chevronRight, size: 13, color: MangaStyle.inkSub, lineWidth: 1.8)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

struct MangaProfileActionDivider: View {
    var body: some View {
        Rectangle()
            .fill(MangaStyle.strokeInk.opacity(0.12))
            .frame(height: 1)
            .padding(.leading, 60)
            .padding(.trailing, 14)
    }
}

struct MangaProfileRecentCard: View {
    let song: Song

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CachedAsyncImage(url: song.coverUrl, width: 112, height: 112) {
                RoundedRectangle(cornerRadius: MangaStyle.cardRadius, style: .continuous)
                    .fill(MangaStyle.bubbleWhite)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 112, height: 112)
            .clipShape(RoundedRectangle(cornerRadius: MangaStyle.cardRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: MangaStyle.cardRadius, style: .continuous).stroke(MangaStyle.strokeInk.opacity(0.7), lineWidth: 1))

            VStack(alignment: .leading, spacing: 3) {
                Text(song.name)
                    .font(MangaStyle.comicFont(13, weight: .black))
                    .foregroundStyle(MangaStyle.ink)
                    .lineLimit(1)

                Text(song.artistName)
                    .font(MangaStyle.comicFont(11, weight: .bold))
                    .foregroundStyle(MangaStyle.inkSub)
                    .lineLimit(1)
            }
            .frame(width: 112, alignment: .leading)
        }
    }
}
