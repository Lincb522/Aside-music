// DemoViewModel.swift
// 示例应用的核心 ViewModel
// 管理 NCMClient 实例和所有 API 调用

import SwiftUI
import AVFoundation
import NeteaseCloudMusicAPI
import CoreImage.CIFilterBuiltins

@MainActor
class DemoViewModel: ObservableObject {

    // MARK: - 客户端

    private(set) var client: NCMClient

    // MARK: - 设置

    @Published var serverUrl: String = "" {
        didSet { updateClient() }
    }
    @Published var cookie: String = ""
    @Published var connectionStatus: String = "未连接"

    // MARK: - 登录

    @Published var isLoggedIn: Bool = false
    @Published var loginNickname: String = ""
    @Published var qrImage: UIImage?
    @Published var qrStatusText: String = ""
    @Published var qrPolling: Bool = false
    private var qrKey: String = ""

    // MARK: - 播放测试

    @Published var testSongId: String = "347230"
    @Published var playSongName: String = ""
    @Published var playUrl: String = ""
    @Published var playStatus: String = ""
    @Published var isPlaying: Bool = false
    @Published var isPlayLoading: Bool = false
    private var audioPlayer: AVPlayer?

    // MARK: - 搜索

    @Published var searchKeyword: String = ""
    @Published var searchResults: [[String: Any]] = []
    @Published var selectedSongLyric: String = ""
    @Published var selectedSongName: String = ""

    // MARK: - 歌单

    @Published var hotPlaylists: [[String: Any]] = []
    @Published var playlistTracks: [[String: Any]] = []
    @Published var selectedPlaylistName: String = ""

    // MARK: - 排行榜

    @Published var toplists: [[String: Any]] = []

    // MARK: - 电台

    @Published var djRecommendList: [[String: Any]] = []
    @Published var djHotList: [[String: Any]] = []
    @Published var djCategories: [[String: Any]] = []
    @Published var djProgramToplistData: [[String: Any]] = []
    @Published var djProgramList: [[String: Any]] = []
    @Published var selectedRadioName: String = ""

    // MARK: - 专辑

    @Published var newAlbums: [[String: Any]] = []
    @Published var newestAlbums: [[String: Any]] = []
    @Published var albumDetailName: String = ""
    @Published var albumTracks: [[String: Any]] = []

    // MARK: - 歌手

    @Published var artistIdInput: String = "6452"
    @Published var artistName: String = ""
    @Published var artistAlias: String = ""
    @Published var artistFansCount: Int = 0
    @Published var artistTopSongs: [[String: Any]] = []
    @Published var artistAlbums: [[String: Any]] = []
    @Published var simiArtists: [[String: Any]] = []
    @Published var artistListData: [[String: Any]] = []

    // MARK: - MV / 视频

    @Published var mvList: [[String: Any]] = []
    @Published var mvFirstList: [[String: Any]] = []
    @Published var mvExclusiveList: [[String: Any]] = []
    @Published var mvDetailName: String = ""
    @Published var mvDetailArtist: String = ""
    @Published var mvDetailUrl: String = ""
    @Published var mvDetailPlayCount: Int = 0
    @Published var mvDetailCommentCount: Int = 0
    @Published var mvDetailLikeCount: Int = 0

    // MARK: - 评论

    @Published var commentResourceId: String = "347230"
    @Published var commentTypeIndex: Int = 0
    @Published var commentList: [[String: Any]] = []
    @Published var commentTotal: Int = 0
    @Published var isHotComments: Bool = false

    // MARK: - 用户

    @Published var userIdInput: String = ""
    @Published var userInfoName: String = ""
    @Published var userInfoSignature: String = ""
    @Published var userInfoFollows: Int = 0
    @Published var userInfoFolloweds: Int = 0
    @Published var userInfoLevel: Int = 0
    @Published var userPlaylists: [[String: Any]] = []
    @Published var userRecordSongs: [[String: Any]] = []
    @Published var accountInfoText: String = ""

    // MARK: - 推荐

    @Published var personalizedPlaylists: [[String: Any]] = []
    @Published var personalizedSongs: [[String: Any]] = []
    @Published var dailyRecommendSongs: [[String: Any]] = []
    @Published var personalFmSongs: [[String: Any]] = []

    // MARK: - 云盘

    @Published var cloudSongs: [[String: Any]] = []
    @Published var cloudSongCount: Int = 0

    // MARK: - VIP / 云贝

    @Published var vipInfoText: String = ""
    @Published var vipGrowthText: String = ""
    @Published var vipTaskList: [[String: Any]] = []
    @Published var yunbeiInfoText: String = ""
    @Published var yunbeiTaskList: [[String: Any]] = []

    // MARK: - 杂项

    @Published var styleListData: [[String: Any]] = []
    @Published var homepageInfo: String = ""
    @Published var signinInfo: String = ""
    @Published var countriesCodeCount: Int = 0
    @Published var recentListenInfo: String = ""
    @Published var simiSongIdInput: String = "347230"
    @Published var simiResults: [[String: Any]] = []

    // MARK: - 解灰

    /// 音源配置项（用于 UI 管理）
    struct SourceItem: Identifiable {
        let id = UUID()
        var name: String
        var type: UnblockSourceType
        var url: String          // 自定义地址音源的 URL
        var script: String       // JS 脚本内容
        var urlTemplate: String? // 自定义 URL 模板
        var enabled: Bool = true
    }

    @Published var unblockSources: [SourceItem] = []
    @Published var unblockQuality: String = "320"
    @Published var unblockSongId: String = "347230"
    @Published var unblockSongName: String = ""
    @Published var unblockResult: UnblockResult?
    @Published var unblockError: String?
    @Published var unblockPlayStatus: String = ""
    @Published var isUnblockPlaying: Bool = false
    @Published var isUnblockLoading: Bool = false
    @Published var isUnblockAllLoading: Bool = false
    @Published var unblockAllResults: [UnblockTestItem] = []
    @Published var showJSFilePicker: Bool = false
    @Published var showAddURLSource: Bool = false
    @Published var jsScriptInput: String = ""
    /// 解灰过程日志（供 UI 展示）
    @Published var unblockLogs: [String] = []
    private var unblockPlayer: AVPlayer?

    /// 解灰全部音源对比测试结果项
    struct UnblockTestItem: Identifiable {
        let id = UUID()
        let sourceName: String
        /// 平台标识（如 kw、mg、qq），非洛雪格式为空
        let platformKey: String
        let success: Bool
        let detail: String
        let url: String
        let duration: String
    }

    /// 当前启用的音源数量
    var enabledSourceCount: Int {
        unblockSources.filter { $0.enabled }.count
    }

    // MARK: - 通用状态

    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    /// 当前 Cookie 字符串（用于显示）
    var currentCookies: String {
        let cookies = client.currentCookies
        guard !cookies.isEmpty else { return "" }
        return cookies.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
    }

    // MARK: - 初始化

    init() {
        self.client = NCMClient()
        print("[NCMDemo] 客户端初始化完成")
    }

    private func updateClient() {
        let url = serverUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        client.serverUrl = url.isEmpty ? nil : url
        print("[NCMDemo] 服务地址更新: \(url.isEmpty ? "直连模式" : url)")
    }

    func applyCookie() {
        let trimmed = cookie.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            print("[NCMDemo] ⚠️ Cookie 为空，未设置")
            return
        }
        client.setCookie(trimmed)
        print("[NCMDemo] ✅ Cookie 已手动设置: \(String(trimmed.prefix(60)))...")
        print("[NCMDemo] 📋 当前 Cookie 键: \(client.currentCookies.keys.sorted().joined(separator: ", "))")
        // 自动检查登录状态
        Task { await fetchLoginStatus() }
    }

    // MARK: - 连接测试

    func testConnection() async {
        isLoading = true
        errorMessage = nil
        connectionStatus = "连接中..."
        let start = CFAbsoluteTimeGetCurrent()
        print("[NCMDemo] ➡️ 测试连接: /banner")

        do {
            let response = try await client.banner()
            let ms = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
            if let code = response.body["code"] as? Int, code == 200 {
                let banners = response.body["banners"] as? [[String: Any]] ?? []
                connectionStatus = "连接成功 ✅ (\(banners.count) 条 Banner)"
                print("[NCMDemo] ✅ /banner 成功 [\(ms)ms] banners=\(banners.count)")
            } else {
                connectionStatus = "连接异常: code=\(response.body["code"] ?? "未知")"
                print("[NCMDemo] ⚠️ /banner 异常 [\(ms)ms]")
            }
        } catch {
            let ms = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
            connectionStatus = "连接失败 ❌"
            errorMessage = error.localizedDescription
            print("[NCMDemo] ❌ /banner 失败 [\(ms)ms] \(error)")
        }
        isLoading = false
    }

    // MARK: - 二维码登录

    func startQrLogin() async {
        qrPolling = true
        qrImage = nil
        qrStatusText = "正在生成二维码..."
        errorMessage = nil
        print("[NCMDemo] ➡️ 开始二维码登录流程")

        do {
            // 1. 获取 key
            let keyResp = try await client.loginQrKey()
            let start = CFAbsoluteTimeGetCurrent()
            guard let unikey = (keyResp.body["data"] as? [String: Any])?["unikey"] as? String
                    ?? keyResp.body["unikey"] as? String else {
                qrStatusText = "获取二维码 Key 失败"
                qrPolling = false
                print("[NCMDemo] ❌ 获取 qrKey 失败: \(keyResp.body)")
                return
            }
            qrKey = unikey
            print("[NCMDemo] ✅ qrKey: \(unikey)")

            // 2. 生成二维码
            let qrResp = try await client.loginQrCreate(key: unikey, qrimg: true)
            let qrData = qrResp.body["data"] as? [String: Any] ?? qrResp.body
            if let qrurl = qrData["qrurl"] as? String {
                qrImage = generateQRCode(from: qrurl)
                qrStatusText = "请使用ncm App 扫码"
                print("[NCMDemo] ✅ 二维码已生成, URL: \(qrurl)")
            } else if let qrimg = qrData["qrimg"] as? String,
                      let imgData = Data(base64Encoded: qrimg.replacingOccurrences(of: "data:image/png;base64,", with: "")),
                      let img = UIImage(data: imgData) {
                qrImage = img
                qrStatusText = "请使用ncm App 扫码"
                print("[NCMDemo] ✅ 二维码已生成（base64 图片）")
            }

            // 3. 轮询扫码状态
            while qrPolling {
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 秒
                let checkResp = try await client.loginQrCheck(key: unikey)
                let code = checkResp.body["code"] as? Int ?? 0
                let message = checkResp.body["message"] as? String ?? ""
                let elapsed = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)

                switch code {
                case 800:
                    qrStatusText = "二维码已过期，请重新生成"
                    qrPolling = false
                    print("[NCMDemo] ⚠️ 二维码过期 [\(elapsed)ms]")
                case 801:
                    qrStatusText = "等待扫码..."
                    print("[NCMDemo] ⏳ 等待扫码 [\(elapsed)ms]")
                case 802:
                    qrStatusText = "已扫码，等待确认..."
                    print("[NCMDemo] ⏳ 已扫码待确认 [\(elapsed)ms]")
                case 803:
                    qrStatusText = "登录成功！"
                    qrPolling = false
                    print("[NCMDemo] ✅ 二维码登录成功 [\(elapsed)ms]")
                    print("[NCMDemo] 📋 Cookie: \(currentCookies.prefix(100))...")
                    // 自动获取用户信息
                    await fetchLoginStatus()
                default:
                    qrStatusText = "状态: \(code) \(message)"
                    print("[NCMDemo] ❓ 未知状态 code=\(code) msg=\(message)")
                }
            }
        } catch {
            qrStatusText = "登录失败: \(error.localizedDescription)"
            qrPolling = false
            print("[NCMDemo] ❌ 二维码登录失败: \(error)")
        }
    }

    /// 获取登录状态并更新用户信息
    func fetchLoginStatus() async {
        print("[NCMDemo] ➡️ 获取登录状态")
        do {
            let resp = try await client.loginStatus()
            if let profile = resp.body["profile"] as? [String: Any],
               let nickname = profile["nickname"] as? String {
                isLoggedIn = true
                loginNickname = nickname
                print("[NCMDemo] ✅ 已登录: \(nickname)")
            } else if let account = resp.body["account"] as? [String: Any],
                      let id = account["id"] {
                isLoggedIn = true
                loginNickname = "用户 \(id)"
                print("[NCMDemo] ✅ 已登录: 用户 \(id)")
            } else {
                isLoggedIn = false
                loginNickname = ""
                print("[NCMDemo] ⚠️ 未登录")
            }
        } catch {
            print("[NCMDemo] ❌ 获取登录状态失败: \(error)")
        }
    }

    /// 退出登录
    func doLogout() async {
        print("[NCMDemo] ➡️ 退出登录")
        do {
            _ = try await client.logout()
            isLoggedIn = false
            loginNickname = ""
            qrImage = nil
            print("[NCMDemo] ✅ 已退出登录")
        } catch {
            print("[NCMDemo] ❌ 退出登录失败: \(error)")
        }
    }

    /// 生成二维码 UIImage
    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let outputImage = filter.outputImage else { return nil }
        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    // MARK: - 播放测试

    func testPlaySong() async {
        guard let songId = Int(testSongId) else {
            playStatus = "请输入有效的歌曲 ID"
            return
        }
        isPlayLoading = true
        playStatus = ""
        playSongName = ""
        playUrl = ""
        print("[NCMDemo] ➡️ 播放测试: id=\(songId)")

        do {
            // 获取歌曲详情
            let detailResp = try await client.songDetail(ids: [songId])
            if let songs = detailResp.body["songs"] as? [[String: Any]],
               let song = songs.first,
               let name = song["name"] as? String {
                let artist = DemoViewModel.artistNames(from: song)
                playSongName = "\(name) - \(artist)"
                print("[NCMDemo] ✅ 歌曲: \(playSongName)")
            }

            // 获取播放链接
            let urlResp = try await client.songUrlV1(ids: [songId], level: .exhigh)
            if let data = urlResp.body["data"] as? [[String: Any]],
               let first = data.first,
               let urlStr = first["url"] as? String, !urlStr.isEmpty {
                playUrl = urlStr
                let size = first["size"] as? Int ?? 0
                let br = first["br"] as? Int ?? 0
                print("[NCMDemo] ✅ 播放链接: \(urlStr)")
                print("[NCMDemo]    码率=\(br/1000)kbps 大小=\(size/1024)KB")

                // 播放
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
                let playerItem = AVPlayerItem(url: URL(string: urlStr)!)
                audioPlayer = AVPlayer(playerItem: playerItem)
                audioPlayer?.play()
                isPlaying = true
                playStatus = "正在播放 (\(br/1000)kbps)"
                print("[NCMDemo] ▶️ 开始播放")
            } else {
                playStatus = "获取播放链接失败（可能需要登录或 VIP）"
                print("[NCMDemo] ⚠️ 无播放链接，可能需要登录")
            }
        } catch {
            playStatus = "播放失败: \(error.localizedDescription)"
            print("[NCMDemo] ❌ 播放测试失败: \(error)")
        }
        isPlayLoading = false
    }

    func stopPlaying() {
        audioPlayer?.pause()
        audioPlayer = nil
        isPlaying = false
        playStatus = "已停止"
        print("[NCMDemo] ⏹ 停止播放")
    }

    // MARK: - 搜索

    func searchSongs() async {
        let keyword = searchKeyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        let start = CFAbsoluteTimeGetCurrent()
        print("[NCMDemo] ➡️ 搜索: \"\(keyword)\"")

        do {
            let response = try await client.cloudsearch(keywords: keyword, type: .single, limit: 20)
            let ms = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
            if let result = response.body["result"] as? [String: Any],
               let songs = result["songs"] as? [[String: Any]] {
                searchResults = songs
                print("[NCMDemo] ✅ 搜索完成 [\(ms)ms] 结果=\(songs.count)首")
            } else {
                searchResults = []
                errorMessage = "未找到结果"
                print("[NCMDemo] ⚠️ 搜索无结果 [\(ms)ms]")
            }
        } catch {
            let ms = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
            errorMessage = "搜索失败: \(error.localizedDescription)"
            print("[NCMDemo] ❌ 搜索失败 [\(ms)ms] \(error)")
        }
        isLoading = false
    }

    func fetchLyric(songId: Int, songName: String) async {
        isLoading = true
        selectedSongName = songName
        selectedSongLyric = ""
        let start = CFAbsoluteTimeGetCurrent()
        print("[NCMDemo] ➡️ 获取歌词: id=\(songId) \"\(songName)\"")

        do {
            let response = try await client.lyric(id: songId)
            let ms = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
            if let lrc = response.body["lrc"] as? [String: Any],
               let lyricText = lrc["lyric"] as? String {
                selectedSongLyric = lyricText
                print("[NCMDemo] ✅ 歌词获取成功 [\(ms)ms] 长度=\(lyricText.count)字符")
            } else {
                selectedSongLyric = "暂无歌词"
                print("[NCMDemo] ⚠️ 暂无歌词 [\(ms)ms]")
            }
        } catch {
            let ms = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
            selectedSongLyric = "获取歌词失败: \(error.localizedDescription)"
            print("[NCMDemo] ❌ 歌词获取失败 [\(ms)ms] \(error)")
        }
        isLoading = false
    }

    // MARK: - 歌单

    func fetchHotPlaylists() async {
        isLoading = true
        errorMessage = nil
        let start = CFAbsoluteTimeGetCurrent()
        print("[NCMDemo] ➡️ 获取热门歌单")

        do {
            let response = try await client.topPlaylist(cat: "全部", limit: 20)
            let ms = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
            if let playlists = response.body["playlists"] as? [[String: Any]] {
                hotPlaylists = playlists
                print("[NCMDemo] ✅ 热门歌单 [\(ms)ms] 数量=\(playlists.count)")
            }
        } catch {
            let ms = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
            errorMessage = "获取歌单失败: \(error.localizedDescription)"
            print("[NCMDemo] ❌ 热门歌单失败 [\(ms)ms] \(error)")
        }
        isLoading = false
    }

    func fetchPlaylistDetail(id: Int, name: String) async {
        isLoading = true
        selectedPlaylistName = name
        playlistTracks = []
        let start = CFAbsoluteTimeGetCurrent()
        print("[NCMDemo] ➡️ 歌单详情: id=\(id) \"\(name)\"")

        do {
            let response = try await client.playlistDetail(id: id)
            let ms = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
            if let playlist = response.body["playlist"] as? [String: Any],
               let tracks = playlist["tracks"] as? [[String: Any]] {
                playlistTracks = Array(tracks.prefix(50))
                print("[NCMDemo] ✅ 歌单详情 [\(ms)ms] 歌曲=\(tracks.count)首")
            }
        } catch {
            let ms = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
            errorMessage = "获取歌单详情失败: \(error.localizedDescription)"
            print("[NCMDemo] ❌ 歌单详情失败 [\(ms)ms] \(error)")
        }
        isLoading = false
    }

    // MARK: - 排行榜

    func fetchToplists() async {
        isLoading = true
        errorMessage = nil
        let start = CFAbsoluteTimeGetCurrent()
        print("[NCMDemo] ➡️ 获取排行榜")

        do {
            let response = try await client.toplist()
            let ms = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
            if let list = response.body["list"] as? [[String: Any]] {
                toplists = list
                print("[NCMDemo] ✅ 排行榜 [\(ms)ms] 数量=\(list.count)")
            }
        } catch {
            let ms = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
            errorMessage = "获取排行榜失败: \(error.localizedDescription)"
            print("[NCMDemo] ❌ 排行榜失败 [\(ms)ms] \(error)")
        }
        isLoading = false
    }

    // MARK: - 电台

    /// 加载电台页面所有数据
    func loadDJData() async {
        isLoading = true
        errorMessage = nil
        print("[NCMDemo] ➡️ 加载电台数据")

        // 并发加载推荐、热门、分类、节目排行
        async let recTask: () = fetchDJRecommend()
        async let hotTask: () = fetchDJHot()
        async let catTask: () = fetchDJCategories()
        async let topTask: () = fetchDJProgramToplist()

        _ = await (recTask, hotTask, catTask, topTask)
        isLoading = false
    }

    /// 获取推荐电台
    private func fetchDJRecommend() async {
        let start = CFAbsoluteTimeGetCurrent()
        do {
            let resp = try await client.djRecommend()
            let ms = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
            if let djRadios = resp.body["djRadios"] as? [[String: Any]] {
                djRecommendList = djRadios
                print("[NCMDemo] ✅ 推荐电台 [\(ms)ms] 数量=\(djRadios.count)")
            }
        } catch {
            print("[NCMDemo] ❌ 推荐电台失败: \(error)")
        }
    }

    /// 获取热门电台
    private func fetchDJHot() async {
        let start = CFAbsoluteTimeGetCurrent()
        do {
            let resp = try await client.djHot(limit: 20)
            let ms = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
            if let djRadios = resp.body["djRadios"] as? [[String: Any]] {
                djHotList = djRadios
                print("[NCMDemo] ✅ 热门电台 [\(ms)ms] 数量=\(djRadios.count)")
            }
        } catch {
            print("[NCMDemo] ❌ 热门电台失败: \(error)")
        }
    }

    /// 获取电台分类
    private func fetchDJCategories() async {
        let start = CFAbsoluteTimeGetCurrent()
        do {
            let resp = try await client.djCatelist()
            let ms = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
            if let categories = resp.body["categories"] as? [[String: Any]] {
                djCategories = categories
                print("[NCMDemo] ✅ 电台分类 [\(ms)ms] 数量=\(categories.count)")
            }
        } catch {
            print("[NCMDemo] ❌ 电台分类失败: \(error)")
        }
    }

    /// 获取节目排行榜
    private func fetchDJProgramToplist() async {
        let start = CFAbsoluteTimeGetCurrent()
        do {
            let resp = try await client.djProgramToplist(limit: 20)
            let ms = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
            if let toplist = resp.body["toplist"] as? [[String: Any]] {
                djProgramToplistData = toplist
                print("[NCMDemo] ✅ 节目排行 [\(ms)ms] 数量=\(toplist.count)")
            }
        } catch {
            print("[NCMDemo] ❌ 节目排行失败: \(error)")
        }
    }

    /// 获取电台节目列表
    func fetchDJPrograms(radioId: Int, radioName: String) async {
        isLoading = true
        selectedRadioName = radioName
        djProgramList = []
        let start = CFAbsoluteTimeGetCurrent()
        print("[NCMDemo] ➡️ 电台节目: id=\(radioId) \"\(radioName)\"")

        do {
            let resp = try await client.djProgram(rid: radioId, limit: 50)
            let ms = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
            if let programs = resp.body["programs"] as? [[String: Any]] {
                djProgramList = programs
                print("[NCMDemo] ✅ 电台节目 [\(ms)ms] 数量=\(programs.count)")
            }
        } catch {
            let ms = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
            errorMessage = "获取节目列表失败: \(error.localizedDescription)"
            print("[NCMDemo] ❌ 电台节目失败 [\(ms)ms] \(error)")
        }
        isLoading = false
    }

    // MARK: - 解灰测试

    /// 导入 JS 脚本（从文本）
    func importJSFromText() {
        let script = jsScriptInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !script.isEmpty else { return }
        let source = JSScriptSource(name: "JS音源", script: script)
        unblockSources.append(SourceItem(
            name: source.name,
            type: .jsScript,
            url: "",
            script: script
        ))
        jsScriptInput = ""
        print("[NCMDemo] 📦 导入 JS 音源: \(source.name)")
    }

    /// 导入 JS 脚本（从文件）
    func importJSFromFile(url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        do {
            let script = try String(contentsOf: url, encoding: .utf8)
            let source = JSScriptSource(name: url.deletingPathExtension().lastPathComponent, script: script)
            unblockSources.append(SourceItem(
                name: source.name,
                type: .jsScript,
                url: "",
                script: script
            ))
            print("[NCMDemo] 📦 导入 JS 文件: \(source.name) (\(url.lastPathComponent))")
        } catch {
            print("[NCMDemo] ❌ 读取 JS 文件失败: \(error)")
        }
    }

    /// 添加自定义地址音源
    func addURLSource(name: String, url: String, template: String?) {
        unblockSources.append(SourceItem(
            name: name,
            type: .httpUrl,
            url: url,
            script: "",
            urlTemplate: template
        ))
        print("[NCMDemo] 📦 添加自定义音源: \(name) -> \(url)")
    }

    /// 构建解灰管理器
    private func buildUnblockManager() -> UnblockManager {
        let manager = UnblockManager()
        for item in unblockSources where item.enabled {
            switch item.type {
            case .jsScript:
                let source = JSScriptSource(name: item.name, script: item.script)
                manager.register(source)
                print("[NCMDemo] 📦 注册 JS 音源: \(item.name)")
            case .httpUrl:
                let source = CustomURLSource(name: item.name, baseURL: item.url, urlTemplate: item.urlTemplate)
                manager.register(source)
                print("[NCMDemo] 📦 注册自定义音源: \(item.name) -> \(item.url)")
            }
        }
        return manager
    }

    /// 获取歌曲名称
    private func fetchSongName(id: Int) async -> (name: String?, artist: String?) {
        do {
            let resp = try await client.songDetail(ids: [id])
            if let songs = resp.body["songs"] as? [[String: Any]], let song = songs.first {
                let name = song["name"] as? String
                let artist = DemoViewModel.artistNames(from: song)
                return (name, artist)
            }
        } catch {
            print("[NCMDemo] ⚠️ 获取歌曲详情失败: \(error)")
        }
        return (nil, nil)
    }

    /// 单曲解灰测试 — 遍历所有音源的所有平台，展示全部结果
    func testUnblockSingle() async {
        guard let songId = Int(unblockSongId) else {
            unblockError = "请输入有效的歌曲 ID"
            return
        }
        isUnblockLoading = true
        unblockResult = nil
        unblockError = nil
        unblockSongName = ""
        unblockPlayStatus = ""
        unblockAllResults = []
        unblockLogs = []
        print("[NCMDemo] ➡️ 解灰测试: id=\(songId) 音质=\(unblockQuality)")

        let info = await fetchSongName(id: songId)
        if let name = info.name {
            unblockSongName = "\(name) - \(info.artist ?? "未知")"
        }

        let start = CFAbsoluteTimeGetCurrent()
        var allItems: [UnblockTestItem] = []

        for sourceItem in unblockSources where sourceItem.enabled {
            switch sourceItem.type {
            case .jsScript:
                // JS 音源：开启 testMode 遍历所有平台
                let source = JSScriptSource(name: sourceItem.name, script: sourceItem.script)
                source.testMode = true
                source.logHandler = { [weak self] msg in
                    DispatchQueue.main.async {
                        self?.unblockLogs.append(msg)
                    }
                }
                let _ = try? await source.match(
                    id: songId,
                    title: info.name,
                    artist: info.artist,
                    quality: unblockQuality
                )
                // 收集每个平台的结果
                for (platform, url) in source.testPlatformResults.sorted(by: { $0.key < $1.key }) {
                    if url.isEmpty {
                        allItems.append(UnblockTestItem(
                            sourceName: sourceItem.name,
                            platformKey: platform,
                            success: false,
                            detail: "未匹配到",
                            url: "",
                            duration: ""
                        ))
                    } else {
                        allItems.append(UnblockTestItem(
                            sourceName: sourceItem.name,
                            platformKey: platform,
                            success: true,
                            detail: url.count > 60 ? String(url.prefix(60)) + "..." : url,
                            url: url,
                            duration: ""
                        ))
                    }
                }
                // 如果不是洛雪格式（没有多平台），testPlatformResults 可能为空
                if source.testPlatformResults.isEmpty {
                    // 简单格式：直接调用一次
                    let simpleResult = try? await JSScriptSource(name: sourceItem.name, script: sourceItem.script)
                        .match(id: songId, title: info.name, artist: info.artist, quality: unblockQuality)
                    let url = simpleResult?.url ?? ""
                    allItems.append(UnblockTestItem(
                        sourceName: sourceItem.name,
                        platformKey: "",
                        success: !url.isEmpty,
                        detail: url.isEmpty ? "未匹配到" : (url.count > 60 ? String(url.prefix(60)) + "..." : url),
                        url: url,
                        duration: ""
                    ))
                }

            case .httpUrl:
                // 自定义地址音源：直接请求
                let source = CustomURLSource(name: sourceItem.name, baseURL: sourceItem.url, urlTemplate: sourceItem.urlTemplate)
                do {
                    let result = try await source.match(
                        id: songId,
                        title: info.name,
                        artist: info.artist,
                        quality: unblockQuality
                    )
                    allItems.append(UnblockTestItem(
                        sourceName: sourceItem.name,
                        platformKey: "",
                        success: !result.url.isEmpty,
                        detail: result.url.isEmpty ? "返回空 URL" : (result.url.count > 60 ? String(result.url.prefix(60)) + "..." : result.url),
                        url: result.url,
                        duration: ""
                    ))
                } catch {
                    allItems.append(UnblockTestItem(
                        sourceName: sourceItem.name,
                        platformKey: "",
                        success: false,
                        detail: error.localizedDescription,
                        url: "",
                        duration: ""
                    ))
                }
            }
        }

        let ms = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
        unblockAllResults = allItems

        let successCount = allItems.filter { $0.success }.count
        if successCount > 0 {
            // 取第一个成功的作为默认播放结果
            if let first = allItems.first(where: { $0.success }) {
                unblockResult = UnblockResult(url: first.url, quality: unblockQuality, platform: "\(first.sourceName)(\(first.platformKey))")
            }
            print("[NCMDemo] ✅ 解灰完成 [\(ms)ms] \(successCount)/\(allItems.count) 个平台成功")
        } else {
            unblockError = "所有音源/平台均未匹配到结果 (\(ms)ms)"
            print("[NCMDemo] ❌ 解灰失败 [\(ms)ms]")
        }
        isUnblockLoading = false
    }

    /// 全部音源对比测试
    func testUnblockAll() async {
        guard let songId = Int(unblockSongId) else {
            unblockError = "请输入有效的歌曲 ID"
            return
        }
        isUnblockAllLoading = true
        unblockAllResults = []
        print("[NCMDemo] ➡️ 全部音源对比: id=\(songId)")

        let info = await fetchSongName(id: songId)
        if let name = info.name {
            unblockSongName = "\(name) - \(info.artist ?? "未知")"
        }

        let manager = buildUnblockManager()
        let allResults = await manager.matchAll(
            id: songId,
            title: info.name,
            artist: info.artist,
            quality: unblockQuality
        )

        var items: [UnblockTestItem] = []
        for r in allResults {
            switch r.result {
            case .success(let res):
                if res.url.isEmpty {
                    items.append(UnblockTestItem(sourceName: r.source, platformKey: "", success: false, detail: "返回空 URL", url: "", duration: ""))
                } else {
                    items.append(UnblockTestItem(sourceName: r.source, platformKey: "", success: true, detail: "音质: \(res.quality) | \(res.url.prefix(60))...", url: res.url, duration: ""))
                }
            case .failure(let error):
                items.append(UnblockTestItem(sourceName: r.source, platformKey: "", success: false, detail: error.localizedDescription, url: "", duration: ""))
            }
        }
        unblockAllResults = items
        print("[NCMDemo] ✅ 对比完成: \(items.filter { $0.success }.count)/\(items.count) 成功")
        isUnblockAllLoading = false
    }

    /// 播放解灰结果
    func playUnblockResult() async {
        guard let result = unblockResult, !result.url.isEmpty else { return }
        if isUnblockPlaying {
            stopUnblockPlaying()
            return
        }
        guard let url = URL(string: result.url) else {
            unblockPlayStatus = "无效的播放 URL"
            return
        }
        print("[NCMDemo] ▶️ 播放解灰结果: \(result.url)")
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            let playerItem = AVPlayerItem(url: url)
            unblockPlayer = AVPlayer(playerItem: playerItem)
            unblockPlayer?.play()
            isUnblockPlaying = true
            unblockPlayStatus = "正在播放 (\(result.platform) \(result.quality))"
        } catch {
            unblockPlayStatus = "播放失败: \(error.localizedDescription)"
            print("[NCMDemo] ❌ 播放失败: \(error)")
        }
    }

    /// 停止解灰播放
    func stopUnblockPlaying() {
        unblockPlayer?.pause()
        unblockPlayer = nil
        isUnblockPlaying = false
        unblockPlayStatus = "已停止"
        print("[NCMDemo] ⏹ 停止解灰播放")
    }

    /// 播放指定 URL（从结果列表中选择播放）
    func playUrl(_ urlString: String, label: String = "") {
        stopUnblockPlaying()
        guard let url = URL(string: urlString) else {
            unblockPlayStatus = "无效的播放 URL"
            return
        }
        print("[NCMDemo] ▶️ 播放: \(label) \(urlString.prefix(60))")
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            let playerItem = AVPlayerItem(url: url)
            unblockPlayer = AVPlayer(playerItem: playerItem)
            unblockPlayer?.play()
            isUnblockPlaying = true
            unblockPlayStatus = "正在播放: \(label)"
        } catch {
            unblockPlayStatus = "播放失败: \(error.localizedDescription)"
            print("[NCMDemo] ❌ 播放失败: \(error)")
        }
    }

    // MARK: - 专辑

    func fetchNewAlbums() async {
        isLoading = true
        do {
            let resp = try await client.albumNew(limit: 20)
            if let albums = resp.body["albums"] as? [[String: Any]] {
                newAlbums = albums
                print("[NCMDemo] ✅ 新碟 \(albums.count) 张")
            }
        } catch {
            errorMessage = "获取新碟失败: \(error.localizedDescription)"
            print("[NCMDemo] ❌ 新碟失败: \(error)")
        }
        isLoading = false
    }

    func fetchNewestAlbums() async {
        isLoading = true
        do {
            let resp = try await client.albumNewest()
            if let albums = resp.body["albums"] as? [[String: Any]] {
                newestAlbums = albums
                print("[NCMDemo] ✅ 最新专辑 \(albums.count) 张")
            }
        } catch {
            errorMessage = "获取最新专辑失败: \(error.localizedDescription)"
            print("[NCMDemo] ❌ 最新专辑失败: \(error)")
        }
        isLoading = false
    }

    func fetchAlbumDetail(id: Int, name: String) async {
        isLoading = true
        albumDetailName = name
        albumTracks = []
        do {
            let resp = try await client.album(id: id)
            if let songs = resp.body["songs"] as? [[String: Any]] {
                albumTracks = songs
                print("[NCMDemo] ✅ 专辑详情 \(songs.count) 首")
            }
        } catch {
            errorMessage = "获取专辑详情失败: \(error.localizedDescription)"
            print("[NCMDemo] ❌ 专辑详情失败: \(error)")
        }
        isLoading = false
    }

    // MARK: - 歌手

    func fetchArtistInfo() async {
        guard let id = Int(artistIdInput) else { return }
        isLoading = true
        artistName = ""
        artistAlias = ""
        artistFansCount = 0
        artistTopSongs = []
        artistAlbums = []
        simiArtists = []

        // 并发加载详情、热门歌曲、专辑、相似歌手
        async let detailTask: () = _fetchArtistDetail(id: id)
        async let topTask: () = _fetchArtistTopSong(id: id)
        async let albumTask: () = _fetchArtistAlbum(id: id)
        async let simiTask: () = _fetchSimiArtist(id: id)
        _ = await (detailTask, topTask, albumTask, simiTask)
        isLoading = false
    }

    private func _fetchArtistDetail(id: Int) async {
        do {
            let resp = try await client.artistDetail(id: id)
            if let data = resp.body["data"] as? [String: Any],
               let artist = data["artist"] as? [String: Any] {
                artistName = artist["name"] as? String ?? ""
                let aliases = artist["alias"] as? [String] ?? []
                artistAlias = aliases.joined(separator: " / ")
                artistFansCount = (data["secondaryExpertIdentiy"] as? [String: Any])?["fansCount"] as? Int ?? 0
                print("[NCMDemo] ✅ 歌手: \(artistName)")
            }
        } catch {
            print("[NCMDemo] ❌ 歌手详情失败: \(error)")
        }
    }

    private func _fetchArtistTopSong(id: Int) async {
        do {
            let resp = try await client.artistTopSong(id: id)
            if let songs = resp.body["songs"] as? [[String: Any]] {
                artistTopSongs = songs
                print("[NCMDemo] ✅ 热门歌曲 \(songs.count) 首")
            }
        } catch {
            print("[NCMDemo] ❌ 热门歌曲失败: \(error)")
        }
    }

    private func _fetchArtistAlbum(id: Int) async {
        do {
            let resp = try await client.artistAlbum(id: id, limit: 20)
            if let albums = resp.body["hotAlbums"] as? [[String: Any]] {
                artistAlbums = albums
                print("[NCMDemo] ✅ 歌手专辑 \(albums.count) 张")
            }
        } catch {
            print("[NCMDemo] ❌ 歌手专辑失败: \(error)")
        }
    }

    private func _fetchSimiArtist(id: Int) async {
        do {
            let resp = try await client.simiArtist(id: id)
            if let artists = resp.body["artists"] as? [[String: Any]] {
                simiArtists = artists
                print("[NCMDemo] ✅ 相似歌手 \(artists.count)")
            }
        } catch {
            print("[NCMDemo] ❌ 相似歌手失败: \(error)")
        }
    }

    func fetchArtistList() async {
        isLoading = true
        do {
            let resp = try await client.artistList(area: .zh, type: .male, limit: 30)
            if let artists = resp.body["artists"] as? [[String: Any]] {
                artistListData = artists
                print("[NCMDemo] ✅ 歌手列表 \(artists.count)")
            }
        } catch {
            errorMessage = "获取歌手列表失败: \(error.localizedDescription)"
            print("[NCMDemo] ❌ 歌手列表失败: \(error)")
        }
        isLoading = false
    }

    // MARK: - MV / 视频

    func fetchMvAll() async {
        isLoading = true
        do {
            let resp = try await client.mvAll(limit: 20)
            if let data = resp.body["data"] as? [[String: Any]] {
                mvList = data
                print("[NCMDemo] ✅ MV 列表 \(data.count)")
            }
        } catch {
            errorMessage = "获取 MV 列表失败: \(error.localizedDescription)"
            print("[NCMDemo] ❌ MV 列表失败: \(error)")
        }
        isLoading = false
    }

    func fetchMvDetail(id: Int) async {
        isLoading = true
        mvDetailName = ""
        mvDetailArtist = ""
        mvDetailUrl = ""
        mvDetailPlayCount = 0
        mvDetailCommentCount = 0
        mvDetailLikeCount = 0
        do {
            let resp = try await client.mvDetail(mvid: id)
            if let data = resp.body["data"] as? [String: Any] {
                mvDetailName = data["name"] as? String ?? ""
                mvDetailArtist = (data["artists"] as? [[String: Any]])?.first?["name"] as? String ?? ""
                mvDetailPlayCount = data["playCount"] as? Int ?? 0
                mvDetailCommentCount = data["commentCount"] as? Int ?? 0
                mvDetailLikeCount = data["likeCount"] as? Int ?? 0
            }
            // 获取播放链接
            let urlResp = try await client.mvUrl(id: id)
            if let data = urlResp.body["data"] as? [String: Any] {
                mvDetailUrl = data["url"] as? String ?? ""
            }
            print("[NCMDemo] ✅ MV 详情: \(mvDetailName)")
        } catch {
            print("[NCMDemo] ❌ MV 详情失败: \(error)")
        }
        isLoading = false
    }

    func fetchMvFirst() async {
        isLoading = true
        do {
            let resp = try await client.mvFirst(limit: 20)
            if let data = resp.body["data"] as? [[String: Any]] {
                mvFirstList = data
                print("[NCMDemo] ✅ 最新 MV \(data.count)")
            }
        } catch {
            print("[NCMDemo] ❌ 最新 MV 失败: \(error)")
        }
        isLoading = false
    }

    func fetchMvExclusive() async {
        isLoading = true
        do {
            let resp = try await client.mvExclusiveRcmd(limit: 20)
            if let data = resp.body["data"] as? [[String: Any]] {
                mvExclusiveList = data
                print("[NCMDemo] ✅ 网易出品 MV \(data.count)")
            }
        } catch {
            print("[NCMDemo] ❌ 网易出品 MV 失败: \(error)")
        }
        isLoading = false
    }

    // MARK: - 评论

    private var commentType: CommentType {
        switch commentTypeIndex {
        case 0: return .song
        case 1: return .mv
        case 2: return .playlist
        case 3: return .album
        default: return .song
        }
    }

    func fetchComments() async {
        guard let id = Int(commentResourceId) else { return }
        isLoading = true
        isHotComments = false
        commentList = []
        commentTotal = 0
        do {
            let resp = try await client.commentNew(type: commentType, id: id, pageSize: 20)
            if let data = resp.body["data"] as? [String: Any] {
                commentTotal = data["totalCount"] as? Int ?? 0
                if let comments = data["comments"] as? [[String: Any]] {
                    commentList = comments
                }
            }
            print("[NCMDemo] ✅ 评论 \(commentList.count) 条 / 共 \(commentTotal)")
        } catch {
            errorMessage = "获取评论失败: \(error.localizedDescription)"
            print("[NCMDemo] ❌ 评论失败: \(error)")
        }
        isLoading = false
    }

    func fetchHotComments() async {
        guard let id = Int(commentResourceId) else { return }
        isLoading = true
        isHotComments = true
        commentList = []
        do {
            let resp = try await client.commentHot(type: commentType, id: id, limit: 20)
            if let comments = resp.body["hotComments"] as? [[String: Any]] {
                commentList = comments
                commentTotal = resp.body["total"] as? Int ?? 0
            }
            print("[NCMDemo] ✅ 热评 \(commentList.count) 条")
        } catch {
            errorMessage = "获取热评失败: \(error.localizedDescription)"
            print("[NCMDemo] ❌ 热评失败: \(error)")
        }
        isLoading = false
    }

    // MARK: - 用户

    func fetchUserInfo() async {
        guard let uid = Int(userIdInput) else { return }
        isLoading = true
        userInfoName = ""
        userInfoSignature = ""
        userPlaylists = []
        do {
            let resp = try await client.userDetail(uid: uid)
            if let profile = resp.body["profile"] as? [String: Any] {
                userInfoName = profile["nickname"] as? String ?? ""
                userInfoSignature = profile["signature"] as? String ?? ""
                userInfoFollows = profile["follows"] as? Int ?? 0
                userInfoFolloweds = profile["followeds"] as? Int ?? 0
            }
            userInfoLevel = resp.body["level"] as? Int ?? 0
            print("[NCMDemo] ✅ 用户: \(userInfoName)")

            // 同时获取歌单
            let plResp = try await client.userPlaylist(uid: uid, limit: 30)
            if let playlist = plResp.body["playlist"] as? [[String: Any]] {
                userPlaylists = playlist
                print("[NCMDemo] ✅ 用户歌单 \(playlist.count)")
            }
        } catch {
            errorMessage = "获取用户信息失败: \(error.localizedDescription)"
            print("[NCMDemo] ❌ 用户信息失败: \(error)")
        }
        isLoading = false
    }

    func fetchCurrentAccount() async {
        isLoading = true
        do {
            let resp = try await client.userAccount()
            if let account = resp.body["account"] as? [String: Any] {
                let id = account["id"] as? Int ?? 0
                let vipType = account["vipType"] as? Int ?? 0
                accountInfoText = "账号 ID: \(id) | VIP 类型: \(vipType)"
                print("[NCMDemo] ✅ 账号信息: \(accountInfoText)")
            } else {
                accountInfoText = "未登录"
            }
        } catch {
            accountInfoText = "获取失败: \(error.localizedDescription)"
            print("[NCMDemo] ❌ 账号信息失败: \(error)")
        }
        isLoading = false
    }

    func fetchUserLevel() async {
        isLoading = true
        do {
            let resp = try await client.userLevel()
            if let data = resp.body["data"] as? [String: Any] {
                let level = data["level"] as? Int ?? 0
                accountInfoText = "等级: Lv.\(level)"
                print("[NCMDemo] ✅ 等级: Lv.\(level)")
            }
        } catch {
            accountInfoText = "获取等级失败: \(error.localizedDescription)"
            print("[NCMDemo] ❌ 等级失败: \(error)")
        }
        isLoading = false
    }

    func fetchUserSubcount() async {
        isLoading = true
        do {
            let resp = try await client.userSubcount()
            let artistCount = resp.body["artistCount"] as? Int ?? 0
            let albumCount = resp.body["subPlaylistCount"] as? Int ?? 0
            let djCount = resp.body["djRadioCount"] as? Int ?? 0
            accountInfoText = "收藏歌手: \(artistCount) | 歌单: \(albumCount) | 电台: \(djCount)"
            print("[NCMDemo] ✅ 订阅数量")
        } catch {
            accountInfoText = "获取订阅数量失败: \(error.localizedDescription)"
            print("[NCMDemo] ❌ 订阅数量失败: \(error)")
        }
        isLoading = false
    }

    func fetchUserRecord() async {
        guard let uid = Int(userIdInput) else { return }
        isLoading = true
        userRecordSongs = []
        do {
            let resp = try await client.userRecord(uid: uid, type: .weekly)
            if let weekData = resp.body["weekData"] as? [[String: Any]] {
                userRecordSongs = weekData
                print("[NCMDemo] ✅ 听歌记录 \(weekData.count) 首")
            } else if let allData = resp.body["allData"] as? [[String: Any]] {
                userRecordSongs = allData
                print("[NCMDemo] ✅ 听歌记录 \(allData.count) 首")
            }
        } catch {
            errorMessage = "获取听歌记录失败: \(error.localizedDescription)"
            print("[NCMDemo] ❌ 听歌记录失败: \(error)")
        }
        isLoading = false
    }

    // MARK: - 推荐

    func fetchPersonalized() async {
        isLoading = true
        do {
            let resp = try await client.personalized(limit: 20)
            if let result = resp.body["result"] as? [[String: Any]] {
                personalizedPlaylists = result
                print("[NCMDemo] ✅ 推荐歌单 \(result.count)")
            }
        } catch {
            errorMessage = "获取推荐歌单失败: \(error.localizedDescription)"
            print("[NCMDemo] ❌ 推荐歌单失败: \(error)")
        }
        isLoading = false
    }

    func fetchPersonalizedNewsong() async {
        isLoading = true
        do {
            let resp = try await client.personalizedNewsong(limit: 20)
            if let result = resp.body["result"] as? [[String: Any]] {
                personalizedSongs = result
                print("[NCMDemo] ✅ 推荐新歌 \(result.count)")
            } else if let data = resp.body["data"] as? [[String: Any]] {
                personalizedSongs = data
                print("[NCMDemo] ✅ 推荐新歌 \(data.count)")
            }
        } catch {
            errorMessage = "获取推荐新歌失败: \(error.localizedDescription)"
            print("[NCMDemo] ❌ 推荐新歌失败: \(error)")
        }
        isLoading = false
    }

    func fetchDailyRecommendSongs() async {
        isLoading = true
        do {
            let resp = try await client.recommendSongs()
            if let data = resp.body["data"] as? [String: Any],
               let songs = data["dailySongs"] as? [[String: Any]] {
                dailyRecommendSongs = songs
                print("[NCMDemo] ✅ 每日推荐 \(songs.count) 首")
            }
        } catch {
            errorMessage = "获取每日推荐失败（需登录）: \(error.localizedDescription)"
            print("[NCMDemo] ❌ 每日推荐失败: \(error)")
        }
        isLoading = false
    }

    func fetchDailyRecommendResource() async {
        isLoading = true
        do {
            let resp = try await client.recommendResource()
            if let recommend = resp.body["recommend"] as? [[String: Any]] {
                personalizedPlaylists = recommend
                print("[NCMDemo] ✅ 每日推荐歌单 \(recommend.count)")
            }
        } catch {
            errorMessage = "获取每日推荐歌单失败（需登录）: \(error.localizedDescription)"
            print("[NCMDemo] ❌ 每日推荐歌单失败: \(error)")
        }
        isLoading = false
    }

    func fetchPersonalFm() async {
        isLoading = true
        do {
            let resp = try await client.personalFm()
            if let data = resp.body["data"] as? [[String: Any]] {
                personalFmSongs = data
                print("[NCMDemo] ✅ 私人 FM \(data.count) 首")
            }
        } catch {
            errorMessage = "获取私人 FM 失败（需登录）: \(error.localizedDescription)"
            print("[NCMDemo] ❌ 私人 FM 失败: \(error)")
        }
        isLoading = false
    }

    // MARK: - 云盘

    func fetchUserCloud() async {
        isLoading = true
        do {
            let resp = try await client.userCloud(limit: 50)
            if let data = resp.body["data"] as? [[String: Any]] {
                cloudSongs = data
                cloudSongCount = resp.body["count"] as? Int ?? data.count
                print("[NCMDemo] ✅ 云盘歌曲 \(data.count) / \(cloudSongCount)")
            }
        } catch {
            errorMessage = "获取云盘失败（需登录）: \(error.localizedDescription)"
            print("[NCMDemo] ❌ 云盘失败: \(error)")
        }
        isLoading = false
    }

    // MARK: - VIP / 云贝

    func fetchVipInfo() async {
        isLoading = true
        do {
            let resp = try await client.vipInfo()
            print("[NCMDemo] VIP 原始响应: \(resp.body)")
            let code = resp.body["code"] as? Int ?? 0
            if code != 200 {
                vipInfoText = "请求失败 code=\(code)，请确认已登录"
            } else if let data = resp.body["data"] as? [String: Any] {
                // 尝试多种字段名
                let vipLevel = data["redVipLevel"] as? Int
                    ?? data["vipLevel"] as? Int
                    ?? data["level"] as? Int ?? 0
                let expireTime = data["redVipExpireTime"] as? Int
                    ?? data["expireTime"] as? Int ?? 0
                let _ = data["dynamicIconUrl"] as? String ?? ""
                let associator = data["associator"] as? [String: Any]
                let musicPackage = data["musicPackage"] as? [String: Any]

                var parts: [String] = []
                parts.append("VIP 等级: \(vipLevel)")
                if expireTime > 0 {
                    parts.append("到期: \(DemoViewModel.formatTimestamp(expireTime))")
                }
                if let assoc = associator, let aExpire = assoc["expireTime"] as? Int, aExpire > 0 {
                    parts.append("黑胶到期: \(DemoViewModel.formatTimestamp(aExpire))")
                }
                if let mp = musicPackage, let mpExpire = mp["expireTime"] as? Int, mpExpire > 0 {
                    parts.append("音乐包到期: \(DemoViewModel.formatTimestamp(mpExpire))")
                }
                vipInfoText = parts.joined(separator: "\n")
                print("[NCMDemo] ✅ VIP 信息: \(vipInfoText)")
            } else {
                vipInfoText = "未获取到 VIP 信息（可能未登录）"
            }
        } catch {
            vipInfoText = "获取 VIP 信息失败: \(error.localizedDescription)"
            print("[NCMDemo] ❌ VIP 信息失败: \(error)")
        }
        isLoading = false
    }

    func fetchVipGrowthpoint() async {
        isLoading = true
        do {
            let resp = try await client.vipGrowthpoint()
            print("[NCMDemo] 成长值原始响应 keys: \(resp.body.keys)")
            let code = resp.body["code"] as? Int ?? 0
            if code != 200 {
                vipGrowthText = "请求失败 code=\(code)，请确认已登录"
            } else if let data = resp.body["data"] as? [String: Any] {
                // 成长值在 data.userLevel.growthPoint
                let userLevel = data["userLevel"] as? [String: Any]
                let point = userLevel?["growthPoint"] as? Int
                    ?? data["growthPoint"] as? Int
                    ?? data["currentGrowthPoint"] as? Int ?? 0
                let level = userLevel?["level"] as? Int ?? data["level"] as? Int ?? 0
                let levelName = userLevel?["levelName"] as? String ?? ""
                let maxLevel = userLevel?["maxLevel"] as? Bool ?? false
                var text = "成长值: \(point)"
                if !levelName.isEmpty { text += " | \(levelName)" }
                else if level > 0 { text += " | Lv.\(level)" }
                if maxLevel { text += " (满级)" }
                vipGrowthText = text
                print("[NCMDemo] ✅ 成长值: \(point)")
            } else {
                vipGrowthText = "未获取到成长值数据"
            }
        } catch {
            vipGrowthText = "获取成长值失败: \(error.localizedDescription)"
            print("[NCMDemo] ❌ 成长值失败: \(error)")
        }
        isLoading = false
    }

    func fetchVipTasks() async {
        isLoading = true
        do {
            let resp = try await client.vipTasks()
            print("[NCMDemo] VIP 任务原始响应 keys: \(resp.body.keys)")
            let code = resp.body["code"] as? Int ?? 0
            if code != 200 {
                errorMessage = "请求失败 code=\(code)，请确认已登录"
            } else if let data = resp.body["data"] as? [String: Any] {
                // taskList 是分组数组，每组有 taskItems 子数组，需要展平
                if let groups = data["taskList"] as? [[String: Any]] {
                    var allTasks: [[String: Any]] = []
                    for group in groups {
                        if let items = group["taskItems"] as? [[String: Any]] {
                            allTasks.append(contentsOf: items)
                        } else {
                            // 分组本身没有 taskItems，当作单个任务
                            allTasks.append(group)
                        }
                    }
                    vipTaskList = allTasks
                } else if let tasks = data["list"] as? [[String: Any]] {
                    vipTaskList = tasks
                } else if let tasks = data["tasks"] as? [[String: Any]] {
                    vipTaskList = tasks
                } else {
                    for (_, value) in data {
                        if let arr = value as? [[String: Any]], !arr.isEmpty {
                            vipTaskList = arr
                            break
                        }
                    }
                }
                print("[NCMDemo] ✅ VIP 任务 \(vipTaskList.count)")
            } else if let data = resp.body["data"] as? [[String: Any]] {
                vipTaskList = data
                print("[NCMDemo] ✅ VIP 任务 \(data.count)")
            } else {
                errorMessage = "未获取到 VIP 任务数据"
            }
        } catch {
            errorMessage = "获取 VIP 任务失败: \(error.localizedDescription)"
            print("[NCMDemo] ❌ VIP 任务失败: \(error)")
        }
        isLoading = false
    }

    func fetchYunbeiInfo() async {
        isLoading = true
        do {
            let resp = try await client.yunbei()
            print("[NCMDemo] 云贝原始响应: \(resp.body)")
            let code = resp.body["code"] as? Int ?? 0
            if code != 200 {
                yunbeiInfoText = "请求失败 code=\(code)，请确认已登录"
            } else {
                let point = resp.body["point"] as? Int ?? 0
                let data = resp.body["data"] as? [String: Any]
                let balance = data?["balance"] as? Int ?? point
                yunbeiInfoText = "云贝余额: \(balance > 0 ? balance : point)"
                print("[NCMDemo] ✅ 云贝: \(balance > 0 ? balance : point)")
            }
        } catch {
            yunbeiInfoText = "获取云贝失败: \(error.localizedDescription)"
            print("[NCMDemo] ❌ 云贝失败: \(error)")
        }
        isLoading = false
    }

    func fetchYunbeiTasks() async {
        isLoading = true
        do {
            let resp = try await client.yunbeiTasks()
            print("[NCMDemo] 云贝任务原始响应 keys: \(resp.body.keys)")
            let code = resp.body["code"] as? Int ?? 0
            if code != 200 {
                errorMessage = "请求失败 code=\(code)，请确认已登录"
            } else if let data = resp.body["data"] as? [[String: Any]] {
                yunbeiTaskList = data
                print("[NCMDemo] ✅ 云贝任务 \(data.count)")
            } else if let data = resp.body["data"] as? [String: Any] {
                // 可能嵌套在 data.list 或 data.tasks 中
                if let list = data["list"] as? [[String: Any]] {
                    yunbeiTaskList = list
                } else if let tasks = data["tasks"] as? [[String: Any]] {
                    yunbeiTaskList = tasks
                }
                print("[NCMDemo] ✅ 云贝任务 \(yunbeiTaskList.count)")
            } else {
                errorMessage = "未获取到云贝任务数据"
            }
        } catch {
            errorMessage = "获取云贝任务失败: \(error.localizedDescription)"
            print("[NCMDemo] ❌ 云贝任务失败: \(error)")
        }
        isLoading = false
    }

    // MARK: - 杂项

    func fetchStyleList() async {
        isLoading = true
        do {
            let resp = try await client.styleList()
            if let data = resp.body["data"] as? [[String: Any]] {
                styleListData = data
                print("[NCMDemo] ✅ 曲风列表 \(data.count)")
            } else if let tags = resp.body["tags"] as? [[String: Any]] {
                styleListData = tags
                print("[NCMDemo] ✅ 曲风列表 \(tags.count)")
            }
        } catch {
            errorMessage = "获取曲风列表失败: \(error.localizedDescription)"
            print("[NCMDemo] ❌ 曲风列表失败: \(error)")
        }
        isLoading = false
    }

    func fetchHomepage() async {
        isLoading = true
        do {
            let resp = try await client.homepageBlockPage()
            if let data = resp.body["data"] as? [String: Any],
               let blocks = data["blocks"] as? [[String: Any]] {
                homepageInfo = "首页 Block: \(blocks.count) 个模块"
                print("[NCMDemo] ✅ 首页 \(blocks.count) 个模块")
            }
        } catch {
            homepageInfo = "获取首页失败: \(error.localizedDescription)"
            print("[NCMDemo] ❌ 首页失败: \(error)")
        }
        isLoading = false
    }

    func fetchDragonBall() async {
        isLoading = true
        do {
            let resp = try await client.homepageDragonBall()
            if let data = resp.body["data"] as? [[String: Any]] {
                homepageInfo = "入口图标: \(data.count) 个"
                print("[NCMDemo] ✅ 入口图标 \(data.count)")
            }
        } catch {
            homepageInfo = "获取入口图标失败: \(error.localizedDescription)"
            print("[NCMDemo] ❌ 入口图标失败: \(error)")
        }
        isLoading = false
    }

    func fetchSigninProgress() async {
        isLoading = true
        do {
            let resp = try await client.signinProgress()
            if let data = resp.body["data"] as? [String: Any] {
                let todaySigned = data["todaySignedIn"] as? Bool ?? false
                signinInfo = "今日签到: \(todaySigned ? "已签到 ✅" : "未签到")"
                print("[NCMDemo] ✅ 签到进度")
            }
        } catch {
            signinInfo = "获取签到进度失败: \(error.localizedDescription)"
            print("[NCMDemo] ❌ 签到进度失败: \(error)")
        }
        isLoading = false
    }

    func fetchCountriesCode() async {
        isLoading = true
        do {
            let resp = try await client.countriesCodeList()
            if let data = resp.body["data"] as? [[String: Any]] {
                countriesCodeCount = data.count
                print("[NCMDemo] ✅ 国家编码 \(data.count)")
            } else if let countryList = resp.body["countryList"] as? [[String: Any]] {
                var total = 0
                for group in countryList {
                    if let list = group["countryList"] as? [[String: Any]] {
                        total += list.count
                    }
                }
                countriesCodeCount = total
                print("[NCMDemo] ✅ 国家编码 \(total)")
            }
        } catch {
            errorMessage = "获取国家编码失败: \(error.localizedDescription)"
            print("[NCMDemo] ❌ 国家编码失败: \(error)")
        }
        isLoading = false
    }

    func fetchRecentListenList() async {
        isLoading = true
        do {
            let resp = try await client.recentListenList()
            if let data = resp.body["data"] as? [String: Any],
               let list = data["list"] as? [[String: Any]] {
                recentListenInfo = "最近听歌: \(list.count) 首"
                print("[NCMDemo] ✅ 最近听歌 \(list.count)")
            }
        } catch {
            recentListenInfo = "获取失败（需登录）: \(error.localizedDescription)"
            print("[NCMDemo] ❌ 最近听歌失败: \(error)")
        }
        isLoading = false
    }

    func fetchSimiSong() async {
        guard let id = Int(simiSongIdInput) else { return }
        isLoading = true
        simiResults = []
        do {
            let resp = try await client.simiSong(id: id)
            if let songs = resp.body["songs"] as? [[String: Any]] {
                simiResults = songs
                print("[NCMDemo] ✅ 相似歌曲 \(songs.count)")
            }
        } catch {
            errorMessage = "获取相似歌曲失败: \(error.localizedDescription)"
            print("[NCMDemo] ❌ 相似歌曲失败: \(error)")
        }
        isLoading = false
    }

    func fetchSimiPlaylist() async {
        guard let id = Int(simiSongIdInput) else { return }
        isLoading = true
        simiResults = []
        do {
            let resp = try await client.simiPlaylist(id: id)
            if let playlists = resp.body["playlists"] as? [[String: Any]] {
                simiResults = playlists
                print("[NCMDemo] ✅ 相似歌单 \(playlists.count)")
            }
        } catch {
            errorMessage = "获取相似歌单失败: \(error.localizedDescription)"
            print("[NCMDemo] ❌ 相似歌单失败: \(error)")
        }
        isLoading = false
    }

    // MARK: - 辅助方法

    static func artistNames(from song: [String: Any]) -> String {
        guard let artists = song["ar"] as? [[String: Any]] ?? song["artists"] as? [[String: Any]] else {
            return "未知歌手"
        }
        return artists.compactMap { $0["name"] as? String }.joined(separator: " / ")
    }

    static func albumName(from song: [String: Any]) -> String {
        if let al = song["al"] as? [String: Any] {
            return al["name"] as? String ?? ""
        }
        if let album = song["album"] as? [String: Any] {
            return album["name"] as? String ?? ""
        }
        return ""
    }

    /// 格式化时间戳为可读字符串
    static func formatTimestamp(_ ms: Int) -> String {
        guard ms > 0 else { return "" }
        let date = Date(timeIntervalSince1970: Double(ms) / 1000.0)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}
