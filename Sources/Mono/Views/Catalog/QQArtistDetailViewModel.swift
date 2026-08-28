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
    private var cancellables = Set<AnyCancellable>()
    
    init(mid: String) {
        self.mid = mid
    }
    
    func loadSongs() {
        currentPage = 1
        APIService.shared.fetchQQSingerSongs(mid: mid, page: 1, num: 30)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let e) = completion { AppLogger.error("[QQArtist] 歌曲加载失败: \(e)") }
            }, receiveValue: { [weak self] songs in
                self?.songs = songs
            })
            .store(in: &cancellables)
    }
    
    func loadMoreSongs() {
        currentPage += 1
        APIService.shared.fetchQQSingerSongs(mid: mid, page: currentPage, num: 30)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] newSongs in
                guard let self else { return }
                let ids = Set(self.songs.map(\.id))
                self.songs.append(contentsOf: newSongs.filter { !ids.contains($0.id) })
            })
            .store(in: &cancellables)
    }
    
    @Published var isLoadingAll = false
    
    func loadAllSongs() {
        guard !isLoadingAll else { return }
        isLoadingAll = true
        Task { @MainActor in
            var page = self.currentPage + 1
            while true {
                let newSongs: [Song]
                do {
                    newSongs = try await withCheckedThrowingContinuation { continuation in
                        var resumed = false
                        var bag: AnyCancellable?
                        bag = APIService.shared.fetchQQSingerSongs(mid: self.mid, page: page, num: 30)
                            .sink(receiveCompletion: { completion in
                                if case .failure(let e) = completion, !resumed { resumed = true; continuation.resume(throwing: e) }
                                bag?.cancel()
                            }, receiveValue: { songs in
                                guard !resumed else { return }
                                resumed = true; continuation.resume(returning: songs); bag?.cancel()
                            })
                    }
                } catch { break }
                if newSongs.isEmpty { break }
                let ids = Set(self.songs.map(\.id))
                let unique = newSongs.filter { !ids.contains($0.id) }
                if unique.isEmpty { break }
                self.songs.append(contentsOf: unique)
                self.currentPage = page
                page += 1
            }
            self.isLoadingAll = false
        }
    }
    
    func loadInfo() {
        APIService.shared.fetchQQSingerInfo(mid: mid)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] json in
                AppLogger.debug("[QQArtist] 歌手详情: \(json)")
                self?.applyResolvedInfo(from: json)
            })
            .store(in: &cancellables)

        // singerInfo 可能不含简介，单独调用 singerDesc 获取
        APIService.shared.fetchQQSingerDesc(mid: mid)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] desc in
                guard let self, !desc.isEmpty else { return }
                if self.resolvedDesc == nil || self.resolvedDesc?.isEmpty == true {
                    self.resolvedDesc = desc
                }
            })
            .store(in: &cancellables)
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
        guard albums.isEmpty else { return }
        isLoadingAlbums = true
        APIService.shared.fetchQQSingerAlbums(mid: mid, num: 30, begin: 0)
            .sink(receiveCompletion: { [weak self] _ in self?.isLoadingAlbums = false },
                  receiveValue: { [weak self] list in self?.albums = list })
            .store(in: &cancellables)
    }
    
    func loadMVs() {
        guard mvs.isEmpty else { return }
        isLoadingMVs = true
        APIService.shared.fetchQQSingerMVs(mid: mid, num: 30, begin: 0)
            .sink(receiveCompletion: { [weak self] _ in self?.isLoadingMVs = false },
                  receiveValue: { [weak self] list in self?.mvs = list })
            .store(in: &cancellables)
    }
}
