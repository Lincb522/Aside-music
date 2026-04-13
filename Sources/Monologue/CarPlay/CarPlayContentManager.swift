import CarPlay
import Combine
import MediaPlayer
@preconcurrency import QQMusicKit

@MainActor
final class CarPlayContentManager: NSObject {
    
    private let interfaceController: CPInterfaceController
    private var cancellables = Set<AnyCancellable>()
    
    private var recommendTemplate: CPListTemplate?
    private var playlistTemplate: CPListTemplate?
    private var searchTemplate: CPListTemplate?
    
    init(interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        super.init()
    }
    
    // MARK: - Setup / Teardown
    
    func setup() {
        let recommend = makeRecommendTab()
        let playlists = makePlaylistTab()
        let search = makeSearchTab()
        let nowPlayingEntry = makeNowPlayingEntryTab()
        
        self.recommendTemplate = recommend
        self.playlistTemplate = playlists
        self.searchTemplate = search
        
        configureNowPlaying(CPNowPlayingTemplate.shared)
        
        recommend.tabImage = UIImage(systemName: "star.fill")
        playlists.tabImage = UIImage(systemName: "music.note.list")
        search.tabImage = UIImage(systemName: "magnifyingglass")
        nowPlayingEntry.tabImage = UIImage(systemName: "play.circle.fill")
        
        let tabBar = CPTabBarTemplate(templates: [recommend, playlists, search, nowPlayingEntry])
        interfaceController.setRootTemplate(tabBar, animated: true, completion: nil)
        
        loadRecommendData()
        loadPlaylistData()
        loadHotSearch()
    }
    
    func teardown() {
        cancellables.removeAll()
        recommendTemplate = nil
        playlistTemplate = nil
        searchTemplate = nil
    }
    
    // MARK: - Recommend Tab
    
    private func makeRecommendTab() -> CPListTemplate {
        let loading = CPListItem(text: String(localized: "加载中..."), detailText: nil)
        loading.isEnabled = false
        let template = CPListTemplate(
            title: String(localized: "推荐"),
            sections: [CPListSection(items: [loading])]
        )
        return template
    }
    
    private func loadRecommendData() {
        let ncmDailyPub = APIService.shared.fetchDailySongs().catch { _ in Just([Song]()) }
        let ncmPlaylistPub = APIService.shared.fetchRecommendPlaylists().catch { _ in Just([Playlist]()) }
        let qqNewSongPub = APIService.shared.fetchQQRecommendNewSongs().catch { _ in Just([Song]()) }
        let qqPlaylistPub = APIService.shared.fetchQQRecommendPlaylists().catch { _ in Just([Playlist]()) }
        
        Publishers.CombineLatest4(ncmDailyPub, ncmPlaylistPub, qqNewSongPub, qqPlaylistPub)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] ncmSongs, ncmPlaylists, qqSongs, qqPlaylists in
                self?.updateRecommendTemplate(
                    ncmSongs: ncmSongs, ncmPlaylists: ncmPlaylists,
                    qqSongs: qqSongs, qqPlaylists: qqPlaylists
                )
            }
            .store(in: &cancellables)
    }
    
    private func updateRecommendTemplate(ncmSongs: [Song], ncmPlaylists: [Playlist],
                                         qqSongs: [Song], qqPlaylists: [Playlist]) {
        var sections = [CPListSection]()
        
        if !ncmSongs.isEmpty {
            let items = ncmSongs.prefix(20).map { makeSongItem($0, context: Array(ncmSongs)) }
            sections.append(CPListSection(items: items, header: String(localized: "每日推荐"), sectionIndexTitle: nil))
        }
        
        if !ncmPlaylists.isEmpty {
            let items = ncmPlaylists.prefix(10).map { makePlaylistItem($0) }
            sections.append(CPListSection(items: items, header: String(localized: "推荐歌单"), sectionIndexTitle: nil))
        }
        
        if !qqSongs.isEmpty {
            let items = qqSongs.prefix(20).map { makeSongItem($0, context: Array(qqSongs)) }
            sections.append(CPListSection(items: items, header: String(localized: "QCM·新歌"), sectionIndexTitle: nil))
        }
        
        if !qqPlaylists.isEmpty {
            let items = qqPlaylists.prefix(10).map { makePlaylistItem($0) }
            sections.append(CPListSection(items: items, header: String(localized: "QCM·推荐歌单"), sectionIndexTitle: nil))
        }
        
        if sections.isEmpty {
            let empty = CPListItem(text: String(localized: "暂无推荐"), detailText: String(localized: "请先登录账号"))
            empty.isEnabled = false
            sections.append(CPListSection(items: [empty]))
        }
        
        recommendTemplate?.updateSections(sections)
    }
    
    // MARK: - Playlist Tab
    
    private func makePlaylistTab() -> CPListTemplate {
        let loading = CPListItem(text: String(localized: "加载中..."), detailText: nil)
        loading.isEnabled = false
        let template = CPListTemplate(
            title: String(localized: "歌单"),
            sections: [CPListSection(items: [loading])]
        )
        return template
    }
    
    private func loadPlaylistData() {
        let ncmSquare = CPListItem(text: String(localized: "NCM·歌单广场"), detailText: String(localized: "发现更多好歌单"))
        ncmSquare.setImage(UIImage(systemName: "square.grid.2x2.fill"))
        ncmSquare.handler = { [weak self] _, completion in
            Task { @MainActor in self?.pushPlaylistSquare() }
            completion()
        }
        
        let qqSquare = CPListItem(text: String(localized: "QCM·歌单广场"), detailText: String(localized: "发现QCM好歌单"))
        qqSquare.setImage(UIImage(systemName: "square.grid.2x2"))
        qqSquare.handler = { [weak self] _, completion in
            Task { @MainActor in self?.pushQQPlaylistSquare() }
            completion()
        }
        
        let ncmArtists = CPListItem(text: String(localized: "NCM·歌手"), detailText: String(localized: "按地区浏览歌手"))
        ncmArtists.setImage(UIImage(systemName: "person.2.fill"))
        ncmArtists.handler = { [weak self] _, completion in
            Task { @MainActor in self?.pushNCMArtistCategories() }
            completion()
        }
        
        let qqArtists = CPListItem(text: String(localized: "QCM·歌手"), detailText: String(localized: "按地区浏览歌手"))
        qqArtists.setImage(UIImage(systemName: "person.2"))
        qqArtists.handler = { [weak self] _, completion in
            Task { @MainActor in self?.pushQQArtistCategories() }
            completion()
        }
        
        let entrySections = [CPListSection(items: [ncmSquare, qqSquare, ncmArtists, qqArtists], header: String(localized: "发现"), sectionIndexTitle: nil)]
        
        var localSections = [CPListSection]()
        let localPlaylists = LocalPlaylistManager.shared.playlists
        if !localPlaylists.isEmpty {
            let items = localPlaylists.map { lp -> CPListItem in
                let item = CPListItem(
                    text: lp.name,
                    detailText: String(localized: "\(lp.songs.count) 首")
                )
                item.handler = { [weak self] _, completion in
                    Task { @MainActor in
                        self?.pushLocalPlaylistDetail(lp)
                    }
                    completion()
                }
                return item
            }
            localSections.append(CPListSection(items: items, header: String(localized: "本地歌单"), sectionIndexTitle: nil))
        }
        
        guard let uid = APIService.shared.currentUserId else {
            var all = entrySections + localSections
            if localSections.isEmpty {
                let empty = CPListItem(text: String(localized: "未登录"), detailText: String(localized: "请在手机端登录后使用"))
                empty.isEnabled = false
                all.append(CPListSection(items: [empty]))
            }
            playlistTemplate?.updateSections(all)
            return
        }
        
        APIService.shared.fetchUserPlaylists(uid: uid)
            .catch { _ in Just([Playlist]()) }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] userPlaylists in
                guard let self else { return }
                var allSections = entrySections + localSections
                
                if !userPlaylists.isEmpty {
                    let items = userPlaylists.map { playlist -> CPListItem in
                        let item = CPListItem(
                            text: playlist.name,
                            detailText: String(localized: "\(playlist.trackCount ?? 0) 首")
                        )
                        item.handler = { [weak self] _, completion in
                            Task { @MainActor in
                                self?.pushPlaylistDetail(playlist)
                            }
                            completion()
                        }
                        self.loadArtwork(url: playlist.coverUrl, for: item)
                        return item
                    }
                    allSections.append(CPListSection(items: items, header: String(localized: "NCM歌单"), sectionIndexTitle: nil))
                }
                
                self.playlistTemplate?.updateSections(allSections)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Playlist Square (歌单广场)
    
    private func pushPlaylistSquare() {
        let loading = CPListItem(text: String(localized: "加载分类..."), detailText: nil)
        loading.isEnabled = false
        let square = CPListTemplate(
            title: String(localized: "歌单广场"),
            sections: [CPListSection(items: [loading])]
        )
        interfaceController.pushTemplate(square, animated: true, completion: nil)
        
        APIService.shared.fetchHotPlaylistCategories()
            .catch { _ in Just([PlaylistCategory]()) }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] categories in
                guard let self else { return }
                if categories.isEmpty {
                    let empty = CPListItem(text: String(localized: "暂无分类"), detailText: nil)
                    empty.isEnabled = false
                    square.updateSections([CPListSection(items: [empty])])
                    return
                }
                
                var catItems = [CPListItem]()
                let allItem = CPListItem(text: String(localized: "全部"), detailText: nil)
                allItem.handler = { [weak self] _, completion in
                    Task { @MainActor in
                        self?.pushCategoryPlaylists(cat: String(localized: "全部"))
                    }
                    completion()
                }
                catItems.append(allItem)
                
                for cat in categories.prefix(20) {
                    let item = CPListItem(text: cat.name, detailText: nil)
                    item.handler = { [weak self] _, completion in
                        Task { @MainActor in
                            self?.pushCategoryPlaylists(cat: cat.name)
                        }
                        completion()
                    }
                    catItems.append(item)
                }
                square.updateSections([CPListSection(items: catItems, header: String(localized: "选择分类"), sectionIndexTitle: nil)])
            }
            .store(in: &cancellables)
    }
    
    private func pushCategoryPlaylists(cat: String) {
        let loading = CPListItem(text: String(localized: "加载中..."), detailText: nil)
        loading.isEnabled = false
        let detail = CPListTemplate(
            title: cat,
            sections: [CPListSection(items: [loading])]
        )
        interfaceController.pushTemplate(detail, animated: true, completion: nil)
        
        APIService.shared.fetchTopPlaylists(cat: cat, limit: 30)
            .catch { _ in Just([Playlist]()) }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] playlists in
                guard let self else { return }
                if playlists.isEmpty {
                    let empty = CPListItem(text: String(localized: "暂无歌单"), detailText: nil)
                    empty.isEnabled = false
                    detail.updateSections([CPListSection(items: [empty])])
                } else {
                    let items = playlists.map { playlist -> CPListItem in
                        let item = CPListItem(
                            text: playlist.name,
                            detailText: String(localized: "\(playlist.trackCount ?? 0) 首")
                        )
                        item.handler = { [weak self] _, completion in
                            Task { @MainActor in
                                self?.pushPlaylistDetail(playlist)
                            }
                            completion()
                        }
                        self.loadArtwork(url: playlist.coverUrl, for: item)
                        return item
                    }
                    detail.updateSections([CPListSection(items: items)])
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - QQ Playlist Square (QQ歌单广场)
    
    private static let hiddenQQCategories: Set<String> = [
        String(localized: "全部"), String(localized: "ai歌单"), String(localized: "私藏"), String(localized: "音乐人在听"), "chill vibes", String(localized: "ai 歌单")
    ]
    
    private func pushQQPlaylistSquare() {
        let loading = CPListItem(text: String(localized: "加载分类..."), detailText: nil)
        loading.isEnabled = false
        let square = CPListTemplate(
            title: String(localized: "QCM·歌单广场"),
            sections: [CPListSection(items: [loading])]
        )
        interfaceController.pushTemplate(square, animated: true, completion: nil)
        
        APIService.shared.fetchQQPlaylistCategories()
            .catch { _ in Just([(id: Int, name: String)]()) }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] categories in
                guard let self else { return }
                let filtered = categories.filter {
                    !Self.hiddenQQCategories.contains($0.name.lowercased())
                }
                if filtered.isEmpty {
                    let empty = CPListItem(text: String(localized: "暂无分类"), detailText: nil)
                    empty.isEnabled = false
                    square.updateSections([CPListSection(items: [empty])])
                    return
                }
                let items = filtered.prefix(25).map { cat -> CPListItem in
                    let item = CPListItem(text: cat.name, detailText: nil)
                    item.handler = { [weak self] _, completion in
                        Task { @MainActor in
                            self?.pushQQCategoryPlaylists(categoryId: cat.id, name: cat.name)
                        }
                        completion()
                    }
                    return item
                }
                square.updateSections([CPListSection(items: items, header: String(localized: "选择分类"), sectionIndexTitle: nil)])
            }
            .store(in: &cancellables)
    }
    
    private func pushQQCategoryPlaylists(categoryId: Int, name: String) {
        let loading = CPListItem(text: String(localized: "加载中..."), detailText: nil)
        loading.isEnabled = false
        let detail = CPListTemplate(title: name, sections: [CPListSection(items: [loading])])
        interfaceController.pushTemplate(detail, animated: true, completion: nil)
        
        APIService.shared.fetchQQPlaylistsByCategory(categoryId: categoryId, size: 30)
            .catch { _ in Just((playlists: [Playlist](), hasMore: false)) }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                guard let self else { return }
                if result.playlists.isEmpty {
                    let empty = CPListItem(text: String(localized: "暂无歌单"), detailText: nil)
                    empty.isEnabled = false
                    detail.updateSections([CPListSection(items: [empty])])
                } else {
                    let items = result.playlists.map { self.makePlaylistItem($0) }
                    detail.updateSections([CPListSection(items: items)])
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - NCM Artist Categories
    
    private func pushNCMArtistCategories() {
        let areas: [(String, Int)] = [
            (String(localized: "热门歌手"), -1), (String(localized: "华语"), 7), (String(localized: "欧美"), 96),
            (String(localized: "日本"), 8), (String(localized: "韩国"), 16), (String(localized: "其他"), 0)
        ]
        let items = areas.map { name, area -> CPListItem in
            let item = CPListItem(text: name, detailText: nil)
            item.handler = { [weak self] _, completion in
                Task { @MainActor in self?.pushNCMArtistList(area: area, title: name) }
                completion()
            }
            return item
        }
        let template = CPListTemplate(
            title: String(localized: "NCM·歌手"),
            sections: [CPListSection(items: items, header: String(localized: "选择地区"), sectionIndexTitle: nil)]
        )
        interfaceController.pushTemplate(template, animated: true, completion: nil)
    }
    
    private func pushNCMArtistList(area: Int, title: String) {
        let loading = CPListItem(text: String(localized: "加载中..."), detailText: nil)
        loading.isEnabled = false
        let detail = CPListTemplate(title: title, sections: [CPListSection(items: [loading])])
        interfaceController.pushTemplate(detail, animated: true, completion: nil)
        
        let pub: AnyPublisher<[ArtistInfo], Error>
        if area == -1 {
            pub = APIService.shared.fetchTopArtists(limit: 50)
        } else {
            pub = APIService.shared.fetchArtistList(area: area, limit: 50)
        }
        
        pub.catch { _ in Just([ArtistInfo]()) }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] artists in
                guard let self else { return }
                if artists.isEmpty {
                    let empty = CPListItem(text: String(localized: "暂无歌手"), detailText: nil)
                    empty.isEnabled = false
                    detail.updateSections([CPListSection(items: [empty])])
                } else {
                    let items = artists.map { self.makeArtistItem($0) }
                    detail.updateSections([CPListSection(items: items)])
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - QQ Artist Categories
    
    private func pushQQArtistCategories() {
        let areas: [(String, AreaType)] = [
            (String(localized: "全部"), .all), (String(localized: "华语"), .china), (String(localized: "欧美"), .america),
            (String(localized: "日本"), .japan), (String(localized: "韩国"), .korea), (String(localized: "台湾"), .taiwan)
        ]
        let items = areas.map { name, area -> CPListItem in
            let item = CPListItem(text: name, detailText: nil)
            item.handler = { [weak self] _, completion in
                Task { @MainActor in self?.pushQQArtistList(area: area, title: name) }
                completion()
            }
            return item
        }
        let template = CPListTemplate(
            title: String(localized: "QCM·歌手"),
            sections: [CPListSection(items: items, header: String(localized: "选择地区"), sectionIndexTitle: nil)]
        )
        interfaceController.pushTemplate(template, animated: true, completion: nil)
    }
    
    private func pushQQArtistList(area: AreaType, title: String) {
        let loading = CPListItem(text: String(localized: "加载中..."), detailText: nil)
        loading.isEnabled = false
        let detail = CPListTemplate(title: title, sections: [CPListSection(items: [loading])])
        interfaceController.pushTemplate(detail, animated: true, completion: nil)
        
        APIService.shared.fetchQQSingerList(area: area)
            .catch { _ in Just([ArtistInfo]()) }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] artists in
                guard let self else { return }
                if artists.isEmpty {
                    let empty = CPListItem(text: String(localized: "暂无歌手"), detailText: nil)
                    empty.isEnabled = false
                    detail.updateSections([CPListSection(items: [empty])])
                } else {
                    let items = artists.map { self.makeArtistItem($0) }
                    detail.updateSections([CPListSection(items: items)])
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Artist Item & Detail
    
    private func makeArtistItem(_ artist: ArtistInfo) -> CPListItem {
        let detail = [
            artist.musicSize.map { String(localized: "\($0) 首") },
            artist.albumSize.map { String(localized: "\($0) 专辑") }
        ].compactMap { $0 }.joined(separator: " · ")
        
        let item = CPListItem(text: artist.name, detailText: detail.isEmpty ? nil : detail)
        item.handler = { [weak self] _, completion in
            Task { @MainActor in self?.pushArtistDetail(artist) }
            completion()
        }
        loadArtwork(url: artist.coverUrl, for: item)
        return item
    }
    
    private func pushArtistDetail(_ artist: ArtistInfo) {
        let loading = CPListItem(text: String(localized: "加载中..."), detailText: nil)
        loading.isEnabled = false
        let detail = CPListTemplate(title: artist.name, sections: [CPListSection(items: [loading])])
        interfaceController.pushTemplate(detail, animated: true, completion: nil)
        
        let songsPub: AnyPublisher<[Song], Error>
        let albumsPub: AnyPublisher<[AlbumInfo], Error>
        
        if artist.isQQMusic, let mid = artist.qqMid {
            songsPub = APIService.shared.fetchQQSingerSongs(mid: mid, num: 30)
            albumsPub = APIService.shared.fetchQQSingerAlbums(mid: mid, num: 20)
        } else {
            songsPub = APIService.shared.fetchArtistTopSongs(id: artist.id)
            albumsPub = APIService.shared.fetchArtistAlbums(id: artist.id, limit: 20)
        }
        
        Publishers.CombineLatest(
            songsPub.catch { _ in Just([Song]()) },
            albumsPub.catch { _ in Just([AlbumInfo]()) }
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] songs, albums in
            guard let self else { return }
            var sections = [CPListSection]()
            
            if !songs.isEmpty {
                let items = songs.prefix(30).map { self.makeSongItem($0, context: Array(songs)) }
                sections.append(CPListSection(items: items, header: String(localized: "热门歌曲"), sectionIndexTitle: nil))
            }
            
            if !albums.isEmpty {
                let items = albums.prefix(20).map { album -> CPListItem in
                    self.makeAlbumItem(album, artist: artist)
                }
                sections.append(CPListSection(items: items, header: String(localized: "专辑"), sectionIndexTitle: nil))
            }
            
            if sections.isEmpty {
                let empty = CPListItem(text: String(localized: "暂无内容"), detailText: nil)
                empty.isEnabled = false
                sections.append(CPListSection(items: [empty]))
            }
            
            detail.updateSections(sections)
        }
        .store(in: &cancellables)
    }
    
    // MARK: - Album Item & Detail
    
    private func makeAlbumItem(_ album: AlbumInfo, artist: ArtistInfo) -> CPListItem {
        let detailText = [
            album.size.map { String(localized: "\($0) 首") },
            album.publishDateText.isEmpty ? nil : album.publishDateText
        ].compactMap { $0 }.joined(separator: " · ")
        
        let item = CPListItem(text: album.name, detailText: detailText.isEmpty ? nil : detailText)
        item.handler = { [weak self] _, completion in
            Task { @MainActor in self?.pushAlbumSongs(album, artist: artist) }
            completion()
        }
        loadArtwork(url: album.coverUrl, for: item)
        return item
    }
    
    private func pushAlbumSongs(_ album: AlbumInfo, artist: ArtistInfo) {
        let loading = CPListItem(text: String(localized: "加载中..."), detailText: nil)
        loading.isEnabled = false
        let detail = CPListTemplate(title: album.name, sections: [CPListSection(items: [loading])])
        interfaceController.pushTemplate(detail, animated: true, completion: nil)
        
        let pub: AnyPublisher<[Song], Error>
        if artist.isQQMusic, let mid = album.qqAlbumMid {
            pub = APIService.shared.fetchQQAlbumSongs(albumMid: mid)
        } else {
            pub = APIService.shared.fetchAlbumDetail(id: album.id).map(\.songs).eraseToAnyPublisher()
        }
        
        pub.catch { _ in Just([Song]()) }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] songs in
                guard let self else { return }
                if songs.isEmpty {
                    let empty = CPListItem(text: String(localized: "专辑为空"), detailText: nil)
                    empty.isEnabled = false
                    detail.updateSections([CPListSection(items: [empty])])
                } else {
                    let items = songs.map { self.makeSongItem($0, context: songs) }
                    detail.updateSections([CPListSection(items: items)])
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Playlist Detail (Push)
    
    private func pushPlaylistDetail(_ playlist: Playlist) {
        let loading = CPListItem(text: String(localized: "加载中..."), detailText: nil)
        loading.isEnabled = false
        let detail = CPListTemplate(
            title: playlist.name,
            sections: [CPListSection(items: [loading])]
        )
        
        interfaceController.pushTemplate(detail, animated: true, completion: nil)
        
        let publisher: AnyPublisher<[Song], Error>
        if playlist.isQQMusic {
            publisher = APIService.shared.fetchQQPlaylistSongs(playlistId: playlist.id)
        } else {
            publisher = APIService.shared.fetchPlaylistTracks(id: playlist.id, limit: 100, offset: 0)
        }
        
        publisher
            .catch { _ in Just([Song]()) }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] songs in
                guard let self else { return }
                if songs.isEmpty {
                    let empty = CPListItem(text: String(localized: "歌单为空"), detailText: nil)
                    empty.isEnabled = false
                    detail.updateSections([CPListSection(items: [empty])])
                } else {
                    let items = songs.map { song in
                        self.makeSongItem(song, context: songs)
                    }
                    detail.updateSections([CPListSection(items: items)])
                }
            }
            .store(in: &cancellables)
    }
    
    private func pushLocalPlaylistDetail(_ lp: LocalPlaylist) {
        let songs = lp.songs
        if songs.isEmpty {
            let empty = CPListItem(text: String(localized: "歌单为空"), detailText: nil)
            empty.isEnabled = false
            let detail = CPListTemplate(
                title: lp.name,
                sections: [CPListSection(items: [empty])]
            )
            interfaceController.pushTemplate(detail, animated: true, completion: nil)
            return
        }
        
        let items = songs.map { makeSongItem($0, context: songs) }
        let detail = CPListTemplate(
            title: lp.name,
            sections: [CPListSection(items: items)]
        )
        interfaceController.pushTemplate(detail, animated: true, completion: nil)
    }
    
    // MARK: - Search Tab (Hot Keywords)
    
    private func makeSearchTab() -> CPListTemplate {
        let loading = CPListItem(text: String(localized: "加载中..."), detailText: nil)
        loading.isEnabled = false
        let assistantConfig = CPAssistantCellConfiguration(
            position: .top,
            visibility: .always,
            assistantAction: .playMedia
        )
        return CPListTemplate(
            title: String(localized: "搜索"),
            sections: [CPListSection(items: [loading])],
            assistantCellConfiguration: assistantConfig
        )
    }
    
    private func loadHotSearch() {
        let ncmHot = APIService.shared.fetchHotSearch().catch { _ in Just([HotSearchItem]()) }
        let qqHot = APIService.shared.fetchQQHotSearch().catch { _ in Just([HotSearchItem]()) }
        
        Publishers.CombineLatest(ncmHot, qqHot)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] ncmItems, qqItems in
                guard let self else { return }
                var sections = [CPListSection]()
                
                if !ncmItems.isEmpty {
                    let items = ncmItems.prefix(15).enumerated().map { index, hot -> CPListItem in
                        let item = CPListItem(
                            text: "\(index + 1). \(hot.searchWord)",
                            detailText: hot.content
                        )
                        item.handler = { [weak self] _, completion in
                            Task { @MainActor in self?.searchAndPush(keyword: hot.searchWord) }
                            completion()
                        }
                        return item
                    }
                    sections.append(CPListSection(items: items, header: String(localized: "NCM热搜"), sectionIndexTitle: nil))
                }
                
                if !qqItems.isEmpty {
                    let items = qqItems.prefix(15).enumerated().map { index, hot -> CPListItem in
                        let item = CPListItem(
                            text: "\(index + 1). \(hot.searchWord)",
                            detailText: hot.content
                        )
                        item.handler = { [weak self] _, completion in
                            Task { @MainActor in self?.searchAndPush(keyword: hot.searchWord) }
                            completion()
                        }
                        return item
                    }
                    sections.append(CPListSection(items: items, header: String(localized: "QCM热搜"), sectionIndexTitle: nil))
                }
                
                if sections.isEmpty {
                    let empty = CPListItem(text: String(localized: "暂无热搜"), detailText: nil)
                    empty.isEnabled = false
                    sections.append(CPListSection(items: [empty]))
                }
                
                self.searchTemplate?.updateSections(sections)
            }
            .store(in: &cancellables)
    }
    
    private func searchAndPush(keyword: String) {
        let loading = CPListItem(text: String(localized: "搜索中..."), detailText: nil)
        loading.isEnabled = false
        let detail = CPListTemplate(
            title: keyword,
            sections: [CPListSection(items: [loading])]
        )
        interfaceController.pushTemplate(detail, animated: true, completion: nil)
        
        let ncmSearch = APIService.shared.searchSongs(keyword: keyword).catch { _ in Just([Song]()) }
        let qqSearch = APIService.shared.searchQQSongs(keyword: keyword).catch { _ in Just([Song]()) }
        
        Publishers.CombineLatest(ncmSearch, qqSearch)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] ncmSongs, qqSongs in
                guard let self else { return }
                var sections = [CPListSection]()
                
                if !ncmSongs.isEmpty {
                    let items = ncmSongs.prefix(20).map { self.makeSongItem($0, context: Array(ncmSongs)) }
                    sections.append(CPListSection(items: items, header: "NCM", sectionIndexTitle: nil))
                }
                
                if !qqSongs.isEmpty {
                    let items = qqSongs.prefix(20).map { self.makeSongItem($0, context: Array(qqSongs)) }
                    sections.append(CPListSection(items: items, header: "QCM", sectionIndexTitle: nil))
                }
                
                if sections.isEmpty {
                    let empty = CPListItem(text: String(localized: "无搜索结果"), detailText: nil)
                    empty.isEnabled = false
                    sections.append(CPListSection(items: [empty]))
                }
                
                detail.updateSections(sections)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Now Playing Tab
    
    private func makeNowPlayingEntryTab() -> CPListTemplate {
        let item = CPListItem(text: String(localized: "正在播放"), detailText: String(localized: "查看当前播放信息"))
        item.setImage(UIImage(systemName: "play.circle.fill"))
        item.handler = { [weak self] _, completion in
            Task { @MainActor in
                guard let self else { return }
                let np = CPNowPlayingTemplate.shared
                self.interfaceController.pushTemplate(np, animated: true, completion: nil)
            }
            completion()
        }
        return CPListTemplate(title: String(localized: "正在播放"), sections: [CPListSection(items: [item])])
    }
    
    private func configureNowPlaying(_ template: CPNowPlayingTemplate) {
        template.add(self)
        template.isUpNextButtonEnabled = false
        template.isAlbumArtistButtonEnabled = false
        
        updateNowPlayingButtons(template)
    }
    
    private func updateNowPlayingButtons(_ template: CPNowPlayingTemplate) {
        let player = PlayerManager.shared
        
        let modeImage: UIImage?
        let modeTitle: String
        switch player.mode {
        case .sequence:
            modeImage = UIImage(systemName: "repeat")
            modeTitle = String(localized: "顺序播放")
        case .loopSingle:
            modeImage = UIImage(systemName: "repeat.1")
            modeTitle = String(localized: "单曲循环")
        case .shuffle:
            modeImage = UIImage(systemName: "shuffle")
            modeTitle = String(localized: "随机播放")
        }
        
        if let _ = modeImage {
            let modeButton = CPNowPlayingButton(handler: { [weak self] _ in
                Task { @MainActor in
                    PlayerManager.shared.switchMode()
                    self?.updateNowPlayingButtons(template)
                }
            })
            modeButton.accessibilityLabel = modeTitle
            template.updateNowPlayingButtons([modeButton])
        }
    }
    
    // MARK: - Playlist Item Builder
    
    private func makePlaylistItem(_ playlist: Playlist) -> CPListItem {
        let count = playlist.trackCount ?? 0
        let item = CPListItem(
            text: playlist.name,
            detailText: count > 0 ? String(localized: "\(count) 首") : nil
        )
        item.handler = { [weak self] _, completion in
            Task { @MainActor in self?.pushPlaylistDetail(playlist) }
            completion()
        }
        loadArtwork(url: playlist.coverUrl, for: item)
        return item
    }
    
    // MARK: - Song Item Builder
    
    private func makeSongItem(_ song: Song, context: [Song]) -> CPListItem {
        let item = CPListItem(
            text: song.name,
            detailText: song.artistName
        )
        item.isExplicitContent = false
        
        let isPlaying = PlayerManager.shared.currentSong?.id == song.id
        item.playingIndicatorLocation = isPlaying ? .trailing : .leading
        item.isPlaying = isPlaying
        
        item.handler = { _, completion in
            Task { @MainActor in
                PlayerManager.shared.play(song: song, in: context)
            }
            completion()
        }
        
        loadArtwork(url: song.coverUrl, for: item, size: 80)
        return item
    }
    
    // MARK: - Artwork Loading
    
    private func loadArtwork(url: URL?, for item: CPListItem, size: Int = 180) {
        guard let url = url else { return }
        
        let sized = url.sized(size)
        Task {
            let image = await ImageLoadCoordinator.shared.loadImage(url: sized)
            if let image {
                item.setImage(image)
            }
        }
    }
}

// MARK: - CPNowPlayingTemplateObserver

extension CarPlayContentManager: @preconcurrency CPNowPlayingTemplateObserver {
    func nowPlayingTemplateUpNextButtonTapped(_ nowPlayingTemplate: CPNowPlayingTemplate) {}
    func nowPlayingTemplateAlbumArtistButtonTapped(_ nowPlayingTemplate: CPNowPlayingTemplate) {}
}

