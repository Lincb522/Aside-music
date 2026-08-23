import Foundation

struct AIRequiredTool: Sendable {
    let name: String
    let description: String
    let parametersJSON: String
}

struct AIRequiredToolResponse: Sendable {
    enum Invocation: String, Sendable, Equatable {
        case toolCall
        case contentFallback
    }

    let arguments: String
    let invocation: Invocation
    let toolInvocationCount: Int
}

private struct AIProviderGeneratedContent: Sendable {
    let value: String
    let toolInvocation: AIRequiredToolResponse.Invocation?
    let toolInvocationCount: Int
}

struct AIProviderClient: Sendable {
    func fetchModels(
        configuration: AIProviderConfiguration,
        apiKey: String
    ) async throws -> [String] {
        if configuration.wireProtocol == .appleIntelligence {
            return [configuration.wireProtocol.defaultModel]
        }

        let normalizedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if configuration.wireProtocol.requiresAPIKey && normalizedKey.isEmpty {
            throw AIEqualizerError.missingAPIKey
        }

        guard let url = try modelDiscoveryEndpoint(
            for: configuration,
            apiKey: normalizedKey
        ) else {
            let configured = configuration.resolvedModel
            return configured.isEmpty ? [] : [configured]
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = configuration.timeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        applyAuthentication(
            wireProtocol: configuration.wireProtocol,
            apiKey: normalizedKey,
            to: &request
        )
        applyCustomHeaders(configuration.customHeadersJSON, to: &request)

        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.timeoutIntervalForRequest = configuration.timeout
        sessionConfiguration.timeoutIntervalForResource = configuration.timeout + 5
        // URLSession 会强引用自身直到被显式 invalidate；一次性会话必须回收。
        let session = URLSession(configuration: sessionConfiguration)
        defer { session.finishTasksAndInvalidate() }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AIEqualizerError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw AIEqualizerError.httpStatus(http.statusCode, Self.errorMessage(from: data))
        }

        let models = try Self.extractModels(from: data, wireProtocol: configuration.wireProtocol)
        var seen = Set<String>()
        return models.filter {
            !$0.isEmpty && seen.insert($0).inserted
        }
    }

    func generate(
        systemPrompt: String,
        userPrompt: String,
        configuration: AIProviderConfiguration,
        apiKey: String,
        minimumTimeout: TimeInterval = 0,
        options: AIGenerationOptions = .standard
    ) async throws -> String {
        try await generate(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            configuration: configuration,
            apiKey: apiKey,
            minimumTimeout: minimumTimeout,
            options: options,
            requiredTool: nil,
            allowsModelFallback: true,
            allowsToolContentFallback: false,
            requiresExactlyOneToolCall: true
        ).value
    }

    /// Performs a single model request that must end in one function call.
    /// The function arguments are the model's final structured result, so a
    /// second model round-trip is not required.
    func generateRequiringTool(
        systemPrompt: String,
        userPrompt: String,
        tool: AIRequiredTool,
        configuration: AIProviderConfiguration,
        apiKey: String,
        minimumTimeout: TimeInterval = 0,
        options: AIGenerationOptions = .standard,
        allowContentFallback: Bool = false,
        requireExactlyOnce: Bool = true
    ) async throws -> AIRequiredToolResponse {
        if configuration.wireProtocol == .appleIntelligence {
            // FoundationModels performs its native tool continuation within a
            // single `respond` call. Apple tuning never accepts prompt/content
            // fallback and always enforces exactly one recorded invocation.
            return try await AppleIntelligenceEqualizerProvider.generateRequiringTool(
                systemPrompt: systemPrompt,
                userPrompt: userPrompt,
                toolName: tool.name
            )
        }

        let generated = try await generate(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            configuration: configuration,
            apiKey: apiKey,
            minimumTimeout: minimumTimeout,
            options: options,
            requiredTool: tool,
            allowsModelFallback: true,
            allowsToolContentFallback: allowContentFallback,
            requiresExactlyOneToolCall: requireExactlyOnce
        )
        guard let invocation = generated.toolInvocation else {
            throw AIEqualizerError.invalidResponse
        }
        return AIRequiredToolResponse(
            arguments: generated.value,
            invocation: invocation,
            toolInvocationCount: generated.toolInvocationCount
        )
    }

    private func generate(
        systemPrompt: String,
        userPrompt: String,
        configuration: AIProviderConfiguration,
        apiKey: String,
        minimumTimeout: TimeInterval,
        options: AIGenerationOptions,
        requiredTool: AIRequiredTool?,
        allowsModelFallback: Bool,
        allowsToolContentFallback: Bool,
        requiresExactlyOneToolCall: Bool
    ) async throws -> AIProviderGeneratedContent {
        if configuration.wireProtocol == .appleIntelligence {
            return AIProviderGeneratedContent(
                value: try await AppleIntelligenceEqualizerProvider.generate(
                    systemPrompt: systemPrompt,
                    userPrompt: userPrompt
                ),
                toolInvocation: nil,
                toolInvocationCount: 0
            )
        }

        let normalizedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if configuration.wireProtocol.requiresAPIKey && normalizedKey.isEmpty {
            throw AIEqualizerError.missingAPIKey
        }

        let responseTimeout = min(180, max(configuration.timeout, minimumTimeout))
        let request = try makeRequest(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            configuration: configuration,
            apiKey: normalizedKey,
            timeout: responseTimeout,
            options: options,
            requiredTool: requiredTool
        )
        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.timeoutIntervalForRequest = responseTimeout
        sessionConfiguration.timeoutIntervalForResource = responseTimeout + 15
        sessionConfiguration.waitsForConnectivity = true
        // URLSession 会强引用自身直到被显式 invalidate；一次性会话必须回收。
        let session = URLSession(configuration: sessionConfiguration)
        defer { session.finishTasksAndInvalidate() }
        let startedAt = Date()
        let endpointHost = request.url?.host ?? "unknown"
        let endpointPath = request.url?.path ?? "unknown"
        AppLogger.network(
            "[AIProviderClient] Generation request started protocol=\(configuration.wireProtocol.rawValue) model=\(configuration.resolvedModel) endpointHost=\(endpointHost) endpointPath=\(endpointPath) timeout=\(Int(responseTimeout))s promptCharacters=\(systemPrompt.count + userPrompt.count) requestBytes=\(request.httpBody?.count ?? 0)",
            step: "ai-provider.request-started"
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            let elapsed = Date().timeIntervalSince(startedAt)
            let elapsedText = String(format: "%.2f", elapsed)
            let code = (error as? URLError)?.code.rawValue
            let codeText = code.map { String($0) } ?? "none"
            AppLogger.error(
                "[AIProviderClient] Generation request failed protocol=\(configuration.wireProtocol.rawValue) model=\(configuration.resolvedModel) elapsed=\(elapsedText)s timeout=\(Int(responseTimeout))s urlErrorCode=\(codeText) error=\(error.localizedDescription)",
                step: "ai-provider.request-failed"
            )
            throw error
        }

        guard let http = response as? HTTPURLResponse else {
            throw AIEqualizerError.invalidResponse
        }
        let elapsedText = String(format: "%.2f", Date().timeIntervalSince(startedAt))
        AppLogger.network(
            "[AIProviderClient] Generation response received protocol=\(configuration.wireProtocol.rawValue) model=\(configuration.resolvedModel) status=\(http.statusCode) elapsed=\(elapsedText)s responseBytes=\(data.count)",
            step: "ai-provider.response-received"
        )
        guard (200...299).contains(http.statusCode) else {
            let message = Self.errorMessage(from: data)
            if allowsModelFallback,
               Self.isUnsupportedModelResponse(statusCode: http.statusCode, message: message),
               let fallbackModel = try? await fallbackModel(
                   for: configuration,
                   apiKey: normalizedKey
               ) {
                var fallbackConfiguration = configuration
                fallbackConfiguration.model = fallbackModel
                AppLogger.warning(
                    "[AIProviderClient] Configured model unavailable; retrying with discovered model previous=\(configuration.resolvedModel) fallback=\(fallbackModel)",
                    step: "ai-provider.model-fallback"
                )
                return try await generate(
                    systemPrompt: systemPrompt,
                    userPrompt: userPrompt,
                    configuration: fallbackConfiguration,
                    apiKey: apiKey,
                    minimumTimeout: minimumTimeout,
                    options: options,
                    requiredTool: requiredTool,
                    allowsModelFallback: false,
                    allowsToolContentFallback: allowsToolContentFallback,
                    requiresExactlyOneToolCall: requiresExactlyOneToolCall
                )
            }
            throw AIEqualizerError.httpStatus(http.statusCode, message)
        }
        do {
            if let requiredTool {
                let result = try Self.extractToolArguments(
                    from: data,
                    wireProtocol: configuration.wireProtocol,
                    toolName: requiredTool.name,
                    allowContentFallback: allowsToolContentFallback,
                    requireExactlyOnce: requiresExactlyOneToolCall
                )
                return AIProviderGeneratedContent(
                    value: result.arguments,
                    toolInvocation: result.invocation,
                    toolInvocationCount: result.toolInvocationCount
                )
            }
            return AIProviderGeneratedContent(
                value: try Self.extractText(from: data, wireProtocol: configuration.wireProtocol),
                toolInvocation: nil,
                toolInvocationCount: 0
            )
        } catch {
            let responsePreview = String(decoding: data.prefix(1_200), as: UTF8.self)
                .replacingOccurrences(of: "\n", with: " ")
            AppLogger.error(
                "[AIProviderClient] Response body did not contain usable model text protocol=\(configuration.wireProtocol.rawValue) status=\(http.statusCode) bytes=\(data.count) body=\(responsePreview)",
                step: "ai-provider.response-decode"
            )
            throw error
        }
    }

    private func makeRequest(
        systemPrompt: String,
        userPrompt: String,
        configuration: AIProviderConfiguration,
        apiKey: String,
        timeout: TimeInterval,
        options: AIGenerationOptions,
        requiredTool: AIRequiredTool?
    ) throws -> URLRequest {
        let model = configuration.resolvedModel
        guard !model.isEmpty else { throw AIEqualizerError.modelUnavailable }
        let url = try endpoint(for: configuration, model: model, apiKey: apiKey)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")

        var body: [String: Any]
        let temperature = options.normalizedTemperature
        let maximumOutputTokens = options.normalizedMaxOutputTokens
        switch configuration.wireProtocol {
        case .openAIResponses:
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            body = [
                "model": model,
                "instructions": systemPrompt,
                "input": userPrompt,
                "temperature": temperature,
                "max_output_tokens": maximumOutputTokens
            ]

        case .openAIChat:
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            body = chatBody(
                systemPrompt: systemPrompt,
                userPrompt: userPrompt,
                model: model,
                jsonMode: true,
                modernTokenParameter: true,
                options: options
            )

        case .openAICompatible:
            if !apiKey.isEmpty {
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            }
            body = chatBody(
                systemPrompt: systemPrompt,
                userPrompt: userPrompt,
                model: model,
                jsonMode: false,
                modernTokenParameter: false,
                options: options
            )

        case .anthropicMessages:
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            body = [
                "model": model,
                "system": systemPrompt,
                "max_tokens": maximumOutputTokens,
                "temperature": temperature,
                "messages": [["role": "user", "content": userPrompt]]
            ]

        case .googleGemini:
            body = [
                "systemInstruction": ["parts": [["text": systemPrompt]]],
                "contents": [["role": "user", "parts": [["text": userPrompt]]]],
                "generationConfig": [
                    "temperature": temperature,
                    "maxOutputTokens": maximumOutputTokens,
                    "responseMimeType": "application/json"
                ]
            ]

        case .azureOpenAI:
            request.setValue(apiKey, forHTTPHeaderField: "api-key")
            body = chatBody(
                systemPrompt: systemPrompt,
                userPrompt: userPrompt,
                model: model,
                jsonMode: true,
                modernTokenParameter: true,
                options: options
            )

        case .ollama:
            body = [
                "model": model,
                "stream": false,
                "format": "json",
                "messages": [
                    ["role": "system", "content": systemPrompt],
                    ["role": "user", "content": userPrompt]
                ],
                "options": [
                    "temperature": temperature,
                    "num_predict": maximumOutputTokens
                ]
            ]

        case .appleIntelligence:
            throw AIEqualizerError.invalidEndpoint
        }

        if let requiredTool {
            body = try applyingRequiredTool(
                requiredTool,
                to: body,
                wireProtocol: configuration.wireProtocol
            )
        }

        applyCustomHeaders(configuration.customHeadersJSON, to: &request)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func applyingRequiredTool(
        _ tool: AIRequiredTool,
        to source: [String: Any],
        wireProtocol: AIWireProtocol
    ) throws -> [String: Any] {
        guard let data = tool.parametersJSON.data(using: .utf8),
              let parameters = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIEqualizerError.invalidResponse
        }
        var body = source
        let function: [String: Any] = [
            "name": tool.name,
            "description": tool.description,
            "parameters": parameters
        ]

        switch wireProtocol {
        case .openAIResponses:
            body["tools"] = [[
                "type": "function",
                "name": tool.name,
                "description": tool.description,
                "parameters": parameters
            ]]
            body["tool_choice"] = ["type": "function", "name": tool.name]
        case .openAIChat, .openAICompatible, .azureOpenAI:
            body["tools"] = [["type": "function", "function": function]]
            body["tool_choice"] = [
                "type": "function",
                "function": ["name": tool.name]
            ]
            // Function arguments already provide a strict JSON container.
            body.removeValue(forKey: "response_format")
        case .anthropicMessages:
            body["tools"] = [[
                "name": tool.name,
                "description": tool.description,
                "input_schema": parameters
            ]]
            body["tool_choice"] = ["type": "tool", "name": tool.name]
        case .googleGemini:
            body["tools"] = [["functionDeclarations": [function]]]
            body["toolConfig"] = [
                "functionCallingConfig": [
                    "mode": "ANY",
                    "allowedFunctionNames": [tool.name]
                ]
            ]
            if var generation = body["generationConfig"] as? [String: Any] {
                generation.removeValue(forKey: "responseMimeType")
                body["generationConfig"] = generation
            }
        case .ollama:
            body["tools"] = [["type": "function", "function": function]]
            body.removeValue(forKey: "format")
        case .appleIntelligence:
            break
        }
        return body
    }

    private func chatBody(
        systemPrompt: String,
        userPrompt: String,
        model: String,
        jsonMode: Bool,
        modernTokenParameter: Bool,
        options: AIGenerationOptions
    ) -> [String: Any] {
        var body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ]
        ]
        body[modernTokenParameter ? "max_completion_tokens" : "max_tokens"] = options.normalizedMaxOutputTokens
        body["temperature"] = options.normalizedTemperature
        if jsonMode {
            body["response_format"] = ["type": "json_object"]
        }
        return body
    }

    private func endpoint(
        for configuration: AIProviderConfiguration,
        model: String,
        apiKey: String
    ) throws -> URL {
        let base = configuration.resolvedBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !base.isEmpty else { throw AIEqualizerError.invalidEndpoint }

        switch configuration.wireProtocol {
        case .openAIResponses:
            return try appendingRoute("responses", to: base, acceptingSuffix: "/responses")
        case .openAIChat:
            return try appendingRoute("chat/completions", to: base, acceptingSuffix: "/chat/completions")
        case .openAICompatible:
            return try openAICompatibleEndpoint(
                route: "chat/completions",
                base: base,
                acceptingSuffix: "/chat/completions"
            )
        case .anthropicMessages:
            return try appendingRoute("messages", to: base, acceptingSuffix: "/messages")
        case .ollama:
            return try appendingRoute("api/chat", to: base, acceptingSuffix: "/api/chat")
        case .googleGemini:
            let encodedModel = model.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? model
            let route = "models/\(encodedModel):generateContent"
            let raw = base.hasSuffix(":generateContent") ? base : "\(base)/\(route)"
            guard var components = URLComponents(string: raw) else { throw AIEqualizerError.invalidEndpoint }
            var items = components.queryItems ?? []
            items.removeAll { $0.name == "key" }
            items.append(URLQueryItem(name: "key", value: apiKey))
            components.queryItems = items
            guard let url = components.url else { throw AIEqualizerError.invalidEndpoint }
            return url
        case .azureOpenAI:
            guard var components = URLComponents(string: base) else {
                throw AIEqualizerError.invalidEndpoint
            }
            if components.path.contains("/openai/deployments/") {
                if !components.path.hasSuffix("/chat/completions") {
                    components.path += "/chat/completions"
                }
            } else {
                let deployment = model.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? model
                components.path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                components.path = "/\(components.path.isEmpty ? "" : components.path + "/")openai/deployments/\(deployment)/chat/completions"
            }
            if !(components.queryItems ?? []).contains(where: { $0.name == "api-version" }) {
                var items = components.queryItems ?? []
                items.append(URLQueryItem(name: "api-version", value: "2024-10-21"))
                components.queryItems = items
            }
            guard let url = components.url else { throw AIEqualizerError.invalidEndpoint }
            return url
        case .appleIntelligence:
            throw AIEqualizerError.invalidEndpoint
        }
    }

    private func modelDiscoveryEndpoint(
        for configuration: AIProviderConfiguration,
        apiKey: String
    ) throws -> URL? {
        let customURL = configuration.modelDiscoveryURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !customURL.isEmpty {
            guard var components = URLComponents(string: customURL) else {
                throw AIEqualizerError.invalidEndpoint
            }
            if configuration.wireProtocol == .openAICompatible,
               components.host?.lowercased() == "dengdeng.ganiran.com",
               components.path == "/models" {
                components.path = "/v1/models"
            }
            if configuration.wireProtocol == .googleGemini,
               !(components.queryItems ?? []).contains(where: { $0.name == "key" }) {
                var items = components.queryItems ?? []
                items.append(URLQueryItem(name: "key", value: apiKey))
                components.queryItems = items
            }
            guard let url = components.url else { throw AIEqualizerError.invalidEndpoint }
            return url
        }

        if configuration.wireProtocol == .azureOpenAI {
            return nil
        }

        let base = configuration.resolvedBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: base) else {
            throw AIEqualizerError.invalidEndpoint
        }

        let suffixes = ["/chat/completions", "/responses", "/messages", "/api/chat"]
        let hadExplicitGenerationRoute = suffixes.contains { components.path.hasSuffix($0) }
        for suffix in suffixes where components.path.hasSuffix(suffix) {
            components.path.removeLast(suffix.count)
            break
        }

        switch configuration.wireProtocol {
        case .openAIResponses, .openAIChat, .anthropicMessages:
            components.path = Self.appendingPath("models", to: components.path)
            if configuration.wireProtocol == .anthropicMessages {
                var items = components.queryItems ?? []
                items.append(URLQueryItem(name: "limit", value: "1000"))
                components.queryItems = items
            }
        case .openAICompatible:
            let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if path.isEmpty, !hadExplicitGenerationRoute {
                components.path = "/v1/models"
            } else {
                components.path = Self.appendingPath("models", to: components.path)
            }
        case .googleGemini:
            components.path = Self.appendingPath("models", to: components.path)
            var items = components.queryItems ?? []
            items.removeAll { $0.name == "key" || $0.name == "pageSize" }
            items.append(URLQueryItem(name: "pageSize", value: "1000"))
            items.append(URLQueryItem(name: "key", value: apiKey))
            components.queryItems = items
        case .ollama:
            components.path = Self.appendingPath("api/tags", to: components.path)
        case .azureOpenAI, .appleIntelligence:
            return nil
        }

        guard let url = components.url else { throw AIEqualizerError.invalidEndpoint }
        return url
    }

    private func applyAuthentication(
        wireProtocol: AIWireProtocol,
        apiKey: String,
        to request: inout URLRequest
    ) {
        switch wireProtocol {
        case .openAIResponses, .openAIChat, .openAICompatible:
            if !apiKey.isEmpty {
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            }
        case .anthropicMessages:
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        case .azureOpenAI:
            request.setValue(apiKey, forHTTPHeaderField: "api-key")
        case .googleGemini, .ollama, .appleIntelligence:
            break
        }
    }

    private func appendingRoute(_ route: String, to base: String, acceptingSuffix suffix: String) throws -> URL {
        let value = base.hasSuffix(suffix) ? base : "\(base)/\(route)"
        guard let url = URL(string: value) else { throw AIEqualizerError.invalidEndpoint }
        return url
    }

    private func openAICompatibleEndpoint(
        route: String,
        base: String,
        acceptingSuffix suffix: String
    ) throws -> URL {
        if base.hasSuffix(suffix), let url = URL(string: base) {
            return url
        }
        guard var components = URLComponents(string: base) else {
            throw AIEqualizerError.invalidEndpoint
        }
        let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = path.isEmpty
            ? "/v1/\(route)"
            : Self.appendingPath(route, to: components.path)
        guard let url = components.url else { throw AIEqualizerError.invalidEndpoint }
        return url
    }

    private func fallbackModel(
        for configuration: AIProviderConfiguration,
        apiKey: String
    ) async throws -> String? {
        let models = try await fetchModels(configuration: configuration, apiKey: apiKey)
        let current = configuration.resolvedModel
        let preferred = configuration.wireProtocol.defaultModel
        if preferred != current, models.contains(preferred) {
            return preferred
        }
        return models.first { $0 != current }
    }

    private func applyCustomHeaders(_ json: String, to request: inout URLRequest) {
        guard let data = json.data(using: .utf8),
              let headers = try? JSONDecoder().decode([String: String].self, from: data) else { return }
        for (name, value) in headers where !name.isEmpty {
            request.setValue(value, forHTTPHeaderField: name)
        }
    }

    private static func extractText(from data: Data, wireProtocol: AIWireProtocol) throws -> String {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIEqualizerError.invalidResponse
        }

        let text: String?
        switch wireProtocol {
        case .openAIResponses:
            if let direct = root["output_text"] as? String {
                text = direct
            } else {
                let output = root["output"] as? [[String: Any]] ?? []
                text = output
                    .flatMap { $0["content"] as? [[String: Any]] ?? [] }
                    .compactMap { $0["text"] as? String }
                    .joined(separator: "\n")
            }
        case .openAIChat, .openAICompatible, .azureOpenAI:
            let choices = root["choices"] as? [[String: Any]]
            let message = choices?.first?["message"] as? [String: Any]
            text = message?["content"] as? String
        case .anthropicMessages:
            let content = root["content"] as? [[String: Any]]
            text = content?.compactMap { $0["text"] as? String }.joined(separator: "\n")
        case .googleGemini:
            let candidates = root["candidates"] as? [[String: Any]]
            let content = candidates?.first?["content"] as? [String: Any]
            let parts = content?["parts"] as? [[String: Any]]
            text = parts?.compactMap { $0["text"] as? String }.joined(separator: "\n")
        case .ollama:
            let message = root["message"] as? [String: Any]
            text = message?["content"] as? String ?? root["response"] as? String
        case .appleIntelligence:
            text = nil
        }

        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIEqualizerError.invalidResponse
        }
        return text
    }

    private static func extractToolArguments(
        from data: Data,
        wireProtocol: AIWireProtocol,
        toolName: String,
        allowContentFallback: Bool,
        requireExactlyOnce: Bool
    ) throws -> AIRequiredToolResponse {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIEqualizerError.invalidResponse
        }

        let arguments: Any?
        let toolInvocationCount: Int
        let matchingToolInvocationCount: Int
        switch wireProtocol {
        case .openAIResponses:
            let output = root["output"] as? [[String: Any]] ?? []
            let calls = output.filter { ($0["type"] as? String) == "function_call" }
            let matchingCalls = calls.filter { ($0["name"] as? String) == toolName }
            toolInvocationCount = calls.count
            matchingToolInvocationCount = matchingCalls.count
            arguments = matchingCalls.first?["arguments"]
        case .openAIChat, .openAICompatible, .azureOpenAI:
            let choices = root["choices"] as? [[String: Any]]
            let message = choices?.first?["message"] as? [String: Any]
            let calls = message?["tool_calls"] as? [[String: Any]] ?? []
            let matchingCalls = calls.filter {
                let function = $0["function"] as? [String: Any]
                return (function?["name"] as? String) == toolName
            }
            toolInvocationCount = calls.count
            matchingToolInvocationCount = matchingCalls.count
            arguments = (matchingCalls.first?["function"] as? [String: Any])?["arguments"]
        case .anthropicMessages:
            let content = root["content"] as? [[String: Any]] ?? []
            let calls = content.filter { ($0["type"] as? String) == "tool_use" }
            let matchingCalls = calls.filter { ($0["name"] as? String) == toolName }
            toolInvocationCount = calls.count
            matchingToolInvocationCount = matchingCalls.count
            arguments = matchingCalls.first?["input"]
        case .googleGemini:
            let candidates = root["candidates"] as? [[String: Any]]
            let content = candidates?.first?["content"] as? [String: Any]
            let parts = content?["parts"] as? [[String: Any]] ?? []
            let calls = parts.compactMap { $0["functionCall"] as? [String: Any] }
            let matchingCalls = calls.filter { ($0["name"] as? String) == toolName }
            toolInvocationCount = calls.count
            matchingToolInvocationCount = matchingCalls.count
            arguments = matchingCalls.first?["args"]
        case .ollama:
            let message = root["message"] as? [String: Any]
            let rawCalls = message?["tool_calls"] as? [[String: Any]] ?? []
            let calls = rawCalls.compactMap { $0["function"] as? [String: Any] }
            let matchingCalls = calls.filter { ($0["name"] as? String) == toolName }
            toolInvocationCount = rawCalls.count
            matchingToolInvocationCount = matchingCalls.count
            arguments = matchingCalls.first?["arguments"]
        case .appleIntelligence:
            return AIRequiredToolResponse(
                arguments: try extractText(from: data, wireProtocol: wireProtocol),
                invocation: .contentFallback,
                toolInvocationCount: 0
            )
        }

        if requireExactlyOnce {
            // A required function choice is successful only when the response
            // contains exactly one tool call and it is the named Mono tool.
            // Duplicate calls and calls to any other function are rejected.
            guard toolInvocationCount == 1,
                  matchingToolInvocationCount == 1 else {
                throw AIEqualizerError.invalidResponse
            }
        } else if toolInvocationCount > 0, matchingToolInvocationCount == 0 {
            // Prompt fallback applies only to responses with no tool call; it
            // must not conceal a model invoking the wrong function.
            throw AIEqualizerError.invalidResponse
        }

        if let value = arguments as? String,
           !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return AIRequiredToolResponse(
                arguments: value,
                invocation: .toolCall,
                toolInvocationCount: toolInvocationCount
            )
        }
        if let arguments,
           JSONSerialization.isValidJSONObject(arguments),
           let data = try? JSONSerialization.data(withJSONObject: arguments),
           let value = String(data: data, encoding: .utf8) {
            return AIRequiredToolResponse(
                arguments: value,
                invocation: .toolCall,
                toolInvocationCount: toolInvocationCount
            )
        }

        // Compatibility endpoints may put the final JSON in message.content.
        // This is accepted only when the remotely managed tool policy opts in;
        // otherwise a successful required-tool request must contain the named
        // function call and cannot silently degrade into prompt-only output.
        guard allowContentFallback else { throw AIEqualizerError.invalidResponse }
        return AIRequiredToolResponse(
            arguments: try extractText(from: data, wireProtocol: wireProtocol),
            invocation: .contentFallback,
            toolInvocationCount: 0
        )
    }

    private static func extractModels(from data: Data, wireProtocol: AIWireProtocol) throws -> [String] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIEqualizerError.invalidResponse
        }

        if let dataItems = root["data"] as? [[String: Any]] {
            let values = dataItems.compactMap { $0["id"] as? String }
            if !values.isEmpty { return values }
        }

        if let modelItems = root["models"] as? [[String: Any]] {
            return modelItems.compactMap { item in
                if wireProtocol == .googleGemini,
                   let methods = item["supportedGenerationMethods"] as? [String],
                   !methods.contains("generateContent") {
                    return nil
                }
                let value = item["name"] as? String ?? item["model"] as? String ?? item["id"] as? String
                guard let value else { return nil }
                return wireProtocol == .googleGemini && value.hasPrefix("models/")
                    ? String(value.dropFirst("models/".count))
                    : value
            }
        }

        if let values = root["models"] as? [String] { return values }
        throw AIEqualizerError.invalidResponse
    }

    private static func appendingPath(_ component: String, to path: String) -> String {
        let base = path.hasSuffix("/") ? String(path.dropLast()) : path
        return "\(base)/\(component)"
    }

    private static func errorMessage(from data: Data) -> String {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return "" }
        if let error = root["error"] as? [String: Any], let message = error["message"] as? String {
            return message
        }
        if let error = root["error"] as? String {
            return error
        }
        return root["message"] as? String
            ?? root["detail"] as? String
            ?? ""
    }

    private static func isUnsupportedModelResponse(
        statusCode: Int,
        message: String
    ) -> Bool {
        guard statusCode == 400 || statusCode == 404 || statusCode == 422 else { return false }
        let normalized = message.lowercased()
        return normalized.contains("model") && (
            normalized.contains("not supported")
                || normalized.contains("unsupported")
                || normalized.contains("not found")
                || normalized.contains("unavailable")
                || normalized.contains("does not exist")
        )
    }
}
