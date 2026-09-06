import SwiftUI
import Combine
import QQMusicKit

// MARK: - QQ 歌手详情 ViewModel

@MainActor
class QQArtistDetailViewModel: ObservableObject {
    @Published var songs: [Song] = []
    @Published var albums: [AlbumInfo] = []
    @Published var mvs: [QQMV] = []
    @Published var isLoading = true
    @Published var isLoadingAlbums = false
    @Published var isLoadingMVs = false
    @Published var resolvedName: String?
    @Published var resolvedCoverUrl: String?
    @Published var resolvedDesc: String?
    @Published var songCount: Int?
    @Published var albumCount: Int?
    @Published var fansCount: Int?
    
    let mid: String
    private var currentPage = 1
    private let songsRequest = LibraryRequestScope()
    private let pageRequest = LibraryRequestScope()
    private let infoRequest = LibraryRequestScope()
    private let descriptionRequest = LibraryRequestScope()
    private let albumsRequest = LibraryRequestScope()
    private let videosRequest = LibraryRequestScope()
    private var allSongsTask: Task<Void, Never>?
    private var loadAllAfterFirstPage = false
    private var hasMoreSongs = true
    private var songsRevision = 0
    
    init(mid: String) {
        self.mid = mid
    }
    
    func loadSongs() {
        guard songs.isEmpty, !songsRequest.isRunning else { return }
        songsRevision += 1
        pageRequest.cancel()
        allSongsTask?.cancel()
        allSongsTask = nil
        isLoadingAll = false
        isLoading = true
        currentPage = 1
        hasMoreSongs = true
        let request = songsRequest.begin()
        songsRequest.cancellable = APIService.shared.fetchQQSingerSongs(mid: mid, page: 1, num: 30)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self, self.songsRequest.isCurrent(request) else { return }
                self.songsRequest.finish(request)
                self.isLoading = false
                if case .failure(let error) = completion {
                    AppLogger.error("[QQArtist] 歌曲加载失败: \(error)")
                }
                if self.loadAllAfterFirstPage {
                    self.loadAllAfterFirstPage = false
                    self.loadAllSongs()
                }
            }, receiveValue: { [weak self] songs in
                guard let self, self.songsRequest.isCurrent(request) else { return }
                self.songs = songs
                self.hasMoreSongs = !songs.isEmpty
            })
    }
    
    func loadMoreSongs() {
        guard !isLoading, !isLoadingAll, !pageRequest.isRunning, hasMoreSongs else { return }
        let page = currentPage + 1
        let request = pageRequest.begin()
        pageRequest.cancellable = APIService.shared.fetchQQSingerSongs(mid: mid, page: page, num: 30)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] _ in
                self?.pageRequest.finish(request)
            }, receiveValue: { [weak self] newSongs in
                guard let self, self.pageRequest.isCurrent(request) else { return }
                let ids = Set(self.songs.map(\.id))
                let unique = newSongs.filter { !ids.contains($0.id) }
                self.songs.append(contentsOf: unique)
                self.currentPage = page
                self.hasMoreSongs = !unique.isEmpty
            })
    }
    
    @Published var isLoadingAll = false
    
    func loadAllSongs() {
        if isLoading {
            loadAllAfterFirstPage = true
            return
        }
        guard !isLoadingAll, hasMoreSongs, !songs.isEmpty else { return }
        pageRequest.cancel()
        isLoadingAll = true
        let revision = songsRevision
        allSongsTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                if self.songsRevision == revision {
                    self.isLoadingAll = false
                    self.allSongsTask = nil
                }
            }
            while self.hasMoreSongs, !Task.isCancelled, self.songsRevision == revision {
                let page = self.currentPage + 1
                do {
                    let newSongs = try await APIService.shared.fetchQQSingerSongs(mid: self.mid, page: page, num: 30).async()
                    guard !Task.isCancelled, self.songsRevision == revision else { return }
                    let ids = Set(self.songs.map(\.id))
                    let unique = newSongs.filter { !ids.contains($0.id) }
                    self.hasMoreSongs = !unique.isEmpty
                    self.songs.append(contentsOf: unique)
                    self.currentPage = page
                } catch {
                    break
                }
            }
        }
    }
    
    func loadInfo() {
        guard !infoRequest.isRunning, !descriptionRequest.isRunning else { return }
        let infoID = infoRequest.begin()
        infoRequest.cancellable = APIService.shared.fetchQQSingerInfo(mid: mid)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] _ in self?.infoRequest.finish(infoID) }, receiveValue: { [weak self] json in
                guard let self, self.infoRequest.isCurrent(infoID) else { return }
                AppLogger.debug("[QQArtist] 歌手详情: \(json)")
                self.applyResolvedInfo(from: json)
            })

        // singerInfo 可能不含简介，单独调用 singerDesc 获取
        let descriptionID = descriptionRequest.begin()
        descriptionRequest.cancellable = APIService.shared.fetchQQSingerDesc(mid: mid)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] _ in self?.descriptionRequest.finish(descriptionID) }, receiveValue: { [weak self] desc in
                guard let self, self.descriptionRequest.isCurrent(descriptionID), !desc.isEmpty else { return }
                if self.resolvedDesc == nil || self.resolvedDesc?.isEmpty == true {
                    self.resolvedDesc = desc
                }
            })
    }

    private func applyResolvedInfo(from json: JSON) {
        let info = artistInfoContainer(from: json)
        let baseInfo = info["BaseInfo"] ?? info["baseInfo"] ?? info["base_info"]
        let singerInfo = info["Singer"] ?? info["singer"]

        if let name = firstNonEmptyString([
            baseInfo?["Name"]?.stringValue,
            baseInfo?["name"]?.stringValue,
            singerInfo?["Name"]?.stringValue,
            singerInfo?["name"]?.stringValue,
            json["name"]?.stringValue,
            json["singerName"]?.stringValue
        ]) {
            resolvedName = name
        }

        if let coverURL = firstNonEmptyString([
            baseInfo?["BackgroundImage"]?.stringValue,
            baseInfo?["background_image"]?.stringValue,
            baseInfo?["Avatar"]?.stringValue,
            baseInfo?["avatar"]?.stringValue,
            baseInfo?["BigAvatar"]?.stringValue,
            singerInfo?["SingerPic"]?.stringValue,
            singerInfo?["singer_pic"]?.stringValue,
            json["pic"]?.stringValue,
            json["singerPic"]?.stringValue,
            json["singer_pic"]?.stringValue,
            json["headpic"]?.stringValue
        ]) {
            resolvedCoverUrl = coverURL.replacingOccurrences(of: "http://", with: "https://")
        }

        if let desc = firstNonEmptyString([
            json["desc"]?.stringValue,
            json["brief"]?.stringValue,
            json["SingerDesc"]?.stringValue
        ]) {
            resolvedDesc = desc
        }

        if let fans = firstNonNilInt([
            info["FansNum"]?["Num"]?.intValue,
            json["fans"]?.intValue,
            json["fansNum"]?.intValue,
            json["fans_num"]?.intValue
        ]) {
            fansCount = fans
        }

        if let songCountValue = firstNonNilInt([
            info["songNum"]?.intValue,
            info["SongNum"]?.intValue,
            singerInfo?["songNum"]?.intValue,
            singerInfo?["SongNum"]?.intValue,
            json["songNum"]?.intValue,
            json["song_num"]?.intValue,
            json["total"]?.intValue
        ]) {
            songCount = songCountValue
        }

        if let albumCountValue = firstNonNilInt([
            info["albumNum"]?.intValue,
            info["AlbumNum"]?.intValue,
            singerInfo?["albumNum"]?.intValue,
            singerInfo?["AlbumNum"]?.intValue,
            json["albumNum"]?.intValue,
            json["album_num"]?.intValue
        ]) {
            albumCount = albumCountValue
        }
    }

    private func artistInfoContainer(from json: JSON) -> JSON {
        if let info = json["Info"] {
            return info
        }
        if let info = json["info"] {
            return info
        }
        return json
    }

    private func firstNonEmptyString(_ candidates: [String?]) -> String? {
        for candidate in candidates {
            if let candidate, !candidate.isEmpty {
                return candidate
            }
        }
        return nil
    }

    private func firstNonNilInt(_ candidates: [Int?]) -> Int? {
        for candidate in candidates {
            if let candidate {
                return candidate
            }
        }
        return nil
    }
    
    func loadAlbums() {
        guard albums.isEmpty, !albumsRequest.isRunning else { return }
        isLoadingAlbums = true
        let request = albumsRequest.begin()
        albumsRequest.cancellable = APIService.shared.fetchQQSingerAlbums(mid: mid, num: 30, begin: 0)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] _ in
                guard let self, self.albumsRequest.isCurrent(request) else { return }
                self.albumsRequest.finish(request)
                self.isLoadingAlbums = false },
                  receiveValue: { [weak self] list in
                guard let self, self.albumsRequest.isCurrent(request) else { return }
                self.albums = list })
    }
    
    func loadMVs() {
        guard mvs.isEmpty, !videosRequest.isRunning else { return }
        isLoadingMVs = true
        let request = videosRequest.begin()
        videosRequest.cancellable = APIService.shared.fetchQQSingerMVs(mid: mid, num: 30, begin: 0)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] _ in
                guard let self, self.videosRequest.isCurrent(request) else { return }
                self.videosRequest.finish(request)
                self.isLoadingMVs = false },
                  receiveValue: { [weak self] list in
                guard let self, self.videosRequest.isCurrent(request) else { return }
                self.mvs = list })
    }
    deinit { allSongsTask?.cancel() }
}
