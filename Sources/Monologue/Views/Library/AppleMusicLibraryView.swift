import SwiftUI

/// Apple Music 资料库歌曲列表的数据源：分页加载（每页 50 首），
/// 滚动到尾部前 4 首时预取下一页，追加时按播放身份键去重。
@MainActor
final class AppleMusicLibraryViewModel: ObservableObject {
    @Published private(set) var songs: [Song] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var canLoadMore = true
    @Published private(set) var errorMessage: String?

    private let service = AppleMusicService.shared
    private let pageSize = 50
    private var nextOffset = 0

    func loadInitial(force: Bool = false) async {
        guard !isLoading, !isLoadingMore else { return }
        guard force || songs.isEmpty else { return }
        await load(reset: true)
    }

    /// 当前行位于列表尾部 4 首以内时触发加载下一页。
    func loadMoreIfNeeded(current song: Song) async {
        guard canLoadMore,
              !isLoading,
              !isLoadingMore,
              songs.suffix(4).contains(where: {
                  PlayerManager.matchesPlaybackTarget($0, expected: song)
              }) else { return }
        await load(reset: false)
    }

    private func load(reset: Bool) async {
        if reset {
            isLoading = true
            errorMessage = nil
            nextOffset = 0
        } else {
            isLoadingMore = true
        }
        defer {
            isLoading = false
            isLoadingMore = false
        }

        do {
            let offset = reset ? 0 : nextOffset
            let page = try await service.librarySongs(
                offset: offset,
                limit: pageSize
            )
            guard !Task.isCancelled else { return }
            if reset {
                songs = page.songs
            } else {
                let existing = Set(songs.map {
                    PlayerManager.playbackIdentityKey(for: $0)
                })
                songs.append(contentsOf: page.songs.filter {
                    !existing.contains(PlayerManager.playbackIdentityKey(for: $0))
                })
            }
            nextOffset = page.nextOffset
            canLoadMore = page.hasMore
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            canLoadMore = false
            errorMessage = error.localizedDescription
            AppLogger.warning(
                "[AppleMusic] 读取资料库失败: \(error.localizedDescription)",
                step: "apple-music.library"
            )
        }
    }
}

/// Apple Music 资料库页：支持独立滚动或嵌入父滚动容器，
/// 涵盖加载中/错误重试/空态/列表四种展示状态。
struct AppleMusicLibraryView: View {
    @StateObject private var model = AppleMusicLibraryViewModel()

    let embeddedInParentScroll: Bool

    init(embeddedInParentScroll: Bool = false) {
        self.embeddedInParentScroll = embeddedInParentScroll
    }

    var body: some View {
        Group {
            if embeddedInParentScroll {
                content
            } else {
                ScrollView {
                    content
                }
                .scrollIndicators(.hidden)
                .themeRenderScrollLayer()
            }
        }
        .task {
            await model.loadInitial()
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading, model.songs.isEmpty {
            ProgressView()
                .tint(MusicSource.appleMusic.themedBadgeColor)
                .frame(maxWidth: .infinity)
                .padding(.top, 54)
        } else if let errorMessage = model.errorMessage, model.songs.isEmpty {
            statusView(
                icon: .musicNote,
                title: String(localized: "apple_music_library_unavailable"),
                detail: errorMessage,
                actionTitle: String(localized: "action_retry")
            ) {
                Task {
                    await model.loadInitial(force: true)
                }
            }
        } else if model.songs.isEmpty {
            statusView(
                icon: .musicNoteList,
                title: String(localized: "apple_music_library_empty"),
                detail: nil,
                actionTitle: nil,
                action: nil
            )
        } else {
            LazyVStack(spacing: 0) {
                ForEach(Array(model.songs.enumerated()), id: \.element.id) { index, song in
                    SongListRow(
                        song: song,
                        index: index,
                        onTap: {
                            PlayerManager.shared.play(
                                song: song,
                                in: model.songs
                            )
                        }
                    )
                    .task {
                        await model.loadMoreIfNeeded(current: song)
                    }
                }

                if model.isLoadingMore {
                    ProgressView()
                        .tint(MusicSource.appleMusic.themedBadgeColor)
                        .padding(.vertical, 18)
                }
            }
            .padding(.bottom, embeddedInParentScroll ? 0 : 120)
        }
    }

    private func statusView(
        icon: MonologueIcon.IconType,
        title: String,
        detail: String?,
        actionTitle: String?,
        action: (() -> Void)?
    ) -> some View {
        VStack(spacing: 12) {
            MonologueIcon(
                icon: icon,
                size: 34,
                color: MusicSource.appleMusic.themedBadgeColor,
                lineWidth: 1.7
            )

            Text(title)
                .font(.rounded(size: 15, weight: .semibold))
                .foregroundStyle(Color.monologueTextPrimary)

            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.rounded(size: 12, weight: .regular))
                    .foregroundStyle(Color.monologueTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.rounded(size: 12, weight: .semibold))
                        .foregroundStyle(Color.monologueTextPrimary)
                        .padding(.horizontal, 16)
                        .frame(height: 36)
                        .background(
                            Capsule()
                                .fill(MusicSource.appleMusic.themedBadgeColor.opacity(0.16))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 28)
        .padding(.top, 48)
    }
}
