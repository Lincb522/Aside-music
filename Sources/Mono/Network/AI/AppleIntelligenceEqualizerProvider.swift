import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

#if canImport(FoundationModels)
@available(iOS 26.0, *)
private actor AppleIntelligenceTuningToolRecorder {
    private var payloads: [String] = []

    func record(_ payload: String) {
        payloads.append(payload)
    }

    func snapshot() -> [String] {
        payloads
    }
}

@available(iOS 26.0, *)
private struct AppleIntelligenceTuningTool: Tool {
    @Generable(description: "Arguments for one complete Mono audio tuning proposal")
    struct Arguments {
        @Guide(description: "A complete JSON object matching the requested Mono audio tuning schema. Do not wrap it in Markdown.")
        var payload: String
    }

    let name: String
    let description = "Submit exactly one complete Mono audio tuning proposal for local validation and compilation."
    let recorder: AppleIntelligenceTuningToolRecorder

    func call(arguments: Arguments) async throws -> String {
        await recorder.record(arguments.payload)
        return "The proposal was received. Do not call this tool again."
    }
}
#endif

/// 端侧 Apple Intelligence（FoundationModels）文本生成通道，iOS 26+ 且设备模型可用时生效，
/// 否则抛出 `modelUnavailable` 由上层回退到其他提供商。
enum AppleIntelligenceEqualizerProvider {
    static func generate(systemPrompt: String, userPrompt: String) async throws -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let model = SystemLanguageModel.default
            guard model.isAvailable else { throw AIEqualizerError.modelUnavailable }
            let session = LanguageModelSession(instructions: systemPrompt)
            let response = try await session.respond(to: userPrompt)
            return response.content
        }
        #endif
        throw AIEqualizerError.modelUnavailable
    }

    /// Uses FoundationModels' native tool-calling path. The recorder is the
    /// source of truth: plain assistant text is never accepted as a tuning
    /// result, and duplicate or missing calls fail local validation.
    static func generateRequiringTool(
        systemPrompt: String,
        userPrompt: String,
        toolName: String
    ) async throws -> AIRequiredToolResponse {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let model = SystemLanguageModel.default
            guard model.isAvailable else { throw AIEqualizerError.modelUnavailable }

            let normalizedToolName = toolName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard normalizedToolName == "mono_audio_tuning" else {
                throw AIEqualizerError.invalidResponse
            }

            let recorder = AppleIntelligenceTuningToolRecorder()
            let tool = AppleIntelligenceTuningTool(
                name: normalizedToolName,
                recorder: recorder
            )
            let instructions = """
            \(systemPrompt)

            Mandatory execution contract: call \(normalizedToolName) exactly once. Put the complete tuning JSON object in its payload argument. Do not return the proposal as assistant text and do not call any other tool.
            """
            let session = LanguageModelSession(
                model: model,
                tools: [tool],
                instructions: instructions
            )

            // One respond call keeps the on-device generation and tool
            // continuation in the same session request; no second model pass.
            _ = try await session.respond(to: userPrompt)
            let payloads = await recorder.snapshot()
            guard payloads.count == 1,
                  let payload = payloads.first?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !payload.isEmpty else {
                throw AIEqualizerError.invalidResponse
            }
            return AIRequiredToolResponse(
                arguments: payload,
                invocation: .toolCall,
                toolInvocationCount: payloads.count
            )
        }
        #endif
        throw AIEqualizerError.modelUnavailable
    }
}
