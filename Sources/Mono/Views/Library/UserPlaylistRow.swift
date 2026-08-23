import SwiftUI

/// 音乐库中的用户歌单行：封面 + 名称 + 曲数/创建者；
/// MinimalWhite 主题使用专属排版，PetWhite 主题调整圆角与配色。
struct UserPlaylistRow: View {
    let playlist: Playlist
    
    var body: some View {
        if MinimalWhiteStyle.isActive {
            minimalWhiteRow
        } else {
            HStack(spacing: 16) {
                CachedAsyncImage(url: playlist.coverUrl) {
                    PetWhiteStyle.isActive ? PetWhiteStyle.mint.opacity(0.26) : Color.gray.opacity(0.1)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: PetWhiteStyle.isActive ? 64 : 60, height: PetWhiteStyle.isActive ? 64 : 60)
                .clipShape(RoundedRectangle(cornerRadius: PetWhiteStyle.isActive ? 18 : 12, style: .continuous))
                .overlay {
                    if PetWhiteStyle.isActive {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(PetWhiteStyle.stroke, lineWidth: 1)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(playlist.name)
                        .font(PetWhiteStyle.isActive ? PetWhiteStyle.bodyFont(16, weight: .black) : .rounded(size: 16, weight: .bold))
                        .foregroundColor(PetWhiteStyle.isActive ? PetWhiteStyle.ink : .monoTextPrimary)
                    Text(String(format: NSLocalizedString("songs_count_by", comment: "Songs count and creator"), playlist.trackCount ?? 0, playlist.creator?.nickname ?? "Unknown"))
                        .font(PetWhiteStyle.isActive ? PetWhiteStyle.labelFont(13, weight: .semibold) : .rounded(size: 14, weight: .medium))
                        .foregroundColor(PetWhiteStyle.isActive ? PetWhiteStyle.inkSoft : .monoTextSecondary)
                }
                Spacer()
                if PetWhiteStyle.isActive {
                    PetWhitePackIcon(icon: .chevronRight, size: 17, visualScale: 1.08, fallbackColor: PetWhiteStyle.inkMuted)
                } else {
                    MonoIcon(icon: .back, size: 16, color: .monoTextSecondary)
                        .rotationEffect(.degrees(180))
                }
            }
            .padding(PetWhiteStyle.isActive ? 12 : 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if PetWhiteStyle.isActive {
                    PetWhiteSurfaceBackground(cornerRadius: 22, elevated: false, tint: PetWhiteStyle.surfaceRaised, accent: PetWhiteStyle.mint)
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.monoGlassTint.opacity(0.4))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: PetWhiteStyle.isActive ? 22 : 16, style: .continuous))
            .shadow(color: Color.black.opacity(PetWhiteStyle.isActive ? 0.04 : 0.1), radius: PetWhiteStyle.isActive ? 8 : 12, x: 0, y: PetWhiteStyle.isActive ? 4 : 6)
            .contentShape(Rectangle())
        }
    }

    private var minimalWhiteSubtitle: String {
        let count = playlist.trackCount ?? 0
        if let creator = playlist.creator?.nickname, !creator.isEmpty {
            return String(format: NSLocalizedString("songs_count_by", comment: "Songs count and creator"), count, creator)
        }
        return String(format: NSLocalizedString("songs_count_format", comment: ""), count)
    }

    private var minimalWhiteRow: some View {
        HStack(spacing: 14) {
            CachedAsyncImage(url: playlist.coverUrl) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(MinimalWhiteStyle.controlGlassFill)
                    .overlay(MonoIcon(icon: .musicNoteList, size: 25, color: MinimalWhiteStyle.inkMuted, lineWidth: 1.5))
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 62, height: 62)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(MinimalWhiteStyle.separator, lineWidth: MinimalWhiteStyle.strokeWidth)
            )
            .shadow(color: MinimalWhiteStyle.ink.opacity(0.06), radius: 10, x: 0, y: 5)

            VStack(alignment: .leading, spacing: 6) {
                Text(playlist.name)
                    .font(MinimalWhiteStyle.bodyFont(16, weight: .semibold))
                    .foregroundStyle(MinimalWhiteStyle.ink)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(minimalWhiteSubtitle)
                    .font(MinimalWhiteStyle.labelFont(12, weight: .regular))
                    .foregroundStyle(MinimalWhiteStyle.inkMuted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            MonoIcon(icon: .chevronRight, size: 13, color: MinimalWhiteStyle.inkMuted, lineWidth: 1.6)
                .frame(width: 32, height: 32)
                .background(MinimalWhiteCircleBackground(elevated: false))
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 2)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(MinimalWhiteStyle.hairline)
                .frame(height: MinimalWhiteStyle.strokeWidth)
                .padding(.leading, 76)
        }
        .contentShape(Rectangle())
    }
}
