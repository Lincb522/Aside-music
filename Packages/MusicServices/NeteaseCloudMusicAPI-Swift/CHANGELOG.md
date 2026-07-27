# 更新日志

## 1.4.0 (2026-05-24)

### 新功能
- 对齐 NeteaseCloudMusicApiEnhanced 4.33.0，新增 28 个后端模块的 Swift 调用入口
- 新增 `backendRoute(_:data:)`，支持直接调用 Mono 本地增强后端模块
- 接入 Mono 本地增强接口：`bannerBackup`、`podcastHomeTab`、`songQualities`、`songUrlNcmget`、`playShorten`

### 改进
- `RouteMap` 补齐 4.33.0 新增模块和本地增强模块映射，避免代理模式回退路由不透明
- 同步 4.33.0 老接口变化：`recommendSongs(afresh:)`、`userFolloweds` 默认分页、`voicelistSearch(keyword:)`、`vipSign` 请求模式
- README 与主工程 Package 注释更新为 4.33.0 / 396+ 路由口径

---

## 1.3.6 (2026-02-09)

### 修复

---

## 1.3.5 (2026-02-08)

### 新功能
- **JSScriptSource 日志回调**：新增 `logHandler` 属性，console.log、HTTP 请求地址、响应状态、JS 异常等内部信息可被外部捕获，不再只输出到控制台
- **测试模式**：新增 `testMode` 属性，开启后 `matchLxFormat` 遍历所有平台（wy、kw、mg、qq 等）而非匹配到就返回
- **平台结果收集**：新增 `testPlatformResults` 属性，测试模式下记录每个平台的成功/失败状态

### 改进
- `httpGet`（简单格式）和 `lxRequest`（洛雪格式）的 HTTP 请求地址、响应状态码均通过 `emitLog` 输出
- JS 异常处理改为通过 `emitLog` 统一输出，外部可捕获
- `matchLxFormat` 每个平台的匹配结果（成功/失败/错误）均通过 `emitLog` 输出

---

## 1.3.4 (2026-02-08)

### 修复
- **JS 音源多源回退**：`matchLxFormat` 支持多 sourceKey 依次尝试（wy → QQ → 酷我 → 咪咕等），不再只试 `wy` 一个源就放弃
- 修复 `musicInfo.source` 硬编码为 `'wy'` 的问题，现在正确传递当前尝试的 sourceKey
- `lxSources` 改为 `public` 访问级别，供外部调试日志读取支持平台列表

### 改进
- 全量参数审计：修复 71 个后端代理模式下 SDK 参数名与后端期望参数名不匹配的问题
- 涵盖 songId→id、userId→uid、artistId→id、trackId→id、cellphone→phone、threadId 解析等多种转换模式
- 评论相关接口（comment_new/floor/hug_list/hug_comment）自动从 threadId 解析出 id + type
- 搜索预建议：type 路径参数提取 + s/keyword→keywords 转换
- 电台详情：id→rid 转换

---

## 1.3.2 (2026-02-08)

### 修复
- 搜索预建议不弹出：`/api/search/suggest/mobile` 经动态路由匹配后 `type`（mobile）丢失，后端 `search_suggest.js` 收不到 `type` 参数
- 搜索预建议参数：SDK 传 `s`，后端期望 `keywords`，新增 `adaptParams` 转换

---

## 1.3.1 (2026-02-08)

### 修复
- 移除不存在的 `SoundQualityType.higher` case，修复 `songUrlV1` 编译错误

---

## 1.3.0 (2026-02-08)

### 新功能

### 修复
- 动态路由路径参数丢失：user/detail、album、artists 等接口经过动态路由匹配后 ID/UID 从路径中被丢弃，后端返回 400 参数错误
- dynamicRoutes 新增 paramName 字段，adaptParams 统一从路径尾部提取参数注入请求体

---

## 1.2.1 (2026-02-08)

### 修复
- 后端代理请求格式：Content-Type 从 `application/json` 改为 `application/x-www-form-urlencoded`，兼容性更好
- URL-encoded 编码使用严格字符集，正确编码 `+`、`=`、`&` 等特殊字符
- Banner 参数适配：`clientType` 字符串自动转换为后端期望的 `type` 数字（0=pc, 1=android, 2=iphone, 3=ipad）
- DEBUG 日志增强：打印参数实际值（截断到 60 字符），方便排查问题

---

## 1.2.0 (2026-02-08)

### 新功能
- 后端代理路由映射表：323 条静态路由 + 43 条动态前缀，100% 覆盖 SDK 全部 349 个 API 路径
- 代理模式参数适配层：自动转换 song_url_v1、song_detail、cloudsearch 等接口的参数格式

### 修复
- 后端代理模式 404：旧版 NeteaseCloudMusicApi 路由格式与ncm原始 API 路径不匹配，新增 RouteMap 完整映射
- 二维码登录 400：`/api/login/qrcode/unikey` 正确映射到后端 `/login/qr/key`

---

## 1.1.0 (2026-02-08)

### 新功能
- JS 音源自动检测脚本格式，兼容洛雪插件格式（自动模拟 `globalThis.lx` 事件环境）
- 自定义地址音源支持 URL 模板（`{id}`、`{quality}`、`{baseURL}` 占位符）

### 修复
- VIP 任务解析：正确展平 `taskList[].taskItems[]` 子数组
- VIP 成长值：从 `data.userLevel.growthPoint` 正确读取

### 示例应用
- VIP 任务显示增加完成状态标签
- Info.plist 改为 `NSAllowsArbitraryLoads`（第三方音源域名不可预知）

### 文档

---

## 1.0.0 (2026-02-07)

首个正式版本。

### 核心
- 362 个ncm API 原生 Swift 封装
- 四种加密模式：WeAPI / EAPI / LinuxAPI / 明文
- 后端代理模式 + 直连加密模式
- async/await、强类型枚举、完整中文注释
- Apple 全系平台：iOS 15+ / macOS 12+ / tvOS 15+ / watchOS 8+
- 零外部依赖（仅 Foundation + CommonCrypto）

### 示例应用
- 二维码登录、Cookie 管理、播放测试
- Xcode 16 文件系统同步组

### 文档
- Docsify 在线文档，白绿主题
- 完整 API 参考（362 个接口）
- 架构设计说明
