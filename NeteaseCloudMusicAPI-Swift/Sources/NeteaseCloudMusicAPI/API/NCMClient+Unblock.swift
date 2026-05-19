// NCMClient+Unblock.swift
// 第三方解灰模块
// 支持导入 JS 音源脚本和自定义音源地址两种方式
// 用于获取灰色（无版权）歌曲的可用播放链接

import Foundation
import JavaScriptCore

// MARK: - 音源协议

/// 第三方音源协议
/// 实现此协议可接入任意第三方音源
public protocol NCMUnblockSource {
    /// 音源名称
    var name: String { get }
    /// 音源类型标识
    var sourceType: UnblockSourceType { get }
    /// 匹配歌曲，返回可用播放链接
    func match(id: Int, title: String?, artist: String?, quality: String) async throws -> UnblockResult
}

/// 音源类型
public enum UnblockSourceType: String, Codable {
    /// JS 脚本音源（导入 .js 文件）
    case jsScript = "js"
    /// 自定义 HTTP 地址音源
    case httpUrl = "http"
}

/// 解灰匹配结果
public struct UnblockResult {
    /// 歌曲播放 URL
    public let url: String
    /// 实际音质
    public let quality: String
    /// 来源平台/音源名称
    public let platform: String
    /// 额外信息
    public let extra: [String: Any]

    public init(url: String, quality: String = "", platform: String = "", extra: [String: Any] = [:]) {
        self.url = url
        self.quality = quality
        self.platform = platform
        self.extra = extra
    }
}

// MARK: - JS 脚本音源

/// JS 脚本音源
/// 支持导入第三方 JS 音源脚本文件
/// 自动检测脚本格式：
/// - 洛雪插件格式：依赖 globalThis.lx 事件系统，SDK 自动模拟运行环境
/// - 简单函数格式：导出 getUrl(songId, quality) 函数
public class JSScriptSource: NCMUnblockSource {
    public private(set) var name: String
    public let sourceType: UnblockSourceType = .jsScript
    /// JS 脚本内容
    public let scriptContent: String
    /// 是否为洛雪插件格式
    public let isLxFormat: Bool
    /// JS 执行上下文
    private let context: JSContext
    /// 洛雪格式：注册的请求处理器
    private var lxRequestHandler: JSValue?
    /// 洛雪格式：支持的音源列表
    public var lxSources: [String: Any] = [:]

    /// 日志回调，外部可设置此闭包捕获所有内部日志
    /// 参数为日志字符串，包含 console.log、HTTP 请求/响应、JS 异常、匹配过程等
    /// 未设置时日志仅输出到控制台（print）
    public var logHandler: ((String) -> Void)?

    /// 是否开启测试模式
    /// 开启后 matchLxFormat 会遍历所有平台（wy、kw、mg、qq 等），而非匹配到就返回
    public var testMode: Bool = false

    /// 测试模式下各平台的匹配结果
    /// key = 平台标识（如 "kw"、"mg"），value = 匹配到的 URL（空字符串表示失败）
    public var testPlatformResults: [String: String] = [:]

    /// 内部日志输出，同时发送给 logHandler 和 print
    private func emitLog(_ message: String) {
        logHandler?(message)
        print(message)
    }

    /// 从 JS 脚本内容初始化
    /// - Parameters:
    ///   - name: 音源名称（自动从脚本注释或 inited 事件中获取）
    ///   - script: JS 脚本内容
    public init(name: String = "JS音源", script: String) {
        self.scriptContent = script
        self.context = JSContext()!
        // 检测是否为洛雪插件格式
        self.isLxFormat = script.contains("globalThis.lx") || script.contains("EVENT_NAMES")

        // 先赋临时名称，满足 Swift 存储属性初始化要求
        self.name = name

        // 注入 console — 通过 emitLog 输出，外部可捕获
        // 注意：init 阶段 logHandler 还未设置，但 closure 捕获的是 self（weak），
        // 后续设置 logHandler 后 console.log 就会走回调
        let emitRef: @convention(block) (JSValue) -> Void = { [weak self] msg in
            self?.emitLog("[JSSource] \(msg)")
        }
        let groupRef: @convention(block) (JSValue) -> Void = { [weak self] msg in
            self?.emitLog("[JSSource] ▸ \(msg)")
        }
        let groupEndHandler: @convention(block) () -> Void = {
            // 忽略 groupEnd
        }
        context.setObject(emitRef, forKeyedSubscript: "___log" as NSString)
        context.setObject(groupRef, forKeyedSubscript: "___group" as NSString)
        context.setObject(groupEndHandler, forKeyedSubscript: "___groupEnd" as NSString)
        context.evaluateScript("""
            var console = {
                log: function() { var args = Array.prototype.slice.call(arguments); ___log(args.map(function(a) { try { return typeof a === 'object' ? JSON.stringify(a) : String(a); } catch(e) { return String(a); } }).join(' ')); },
                warn: function() { var args = Array.prototype.slice.call(arguments); ___log(args.map(function(a) { try { return typeof a === 'object' ? JSON.stringify(a) : String(a); } catch(e) { return String(a); } }).join(' ')); },
                error: function() { var args = Array.prototype.slice.call(arguments); ___log(args.map(function(a) { try { return typeof a === 'object' ? JSON.stringify(a) : String(a); } catch(e) { return String(a); } }).join(' ')); },
                group: function() { var args = Array.prototype.slice.call(arguments); ___group(args.join(' ')); },
                groupEnd: ___groupEnd
            };
        """)

        // 注入同步 HTTP 请求（简单格式用）
        let httpGetEmit: @convention(block) (String) -> String = { [weak self] urlStr in
            self?.emitLog("[JSSource] HTTP GET \(urlStr)")
            guard let url = URL(string: urlStr) else {
                self?.emitLog("[JSSource] ⚠️ 无效 URL: \(urlStr)")
                return ""
            }
            let semaphore = DispatchSemaphore(value: 0)
            var result = ""
            var respCode = 0
            let task = URLSession.shared.dataTask(with: url) { data, resp, error in
                respCode = (resp as? HTTPURLResponse)?.statusCode ?? 0
                if let error = error {
                    self?.emitLog("[JSSource] ❌ HTTP 错误: \(error.localizedDescription)")
                } else if let data = data, let str = String(data: data, encoding: .utf8) {
                    result = str
                }
                semaphore.signal()
            }
            task.resume()
            semaphore.wait()
            self?.emitLog("[JSSource] HTTP 响应 \(respCode) 长度=\(result.count)")
            return result
        }
        context.setObject(httpGetEmit, forKeyedSubscript: "httpGet" as NSString)

        // 先赋临时名称，满足 Swift 存储属性初始化要求
        self.name = name

        if isLxFormat {
            // 模拟洛雪运行环境
            self.setupLxEnvironment()
        }

        // 异常处理
        context.exceptionHandler = { [weak self] _, exception in
            if let ex = exception {
                self?.emitLog("[JSSource] ⚠️ JS 异常: \(ex)")
            }
        }

        // 执行脚本
        emitLog("[JSSource] 📦 加载脚本 (\(script.count) 字符, 格式: \(isLxFormat ? "洛雪插件" : "简单函数"))")
        context.evaluateScript(script)

        // 获取音源名称（覆盖临时值）
        // 优先从脚本注释中提取 @name
        if let range = script.range(of: #"@name\s+(.+)"#, options: .regularExpression) {
            let matched = String(script[range])
            let nameValue = matched.replacingOccurrences(of: #"@name\s+"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
            if !nameValue.isEmpty {
                self.name = nameValue
            }
        }
        // 简单格式：尝试 getMusicInfo()
        if !isLxFormat {
            if let info = context.evaluateScript("typeof getMusicInfo === 'function' ? getMusicInfo() : null"),
               !info.isNull, !info.isUndefined,
               let dict = info.toDictionary(),
               let scriptName = dict["name"] as? String {
                self.name = scriptName
            }
        }
    }

    /// 从文件 URL 初始化
    public convenience init(name: String = "JS音源", fileURL: URL) throws {
        let script = try String(contentsOf: fileURL, encoding: .utf8)
        self.init(name: name, script: script)
    }

    /// 模拟洛雪 globalThis.lx 运行环境
    private func setupLxEnvironment() {
        // 存储事件处理器的容器
        context.evaluateScript("""
            var ___lxHandlers = {};
            var ___lxSources = {};
            var ___lxInited = false;
        """)

        // 注入同步 HTTP 请求（洛雪 request 格式）
        // request(url, options, callback) -> callback(err, resp)
        let lxRequest: @convention(block) (String, JSValue, JSValue) -> Void = { [weak self] urlStr, optionsVal, callback in
            let options = optionsVal.toDictionary() ?? [:]
            let method = (options["method"] as? String) ?? "GET"
            self?.emitLog("[JSSource] HTTP \(method) \(urlStr)")

            guard let url = URL(string: urlStr) else {
                self?.emitLog("[JSSource] ⚠️ 无效 URL: \(urlStr)")
                callback.call(withArguments: ["无效 URL", NSNull()])
                return
            }
            let headers = options["headers"] as? [String: String] ?? [:]

            var request = URLRequest(url: url)
            request.httpMethod = method
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
            if let bodyData = options["body"] as? String {
                request.httpBody = bodyData.data(using: .utf8)
            }

            let semaphore = DispatchSemaphore(value: 0)
            var responseBody: Any = NSNull()
            var responseError: Any = NSNull()
            var statusCode = 200
            var dataSize = 0

            let task = URLSession.shared.dataTask(with: request) { data, resp, error in
                if let error = error {
                    responseError = error.localizedDescription
                } else if let data = data {
                    statusCode = (resp as? HTTPURLResponse)?.statusCode ?? 200
                    dataSize = data.count
                    // 尝试解析 JSON
                    if let json = try? JSONSerialization.jsonObject(with: data) {
                        responseBody = json
                    } else if let text = String(data: data, encoding: .utf8) {
                        responseBody = text
                    }
                }
                semaphore.signal()
            }
            task.resume()
            semaphore.wait()

            if !(responseError is NSNull) {
                self?.emitLog("[JSSource] ❌ HTTP 错误: \(responseError)")
                callback.call(withArguments: [responseError, NSNull()])
            } else {
                self?.emitLog("[JSSource] HTTP 响应 \(statusCode) 大小=\(dataSize)字节")
                // 构造 resp 对象: { statusCode, body, headers }
                let respObj: [String: Any] = [
                    "statusCode": statusCode,
                    "body": responseBody,
                    "headers": [String: String]()
                ]
                callback.call(withArguments: [NSNull(), respObj])
            }
        }
        context.setObject(lxRequest, forKeyedSubscript: "___lxRequest" as NSString)

        // on(eventName, handler) — 注册事件处理器
        let lxOn: @convention(block) (String, JSValue) -> Void = { [weak self] eventName, handler in
            self?.context.evaluateScript("___lxHandlers['\(eventName)'] = true;")
            if eventName == "request" {
                self?.lxRequestHandler = handler
            }
        }
        context.setObject(lxOn, forKeyedSubscript: "___lxOn" as NSString)

        // send(eventName, data) — 发送事件
        let lxSend: @convention(block) (String, JSValue) -> Void = { [weak self] eventName, data in
            if eventName == "inited" {
                if let dict = data.toDictionary(),
                   let sources = dict["sources"] as? [String: Any] {
                    self?.lxSources = sources
                }
            }
        }
        context.setObject(lxSend, forKeyedSubscript: "___lxSend" as NSString)

        // 注入 globalThis.lx 对象
        context.evaluateScript("""
            var globalThis = globalThis || this;
            globalThis.lx = {
                EVENT_NAMES: {
                    request: 'request',
                    inited: 'inited',
                    updateAlert: 'updateAlert'
                },
                request: ___lxRequest,
                on: ___lxOn,
                send: ___lxSend,
                utils: {},
                env: 'mobile',
                version: '2.0.0'
            };
            var lx = globalThis.lx;
        """)
    }

    public func match(id: Int, title: String?, artist: String?, quality: String) async throws -> UnblockResult {
        if isLxFormat {
            return try await matchLxFormat(id: id, title: title, artist: artist, quality: quality)
        } else {
            return try await matchSimpleFormat(id: id, quality: quality)
        }
    }

    /// 简单格式：调用 getUrl(songId, quality)
    private func matchSimpleFormat(id: Int, quality: String) async throws -> UnblockResult {
        emitLog("[JSSource] 🔍 简单格式匹配: id=\(id) quality=\(quality)")
        guard let getUrl = context.objectForKeyedSubscript("getUrl"),
              !getUrl.isUndefined else {
            emitLog("[JSSource] ❌ 脚本未导出 getUrl 函数")
            throw NCMError.invalidURL
        }

        let jsResult = getUrl.call(withArguments: [id, quality])

        if let dict = jsResult?.toDictionary(),
           let url = dict["url"] as? String, !url.isEmpty {
            emitLog("[JSSource] ✅ 匹配成功: \(url.prefix(80))")
            return UnblockResult(
                url: url,
                quality: dict["quality"] as? String ?? quality,
                platform: name,
                extra: dict as? [String: Any] ?? [:]
            )
        } else if let urlStr = jsResult?.toString(), !urlStr.isEmpty, urlStr != "undefined", urlStr != "null" {
            emitLog("[JSSource] ✅ 匹配成功: \(urlStr.prefix(80))")
            return UnblockResult(url: urlStr, quality: quality, platform: name)
        }

        emitLog("[JSSource] ❌ 匹配失败: 返回空结果")
        return UnblockResult(url: "", quality: quality, platform: name)
    }

    /// 洛雪格式：通过事件系统调用
    private func matchLxFormat(id: Int, title: String?, artist: String?, quality: String) async throws -> UnblockResult {
        guard lxRequestHandler != nil else {
            emitLog("[JSSource] ❌ 洛雪格式: 无 request handler")
            throw NCMError.invalidURL
        }

        // 收集所有要尝试的平台
        let allSourceKeys: [String]
        if testMode {
            // 测试模式：遍历所有平台
            allSourceKeys = Array(lxSources.keys).sorted()
            testPlatformResults.removeAll()
            emitLog("[JSSource] 🧪 测试模式: 遍历 \(allSourceKeys.count) 个平台 [\(allSourceKeys.joined(separator: ", "))]")
        } else {
            // 正常模式：优先 wy，然后依次尝试其他平台
            var keys: [String] = []
            if lxSources.keys.contains("wy") { keys.append("wy") }
            for k in lxSources.keys.sorted() where k != "wy" { keys.append(k) }
            if keys.isEmpty { keys.append("wy") }
            allSourceKeys = keys
        }

        // 映射音质：320 -> 320k, 128 -> 128k, flac 等
        let lxQuality: String
        switch quality {
        case "128": lxQuality = "128k"
        case "192": lxQuality = "192k"
        case "320": lxQuality = "320k"
        case "740", "flac": lxQuality = "flac"
        case "999": lxQuality = "flac24bit"
        default:
            if quality.hasSuffix("k") || quality.contains("flac") || quality.contains("hires") || quality.contains("atmos") || quality.contains("master") {
                lxQuality = quality
            } else {
                lxQuality = quality + "k"
            }
        }

        let songName = (title ?? "").replacingOccurrences(of: "'", with: "\\'").replacingOccurrences(of: "\n", with: "")
        let artistName = (artist ?? "").replacingOccurrences(of: "'", with: "\\'").replacingOccurrences(of: "\n", with: "")

        emitLog("[JSSource] 🔍 洛雪格式匹配: id=\(id) \"\(songName)\" - \"\(artistName)\" quality=\(lxQuality)")

        let ctx = self.context
        let handler = self.lxRequestHandler!
        let sourceName = self.name

        // 逐平台尝试
        var firstSuccessResult: UnblockResult?

        for sourceKey in allSourceKeys {
            emitLog("[JSSource] 🔄 尝试平台: \(sourceKey)")

            let result: UnblockResult? = try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    var resolvedUrl: String?
                    var resolvedError: String?
                    let semaphore = DispatchSemaphore(value: 0)

                    let onSuccess: @convention(block) (String) -> Void = { url in
                        resolvedUrl = url
                        semaphore.signal()
                    }
                    let onError: @convention(block) (String) -> Void = { err in
                        resolvedError = err
                        semaphore.signal()
                    }
                    ctx.setObject(onSuccess, forKeyedSubscript: "___onMatchSuccess" as NSString)
                    ctx.setObject(onError, forKeyedSubscript: "___onMatchError" as NSString)
                    ctx.setObject(handler, forKeyedSubscript: "___lxRequestHandler" as NSString)

                    let jsCall = """
                    (function() {
                        try {
                            var handler = ___lxRequestHandler;
                            if (!handler) { ___onMatchError('no handler'); return; }
                            var result = handler({
                                action: 'musicUrl',
                                source: '\(sourceKey)',
                                info: {
                                    type: '\(lxQuality)',
                                    musicInfo: {
                                        songmid: \(id),
                                        hash: '\(id)',
                                        name: '\(songName)',
                                        singer: '\(artistName)',
                                        source: '\(sourceKey)'
                                    }
                                }
                            });
                            if (result && typeof result.then === 'function') {
                                result.then(function(url) {
                                    ___onMatchSuccess(String(url || ''));
                                })['catch'](function(err) {
                                    ___onMatchError(String(err || 'unknown'));
                                });
                            } else {
                                ___onMatchSuccess(String(result || ''));
                            }
                        } catch(e) {
                            ___onMatchError(String(e));
                        }
                    })();
                    """

                    ctx.evaluateScript(jsCall)

                    let waitResult = semaphore.wait(timeout: .now() + 30)

                    // 清理
                    ctx.evaluateScript("delete ___onMatchSuccess; delete ___onMatchError; delete ___lxRequestHandler;")

                    if waitResult == .timedOut {
                        self?.emitLog("[JSSource] ⏱ 平台 \(sourceKey) 超时 (30s)")
                        continuation.resume(returning: nil)
                        return
                    }

                    if let error = resolvedError {
                        self?.emitLog("[JSSource] ❌ 平台 \(sourceKey) 错误: \(error)")
                        continuation.resume(returning: nil)
                        return
                    }

                    let url = resolvedUrl ?? ""
                    if url.isEmpty {
                        self?.emitLog("[JSSource] ❌ 平台 \(sourceKey) 返回空 URL")
                        continuation.resume(returning: nil)
                    } else {
                        self?.emitLog("[JSSource] ✅ 平台 \(sourceKey) 成功: \(url.prefix(80))")
                        continuation.resume(returning: UnblockResult(url: url, quality: quality, platform: sourceName + "(\(sourceKey))"))
                    }
                }
            }

            if testMode {
                // 测试模式：记录每个平台结果，继续遍历
                testPlatformResults[sourceKey] = result?.url ?? ""
                if result != nil && firstSuccessResult == nil {
                    firstSuccessResult = result
                }
            } else {
                // 正常模式：匹配到就返回
                if let result = result {
                    return result
                }
            }
        }

        // 测试模式返回第一个成功的
        if testMode {
            let successCount = testPlatformResults.values.filter { !$0.isEmpty }.count
            emitLog("[JSSource] 🧪 测试完成: \(successCount)/\(allSourceKeys.count) 个平台成功")
            if let result = firstSuccessResult {
                return result
            }
        }

        emitLog("[JSSource] ❌ 所有平台均未匹配到结果")
        return UnblockResult(url: "", quality: quality, platform: sourceName)
    }
}

// MARK: - 自定义地址音源

/// 自定义 HTTP 地址音源
/// 支持多种常见 API 格式，自动适配返回值
public struct CustomURLSource: NCMUnblockSource {
    public let name: String
    public let sourceType: UnblockSourceType = .httpUrl
    /// API 基础地址
    public let baseURL: String
    /// URL 模板，支持占位符: {id}, {quality}, {br}
    /// 默认格式: {baseURL}?types=url&id={id}&br={quality}
    public let urlTemplate: String?

    public init(name: String = "自定义音源", baseURL: String, urlTemplate: String? = nil) {
        self.name = name
        self.baseURL = baseURL
        self.urlTemplate = urlTemplate
    }

    public func match(id: Int, title: String?, artist: String?, quality: String) async throws -> UnblockResult {
        let urlStr: String
        if let template = urlTemplate {
            // 使用自定义模板
            urlStr = template
                .replacingOccurrences(of: "{id}", with: "\(id)")
                .replacingOccurrences(of: "{quality}", with: quality)
                .replacingOccurrences(of: "{br}", with: quality)
                .replacingOccurrences(of: "{baseURL}", with: baseURL)
        } else {
            // 默认格式
            urlStr = "\(baseURL)?types=url&id=\(id)&br=\(quality)"
        }

        guard let url = URL(string: urlStr) else {
            throw NCMError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 200

        // 尝试解析 JSON
        if let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
            // 兼容多种返回格式
            let resultUrl = json["url"] as? String
                ?? json["data"] as? String
                ?? (json["data"] as? [String: Any])?["url"] as? String
                ?? ""
            return UnblockResult(url: resultUrl, quality: quality, platform: name, extra: json)
        }

        // 可能直接返回 URL 文本
        if let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           statusCode == 200, text.hasPrefix("http") {
            return UnblockResult(url: text, quality: quality, platform: name)
        }

        return UnblockResult(url: "", quality: quality, platform: name)
    }
}

// MARK: - 后端解灰音源

/// 后端内置解灰音源
/// 通过旧版 NeteaseCloudMusicApi 后端的解灰接口获取播放链接
/// 支持两种模式：
/// - `.match`: 调用 `/song/url/match`，使用 unblockmusic-utils 匹配多平台
/// - `.ncmget`: 调用 `/song/url/ncmget`，使用 GD 音乐台 API
public class ServerUnblockSource: NCMUnblockSource {

    /// 后端解灰模式
    public enum Mode: String {
        /// 通过后端 /song/url/match，使用 unblockmusic-utils 多平台匹配
        case match
        /// 通过后端 /song/url/ncmget，使用 GD 音乐台 API
        case ncmget
        /// 直连 GD 音乐台 API（不需要后端）
        case gdDirect
    }

    /// GD 音乐台默认 API 地址
    public static let gdDefaultURL = "https://music-api.gdstudio.xyz/api.php"

    public let name: String
    public let sourceType: UnblockSourceType = .httpUrl
    /// 后端服务地址（match/ncmget 模式需要，gdDirect 模式不需要）
    public let serverUrl: String
    /// 解灰模式
    public let mode: Mode

    /// 初始化后端解灰音源
    /// - Parameters:
    ///   - name: 音源名称（可选，自动根据模式生成）
    ///   - serverUrl: 后端地址（gdDirect 模式可传空字符串）
    ///   - mode: 解灰模式，默认 `.match`
    public init(name: String? = nil, serverUrl: String = "", mode: Mode = .match) {
        self.serverUrl = serverUrl
        self.mode = mode
        switch mode {
        case .match:
            self.name = name ?? "后端解灰(match)"
        case .ncmget:
            self.name = name ?? "后端解灰(GD)"
        case .gdDirect:
            self.name = name ?? "GD音乐台"
        }
    }

    /// 便捷构造：直连 GD 音乐台（不需要后端）
    public static func gd(name: String = "GD音乐台") -> ServerUnblockSource {
        return ServerUnblockSource(name: name, serverUrl: "", mode: .gdDirect)
    }

    public func match(id: Int, title: String?, artist: String?, quality: String) async throws -> UnblockResult {
        let urlStr: String

        switch mode {
        case .match:
            let base = serverUrl.hasSuffix("/") ? String(serverUrl.dropLast()) : serverUrl
            urlStr = "\(base)/song/url/match?id=\(id)"
        case .ncmget:
            let base = serverUrl.hasSuffix("/") ? String(serverUrl.dropLast()) : serverUrl
            let br = quality.hasSuffix("000") ? String(quality.dropLast(3)) : quality
            urlStr = "\(base)/song/url/ncmget?id=\(id)&br=\(br)"
        case .gdDirect:
            // 直连 GD 音乐台，不经过后端
            let br = quality.hasSuffix("000") ? String(quality.dropLast(3)) : quality
            urlStr = "\(ServerUnblockSource.gdDefaultURL)?types=url&id=\(id)&br=\(br)"
        }

        guard let url = URL(string: urlStr) else {
            throw NCMError.invalidURL
        }

        #if DEBUG
        print("[ServerUnblock] 请求: \(urlStr)")
        #endif

        let (data, response) = try await URLSession.shared.data(from: url)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 200

        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return UnblockResult(url: "", quality: quality, platform: name)
        }

        #if DEBUG
        if let jsonStr = String(data: data, encoding: .utf8) {
            print("[ServerUnblock] 响应(\(statusCode)): \(String(jsonStr.prefix(300)))")
        }
        #endif

        // 解析返回的 URL
        var resultUrl = ""
        switch mode {
        case .match:
            // song_url_match 返回 {code: 200, data: "http://..."}
            resultUrl = json["data"] as? String ?? ""
        case .ncmget:
            // song_url_ncmget 返回 {code: 200, data: {url: "http://..."}}
            if let dataObj = json["data"] as? [String: Any] {
                resultUrl = dataObj["url"] as? String ?? ""
            }
        case .gdDirect:
            // GD 音乐台直连返回 {url: "http://..."}
            resultUrl = json["url"] as? String ?? ""
        }

        // 检查是否有代理 URL
        let proxyUrl = json["proxyUrl"] as? String
            ?? (json["data"] as? [String: Any])?["proxyUrl"] as? String
            ?? ""
        let finalUrl = proxyUrl.isEmpty ? resultUrl : proxyUrl

        return UnblockResult(
            url: finalUrl,
            quality: quality,
            platform: name,
            extra: json
        )
    }
}

// MARK: - 解灰管理器

/// 第三方音源管理器
/// 管理多个音源，支持按优先级自动降级匹配
public class UnblockManager {
    /// 已注册的音源列表（按优先级排序）
    public private(set) var sources: [NCMUnblockSource] = []

    public init() {}

    /// 注册音源
    public func register(_ source: NCMUnblockSource) {
        sources.append(source)
    }

    /// 批量注册音源
    public func register(_ sources: [NCMUnblockSource]) {
        self.sources.append(contentsOf: sources)
    }

    /// 移除所有音源
    public func removeAll() {
        sources.removeAll()
    }

    /// 移除指定名称的音源
    public func remove(named name: String) {
        sources.removeAll { $0.name == name }
    }

    /// 按优先级尝试所有音源匹配
    /// - Returns: 第一个成功匹配的结果，全部失败返回 nil
    public func match(
        id: Int,
        title: String? = nil,
        artist: String? = nil,
        quality: String = "320"
    ) async -> UnblockResult? {
        for source in sources {
            do {
                let result = try await source.match(id: id, title: title, artist: artist, quality: quality)
                if !result.url.isEmpty {
                    return result
                }
            } catch {
                continue
            }
        }
        return nil
    }

    /// 尝试所有音源，返回全部结果
    public func matchAll(
        id: Int,
        title: String? = nil,
        artist: String? = nil,
        quality: String = "320"
    ) async -> [(source: String, result: Result<UnblockResult, Error>)] {
        var results: [(source: String, result: Result<UnblockResult, Error>)] = []
        for source in sources {
            do {
                let r = try await source.match(id: id, title: title, artist: artist, quality: quality)
                results.append((source: source.name, result: .success(r)))
            } catch {
                results.append((source: source.name, result: .failure(error)))
            }
        }
        return results
    }
}

// MARK: - NCMClient 解灰扩展

extension NCMClient {

    /// 使用解灰管理器匹配歌曲
    public func songUrlUnblock(
        manager: UnblockManager,
        id: Int,
        title: String? = nil,
        artist: String? = nil,
        quality: String = "320"
    ) async throws -> APIResponse {
        guard let result = await manager.match(id: id, title: title, artist: artist, quality: quality) else {
            return APIResponse(
                status: 404,
                body: ["code": 404, "msg": "所有音源均未匹配到结果"],
                cookies: []
            )
        }
        return APIResponse(
            status: 200,
            body: [
                "code": 200,
                "data": [
                    "id": id,
                    "url": result.url,
                    "quality": result.quality,
                    "platform": result.platform,
                ] as [String: Any],
            ],
            cookies: []
        )
    }

    // MARK: - 自动解灰

    /// 判断歌曲数据项是否需要解灰
    /// 检查 songUrl / songUrlV1 返回的 data 数组中的单个元素
    /// - Parameter item: 歌曲 URL 数据项
    /// - Returns: true 表示该歌曲不可用，需要解灰
    internal func needsUnblock(_ item: [String: Any]) -> Bool {
        // 无 URL 或 URL 为空
        let url = item["url"] as? String ?? ""
        if url.isEmpty { return true }
        // 有试听限制（freeTrialInfo 不为 null/nil）
        if item["freeTrialInfo"] != nil && !(item["freeTrialInfo"] is NSNull) { return true }
        // fee 为 1（VIP 歌曲）或 4（付费专辑），且 URL 为空
        if let fee = item["fee"] as? Int, [1, 4].contains(fee) && url.isEmpty { return true }
        return false
    }

    /// 对 songUrl / songUrlV1 的响应执行自动解灰
    /// 遍历 data 数组，对不可用的歌曲逐个尝试第三方音源匹配，替换 URL
    /// 内置缓存机制：同一首歌在 `unblockCacheTTL` 时间内不会重复解灰，防止无限重试
    /// - Parameters:
    ///   - response: 原始 API 响应
    ///   - ids: 请求的歌曲 ID 数组
    ///   - quality: 目标音质（如 "320"、"flac"）
    /// - Returns: 处理后的响应（不可用歌曲的 URL 被替换为第三方音源链接）
    internal func autoUnblockResponse(
        _ response: APIResponse,
        ids: [Int],
        quality: String
    ) async -> APIResponse {
        guard let manager = unblockManager else { return response }
        guard var dataArray = response.body["data"] as? [[String: Any]] else { return response }

        let now = Date()

        // 清理过期缓存
        unblockCache = unblockCache.filter { now.timeIntervalSince($0.value.cachedAt) < unblockCacheTTL }

        // 筛选需要解灰的歌曲 ID（排除缓存命中的）
        let needUnblockIds = dataArray.compactMap { item -> Int? in
            guard needsUnblock(item) else { return nil }
            guard let id = item["id"] as? Int else { return nil }
            // 缓存命中：之前已解灰过，不再重复请求
            if let cached = unblockCache[id], now.timeIntervalSince(cached.cachedAt) < unblockCacheTTL {
                return nil
            }
            return id
        }

        // 对缓存命中的歌曲直接使用缓存 URL
        var modified = false
        for i in 0..<dataArray.count {
            guard needsUnblock(dataArray[i]) else { continue }
            guard let songId = dataArray[i]["id"] as? Int else { continue }
            if let cached = unblockCache[songId], !cached.url.isEmpty,
               now.timeIntervalSince(cached.cachedAt) < unblockCacheTTL {
                dataArray[i]["url"] = cached.url
                dataArray[i]["freeTrialInfo"] = NSNull()
                dataArray[i]["_unblocked"] = true
                dataArray[i]["_unblockedFromCache"] = true
                modified = true
                #if DEBUG
                print("[NCM] 🔓 解灰缓存命中: id=\(songId)")
                #endif
            }
        }

        guard !needUnblockIds.isEmpty else {
            if modified {
                var newBody = response.body
                newBody["data"] = dataArray
                return APIResponse(status: response.status, body: newBody, cookies: response.cookies)
            }
            return response
        }

        #if DEBUG
        print("[NCM] 🔓 自动解灰: \(needUnblockIds.count)/\(dataArray.count) 首需要解灰")
        #endif

        // 批量获取歌曲详情（歌名、歌手传给音源提高匹配率）
        var songInfoMap: [Int: (name: String, artist: String)] = [:]
        if let detailResp = try? await songDetail(ids: needUnblockIds),
           let songs = detailResp.body["songs"] as? [[String: Any]] {
            for song in songs {
                guard let id = song["id"] as? Int else { continue }
                let name = song["name"] as? String ?? ""
                let artists = (song["ar"] as? [[String: Any]] ?? song["artists"] as? [[String: Any]] ?? [])
                    .compactMap { $0["name"] as? String }
                    .joined(separator: " / ")
                songInfoMap[id] = (name, artists)
            }
        }

        // 逐首尝试解灰
        for i in 0..<dataArray.count {
            guard needsUnblock(dataArray[i]) else { continue }
            guard let songId = dataArray[i]["id"] as? Int else { continue }
            // 跳过已从缓存填充的
            if unblockCache[songId] != nil { continue }

            let info = songInfoMap[songId]

            #if DEBUG
            print("[NCM] 🔓 解灰: id=\(songId) \(info?.name ?? "") - \(info?.artist ?? "")")
            #endif

            if let result = await manager.match(
                id: songId,
                title: info?.name,
                artist: info?.artist,
                quality: quality
            ), !result.url.isEmpty {
                dataArray[i]["url"] = result.url
                dataArray[i]["freeTrialInfo"] = NSNull()
                dataArray[i]["_unblocked"] = true
                dataArray[i]["_unblockedFrom"] = result.platform
                modified = true

                // 写入缓存
                unblockCache[songId] = (url: result.url, cachedAt: now)

                #if DEBUG
                print("[NCM] ✅ 解灰成功: id=\(songId) 来源=\(result.platform)")
                #endif
            } else {
                // 解灰失败也写入缓存（空 URL），防止反复尝试
                unblockCache[songId] = (url: "", cachedAt: now)

                #if DEBUG
                print("[NCM] ❌ 解灰失败: id=\(songId) 所有音源均未匹配（已缓存 \(Int(unblockCacheTTL))s）")
                #endif
            }
        }

        if modified {
            var newBody = response.body
            newBody["data"] = dataArray
            return APIResponse(status: response.status, body: newBody, cookies: response.cookies)
        }
        return response
    }
}
