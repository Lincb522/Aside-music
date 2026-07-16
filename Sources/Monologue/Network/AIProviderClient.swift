import Foundation

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
        let (data, response) = try await URLSession(configuration: sessionConfiguration).data(for: request)
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
        apiKey: String
    ) async throws -> String {
        if configuration.wireProtocol == .appleIntelligence {
            return try await AppleIntelligenceEqualizerProvider.generate(
                systemPrompt: systemPrompt,
                userPrompt: userPrompt
            )
        }

        let normalizedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if configuration.wireProtocol.requiresAPIKey && normalizedKey.isEmpty {
            throw AIEqualizerError.missingAPIKey
        }

        let request = try makeRequest(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            configuration: configuration,
            apiKey: normalizedKey
        )
        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.timeoutIntervalForRequest = configuration.timeout
        sessionConfiguration.timeoutIntervalForResource = configuration.timeout + 5
        let session = URLSession(configuration: sessionConfiguration)
        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw AIEqualizerError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw AIEqualizerError.httpStatus(http.statusCode, Self.errorMessage(from: data))
        }
        return try Self.extractText(from: data, wireProtocol: configuration.wireProtocol)
    }

    private func makeRequest(
        systemPrompt: String,
        userPrompt: String,
        configuration: AIProviderConfiguration,
        apiKey: String
    ) throws -> URLRequest {
        let model = configuration.resolvedModel
        guard !model.isEmpty else { throw AIEqualizerError.modelUnavailable }
        let url = try endpoint(for: configuration, model: model, apiKey: apiKey)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = configuration.timeout
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")

        let body: [String: Any]
        switch configuration.wireProtocol {
        case .openAIResponses:
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            body = [
                "model": model,
                "instructions": systemPrompt,
                "input": userPrompt,
                "max_output_tokens": 2_400
            ]

        case .openAIChat:
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            body = chatBody(
                systemPrompt: systemPrompt,
                userPrompt: userPrompt,
                model: model,
                jsonMode: true,
                modernTokenParameter: true
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
                modernTokenParameter: false
            )

        case .anthropicMessages:
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            body = [
                "model": model,
                "system": systemPrompt,
                "max_tokens": 2_400,
                "temperature": 0.1,
                "messages": [["role": "user", "content": userPrompt]]
            ]

        case .googleGemini:
            body = [
                "systemInstruction": ["parts": [["text": systemPrompt]]],
                "contents": [["role": "user", "parts": [["text": userPrompt]]]],
                "generationConfig": [
                    "temperature": 0.1,
                    "maxOutputTokens": 2_400,
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
                modernTokenParameter: true
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
                "options": ["temperature": 0.1]
            ]

        case .appleIntelligence:
            throw AIEqualizerError.invalidEndpoint
        }

        applyCustomHeaders(configuration.customHeadersJSON, to: &request)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func chatBody(
        systemPrompt: String,
        userPrompt: String,
        model: String,
        jsonMode: Bool,
        modernTokenParameter: Bool
    ) -> [String: Any] {
        var body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ]
        ]
        body[modernTokenParameter ? "max_completion_tokens" : "max_tokens"] = 2_400
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
        case .openAIChat, .openAICompatible:
            return try appendingRoute("chat/completions", to: base, acceptingSuffix: "/chat/completions")
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
        for suffix in suffixes where components.path.hasSuffix(suffix) {
            components.path.removeLast(suffix.count)
            break
        }

        switch configuration.wireProtocol {
        case .openAIResponses, .openAIChat, .openAICompatible, .anthropicMessages:
            components.path = Self.appendingPath("models", to: components.path)
            if configuration.wireProtocol == .anthropicMessages {
                var items = components.queryItems ?? []
                items.append(URLQueryItem(name: "limit", value: "1000"))
                components.queryItems = items
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
        return root["message"] as? String ?? ""
    }
}
