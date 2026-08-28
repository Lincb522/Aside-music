import Combine
import QQMusicKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - 音源切换器

struct MusicSourcePicker: View {
    @Binding var source: LibraryViewModel.MusicSource
    var sources: [LibraryViewModel.MusicSource] = LibraryViewModel.MusicSource.allCases
    var usesPlatformTint = true
    @Namespace private var ns
    typealias Theme = PlaylistDetailView.Theme

    var body: some View {
        HStack(spacing: 4) {
            ForEach(sources, id: \.self) { s in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        source = s
                    }
                } label: {
                    let tint: Color = {
                        switch s {
                        case .ncm: return MusicSource.netease.themedBadgeColor
                        case .qq: return MusicSource.qqmusic.themedBadgeColor
                        case .kugou: return MusicSource.kugou.themedBadgeColor
                        case .appleMusic: return MusicSource.appleMusic.themedBadgeColor
                        }
                    }()
                    let selected = source == s

                    Text(s.shortName)
                        .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(12, weight: selected ? .semibold : .medium) : .system(size: 13, weight: selected ? .bold : .medium, design: .rounded))
                        .foregroundColor(sourceForeground(selected: selected, tint: tint))
                        .padding(.horizontal, NeumorphicStyle.isActive ? 13 : 14)
                        .padding(.vertical, NeumorphicStyle.isActive ? 8 : 7)
                        .background {
                            if NeumorphicStyle.isActive {
                                NeumorphicSurfaceBackground(
                                    cornerRadius: 14,
                                    elevated: selected,
                                    pressed: !selected,
                                    tint: sourceBackgroundTint(selected: selected, tint: tint),
                                    lightweight: true
                                )
                            } else if selected {
                                Capsule()
                                    .fill(sourceSelectedFill(tint: tint))
                                    .matchedGeometryEffect(id: "sourcePill", in: ns)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(NeumorphicStyle.isActive ? 5 : 3)
        .background {
            if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(cornerRadius: 18, elevated: true)
            } else {
                Capsule().fill(Color.monoTextPrimary.opacity(0.06))
            }
        }
    }

    private func sourceForeground(selected: Bool, tint: Color) -> Color {
        if usesPlatformTint {
            return selected ? tint : tint.opacity(0.66)
        }
        if NeumorphicStyle.isActive {
            return selected ? NeumorphicStyle.ink : NeumorphicStyle.inkSoft
        }
        return selected ? .monoIconForeground : .monoTextPrimary
    }

    private func sourceSelectedFill(tint: Color) -> Color {
        usesPlatformTint ? tint.opacity(0.13) : .monoIconBackground
    }

    private func sourceBackgroundTint(selected: Bool, tint: Color) -> Color {
        guard selected else { return NeumorphicStyle.surface }
        return usesPlatformTint ? tint.opacity(0.16) : NeumorphicStyle.accent.opacity(0.14)
    }
}
