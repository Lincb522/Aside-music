import Foundation
import FFmpegSwiftSDK

/// 本地歌单在云同步协议中的完整快照。
struct LocalPlaylistCloudPlaylist: Codable, Hashable {
    var id: String
    var name: String
    var desc: String?
    var coverUrl: String?
    var createdAt: Date
    var updatedAt: Date
    var isSystem: Bool
    var songs: [Song]
}

// MARK: - 下载记录云端模型（仅元数据，不含音频文件）

struct CloudDownloadRecord: Codable, Hashable {
    var songId: Int
    var name: String
    var artistName: String
    var albumName: String?
    var coverUrl: String?
    var duration: Int?
    var source: String?        // MusicSource.rawValue
    var qqMid: String?
    var qishuiTrackId: Int?
    var qishuiQualityRaw: String?
    var qualityRaw: String?
    var qqQualityRaw: String?
    var downloadedAt: Date?

    /// 从 DownloadedSong 创建（仅保存元数据）
    init(from downloaded: DownloadedSong) {
        self.songId = downloaded.id
        self.name = downloaded.name
        self.artistName = downloaded.artistName
        self.albumName = downloaded.albumName
        self.coverUrl = downloaded.coverUrl
        self.duration = downloaded.duration
        self.qqMid = downloaded.qqMid
        self.qishuiTrackId = downloaded.qishuiTrackId
        self.qishuiQualityRaw = downloaded.qishuiQualityRaw
        self.qualityRaw = downloaded.qualityRaw
        self.qqQualityRaw = downloaded.qqQualityRaw
        self.downloadedAt = downloaded.downloadedAt

        if downloaded.isQishui {
            self.source = MusicSource.qishui.rawValue
        } else if downloaded.isQQMusic {
            self.source = MusicSource.qqmusic.rawValue
        } else {
            self.source = MusicSource.netease.rawValue
        }
    }

    /// 转换为 Song（用于下载歌单恢复显示）
    func toSong() -> Song {
        var song = Song(
            id: songId,
            name: name,
            ar: [Artist(id: 0, name: artistName)],
            al: Album(id: 0, name: albumName ?? "", picUrl: coverUrl),
            dt: duration,
            fee: nil,
            mv: nil,
            h: nil, m: nil, l: nil, sq: nil, hr: nil,
            alia: nil,
            privilege: nil
        )
        song.source = MusicSource(rawValue: source ?? "") ?? song.musicSource
        song.qqMid = qqMid
        song.qishuiTrackId = qishuiTrackId
        return song
    }
}

// MARK: - 播放记录与听歌统计

struct CloudPlayHistoryRecord: Codable, Equatable {
    var id: UUID
    var songId: Int
    var songName: String
    var artistName: String
    var coverUrl: String?
    var playedAt: Date
    var playDuration: Int
    var completed: Bool
    var trackDuration: Int?
    var effectivePlay: Bool?
    var qualificationVersion: Int?
    var sourceRaw: String?
    var qqMid: String?
    var qqAlbumMid: String?
    var qishuiTrackId: Int?
    var appleMusicID: String?
    var appleMusicISRC: String?

    init(from record: PlayHistory) {
        id = record.id
        songId = record.songId
        songName = record.songName
        artistName = record.artistName
        coverUrl = record.coverUrl
        playedAt = record.playedAt
        playDuration = record.playDuration
        completed = record.completed
        trackDuration = record.trackDuration
        effectivePlay = record.effectivePlay
        qualificationVersion = record.qualificationVersion
        sourceRaw = record.sourceRaw
        qqMid = record.qqMid
        qqAlbumMid = record.qqAlbumMid
        qishuiTrackId = record.qishuiTrackId
        appleMusicID = record.appleMusicID
        appleMusicISRC = record.appleMusicISRC
    }

    func makeLocalRecord() -> PlayHistory {
        let record = PlayHistory(
            songId: songId,
            songName: songName,
            artistName: artistName,
            coverUrl: coverUrl,
            playDuration: max(0, playDuration),
            completed: completed,
            trackDuration: max(0, trackDuration ?? 0),
            effectivePlay: effectivePlay ?? false,
            qualificationVersion: qualificationVersion ?? 0,
            sourceRaw: sourceRaw,
            qqMid: qqMid,
            qqAlbumMid: qqAlbumMid,
            qishuiTrackId: qishuiTrackId,
            appleMusicID: appleMusicID,
            appleMusicISRC: appleMusicISRC
        )
        record.id = id
        record.playedAt = playedAt
        return record
    }
}

struct CloudPlaybackHistorySnapshot: Codable {
    var records: [CloudPlayHistoryRecord]
    var recentClearedAt: Date?
}

// MARK: - 个性化与音效

struct CloudThemeCustomizationEntry: Codable {
    var theme: GlobalThemeId
    var currentLight: ThemeColorPreset?
    var savedLight: [ThemeColorPreset]
    var currentDark: ThemeColorPreset?
    var savedDark: [ThemeColorPreset]
}

struct CloudThemeCustomizationSnapshot: Codable {
    var entries: [CloudThemeCustomizationEntry]
}

struct CloudAIEqualizerSongMetadata: Codable, Hashable {
    var songIdentifier: String
    var songId: Int
    var songName: String
    var artistName: String
    var albumName: String?
    var coverUrl: String?
    var sourceRaw: String

    init(song: Song) {
        let source = song.musicSource
        songIdentifier = "\(source.rawValue):\(song.id)"
        songId = song.id
        songName = song.name
        artistName = song.artistName
        albumName = song.al?.name
        coverUrl = song.coverUrl?.absoluteString
        sourceRaw = source.rawValue
    }
}

/// A privacy-reduced, structured copy of the measured signal and current DSP
/// state. It intentionally excludes song titles, artist names, raw audio and
/// route display names while retaining measured tuning features plus bounded,
/// audio-derived genre and instrument hints used for style conditioning.
struct CloudAIEqualizerTrainingFeatures: Codable, Equatable, Sendable {
    var source: String
    var outputKind: String
    var sampleDuration: Double
    var sampleRate: Double
    var frameCount: Int
    var graphicEQMode: GraphicEQMode
    var bandFrequenciesHz: [Float]
    var bandEnergyDB: [Float]
    var bandEnergySpreadDB: [Float]?
    var sectionBandEnergyDB: [[Float]]?
    var spectralCentroidHz: Float
    var spectralRolloffHz: Float
    var spectralCentroidP10Hz: Float?
    var spectralCentroidP90Hz: Float?
    var spectralRolloffP10Hz: Float?
    var spectralRolloffP90Hz: Float?
    var rmsDBFS: Float
    var dynamicSpreadDB: Float
    var integratedLUFS: Float
    var shortTermLUFS: Float
    var momentaryLUFS: Float
    var loudnessRangeLU: Float
    var samplePeakDBFS: Float
    var estimatedTruePeakDBTP: Float
    var crestFactorDB: Float
    var dynamicRangeDR: Float
    var clippingRatio: Float
    var phaseCorrelation: Float
    var monoCompatibility: Float
    var measuredStereoWidth: Float
    var spectralFlatness: Float
    var spectralBandwidthHz: Float
    var spectralFlux: Float
    var spectralFluxP90: Float?
    var lowEnergyRatio: Float
    var midEnergyRatio: Float
    var highEnergyRatio: Float
    var estimatedBPM: Float
    var tempoConfidence: Float
    var tempoStability: Float
    var estimatedKey: String
    var keyConfidence: Float
    var dominantPitchHz: Float
    var melodyRangeSemitones: Float
    var melodicActivity: Float
    var melodyContourHz: [Float]
    var transientDensity: Float
    var chroma: [Float]
    var genreHints: [String]
    var instrumentHints: [String]
    var genreScores: [String: Float]?
    var instrumentScores: [String: Float]?
    var rmsP10DBFS: Float?
    var rmsP50DBFS: Float?
    var rmsP90DBFS: Float?
    var vocalReference: AIEqualizerVocalReferenceFeatures?
    var currentBassGain: Float
    var currentTrebleGain: Float
    var currentSurroundLevel: Float
    var currentReverbLevel: Float
    var currentStereoWidth: Float
    var professionalProcessingIntensity: Float
    var outputCalibrationEnabled: Bool
    var loudnessMatchingEnabled: Bool
    var smartSongCompensationEnabled: Bool
    var dynamicEQEnabled: Bool
    var multibandDynamicsEnabled: Bool
    var parametricEQEnabled: Bool

    init(features: AIEqualizerAudioFeatures) {
        source = features.source
        outputKind = features.outputKind
        sampleDuration = features.sampleDuration
        sampleRate = features.sampleRate
        frameCount = features.frameCount
        graphicEQMode = features.graphicEQMode
        bandFrequenciesHz = features.bandFrequenciesHz
        bandEnergyDB = features.bandEnergyDB
        bandEnergySpreadDB = features.bandEnergySpreadDB
        sectionBandEnergyDB = features.sectionBandEnergyDB
        spectralCentroidHz = features.spectralCentroidHz
        spectralRolloffHz = features.spectralRolloffHz
        spectralCentroidP10Hz = features.spectralCentroidP10Hz
        spectralCentroidP90Hz = features.spectralCentroidP90Hz
        spectralRolloffP10Hz = features.spectralRolloffP10Hz
        spectralRolloffP90Hz = features.spectralRolloffP90Hz
        rmsDBFS = features.rmsDBFS
        dynamicSpreadDB = features.dynamicSpreadDB
        integratedLUFS = features.integratedLUFS
        shortTermLUFS = features.shortTermLUFS
        momentaryLUFS = features.momentaryLUFS
        loudnessRangeLU = features.loudnessRangeLU
        samplePeakDBFS = features.samplePeakDBFS
        estimatedTruePeakDBTP = features.estimatedTruePeakDBTP
        crestFactorDB = features.crestFactorDB
        dynamicRangeDR = features.dynamicRangeDR
        clippingRatio = features.clippingRatio
        phaseCorrelation = features.phaseCorrelation
        monoCompatibility = features.monoCompatibility
        measuredStereoWidth = features.measuredStereoWidth
        spectralFlatness = features.spectralFlatness
        spectralBandwidthHz = features.spectralBandwidthHz
        spectralFlux = features.spectralFlux
        spectralFluxP90 = features.spectralFluxP90
        lowEnergyRatio = features.lowEnergyRatio
        midEnergyRatio = features.midEnergyRatio
        highEnergyRatio = features.highEnergyRatio
        estimatedBPM = features.estimatedBPM
        tempoConfidence = features.tempoConfidence
        tempoStability = features.tempoStability
        estimatedKey = features.estimatedKey
        keyConfidence = features.keyConfidence
        dominantPitchHz = features.dominantPitchHz
        melodyRangeSemitones = features.melodyRangeSemitones
        melodicActivity = features.melodicActivity
        melodyContourHz = features.melodyContourHz
        transientDensity = features.transientDensity
        chroma = features.chroma
        genreHints = features.genreHints
        instrumentHints = features.instrumentHints
        genreScores = features.genreScores
        instrumentScores = features.instrumentScores
        rmsP10DBFS = features.rmsP10DBFS
        rmsP50DBFS = features.rmsP50DBFS
        rmsP90DBFS = features.rmsP90DBFS
        vocalReference = features.vocalReference
        currentBassGain = features.currentBassGain
        currentTrebleGain = features.currentTrebleGain
        currentSurroundLevel = features.currentSurroundLevel
        currentReverbLevel = features.currentReverbLevel
        currentStereoWidth = features.currentStereoWidth
        professionalProcessingIntensity = features.professionalProcessingIntensity
        outputCalibrationEnabled = features.outputCalibrationEnabled
        loudnessMatchingEnabled = features.loudnessMatchingEnabled
        smartSongCompensationEnabled = features.smartSongCompensationEnabled
        dynamicEQEnabled = features.dynamicEQEnabled
        multibandDynamicsEnabled = features.multibandDynamicsEnabled
        parametricEQEnabled = features.parametricEQEnabled
    }
}

struct CloudAIEqualizerDeviceTrainingContext: Codable, Equatable, Sendable {
    var identifier: String
    var referenceGainsDB: [Float]
    var spatialGuidance: String
    var detailSchemaVersion: Int? = nil
    var outputKind: String? = nil
    var profileSource: String? = nil
    var calibrationEnabled: Bool? = nil
    var profileActive: Bool? = nil
    var profileIsCustom: Bool? = nil
    var outputSampleRate: Double? = nil
    var outputChannelCount: Int? = nil
    var outputLatencyMS: Double? = nil
    var ioBufferDurationMS: Double? = nil
    var routeDefaultGainsDB: [Float]? = nil
    var profileGainsDB: [Float]? = nil
    var effectiveGainsDB: [Float]? = nil
    var profilePreampDB: Float? = nil
    var acousticFilters: [AIEqualizerDeviceAcousticFilterContext]? = nil
    var fitDescription: String? = nil

    init(target: AIEqualizerDeviceTuningTarget) {
        identifier = target.identifier
        referenceGainsDB = target.referenceGainsDB
        spatialGuidance = target.spatialGuidance
    }

    init(context: AIEqualizerDeviceTrainingContext) {
        identifier = context.identifier
        referenceGainsDB = context.referenceGainsDB
        spatialGuidance = context.spatialGuidance
        detailSchemaVersion = context.detailSchemaVersion
        outputKind = context.outputKind
        profileSource = context.profileSource
        calibrationEnabled = context.calibrationEnabled
        profileActive = context.profileActive
        profileIsCustom = context.profileIsCustom
        outputSampleRate = context.outputSampleRate
        outputChannelCount = context.outputChannelCount
        outputLatencyMS = context.outputLatencyMS
        ioBufferDurationMS = context.ioBufferDurationMS
        routeDefaultGainsDB = context.routeDefaultGainsDB
        profileGainsDB = context.profileGainsDB
        effectiveGainsDB = context.effectiveGainsDB
        profilePreampDB = context.profilePreampDB
        acousticFilters = context.acousticFilters
        fitDescription = context.fitDescription
    }
}

/// One complete supervised example for the style, track, preference, and
/// device-conditioned model. Device baselines remain inputs only; explicit
/// population/personalized targets do not contain local device correction.
struct CloudAIEqualizerTrainingSample: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 4

    var schemaVersion: Int
    var id: UUID
    var songIdentifier: String
    var capturedAt: Date
    var features: CloudAIEqualizerTrainingFeatures
    var deviceContext: CloudAIEqualizerDeviceTrainingContext?
    var target: AIEqualizerProposal
    /// The locally validated population target before private user preference
    /// and output-device correction are applied.
    var populationTarget: AIEqualizerProposal?
    /// A bounded Agent learning policy, containing no raw listening audio.
    var learningContext: AIEqualizerLearningContext?
    /// The locally validated target after Agent learning but before device
    /// correction, so the model can learn personalization without absorbing an
    /// output-device response.
    var personalizedTarget: AIEqualizerProposal?
    var feedback: AIEqualizerLearningFeedback?
    var listenedSeconds: TimeInterval?
    var outcomeUpdatedAt: Date?

    init(
        proposal: AIEqualizerProposal,
        features: AIEqualizerAudioFeatures,
        songIdentifier: String,
        deviceTuningTarget: AIEqualizerDeviceTuningTarget?,
        deviceTrainingContext: AIEqualizerDeviceTrainingContext? = nil,
        populationTarget: AIEqualizerProposal? = nil,
        learningContext: AIEqualizerLearningContext? = nil,
        personalizedTarget: AIEqualizerProposal? = nil
    ) {
        schemaVersion = Self.currentSchemaVersion
        id = proposal.id
        self.songIdentifier = songIdentifier
        capturedAt = proposal.createdAt
        self.features = CloudAIEqualizerTrainingFeatures(features: features)
        deviceContext = deviceTrainingContext.map(CloudAIEqualizerDeviceTrainingContext.init)
            ?? deviceTuningTarget.map(CloudAIEqualizerDeviceTrainingContext.init)
        target = proposal
        self.populationTarget = populationTarget
        self.learningContext = learningContext
        self.personalizedTarget = personalizedTarget
        feedback = nil
        listenedSeconds = nil
        outcomeUpdatedAt = nil
    }
}

struct CloudAIEqualizerSnapshot: Codable {
    var cachedProposals: [String: AIEqualizerProposal]
    var savedProposals: [String: [AIEqualizerSavedProposal]]
    var proposalMetadata: [String: CloudAIEqualizerSongMetadata]? = nil
    /// Protocol v5: complete, structured examples available to cloud training.
    var trainingSamples: [String: CloudAIEqualizerTrainingSample]? = nil
}

// MARK: - 云端快照

struct LocalPlaylistCloudSnapshot: Codable {
    /// 云端协议版本；服务端据此区分旧客户端未上传字段与新版主动清空。
    var version: Int = 5
    var updatedAt: Date
    var deviceId: String
    var deviceName: String
    var playlists: [LocalPlaylistCloudPlaylist]
    /// 下载记录元数据（协议 v2 起）
    var downloads: [CloudDownloadRecord]?
    /// 本地播客订阅（协议 v2 起）
    var localRadioSubscriptions: [RadioStation]?
    /// 个性化配色与用户保存的配色方案（协议 v3 起）
    var themeCustomization: CloudThemeCustomizationSnapshot?
    /// 播放记录是听歌统计的数据源（协议 v3 起）
    var playbackHistory: CloudPlaybackHistorySnapshot?
    /// AI 智能调音缓存与历史方案（协议 v3 起）
    var aiEqualizer: CloudAIEqualizerSnapshot?
    /// 用户自定义均衡器预设（协议 v3 起）
    var customEQPresets: [EQPreset]?
    /// 声音中心 Agent 的本机技能偏好与自定义技能（协议 v4 起）。
    /// 服务端强制技能与工具策略仍由 Agent 配置接口统一下发。
    var audioAgentSkills: MonoAudioAgentSkillCloudSnapshot?
}

struct LocalPlaylistCloudFetchResponse: Codable {
    var ok: Bool
    var tokenName: String?
    var hasSnapshot: Bool
    var version: Int?
    var updatedAt: Date?
    var revision: String?
    var playlists: [LocalPlaylistCloudPlaylist]
    /// 下载记录元数据（协议 v2 起）
    var downloads: [CloudDownloadRecord]?
    /// 本地播客订阅（协议 v2 起）
    var localRadioSubscriptions: [RadioStation]?
    /// 个性化配色与用户保存的配色方案（协议 v3 起）
    var themeCustomization: CloudThemeCustomizationSnapshot?
    /// 播放记录与听歌统计（协议 v3 起）
    var playbackHistory: CloudPlaybackHistorySnapshot?
    /// AI 智能调音方案（协议 v3 起）
    var aiEqualizer: CloudAIEqualizerSnapshot?
    /// 用户自定义均衡器预设（协议 v3 起）
    var customEQPresets: [EQPreset]?
    /// 声音中心 Agent 的本机技能偏好与自定义技能（协议 v4 起）
    var audioAgentSkills: MonoAudioAgentSkillCloudSnapshot?
}

struct LocalPlaylistCloudUploadResponse: Codable {
    var ok: Bool
    var updatedAt: Date
    var revision: String
    var playlistCount: Int
    var songCount: Int
    var aiTuningPlanCount: Int?
    var aiTrainingSampleCount: Int?
}

struct LocalPlaylistCloudDeleteResponse: Codable {
    var ok: Bool
    var updatedAt: Date
}
