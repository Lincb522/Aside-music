import Foundation

/// Stable platform identity for routes, sharing, and provider-specific requests.
/// The provider ID remains separate from Mono's numeric ID so catalog entries
/// from different services can never be mixed.
struct PlatformSongIdentity: Hashable, Sendable {
    let platform: String
    let platformSongID: String

    var cacheKey: String { "\(platform):\(platformSongID)" }
}

extension Song {
    var platformIdentity: PlatformSongIdentity {
        switch musicSource {
        case .netease:
            return PlatformSongIdentity(platform: "NCM", platformSongID: String(id))
        case .qqmusic:
            return PlatformSongIdentity(platform: "QCM", platformSongID: qqMid ?? String(id))
        case .qishui:
            return PlatformSongIdentity(
                platform: "QSM",
                platformSongID: qishuiTrackId.map(String.init) ?? String(id)
            )
        case .kugou:
            return PlatformSongIdentity(platform: "KCM", platformSongID: kugouHash ?? String(id))
        case .appleMusic:
            return PlatformSongIdentity(
                platform: "AM",
                platformSongID: appleMusicCatalogID ?? String(id)
            )
        case .local:
            return PlatformSongIdentity(platform: "LOCAL", platformSongID: String(id))
        }
    }
}

/// Provider-owned details shown on the song information page. All copy in this
/// payload comes directly from the selected music service or local file tags;
/// it is never generated or rewritten by Mono's AI services.
struct PlatformSongDetail {
    var releaseDate: String?
    var attributes: [PlatformSongAttribute]
    var sections: [PlatformSongSection]

    static let empty = PlatformSongDetail(
        releaseDate: nil,
        attributes: [],
        sections: []
    )
}

struct PlatformSongAttribute: Identifiable, Hashable {
    let id: String
    let label: String
    let value: String
}

struct PlatformSongSection: Identifiable, Hashable {
    let id: String
    let title: String
    let body: String
}

struct AppAgentRemoteConfiguration: Codable, Sendable {
    let schemaVersion: Int
    let release: String
    let version: Int
    let agentManagementEnabled: Bool?
    let agents: AppAgentConfigurationSet?
    let cacheMaxAgeSeconds: Int
    let generatedAt: String?
    let etag: String?

    static let bundledDefault = AppAgentRemoteConfiguration(
        schemaVersion: 1,
        release: "bundled-default",
        version: 0,
        agentManagementEnabled: false,
        agents: nil,
        cacheMaxAgeSeconds: 3_600,
        generatedAt: nil,
        etag: nil
    )
}

enum AppAgentIdentifier: String, Sendable {
    case equalizer
    case listeningInsight
    case specialGreeting
}

struct AppAgentConfiguration: Codable, Sendable {
    let enabled: Bool
    let promptVersion: String
    let systemPrompt: String
    let secondarySystemPrompt: String
    let userPromptTemplate: String
    let temperature: Double
    let maxOutputTokens: Int
    let minimumTimeoutSeconds: Double
    let maxAttempts: Int?
    /// Server-managed skill configuration. `skillConfiguration` is retained as
    /// a decoding alias for early server builds; new payloads use `skills`.
    let skills: AppAgentSkillConfiguration?
    let skillConfiguration: AppAgentSkillConfiguration?
    let toolPolicy: AppAgentToolPolicyConfiguration?

    var resolvedSkillConfiguration: AppAgentSkillConfiguration? {
        skills ?? skillConfiguration
    }

    func systemPrompt(fallback: String, secondaryFallback: String? = nil) -> String {
        let primary = systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let secondary = secondarySystemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if secondaryFallback != nil, !secondary.isEmpty { return secondary }
        return primary.isEmpty ? (secondaryFallback ?? fallback) : primary
    }

    func userPrompt(fallback: String) -> String {
        let template = userPromptTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !template.isEmpty else { return fallback }
        if template.contains("{{input}}") {
            return template.replacingOccurrences(of: "{{input}}", with: fallback)
        }
        return "\(template)\n\n\(fallback)"
    }

    var generationOptions: AIGenerationOptions {
        AIGenerationOptions(
            temperature: temperature,
            maxOutputTokens: maxOutputTokens
        )
    }

    var resolvedMinimumTimeoutSeconds: TimeInterval {
        min(180, max(0, minimumTimeoutSeconds))
    }

    func resolvedMaxAttempts(fallback: Int) -> Int {
        min(4, max(1, maxAttempts ?? fallback))
    }
}

/// Remotely managed capabilities for the tuning Agent. Every field is optional
/// so clients remain compatible with both old payloads and partial rollouts.
struct AppAgentSkillConfiguration: Codable, Equatable, Sendable {
    let revision: String?
    let builtIns: AppAgentBuiltInSkillConfiguration?
    let custom: [AppAgentCustomSkillConfiguration]?
}

struct AppAgentBuiltInSkillConfiguration: Codable, Equatable, Sendable {
    let measurementEvidence: Bool?
    let deviceCoordination: Bool?
    let headroomGuard: Bool?
    let phaseGuard: Bool?
    let outputValidation: Bool?
    let artistReference: Bool?
    let vocalReference: Bool?
}

struct AppAgentCustomSkillConfiguration: Codable, Equatable, Sendable {
    let id: String?
    let name: String?
    let instruction: String?
    let enabled: Bool?
    /// Compatibility with the local custom-skill representation.
    let isEnabled: Bool?

    var resolvedEnabled: Bool { enabled ?? isEnabled ?? true }
}

struct AppAgentToolPolicyConfiguration: Codable, Equatable, Sendable {
    let revision: String?
    let requiredToolName: String?
    let invocationMode: String?
    let requireExactlyOnce: Bool?
    let localValidationRequired: Bool?
    let allowPromptFallback: Bool?

    static let bundledSafeDefault = AppAgentToolPolicyConfiguration(
        revision: "bundled-v1",
        requiredToolName: "mono_audio_tuning",
        invocationMode: "required",
        requireExactlyOnce: true,
        localValidationRequired: true,
        allowPromptFallback: false
    )

    /// Server policy may supply revision metadata, but cannot replace Mono's
    /// mandatory tool contract or enable prompt/content fallback.
    var resolvedSafePolicy: AppAgentToolPolicyConfiguration {
        AppAgentToolPolicyConfiguration(
            revision: revision?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                ?? Self.bundledSafeDefault.revision,
            requiredToolName: Self.bundledSafeDefault.requiredToolName,
            invocationMode: Self.bundledSafeDefault.invocationMode,
            requireExactlyOnce: true,
            localValidationRequired: true,
            allowPromptFallback: false
        )
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

struct AppAgentConfigurationSet: Codable, Sendable {
    let equalizer: AppAgentConfiguration?
    let listeningInsight: AppAgentConfiguration?
    let specialGreeting: AppAgentConfiguration?

    subscript(identifier: AppAgentIdentifier) -> AppAgentConfiguration? {
        switch identifier {
        case .equalizer: return equalizer
        case .listeningInsight: return listeningInsight
        case .specialGreeting: return specialGreeting
        }
    }
}
