import SwiftUI

// "添加到歌单"选择器的通用组件集：卡片容器、分区、行、徽章与空态。
// 各组件均根据当前激活的主题（Neumorphic/PetWhite/Sequoia 等）切换字体、颜色与背景。

/// 选择器内的通用卡片容器，提供主题化背景与描边。
struct PlaylistPickerContainerCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if NeumorphicStyle.isActive {
                    NeumorphicSurfaceBackground(cornerRadius: 22, elevated: false)
                } else if PetWhiteStyle.isActive {
                    PetWhiteSurfaceBackground(cornerRadius: 22, elevated: false, tint: PetWhiteStyle.surfaceRaised, accent: PetWhiteStyle.mint)
                } else if SequoiaStyle.isActive {
                    SequoiaSurfaceBackground(cornerRadius: 20, elevated: false, role: .list)
                } else {
                    Color.monoTextPrimary.opacity(0.04)
                }
            }
            .clipShape(.rect(cornerRadius: NeumorphicStyle.isActive ? 22 : (SequoiaStyle.isActive ? 20 : 18), style: .continuous))
            .overlay {
                if !NeumorphicStyle.isActive && !PetWhiteStyle.isActive && !SequoiaStyle.isActive {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.monoTextPrimary.opacity(0.06), lineWidth: 1)
                }
            }
    }
}

/// 带标题/副标题的分区容器。
struct PlaylistPickerSection<Content: View>: View {
    let title: LocalizedStringKey
    let subtitle: String?

    private let content: Content

    init(
        title: LocalizedStringKey,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(sectionTitleFont)
                    .foregroundStyle(sectionTitleColor)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(sectionSubtitleFont)
                        .foregroundStyle(sectionSubtitleColor)
                }
            }
            .padding(.horizontal, 4)

            VStack(spacing: 10) {
                content
            }
        }
    }

    private var sectionTitleFont: Font {
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(13, weight: .semibold) }
        if PetWhiteStyle.isActive { return PetWhiteStyle.labelFont(13, weight: .black) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(13, weight: .semibold) }
        return .system(size: 13, weight: .semibold, design: .rounded)
    }

    private var sectionSubtitleFont: Font {
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(12, weight: .regular) }
        if PetWhiteStyle.isActive { return PetWhiteStyle.labelFont(12, weight: .semibold) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(12, weight: .regular) }
        return .system(size: 12, design: .rounded)
    }

    private var sectionTitleColor: Color {
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        if PetWhiteStyle.isActive { return PetWhiteStyle.inkSoft }
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        return .monoTextSecondary
    }

    private var sectionSubtitleColor: Color {
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkMuted }
        if PetWhiteStyle.isActive { return PetWhiteStyle.inkMuted }
        if SequoiaStyle.isActive { return SequoiaStyle.inkMuted }
        return .monoTextSecondary.opacity(0.75)
    }
}

/// 行尾部的状态胶囊徽章（如"已添加"）。
struct PlaylistPickerStatusBadge: View {
    let text: String
    var tint: Color = .monoTextSecondary

    var body: some View {
        Text(text)
            .font(SequoiaStyle.isActive ? SequoiaStyle.labelFont(11, weight: .semibold) : .system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                if NeumorphicStyle.isActive {
                    NeumorphicSurfaceBackground(cornerRadius: 13, elevated: false, pressed: true, tint: tint.opacity(0.15), lightweight: true)
                } else if SequoiaStyle.isActive {
                    Capsule()
                        .fill(SequoiaStyle.materialList.opacity(0.74))
                        .overlay(Capsule().stroke(tint.opacity(0.18), lineWidth: 0.55))
                } else {
                    tint.opacity(0.12)
                }
            }
            .clipShape(.capsule)
    }
}

/// 带图标的操作卡片（如"新建歌单"），支持加载/禁用/状态徽章。
struct PlaylistPickerActionCard: View {
    let icon: MonoIcon.IconType
    let title: String
    let subtitle: String?
    let tint: Color
    var statusText: String? = nil
    var statusTint: Color = .monoTextSecondary
    var isLoading = false
    var isDisabled = false
    var showsChevron = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            PlaylistPickerContainerCard {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.clear)
                            .frame(width: 46, height: 46)
                            .background {
                                if NeumorphicStyle.isActive {
                                    NeumorphicSurfaceBackground(cornerRadius: 15, elevated: false, pressed: true, tint: tint.opacity(0.16), lightweight: true)
                                } else if PetWhiteStyle.isActive {
                                    PetWhiteSurfaceBackground(cornerRadius: 15, elevated: false, tint: tint.opacity(0.16), accent: tint)
                                } else if SequoiaStyle.isActive {
                                    SequoiaSurfaceBackground(cornerRadius: 15, elevated: false, fill: tint.opacity(0.10), role: .selected)
                                } else {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(tint.opacity(0.12))
                                }
                            }

                        MonoIcon(icon: icon, size: 18, color: tint)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(actionTitleFont)
                            .foregroundStyle(primaryTextColor)
                            .lineLimit(1)

                        if let subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(secondaryTextFont)
                                .foregroundStyle(secondaryTextColor)
                                .lineLimit(2)
                        }
                    }

                    Spacer(minLength: 12)

                    trailingView
                }
            }
            .opacity(isDisabled ? 0.58 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
    }

    @ViewBuilder
    private var trailingView: some View {
        if isLoading {
            ProgressView()
                .controlSize(.small)
                .tint(SequoiaStyle.isActive ? SequoiaStyle.accent : Color.monoTextSecondary)
        } else if let statusText, !statusText.isEmpty {
            PlaylistPickerStatusBadge(text: statusText, tint: statusTint)
        } else if showsChevron {
            MonoIcon(icon: .chevronRight, size: 12, color: (SequoiaStyle.isActive ? SequoiaStyle.inkMuted : .monoTextSecondary).opacity(0.55))
        }
    }

    private var actionTitleFont: Font {
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(15, weight: .semibold) }
        if PetWhiteStyle.isActive { return PetWhiteStyle.bodyFont(15, weight: .black) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(15, weight: .semibold) }
        return .system(size: 15, weight: .semibold, design: .rounded)
    }

    private var secondaryTextFont: Font {
        if PetWhiteStyle.isActive { return PetWhiteStyle.labelFont(12, weight: .semibold) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(12, weight: .regular) }
        return .system(size: 12, design: .rounded)
    }

    private var primaryTextColor: Color {
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        if PetWhiteStyle.isActive { return PetWhiteStyle.ink }
        if SequoiaStyle.isActive { return SequoiaStyle.ink }
        return .monoTextPrimary
    }

    private var secondaryTextColor: Color {
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        if PetWhiteStyle.isActive { return PetWhiteStyle.inkSoft }
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        return .monoTextSecondary
    }
}

/// 单个歌单行：封面 + 标题/副标题 + 状态尾部。
struct PlaylistPickerPlaylistRow: View {
    let title: String
    let subtitle: String
    let coverURL: URL?
    let placeholderIcon: MonoIcon.IconType
    var statusText: String? = nil
    var statusTint: Color = .monoTextSecondary
    var isLoading = false
    var isDisabled = false
    var showsChevron = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            PlaylistPickerContainerCard {
                HStack(spacing: 14) {
                    PlaylistPickerArtwork(coverURL: coverURL, placeholderIcon: placeholderIcon)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(playlistTitleFont)
                            .foregroundStyle(primaryTextColor)
                            .lineLimit(1)

                        Text(subtitle)
                            .font(playlistSubtitleFont)
                            .foregroundStyle(secondaryTextColor)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 12)

                    trailingView
                }
            }
            .opacity(isDisabled ? 0.58 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
    }

    @ViewBuilder
    private var trailingView: some View {
        if isLoading {
            ProgressView()
                .controlSize(.small)
                .tint(SequoiaStyle.isActive ? SequoiaStyle.accent : Color.monoTextSecondary)
        } else if let statusText, !statusText.isEmpty {
            PlaylistPickerStatusBadge(text: statusText, tint: statusTint)
        } else if showsChevron {
            MonoIcon(icon: .chevronRight, size: 12, color: (SequoiaStyle.isActive ? SequoiaStyle.inkMuted : .monoTextSecondary).opacity(0.55))
        }
    }

    private var playlistTitleFont: Font {
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(15, weight: .medium) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(15, weight: .medium) }
        return .system(size: 15, weight: .medium, design: .rounded)
    }

    private var playlistSubtitleFont: Font {
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(12, weight: .regular) }
        return .system(size: 12, design: .rounded)
    }

    private var primaryTextColor: Color {
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        if SequoiaStyle.isActive { return SequoiaStyle.ink }
        return .monoTextPrimary
    }

    private var secondaryTextColor: Color {
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        return .monoTextSecondary
    }
}

/// 无歌单时的空态提示卡片。
struct PlaylistPickerEmptyStateCard: View {
    let icon: MonoIcon.IconType
    let message: String

    var body: some View {
        PlaylistPickerContainerCard {
            HStack(spacing: 12) {
                MonoIcon(icon: icon, size: 18, color: .monoTextSecondary.opacity(0.7))

                Text(message)
                    .font(SequoiaStyle.isActive ? SequoiaStyle.labelFont(13, weight: .regular) : .system(size: 13, design: .rounded))
                    .foregroundStyle(SequoiaStyle.isActive ? SequoiaStyle.inkSoft : Color.monoTextSecondary)
            }
        }
    }
}

/// 50x50 歌单封面，无图时显示主题化占位图标。
private struct PlaylistPickerArtwork: View {
    let coverURL: URL?
    let placeholderIcon: MonoIcon.IconType

    var body: some View {
        Group {
            if let coverURL {
                CachedAsyncImage(url: coverURL.sized(200)) {
                    placeholder
                }
                .aspectRatio(contentMode: .fill)
            } else {
                placeholder
            }
        }
        .frame(width: 50, height: 50)
        .clipShape(.rect(cornerRadius: 12, style: .continuous))
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill((NeumorphicStyle.isActive || SequoiaStyle.isActive) ? Color.clear : Color.monoGlassTint)
                .background {
                    if NeumorphicStyle.isActive {
                        NeumorphicSurfaceBackground(cornerRadius: 12, elevated: false, pressed: true, lightweight: true)
                    } else if SequoiaStyle.isActive {
                        SequoiaSurfaceBackground(cornerRadius: 12, elevated: false, pressed: true, role: .list)
                    }
                }

            MonoIcon(icon: placeholderIcon, size: 18, color: (NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : (SequoiaStyle.isActive ? SequoiaStyle.inkMuted : .monoTextSecondary)).opacity(0.45))
        }
    }
}
