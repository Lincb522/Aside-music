import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

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
