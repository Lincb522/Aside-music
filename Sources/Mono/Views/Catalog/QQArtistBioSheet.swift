import SwiftUI
import Combine
import QQMusicKit

// MARK: - QQ 歌手简介 Sheet

struct QQArtistBioSheet: View {
    let name: String
    let coverUrl: URL?
    let desc: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.monoSheetDismiss) private var monoSheetDismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                CachedAsyncImage(url: coverUrl) {
                    Circle().fill(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.controlGlassFill : (NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.monoGlassTint))
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 48, height: 48)
                .clipShape(Circle())
                .overlay {
                    if NeumorphicStyle.isActive {
                        Circle()
                            .stroke(NeumorphicStyle.separator.opacity(0.35), lineWidth: 0.7)
                    } else if MinimalWhiteStyle.isActive {
                        Circle()
                            .stroke(MinimalWhiteStyle.hairline, lineWidth: MinimalWhiteStyle.strokeWidth)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(name)
                        .font(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.titleFont(20, weight: .semibold) : (NeumorphicStyle.isActive ? NeumorphicStyle.titleFont(20, weight: .semibold) : .rounded(size: 20, weight: .bold)))
                        .foregroundColor(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.ink : (NeumorphicStyle.isActive ? NeumorphicStyle.ink : .monoTextPrimary))
                        .lineLimit(1)
                    PlatformBadgeLabel(text: "QCM", source: .qqmusic, fontSize: 10)
                }

                Spacer()

                Button(action: { dismissCurrentPresentation(systemDismiss: dismiss, monoSheetDismiss: monoSheetDismiss) }) {
                    MonoIcon(icon: .close, size: 20, color: MinimalWhiteStyle.isActive ? MinimalWhiteStyle.inkMuted : (NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : .monoTextSecondary))
                        .frame(width: 32, height: 32)
                        .background {
                            if NeumorphicStyle.isActive {
                                NeumorphicSurfaceBackground(cornerRadius: 16, elevated: false, pressed: true, lightweight: true)
                            } else if MinimalWhiteStyle.isActive {
                                MinimalWhiteCircleBackground(elevated: false)
                            } else {
                                Circle().fill(Color.monoSeparator)
                            }
                        }
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.top, 16)
            .padding(.bottom, 16)

            Rectangle()
                .fill(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.hairline : (NeumorphicStyle.isActive ? NeumorphicStyle.separator.opacity(0.45) : Color.monoSeparator))
                .frame(height: 0.5)

            ScrollView {
                Text(desc)
                    .font(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.bodyFont(15, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.bodyFont(15, weight: .regular) : .rounded(size: 15, weight: .regular)))
                    .foregroundColor(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.inkSoft : (NeumorphicStyle.isActive ? NeumorphicStyle.ink : .monoTextPrimary))
                    .lineSpacing(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background {
                        if MinimalWhiteStyle.isActive {
                            MinimalWhiteSurfaceBackground(
                                cornerRadius: MinimalWhiteStyle.cardRadius,
                                elevated: false,
                                tint: MinimalWhiteStyle.glassFill
                            )
                        }
                    }
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding - 16)
                    .padding(.top, 4)
                    .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
    }
}
