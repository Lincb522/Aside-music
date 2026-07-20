import CryptoKit
import Foundation

// MARK: - Mono Next Suite

enum MonoNextFeature: String, CaseIterable, Codable, Identifiable, Sendable {
    case flow
    case soundTwin
    case spatialLive
    case stems
    case liveMaster
    case dna
    case session
    case recovery

    var id: String { rawValue }
}

struct MonoTrackIdentity: Codable, Hashable, Sendable {
    let source: String
    let songID: Int
    let title: String
    let artist: String

    init(song: Song) {
        source = song.musicSource.rawValue
        songID = song.id
        title = song.name
        artist = song.artistName
    }

    var storageKey: String { "\(source):\(songID)" }
}

struct MonoDNASection: Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable {
        case opening
        case body
        case peak
        case release
    }

    let kind: Kind
    let startProgress: Double
    let endProgress: Double
    let energy: Float
    let density: Float
    let vocalFocus: Float
    let spatialFocus: Float
}

/// A compact, persisted song fingerprint derived from the Agent's measured
/// audio features. It stores measurements rather than raw PCM.
struct MonoTrackDNA: Codable, Equatable, Identifiable, Sendable {
    static let schemaVersion = 1

    let identity: MonoTrackIdentity
    let fingerprint: String
    let capturedAt: Date
    let sampleDuration: Double
    let bpm: Float
    let tempoConfidence: Float
    let tempoStability: Float
    let musicalKey: String
    let keyConfidence: Float
    let loudnessLUFS: Float
    let dynamicRange: Float
    let crestFactor: Float
    let spectralCentroidHz: Float
    let spectralRolloffHz: Float
    let spectralFlatness: Float
    let lowEnergy: Float
    let midEnergy: Float
    let highEnergy: Float
    let transientDensity: Float
    let stereoWidth: Float
    let monoCompatibility: Float
    let vocalPresence: Float
    let vocalWarmth: Float
    let vocalBrightness: Float
    let melodicActivity: Float
    let melodyRangeSemitones: Float
    let genreHints: [String]
    let instrumentHints: [String]
    let energy: Float
    let brightness: Float
    let rhythmicDrive: Float
    let acousticProbability: Float
    let sections: [MonoDNASection]

    var id: String { identity.storageKey }

    init(song: Song, features: AIEqualizerAudioFeatures, now: Date = Date()) {
        identity = MonoTrackIdentity(song: song)
        capturedAt = now
        sampleDuration = features.sampleDuration
        bpm = features.estimatedBPM
        tempoConfidence = features.tempoConfidence
        tempoStability = features.tempoStability
        musicalKey = features.estimatedKey
        keyConfidence = features.keyConfidence
        loudnessLUFS = features.integratedLUFS
        dynamicRange = features.dynamicRangeDR
        crestFactor = features.crestFactorDB
        spectralCentroidHz = features.spectralCentroidHz
        spectralRolloffHz = features.spectralRolloffHz
        spectralFlatness = features.spectralFlatness
        lowEnergy = features.lowEnergyRatio
        midEnergy = features.midEnergyRatio
        highEnergy = features.highEnergyRatio
        transientDensity = features.transientDensity
        stereoWidth = features.measuredStereoWidth
        monoCompatibility = features.monoCompatibility
        vocalPresence = features.vocalReference?.presence ?? 0
        vocalWarmth = features.vocalReference?.warmth ?? 0
        vocalBrightness = features.vocalReference?.brightness ?? 0
        melodicActivity = features.melodicActivity
        melodyRangeSemitones = features.melodyRangeSemitones
        genreHints = features.genreHints
        instrumentHints = features.instrumentHints

        let normalizedLoudness = Self.normalize(features.integratedLUFS, lower: -24, upper: -6)
        let normalizedTransient = Self.normalize(features.transientDensity, lower: 0.02, upper: 0.55)
        let normalizedCentroid = Self.normalize(features.spectralCentroidHz, lower: 700, upper: 5_200)
        let normalizedTempo = Self.normalize(features.estimatedBPM, lower: 65, upper: 168)
        energy = Self.clamp(
            normalizedLoudness * 0.34
                + normalizedTransient * 0.30
                + features.highEnergyRatio * 0.14
                + normalizedTempo * features.tempoConfidence * 0.22
        )
        brightness = Self.clamp(
            normalizedCentroid * 0.58
                + features.highEnergyRatio * 0.28
                + features.spectralFlatness * 0.14
        )
        rhythmicDrive = Self.clamp(
            normalizedTransient * 0.48
                + features.tempoStability * 0.32
                + features.tempoConfidence * 0.20
        )

        let acousticTokens = Set(["acoustic", "piano", "strings", "guitar"])
        let electronicTokens = Set(["electronic", "synth", "edm"])
        let measuredTokens = Set((features.genreHints + features.instrumentHints).map { $0.lowercased() })
        let acousticMatches = Float(measuredTokens.intersection(acousticTokens).count)
        let electronicMatches = Float(measuredTokens.intersection(electronicTokens).count)
        acousticProbability = Self.clamp(
            0.44
                + acousticMatches * 0.18
                - electronicMatches * 0.20
                - features.spectralFlatness * 0.18
        )

        sections = Self.makeSections(
            energy: energy,
            rhythmicDrive: rhythmicDrive,
            vocalPresence: vocalPresence,
            stereoWidth: stereoWidth,
            dynamicRange: features.dynamicRangeDR
        )
        fingerprint = Self.makeFingerprint(identity: identity, features: features)
    }

    private static func makeSections(
        energy: Float,
        rhythmicDrive: Float,
        vocalPresence: Float,
        stereoWidth: Float,
        dynamicRange: Float
    ) -> [MonoDNASection] {
        let dynamicLift = normalize(dynamicRange, lower: 4, upper: 16) * 0.12
        let spatial = clamp(normalize(stereoWidth, lower: 0.7, upper: 1.7))
        return [
            MonoDNASection(
                kind: .opening,
                startProgress: 0,
                endProgress: 0.16,
                energy: clamp(energy * 0.72),
                density: clamp(rhythmicDrive * 0.68),
                vocalFocus: clamp(vocalPresence * 0.75),
                spatialFocus: clamp(spatial * 0.78)
            ),
            MonoDNASection(
                kind: .body,
                startProgress: 0.16,
                endProgress: 0.58,
                energy: clamp(energy * 0.96),
                density: clamp(rhythmicDrive * 0.95),
                vocalFocus: clamp(vocalPresence),
                spatialFocus: clamp(spatial)
            ),
            MonoDNASection(
                kind: .peak,
                startProgress: 0.58,
                endProgress: 0.84,
                energy: clamp(energy + dynamicLift),
                density: clamp(rhythmicDrive + dynamicLift),
                vocalFocus: clamp(vocalPresence + 0.06),
                spatialFocus: clamp(spatial + 0.08)
            ),
            MonoDNASection(
                kind: .release,
                startProgress: 0.84,
                endProgress: 1,
                energy: clamp(energy * 0.78),
                density: clamp(rhythmicDrive * 0.74),
                vocalFocus: clamp(vocalPresence * 0.88),
                spatialFocus: clamp(spatial * 0.9)
            )
        ]
    }

    private static func makeFingerprint(
        identity: MonoTrackIdentity,
        features: AIEqualizerAudioFeatures
    ) -> String {
        let bands = features.bandEnergyDB.map { String(format: "%.2f", $0) }.joined(separator: ",")
        let chroma = features.chroma.map { String(format: "%.3f", $0) }.joined(separator: ",")
        let source = [
            identity.storageKey,
            String(format: "%.2f", features.estimatedBPM),
            features.estimatedKey,
            String(format: "%.2f", features.integratedLUFS),
            String(format: "%.3f", features.spectralCentroidHz),
            bands,
            chroma
        ].joined(separator: "|")
        let digest = SHA256.hash(data: Data(source.utf8))
        return digest.prefix(12).map { String(format: "%02x", $0) }.joined()
    }

    private static func normalize(_ value: Float, lower: Float, upper: Float) -> Float {
        guard value.isFinite, upper > lower else { return 0 }
        return clamp((value - lower) / (upper - lower))
    }

    private static func clamp(_ value: Float) -> Float {
        min(1, max(0, value.isFinite ? value : 0))
    }
}

enum MonoFlowMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case seamless
    case rhythmic
    case energy
    case faithful

    var id: String { rawValue }
}

struct MonoFlowTransitionPlan: Codable, Equatable, Sendable {
    let source: MonoTrackIdentity
    let destination: MonoTrackIdentity
    let mode: MonoFlowMode
    let crossfadeDuration: Float
    let outgoingGainDB: Float
    let incomingGainDB: Float
    let tempoCompatibility: Float
    let keyCompatibility: Float
    let energyCompatibility: Float
    let protectsVocals: Bool
    let generatedAt: Date

    var confidence: Float {
        min(1, max(0, tempoCompatibility * 0.42 + keyCompatibility * 0.28 + energyCompatibility * 0.30))
    }
}

struct MonoLiveMasterFrame: Codable, Equatable, Sendable {
    let section: MonoDNASection.Kind
    let progress: Double
    let intensity: Float
    let bassTrimDB: Float
    let trebleTrimDB: Float
    let stereoWidthMultiplier: Float
    let loudnessTrimDB: Float
}

enum MonoSoundTwinFeedback: String, Codable, Sendable {
    case preferred
    case rejected
    case neutral
}

struct MonoSoundTwinObservation: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let songIdentity: MonoTrackIdentity
    let outputIdentity: String
    let proposalID: UUID
    let feedback: MonoSoundTwinFeedback
    let retainedSeconds: Double
    let recordedAt: Date
}

struct MonoSoundTwinProfile: Codable, Equatable, Sendable {
    var bassPreference: Float = 0
    var treblePreference: Float = 0
    var vocalPreference: Float = 0
    var dynamicsPreference: Float = 0
    var spatialPreference: Float = 0
    var confidence: Float = 0
    var evidenceCount: Int = 0
}

enum MonoSpatialLiveMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case off
    case fixedStage
    case headTracked

    var id: String { rawValue }
}

struct MonoSpatialLiveConfiguration: Codable, Equatable, Sendable {
    var mode: MonoSpatialLiveMode = .off
    var stageWidth: Float = 1
    var stageDepth: Float = 0
    var centerFocus: Float = 0.5
    var ambience: Float = 0
}

enum MonoStemKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case vocals
    case drums
    case bass
    case instruments

    var id: String { rawValue }
}

struct MonoStemAsset: Codable, Equatable, Sendable {
    let kind: MonoStemKind
    let relativePath: String
    let duration: Double
    let sampleRate: Double
    let channelCount: Int
}

struct MonoStemsManifest: Codable, Equatable, Identifiable, Sendable {
    let identity: MonoTrackIdentity
    let sourceFingerprint: String
    let modelRevision: String
    let createdAt: Date
    let assets: [MonoStemAsset]

    var id: String { identity.storageKey }
}

enum MonoSessionRole: String, Codable, Sendable {
    case host
    case listener
}

struct MonoSessionParticipant: Codable, Equatable, Identifiable, Sendable {
    let id: String
    var displayName: String
    var avatarURL: String? = nil
    var role: MonoSessionRole
    var joinedAt: Date
    var isReady: Bool
}

struct MonoSessionChatMessage: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let senderID: String
    let senderName: String
    var senderAvatarURL: String? = nil
    let text: String
    let sentAt: Date
}

struct MonoSessionPlaybackState: Codable, Equatable {
    var sequence: Int64
    var song: Song?
    var position: Double
    var isPlaying: Bool
    var hostTimestamp: Date
    var queueRevision: String
}

struct MonoSessionQueueState: Codable, Equatable {
    var revision: Int64
    var songs: [Song]
    var updatedAt: Date
}

struct MonoSessionPermissions: Codable, Equatable {
    var membersCanControlPlayback: Bool

    static let hostOnly = MonoSessionPermissions(membersCanControlPlayback: false)
}

struct MonoSessionRoom: Codable, Equatable, Identifiable {
    let id: String
    var inviteCode: String
    var hostID: String
    var participants: [MonoSessionParticipant]
    var playback: MonoSessionPlaybackState
    var queue: MonoSessionQueueState?
    var permissions: MonoSessionPermissions?
    var createdAt: Date
}

enum MonoSessionConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case inRoom
    case failed(String)
}

enum MonoSessionCommand: String, Codable {
    case create
    case join
    case resume
    case leave
    case room
    case playback
    case participants
    case chat
    case queue
    case permissions
    case track
    case heartbeat
    case error
}

struct MonoSessionWireMessage: Codable {
    var command: MonoSessionCommand
    var requestID: UUID
    var roomID: String?
    var inviteCode: String?
    var participant: MonoSessionParticipant?
    var participants: [MonoSessionParticipant]?
    var playback: MonoSessionPlaybackState?
    var queue: MonoSessionQueueState?
    var permissions: MonoSessionPermissions?
    var chat: MonoSessionChatMessage?
    var messages: [MonoSessionChatMessage]?
    var room: MonoSessionRoom?
    var sentAt: Date
    var errorCode: String?
    var errorMessage: String?

    init(
        command: MonoSessionCommand,
        requestID: UUID,
        roomID: String? = nil,
        inviteCode: String? = nil,
        participant: MonoSessionParticipant? = nil,
        participants: [MonoSessionParticipant]? = nil,
        playback: MonoSessionPlaybackState? = nil,
        queue: MonoSessionQueueState? = nil,
        permissions: MonoSessionPermissions? = nil,
        chat: MonoSessionChatMessage? = nil,
        messages: [MonoSessionChatMessage]? = nil,
        room: MonoSessionRoom? = nil,
        sentAt: Date,
        errorCode: String? = nil,
        errorMessage: String? = nil
    ) {
        self.command = command
        self.requestID = requestID
        self.roomID = roomID
        self.inviteCode = inviteCode
        self.participant = participant
        self.participants = participants
        self.playback = playback
        self.queue = queue
        self.permissions = permissions
        self.chat = chat
        self.messages = messages
        self.room = room
        self.sentAt = sentAt
        self.errorCode = errorCode
        self.errorMessage = errorMessage
    }
}

enum MonoRecoveryEventKind: String, Codable, Sendable {
    case request
    case resolving
    case buffering
    case playing
    case paused
    case seeking
    case transition
    case routeChange
    case interruption
    case failure
    case recovered
}

struct MonoRecoveryEvent: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let timestamp: Date
    let kind: MonoRecoveryEventKind
    let songIdentity: MonoTrackIdentity?
    let position: Double
    let duration: Double
    let engineState: String
    let isLoading: Bool
    let route: String
    let sessionID: Int
    let detail: String
}

enum MonoRecoveryAction: String, Codable, Sendable {
    case none
    case clearLoadingState
    case reactivateAudioSession
    case rebuildCurrentPipeline
    case reloadCurrentTrack
}

struct MonoRecoverySnapshot: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let updatedAt: Date
    let events: [MonoRecoveryEvent]
    let lastAction: MonoRecoveryAction
    let consecutiveFailures: Int
}
