# NeteaseCloudMusicAPI-Swift 文档

基于 [NeteaseCloudMusicApi](https://github.com/Binaryify/NeteaseCloudMusicApi) 封装 362 个接口的原生 Swift SDK。

## 使用须知

!> 本项目仅供学习使用，请尊重版权，请勿利用此项目从事商业行为或进行破坏版权行为

!> 不要频繁调用登录接口，否则可能会被风控。登录状态还存在就不要重复调用登录接口

!> 部分接口如登录接口不能调用太频繁，否则可能会触发 503 错误或 IP 高频错误。建议做好请求频率控制

!> 由于网易限制，在国外服务器或部分国内云服务上使用会受到限制（如 `460 cheating` 异常）。建议在国内网络环境下部署后端服务

!> 建议使用二维码登录或验证码登录，密码登录可能触发安全验证

!> 图片 URL 加上 `?param=宽y高` 可控制图片尺寸，如 `http://p4.music.126.net/xxx.jpg?param=200y200`

!> 分页接口返回字段里有 `more`，`more` 为 `true` 则表示有下一页

### 关于后端代理

本 SDK 需要配合 [NeteaseCloudMusicApi](https://github.com/Binaryify/NeteaseCloudMusicApi) 后端服务使用。请求发送到你部署的 Node 后端，由后端处理加密和转发。请先自行部署后端服务，然后通过 `NCMClient(serverUrl:)` 初始化客户端。

### 关于直连加密

SDK 也支持不部署后端，客户端直接加密请求ncm服务器：

```swift
// 直连模式，不传 serverUrl
let client = NCMClient()
```

直连模式下 SDK 会自动选择加密方式（WeAPI / EAPI / LinuxAPI），与官方客户端行为一致。适合不想部署后端的场景，但部分功能可能受网易风控限制。

### iOS ATS 注意事项

!> ncm的部分资源 URL（如歌曲播放链接 `http://m*.music.126.net`）使用 HTTP 协议。iOS 默认的 App Transport Security (ATS) 会阻止 HTTP 请求，导致播放失败。

如果仅使用ncm官方接口，可以按域名添加例外：

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSExceptionDomains</key>
    <dict>
        <key>music.126.net</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
            <key>NSIncludesSubdomains</key>
            <true/>
        </dict>
    </dict>
</dict>
```

如果使用直连模式，还需要添加 `163.com` 域名的例外（直连请求走 `interface.music.163.com`，虽然是 HTTPS，但部分重定向可能涉及 HTTP）。

!> 如果使用第三方解灰模块，由于导入的 JS 音源脚本可能请求任意 HTTP 域名（域名不可预知），建议直接允许所有 HTTP 请求：

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

### 关于 Cookie

- 登录成功后，SDK 会自动管理 Cookie，后续请求会自动携带
- 也可以手动通过 `client.setCookie("MUSIC_U=xxx; __csrf=xxx")` 设置 Cookie
- 需要登录的接口（如每日推荐、用户歌单等），未登录调用会返回错误码 301
- Cookie 有效期有限，过期后需要重新登录

### 关于加密

SDK 内置四种加密模式，与官方客户端一致：

| 模式 | 说明 | 使用场景 |
|------|------|----------|
| WeAPI | 双重 AES-CBC + RSA | 大部分 Web 端接口 |
| EAPI | AES-ECB + 自定义 Header | 客户端专属接口（如歌曲下载） |
| LinuxAPI | AES-ECB (Linux 密钥) | Linux 客户端接口 |
| 明文 | 不加密，直接 POST JSON | 后端代理模式 |

后端代理模式下使用明文模式，由后端处理加密。

### 关于返回值

所有接口返回 `APIResponse` 类型：

```swift
struct APIResponse {
    let status: Int      // HTTP 状态码
    let body: [String: Any]  // 响应 JSON
    let cookie: [String]     // 响应 Cookie
}
```

- `body` 中通常包含 `code` 字段，`200` 表示成功
- ncm的错误码：`301` 未登录、`400` 参数错误、`502` 服务器错误、`460` IP 异常

### 关于平台支持

| 平台 | 最低版本 | 说明 |
|------|----------|------|
| iOS | 15.0 | iPhone / iPad |
| macOS | 12.0 | 原生 + Mac Catalyst |
| tvOS | 15.0 | Apple TV |
| watchOS | 8.0 | Apple Watch |

---

## 安装

### Swift Package Manager

在 `Package.swift` 中添加依赖：

```swift
dependencies: [
    .package(url: "https://github.com/your-repo/NeteaseCloudMusicAPI-Swift.git", from: "1.0.0")
]
```

或在 Xcode 中：`File` → `Add Package Dependencies` → 输入仓库地址。

## 快速开始

### 两种模式

| 模式 | 初始化方式 | 说明 |
|------|-----------|------|
| 后端代理 | `NCMClient(serverUrl: "http://localhost:3000")` | 请求发送到你部署的 Node 后端 |
| 直连加密 | `NCMClient()` | 客户端直接连接ncm服务器 |

### 后端代理模式

首先部署 [NeteaseCloudMusicApi](https://github.com/Binaryify/NeteaseCloudMusicApi) 后端服务，然后：

```swift
import NeteaseCloudMusicAPI

// 创建客户端，指向你的后端服务
let client = NCMClient(serverUrl: "http://localhost:3000")

// 搜索歌曲
let result = try await client.cloudsearch(keywords: "周杰伦")
print(result.body)

// 获取歌曲详情
let detail = try await client.songDetail(ids: [347230])
print(detail.body)

// 获取歌词
let lyric = try await client.lyric(id: 347230)
print(lyric.body)
```

### 直连加密模式

无需部署后端，客户端直接加密请求ncm服务器：

```swift
import NeteaseCloudMusicAPI

// 直连模式，不传 serverUrl
let client = NCMClient()

// 所有接口用法完全一致
let result = try await client.cloudsearch(keywords: "周杰伦")
print(result.body)
```

> 直连模式下 SDK 会自动选择加密方式（WeAPI / EAPI / LinuxAPI），与官方客户端行为一致。适合不想部署后端的场景，但部分功能可能受网易风控限制。

## 登录与 Cookie

```swift
let client = NCMClient(serverUrl: "http://localhost:3000")

// 方式一：手机号登录
let loginResult = try await client.loginCellphone(
    phone: "13800138000",
    password: "your_password"
)

// 方式二：二维码登录
let qrKey = try await client.loginQrKey()
let key = qrKey.body["unikey"] as! String
let qrUrl = try await client.loginQrCreate(key: key)
// 展示二维码，等待用户扫码后轮询
let checkResult = try await client.loginQrCheck(key: key)

// 方式三：直接设置 Cookie
client.setCookie("MUSIC_U=xxx; __csrf=xxx")

// 查看当前 Cookie
print(client.currentCookies)
```

!> 不要频繁调用登录接口，否则可能会被风控。登录状态还存在就不要重复调用登录接口。

!> 建议使用二维码登录或验证码登录，密码登录可能触发安全验证。

---


## 搜索

### 云搜索

说明：搜索歌曲、专辑、歌手、歌单、MV、歌词等，结果更全面

**方法签名：**

```swift
func cloudsearch(keywords: String, type: SearchType = .single, limit: Int = 30, offset: Int = 0) async throws -> APIResponse
```

**参数：**

| 参数 | 类型 | 必选 | 说明 |
|------|------|------|------|
| keywords | String | ✅ | 搜索关键词 |
| type | SearchType | ❌ | 搜索类型，默认 `.single`（单曲） |
| limit | Int | ❌ | 每页数量，默认 30 |
| offset | Int | ❌ | 偏移量，默认 0 |

**调用例子：**

```swift
let result = try await client.cloudsearch(keywords: "周杰伦")
let result = try await client.cloudsearch(keywords: "周杰伦", type: .album, limit: 10)
```

### 搜索（旧版）

说明：旧版搜索接口

**方法签名：**

```swift
func search(keywords: String, type: SearchType = .single, limit: Int = 30, offset: Int = 0) async throws -> APIResponse
```

**参数：**

| 参数 | 类型 | 必选 | 说明 |
|------|------|------|------|
| keywords | String | ✅ | 搜索关键词 |
| type | SearchType | ❌ | 搜索类型，默认 `.single` |
| limit | Int | ❌ | 每页数量，默认 30 |
| offset | Int | ❌ | 偏移量，默认 0 |

**调用例子：**

```swift
let result = try await client.search(keywords: "晴天")
```

### 默认搜索关键词

说明：获取搜索框默认关键词

**方法签名：**

```swift
func searchDefault() async throws -> APIResponse
```

**调用例子：**

```swift
let result = try await client.searchDefault()
```

### 热搜列表（详细）

说明：获取热搜详细列表

**方法签名：**

```swift
func searchHotDetail() async throws -> APIResponse
```

**调用例子：**

```swift
let result = try await client.searchHotDetail()
```

### 热搜列表（简略）

说明：获取热搜简略列表

**方法签名：**

```swift
func searchHot() async throws -> APIResponse
```

**调用例子：**

```swift
let result = try await client.searchHot()
```

### 搜索建议

说明：根据关键词获取搜索建议

**方法签名：**

```swift
func searchSuggest(keywords: String, type: SearchSuggestType = .mobile) async throws -> APIResponse
```

**参数：**

| 参数 | 类型 | 必选 | 说明 |
|------|------|------|------|
| keywords | String | ✅ | 搜索关键词 |
| type | SearchSuggestType | ❌ | 建议类型，默认 `.mobile` |

**调用例子：**

```swift
let result = try await client.searchSuggest(keywords: "海阔天空")
```

### 搜索多重匹配

说明：搜索多类型匹配结果（歌手、专辑、歌曲等同时匹配）

**方法签名：**

```swift
func searchMultimatch(keywords: String) async throws -> APIResponse
```

**调用例子：**

```swift
let result = try await client.searchMultimatch(keywords: "周杰伦")
```

### 搜索匹配（本地歌曲）

说明：本地歌曲匹配音乐信息

**方法签名：**

```swift
func searchMatch(title: String = "", artist: String = "", album: String = "", duration: Int = 0, md5: String = "") async throws -> APIResponse
```

**参数：**

| 参数 | 类型 | 必选 | 说明 |
|------|------|------|------|
| title | String | ❌ | 歌曲标题 |
| artist | String | ❌ | 歌手名 |
| album | String | ❌ | 专辑名 |
| duration | Int | ❌ | 时长（毫秒） |
| md5 | String | ❌ | 文件 MD5 |

**调用例子：**

```swift
let result = try await client.searchMatch(title: "晴天", artist: "周杰伦")
```

---


## 歌曲

### 获取歌曲详情

说明：传入歌曲 ID 数组，获取歌曲详细信息

**方法签名：**

```swift
func songDetail(ids: [Int]) async throws -> APIResponse
```

**参数：**

| 参数 | 类型 | 必选 | 说明 |
|------|------|------|------|
| ids | [Int] | ✅ | 歌曲 ID 数组 |

**调用例子：**

```swift
let result = try await client.songDetail(ids: [347230])
let result = try await client.songDetail(ids: [347230, 347231, 347232])
```

### 获取歌曲播放链接

说明：传入歌曲 ID 数组，获取歌曲播放链接

**方法签名：**

```swift
func songUrl(ids: [Int], br: Int = 999000) async throws -> APIResponse
```

**参数：**

| 参数 | 类型 | 必选 | 说明 |
|------|------|------|------|
| ids | [Int] | ✅ | 歌曲 ID 数组 |
| br | Int | ❌ | 码率，默认 999000 |

**调用例子：**

```swift
let result = try await client.songUrl(ids: [347230])
let result = try await client.songUrl(ids: [347230], br: 320000)
```

### 获取歌曲播放链接 V1

说明：使用音质等级获取播放链接，支持无损和沉浸环绕声

**方法签名：**

```swift
func songUrlV1(ids: [Int], level: SoundQualityType = .exhigh) async throws -> APIResponse
```

**参数：**

| 参数 | 类型 | 必选 | 说明 |
|------|------|------|------|
| ids | [Int] | ✅ | 歌曲 ID 数组 |
| level | SoundQualityType | ❌ | 音质等级，默认 `.exhigh`（极高） |

> SoundQualityType 可选值：`.standard`（标准）、`.higher`（较高）、`.exhigh`（极高）、`.lossless`（无损）、`.hires`（Hi-Res）、`.jyeffect`（高清环绕声）、`.sky`（沉浸环绕声）、`.jymaster`（超清母带）

**调用例子：**

```swift
let result = try await client.songUrlV1(ids: [347230], level: .lossless)
```

### 获取歌曲下载链接

说明：获取歌曲下载链接

**方法签名：**

```swift
func songDownloadUrl(id: Int, br: Int = 999000) async throws -> APIResponse
```

**参数：**

| 参数 | 类型 | 必选 | 说明 |
|------|------|------|------|
| id | Int | ✅ | 歌曲 ID |
| br | Int | ❌ | 码率，默认 999000 |

**调用例子：**

```swift
let result = try await client.songDownloadUrl(id: 347230)
```

### 获取歌曲下载链接 V1

说明：使用音质等级获取下载链接

**方法签名：**

```swift
func songDownloadUrlV1(id: Int, level: SoundQualityType = .exhigh) async throws -> APIResponse
```

**调用例子：**

```swift
let result = try await client.songDownloadUrlV1(id: 347230, level: .hires)
```

### 获取歌词

说明：获取歌曲歌词

**方法签名：**

```swift
func lyric(id: Int) async throws -> APIResponse
```

**参数：**

| 参数 | 类型 | 必选 | 说明 |
|------|------|------|------|
| id | Int | ✅ | 歌曲 ID |

**调用例子：**

```swift
let result = try await client.lyric(id: 347230)
```

### 获取歌词（新版）

说明：获取新版歌词，包含逐字歌词

**方法签名：**

```swift
func lyricNew(id: Int) async throws -> APIResponse
```

**调用例子：**

```swift
let result = try await client.lyricNew(id: 347230)
```

### 红心歌曲

说明：红心/取消红心歌曲

**方法签名：**

```swift
func like(id: Int, like: Bool = true) async throws -> APIResponse
```

**参数：**

| 参数 | 类型 | 必选 | 说明 |
|------|------|------|------|
| id | Int | ✅ | 歌曲 ID |
| like | Bool | ❌ | 是否红心，默认 true |

**调用例子：**

```swift
// 红心
let result = try await client.like(id: 347230)
// 取消红心
let result = try await client.like(id: 347230, like: false)
```

### 红心歌曲列表

说明：获取用户喜欢的歌曲 ID 列表

**方法签名：**

```swift
func likelist(uid: Int) async throws -> APIResponse
```

**调用例子：**

```swift
let result = try await client.likelist(uid: 32953014)
```

### 检查是否已红心

说明：检查歌曲是否已红心

**方法签名：**

```swift
func songLikeCheck(ids: String) async throws -> APIResponse
```

**调用例子：**

```swift
let result = try await client.songLikeCheck(ids: "347230")
```

### 听歌打卡

说明：记录听歌行为

**方法签名：**

```swift
func scrobble(id: Int, sourceid: Int, time: Int = 0) async throws -> APIResponse
```

**参数：**

| 参数 | 类型 | 必选 | 说明 |
|------|------|------|------|
| id | Int | ✅ | 歌曲 ID |
| sourceid | Int | ✅ | 来源 ID（如歌单 ID） |
| time | Int | ❌ | 播放时长（秒），默认 0 |

**调用例子：**

```swift
let result = try await client.scrobble(id: 347230, sourceid: 2059327575, time: 240)
```

### 歌曲可用性检查

说明：检查歌曲是否可用

**方法签名：**

```swift
func checkMusic(ids: [Int], br: Int = 999000) async throws -> APIResponse
```

**调用例子：**

```swift
let result = try await client.checkMusic(ids: [347230])
```

### 新歌速递

说明：获取新歌列表

**方法签名：**

```swift
func topSong(type: TopSongType = .all) async throws -> APIResponse
```

> TopSongType 可选值：`.all`（全部）、`.zh`（华语）、`.ea`（欧美）、`.kr`（韩国）、`.jp`（日本）

**调用例子：**

```swift
let result = try await client.topSong(type: .zh)
```

### 私人 FM

说明：获取私人 FM 歌曲

**方法签名：**

```swift
func personalFm() async throws -> APIResponse
```

**调用例子：**

```swift
let result = try await client.personalFm()
```

### 私人 FM 模式

说明：设置私人 FM 模式

**方法签名：**

```swift
func personalFmMode(mode: String = "DEFAULT") async throws -> APIResponse
```

**调用例子：**

```swift
let result = try await client.personalFmMode(mode: "DEFAULT")
```

### 歌曲副歌片段

说明：获取歌曲副歌时间信息

```swift
let result = try await client.songChorus(id: 347230)
```

### 歌曲动态封面

说明：获取歌曲动态封面

```swift
let result = try await client.songDynamicCover(id: 347230)
```

### 歌曲百科摘要

说明：获取歌曲百科基础信息

```swift
let result = try await client.songWikiSummary(id: 347230)
```

### 歌曲音质详情

说明：获取歌曲音质详情

```swift
let result = try await client.songMusicDetail(id: 347230)
```

### 已购歌曲

说明：获取已购单曲列表

```swift
let result = try await client.songPurchased(limit: 20, offset: 0)
```

### 歌曲红心数量

说明：获取歌曲红心数量

```swift
let result = try await client.songRedCount(id: 347230)
```

### 歌曲下载排行

说明：获取会员下载歌曲记录

```swift
let result = try await client.songDownlist(limit: 20, offset: 0)
```

### 歌曲月下载排行

说明：获取会员本月下载歌曲记录

```swift
let result = try await client.songMonthdownlist(limit: 20, offset: 0)
```

### 歌曲单曲下载排行

说明：获取已购买单曲下载记录

```swift
let result = try await client.songSingledownlist(limit: 20, offset: 0)
```

### 歌曲排序更新

说明：更新歌单中歌曲顺序

```swift
let result = try await client.songOrderUpdate(pid: 12345, ids: "[347230,347231]")
```

### 歌词标记

说明：获取歌词摘录信息

```swift
let result = try await client.songLyricsMark(id: 347230)
```

### 添加歌词标记

说明：添加/修改歌词摘录

```swift
let result = try await client.songLyricsMarkAdd(id: 347230, markData: "[...]")
```

### 删除歌词标记

说明：删除歌词摘录

```swift
let result = try await client.songLyricsMarkDel(id: "markId")
```

### 我的歌词本

说明：获取我的歌词本

```swift
let result = try await client.songLyricsMarkUserPage(limit: 10, offset: 0)
```

---


## 歌单

### 获取歌单详情

说明：获取歌单详细信息

**方法签名：**

```swift
func playlistDetail(id: Int, s: Int = 8) async throws -> APIResponse
```

**参数：**

| 参数 | 类型 | 必选 | 说明 |
|------|------|------|------|
| id | Int | ✅ | 歌单 ID |
| s | Int | ❌ | 收藏者数量，默认 8 |

**调用例子：**

```swift
let result = try await client.playlistDetail(id: 24381616)
```

### 获取歌单动态信息

说明：获取歌单播放量、收藏量等动态信息

```swift
let result = try await client.playlistDetailDynamic(id: 24381616)
```

### 获取歌单所有歌曲

说明：获取歌单中所有歌曲详情（支持分页）

**方法签名：**

```swift
func playlistTrackAll(id: Int, limit: Int = 10, offset: Int = 0) async throws -> APIResponse
```

**调用例子：**

```swift
let result = try await client.playlistTrackAll(id: 24381616, limit: 50)
```

### 添加/删除歌单曲目

说明：向歌单添加或删除歌曲

**方法签名：**

```swift
func playlistTracks(op: String, pid: Int, trackIds: [Int]) async throws -> APIResponse
```

**参数：**

| 参数 | 类型 | 必选 | 说明 |
|------|------|------|------|
| op | String | ✅ | 操作类型，`"add"` 添加，`"del"` 删除 |
| pid | Int | ✅ | 歌单 ID |
| trackIds | [Int] | ✅ | 歌曲 ID 数组 |

**调用例子：**

```swift
let result = try await client.playlistTracks(op: "add", pid: 24381616, trackIds: [347230])
```

### 创建歌单

说明：创建新歌单

**方法签名：**

```swift
func playlistCreate(name: String, privacy: Int = 0, type: String = "NORMAL") async throws -> APIResponse
```

**参数：**

| 参数 | 类型 | 必选 | 说明 |
|------|------|------|------|
| name | String | ✅ | 歌单名称 |
| privacy | Int | ❌ | 0 普通歌单，10 隐私歌单 |
| type | String | ❌ | 歌单类型，默认 `"NORMAL"` |

**调用例子：**

```swift
let result = try await client.playlistCreate(name: "我的歌单")
let result = try await client.playlistCreate(name: "私密歌单", privacy: 10)
```

### 删除歌单

说明：删除歌单

```swift
let result = try await client.playlistDelete(ids: [12345])
```

### 收藏/取消收藏歌单

说明：收藏或取消收藏歌单

**方法签名：**

```swift
func playlistSubscribe(id: Int, action: SubAction) async throws -> APIResponse
```

**调用例子：**

```swift
let result = try await client.playlistSubscribe(id: 24381616, action: .sub)
let result = try await client.playlistSubscribe(id: 24381616, action: .unsub)
```

### 歌单收藏者

说明：获取歌单收藏者列表

```swift
let result = try await client.playlistSubscribers(id: 24381616, limit: 20)
```

### 歌单广场

说明：获取歌单列表（分类歌单）

**方法签名：**

```swift
func topPlaylist(cat: String = "全部", limit: Int = 50, offset: Int = 0, order: ListOrder = .hot) async throws -> APIResponse
```

**调用例子：**

```swift
let result = try await client.topPlaylist(cat: "华语")
let result = try await client.topPlaylist(cat: "全部", limit: 10, order: .new)
```

### 精品歌单

说明：获取精品歌单列表

**方法签名：**

```swift
func topPlaylistHighquality(cat: String = "全部", limit: Int = 50, lasttime: Int = 0) async throws -> APIResponse
```

**调用例子：**

```swift
let result = try await client.topPlaylistHighquality(cat: "华语")
```

### 歌单分类

说明：获取所有歌单分类

```swift
let result = try await client.playlistCatlist()
```

### 热门歌单标签

说明：获取热门歌单分类标签

```swift
let result = try await client.playlistHot()
```

### 编辑歌单

说明：批量更新歌单名称、描述、标签

```swift
let result = try await client.playlistUpdate(id: 12345, name: "新名称", desc: "新描述", tags: "华语")
```

### 更新歌单名

```swift
let result = try await client.playlistNameUpdate(id: 12345, name: "新名称")
```

### 更新歌单描述

```swift
let result = try await client.playlistDescUpdate(id: 12345, desc: "新描述")
```

### 更新歌单标签

```swift
let result = try await client.playlistTagsUpdate(id: 12345, tags: "华语;流行")
```

### 更新歌单顺序

```swift
let result = try await client.playlistOrderUpdate(ids: "[12345,67890]")
```

### 歌单隐私设置

说明：公开隐私歌单

```swift
let result = try await client.playlistPrivacy(id: 12345)
```

### 我喜欢的音乐

```swift
let result = try await client.playlistMylike()
```

### 歌单封面更新

```swift
let result = try await client.playlistCoverUpdate(...)
```

### 导入歌单

```swift
let result = try await client.playlistImportNameTaskCreate(playlistName: "导入歌单", songs: "[...]")
```

### 导入歌单状态

```swift
let result = try await client.playlistImportTaskStatus(id: "taskId")
```

### 歌单推荐

```swift
let result = try await client.playlistDetailRcmdGet(id: 24381616)
```

### 歌单分类列表（新版）

```swift
let result = try await client.playlistCategoryList(cat: "全部", limit: 24)
```

### 精品歌单标签

```swift
let result = try await client.playlistHighqualityTags()
```

### 添加歌曲到歌单（新版）

```swift
let result = try await client.playlistTrackAdd(pid: 12345, ids: [347230])
```

### 从歌单删除歌曲（新版）

```swift
let result = try await client.playlistTrackDelete(id: 12345, ids: [347230])
```

### 更新播放量

```swift
let result = try await client.playlistUpdatePlaycount(id: 12345)
```

### 歌单最近视频

```swift
let result = try await client.playlistVideoRecent()
```

---


## 用户

### 获取用户详情

说明：传入用户 ID，获取用户详细信息

**方法签名：**

```swift
func userDetail(uid: Int) async throws -> APIResponse
```

**调用例子：**

```swift
let result = try await client.userDetail(uid: 32953014)
```

### 获取用户详情（新版）

```swift
let result = try await client.userDetailNew(uid: 32953014)
```

### 获取账号信息

说明：获取当前登录用户的账号信息

```swift
let result = try await client.userAccount()
```

### 用户收藏计数

说明：获取用户各类收藏计数

```swift
let result = try await client.userSubcount()
```

### 用户等级

```swift
let result = try await client.userLevel()
```

### 用户歌单

说明：获取用户创建和收藏的歌单

**方法签名：**

```swift
func userPlaylist(uid: Int, limit: Int = 30, offset: Int = 0) async throws -> APIResponse
```

**调用例子：**

```swift
let result = try await client.userPlaylist(uid: 32953014)
```

### 用户听歌排行

说明：获取用户听歌排行

**方法签名：**

```swift
func userRecord(uid: Int, type: UserRecordType = .all) async throws -> APIResponse
```

> UserRecordType：`.all`（所有时间）、`.week`（最近一周）

**调用例子：**

```swift
let result = try await client.userRecord(uid: 32953014, type: .week)
```

### 用户关注列表

```swift
let result = try await client.userFollows(uid: 32953014, limit: 30)
```

### 用户粉丝列表

```swift
let result = try await client.userFolloweds(uid: 32953014, limit: 30)
```

### 关注/取消关注

**方法签名：**

```swift
func follow(id: Int, action: SubAction) async throws -> APIResponse
```

**调用例子：**

```swift
let result = try await client.follow(id: 32953014, action: .sub)
let result = try await client.follow(id: 32953014, action: .unsub)
```

### 用户绑定信息

```swift
let result = try await client.userBinding(uid: 32953014)
```

### 绑定手机号

```swift
let result = try await client.userBindingCellphone(phone: "13800138000", captcha: "1234")
```

### 更换手机号

```swift
let result = try await client.userReplacephone(phone: "13900139000", captcha: "5678", oldcaptcha: "1234")
```

### 更新用户信息

**方法签名：**

```swift
func userUpdate(nickname: String, signature: String, gender: Int, birthday: Int, province: Int, city: Int) async throws -> APIResponse
```

**调用例子：**

```swift
let result = try await client.userUpdate(
    nickname: "新昵称",
    signature: "个性签名",
    gender: 1,
    birthday: 631152000000,
    province: 110000,
    city: 110101
)
```

### 用户动态

```swift
let result = try await client.userEvent(uid: 32953014)
```

### 用户电台

```swift
let result = try await client.userDj(uid: 32953014)
```

### 用户音频

```swift
let result = try await client.userAudio(uid: 32953014)
```

### 用户评论历史

```swift
let result = try await client.userCommentHistory(uid: 32953014, limit: 10)
```

### 用户勋章

```swift
let result = try await client.userMedal(uid: 32953014)
```

### 互相关注

```swift
let result = try await client.userMutualfollowGet(uid: 32953014)
```

### 混合关注列表

说明：获取关注的用户/歌手（混合列表）

```swift
let result = try await client.userFollowMixed(size: 30, cursor: 0, scene: 0)
```

### 用户社交状态

```swift
let result = try await client.userSocialStatus(uid: 32953014)
```

### 编辑社交状态

```swift
let result = try await client.userSocialStatusEdit(type: 1, content: "正在听歌")
```

### 社交状态推荐

```swift
let result = try await client.userSocialStatusRcmd()
```

### 支持的社交状态列表

```swift
let result = try await client.userSocialStatusSupport()
```

---


## 歌手

### 歌手详情

说明：获取歌手详细信息

```swift
let result = try await client.artistDetail(id: 6452)
```

### 歌手信息（含热门歌曲）

```swift
let result = try await client.artists(id: 6452)
```

### 歌手歌曲列表

**方法签名：**

```swift
func artistSongs(id: Int, limit: Int = 50, offset: Int = 0, order: ArtistSongsOrder = .hot) async throws -> APIResponse
```

> ArtistSongsOrder：`.hot`（热门排序）、`.time`（时间排序）

**调用例子：**

```swift
let result = try await client.artistSongs(id: 6452, limit: 50)
```

### 歌手热门 50 首

```swift
let result = try await client.artistTopSong(id: 6452)
```

### 歌手专辑

```swift
let result = try await client.artistAlbum(id: 6452, limit: 30)
```

### 歌手描述

```swift
let result = try await client.artistDesc(id: 6452)
```

### 歌手动态信息

```swift
let result = try await client.artistDetailDynamic(id: 6452)
```

### 歌手 MV

```swift
let result = try await client.artistMv(id: 6452, limit: 30)
```

### 歌手最新 MV

说明：获取关注歌手的新 MV

```swift
let result = try await client.artistNewMv(limit: 20)
```

### 歌手最新歌曲

说明：获取关注歌手的新歌

```swift
let result = try await client.artistNewSong(limit: 20)
```

### 歌手分类列表

**方法签名：**

```swift
func artistList(area: ArtistArea = .all, type: ArtistType = .male, initial: String = "", limit: Int = 30, offset: Int = 0) async throws -> APIResponse
```

> ArtistArea：`.all`、`.zh`（华语）、`.ea`（欧美）、`.jp`（日本）、`.kr`（韩国）、`.other`
>
> ArtistType：`.male`（男歌手）、`.female`（女歌手）、`.band`（乐队/组合）

**调用例子：**

```swift
let result = try await client.artistList(area: .zh, type: .male, initial: "Z")
```

### 收藏歌手

```swift
let result = try await client.artistSub(id: 6452, action: .sub)
let result = try await client.artistSub(id: 6452, action: .unsub)
```

### 已收藏歌手

```swift
let result = try await client.artistSublist(limit: 25)
```

### 歌手粉丝

```swift
let result = try await client.artistFans(id: 6452, limit: 20)
```

### 歌手关注数

```swift
let result = try await client.artistFollowCount(id: 6452)
```

### 歌手视频

```swift
let result = try await client.artistVideo(id: 6452, size: 10)
```

### 相似歌手

```swift
let result = try await client.simiArtist(id: 6452)
```

---

## 专辑

### 专辑详情

说明：获取专辑信息和歌曲列表

```swift
let result = try await client.album(id: 32311)
```

### 专辑动态信息

说明：获取专辑评论数、分享数、是否收藏等

```swift
let result = try await client.albumDetailDynamic(id: 32311)
```

### 收藏专辑

```swift
let result = try await client.albumSub(id: 32311, action: .sub)
let result = try await client.albumSub(id: 32311, action: .unsub)
```

### 已收藏专辑

```swift
let result = try await client.albumSublist(limit: 25)
```

### 最新专辑

```swift
let result = try await client.albumNewest()
```

### 新碟上架

**方法签名：**

```swift
func albumNew(area: AlbumListArea = .all, limit: Int = 30, offset: Int = 0) async throws -> APIResponse
```

> AlbumListArea：`.all`、`.zh`（华语）、`.ea`（欧美）、`.kr`（韩国）、`.jp`（日本）

**调用例子：**

```swift
let result = try await client.albumNew(area: .zh, limit: 30)
```

### 热门新碟

```swift
let result = try await client.topAlbum(limit: 50, area: "ZH")
```

### 专辑列表

```swift
let result = try await client.albumList(area: "ALL", limit: 30)
```

### 专辑风格列表

```swift
let result = try await client.albumListStyle(area: .zh, limit: 10)
```

### 数字专辑详情

```swift
let result = try await client.albumDetail(id: 32311)
```

### 专辑权限

```swift
let result = try await client.albumPrivilege(id: 32311)
```

### 专辑销量榜

```swift
let result = try await client.albumSongsaleboard(albumType: 0, type: "daily")
```

### 购买数字专辑

```swift
let result = try await client.digitalAlbumOrdering(id: 32311, payment: 1)
```

### 已购数字专辑

```swift
let result = try await client.digitalAlbumPurchased(limit: 30)
```

### 数字专辑销量

```swift
let result = try await client.digitalAlbumSales(ids: "32311")
```

---


## 评论

### 发表/删除/回复评论

说明：对资源进行评论操作

**方法签名：**

```swift
func comment(action: CommentAction, type: CommentType, id: Int, content: String = "", commentId: Int = 0) async throws -> APIResponse
```

**参数：**

| 参数 | 类型 | 必选 | 说明 |
|------|------|------|------|
| action | CommentAction | ✅ | `.add` 发表、`.delete` 删除、`.reply` 回复 |
| type | CommentType | ✅ | `.song`、`.mv`、`.playlist`、`.album`、`.dj`、`.video`、`.event` |
| id | Int | ✅ | 资源 ID |
| content | String | ❌ | 评论内容（发表和回复时需要） |
| commentId | Int | ❌ | 评论 ID（删除和回复时需要） |

**调用例子：**

```swift
// 发表评论
let result = try await client.comment(action: .add, type: .song, id: 347230, content: "好听！")
// 删除评论
let result = try await client.comment(action: .delete, type: .song, id: 347230, commentId: 123456)
// 回复评论
let result = try await client.comment(action: .reply, type: .song, id: 347230, content: "谢谢", commentId: 123456)
```

### 获取评论（新版）

说明：获取资源评论列表，支持排序

**方法签名：**

```swift
func commentNew(type: CommentType, id: Int, pageNo: Int = 1, pageSize: Int = 20, sortType: Int = 99, cursor: String = "") async throws -> APIResponse
```

**参数：**

| 参数 | 类型 | 必选 | 说明 |
|------|------|------|------|
| type | CommentType | ✅ | 资源类型 |
| id | Int | ✅ | 资源 ID |
| pageNo | Int | ❌ | 页码，默认 1 |
| pageSize | Int | ❌ | 每页数量，默认 20 |
| sortType | Int | ❌ | 排序：99 推荐，2 热度，3 时间 |
| cursor | String | ❌ | 分页游标（sortType=3 时使用） |

**调用例子：**

```swift
let result = try await client.commentNew(type: .song, id: 347230, sortType: 99)
```

### 热门评论

```swift
let result = try await client.commentHot(type: .song, id: 347230, limit: 20)
```

### 楼层评论

```swift
let result = try await client.commentFloor(type: .song, id: 347230, parentCommentId: 123456)
```

### 评论点赞

```swift
// 点赞
let result = try await client.commentLike(type: .song, id: 347230, commentId: 123456, like: true)
// 取消点赞
let result = try await client.commentLike(type: .song, id: 347230, commentId: 123456, like: false)
```

### 评论抱一抱列表

```swift
let result = try await client.commentHugList(uid: 32953014, cid: 123456, sid: 347230)
```

### 歌曲评论

```swift
let result = try await client.commentMusic(id: 347230, limit: 20)
```

### 专辑评论

```swift
let result = try await client.commentAlbum(id: 32311, limit: 20)
```

### 歌单评论

```swift
let result = try await client.commentPlaylist(id: 24381616, limit: 20)
```

### MV 评论

```swift
let result = try await client.commentMv(id: 5436712, limit: 20)
```

### 电台评论

```swift
let result = try await client.commentDj(id: 336355127, limit: 20)
```

### 视频评论

```swift
let result = try await client.commentVideo(id: "89ADDE33C0AAE8EC14B99F6750DB954D", limit: 20)
```

### 动态评论

```swift
let result = try await client.commentEvent(threadId: "A_EV_2_xxx")
```

---

## MV / 视频

### MV 列表

说明：获取全部 MV 列表

**方法签名：**

```swift
func mvAll(area: MvArea = .all, type: MvType = .all, order: MvOrder = .hot, limit: Int = 30, offset: Int = 0) async throws -> APIResponse
```

> MvArea：`.all`、`.mainland`（内地）、`.hktw`（港台）、`.ea`（欧美）、`.kr`（韩国）、`.jp`（日本）
>
> MvOrder：`.hot`（最热）、`.new`（最新）

**调用例子：**

```swift
let result = try await client.mvAll(area: .mainland, order: .hot)
```

### 最新 MV

```swift
let result = try await client.mvFirst(area: .all, limit: 30)
```

### 独家放送 MV

```swift
let result = try await client.mvExclusiveRcmd(limit: 30)
```

### MV 详情

```swift
let result = try await client.mvDetail(mvid: 5436712)
```

### MV 点赞数等

```swift
let result = try await client.mvDetailInfo(mvid: 5436712)
```

### MV 播放地址

**方法签名：**

```swift
func mvUrl(id: Int, r: Int = 1080) async throws -> APIResponse
```

**调用例子：**

```swift
let result = try await client.mvUrl(id: 5436712, r: 1080)
```

### 收藏 MV

```swift
let result = try await client.mvSub(mvid: 5436712, action: .sub)
```

### 已收藏 MV

```swift
let result = try await client.mvSublist(limit: 25)
```

### MV 排行榜

```swift
let result = try await client.topMv(limit: 30, area: "")
```

### 视频详情

```swift
let result = try await client.videoDetail(id: "89ADDE33C0AAE8EC14B99F6750DB954D")
```

### 视频点赞数等

```swift
let result = try await client.videoDetailInfo(vid: "89ADDE33C0AAE8EC14B99F6750DB954D")
```

### 视频播放地址

```swift
let result = try await client.videoUrl(id: "89ADDE33C0AAE8EC14B99F6750DB954D", resolution: 1080)
```

### 收藏视频

```swift
let result = try await client.videoSub(id: "89ADDE33C0AAE8EC14B99F6750DB954D", action: .sub)
```

### 视频分组

```swift
let result = try await client.videoGroup(id: 9104)
```

### 视频分组列表

```swift
let result = try await client.videoGroupList()
```

### 视频分类列表

```swift
let result = try await client.videoCategoryList()
```

### 全部视频动态

```swift
let result = try await client.videoTimelineAll(offset: 0)
```

### 推荐视频

```swift
let result = try await client.videoTimelineRecommend(offset: 0)
```

### 相关视频

```swift
let result = try await client.relatedAllvideo(id: "89ADDE33C0AAE8EC14B99F6750DB954D")
```

---


## 电台 / 播客

### 电台详情

```swift
let result = try await client.djDetail(rid: 336355127)
```

### 电台节目列表

**方法签名：**

```swift
func djProgram(rid: Int, limit: Int = 30, offset: Int = 0, asc: Bool = false) async throws -> APIResponse
```

**调用例子：**

```swift
let result = try await client.djProgram(rid: 336355127, limit: 30)
```

### 节目详情

```swift
let result = try await client.djProgramDetail(id: 1369798382)
```

### 订阅电台

```swift
let result = try await client.djSub(rid: 336355127, action: .sub)
```

### 已订阅电台

```swift
let result = try await client.djSublist(limit: 30)
```

### 热门电台

```swift
let result = try await client.djHot(limit: 30)
```

### 推荐电台

```swift
let result = try await client.djRecommend()
```

### 分类推荐

```swift
let result = try await client.djRecommendType(cateId: 2001)
```

### 电台分类

```swift
let result = try await client.djCatelist()
```

### 推荐分类电台

```swift
let result = try await client.djCategoryRecommend()
```

### 非热门分类

```swift
let result = try await client.djCategoryExcludehot()
```

### 分类热门电台

```swift
let result = try await client.djRadioHot(cateId: 2001, limit: 30)
```

### 电台排行榜

```swift
let result = try await client.djToplist(limit: 30)
```

### 24 小时主播榜

```swift
let result = try await client.djToplistHours(limit: 100)
```

### 新人排行

```swift
let result = try await client.djToplistNewcomer(limit: 100)
```

### 付费排行

```swift
let result = try await client.djToplistPay(limit: 100)
```

### 最热主播

```swift
let result = try await client.djToplistPopular(limit: 100)
```

### 新晋电台榜

```swift
let result = try await client.djRadioTop(sortIndex: 1, dataGapDays: 7)
```

### 节目排行

```swift
let result = try await client.djProgramToplist(limit: 30)
```

### 24 小时节目排行

```swift
let result = try await client.djProgramToplistHours(limit: 100)
```

### 电台 Banner

```swift
let result = try await client.djBanner()
```

### 电台订阅者

```swift
let result = try await client.djSubscriber(id: 336355127, limit: 20)
```

### 付费精选

```swift
let result = try await client.djPaygift(limit: 30)
```

### 个性化推荐

```swift
let result = try await client.djPersonalizeRecommend(limit: 6)
```

### 今日优选

```swift
let result = try await client.djTodayPerfered(page: 0)
```

---

## 排行榜

### 所有排行榜

```swift
let result = try await client.toplist()
```

### 排行榜详情

```swift
let result = try await client.toplistDetail()
```

### 排行榜详情 V2

```swift
let result = try await client.toplistDetailV2()
```

### 新歌速递

**方法签名：**

```swift
func topSong(type: TopSongType = .all) async throws -> APIResponse
```

> TopSongType：`.all`（全部）、`.zh`（华语）、`.ea`（欧美）、`.kr`（韩国）、`.jp`（日本）

**调用例子：**

```swift
let result = try await client.topSong(type: .zh)
```

### 热门歌手

```swift
let result = try await client.topArtists(limit: 50)
```

### 歌手排行榜

**方法签名：**

```swift
func toplistArtist(type: ToplistArtistType = .zh) async throws -> APIResponse
```

> ToplistArtistType：`.zh`（华语）、`.ea`（欧美）、`.kr`（韩国）、`.jp`（日本）

**调用例子：**

```swift
let result = try await client.toplistArtist(type: .zh)
```

### 新碟上架

```swift
let result = try await client.topAlbum(limit: 50, area: "ALL")
```

### MV 排行

```swift
let result = try await client.topMv(limit: 30, area: "")
```

### 歌单排行

```swift
let result = try await client.topPlaylist(cat: "全部", limit: 50)
```

---

## 推荐

### 每日推荐歌曲

说明：需要登录

```swift
let result = try await client.recommendSongs()
```

### 每日推荐歌单

说明：需要登录

```swift
let result = try await client.recommendResource()
```

### 不喜欢推荐歌曲

```swift
let result = try await client.recommendSongsDislike(id: 347230)
```

### 推荐歌单

```swift
let result = try await client.personalized(limit: 30)
```

### 推荐新歌

```swift
let result = try await client.personalizedNewsong(limit: 10)
```

### 推荐 MV

```swift
let result = try await client.personalizedMv()
```

### 推荐电台

```swift
let result = try await client.personalizedDjprogram()
```

### 独家放送

```swift
let result = try await client.personalizedPrivatecontent()
```

### 独家放送列表

```swift
let result = try await client.personalizedPrivatecontentList(limit: 60)
```

### 推荐节目

```swift
let result = try await client.programRecommend(type: 2001, limit: 10)
```

### 历史推荐歌曲

```swift
let result = try await client.historyRecommendSongs()
```

### 历史推荐详情

```swift
let result = try await client.historyRecommendSongsDetail(date: "2024-01-01")
```

### 相关歌单

```swift
let result = try await client.relatedPlaylist(...)
```

### 相似推荐系列

```swift
let result = try await client.simiPlaylist(id: 347230)
let result = try await client.simiSong(id: 347230)
let result = try await client.simiMv(mvid: 5436712)
let result = try await client.simiUser(id: 347230)
```

---


## 登录认证

### 手机号登录

**方法签名：**

```swift
func loginCellphone(phone: String, password: String, countrycode: String = "86") async throws -> APIResponse
```

**参数：**

| 参数 | 类型 | 必选 | 说明 |
|------|------|------|------|
| phone | String | ✅ | 手机号码 |
| password | String | ✅ | 密码（明文，内部自动 MD5） |
| countrycode | String | ❌ | 国家码，默认 "86" |

**调用例子：**

```swift
let result = try await client.loginCellphone(phone: "13800138000", password: "your_password")
```

### 邮箱登录

```swift
let result = try await client.loginEmail(email: "xxx@163.com", password: "your_password")
```

### 二维码登录

二维码登录涉及 3 个接口：

```swift
// 1. 获取二维码 Key
let keyResult = try await client.loginQrKey()
let key = keyResult.body["unikey"] as! String

// 2. 生成二维码
let qrResult = try await client.loginQrCreate(key: key)
// qrResult.body["data"]["qrurl"] 为二维码内容

// 3. 轮询扫码状态
// 800 过期，801 等待扫码，802 待确认，803 登录成功
let checkResult = try await client.loginQrCheck(key: key)
```

### 获取登录状态

```swift
let result = try await client.loginStatus()
```

### 刷新登录

```swift
let result = try await client.loginRefresh()
```

### 退出登录

```swift
let result = try await client.logout()
```

### 发送验证码

**方法签名：**

```swift
func captchaSent(phone: String, ctcode: String = "86") async throws -> APIResponse
```

**调用例子：**

```swift
let result = try await client.captchaSent(phone: "13800138000")
```

### 验证验证码

```swift
let result = try await client.captchaVerify(phone: "13800138000", captcha: "1234")
```

### 手机号注册

**方法签名：**

```swift
func registerCellphone(phone: String, password: String, captcha: String, nickname: String, countrycode: String = "86") async throws -> APIResponse
```

**调用例子：**

```swift
let result = try await client.registerCellphone(
    phone: "13800138000",
    password: "your_password",
    captcha: "1234",
    nickname: "新用户"
)
```

---

## VIP / 云贝

### VIP 信息

```swift
let result = try await client.vipInfo()
```

### VIP 信息 V2

```swift
let result = try await client.vipInfoV2()
```

### VIP 成长值

```swift
let result = try await client.vipGrowthpoint()
```

### VIP 成长值详情

```swift
let result = try await client.vipGrowthpointDetails(limit: 20)
```

### 领取成长值

```swift
let result = try await client.vipGrowthpointGet(ids: "taskId")
```

### VIP 任务

```swift
let result = try await client.vipTasks()
```

### VIP 签到

```swift
let result = try await client.vipSign()
```

### 签到信息

```swift
let result = try await client.vipSignInfo()
```

### 黑胶时光机

```swift
let result = try await client.vipTimemachine()
```

### 云贝数量

```swift
let result = try await client.yunbei()
```

### 云贝信息

```swift
let result = try await client.yunbeiInfo()
```

### 云贝签到

```swift
let result = try await client.yunbeiSign()
```

### 云贝任务

```swift
let result = try await client.yunbeiTasks()
```

### 待完成任务

```swift
let result = try await client.yunbeiTasksTodo()
```

### 完成任务

```swift
let result = try await client.yunbeiTaskFinish(userTaskId: 12345)
```

### 今日云贝

```swift
let result = try await client.yunbeiToday()
```

### 云贝支出

```swift
let result = try await client.yunbeiExpense(limit: 10)
```

### 云贝收入

```swift
let result = try await client.yunbeiReceipt(limit: 10)
```

### 云贝推荐歌曲

```swift
let result = try await client.yunbeiRcmdSong(id: 347230, reason: "好歌献给你")
```

### 推荐历史

```swift
let result = try await client.yunbeiRcmdSongHistory(size: 20)
```

---

## 私信

### 私信列表

```swift
let result = try await client.msgPrivate(limit: 30)
```

### 私信历史

```swift
let result = try await client.msgPrivateHistory(uid: 32953014, limit: 30)
```

### 最近联系人

```swift
let result = try await client.msgRecentcontact()
```

### 评论消息

```swift
let result = try await client.msgComments(uid: 32953014)
```

### 转发消息

```swift
let result = try await client.msgForwards(limit: 30)
```

### 通知消息

```swift
let result = try await client.msgNotices(limit: 30)
```

### 发送文字

```swift
let result = try await client.sendText(userIds: [32953014], msg: "你好！")
```

### 发送歌曲

```swift
let result = try await client.sendSong(userIds: [32953014], id: 347230, msg: "推荐给你")
```

### 发送专辑

```swift
let result = try await client.sendAlbum(userIds: [32953014], id: 32311)
```

### 发送歌单

```swift
let result = try await client.sendPlaylist(userIds: [32953014], id: 24381616)
```

---

## 云盘

### 云盘歌曲列表

```swift
let result = try await client.userCloud(limit: 30)
```

### 云盘歌曲详情

```swift
let result = try await client.userCloudDetail(ids: [347230])
```

### 删除云盘歌曲

```swift
let result = try await client.userCloudDel(ids: [347230])
```

### 云盘歌曲匹配

说明：将云盘歌曲匹配到曲库歌曲

```swift
let result = try await client.cloudMatch(sid: 12345, asid: 347230)
```

### 云盘导入

```swift
let result = try await client.cloudImport(songId: 347230)
```

### 云盘歌词

```swift
let result = try await client.cloudLyricGet(uid: 32953014, sid: 347230)
```

---


## 其他

本分类包含 119 个接口，涵盖 Banner、一起听、听歌足迹、音乐人、粉丝中心、曲风、UGC 百科、声音/播客、广播电台、动态、话题、Mlog、乐谱、首页等。

### Banner

```swift
let result = try await client.banner(type: .iphone)
```

> BannerType：`.pc`、`.android`、`.iphone`、`.ipad`

### 批量请求

```swift
let result = try await client.batch(requests: [
    "/api/v1/user/detail/32953014": [:],
    "/api/subcount": [:]
])
```

### 国家编码列表

```swift
let result = try await client.countriesCodeList()
```

### 日历

```swift
let result = try await client.calendar(startTime: 1609459200000, endTime: 1612137600000)
```

### 相似歌单

```swift
let result = try await client.simiPlaylist(id: 347230)
```

### 相似歌曲

```swift
let result = try await client.simiSong(id: 347230)
```

### 相似 MV

```swift
let result = try await client.simiMv(mvid: 5436712)
```

### 相似用户

```swift
let result = try await client.simiUser(id: 347230)
```

### FM 垃圾桶

说明：将歌曲加入 FM 不喜欢列表

```swift
let result = try await client.fmTrash(id: 347230)
```

### 每日签到

```swift
let result = try await client.dailySignin(type: .android)
```

### 资源点赞

```swift
let result = try await client.resourceLike(id: 5436712, type: .mv, like: true)
```

### 一起听

```swift
// 创建房间
let result = try await client.listentogetherRoomCreate()

// 接受邀请
let result = try await client.listentogetherAccept(roomId: "roomId", inviterId: "inviterId")

// 发送心跳
let result = try await client.listentogetherHeartbeat(roomId: "roomId", songId: "songId", playStatus: "playing", progress: 120)

// 获取状态
let result = try await client.listentogetherStatus()

// 房间情况
let result = try await client.listentogetherRoomCheck(roomId: "roomId")

// 结束房间
let result = try await client.listentogetherEnd(roomId: "roomId")

// 发送播放状态
let result = try await client.listentogetherPlayCommand(
    roomId: "roomId", commandType: "play", progress: 0,
    playStatus: "playing", formerSongId: "", targetSongId: "347230", clientSeq: "1"
)

// 更新播放列表
let result = try await client.listentogetherSyncListCommand(
    roomId: "roomId", commandType: "replace", userId: 32953014,
    version: 1, randomList: "", displayList: ""
)

// 获取当前播放列表
let result = try await client.listentogetherSyncPlaylistGet(roomId: "roomId")
```

### 听歌足迹

```swift
// 本周/本月收听时长
let result = try await client.listenDataRealtimeReport(type: "week")

// 周/月/年收听报告
let result = try await client.listenDataReport(type: "week")

// 今日收听
let result = try await client.listenDataTodaySong()

// 总收听时长
let result = try await client.listenDataTotal()

// 年度听歌足迹
let result = try await client.listenDataYearReport()
```

### 音乐人

```swift
// 云豆数
let result = try await client.musicianCloudbean()

// 领取云豆
let result = try await client.musicianCloudbeanObtain(id: 12345, period: "2024-01")

// 数据概况
let result = try await client.musicianDataOverview()

// 播放趋势
let result = try await client.musicianPlayTrend(...)

// 签到
let result = try await client.musicianSign()

// 任务列表
let result = try await client.musicianTasks()

// 新版任务
let result = try await client.musicianTasksNew()
```

### 粉丝中心

```swift
// 年龄分布
let result = try await client.fanscenterBasicinfoAgeGet()

// 性别分布
let result = try await client.fanscenterBasicinfoGenderGet()

// 省份分布
let result = try await client.fanscenterBasicinfoProvinceGet()

// 粉丝概览
let result = try await client.fanscenterOverviewGet()

// 粉丝趋势
let result = try await client.fanscenterTrendList()
```

### 曲风

```swift
// 曲风列表
let result = try await client.styleList()

// 曲风详情
let result = try await client.styleDetail(tagId: 1001)

// 曲风歌曲
let result = try await client.styleSong(tagId: 1001)

// 曲风专辑
let result = try await client.styleAlbum(tagId: 1001)

// 曲风歌单
let result = try await client.stylePlaylist(tagId: 1001)

// 曲风歌手
let result = try await client.styleArtist(tagId: 1001)

// 曲风偏好
let result = try await client.stylePreference()
```

### UGC 百科

```swift
let result = try await client.ugcDetail(...)
let result = try await client.ugcAlbumGet(...)
let result = try await client.ugcArtistGet(...)
let result = try await client.ugcArtistSearch(...)
let result = try await client.ugcMvGet(...)
let result = try await client.ugcSongGet(...)
let result = try await client.ugcUserDevote(...)
```

### 声音 / 播客

```swift
// 声音详情
let result = try await client.voiceDetail(id: 12345)

// 声音歌词
let result = try await client.voiceLyric(id: 12345)

// 删除声音
let result = try await client.voiceDelete(id: 12345)

// 声音列表详情
let result = try await client.voicelistDetail(id: 12345)

// 声音列表
let result = try await client.voicelistList(...)

// 声音列表搜索
let result = try await client.voicelistListSearch(...)

// 声音搜索
let result = try await client.voicelistSearch(...)

// 声音转换
let result = try await client.voicelistTrans(...)
```

### 广播电台

```swift
// 广播分类地区
let result = try await client.broadcastCategoryRegionGet()

// 广播频道收藏列表
let result = try await client.broadcastChannelCollectList()

// 广播频道当前信息
let result = try await client.broadcastChannelCurrentinfo(...)

// 广播频道列表
let result = try await client.broadcastChannelList(...)

// 广播订阅
let result = try await client.broadcastSub(...)
```

### 动态

```swift
// 获取动态
let result = try await client.event(...)

// 删除动态
let result = try await client.eventDel(id: 12345)

// 转发动态
let result = try await client.eventForward(...)
```

### 话题

```swift
// 热门话题
let result = try await client.hotTopic(limit: 20)

// 话题详情
let result = try await client.topicDetail(...)

// 话题热门动态
let result = try await client.topicDetailEventHot(...)

// 已收藏话题
let result = try await client.topicSublist(...)
```

### Mlog

```swift
// Mlog 音乐推荐
let result = try await client.mlogMusicRcmd(...)

// Mlog 转视频
let result = try await client.mlogToVideo(id: "mlogId")

// Mlog 播放地址
let result = try await client.mlogUrl(id: "mlogId")
```

### 乐谱

```swift
// 乐谱列表
let result = try await client.sheetList(id: 347230)

// 乐谱预览
let result = try await client.sheetPreview(id: "sheetId")
```

### 首页

```swift
// 首页 Block
let result = try await client.homepageBlockPage()

// 首页圆形图标
let result = try await client.homepageDragonBall()
```

### 其他工具

```swift
// 检测手机号是否已注册
let result = try await client.cellphoneExistenceCheck(phone: "13800138000")

// 重复昵称检测
let result = try await client.nicknameCheck(nickname: "testUser")

// 初始化昵称
let result = try await client.activateInitProfile(nickname: "newUser")

// 更换绑定手机
let result = try await client.rebind(phone: "13900139000", captcha: "5678", oldcaptcha: "1234")

// 获取用户 ID
let result = try await client.getUserids(nicknames: "用户昵称")

// 每日签到
let result = try await client.dailySignin()

// 签到进度
let result = try await client.signinProgress()

// 签到开心信息
let result = try await client.signHappyInfo()

// 年度总结
let result = try await client.summaryAnnual()

// 最近播放 - 歌曲
let result = try await client.recordRecentSong(limit: 100)

// 最近播放 - 专辑
let result = try await client.recordRecentAlbum(limit: 100)

// 最近播放 - 歌单
let result = try await client.recordRecentPlaylist(limit: 100)

// 最近播放 - 视频
let result = try await client.recordRecentVideo(limit: 100)

// 最近播放 - 电台
let result = try await client.recordRecentDj(limit: 100)

// 最近播放 - 声音
let result = try await client.recordRecentVoice(limit: 100)

// 最近播放列表
let result = try await client.recentListenList(...)

// 游客登录
let result = try await client.registerAnonimous()

// 音频指纹匹配
let result = try await client.audioMatch(...)

// 头像上传
let result = try await client.avatarUpload(...)

// 歌单封面更新
let result = try await client.playlistCoverUpdate(...)

// 声音上传
let result = try await client.voiceUpload(...)

// 智能播放列表
let result = try await client.playmodeIntelligenceList(...)

// 歌曲向量
let result = try await client.playmodeSongVector(...)

// 星评评论摘要
let result = try await client.starpickCommentsSummary(id: 347230)

// 门槛详情
let result = try await client.thresholdDetailGet(...)

// 创作者认证信息
let result = try await client.creatorAuthinfoGet()

// 首次听歌信息
let result = try await client.musicFirstListenInfo(id: 347230)

// 抱一抱评论
let result = try await client.hugComment(...)

// 设置
let result = try await client.setting()

// 分享资源
let result = try await client.shareResource(...)

// Weblog
let result = try await client.weblog(data: [...])

// 验证二维码
let result = try await client.verifyGetQr(...)
let result = try await client.verifyQrcodestatus(...)

// AI DJ 内容推荐
let result = try await client.aidjContentRcmd(...)

// 播放量计数
let result = try await client.plCount(...)
```

---

## 第三方解灰

> 第三方解灰模块用于获取灰色（无版权）歌曲的可用播放链接。SDK 提供了基于协议的多音源架构，支持导入 JS 音源脚本文件和自定义 HTTP 地址两种方式，并可自定义扩展。

!> 使用解灰模块时，导入的第三方 JS 音源可能请求任意 HTTP 域名。请确保在 Info.plist 中设置 `NSAllowsArbitraryLoads` 为 `true`，否则 iOS ATS 会拦截 HTTP 请求导致音源匹配失败。详见 [iOS ATS 注意事项](#ios-ats-注意事项)。

### 架构概览

```
┌──────────────────────────────────────────────┐
│              UnblockManager                   │
│         (多音源管理器，按优先级降级)             │
├─────────────────┬────────────────────────────┤
│  JSScriptSource  │    CustomURLSource         │
│ (导入 JS 脚本文件) │  (自定义 HTTP 地址)        │
├─────────────────┴────────────────────────────┤
│           NCMUnblockSource 协议               │
│    (自定义音源只需实现此协议即可接入)             │
└──────────────────────────────────────────────┘
```

### NCMUnblockSource 协议

所有音源都需要实现 `NCMUnblockSource` 协议：

```swift
public protocol NCMUnblockSource {
    /// 音源名称
    var name: String { get }
    /// 音源类型标识
    var sourceType: UnblockSourceType { get }
    /// 匹配歌曲，返回可用播放链接
    func match(id: Int, title: String?, artist: String?, quality: String) async throws -> UnblockResult
}
```

**UnblockSourceType 枚举：**

| 值 | 说明 |
|------|------|
| `.jsScript` | JS 脚本音源 |
| `.httpUrl` | 自定义 HTTP 地址音源 |

**UnblockResult 结构：**

| 属性 | 类型 | 说明 |
|------|------|------|
| url | String | 歌曲播放 URL |
| quality | String | 实际音质 |
| platform | String | 来源平台/音源名称 |
| extra | [String: Any] | 额外信息 |

### UnblockManager 管理器

`UnblockManager` 管理多个音源，支持按优先级自动降级匹配。

```swift
let manager = UnblockManager()

// 注册 JS 脚本音源
let jsSource = JSScriptSource(name: "我的音源", script: jsScriptContent)
manager.register(jsSource)

// 注册自定义地址音源
let urlSource = CustomURLSource(name: "自定义API", baseURL: "https://my-api.example.com/api.php")
manager.register(urlSource)

// 按优先级匹配（第一个成功即返回）
let result = await manager.match(id: 347230, quality: "320")
print(result?.url ?? "未匹配到")

// 尝试所有音源，返回全部结果
let allResults = await manager.matchAll(id: 347230)
for item in allResults {
    switch item.result {
    case .success(let r): print("\(item.source): \(r.url)")
    case .failure(let e): print("\(item.source): 失败 - \(e)")
    }
}
```

**管理器方法：**

| 方法 | 说明 |
|------|------|
| `register(_:)` | 注册单个音源 |
| `register(_:)` | 批量注册音源数组 |
| `remove(named:)` | 移除指定名称的音源 |
| `removeAll()` | 移除所有音源 |
| `match(...)` | 按优先级匹配，返回第一个成功结果 |
| `matchAll(...)` | 尝试所有音源，返回全部结果 |

### 内置音源

#### JSScriptSource — JS 脚本音源

支持导入第三方 JS 音源脚本文件。使用 `JavaScriptCore` 执行脚本。

JS 脚本需导出以下函数：
- `getUrl(songId, quality)` — 返回 `{ url: "...", quality: "..." }` 对象或 URL 字符串
- `getMusicInfo()`（可选）— 返回 `{ name: "音源名" }` 用于自动获取音源名称

```swift
// 从脚本内容初始化
let source = JSScriptSource(name: "我的音源", script: """
    function getUrl(songId, quality) {
        var resp = httpGet("https://my-api.example.com/song/" + songId + "?q=" + quality);
        var data = JSON.parse(resp);
        return { url: data.url, quality: quality };
    }
    function getMusicInfo() {
        return { name: "我的音源" };
    }
""")

// 从文件初始化
let source = try JSScriptSource(name: "第三方音源", fileURL: fileURL)
```

| 参数 | 类型 | 必选 | 说明 |
|------|------|------|------|
| name | String | ❌ | 音源名称，默认 `"JS音源"`（若脚本有 `getMusicInfo` 则自动获取） |
| script | String | ✅ | JS 脚本内容 |

> JS 脚本中可使用 `httpGet(url)` 发起同步 HTTP GET 请求，以及 `console.log()` 输出调试日志。

#### CustomURLSource — 自定义 HTTP 地址音源

支持自定义 HTTP API 地址，自动适配多种返回格式。

```swift
// 使用默认请求格式
let source = CustomURLSource(
    name: "自定义API",
    baseURL: "https://my-api.example.com/api.php"
)
// 默认请求: {baseURL}?types=url&id={id}&br={quality}

// 使用自定义 URL 模板
let source = CustomURLSource(
    name: "自定义API",
    baseURL: "https://my-api.example.com",
    urlTemplate: "{baseURL}/song/{id}?quality={quality}"
)
```

| 参数 | 类型 | 必选 | 说明 |
|------|------|------|------|
| name | String | ❌ | 音源名称，默认 `"自定义音源"` |
| baseURL | String | ✅ | API 基础地址 |
| urlTemplate | String? | ❌ | URL 模板，支持 `{id}`、`{quality}`、`{br}`、`{baseURL}` 占位符 |

**返回值兼容格式：**
- JSON 对象：`{ "url": "..." }` 或 `{ "data": "..." }` 或 `{ "data": { "url": "..." } }`
- 纯文本：直接返回以 `http` 开头的 URL 字符串

### 自定义音源

实现 `NCMUnblockSource` 协议即可接入任意第三方音源：

```swift
struct MyCustomSource: NCMUnblockSource {
    let name = "MySource"
    let sourceType: UnblockSourceType = .httpUrl

    func match(id: Int, title: String?, artist: String?, quality: String) async throws -> UnblockResult {
        // 自定义匹配逻辑
        let url = "https://my-api.example.com/song/\(id)"
        let (data, _) = try await URLSession.shared.data(from: URL(string: url)!)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return UnblockResult(
            url: json["url"] as? String ?? "",
            quality: quality,
            platform: "custom"
        )
    }
}

// 注册使用
let manager = UnblockManager()
manager.register(MyCustomSource())
```

### NCMClient 集成

#### songUrlUnblock — 使用管理器匹配

```swift
func songUrlUnblock(manager: UnblockManager, id: Int, title: String?, artist: String?, quality: String) async throws -> APIResponse
```

| 参数 | 类型 | 必选 | 说明 |
|------|------|------|------|
| manager | UnblockManager | ✅ | 解灰管理器实例 |
| id | Int | ✅ | 歌曲 ID |
| title | String? | ❌ | 歌曲名（辅助匹配） |
| artist | String? | ❌ | 歌手名（辅助匹配） |
| quality | String | ❌ | 期望音质，默认 `"320"` |

**调用例子：**

```swift
let manager = UnblockManager()

// 导入 JS 音源
let jsSource = JSScriptSource(name: "第三方音源", script: jsContent)
manager.register(jsSource)

// 添加自定义地址音源
let urlSource = CustomURLSource(name: "备用API", baseURL: "https://my-api.example.com/api.php")
manager.register(urlSource)

// 使用 NCMClient 解灰
let result = try await client.songUrlUnblock(manager: manager, id: 347230, quality: "320")
print(result.body)
```

---

## 架构设计

```
┌─────────────────────────────────────────────┐
│                  NCMClient                   │
│          (面向用户的统一入口)                   │
│                                              │
│  ┌─ serverUrl? ──→ 后端代理模式 (HTTP POST)   │
│  └─ nil ─────────→ 直连加密模式 ↓             │
├──────────────────────────────────────────────┤
│              RequestClient                    │
│     (URL 构建 · 加密分发 · HTTP 执行)          │
├──────────┬───────────┬───────────────────────┤
│CryptoEngine│SessionManager│   NCMConstants    │
│ AES-CBC    │ Cookie 管理  │   密钥 · 域名     │
│ AES-ECB    │ 设备元数据   │   公钥 · 常量     │
│ RSA        │ UA 选择      │                   │
│ MD5        │ EAPI Header  │                   │
└──────────┴───────────┴───────────────────────┘
```

### 三层架构

| 层级 | 模块 | 职责 |
|------|------|------|
| 加密层 | `CryptoEngine` | AES-CBC/ECB 加解密、RSA 无填充加密、MD5 哈希 |
| 网络层 | `RequestClient` | URL 路径重写、加密分发、HTTP POST、响应解密 |
| 会话层 | `SessionManager` | Cookie 管理、设备元数据、UA 选择、EAPI Header |
| 入口层 | `NCMClient` | 362 个 API 方法、后端代理路由、Cookie 设置 |

### API 扩展文件

| 文件 | 接口数 | 覆盖范围 |
|------|--------|----------|
| `NCMClient+Song.swift` | 26 | 歌曲、歌词、FM、红心 |
| `NCMClient+Playlist.swift` | 28 | 歌单 CRUD、收藏、导入 |
| `NCMClient+User.swift` | 25 | 用户信息、云盘、关注 |
| `NCMClient+DJ.swift` | 25 | 电台、播客、节目 |
| `NCMClient+VIP.swift` | 20 | VIP、云贝、签到 |
| `NCMClient+MV.swift` | 18 | MV、视频 |
| `NCMClient+Artist.swift` | 17 | 歌手信息、排行 |
| `NCMClient+Album.swift` | 14 | 专辑、数字专辑 |
| `NCMClient+Recommend.swift` | 14 | 推荐、个性化 |
| `NCMClient+Comment.swift` | 13 | 评论 CRUD |
| `NCMClient+Auth.swift` | 11 | 登录、注册、验证 |
| `NCMClient+Message.swift` | 10 | 私信、通知 |
| `NCMClient+Search.swift` | 8 | 搜索、热搜 |
| `NCMClient+Ranking.swift` | 8 | 排行榜 |
| `NCMClient+Cloud.swift` | 6 | 云盘上传 |
| `NCMClient+Unblock.swift` | 1 | 第三方解灰（JS 脚本 + 自定义地址） |
| `NCMClient+Misc.swift` | 119 | 其他全部接口 |

---

## 致谢

本项目的灵感和 API 参考来自以下优秀的开源项目：

- [Binaryify/NeteaseCloudMusicApi](https://github.com/Binaryify/NeteaseCloudMusicApi) — ncm Node.js API 服务，本项目的核心参考，364 个模块完整移植为原生 Swift
- [NeteaseCloudMusicApiEnhanced/api-enhanced](https://github.com/neteasecloudmusicapienhanced/api-enhanced) — ncm API 增强版，基于原版持续维护的社区项目
- [darknessomi/musicbox](https://github.com/darknessomi/musicbox) — ncm命令行客户端，加密算法参考
- [disoul/electron-cloud-music](https://github.com/nicerloop/electron-cloud-music) — ncm Electron 客户端
- [sqaiyan/netmusic-node](https://github.com/sqaiyan/netmusic-node) — ncm Node.js API 封装
- [UnblockNeteaseMusic](https://github.com/UnblockNeteaseMusic/server) — 解锁ncm灰色歌曲，第三方解灰功能参考

感谢以上项目的作者和贡献者们。
