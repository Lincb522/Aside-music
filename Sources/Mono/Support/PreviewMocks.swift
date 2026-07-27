import SwiftUI

/// 为全项目 UI 预览提供 Mock 数据
@MainActor
struct PreviewMocks {
    
    // MARK: - Sample Data
    
    static let song = Song(
        id: 1,
        name: "青花瓷",
        ar: [Artist(id: 1, name: "周杰伦")],
        al: Album(id: 1, name: "我很忙", picUrl: "https://p2.music.126.net/L6v6Bcn9Nshf99G9-Yl8WA==/109951165608244970.jpg"),
        dt: 239000,
        fee: 0,
        mv: 0,
        h: nil, m: nil, l: nil, sq: nil, hr: nil,
        alia: ["Qing Hua Ci"],
        privilege: nil,
        source: .netease
    )
    
    static let songs: [Song] = [
        song,
        Song(id: 2, name: "兰亭序", ar: [Artist(id: 1, name: "周杰伦")], al: Album(id: 2, name: "魔杰座", picUrl: ""), dt: 254000, fee: 0, mv: 0, h: nil, m: nil, l: nil, sq: nil, hr: nil, alia: nil, privilege: nil, source: .netease),
        Song(id: 3, name: "发如雪", ar: [Artist(id: 1, name: "周杰伦")], al: Album(id: 3, name: "十一月的萧邦", picUrl: ""), dt: 301000, fee: 0, mv: 0, h: nil, m: nil, l: nil, sq: nil, hr: nil, alia: nil, privilege: nil, source: .netease)
    ]
    
    static let playlist = Playlist(
        id: 1,
        name: "水墨国风精选",
        coverImgUrl: nil,
        picUrl: "https://p2.music.126.net/L6v6Bcn9Nshf99G9-Yl8WA==/109951165608244970.jpg",
        trackCount: 10,
        playCount: 1234567,
        subscribedCount: 100,
        shareCount: 50,
        commentCount: 20,
        creator: PlaylistCreator(userId: 1, nickname: "Mono", avatarUrl: ""),
        description: "素胚勾勒出青花笔锋浓转淡",
        tags: ["国风", "古风"]
    )
    
    // MARK: - Mock State Configuration
    
    /// 初始化 PlayerManager 的预览状态
    static func setupPlayerPreview() {
        let player = PlayerManager.shared
        player.currentSong = song
        player.context = songs
        player.isPlaying = true
    }
    
    /// 初始化 HomeViewModel 的预览状态
    static func setupHomePreview() {
        let home = HomeViewModel.shared
        home.dailySongs = songs
        home.recommendPlaylists = [playlist]
        home.banners = [
            Banner(targetId: 1, targetType: 1, typeTitle: "HOT", url: nil, pic: "https://p1.music.126.net/test1.jpg"),
            Banner(targetId: 2, targetType: 1, typeTitle: "NEW", url: nil, pic: "https://p1.music.126.net/test2.jpg")
        ]
    }
}

// MARK: - Preview Helpers

extension View {
    /// 注入所有必要的预览环境
    func withPreviewEnvironment() -> some View {
        self
            .onAppear {
                PreviewMocks.setupPlayerPreview()
                PreviewMocks.setupHomePreview()
            }
    }
}
