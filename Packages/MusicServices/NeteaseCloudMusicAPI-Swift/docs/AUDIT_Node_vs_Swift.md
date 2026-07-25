# Node.js vs Swift 接口覆盖审计报告

本报告详细对比了 `NeteaseCloudMusicAPI` (Node.js) 与 `NeteaseCloudMusicAPI-Swift` 的接口实现情况。

## 审计说明

- **审计时间**: 2026-02-09
- **对比对象**:
    - Node.js 模块路径: `module/*.js`
    - Swift 实现路径: `Sources/NeteaseCloudMusicAPI/API/*.swift`
- **审计方法**: 自动化脚本提取 Node.js 模块中的 API 路径，并在 Swift 代码库中进行全量匹配搜索。

## 覆盖率摘要

- **总模块数**: 361
- **提取路径数**: 365
- **已覆盖路径**: 365
- **覆盖率**: **100.0%**

## 逻辑与默认值差异 (Logic & Default Value Differences)

虽然接口路径覆盖率达到了 100%，但在参数默认值和逻辑实现上，Node.js 原版与 Swift 版本存在以下已知差异（示例）：

### 1. 客户端类型默认值 (Client Type Defaults)
部分接口在未指定 `type` 参数时，默认的客户端标识不同。
*   **Banner (`banner.js`)**:
    *   **Node.js**: 默认 `type = 0` (PC)。
    *   **Swift**: 默认 `type = .iphone` (iPhone)。
*   **Search (Voice Mode)**:
    *   **Node.js**: 语音搜索模式下硬编码 `scene: 'normal'`。
    *   **Swift**: 允许传入 `scene` 参数，且默认值为空字符串 `""`。

### 2. 类型严格性 (Type Strictness)
*   **Node.js**: 依赖弱类型，通常直接透传 Query String 中的字符串（例如 `privacy: '0'`）。
*   **Swift**: 使用强类型，明确区分 `Int` 和 `String`（例如 `privacy: Int = 0`）。这通常更规范，但在极少数对类型敏感的后端接口中可能需要注意。

### 3. 硬编码逻辑
*   **Node.js**: 经常在模块内部通过 `query.xxx || default` 的方式处理逻辑。
*   **Swift**: 将这些逻辑转化为函数参数的默认值。大部分保持了一致，但如上述 `Banner` 的例子，存在根据平台习惯调整默认值的情况。

---

## 详细对比表

| Node 模块 | Node API 路径 | Swift 文件 | Swift 行号 | 状态 |
|---|---|---|---|---|
| **activate_init_profile.js** | `/api/activate/initProfile` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L556) | 556 | ✅ 已覆盖 |
| **aidj_content_rcmd.js** | `/api/aidj/content/rcmd/info` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L571) | 571 | ✅ 已覆盖 |
| **album.js** | `/api/v1/album/` | [NCMClient+Album.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Album.swift#L15) | 15 | ✅ 已覆盖 |
| **album_detail.js** | `/api/vipmall/albumproduct/detail` | [NCMClient+Album.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Album.swift#L118) | 118 | ✅ 已覆盖 |
| **album_detail_dynamic.js** | `/api/album/detail/dynamic` | [NCMClient+Album.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Album.swift#L29) | 29 | ✅ 已覆盖 |
| **album_list.js** | `/api/vipmall/albumproduct/list` | [NCMClient+Album.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Album.swift#L168) | 168 | ✅ 已覆盖 |
| **album_list_style.js** | `/api/vipmall/appalbum/album/style` | [NCMClient+Album.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Album.swift#L188) | 188 | ✅ 已覆盖 |
| **album_new.js** | `/api/album/new` | [NCMClient+Album.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Album.swift#L94) | 94 | ✅ 已覆盖 |
| **album_newest.js** | `/api/discovery/newAlbum` | [NCMClient+Album.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Album.swift#L104) | 104 | ✅ 已覆盖 |
| **album_privilege.js** | `/api/album/privilege` | [NCMClient+Album.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Album.swift#L196) | 196 | ✅ 已覆盖 |
| **album_songsaleboard.js** | `/api/feealbum/songsaleboard/` | [NCMClient+Album.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Album.swift#L216) | 216 | ✅ 已覆盖 |
| **album_sub.js** | `/api/album/` | [NCMClient+Album.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Album.swift#L29) | 29 | ✅ 已覆盖 |
| **album_sublist.js** | `/api/album/sublist` | [NCMClient+Album.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Album.swift#L70) | 70 | ✅ 已覆盖 |
| **artist_album.js** | `/api/artist/albums/` | [NCMClient+Artist.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Artist.swift#L78) | 78 | ✅ 已覆盖 |
| **artist_desc.js** | `/api/artist/introduction` | [NCMClient+Artist.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Artist.swift#L116) | 116 | ✅ 已覆盖 |
| **artist_detail.js** | `/api/artist/head/info/get` | [NCMClient+Artist.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Artist.swift#L18) | 18 | ✅ 已覆盖 |
| **artist_detail_dynamic.js** | `/api/artist/detail/dynamic` | [NCMClient+Artist.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Artist.swift#L230) | 230 | ✅ 已覆盖 |
| **artist_fans.js** | `/api/artist/fans/get` | [NCMClient+Artist.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Artist.swift#L245) | 245 | ✅ 已覆盖 |
| **artist_follow_count.js** | `/api/artist/follow/count/get` | [NCMClient+Artist.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Artist.swift#L253) | 253 | ✅ 已覆盖 |
| **artist_list.js** | `/api/v1/artist/list` | [NCMClient+Artist.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Artist.swift#L160) | 160 | ✅ 已覆盖 |
| **artist_mv.js** | `/api/artist/mvs` | [NCMClient+Artist.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Artist.swift#L102) | 102 | ✅ 已覆盖 |
| **artist_new_mv.js** | `/api/sub/artist/new/works/mv/list` | [NCMClient+Artist.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Artist.swift#L267) | 267 | ✅ 已覆盖 |
| **artist_new_song.js** | `/api/sub/artist/new/works/song/list` | [NCMClient+Artist.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Artist.swift#L281) | 281 | ✅ 已覆盖 |
| **artist_songs.js** | `/api/v1/artist/songs` | [NCMClient+Artist.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Artist.swift#L56) | 56 | ✅ 已覆盖 |
| **artist_sub.js** | `/api/artist/` | [NCMClient+Artist.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Artist.swift#L18) | 18 | ✅ 已覆盖 |
| **artist_sublist.js** | `/api/artist/sublist` | [NCMClient+Artist.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Artist.swift#L202) | 202 | ✅ 已覆盖 |
| **artist_top_song.js** | `/api/artist/top/song` | [NCMClient+Artist.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Artist.swift#L216) | 216 | ✅ 已覆盖 |
| **artist_video.js** | `/api/mlog/artist/video` | [NCMClient+Artist.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Artist.swift#L298) | 298 | ✅ 已覆盖 |
| **artists.js** | `/api/v1/artist/` | [NCMClient+Artist.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Artist.swift#L28) | 28 | ✅ 已覆盖 |
| **audio_match.js** | (无直接 API 调用) | - | - | ⚠️ 需人工核查 |
| **avatar_upload.js** | `/api/user/avatar/upload/v1` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L846) | 846 | ✅ 已覆盖 |
| **banner.js** | `/api/v2/banner/get` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L27) | 27 | ✅ 已覆盖 |
| **batch.js** | `/api/batch` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L39) | 39 | ✅ 已覆盖 |
| **broadcast_category_region_get.js** | `/api/voice/broadcast/category/region/get` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L425) | 425 | ✅ 已覆盖 |
| **broadcast_channel_collect_list.js** | `/api/content/channel/collect/list` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L434) | 434 | ✅ 已覆盖 |
| **broadcast_channel_currentinfo.js** | `/api/voice/broadcast/channel/currentinfo` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L439) | 439 | ✅ 已覆盖 |
| **broadcast_channel_list.js** | `/api/voice/broadcast/channel/list` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L448) | 448 | ✅ 已覆盖 |
| **broadcast_sub.js** | `/api/content/interact/collect` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L457) | 457 | ✅ 已覆盖 |
| **calendar.js** | `/api/mcalendar/detail` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L50) | 50 | ✅ 已覆盖 |
| **captcha_sent.js** | `/api/sms/captcha/sent` | [NCMClient+Auth.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Auth.swift#L89) | 89 | ✅ 已覆盖 |
| **captcha_verify.js** | `/api/sms/captcha/verify` | [NCMClient+Auth.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Auth.swift#L112) | 112 | ✅ 已覆盖 |
| **cellphone_existence_check.js** | `/api/cellphone/existence/check` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L577) | 577 | ✅ 已覆盖 |
| **check_music.js** | `/api/song/enhance/player/url` | [NCMClient+Song.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Song.swift#L38) | 38 | ✅ 已覆盖 |
| **cloud.js** | `/api/cloud/upload/check` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L872) | 872 | ✅ 已覆盖 |
| **cloud.js** | `/api/nos/token/alloc` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L837) | 837 | ✅ 已覆盖 |
| **cloud.js** | `/api/upload/cloud/info/v2` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L896) | 896 | ✅ 已覆盖 |
| **cloud.js** | `/api/cloud/pub/v2` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L903) | 903 | ✅ 已覆盖 |
| **cloud_import.js** | `/api/cloud/upload/check/v2` | [NCMClient+Cloud.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Cloud.swift#L107) | 107 | ✅ 已覆盖 |
| **cloud_import.js** | `/api/cloud/user/song/import` | [NCMClient+Cloud.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Cloud.swift#L124) | 124 | ✅ 已覆盖 |
| **cloud_lyric_get.js** | `/api/cloud/lyric/get` | [NCMClient+Cloud.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Cloud.swift#L141) | 141 | ✅ 已覆盖 |
| **cloud_match.js** | `/api/cloud/user/song/match` | [NCMClient+Cloud.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Cloud.swift#L74) | 74 | ✅ 已覆盖 |
| **cloudsearch.js** | `/api/cloudsearch/pc` | [NCMClient+Search.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Search.swift#L70) | 70 | ✅ 已覆盖 |
| **comment.js** | `/api/resource/comments/` | [NCMClient+Comment.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Comment.swift#L51) | 51 | ✅ 已覆盖 |
| **comment_album.js** | `/api/v1/resource/comments/R_AL_3_` | [NCMClient+Comment.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Comment.swift#L246) | 246 | ✅ 已覆盖 |
| **comment_dj.js** | `/api/v1/resource/comments/A_DJ_1_` | [NCMClient+Comment.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Comment.swift#L294) | 294 | ✅ 已覆盖 |
| **comment_event.js** | `/api/v1/resource/comments/` | [NCMClient+Comment.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Comment.swift#L196) | 196 | ✅ 已覆盖 |
| **comment_floor.js** | `/api/resource/comment/floor/get` | [NCMClient+Comment.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Comment.swift#L145) | 145 | ✅ 已覆盖 |
| **comment_hot.js** | `/api/v1/resource/hotcomments/` | [NCMClient+Comment.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Comment.swift#L113) | 113 | ✅ 已覆盖 |
| **comment_hug_list.js** | `/api/v2/resource/comments/hug/list` | [NCMClient+Comment.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Comment.swift#L343) | 343 | ✅ 已覆盖 |
| **comment_like.js** | `/api/v1/comment/` | [NCMClient+Comment.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Comment.swift#L171) | 171 | ✅ 已覆盖 |
| **comment_music.js** | `/api/v1/resource/comments/R_SO_4_` | [NCMClient+Comment.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Comment.swift#L196) | 196 | ✅ 已覆盖 |
| **comment_mv.js** | `/api/v1/resource/comments/R_MV_5_` | [NCMClient+Comment.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Comment.swift#L271) | 271 | ✅ 已覆盖 |
| **comment_new.js** | `/api/v2/resource/comments` | [NCMClient+Comment.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Comment.swift#L85) | 85 | ✅ 已覆盖 |
| **comment_playlist.js** | `/api/v1/resource/comments/A_PL_0_` | [NCMClient+Comment.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Comment.swift#L221) | 221 | ✅ 已覆盖 |
| **comment_video.js** | `/api/v1/resource/comments/R_VI_62_` | [NCMClient+Comment.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Comment.swift#L360) | 360 | ✅ 已覆盖 |
| **countries_code_list.js** | `/api/lbs/countries/v1` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L44) | 44 | ✅ 已覆盖 |
| **creator_authinfo_get.js** | `/api/user/creator/authinfo/get` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L582) | 582 | ✅ 已覆盖 |
| **daily_signin.js** | `/api/point/dailyTask` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L103) | 103 | ✅ 已覆盖 |
| **digitalAlbum_detail.js** | `/api/vipmall/albumproduct/detail` | [NCMClient+Album.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Album.swift#L118) | 118 | ✅ 已覆盖 |
| **digitalAlbum_ordering.js** | `/api/ordering/web/digital` | [NCMClient+Album.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Album.swift#L233) | 233 | ✅ 已覆盖 |
| **digitalAlbum_purchased.js** | `/api/digitalAlbum/purchased` | [NCMClient+Album.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Album.swift#L139) | 139 | ✅ 已覆盖 |
| **digitalAlbum_sales.js** | `/api/vipmall/albumproduct/album/query/sales` | [NCMClient+Album.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Album.swift#L241) | 241 | ✅ 已覆盖 |
| **djRadio_top.js** | `/api/expert/worksdata/works/top/get` | [NCMClient+DJ.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+DJ.swift#L350) | 350 | ✅ 已覆盖 |
| **dj_banner.js** | `/api/djradio/banner/get` | [NCMClient+DJ.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+DJ.swift#L207) | 207 | ✅ 已覆盖 |
| **dj_category_excludehot.js** | `/api/djradio/category/excludehot` | [NCMClient+DJ.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+DJ.swift#L213) | 213 | ✅ 已覆盖 |
| **dj_category_recommend.js** | `/api/djradio/home/category/recommend` | [NCMClient+DJ.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+DJ.swift#L219) | 219 | ✅ 已覆盖 |
| **dj_catelist.js** | `/api/djradio/category/get` | [NCMClient+DJ.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+DJ.swift#L110) | 110 | ✅ 已覆盖 |
| **dj_detail.js** | `/api/djradio/v2/get` | [NCMClient+DJ.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+DJ.swift#L18) | 18 | ✅ 已覆盖 |
| **dj_hot.js** | `/api/djradio/hot/v1` | [NCMClient+DJ.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+DJ.swift#L195) | 195 | ✅ 已覆盖 |
| **dj_paygift.js** | `/api/djradio/home/paygift/list` | [NCMClient+DJ.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+DJ.swift#L233) | 233 | ✅ 已覆盖 |
| **dj_personalize_recommend.js** | `/api/djradio/personalize/rcmd` | [NCMClient+DJ.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+DJ.swift#L241) | 241 | ✅ 已覆盖 |
| **dj_program.js** | `/api/dj/program/byradio` | [NCMClient+DJ.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+DJ.swift#L44) | 44 | ✅ 已覆盖 |
| **dj_program_detail.js** | `/api/dj/program/detail` | [NCMClient+DJ.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+DJ.swift#L58) | 58 | ✅ 已覆盖 |
| **dj_program_toplist.js** | `/api/program/toplist/v1` | [NCMClient+DJ.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+DJ.swift#L100) | 100 | ✅ 已覆盖 |
| **dj_program_toplist_hours.js** | `/api/djprogram/toplist/hours` | [NCMClient+DJ.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+DJ.swift#L249) | 249 | ✅ 已覆盖 |
| **dj_radio_hot.js** | `/api/djradio/hot` | [NCMClient+DJ.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+DJ.swift#L264) | 264 | ✅ 已覆盖 |
| **dj_recommend.js** | `/api/djradio/recommend/v1` | [NCMClient+DJ.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+DJ.swift#L120) | 120 | ✅ 已覆盖 |
| **dj_recommend_type.js** | `/api/djradio/recommend` | [NCMClient+DJ.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+DJ.swift#L134) | 134 | ✅ 已覆盖 |
| **dj_sub.js** | `/api/djradio/` | [NCMClient+User.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+User.swift#L212) | 212 | ✅ 已覆盖 |
| **dj_sublist.js** | `/api/djradio/get/subed` | [NCMClient+DJ.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+DJ.swift#L175) | 175 | ✅ 已覆盖 |
| **dj_subscriber.js** | `/api/djradio/subscriber` | [NCMClient+DJ.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+DJ.swift#L281) | 281 | ✅ 已覆盖 |
| **dj_today_perfered.js** | `/api/djradio/home/today/perfered` | [NCMClient+DJ.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+DJ.swift#L289) | 289 | ✅ 已覆盖 |
| **dj_toplist.js** | `/api/djradio/toplist` | [NCMClient+DJ.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+DJ.swift#L80) | 80 | ✅ 已覆盖 |
| **dj_toplist_hours.js** | `/api/dj/toplist/hours` | [NCMClient+DJ.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+DJ.swift#L297) | 297 | ✅ 已覆盖 |
| **dj_toplist_newcomer.js** | `/api/dj/toplist/newcomer` | [NCMClient+DJ.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+DJ.swift#L310) | 310 | ✅ 已覆盖 |
| **dj_toplist_pay.js** | `/api/djradio/toplist/pay` | [NCMClient+DJ.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+DJ.swift#L318) | 318 | ✅ 已覆盖 |
| **dj_toplist_popular.js** | `/api/dj/toplist/popular` | [NCMClient+DJ.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+DJ.swift#L326) | 326 | ✅ 已覆盖 |
| **event.js** | `/api/v1/event/get` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L465) | 465 | ✅ 已覆盖 |
| **event_del.js** | `/api/event/delete` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L470) | 470 | ✅ 已覆盖 |
| **event_forward.js** | `/api/event/forward` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L476) | 476 | ✅ 已覆盖 |
| **fanscenter_basicinfo_age_get.js** | `/api/fanscenter/basicinfo/age/get` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L253) | 253 | ✅ 已覆盖 |
| **fanscenter_basicinfo_gender_get.js** | `/api/fanscenter/basicinfo/gender/get` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L258) | 258 | ✅ 已覆盖 |
| **fanscenter_basicinfo_province_get.js** | `/api/fanscenter/basicinfo/province/get` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L263) | 263 | ✅ 已覆盖 |
| **fanscenter_overview_get.js** | `/api/fanscenter/overview/get` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L268) | 268 | ✅ 已覆盖 |
| **fanscenter_trend_list.js** | `/api/fanscenter/trend/list` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L279) | 279 | ✅ 已覆盖 |
| **fm_trash.js** | `/api/radio/trash/add` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L98) | 98 | ✅ 已覆盖 |
| **follow.js** | `/api/user/` | [NCMClient+VIP.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+VIP.swift#L66) | 66 | ✅ 已覆盖 |
| **get_userids.js** | `/api/user/getUserIds` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L587) | 587 | ✅ 已覆盖 |
| **history_recommend_songs.js** | `/api/discovery/recommend/songs/history/recent` | [NCMClient+Recommend.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Recommend.swift#L154) | 154 | ✅ 已覆盖 |
| **history_recommend_songs_detail.js** | `/api/discovery/recommend/songs/history/detail` | [NCMClient+Recommend.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Recommend.swift#L162) | 162 | ✅ 已覆盖 |
| **homepage_block_page.js** | `/api/homepage/block/page` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L544) | 544 | ✅ 已覆盖 |
| **homepage_dragon_ball.js** | `/api/homepage/dragon/ball/static` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L549) | 549 | ✅ 已覆盖 |
| **hot_topic.js** | `/api/act/hot` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L500) | 500 | ✅ 已覆盖 |
| **hug_comment.js** | `/api/v2/resource/comments/hug/listener` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L603) | 603 | ✅ 已覆盖 |
| **like.js** | `/api/radio/like` | [NCMClient+Song.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Song.swift#L155) | 155 | ✅ 已覆盖 |
| **likelist.js** | `/api/song/like/get` | [NCMClient+Song.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Song.swift#L169) | 169 | ✅ 已覆盖 |
| **listen_data_realtime_report.js** | `/api/content/activity/listen/data/realtime/report` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L185) | 185 | ✅ 已覆盖 |
| **listen_data_report.js** | `/api/content/activity/listen/data/report` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L192) | 192 | ✅ 已覆盖 |
| **listen_data_today_song.js** | `/api/content/activity/listen/data/today/song/play/rank` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L197) | 197 | ✅ 已覆盖 |
| **listen_data_total.js** | `/api/content/activity/listen/data/total` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L202) | 202 | ✅ 已覆盖 |
| **listen_data_year_report.js** | `/api/content/activity/listen/data/year/report` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L207) | 207 | ✅ 已覆盖 |
| **listentogether_accept.js** | `/api/listen/together/play/invitation/accept` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L127) | 127 | ✅ 已覆盖 |
| **listentogether_end.js** | `/api/listen/together/end/v2` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L132) | 132 | ✅ 已覆盖 |
| **listentogether_heatbeat.js** | `/api/listen/together/heartbeat` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L138) | 138 | ✅ 已覆盖 |
| **listentogether_play_command.js** | `/api/listen/together/play/command/report` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L148) | 148 | ✅ 已覆盖 |
| **listentogether_room_check.js** | `/api/listen/together/room/check` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L153) | 153 | ✅ 已覆盖 |
| **listentogether_room_create.js** | `/api/listen/together/room/create` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L158) | 158 | ✅ 已覆盖 |
| **listentogether_status.js** | `/api/listen/together/status/get` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L163) | 163 | ✅ 已覆盖 |
| **listentogether_sync_list_command.js** | `/api/listen/together/sync/list/command/report` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L173) | 173 | ✅ 已覆盖 |
| **listentogether_sync_playlist_get.js** | `/api/listen/together/sync/playlist/get` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L178) | 178 | ✅ 已覆盖 |
| **login.js** | `/api/w/login` | [NCMClient+Auth.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Auth.swift#L60) | 60 | ✅ 已覆盖 |
| **login_cellphone.js** | `/api/w/login/cellphone` | [NCMClient+Auth.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Auth.swift#L37) | 37 | ✅ 已覆盖 |
| **login_qr_check.js** | `/api/login/qrcode/client/login` | [NCMClient+Auth.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Auth.swift#L159) | 159 | ✅ 已覆盖 |
| **login_qr_create.js** | (无直接 API 调用) | - | - | ⚠️ 需人工核查 |
| **login_qr_key.js** | `/api/login/qrcode/unikey` | [NCMClient+Auth.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Auth.swift#L125) | 125 | ✅ 已覆盖 |
| **login_refresh.js** | `/api/login/token/refresh` | [NCMClient+Auth.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Auth.swift#L178) | 178 | ✅ 已覆盖 |
| **login_status.js** | `/api/w/nuser/account/get` | [NCMClient+Auth.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Auth.swift#L168) | 168 | ✅ 已覆盖 |
| **logout.js** | `/api/logout` | [NCMClient+Auth.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Auth.swift#L69) | 69 | ✅ 已覆盖 |
| **lyric.js** | `/api/song/lyric` | [NCMClient+Song.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Song.swift#L116) | 116 | ✅ 已覆盖 |
| **lyric_new.js** | `/api/song/lyric/v1` | [NCMClient+Song.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Song.swift#L137) | 137 | ✅ 已覆盖 |
| **mlog_music_rcmd.js** | `/api/mlog/rcmd/feed/list` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L511) | 511 | ✅ 已覆盖 |
| **mlog_to_video.js** | `/api/mlog/video/convert/id` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L516) | 516 | ✅ 已覆盖 |
| **mlog_url.js** | `/api/mlog/detail/v1` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L522) | 522 | ✅ 已覆盖 |
| **msg_comments.js** | `/api/v1/user/comments/` | [NCMClient+Message.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Message.swift#L199) | 199 | ✅ 已覆盖 |
| **msg_forwards.js** | `/api/forwards/get` | [NCMClient+Message.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Message.swift#L213) | 213 | ✅ 已覆盖 |
| **msg_notices.js** | `/api/msg/notices` | [NCMClient+Message.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Message.swift#L166) | 166 | ✅ 已覆盖 |
| **msg_private.js** | `/api/msg/private/users` | [NCMClient+Message.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Message.swift#L25) | 25 | ✅ 已覆盖 |
| **msg_private_history.js** | `/api/msg/private/history` | [NCMClient+Message.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Message.swift#L51) | 51 | ✅ 已覆盖 |
| **msg_recentcontact.js** | `/api/msg/recentcontact/get` | [NCMClient+Message.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Message.swift#L176) | 176 | ✅ 已覆盖 |
| **music_first_listen_info.js** | `/api/content/activity/music/first/listen/info` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L608) | 608 | ✅ 已覆盖 |
| **musician_cloudbean.js** | `/api/cloudbean/get` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L214) | 214 | ✅ 已覆盖 |
| **musician_cloudbean_obtain.js** | `/api/nmusician/workbench/mission/reward/obtain/new` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L220) | 220 | ✅ 已覆盖 |
| **musician_data_overview.js** | `/api/creator/musician/statistic/data/overview/get` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L225) | 225 | ✅ 已覆盖 |
| **musician_play_trend.js** | `/api/creator/musician/play/count/statistic/data/trend/get` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L231) | 231 | ✅ 已覆盖 |
| **musician_sign.js** | `/api/creator/user/access` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L236) | 236 | ✅ 已覆盖 |
| **musician_tasks.js** | `/api/nmusician/workbench/mission/cycle/list` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L241) | 241 | ✅ 已覆盖 |
| **musician_tasks_new.js** | `/api/nmusician/workbench/mission/stage/list ` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L246) | 246 | ✅ 已覆盖 |
| **mv_all.js** | `/api/mv/all` | [NCMClient+MV.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+MV.swift#L85) | 85 | ✅ 已覆盖 |
| **mv_detail.js** | `/api/v1/mv/detail` | [NCMClient+MV.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+MV.swift#L18) | 18 | ✅ 已覆盖 |
| **mv_detail_info.js** | `/api/comment/commentthread/info` | [NCMClient+MV.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+MV.swift#L33) | 33 | ✅ 已覆盖 |
| **mv_exclusive_rcmd.js** | `/api/mv/exclusive/rcmd` | [NCMClient+MV.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+MV.swift#L126) | 126 | ✅ 已覆盖 |
| **mv_first.js** | `/api/mv/first` | [NCMClient+MV.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+MV.swift#L107) | 107 | ✅ 已覆盖 |
| **mv_sub.js** | `/api/mv/` | [NCMClient+MV.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+MV.swift#L85) | 85 | ✅ 已覆盖 |
| **mv_sublist.js** | `/api/cloudvideo/allvideo/sublist` | [NCMClient+MV.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+MV.swift#L167) | 167 | ✅ 已覆盖 |
| **mv_url.js** | `/api/song/enhance/play/mv/url` | [NCMClient+MV.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+MV.swift#L50) | 50 | ✅ 已覆盖 |
| **nickname_check.js** | `/api/nickname/duplicated` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L613) | 613 | ✅ 已覆盖 |
| **personal_fm.js** | `/api/v1/radio/get` | [NCMClient+Recommend.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Recommend.swift#L109) | 109 | ✅ 已覆盖 |
| **personal_fm_mode.js** | `/api/v1/radio/get` | [NCMClient+Recommend.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Recommend.swift#L109) | 109 | ✅ 已覆盖 |
| **personalized.js** | `/api/personalized/playlist` | [NCMClient+Recommend.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Recommend.swift#L21) | 21 | ✅ 已覆盖 |
| **personalized_djprogram.js** | `/api/personalized/djprogram` | [NCMClient+Recommend.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Recommend.swift#L136) | 136 | ✅ 已覆盖 |
| **personalized_mv.js** | `/api/personalized/mv` | [NCMClient+Recommend.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Recommend.swift#L48) | 48 | ✅ 已覆盖 |
| **personalized_newsong.js** | `/api/personalized/newsong` | [NCMClient+Recommend.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Recommend.swift#L38) | 38 | ✅ 已覆盖 |
| **personalized_privatecontent.js** | `/api/personalized/privatecontent` | [NCMClient+Recommend.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Recommend.swift#L58) | 58 | ✅ 已覆盖 |
| **personalized_privatecontent_list.js** | `/api/v2/privatecontent/list` | [NCMClient+Recommend.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Recommend.swift#L79) | 79 | ✅ 已覆盖 |
| **pl_count.js** | `/api/pl/count` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L618) | 618 | ✅ 已覆盖 |
| **playlist_category_list.js** | `/api/playlist/category/list` | [NCMClient+Playlist.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Playlist.swift#L304) | 304 | ✅ 已覆盖 |
| **playlist_catlist.js** | `/api/playlist/catalogue` | [NCMClient+Playlist.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Playlist.swift#L220) | 220 | ✅ 已覆盖 |
| **playlist_cover_update.js** | `/api/playlist/cover/update` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L857) | 857 | ✅ 已覆盖 |
| **playlist_create.js** | `/api/playlist/create` | [NCMClient+Playlist.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Playlist.swift#L27) | 27 | ✅ 已覆盖 |
| **playlist_delete.js** | `/api/playlist/remove` | [NCMClient+Playlist.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Playlist.swift#L41) | 41 | ✅ 已覆盖 |
| **playlist_desc_update.js** | `/api/playlist/desc/update` | [NCMClient+Playlist.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Playlist.swift#L314) | 314 | ✅ 已覆盖 |
| **playlist_detail.js** | `/api/v6/playlist/detail` | [NCMClient+Playlist.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Playlist.swift#L83) | 83 | ✅ 已覆盖 |
| **playlist_detail_dynamic.js** | `/api/playlist/detail/dynamic` | [NCMClient+Playlist.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Playlist.swift#L98) | 98 | ✅ 已覆盖 |
| **playlist_detail_rcmd_get.js** | `/api/playlist/detail/rcmd/get` | [NCMClient+Playlist.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Playlist.swift#L326) | 326 | ✅ 已覆盖 |
| **playlist_highquality_tags.js** | `/api/playlist/highquality/tags` | [NCMClient+Playlist.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Playlist.swift#L332) | 332 | ✅ 已覆盖 |
| **playlist_hot.js** | `/api/playlist/hottags` | [NCMClient+Playlist.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Playlist.swift#L230) | 230 | ✅ 已覆盖 |
| **playlist_import_name_task_create.js** | `/api/playlist/import/name/task/create` | [NCMClient+Playlist.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Playlist.swift#L355) | 355 | ✅ 已覆盖 |
| **playlist_import_task_status.js** | `/api/playlist/import/task/status/v2` | [NCMClient+Playlist.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Playlist.swift#L365) | 365 | ✅ 已覆盖 |
| **playlist_mylike.js** | `/api/mlog/playlist/mylike/bytime/get` | [NCMClient+Playlist.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Playlist.swift#L379) | 379 | ✅ 已覆盖 |
| **playlist_name_update.js** | `/api/playlist/update/name` | [NCMClient+Playlist.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Playlist.swift#L389) | 389 | ✅ 已覆盖 |
| **playlist_order_update.js** | `/api/playlist/order/update` | [NCMClient+Playlist.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Playlist.swift#L397) | 397 | ✅ 已覆盖 |
| **playlist_privacy.js** | `/api/playlist/update/privacy` | [NCMClient+Playlist.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Playlist.swift#L405) | 405 | ✅ 已覆盖 |
| **playlist_subscribe.js** | `/api/playlist/` | [NCMClient+Ranking.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Ranking.swift#L171) | 171 | ✅ 已覆盖 |
| **playlist_subscribers.js** | `/api/playlist/subscribers` | [NCMClient+Playlist.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Playlist.swift#L211) | 211 | ✅ 已覆盖 |
| **playlist_tags_update.js** | `/api/playlist/tags/update` | [NCMClient+Playlist.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Playlist.swift#L415) | 415 | ✅ 已覆盖 |
| **playlist_track_add.js** | `/api/playlist/track/add` | [NCMClient+Playlist.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Playlist.swift#L429) | 429 | ✅ 已覆盖 |
| **playlist_track_all.js** | `/api/v6/playlist/detail` | [NCMClient+Playlist.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Playlist.swift#L83) | 83 | ✅ 已覆盖 |
| **playlist_track_all.js** | `/api/v3/song/detail` | [NCMClient+Song.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Song.swift#L19) | 19 | ✅ 已覆盖 |
| **playlist_track_delete.js** | `/api/playlist/track/delete` | [NCMClient+Playlist.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Playlist.swift#L443) | 443 | ✅ 已覆盖 |
| **playlist_tracks.js** | `/api/playlist/manipulate/tracks` | [NCMClient+Song.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Song.swift#L359) | 359 | ✅ 已覆盖 |
| **playlist_tracks.js** | `/api/playlist/manipulate/tracks` | [NCMClient+Song.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Song.swift#L359) | 359 | ✅ 已覆盖 |
| **playlist_update.js** | `/api/batch` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L39) | 39 | ✅ 已覆盖 |
| **playlist_update_playcount.js** | `/api/playlist/update/playcount` | [NCMClient+Playlist.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Playlist.swift#L451) | 451 | ✅ 已覆盖 |
| **playlist_video_recent.js** | `/api/playlist/video/recent` | [NCMClient+Playlist.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Playlist.swift#L457) | 457 | ✅ 已覆盖 |
| **playmode_intelligence_list.js** | `/api/playmode/intelligence/list` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L627) | 627 | ✅ 已覆盖 |
| **playmode_song_vector.js** | `/api/playmode/song/vector/get` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L632) | 632 | ✅ 已覆盖 |
| **program_recommend.js** | `/api/program/recommend/v1` | [NCMClient+Recommend.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Recommend.swift#L177) | 177 | ✅ 已覆盖 |
| **rebind.js** | `/api/user/replaceCellphone` | [NCMClient+User.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+User.swift#L353) | 353 | ✅ 已覆盖 |
| **recent_listen_list.js** | `/api/pc/recent/listen/list` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L637) | 637 | ✅ 已覆盖 |
| **recommend_resource.js** | `/api/v1/discovery/recommend/resource` | [NCMClient+Recommend.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Recommend.swift#L99) | 99 | ✅ 已覆盖 |
| **recommend_songs.js** | `/api/v3/discovery/recommend/songs` | [NCMClient+Recommend.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Recommend.swift#L89) | 89 | ✅ 已覆盖 |
| **recommend_songs_dislike.js** | `/api/v2/discovery/recommend/dislike` | [NCMClient+Recommend.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Recommend.swift#L148) | 148 | ✅ 已覆盖 |
| **record_recent_album.js** | `/api/play-record/album/list` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L642) | 642 | ✅ 已覆盖 |
| **record_recent_dj.js** | `/api/play-record/djradio/list` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L647) | 647 | ✅ 已覆盖 |
| **record_recent_playlist.js** | `/api/play-record/playlist/list` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L652) | 652 | ✅ 已覆盖 |
| **record_recent_song.js** | `/api/play-record/song/list` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L657) | 657 | ✅ 已覆盖 |
| **record_recent_video.js** | `/api/play-record/newvideo/list` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L662) | 662 | ✅ 已覆盖 |
| **record_recent_voice.js** | `/api/play-record/voice/list` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L667) | 667 | ✅ 已覆盖 |
| **register_anonimous.js** | `/api/register/anonimous` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L776) | 776 | ✅ 已覆盖 |
| **register_cellphone.js** | `/api/w/register/cellphone` | [NCMClient+Auth.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Auth.swift#L207) | 207 | ✅ 已覆盖 |
| **related_allvideo.js** | `/api/cloudvideo/v1/allvideo/rcmd` | [NCMClient+MV.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+MV.swift#L313) | 313 | ✅ 已覆盖 |
| **related_playlist.js** | (无直接 API 调用) | - | - | ⚠️ 需人工核查 |
| **resource_like.js** | `/api/resource/` | [NCMClient+Comment.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Comment.swift#L51) | 51 | ✅ 已覆盖 |
| **scrobble.js** | `/api/feedback/weblog` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L720) | 720 | ✅ 已覆盖 |
| **search.js** | `/api/search/voice/get` | [NCMClient+Search.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Search.swift#L33) | 33 | ✅ 已覆盖 |
| **search.js** | `/api/search/get` | [NCMClient+Search.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Search.swift#L44) | 44 | ✅ 已覆盖 |
| **search_default.js** | `/api/search/defaultkeyword/get` | [NCMClient+Search.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Search.swift#L108) | 108 | ✅ 已覆盖 |
| **search_hot.js** | `/api/search/hot` | [NCMClient+Search.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Search.swift#L135) | 135 | ✅ 已覆盖 |
| **search_hot_detail.js** | `/api/hotsearchlist/get` | [NCMClient+Search.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Search.swift#L79) | 79 | ✅ 已覆盖 |
| **search_match.js** | `/api/search/match/new` | [NCMClient+Search.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Search.swift#L155) | 155 | ✅ 已覆盖 |
| **search_multimatch.js** | `/api/search/suggest/multimatch` | [NCMClient+Search.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Search.swift#L122) | 122 | ✅ 已覆盖 |
| **search_suggest.js** | `/api/search/suggest/` | [NCMClient+Search.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Search.swift#L98) | 98 | ✅ 已覆盖 |
| **send_album.js** | `/api/msg/private/send` | [NCMClient+Message.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Message.swift#L73) | 73 | ✅ 已覆盖 |
| **send_playlist.js** | `/api/msg/private/send` | [NCMClient+Message.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Message.swift#L73) | 73 | ✅ 已覆盖 |
| **send_song.js** | `/api/msg/private/send` | [NCMClient+Message.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Message.swift#L73) | 73 | ✅ 已覆盖 |
| **send_text.js** | `/api/msg/private/send` | [NCMClient+Message.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Message.swift#L73) | 73 | ✅ 已覆盖 |
| **setting.js** | `/api/user/setting` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L725) | 725 | ✅ 已覆盖 |
| **share_resource.js** | `/api/share/friends/resource` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L673) | 673 | ✅ 已覆盖 |
| **sheet_list.js** | `/api/music/sheet/list/v1` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L530) | 530 | ✅ 已覆盖 |
| **sheet_preview.js** | `/api/music/sheet/preview/info` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L535) | 535 | ✅ 已覆盖 |
| **sign_happy_info.js** | `/api/sign/happy/info` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L678) | 678 | ✅ 已覆盖 |
| **signin_progress.js** | `/api/act/modules/signin/v2/progress` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L683) | 683 | ✅ 已覆盖 |
| **simi_artist.js** | `/api/discovery/simiArtist` | [NCMClient+Artist.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Artist.swift#L130) | 130 | ✅ 已覆盖 |
| **simi_mv.js** | `/api/discovery/simiMV` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L78) | 78 | ✅ 已覆盖 |
| **simi_playlist.js** | `/api/discovery/simiPlaylist` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L62) | 62 | ✅ 已覆盖 |
| **simi_song.js** | `/api/v1/discovery/simiSong` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L72) | 72 | ✅ 已覆盖 |
| **simi_user.js** | `/api/discovery/simiUser` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L88) | 88 | ✅ 已覆盖 |
| **song_chorus.js** | `/api/song/chorus` | [NCMClient+Song.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Song.swift#L235) | 235 | ✅ 已覆盖 |
| **song_detail.js** | `/api/v3/song/detail` | [NCMClient+Song.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Song.swift#L19) | 19 | ✅ 已覆盖 |
| **song_downlist.js** | `/api/member/song/downlist` | [NCMClient+Song.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Song.swift#L249) | 249 | ✅ 已覆盖 |
| **song_download_url.js** | `/api/song/enhance/download/url` | [NCMClient+Song.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Song.swift#L98) | 98 | ✅ 已覆盖 |
| **song_download_url_v1.js** | `/api/song/enhance/download/url/v1` | [NCMClient+Song.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Song.swift#L263) | 263 | ✅ 已覆盖 |
| **song_dynamic_cover.js** | `/api/songplay/dynamic-cover` | [NCMClient+Song.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Song.swift#L271) | 271 | ✅ 已覆盖 |
| **song_like_check.js** | `/api/song/like/check` | [NCMClient+Song.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Song.swift#L279) | 279 | ✅ 已覆盖 |
| **song_lyrics_mark.js** | `/api/song/play/lyrics/mark/song` | [NCMClient+Song.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Song.swift#L287) | 287 | ✅ 已覆盖 |
| **song_lyrics_mark_add.js** | `/api/song/play/lyrics/mark/add` | [NCMClient+Song.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Song.swift#L302) | 302 | ✅ 已覆盖 |
| **song_lyrics_mark_del.js** | `/api/song/play/lyrics/mark/del` | [NCMClient+Song.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Song.swift#L310) | 310 | ✅ 已覆盖 |
| **song_lyrics_mark_user_page.js** | `/api/song/play/lyrics/mark/user/page` | [NCMClient+Song.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Song.swift#L323) | 323 | ✅ 已覆盖 |
| **song_monthdownlist.js** | `/api/member/song/monthdownlist` | [NCMClient+Song.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Song.swift#L337) | 337 | ✅ 已覆盖 |
| **song_music_detail.js** | `/api/song/music/detail/get` | [NCMClient+Song.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Song.swift#L345) | 345 | ✅ 已覆盖 |
| **song_order_update.js** | `/api/playlist/manipulate/tracks` | [NCMClient+Song.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Song.swift#L359) | 359 | ✅ 已覆盖 |
| **song_purchased.js** | `/api/single/mybought/song/list` | [NCMClient+Song.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Song.swift#L372) | 372 | ✅ 已覆盖 |
| **song_red_count.js** | `/api/song/red/count` | [NCMClient+Song.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Song.swift#L380) | 380 | ✅ 已覆盖 |
| **song_singledownlist.js** | `/api/member/song/singledownlist` | [NCMClient+Song.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Song.swift#L394) | 394 | ✅ 已覆盖 |
| **song_url.js** | `/api/song/enhance/player/url` | [NCMClient+Song.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Song.swift#L38) | 38 | ✅ 已覆盖 |
| **song_url_match.js** | (无直接 API 调用) | - | - | ⚠️ 需人工核查 |
| **song_url_ncmget.js** | (无直接 API 调用) | - | - | ⚠️ 需人工核查 |
| **song_url_v1.js** | `/api/song/enhance/player/url/v1` | [NCMClient+Song.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Song.swift#L66) | 66 | ✅ 已覆盖 |
| **song_wiki_summary.js** | `/api/song/play/about/block/page` | [NCMClient+Song.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Song.swift#L402) | 402 | ✅ 已覆盖 |
| **starpick_comments_summary.js** | `/api/homepage/block/page` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L544) | 544 | ✅ 已覆盖 |
| **style_album.js** | `/api/style-tag/home/album` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L287) | 287 | ✅ 已覆盖 |
| **style_artist.js** | `/api/style-tag/home/artist` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L293) | 293 | ✅ 已覆盖 |
| **style_detail.js** | `/api/style-tag/home/head` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L298) | 298 | ✅ 已覆盖 |
| **style_list.js** | `/api/tag/list/get` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L303) | 303 | ✅ 已覆盖 |
| **style_playlist.js** | `/api/style-tag/home/playlist` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L309) | 309 | ✅ 已覆盖 |
| **style_preference.js** | `/api/tag/my/preference/get` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L314) | 314 | ✅ 已覆盖 |
| **style_song.js** | `/api/style-tag/home/song` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L320) | 320 | ✅ 已覆盖 |
| **summary_annual.js** | `/api/activity/summary/annual/` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L695) | 695 | ✅ 已覆盖 |
| **threshold_detail_get.js** | `/api/influencer/web/apply/threshold/detail/get` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L700) | 700 | ✅ 已覆盖 |
| **top_album.js** | `/api/discovery/new/albums/area` | [NCMClient+Ranking.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Ranking.swift#L123) | 123 | ✅ 已覆盖 |
| **top_artists.js** | `/api/artist/top` | [NCMClient+Ranking.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Ranking.swift#L59) | 59 | ✅ 已覆盖 |
| **top_list.js** | `/api/playlist/v4/detail` | [NCMClient+Ranking.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Ranking.swift#L171) | 171 | ✅ 已覆盖 |
| **top_mv.js** | `/api/mv/toplist` | [NCMClient+Ranking.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Ranking.swift#L147) | 147 | ✅ 已覆盖 |
| **top_playlist.js** | `/api/playlist/list` | [NCMClient+Playlist.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Playlist.swift#L257) | 257 | ✅ 已覆盖 |
| **top_playlist_highquality.js** | `/api/playlist/highquality/list` | [NCMClient+Playlist.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Playlist.swift#L283) | 283 | ✅ 已覆盖 |
| **top_song.js** | `/api/v1/discovery/new/songs` | [NCMClient+Ranking.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Ranking.swift#L38) | 38 | ✅ 已覆盖 |
| **topic_detail.js** | `/api/act/detail` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L483) | 483 | ✅ 已覆盖 |
| **topic_detail_event_hot.js** | `/api/act/event/hot` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L488) | 488 | ✅ 已覆盖 |
| **topic_sublist.js** | `/api/topic/sublist` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L494) | 494 | ✅ 已覆盖 |
| **toplist.js** | `/api/toplist` | [NCMClient+Ranking.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Ranking.swift#L14) | 14 | ✅ 已覆盖 |
| **toplist_artist.js** | `/api/toplist/artist` | [NCMClient+Ranking.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Ranking.swift#L85) | 85 | ✅ 已覆盖 |
| **toplist_detail.js** | `/api/toplist/detail` | [NCMClient+Ranking.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Ranking.swift#L23) | 23 | ✅ 已覆盖 |
| **toplist_detail_v2.js** | `/api/toplist/detail/v2` | [NCMClient+Ranking.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Ranking.swift#L159) | 159 | ✅ 已覆盖 |
| **ugc_album_get.js** | `/api/rep/ugc/album/get` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L327) | 327 | ✅ 已覆盖 |
| **ugc_artist_get.js** | `/api/rep/ugc/artist/get` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L332) | 332 | ✅ 已覆盖 |
| **ugc_artist_search.js** | `/api/rep/ugc/artist/search` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L338) | 338 | ✅ 已覆盖 |
| **ugc_detail.js** | `/api/rep/ugc/detail` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L347) | 347 | ✅ 已覆盖 |
| **ugc_mv_get.js** | `/api/rep/ugc/mv/get` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L352) | 352 | ✅ 已覆盖 |
| **ugc_song_get.js** | `/api/rep/ugc/song/get` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L357) | 357 | ✅ 已覆盖 |
| **ugc_user_devote.js** | `/api/rep/ugc/user/devote` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L362) | 362 | ✅ 已覆盖 |
| **user_account.js** | `/api/nuser/account/get` | [NCMClient+User.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+User.swift#L139) | 139 | ✅ 已覆盖 |
| **user_audio.js** | `/api/djradio/get/byuser` | [NCMClient+User.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+User.swift#L212) | 212 | ✅ 已覆盖 |
| **user_binding.js** | `/api/v1/user/bindings/` | [NCMClient+User.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+User.swift#L150) | 150 | ✅ 已覆盖 |
| **user_bindingcellphone.js** | `/api/user/bindingCellphone` | [NCMClient+User.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+User.swift#L234) | 234 | ✅ 已覆盖 |
| **user_cloud.js** | `/api/v1/cloud/get` | [NCMClient+Cloud.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Cloud.swift#L24) | 24 | ✅ 已覆盖 |
| **user_cloud_del.js** | `/api/cloud/del` | [NCMClient+Cloud.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Cloud.swift#L55) | 55 | ✅ 已覆盖 |
| **user_cloud_detail.js** | `/api/v1/cloud/get/byids` | [NCMClient+Cloud.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Cloud.swift#L41) | 41 | ✅ 已覆盖 |
| **user_comment_history.js** | `/api/comment/user/comment/history` | [NCMClient+User.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+User.swift#L252) | 252 | ✅ 已覆盖 |
| **user_detail.js** | `/api/v1/user/detail/` | [NCMClient+User.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+User.swift#L15) | 15 | ✅ 已覆盖 |
| **user_detail_new.js** | `/api/w/v1/user/detail/` | [NCMClient+User.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+User.swift#L263) | 263 | ✅ 已覆盖 |
| **user_dj.js** | `/api/dj/program/` | [NCMClient+User.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+User.swift#L277) | 277 | ✅ 已覆盖 |
| **user_event.js** | `/api/event/get/` | [NCMClient+User.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+User.swift#L294) | 294 | ✅ 已覆盖 |
| **user_follow_mixed.js** | `/api/user/follow/users/mixed/get/v2` | [NCMClient+User.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+User.swift#L312) | 312 | ✅ 已覆盖 |
| **user_followeds.js** | `/api/user/getfolloweds/` | [NCMClient+User.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+User.swift#L109) | 109 | ✅ 已覆盖 |
| **user_follows.js** | `/api/user/getfollows/` | [NCMClient+User.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+User.swift#L82) | 82 | ✅ 已覆盖 |
| **user_level.js** | `/api/user/level` | [NCMClient+User.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+User.swift#L119) | 119 | ✅ 已覆盖 |
| **user_medal.js** | `/api/medal/user/page` | [NCMClient+User.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+User.swift#L320) | 320 | ✅ 已覆盖 |
| **user_mutualfollow_get.js** | `/api/user/mutualfollow/get` | [NCMClient+User.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+User.swift#L328) | 328 | ✅ 已覆盖 |
| **user_playlist.js** | `/api/user/playlist` | [NCMClient+User.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+User.swift#L39) | 39 | ✅ 已覆盖 |
| **user_record.js** | `/api/v1/play/record` | [NCMClient+User.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+User.swift#L59) | 59 | ✅ 已覆盖 |
| **user_replacephone.js** | `/api/user/replaceCellphone` | [NCMClient+User.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+User.swift#L353) | 353 | ✅ 已覆盖 |
| **user_social_status.js** | `/api/social/user/status` | [NCMClient+User.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+User.swift#L361) | 361 | ✅ 已覆盖 |
| **user_social_status_edit.js** | `/api/social/user/status/edit` | [NCMClient+User.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+User.swift#L379) | 379 | ✅ 已覆盖 |
| **user_social_status_rcmd.js** | `/api/social/user/status/rcmd` | [NCMClient+User.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+User.swift#L385) | 385 | ✅ 已覆盖 |
| **user_social_status_support.js** | `/api/social/user/status/support` | [NCMClient+User.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+User.swift#L391) | 391 | ✅ 已覆盖 |
| **user_subcount.js** | `/api/subcount` | [NCMClient+User.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+User.swift#L129) | 129 | ✅ 已覆盖 |
| **user_update.js** | `/api/user/profile/update` | [NCMClient+User.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+User.swift#L199) | 199 | ✅ 已覆盖 |
| **verify_getQr.js** | `/api/frontrisk/verify/getqrcode` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L710) | 710 | ✅ 已覆盖 |
| **verify_qrcodestatus.js** | `/api/frontrisk/verify/qrcodestatus` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L715) | 715 | ✅ 已覆盖 |
| **video_category_list.js** | `/api/cloudvideo/category/list` | [NCMClient+MV.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+MV.swift#L253) | 253 | ✅ 已覆盖 |
| **video_detail.js** | `/api/cloudvideo/v1/video/detail` | [NCMClient+MV.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+MV.swift#L181) | 181 | ✅ 已覆盖 |
| **video_detail_info.js** | `/api/comment/commentthread/info` | [NCMClient+MV.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+MV.swift#L33) | 33 | ✅ 已覆盖 |
| **video_group.js** | `/api/videotimeline/videogroup/otherclient/get` | [NCMClient+MV.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+MV.swift#L268) | 268 | ✅ 已覆盖 |
| **video_group_list.js** | `/api/cloudvideo/group/list` | [NCMClient+MV.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+MV.swift#L274) | 274 | ✅ 已覆盖 |
| **video_sub.js** | `/api/cloudvideo/video/` | [NCMClient+MV.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+MV.swift#L233) | 233 | ✅ 已覆盖 |
| **video_timeline_all.js** | `/api/videotimeline/otherclient/get` | [NCMClient+MV.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+MV.swift#L287) | 287 | ✅ 已覆盖 |
| **video_timeline_recommend.js** | `/api/videotimeline/get` | [NCMClient+MV.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+MV.swift#L301) | 301 | ✅ 已覆盖 |
| **video_url.js** | `/api/cloudvideo/playurl` | [NCMClient+MV.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+MV.swift#L213) | 213 | ✅ 已覆盖 |
| **vip_growthpoint.js** | `/api/vipnewcenter/app/level/growhpoint/basic` | [NCMClient+VIP.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+VIP.swift#L96) | 96 | ✅ 已覆盖 |
| **vip_growthpoint_details.js** | `/api/vipnewcenter/app/level/growth/details` | [NCMClient+VIP.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+VIP.swift#L116) | 116 | ✅ 已覆盖 |
| **vip_growthpoint_get.js** | `/api/vipnewcenter/app/level/task/reward/get` | [NCMClient+VIP.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+VIP.swift#L130) | 130 | ✅ 已覆盖 |
| **vip_info.js** | `/api/music-vip-membership/front/vip/info` | [NCMClient+VIP.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+VIP.swift#L15) | 15 | ✅ 已覆盖 |
| **vip_info_v2.js** | `/api/music-vip-membership/client/vip/info` | [NCMClient+VIP.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+VIP.swift#L26) | 26 | ✅ 已覆盖 |
| **vip_sign.js** | `/api/vip-center-bff/task/sign` | [NCMClient+VIP.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+VIP.swift#L36) | 36 | ✅ 已覆盖 |
| **vip_sign_info.js** | `/api/vipnewcenter/app/user/sign/info` | [NCMClient+VIP.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+VIP.swift#L136) | 136 | ✅ 已覆盖 |
| **vip_tasks.js** | `/api/vipnewcenter/app/level/task/list` | [NCMClient+VIP.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+VIP.swift#L142) | 142 | ✅ 已覆盖 |
| **vip_timemachine.js** | `/api/vipmusic/newrecord/weekflow` | [NCMClient+VIP.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+VIP.swift#L160) | 160 | ✅ 已覆盖 |
| **voice_delete.js** | `/api/content/voice/delete` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L369) | 369 | ✅ 已覆盖 |
| **voice_detail.js** | `/api/voice/workbench/voice/detail` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L374) | 374 | ✅ 已覆盖 |
| **voice_lyric.js** | `/api/voice/lyric/get` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L379) | 379 | ✅ 已覆盖 |
| **voice_upload.js** | `/api/nos/token/alloc` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L837) | 837 | ✅ 已覆盖 |
| **voice_upload.js** | `/api/voice/workbench/voice/batch/upload/preCheck` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L914) | 914 | ✅ 已覆盖 |
| **voice_upload.js** | `/api/voice/workbench/voice/batch/upload/v2` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L925) | 925 | ✅ 已覆盖 |
| **voicelist_detail.js** | `/api/voice/workbench/voicelist/detail` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L384) | 384 | ✅ 已覆盖 |
| **voicelist_list.js** | `/api/voice/workbench/voices/by/voicelist` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L390) | 390 | ✅ 已覆盖 |
| **voicelist_list_search.js** | `/api/voice/workbench/voice/list` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L403) | 403 | ✅ 已覆盖 |
| **voicelist_search.js** | `/api/voice/workbench/voicelist/search` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L409) | 409 | ✅ 已覆盖 |
| **voicelist_trans.js** | `/api/voice/workbench/radio/program/trans` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L418) | 418 | ✅ 已覆盖 |
| **weblog.js** | `/api/feedback/weblog` | [NCMClient+Misc.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+Misc.swift#L720) | 720 | ✅ 已覆盖 |
| **yunbei.js** | `/api/point/signed/get` | [NCMClient+VIP.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+VIP.swift#L166) | 166 | ✅ 已覆盖 |
| **yunbei_expense.js** | `/api/point/expense` | [NCMClient+VIP.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+VIP.swift#L176) | 176 | ✅ 已覆盖 |
| **yunbei_info.js** | `/api/v1/user/info` | [NCMClient+VIP.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+VIP.swift#L46) | 46 | ✅ 已覆盖 |
| **yunbei_rcmd_song.js** | `/api/yunbei/rcmd/song/submit` | [NCMClient+VIP.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+VIP.swift#L193) | 193 | ✅ 已覆盖 |
| **yunbei_rcmd_song_history.js** | `/api/yunbei/rcmd/song/history/list` | [NCMClient+VIP.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+VIP.swift#L204) | 204 | ✅ 已覆盖 |
| **yunbei_receipt.js** | `/api/point/receipt` | [NCMClient+VIP.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+VIP.swift#L214) | 214 | ✅ 已覆盖 |
| **yunbei_sign.js** | `/api/pointmall/user/sign` | [NCMClient+VIP.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+VIP.swift#L56) | 56 | ✅ 已覆盖 |
| **yunbei_task_finish.js** | `/api/usertool/task/point/receive` | [NCMClient+VIP.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+VIP.swift#L86) | 86 | ✅ 已覆盖 |
| **yunbei_tasks.js** | `/api/usertool/task/list/all` | [NCMClient+VIP.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+VIP.swift#L66) | 66 | ✅ 已覆盖 |
| **yunbei_tasks_todo.js** | `/api/usertool/task/todo/query` | [NCMClient+VIP.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+VIP.swift#L220) | 220 | ✅ 已覆盖 |
| **yunbei_today.js** | `/api/point/today/get` | [NCMClient+VIP.swift](file://Sources/NeteaseCloudMusicAPI/API/NCMClient+VIP.swift#L226) | 226 | ✅ 已覆盖 |
