import Foundation

struct KCMSearchPage {
    let songs: [Song]
    let total: Int?
    let hasMore: Bool
}

struct KCMPlaylistPage {
    let playlists: [Playlist]
    let hasMore: Bool
}

struct KCMArtistSearchPage {
    let artists: [ArtistInfo]
    let total: Int
    let hasMore: Bool
}

struct KCMPlaylistSearchPage {
    let playlists: [Playlist]
    let total: Int
    let hasMore: Bool
}

struct KCMAlbumSearchPage {
    let albums: [SearchAlbum]
    let total: Int
    let hasMore: Bool
}

struct KCMMVSearchPage {
    let mvs: [KCMMV]
    let total: Int
    let hasMore: Bool
}

struct KCMPlaylistCategory: Identifiable, Hashable {
    let id: Int
    let name: String
    let groupName: String?
}

struct KCMQRCodeSession: Sendable {
    let key: String
    let imageData: Data
}

enum KCMQRCodeStatus: Sendable {
    case expired
    case waiting
    case scanned
    case confirmed
}

struct KCMAccountProfile: Sendable {
    let userID: Int
    let nickname: String?
    let avatarURL: URL?
    let membershipLevel: KCMMembershipLevel
    let membershipExpiration: Date?
    let conceptProductType: String?

    var isVIP: Bool { membershipLevel != .none }
}

struct KCMSongQualityInfo: Identifiable, Sendable {
    let quality: SoundQuality
    let code: String
    let bitrate: Int
    let size: Int
    let isAvailable: Bool

    var id: String { code }

    var sizeText: String {
        guard size > 0 else { return "" }
        if size >= 1_048_576 {
            return String(format: "%.1f MB", Double(size) / 1_048_576)
        }
        if size >= 1_024 {
            return String(format: "%.0f KB", Double(size) / 1_024)
        }
        return "\(size) B"
    }
}

struct KCMPlaybackURLResult: Sendable {
    let url: URL
    let quality: SoundQuality
}

enum KCMDailyVIPClaimResult: Sendable {
    case claimed
    case alreadyClaimed
}

enum KCMMusicError: LocalizedError {
    case authenticationRequired
    case sessionExpired(KCMMusicService.SessionCredentialContext? = nil)
    case verificationRequired
    case invalidResponse
    case server(Int, String)
    case unavailable

    var errorDescription: String? {
        switch self {
        case .authenticationRequired:
            return String(localized: "kcm_error_authentication_required")
        case .sessionExpired:
            return String(localized: "kcm_error_session_expired")
        case .verificationRequired:
            return String(localized: "kcm_error_verification_required")
        case .invalidResponse:
            return String(localized: "kcm_error_invalid_response")
        case .server(let code, let message):
            return message.isEmpty
                ? String(format: String(localized: "kcm_error_server_format"), code)
                : message
        case .unavailable:
            return String(localized: "kcm_error_unavailable")
        }
    }
}
