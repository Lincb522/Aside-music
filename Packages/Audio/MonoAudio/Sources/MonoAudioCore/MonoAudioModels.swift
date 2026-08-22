import Foundation

public enum MonoAudioSchema {
    public static let currentVersion = 1
}

public enum GraphicEQMode: String, Codable, CaseIterable, Sendable {
    case tenBand
    case thirtyTwoBand

    public var centerFrequenciesHz: [Double] {
        switch self {
        case .tenBand:
            [31, 62, 125, 250, 500, 1_000, 2_000, 4_000, 8_000, 16_000]
        case .thirtyTwoBand:
            [
                16, 20, 25, 31.5, 40, 50, 63, 80,
                100, 125, 160, 200, 250, 315, 400, 500,
                630, 800, 1_000, 1_250, 1_600, 2_000, 2_500, 3_150,
                4_000, 5_000, 6_300, 8_000, 10_000, 12_500, 16_000, 20_000,
            ]
        }
    }

    public var qValues: [Double] {
        switch self {
        case .tenBand:
            [0.95, 1.15, 1.30, 1.35, 1.40, 1.40, 1.40, 1.35, 1.20, 0.95]
        case .thirtyTwoBand:
            Array(repeating: 4.318, count: 32)
        }
    }

    public var maximumAdjacentJumpDB: Double {
        switch self {
        case .tenBand: 4.5
        case .thirtyTwoBand: 3.0
        }
    }
}

public struct GraphicEQCurve: Codable, Equatable, Sendable {
    public var mode: GraphicEQMode
    public var gainsDB: [Double]

    public init(mode: GraphicEQMode, gainsDB: [Double]) {
        self.mode = mode
        self.gainsDB = gainsDB
    }

    public static func flat(_ mode: GraphicEQMode = .tenBand) -> Self {
        .init(mode: mode, gainsDB: Array(repeating: 0, count: mode.centerFrequenciesHz.count))
    }
}

public enum ParametricFilterKind: String, Codable, CaseIterable, Sendable {
    case peak
    case lowShelf
    case highShelf
}

public struct ParametricEQBand: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var isEnabled: Bool
    public var kind: ParametricFilterKind
    public var frequencyHz: Double
    public var gainDB: Double
    public var q: Double

    public init(
        id: UUID = UUID(),
        isEnabled: Bool = true,
        kind: ParametricFilterKind = .peak,
        frequencyHz: Double,
        gainDB: Double,
        q: Double
    ) {
        self.id = id
        self.isEnabled = isEnabled
        self.kind = kind
        self.frequencyHz = frequencyHz
        self.gainDB = gainDB
        self.q = q
    }
}

public struct CompressorConfiguration: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var thresholdDB: Double
    public var ratio: Double
    public var attackMS: Double
    public var releaseMS: Double
    public var makeupDB: Double

    public init(
        isEnabled: Bool = false,
        thresholdDB: Double = -18,
        ratio: Double = 1.5,
        attackMS: Double = 20,
        releaseMS: Double = 180,
        makeupDB: Double = 0
    ) {
        self.isEnabled = isEnabled
        self.thresholdDB = thresholdDB
        self.ratio = ratio
        self.attackMS = attackMS
        self.releaseMS = releaseMS
        self.makeupDB = makeupDB
    }
}

public struct SpatialConfiguration: Codable, Equatable, Sendable {
    public var stereoWidth: Double

    public init(stereoWidth: Double = 1) {
        self.stereoWidth = stereoWidth
    }
}

public struct OutputSafetyConfiguration: Codable, Equatable, Sendable {
    public var preampDB: Double
    public var limiterEnabled: Bool
    public var limiterCeilingDBFS: Double
    public var uncertaintyMarginDB: Double

    public init(
        preampDB: Double = -0.5,
        limiterEnabled: Bool = true,
        limiterCeilingDBFS: Double = -1,
        uncertaintyMarginDB: Double = 0.5
    ) {
        self.preampDB = preampDB
        self.limiterEnabled = limiterEnabled
        self.limiterCeilingDBFS = limiterCeilingDBFS
        self.uncertaintyMarginDB = uncertaintyMarginDB
    }
}

/// Portable, versioned tuning contract. Device correction is deliberately
/// separate from track correction so an Agent cannot reproduce an OPRA curve.
public struct MonoAudioPlan: Codable, Equatable, Identifiable, Sendable {
    public var schemaVersion: Int
    public var id: UUID
    public var name: String
    public var deviceBaseline: GraphicEQCurve?
    public var graphicEQ: GraphicEQCurve
    public var parametricEQ: [ParametricEQBand]
    public var compressor: CompressorConfiguration
    public var spatial: SpatialConfiguration
    public var outputSafety: OutputSafetyConfiguration

    public init(
        schemaVersion: Int = MonoAudioSchema.currentVersion,
        id: UUID = UUID(),
        name: String,
        deviceBaseline: GraphicEQCurve? = nil,
        graphicEQ: GraphicEQCurve = .flat(),
        parametricEQ: [ParametricEQBand] = [],
        compressor: CompressorConfiguration = .init(),
        spatial: SpatialConfiguration = .init(),
        outputSafety: OutputSafetyConfiguration = .init()
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.name = name
        self.deviceBaseline = deviceBaseline
        self.graphicEQ = graphicEQ
        self.parametricEQ = parametricEQ
        self.compressor = compressor
        self.spatial = spatial
        self.outputSafety = outputSafety
    }
}

public struct AudioFeatureSnapshot: Codable, Equatable, Sendable {
    public var integratedLUFS: Double?
    public var truePeakDBTP: Double?
    public var crestFactorDB: Double?
    public var phaseCorrelation: Double?
    public var confidence: Double

    public init(
        integratedLUFS: Double? = nil,
        truePeakDBTP: Double? = nil,
        crestFactorDB: Double? = nil,
        phaseCorrelation: Double? = nil,
        confidence: Double
    ) {
        self.integratedLUFS = integratedLUFS
        self.truePeakDBTP = truePeakDBTP
        self.crestFactorDB = crestFactorDB
        self.phaseCorrelation = phaseCorrelation
        self.confidence = confidence
    }
}
