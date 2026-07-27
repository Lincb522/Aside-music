import SwiftUI

// MARK: - aside 详情页共用 Hero 头部

/// 歌单 / 专辑 / 本地歌单等详情页的沉浸式头部，对齐歌手页设计语言：
/// 全宽封面随下拉弹性拉伸、随上滑视差收起，底部透明渐隐进页面背景，
/// 信息区大标题 + 元信息 + 播放全部胶囊。
/// 仅供 default(aside) 及无独立分支的主题使用；其余主题走各自 header。
struct AsideDetailHeroHeader<Accessory: View>: View {
    let coverUrl: URL?
    var placeholderImageName: String? = nil
    let title: String
    /// 标题下方主副标（如歌手名），可点跳转
    var subtitle: String? = nil
    var onSubtitleTap: (() -> Void)? = nil
    var metaItems: [String] = []
    var descriptionText: String? = nil
    var onDescriptionTap: (() -> Void)? = nil
    /// 由页面的 `.monoScrollOffset($scrollOffset)` 提供
    let scrollOffset: CGFloat
    var heroHeight: CGFloat = 320
    var playAllTitle = String(localized: "play_now")
    var playAllDisabled = false
    let onPlayAll: () -> Void
    @ViewBuilder var accessory: () -> Accessory

    var body: some View {
        VStack(spacing: 0) {
            heroSection
            infoSection
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.top, ThemedPageStyle.isActive ? 12 : -36)
        }
    }

    // MARK: - 封面 Hero（弹性拉伸 + 底部渐隐）

    private var heroSection: some View {
        let stretchHeight = max(heroHeight - scrollOffset, 0)

        return ZStack(alignment: .bottom) {
            CachedAsyncImage(url: coverUrl) {
                heroArtworkPlaceholder
            }
            .aspectRatio(contentMode: .fill)
            .frame(height: stretchHeight)
            .frame(maxWidth: .infinity)
            .clipped()
            .monoBackgroundExtension()
        }
        .frame(height: stretchHeight)
        // 透明渐隐：不压死页面背景（封面色彩背景/主题背景都能接住）
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: 0.58),
                    .init(color: .black.opacity(0.4), location: 0.85),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .padding(.bottom, scrollOffset)
        .offset(y: scrollOffset)
    }

    @ViewBuilder
    private var heroArtworkPlaceholder: some View {
        if let placeholderImageName {
            Image(placeholderImageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            Rectangle().fill(Color.monoGlassTint)
        }
    }

    // MARK: - 信息区（大标题 + 元信息 + 操作行）

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.monoTextPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if let subtitle, !subtitle.isEmpty {
                if let onSubtitleTap {
                    Button(action: onSubtitleTap) {
                        HStack(spacing: 4) {
                            Text(subtitle)
                                .font(.rounded(size: 14, weight: .semibold))
                                .foregroundColor(.monoTextPrimary.opacity(0.82))
                                .lineLimit(1)
                            MonoIcon(icon: .chevronRight, size: 9, color: .monoTextSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(subtitle)
                        .font(.rounded(size: 14, weight: .semibold))
                        .foregroundColor(.monoTextPrimary.opacity(0.82))
                        .lineLimit(1)
                }
            }

            if !metaItems.isEmpty {
                HStack(spacing: 16) {
                    ForEach(metaItems, id: \.self) { item in
                        Text(item)
                            .font(.rounded(size: 13))
                            .foregroundColor(.monoTextSecondary)
                            .lineLimit(1)
                    }
                }
            }

            if let descriptionText,
               !descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if let onDescriptionTap {
                    Button(action: onDescriptionTap) {
                        descriptionLine(descriptionText, showsChevron: true)
                    }
                    .buttonStyle(.plain)
                } else {
                    descriptionLine(descriptionText, showsChevron: false)
                }
            }

            HStack(spacing: 12) {
                Button(action: onPlayAll) {
                    HStack(spacing: 8) {
                        MonoIcon(icon: .play, size: 14, color: .monoIconForeground)
                        Text(playAllTitle)
                            .font(.rounded(size: 14, weight: .bold))
                            .foregroundColor(.monoIconForeground)
                    }
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.monoIconBackground))
                }
                .buttonStyle(MonoBouncingButtonStyle(scale: 0.95))
                .opacity(playAllDisabled ? 0.5 : 1)
                .disabled(playAllDisabled)

                accessory()

                Spacer()
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func descriptionLine(_ text: String, showsChevron: Bool) -> some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.rounded(size: 13))
                .foregroundColor(.monoTextSecondary)
                .lineLimit(1)
            if showsChevron {
                MonoIcon(icon: .chevronRight, size: 10, color: .monoTextSecondary)
            }
        }
    }
}

extension AsideDetailHeroHeader where Accessory == EmptyView {
    init(
        coverUrl: URL?,
        placeholderImageName: String? = nil,
        title: String,
        subtitle: String? = nil,
        onSubtitleTap: (() -> Void)? = nil,
        metaItems: [String] = [],
        descriptionText: String? = nil,
        onDescriptionTap: (() -> Void)? = nil,
        scrollOffset: CGFloat,
        heroHeight: CGFloat = 320,
        playAllTitle: String = String(localized: "play_now"),
        playAllDisabled: Bool = false,
        onPlayAll: @escaping () -> Void
    ) {
        self.init(
            coverUrl: coverUrl,
            placeholderImageName: placeholderImageName,
            title: title,
            subtitle: subtitle,
            onSubtitleTap: onSubtitleTap,
            metaItems: metaItems,
            descriptionText: descriptionText,
            onDescriptionTap: onDescriptionTap,
            scrollOffset: scrollOffset,
            heroHeight: heroHeight,
            playAllTitle: playAllTitle,
            playAllDisabled: playAllDisabled,
            onPlayAll: onPlayAll,
            accessory: { EmptyView() }
        )
    }
}
