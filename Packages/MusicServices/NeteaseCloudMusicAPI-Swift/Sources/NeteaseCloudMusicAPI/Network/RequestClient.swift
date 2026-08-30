// RequestClient.swift
// HTTP 请求客户端
// 处理 URL 构建、加密分发、HTTP 执行和响应解密
// 任务 7.1: 实现 RequestClient 核心

import Foundation

// MARK: - 请求客户端

/// HTTP 请求客户端
/// 负责 URL 路径重写、加密分发、HTTP POST 请求执行和请求头构建
class RequestClient {

    // MARK: - 属性

    /// URLSession 实例，用于发送 HTTP 请求
    let session: URLSession

    /// 会话管理器，管理 Cookie 和设备元数据
    let sessionManager: SessionManager

    /// ncm主域名（WeAPI / LinuxAPI 使用），可自定义
    var domain: String = NCMConstants.domain

    /// ncm API 接口域名（EAPI / 明文模式使用），可自定义
    var apiDomain: String = NCMConstants.apiDomain

    // MARK: - 初始化

    /// 初始化请求客户端
    /// - Parameters:
    ///   - session: URLSession 实例，默认使用 `.shared`
    ///   - sessionManager: 会话管理器实例
    init(session: URLSession = .shared, sessionManager: SessionManager) {
        self.session = session
        self.sessionManager = sessionManager
    }

    // MARK: - 核心请求方法

    /// 发送 API 请求
    /// 根据加密模式执行 URL 重写、加密、构建请求头，然后发送 HTTP POST 请求
    /// - Parameters:
    ///   - uri: API 路径（如 `/api/song/detail`）
    ///   - data: 请求参数字典
    ///   - options: 请求配置选项（加密模式、UA、真实 IP 等）
    /// - Returns: API 响应（包含状态码、响应体和 Cookie）
    /// - Throws: `NCMError` 如果加密、网络请求或响应解析失败
    func request(
        uri: String,
        data: [String: Any],
        options: RequestOptions,
        expectedSessionGeneration: UInt64? = nil
    ) async throws -> APIResponse {
        let start = CFAbsoluteTimeGetCurrent()
        let requestGeneration = expectedSessionGeneration ?? sessionManager.sessionGeneration
        guard sessionManager.sessionGeneration == requestGeneration else {
            throw CancellationError()
        }

        #if DEBUG
        print("[NCM] ➡️ \(options.crypto) \(uri)")
        print("[NCM]    参数: \(data.keys.sorted().joined(separator: ", "))")
        #endif

        // 1. 根据加密模式构建 URL 和加密参数
        let (url, body) = try buildRequestComponents(uri: uri, data: data, options: options)

        #if DEBUG
        print("[NCM]    URL: \(url.absoluteString)")
        #endif

        // 2. 构建请求头
        let headers = buildHeaders(uri: uri, options: options)
        guard sessionManager.sessionGeneration == requestGeneration else {
            throw CancellationError()
        }

        // 3. 构建 URLRequest
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        // 设置所有请求头
        for (key, value) in headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        // 设置请求体（URL 编码的表单数据）
        let bodyString = RequestClient.urlEncode(body)
        urlRequest.httpBody = bodyString.data(using: .utf8)

        // 4. 发送 HTTP POST 请求
        let (responseData, httpResponse) = try await executeRequest(urlRequest)
        guard sessionManager.sessionGeneration == requestGeneration else {
            throw CancellationError()
        }

        let ms = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)

        // 5. 提取响应信息
        let statusCode = httpResponse.statusCode
        let setCookieHeaders = RequestClient.extractSetCookieHeaders(from: httpResponse)

        #if DEBUG
        print("[NCM] ⬅️ \(statusCode) \(uri) [\(ms)ms] 数据=\(responseData.count)字节")
        if !setCookieHeaders.isEmpty {
            print("[NCM]    Set-Cookie: \(setCookieHeaders.count) 条")
        }
        #endif

        // 6. 解析响应体为 JSON
        let responseBody = parseResponseBody(responseData)

        #if DEBUG
        if let code = responseBody["code"] as? Int {
            print("[NCM]    响应 code=\(code)")
        }
        #endif

        // 7. 处理响应（状态码归一化、EAPI 解密、Cookie 更新、非 200 抛错）
        do {
            let result = try processResponse(
                statusCode: statusCode,
                responseData: responseData,
                responseBody: responseBody,
                setCookieHeaders: setCookieHeaders,
                options: options,
                expectedSessionGeneration: requestGeneration
            )
            #if DEBUG
            print("[NCM] ✅ \(uri) 完成 [\(ms)ms]")
            #endif
            return result
        } catch {
            #if DEBUG
            print("[NCM] ❌ \(uri) 失败 [\(ms)ms] \(error)")
            #endif
            throw error
        }
    }

    // MARK: - 响应处理

    /// 处理 API 响应
    /// 执行状态码归一化、EAPI 加密响应解密、Cookie 更新和非 200 状态抛错
    /// - Parameters:
    ///   - statusCode: 原始 HTTP 状态码
    ///   - responseData: 原始响应数据
    ///   - responseBody: 已解析的 JSON 响应体（可能需要被解密后的数据替换）
    ///   - setCookieHeaders: 响应中的 Set-Cookie 头列表
    ///   - options: 请求配置选项（包含 e_r 标志）
    /// - Returns: 处理后的 API 响应
    /// - Throws: `NCMError.apiError` 如果归一化后状态码非 200
    private func processResponse(
        statusCode: Int,
        responseData: Data,
        responseBody: [String: Any],
        setCookieHeaders: [String],
        options: RequestOptions,
        expectedSessionGeneration: UInt64
    ) throws -> APIResponse {
        var body = responseBody

        // 1. 如果 e_r 为 true，尝试解密 EAPI 加密响应
        if let e_r = options.e_r, e_r {
            body = decryptEAPIResponse(responseData: responseData, fallbackBody: body)
        }

        // 2. 状态码归一化
        let normalizedStatus = RequestClient.normalizeStatusCode(statusCode, body: body)

        // 3. 更新会话 Cookie
        guard sessionManager.updateCookies(
            from: setCookieHeaders,
            ifSessionGeneration: expectedSessionGeneration
        ) else {
            throw CancellationError()
        }

        // 4. 如果归一化后状态码非 200，抛出 API 业务错误
        if normalizedStatus != 200 {
            throw NCMError.apiError(code: normalizedStatus, body: body)
        }

        // 5. 返回处理后的响应
        return APIResponse(
            status: normalizedStatus,
            body: body,
            cookies: setCookieHeaders
        )
    }

    /// 状态码归一化
    /// - 如果响应体中的 "code" 字段在特殊状态码集合中，归一化为 200
    /// - 如果状态码超出 100-599 范围，归一化为 400
    /// - Parameters:
    ///   - statusCode: 原始 HTTP 状态码
    ///   - body: 响应体字典（用于检查 "code" 字段）
    /// - Returns: 归一化后的状态码
    static func normalizeStatusCode(_ statusCode: Int, body: [String: Any]) -> Int {
        // 检查响应体中的 "code" 字段是否在特殊状态码集合中
        if let code = body["code"] as? Int,
           NCMConstants.specialStatusCodes.contains(code) {
            return 200
        }

        // 检查状态码是否超出有效范围 100-599
        if statusCode < 100 || statusCode > 599 {
            return 400
        }

        return statusCode
    }

    /// 尝试解密 EAPI 加密响应
    /// 当 e_r 标志为 true 时，将原始响应数据视为 hex 编码的加密数据进行解密
    /// 如果解密失败，回退到原始响应体
    /// - Parameters:
    ///   - responseData: 原始响应数据
    ///   - fallbackBody: 解密失败时的回退响应体
    /// - Returns: 解密后的 JSON 字典，或回退响应体
    private func decryptEAPIResponse(
        responseData: Data,
        fallbackBody: [String: Any]
    ) -> [String: Any] {
        // 将原始响应数据转换为 hex 字符串
        guard let hexString = String(data: responseData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !hexString.isEmpty else {
            return fallbackBody
        }

        // 尝试使用 EAPI 密钥解密
        do {
            let decrypted = try CryptoEngine.eapiDecrypt(hexString: hexString)
            return decrypted
        } catch {
            // 解密失败，回退到原始响应体
            return fallbackBody
        }
    }

    // MARK: - URL 路径重写

    /// 根据加密模式重写 URL 路径
    /// - weapi: `/api/xxx` → `/weapi/xxx`
    /// - eapi: `/api/xxx` → `/eapi/xxx`
    /// - linuxapi 和 api 模式不重写路径
    /// - Parameters:
    ///   - uri: 原始 API 路径
    ///   - crypto: 加密模式
    /// - Returns: 重写后的路径
    static func rewritePath(_ uri: String, for crypto: CryptoMode) -> String {
        switch crypto {
        case .weapi:
            // /api/ → /weapi/
            if uri.hasPrefix("/api/") {
                return "/weapi/" + uri.dropFirst("/api/".count)
            }
            return uri
        case .eapi:
            // /api/ → /eapi/
            if uri.hasPrefix("/api/") {
                return "/eapi/" + uri.dropFirst("/api/".count)
            }
            return uri
        case .linuxapi, .api:
            // 不重写路径
            return uri
        }
    }

    // MARK: - 请求组件构建

    /// 根据加密模式构建完整的请求 URL 和加密后的请求体
    /// - Parameters:
    ///   - uri: 原始 API 路径
    ///   - data: 请求参数字典
    ///   - options: 请求配置选项
    /// - Returns: 元组（请求 URL，加密后的参数字典）
    /// - Throws: `NCMError.encryptionFailed` 如果加密失败
    private func buildRequestComponents(
        uri: String,
        data: [String: Any],
        options: RequestOptions
    ) throws -> (URL, [String: String]) {
        switch options.crypto {
        case .weapi:
            return try buildWeapiComponents(uri: uri, data: data)
        case .linuxapi:
            return try buildLinuxapiComponents(uri: uri, data: data)
        case .eapi:
            return try buildEapiComponents(uri: uri, data: data, options: options)
        case .api:
            return try buildApiComponents(uri: uri, data: data)
        }
    }

    /// 构建 WeAPI 模式的请求组件
    /// URL: `https://music.163.com/weapi/{path}`
    /// 使用 CryptoEngine.weapiEncrypt 加密
    private func buildWeapiComponents(
        uri: String,
        data: [String: Any]
    ) throws -> (URL, [String: String]) {
        // 重写路径
        let rewrittenPath = RequestClient.rewritePath(uri, for: .weapi)
        let urlString = domain + rewrittenPath

        guard let url = URL(string: urlString) else {
            throw NCMError.invalidResponse(detail: "无效的 URL: \(urlString)")
        }

        // 加密数据
        do {
            let encrypted = try CryptoEngine.weapiEncrypt(data)
            let body: [String: String] = [
                "params": encrypted.params,
                "encSecKey": encrypted.encSecKey,
            ]
            return (url, body)
        } catch {
            throw NCMError.encryptionFailed(mode: .weapi, detail: "\(error)")
        }
    }

    /// 构建 LinuxAPI 模式的请求组件
    /// URL: `https://music.163.com/api/linux/forward`
    /// 将原始 URL 包装在加密载荷中
    private func buildLinuxapiComponents(
        uri: String,
        data: [String: Any]
    ) throws -> (URL, [String: String]) {
        // LinuxAPI 固定 URL
        let urlString = domain + "/api/linux/forward"

        guard let url = URL(string: urlString) else {
            throw NCMError.invalidResponse(detail: "无效的 URL: \(urlString)")
        }

        // 构建包含原始 URL 的载荷
        let originalUrl = domain + uri
        let payload: [String: Any] = [
            "method": "POST",
            "url": originalUrl,
            "params": data,
        ]

        // 加密载荷
        do {
            let encrypted = try CryptoEngine.linuxapiEncrypt(payload)
            let body: [String: String] = [
                "eparams": encrypted.eparams,
            ]
            return (url, body)
        } catch {
            throw NCMError.encryptionFailed(mode: .linuxapi, detail: "\(error)")
        }
    }

    /// 构建 EAPI 模式的请求组件
    /// URL: `https://interface.music.163.com/eapi/{path}`
    /// 使用 CryptoEngine.eapiEncrypt 加密
    private func buildEapiComponents(
        uri: String,
        data: [String: Any],
        options: RequestOptions
    ) throws -> (URL, [String: String]) {
        // 重写路径
        let rewrittenPath = RequestClient.rewritePath(uri, for: .eapi)
        let urlString = apiDomain + rewrittenPath

        guard let url = URL(string: urlString) else {
            throw NCMError.invalidResponse(detail: "无效的 URL: \(urlString)")
        }

        // 构建 EAPI 请求头并合并到数据中
        let csrfToken = sessionManager.cookies["__csrf"] ?? ""
        let eapiHeader = sessionManager.buildEAPIHeader(csrfToken: csrfToken)

        var mergedData = data
        mergedData["header"] = eapiHeader

        // 如果设置了 e_r 标志，添加到数据中
        if let e_r = options.e_r, e_r {
            mergedData["e_r"] = true
        }

        // 加密数据（使用原始 uri 作为 eapi 加密的 url 参数）
        do {
            let encrypted = try CryptoEngine.eapiEncrypt(url: uri, object: mergedData)
            let body: [String: String] = [
                "params": encrypted.params,
            ]
            return (url, body)
        } catch {
            throw NCMError.encryptionFailed(mode: .eapi, detail: "\(error)")
        }
    }

    /// 构建 API 明文模式的请求组件
    /// URL: `https://interface.music.163.com{path}`
    /// 直接发送 URL 编码的表单数据，无加密
    private func buildApiComponents(
        uri: String,
        data: [String: Any]
    ) throws -> (URL, [String: String]) {
        let urlString = apiDomain + uri

        guard let url = URL(string: urlString) else {
            throw NCMError.invalidResponse(detail: "无效的 URL: \(urlString)")
        }

        // 明文模式：将参数值转换为字符串
        var body: [String: String] = [:]
        for (key, value) in data {
            body[key] = "\(value)"
        }

        return (url, body)
    }

    // MARK: - 请求头构建

    /// 构建 HTTP 请求头
    /// 根据加密模式设置 Cookie、User-Agent、Referer、X-Real-IP 等头部
    /// - Parameters:
    ///   - uri: API 路径
    ///   - options: 请求配置选项
    /// - Returns: 请求头字典
    func buildHeaders(uri: String, options: RequestOptions) -> [String: String] {
        var headers: [String: String] = [:]

        // 1. 设置 User-Agent
        if let customUA = options.ua, !customUA.isEmpty {
            headers["User-Agent"] = customUA
        } else {
            headers["User-Agent"] = sessionManager.chooseUserAgent(crypto: options.crypto)
        }

        // 2. 设置 Cookie
        let cookieHeader = sessionManager.buildCookieHeader(for: uri, crypto: options.crypto)
        if !cookieHeader.isEmpty {
            headers["Cookie"] = cookieHeader
        }

        // 3. 根据加密模式设置特定头部
        switch options.crypto {
        case .weapi:
            // WeAPI 模式设置 Referer
            headers["Referer"] = domain
        case .linuxapi:
            // LinuxAPI 模式设置 User-Agent 为 Linux 客户端
            headers["User-Agent"] = SessionManager.userAgentMap[.linuxapi]?[.linux]
                ?? "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.90 Safari/537.36"
        case .eapi, .api:
            break
        }

        // 4. 设置 X-Real-IP 和 X-Forwarded-For（如果配置了 realIP）
        if let realIP = options.realIP, !realIP.isEmpty {
            headers["X-Real-IP"] = realIP
            headers["X-Forwarded-For"] = realIP
        }

        return headers
    }

    // MARK: - HTTP 请求执行

    /// 执行 HTTP 请求
    /// - Parameter request: 配置好的 URLRequest
    /// - Returns: 元组（响应数据，HTTP 响应）
    /// - Throws: `NCMError.networkError` 如果请求失败
    private func executeRequest(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NCMError.invalidResponse(detail: "响应不是 HTTP 响应")
            }
            return (data, httpResponse)
        } catch let error as NCMError {
            throw error
        } catch {
            throw NCMError.networkError(statusCode: -1, message: "网络请求失败: \(error.localizedDescription)")
        }
    }

    // MARK: - 响应解析

    /// 从 HTTP 响应中提取 Set-Cookie 头
    /// - Parameter response: HTTP 响应
    /// - Returns: Set-Cookie 头字符串数组（每个 Cookie 一条）
    static func extractSetCookieHeaders(from response: HTTPURLResponse) -> [String] {
        // 优先使用 HTTPCookieStorage 解析（最可靠）
        if let url = response.url,
           let allHeaders = response.allHeaderFields as? [String: String] {
            let httpCookies = HTTPCookie.cookies(withResponseHeaderFields: allHeaders, for: url)
            if !httpCookies.isEmpty {
                return httpCookies.map { cookie in
                    "\(cookie.name)=\(cookie.value)"
                }
            }
        }

        // 回退：手动从 allHeaderFields 提取并拆分
        var setCookies: [String] = []
        for (key, value) in response.allHeaderFields {
            let headerName = "\(key)".lowercased()
            if headerName == "set-cookie" {
                let valueStr = "\(value)"
                // allHeaderFields 会把多个 Set-Cookie 用逗号合并
                // 按 ", " + 大写字母开头的 key= 模式拆分
                let parts = RequestClient.splitSetCookieHeader(valueStr)
                setCookies.append(contentsOf: parts)
            }
        }
        return setCookies
    }

    /// 拆分被合并的 Set-Cookie 头字符串
    /// HTTPURLResponse.allHeaderFields 会把多个 Set-Cookie 用 ", " 合并
    /// 需要智能拆分，避免误拆 expires 中的逗号（如 "Thu, 01 Jan 2026"）
    static func splitSetCookieHeader(_ header: String) -> [String] {
        var results: [String] = []
        var current = ""

        // 按逗号拆分，但要判断逗号后面是否是新的 Cookie（key=value 格式）
        let segments = header.components(separatedBy: ",")
        for segment in segments {
            let trimmed = segment.trimmingCharacters(in: .whitespaces)
            // 判断是否是新的 Set-Cookie 条目：包含 "=" 且第一个 "=" 前没有空格和分号
            let firstEquals = trimmed.firstIndex(of: "=")
            let firstSemicolon = trimmed.firstIndex(of: ";")
            let firstSpace = trimmed.firstIndex(of: " ")

            let isNewCookie: Bool
            if let eq = firstEquals {
                // "=" 前面的部分应该是一个合法的 Cookie 名（无空格、无分号）
                let beforeEquals = trimmed[trimmed.startIndex..<eq]
                let hasSpaceBeforeEq = firstSpace != nil && firstSpace! < eq
                let hasSemicolonBeforeEq = firstSemicolon != nil && firstSemicolon! < eq
                isNewCookie = !beforeEquals.isEmpty && !hasSpaceBeforeEq && !hasSemicolonBeforeEq
            } else {
                isNewCookie = false
            }

            if isNewCookie && !current.isEmpty {
                results.append(current.trimmingCharacters(in: .whitespaces))
                current = trimmed
            } else if current.isEmpty {
                current = trimmed
            } else {
                current += "," + segment
            }
        }
        if !current.isEmpty {
            results.append(current.trimmingCharacters(in: .whitespaces))
        }
        return results
    }

    /// 解析响应体为 JSON 字典
    /// 如果无法解析为 JSON，返回包含原始数据的字典
    /// - Parameter data: 响应数据
    /// - Returns: JSON 字典
    private func parseResponseBody(_ data: Data) -> [String: Any] {
        // 尝试解析为 JSON 字典
        if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            return json
        }

        // 如果无法解析为 JSON，返回包含原始数据的字典
        let rawString = String(data: data, encoding: .utf8) ?? ""
        return ["_raw": rawString]
    }

    // MARK: - URL 编码辅助方法

    /// 将字典编码为 URL 编码的表单字符串
    /// - Parameter params: 参数字典
    /// - Returns: URL 编码的字符串（如 `key1=value1&key2=value2`）
    static func urlEncode(_ params: [String: String]) -> String {
        // 自定义允许的字符集（不编码字母、数字、-、_、.、~）
        var allowedCharacters = CharacterSet.alphanumerics
        allowedCharacters.insert(charactersIn: "-._~")

        return params.map { key, value in
            let encodedKey = key.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? key
            let encodedValue = value.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? value
            return "\(encodedKey)=\(encodedValue)"
        }.joined(separator: "&")
    }
}
