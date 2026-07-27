import Foundation
import Combine

/// Coordinates stable song content with the platform-owned recommendation
/// APIs. Every load is tied to a platform identity so stale responses cannot
/// overwrite a newly opened song.
@MainActor
final class SongDetailViewModel: ObservableObject {
    @Published private(set) var contentDetail: SongContentDetailResponse?
    @Published private(set) var contentConfiguration: SongContentFeatureConfiguration = .bundledDefault
    @Published private(set) var relatedSongs: [Song] = []
    @Published private(set) var simiSongs: [Song] = []
    @Published private(set) var wikiBlocks: [SongWikiBlock] = []
    @Published private(set) var isContentLoading = false
    @Published private(set) var isRelatedLoading = false
    @Published private(set) var isShowingCachedContent = false

    private var contentTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private var requestedIdentity: SongContentRequestIdentity?

    var publishedContent: SongContentBody? {
        guard let content = contentDetail?.content, content.hasPublishedCopy else { return nil }
        return content
    }

    var isContentGenerating: Bool {
        guard let detail = contentDetail else { return false }
        return detail.generation?.isActive == true || detail.content?.status == "generating"
    }

    func load(song: Song) {
        cancelLoading()

        let identity = song.contentRequestIdentity
        requestedIdentity = identity
        contentDetail = nil
        relatedSongs = []
        simiSongs = []
        wikiBlocks = []
        isShowingCachedContent = false

        loadPublishedContent(song: song, identity: identity)

        guard song.musicSource == .netease else { return }

        if let artistID = song.artists.first?.id {
            loadRelatedSongs(artistID: artistID, excludingSongID: song.id)
        }
        loadSongWiki(songID: song.id)
        loadSimiSongs(songID: song.id)
    }

    func cancelLoading() {
        contentTask?.cancel()
        contentTask = nil
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
        isContentLoading = false
        isRelatedLoading = false
    }

    private func loadPublishedContent(song: Song, identity: SongContentRequestIdentity) {
        isContentLoading = true
        contentTask = Task { [weak self] in
            if let cached = await SongContentDetailCache.shared.response(for: identity),
               !Task.isCancelled,
               self?.requestedIdentity == identity {
                self?.contentDetail = cached
                self?.isShowingCachedContent = true
            }
            let configuration = await SongContentConfigurationStore.shared.configuration()
            guard !Task.isCancelled, self?.requestedIdentity == identity else { return }
            self?.contentConfiguration = configuration
            guard configuration.enabled else {
                self?.isContentLoading = false
                return
            }

            var pollCount = 0
            var consecutiveFailures = 0
            while !Task.isCancelled, self?.requestedIdentity == identity {
                do {
                    let detail = pollCount == 0
                        ? try await APIService.shared.ensureSongContent(song: song)
                        : try await APIService.shared.fetchSongContent(identity: identity)
                    guard !Task.isCancelled, self?.requestedIdentity == identity else { return }
                    consecutiveFailures = 0
                    self?.contentDetail = detail
                    self?.isShowingCachedContent = false
                    self?.isContentLoading = false

                    let hasPublishedContent = detail.content?.hasPublishedCopy == true
                    let isGeneratingUpgrade = detail.generation?.isActive == true

                    if hasPublishedContent && !isGeneratingUpgrade {
                        await SongContentDetailCache.shared.storePublished(detail, for: identity)
                    } else if !hasPublishedContent && detail.generation == nil {
                        await SongContentDetailCache.shared.remove(for: identity)
                    }

                    guard isGeneratingUpgrade else { return }

                    pollCount += 1
                    let retrySeconds = min(
                        15,
                        max(2, detail.generation?.retryAfterSeconds ?? configuration.pollingIntervalSeconds)
                    )
                    try await Task.sleep(for: .seconds(retrySeconds))
                } catch is CancellationError {
                    return
                } catch {
                    // The content service is additive during rollout. Platform
                    // metadata and playback remain available when it is offline.
                    AppLogger.debug("Song content unavailable for \(identity.cacheKey): \(error)")
                    guard self?.requestedIdentity == identity else { return }
                    consecutiveFailures += 1
                    guard consecutiveFailures <= 4 else {
                        self?.isContentLoading = false
                        return
                    }
                    let retrySeconds = min(8, 1 << consecutiveFailures)
                    do {
                        try await Task.sleep(for: .seconds(retrySeconds))
                    } catch {
                        return
                    }
                }
            }
        }
    }

    private func loadRelatedSongs(artistID: Int, excludingSongID: Int) {
        isRelatedLoading = true
        APIService.shared.fetchArtistTopSongs(id: artistID)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    AppLogger.error("Error loading related songs: \(error)")
                }
                self?.isRelatedLoading = false
            }, receiveValue: { [weak self] songs in
                self?.relatedSongs = songs.filter { $0.id != excludingSongID }
            })
            .store(in: &cancellables)
    }

    private func loadSimiSongs(songID: Int) {
        APIService.shared.fetchSimiSongs(id: songID)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] songs in
                self?.simiSongs = songs.filter { $0.id != songID }
            })
            .store(in: &cancellables)
    }

    private func loadSongWiki(songID: Int) {
        APIService.shared.fetchSongWiki(id: songID)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] blocks in
                self?.wikiBlocks = blocks
            })
            .store(in: &cancellables)
    }
}
