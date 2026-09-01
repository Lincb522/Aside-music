import SwiftUI

// Capsule 主题下详情页（歌单/专辑/歌手等）的通用组件集。

/// 详情页头部：大封面 + 标题/副标题/描述 + 可选操作区。
struct CapsuleDetailHeader<Actions: View>: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let coverURL: URL?
    let fallbackImageName: String?
    let fallbackIcon: MonoIcon.IconType
    let tint: Color
    let chips: [String]
    let actions: Actions

    init(
        eyebrow: String,
        title: String,
        subtitle: String = "",
        coverURL: URL?,
        fallbackImageName: String? = nil,
        fallbackIcon: MonoIcon.IconType,
        tint: Color = CapsuleStyle.accent,
        chips: [String] = [],
        @ViewBuilder actions: () -> Actions
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.coverURL = coverURL
        self.fallbackImageName = fallbackImageName
        self.fallbackIcon = fallbackIcon
        self.tint = tint
        self.chips = chips
        self.actions = actions()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 14) {
                    artwork
                    identity
                }

                VStack(alignment: .leading, spacing: 14) {
                    artwork
                    identity
                }
            }

            actions
        }
        .padding(15)
        .background(
            CapsuleSurfaceBackground(
                cornerRadius: 32,
                elevated: true,
                tint: CapsuleStyle.surface.opacity(0.92)
            )
        )
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 7) {
                Capsule().fill(tint).frame(width: 42, height: 7)
                Capsule().fill(CapsuleStyle.cyan.opacity(0.78)).frame(width: 18, height: 7)
            }
            .padding(16)
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.top, DeviceLayout.usesExpandedLayout ? 24 : 16)
        .padding(.bottom, 12)
        .iPadContentWidth(900)
    }

    private var artwork: some View {
        CachedAsyncImage(url: coverURL, width: artworkSize.width, height: artworkSize.height) {
            if let fallbackImageName {
                Image(fallbackImageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(CapsuleStyle.surfaceTint)
                    .overlay(MonoIcon(icon: fallbackIcon, size: 34, color: tint.opacity(0.74), lineWidth: 1.8))
            }
        }
        .aspectRatio(contentMode: .fill)
        .frame(width: artworkSize.width, height: artworkSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(CapsuleStyle.hairline.opacity(0.76), lineWidth: 0.8)
        )
        .background(
            CapsuleSurfaceBackground(cornerRadius: 30, elevated: true, tint: CapsuleStyle.surfaceRaised.opacity(0.8))
        )
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                CapsuleDetailChip(text: eyebrow, icon: fallbackIcon, tint: tint, selected: true)

                ForEach(Array(chips.prefix(2).enumerated()), id: \.offset) { _, chip in
                    CapsuleDetailChip(text: chip, tint: CapsuleStyle.cyan)
                }
            }

            Text(title)
                .font(CapsuleStyle.titleFont(DeviceLayout.usesExpandedLayout ? 29 : 24, weight: .bold))
                .foregroundStyle(CapsuleStyle.ink)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(CapsuleStyle.bodyFont(12.5, weight: .medium))
                    .foregroundStyle(CapsuleStyle.inkSoft)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var artworkSize: CGSize {
        CGSize(width: DeviceLayout.usesExpandedLayout ? 158 : 124, height: DeviceLayout.usesExpandedLayout ? 158 : 124)
    }
}

extension CapsuleDetailHeader where Actions == EmptyView {
    init(
        eyebrow: String,
        title: String,
        subtitle: String = "",
        coverURL: URL?,
        fallbackImageName: String? = nil,
        fallbackIcon: MonoIcon.IconType,
        tint: Color = CapsuleStyle.accent,
        chips: [String] = []
    ) {
        self.init(
            eyebrow: eyebrow,
            title: title,
            subtitle: subtitle,
            coverURL: coverURL,
            fallbackImageName: fallbackImageName,
            fallbackIcon: fallbackIcon,
            tint: tint,
            chips: chips
        ) {
            EmptyView()
        }
    }
}

struct CapsuleDetailChip: View {
    let text: String
    var icon: MonoIcon.IconType?
    var tint: Color = CapsuleStyle.accent
    var selected = false

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                MonoIcon(
                    icon: icon,
                    size: 12,
                    color: selected ? CapsuleStyle.readableLabel(on: tint) : tint,
                    lineWidth: 1.7
                )
            }

            Text(text)
                .font(CapsuleStyle.labelFont(11, weight: .bold))
                .foregroundStyle(selected ? CapsuleStyle.readableLabel(on: tint) : CapsuleStyle.inkSoft)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(
            Capsule()
                .fill(selected ? tint : CapsuleStyle.surfaceRaised.opacity(0.76))
                .overlay(
                    Capsule()
                        .stroke(selected ? Color.white.opacity(0.34) : CapsuleStyle.separator.opacity(0.45), lineWidth: 0.7)
                )
        )
    }
}

struct CapsuleDetailActionPill: View {
    let title: String
    let icon: MonoIcon.IconType
    var tint: Color = CapsuleStyle.accent
    var filled = true

    var body: some View {
        HStack(spacing: 7) {
            MonoIcon(
                icon: icon,
                size: 13,
                color: filled ? CapsuleStyle.readableLabel(on: tint) : tint,
                lineWidth: 1.8
            )
            Text(title)
                .font(CapsuleStyle.labelFont(12, weight: .bold))
                .foregroundStyle(filled ? CapsuleStyle.readableLabel(on: tint) : CapsuleStyle.ink)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 14)
        .frame(height: 38)
        .background(
            Capsule()
                .fill(filled ? tint : CapsuleStyle.surfaceRaised.opacity(0.84))
                .overlay(
                    Capsule()
                        .stroke(filled ? Color.white.opacity(0.34) : CapsuleStyle.separator.opacity(0.48), lineWidth: 0.8)
                )
        )
    }
}

struct CapsuleDetailIconButton: View {
    let icon: MonoIcon.IconType
    var tint: Color = CapsuleStyle.accent

    var body: some View {
        MonoIcon(icon: icon, size: 14, color: tint, lineWidth: 1.8)
            .frame(width: 38, height: 38)
            .background(
                CapsuleSurfaceBackground(
                    cornerRadius: 17,
                    elevated: true,
                    tint: CapsuleStyle.surfaceRaised.opacity(0.9)
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(tint.opacity(0.16), lineWidth: 0.8)
            )
    }
}

/// 详情页分区容器：标题行 + 内容卡片。
struct CapsuleDetailSection<Content: View>: View {
    let title: String
    var subtitle = ""
    var icon: MonoIcon.IconType = .musicNoteList
    var tint: Color = CapsuleStyle.accent
    var elevated = true
    let content: Content

    init(
        title: String,
        subtitle: String = "",
        icon: MonoIcon.IconType = .musicNoteList,
        tint: Color = CapsuleStyle.accent,
        elevated: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.tint = tint
        self.elevated = elevated
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                CapsuleDetailChip(text: title, icon: icon, tint: tint, selected: true)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(CapsuleStyle.labelFont(12, weight: .semibold))
                        .foregroundStyle(CapsuleStyle.inkMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer(minLength: 8)

                HStack(spacing: 5) {
                    Capsule().fill(tint.opacity(0.84)).frame(width: 24, height: 6)
                    Capsule().fill(CapsuleStyle.cyan.opacity(0.68)).frame(width: 10, height: 6)
                }
            }

            content
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            CapsuleSurfaceBackground(
                cornerRadius: 28,
                elevated: elevated,
                tint: CapsuleStyle.surface.opacity(elevated ? 0.9 : 0.76)
            )
        )
        .padding(.horizontal, DeviceLayout.usesExpandedLayout ? 32 : max(DeviceLayout.viewHorizontalPadding - 8, 10))
        .iPadContentWidth(960)
    }
}

struct CapsuleDetailEmptyState: View {
    let title: LocalizedStringKey
    var icon: MonoIcon.IconType = .musicNoteList
    var tint: Color = CapsuleStyle.accent

    var body: some View {
        VStack(spacing: 12) {
            CapsuleIconBadge(icon: icon, tint: tint, size: 54)

            Text(title)
                .font(CapsuleStyle.labelFont(14, weight: .semibold))
                .foregroundStyle(CapsuleStyle.inkSoft)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 38)
        .background(
            CapsuleSurfaceBackground(
                cornerRadius: 26,
                elevated: false,
                tint: CapsuleStyle.surfaceTint.opacity(0.68)
            )
        )
    }
}
