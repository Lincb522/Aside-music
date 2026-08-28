import Combine
import QQMusicKit
import SwiftUI
import UniformTypeIdentifiers

struct NeumorphicLibraryEmptyState: View {
    let icon: MonoIcon.IconType
    let title: String
    var detail: String = ""
    var tint: Color = NeumorphicStyle.accent

    var body: some View {
        VStack(spacing: 12) {
            NeumorphicIconBadge(icon: icon, tint: tint, size: 56)

            Text(title)
                .font(NeumorphicStyle.bodyFont(15, weight: .semibold))
                .foregroundStyle(NeumorphicStyle.ink)
                .multilineTextAlignment(.center)

            if !detail.isEmpty {
                Text(detail)
                    .font(NeumorphicStyle.labelFont(12))
                    .foregroundStyle(NeumorphicStyle.inkMuted)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .padding(.horizontal, 18)
        .background(NeumorphicSurfaceBackground(cornerRadius: 24, elevated: true))
    }
}

struct LocalPlaylistRow: View {
    let summary: LocalPlaylistSummary
    typealias Theme = PlaylistDetailView.Theme

    var body: some View {
        HStack(spacing: 14) {
            Group {
                if let url = summary.displayCoverUrl {
                    CachedAsyncImage(url: url.sized(200)) {
                        systemPlaceholder
                    }
                    .aspectRatio(contentMode: .fill)
                } else {
                    systemPlaceholder
                }
            }
            .frame(width: PetWhiteStyle.isActive ? 64 : DeviceLayout.listRowCoverStandard, height: PetWhiteStyle.isActive ? 64 : DeviceLayout.listRowCoverStandard)
            .cornerRadius(PetWhiteStyle.isActive ? 18 : (CapsuleStyle.isActive ? 16 : (SequoiaStyle.isActive ? 14 : 12)))
            .overlay {
                if PetWhiteStyle.isActive {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(PetWhiteStyle.stroke, lineWidth: 1)
                } else if SequoiaStyle.isActive {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(SequoiaStyle.separator.opacity(0.78), lineWidth: 0.6)
                } else if CapsuleStyle.isActive {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(CapsuleStyle.hairline.opacity(0.7), lineWidth: 0.8)
                }
            }
            .shadow(color: CapsuleStyle.isActive ? Color.clear : (SequoiaStyle.isActive ? Color.black.opacity(0.04) : Color.black.opacity(0.08)), radius: CapsuleStyle.isActive ? 0 : (SequoiaStyle.isActive ? 3 : 4), x: 0, y: 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(summary.name)
                    .font(localRowTitleFont)
                    .foregroundColor(localRowPrimaryColor)
                    .lineLimit(1)

                Text(String(format: String(localized: "songs_count_format"), summary.trackCount))
                    .font(localRowSubtitleFont)
                    .foregroundColor(localRowSecondaryColor)
            }

            Spacer()

            if PetWhiteStyle.isActive {
                PetWhitePackIcon(icon: .chevronRight, size: 16, visualScale: 1.05, fallbackColor: PetWhiteStyle.inkMuted)
            } else {
                MonoIcon(icon: .chevronRight, size: 12, color: localRowSecondaryColor.opacity(0.7))
            }
        }
        .padding(PetWhiteStyle.isActive ? 12 : 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if PetWhiteStyle.isActive {
                PetWhiteSurfaceBackground(cornerRadius: 22, elevated: false, tint: PetWhiteStyle.surfaceRaised, accent: PetWhiteStyle.mint)
            } else if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(cornerRadius: 20, elevated: true, lightweight: true)
            } else if CapsuleStyle.isActive {
                CapsuleFlatRowBackground(cornerRadius: 18)
            } else if SequoiaStyle.isActive {
                SequoiaSurfaceBackground(cornerRadius: 20, elevated: false, role: .list)
            } else {
                Color.clear
                    .monoGlass(cornerRadius: MangaStyle.isActive ? MangaStyle.cardRadius : (MujiStyle.isActive ? 10 : 18))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: PetWhiteStyle.isActive ? 22 : (NeumorphicStyle.isActive ? 20 : (MangaStyle.isActive ? MangaStyle.cardRadius : (MujiStyle.isActive ? 10 : (CapsuleStyle.isActive ? 18 : (SequoiaStyle.isActive ? 20 : 18))))), style: .continuous))
        .contentShape(Rectangle())
    }

    private var systemPlaceholder: some View {
        LocalPlaylistPlaceholderArtwork()
    }

    private var localRowTitleFont: Font {
        if PetWhiteStyle.isActive {
            return PetWhiteStyle.bodyFont(16, weight: .black)
        }
        if MangaStyle.isActive {
            return MangaStyle.bodyFont(15, weight: .black)
        }
        if MujiStyle.isActive {
            return MujiStyle.bodyFont(15, weight: .regular)
        }
        if NeumorphicStyle.isActive {
            return NeumorphicStyle.bodyFont(15, weight: .semibold)
        }
        if CapsuleStyle.isActive {
            return CapsuleStyle.bodyFont(15, weight: .bold)
        }
        if SequoiaStyle.isActive {
            return SequoiaStyle.bodyFont(15, weight: .semibold)
        }
        return .system(size: 15, weight: .semibold, design: .rounded)
    }

    private var localRowSubtitleFont: Font {
        if PetWhiteStyle.isActive {
            return PetWhiteStyle.labelFont(12, weight: .semibold)
        }
        if MangaStyle.isActive {
            return MangaStyle.bodyFont(12, weight: .bold)
        }
        if MujiStyle.isActive {
            return MujiStyle.labelFont(12, weight: .regular)
        }
        if NeumorphicStyle.isActive {
            return NeumorphicStyle.labelFont(12, weight: .medium)
        }
        if CapsuleStyle.isActive {
            return CapsuleStyle.labelFont(12, weight: .semibold)
        }
        if SequoiaStyle.isActive {
            return SequoiaStyle.labelFont(12, weight: .regular)
        }
        return .system(size: 12, weight: .medium, design: .rounded)
    }

    private var localRowPrimaryColor: Color {
        if PetWhiteStyle.isActive { return PetWhiteStyle.ink }
        if SequoiaStyle.isActive { return SequoiaStyle.ink }
        if CapsuleStyle.isActive { return CapsuleStyle.ink }
        return NeumorphicStyle.isActive ? NeumorphicStyle.ink : Theme.text
    }

    private var localRowSecondaryColor: Color {
        if PetWhiteStyle.isActive { return PetWhiteStyle.inkSoft }
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        if CapsuleStyle.isActive { return CapsuleStyle.inkSoft }
        return NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : Theme.secondaryText
    }
}
