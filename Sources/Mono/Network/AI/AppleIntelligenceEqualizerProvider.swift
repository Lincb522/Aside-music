import Foundation

#if canImport(FoundationModels)
import FoundationModels
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
}
