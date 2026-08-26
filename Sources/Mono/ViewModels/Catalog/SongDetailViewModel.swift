import Combine
import Foundation

/// Loads provider-owned song information. The detail page never calls the
/// generated song-story service; every section comes from the selected platform.
@MainActor
final class SongDetailViewModel: ObservableObject {
    @Published private(set) var platformDetail: PlatformSongDetail = .empty
    @Published private(set) var relatedSongs: [Song] = []
    @Published private(set) var simiSongs: [Song] = []
    @Published private(set) var isPlatformDetailLoading = false
    @Published private(set) var isRelatedLoading = false

    private var platformTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private var requestedIdentity: PlatformSongIdentity?
    private var pendingPlatformRequests = 0

    func load(song: Song) {
        cancelLoading()

        let identity = song.platformIdentity
        requestedIdentity = identity
        platformDetail = localFileDetail(for: song)
        relatedSongs = []
        simiSongs = []

        switch song.musicSource {
        case .netease:
            loadNeteaseDetail(song: song, identity: identity)
            loadNeteaseRecommendations(song: song)
        case .qqmusic:
            loadQQDetail(song: song, identity: identity)
            loadQQArtistSongs(song: song)
        case .qishui:
            loadQishuiDetail(song: song, identity: identity)
        case .kugou:
            loadKugouDetail(song: song, identity: identity)
            loadKugouArtistSongs(song: song)
        case .appleMusic:
            loadAppleMusicDetail(song: song, identity: identity)
        case .local:
            break
        }
    }

    func cancelLoading() {
        platformTask?.cancel()
        platformTask = nil
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
        pendingPlatformRequests = 0
        isPlatformDetailLoading = false
        isRelatedLoading = false
    }

    // MARK: - Provider details

    private func loadNeteaseDetail(song: Song, identity: PlatformSongIdentity) {
        beginPlatformRequest()
        APIService.shared.fetchSongWiki(id: song.id)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    AppLogger.debug("[Netease] 音乐百科不可用: \(error)")
                }
                self?.endPlatformRequest()
            }, receiveValue: { [weak self] blocks in
                guard let self, self.requestedIdentity == identity else { return }
                let sections = blocks.enumerated().compactMap { index, block -> PlatformSongSection? in
                    guard let body = block.readableDescription else { return nil }
                    return PlatformSongSection(
                        id: "ncm-wiki-\(index)-\(block.type)",
                        title: block.readableTitle ?? String(localized: "song_wiki_title"),
                        body: body
                    )
                }
                self.merge(
                    PlatformSongDetail(releaseDate: nil, attributes: [], sections: sections),
                    for: identity
                )
            })
            .store(in: &cancellables)

        if let albumID = song.album?.id, albumID > 0 {
            beginPlatformRequest()
            APIService.shared.fetchAlbumDetail(id: albumID)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        AppLogger.debug("[Netease] 专辑简介不可用: \(error)")
                    }
                    self?.endPlatformRequest()
                }, receiveValue: { [weak self] result in
                    guard let self, self.requestedIdentity == identity else { return }
                    let description = result.album?.description?
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    let releaseDate = result.album?.publishTime.map { timestamp in
                        Date(timeIntervalSince1970: TimeInterval(timestamp) / 1_000)
                            .formatted(date: .abbreviated, time: .omitted)
                    }
                    let sections = description.flatMap { value -> [PlatformSongSection]? in
                        guard !value.isEmpty else { return nil }
                        return [
                            PlatformSongSection(
                                id: "ncm-album-introduction",
                                title: String(localized: "song_detail_album_introduction"),
                                body: value
                            )
                        ]
                    } ?? []
                    self.merge(
                        PlatformSongDetail(
                            releaseDate: releaseDate,
                            attributes: [],
                            sections: sections
                        ),
                        for: identity
                    )
                })
                .store(in: &cancellables)
        }

    }

    private func loadQQDetail(song: Song, identity: PlatformSongIdentity) {
        beginPlatformRequest()
        APIService.shared.fetchQQSongPlatformDetail(song: song)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    AppLogger.debug("[QQMusic] 歌曲平台信息不可用: \(error)")
                }
                self?.endPlatformRequest()
            }, receiveValue: { [weak self] detail in
                self?.merge(detail, for: identity)
            })
            .store(in: &cancellables)
    }

    private func loadQishuiDetail(song: Song, identity: PlatformSongIdentity) {
        beginPlatformRequest()
        APIService.shared.fetchQishuiSongPlatformDetail(song: song)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    AppLogger.debug("[Qishui] 歌曲平台信息不可用: \(error)")
                }
                self?.endPlatformRequest()
            }, receiveValue: { [weak self] detail in
                self?.merge(detail, for: identity)
            })
            .store(in: &cancellables)
    }

    private func loadKugouDetail(song: Song, identity: PlatformSongIdentity) {
        beginPlatformRequest()
        APIService.shared.fetchKugouSongPlatformDetail(song: song)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    AppLogger.debug("[Kugou] 歌曲平台信息不可用: \(error)")
                }
                self?.endPlatformRequest()
            }, receiveValue: { [weak self] detail in
                self?.merge(detail, for: identity)
            })
            .store(in: &cancellables)
    }

    private func loadAppleMusicDetail(song: Song, identity: PlatformSongIdentity) {
        beginPlatformRequest()
        platformTask = Task { [weak self] in
            defer { self?.endPlatformRequest() }
            do {
                let detail = try await AppleMusicService.shared.platformSongDetail(for: song)
                guard !Task.isCancelled else { return }
                self?.merge(detail, for: identity)
            } catch is CancellationError {
                return
            } catch {
                AppLogger.debug("[AppleMusic] 歌曲目录信息不可用: \(error)")
            }
        }
    }

    private func localFileDetail(for song: Song) -> PlatformSongDetail {
        guard song.isLocal else { return .empty }
        var attributes: [PlatformSongAttribute] = []

        if let fileURL = song.localFileURL {
            let fileType = fileURL.pathExtension.uppercased()
            if !fileType.isEmpty {
                attributes.append(
                    PlatformSongAttribute(
                        id: "local-format",
                        label: String(localized: "song_detail_file_format"),
                        value: fileType
                    )
                )
            }
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
               let fileSize = resourceValues.fileSize,
               fileSize > 0 {
                attributes.append(
                    PlatformSongAttribute(
                        id: "local-size",
                        label: String(localized: "song_detail_file_size"),
                        value: ByteCountFormatter.string(
                            fromByteCount: Int64(fileSize),
                            countStyle: .file
                        )
                    )
                )
            }
        }

        return PlatformSongDetail(releaseDate: nil, attributes: attributes, sections: [])
    }

    private func merge(_ incoming: PlatformSongDetail, for identity: PlatformSongIdentity) {
        guard requestedIdentity == identity else { return }
        if let releaseDate = incoming.releaseDate, !releaseDate.isEmpty {
            platformDetail.releaseDate = releaseDate
        }
        for attribute in incoming.attributes where !platformDetail.attributes.contains(where: { $0.id == attribute.id }) {
            platformDetail.attributes.append(attribute)
        }
        for section in incoming.sections where !platformDetail.sections.contains(where: { $0.id == section.id }) {
            platformDetail.sections.append(section)
        }
    }

    private func beginPlatformRequest() {
        pendingPlatformRequests += 1
        isPlatformDetailLoading = true
    }

    private func endPlatformRequest() {
        pendingPlatformRequests = max(0, pendingPlatformRequests - 1)
        isPlatformDetailLoading = pendingPlatformRequests > 0
    }

    // MARK: - Provider recommendations

    private func loadNeteaseRecommendations(song: Song) {
        if let artistID = song.artists.first?.id {
            isRelatedLoading = true
            APIService.shared.fetchArtistTopSongs(id: artistID)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        AppLogger.error("Error loading related songs: \(error)")
                    }
                    self?.isRelatedLoading = false
                }, receiveValue: { [weak self] songs in
                    self?.relatedSongs = songs.filter { $0.id != song.id }
                })
                .store(in: &cancellables)
        }

        APIService.shared.fetchSimiSongs(id: song.id)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] songs in
                self?.simiSongs = songs.filter { $0.id != song.id }
            })
            .store(in: &cancellables)
    }

    private func loadQQArtistSongs(song: Song) {
        guard let artistMID = song.qqArtistMid, !artistMID.isEmpty else { return }
        isRelatedLoading = true
        APIService.shared.fetchQQSingerSongs(mid: artistMID, page: 1, num: 30)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    AppLogger.debug("[QQMusic] 歌手歌曲不可用: \(error)")
                }
                self?.isRelatedLoading = false
            }, receiveValue: { [weak self] songs in
                self?.relatedSongs = songs.filter { $0.platformIdentity != song.platformIdentity }
            })
            .store(in: &cancellables)
    }

    private func loadKugouArtistSongs(song: Song) {
        guard let artistID = song.artists.first?.id, artistID > 0 else { return }
        isRelatedLoading = true
        APIService.shared.fetchKugouArtistSongs(id: artistID, page: 1, pageSize: 30)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    AppLogger.debug("[Kugou] 歌手歌曲不可用: \(error)")
                }
                self?.isRelatedLoading = false
            }, receiveValue: { [weak self] songs in
                self?.relatedSongs = songs.filter { $0.platformIdentity != song.platformIdentity }
            })
            .store(in: &cancellables)
    }
}
