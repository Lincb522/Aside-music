import Foundation

/// Stable identity used by the song-content service. The platform ID is kept
/// separate from the local numeric ID so content cannot be mixed across music
/// providers or recording versions.
struct SongContentRequestIdentity: Hashable, Sendable {
    let platform: String
    let platformSongID: String

    var cacheKey: String { "\(platform):\(platformSongID)" }
}

struct SongContentRequestSnapshot: Encodable, Sendable {
    struct ArtistSnapshot: Encodable, Sendable {
        let id: String
        let name: String
    }

    struct AlbumSnapshot: Encodable, Sendable {
        let id: String
        let name: String
    }

    let title: String
    let artists: [ArtistSnapshot]
    let album: AlbumSnapshot?
    let durationMs: Int?
    let coverUrl: String?
    let isrc: String?
    let platformArtistId: String?
    let platformAlbumId: String?
}

extension Song {
    var contentRequestIdentity: SongContentRequestIdentity {
        switch musicSource {
        case .netease:
            return SongContentRequestIdentity(platform: "NCM", platformSongID: String(id))
        case .qqmusic:
            return SongContentRequestIdentity(platform: "QCM", platformSongID: qqMid ?? String(id))
        case .qishui:
            return SongContentRequestIdentity(
                platform: "QSM",
                platformSongID: qishuiTrackId.map(String.init) ?? String(id)
            )
        case .kugou:
            return SongContentRequestIdentity(platform: "KCM", platformSongID: kugouHash ?? String(id))
        case .appleMusic:
            return SongContentRequestIdentity(
                platform: "AM",
                platformSongID: appleMusicCatalogID ?? String(id)
            )
        case .local:
            return SongContentRequestIdentity(platform: "LOCAL", platformSongID: String(id))
        }
    }

    var contentRequestSnapshot: SongContentRequestSnapshot {
        let platformArtistID: String? = {
            switch musicSource {
            case .qqmusic: return qqArtistMid
            default: return artists.first.map { String($0.id) }
            }
        }()
        let platformAlbumID: String? = {
            switch musicSource {
            case .qqmusic: return qqAlbumMid
            case .kugou: return kugouAlbumID.map(String.init)
            default: return album.map { String($0.id) }
            }
        }()

        return SongContentRequestSnapshot(
            title: name,
            artists: artists.map {
                SongContentRequestSnapshot.ArtistSnapshot(id: String($0.id), name: $0.name)
            },
            album: album.map {
                SongContentRequestSnapshot.AlbumSnapshot(
                    id: platformAlbumID ?? String($0.id),
                    name: $0.name
                )
            },
            durationMs: dt,
            coverUrl: coverUrl?.absoluteString,
            isrc: musicSource == .appleMusic ? appleMusicISRC : nil,
            platformArtistId: platformArtistID,
            platformAlbumId: platformAlbumID
        )
    }
}

struct SongContentDetailResponse: Codable, Sendable {
    let song: SongContentRemoteSong?
    let content: SongContentBody?
    let generation: SongContentGeneration?
    let sources: [SongContentSource]?
    let cache: SongContentCacheMetadata?
}

struct SongContentRemoteSong: Codable, Sendable {
    let id: String
    let title: String
    let artists: [SongContentArtist]
    let album: SongContentAlbum?
    let durationMs: Int?
    let releaseDate: SongContentReleaseDate?
    let coverUrl: String?
    let platformMappings: [SongContentPlatformMapping]
}

struct SongContentArtist: Codable, Identifiable, Sendable {
    let id: String
    let name: String
}

struct SongContentAlbum: Codable, Sendable {
    let id: String?
    let name: String
}

struct SongContentReleaseDate: Codable, Sendable {
    let value: String
    let precision: String?
}

struct SongContentPlatformMapping: Codable, Sendable {
    let platform: String
    let songId: String
}

struct SongContentBody: Codable, Sendable {
    let status: String
    let version: String?
    let songSummary: String?
    let creationStory: String?
    let background: String?
    let albumSummary: String?
    let updatedAt: String?
    let sourceSummary: SongContentSourceSummary?
    let sourceRefs: [String: [String]]?
    let confidence: String?
    let riskFlags: [String]?

    var hasPublishedCopy: Bool {
        status == "published" && [songSummary, creationStory, background, albumSummary]
            .contains { value in
                guard let value else { return false }
                return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
    }
}

struct SongContentSourceSummary: Codable, Sendable {
    let count: Int
    let highestGrade: String?
}

struct SongContentSource: Codable, Identifiable, Sendable {
    let id: String
    let title: String
    let publisher: String?
    let url: String
    let publishedAt: String?
    let grade: String?

    var destinationURL: URL? { URL(string: url) }
}

struct SongContentGeneration: Codable, Sendable {
    let status: String
    let retryAfterSeconds: Int?

    var isActive: Bool {
        status == "generating"
    }
}

struct SongContentCacheMetadata: Codable, Sendable {
    let etag: String?
    let maxAge: Int?
}

struct SongContentFeatureConfiguration: Codable, Sendable {
    let schemaVersion: Int
    let release: String
    let version: Int
    let enabled: Bool
    let modules: SongContentModuleConfiguration
    let agentManagementEnabled: Bool?
    let agents: AppAgentConfigurationSet?
    let pollingIntervalSeconds: Int
    let cacheMaxAgeSeconds: Int
    let generatedAt: String?
    let etag: String?

    static let bundledDefault = SongContentFeatureConfiguration(
        schemaVersion: 1,
        release: "bundled-default",
        version: 0,
        enabled: true,
        modules: .allEnabled,
        agentManagementEnabled: false,
        agents: nil,
        pollingIntervalSeconds: 3,
        cacheMaxAgeSeconds: 3_600,
        generatedAt: nil,
        etag: nil
    )
}

enum AppAgentIdentifier: String, Sendable {
    case equalizer
    case listeningInsight
    case specialGreeting
    case stageDirector
    case wallpaperTranslator
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
}

struct AppAgentConfigurationSet: Codable, Sendable {
    let equalizer: AppAgentConfiguration?
    let listeningInsight: AppAgentConfiguration?
    let specialGreeting: AppAgentConfiguration?
    let stageDirector: AppAgentConfiguration?
    let wallpaperTranslator: AppAgentConfiguration?

    subscript(identifier: AppAgentIdentifier) -> AppAgentConfiguration? {
        switch identifier {
        case .equalizer: return equalizer
        case .listeningInsight: return listeningInsight
        case .specialGreeting: return specialGreeting
        case .stageDirector: return stageDirector
        case .wallpaperTranslator: return wallpaperTranslator
        }
    }
}

struct SongContentModuleConfiguration: Codable, Sendable {
    let songSummary: Bool
    let creationStory: Bool
    let background: Bool
    let albumSummary: Bool
    let sources: Bool
    let similarSongs: Bool?
    let artistSongs: Bool?

    static let allEnabled = SongContentModuleConfiguration(
        songSummary: true,
        creationStory: true,
        background: true,
        albumSummary: true,
        sources: true,
        similarSongs: true,
        artistSongs: true
    )
}
