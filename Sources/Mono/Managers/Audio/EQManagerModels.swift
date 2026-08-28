import Foundation
import Combine
import AVFoundation
import FFmpegSwiftSDK

enum MonoAudioOutputKind: String, Codable, CaseIterable, Identifiable {
    case builtInSpeaker
    case wired
    case bluetooth
    case car
    case airPlay
    case usb
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .builtInSpeaker: return String(localized: "eq_output_speaker")
        case .wired: return String(localized: "eq_output_wired")
        case .bluetooth: return String(localized: "eq_output_bluetooth")
        case .car: return String(localized: "eq_output_car")
        case .airPlay: return "AirPlay"
        case .usb: return String(localized: "eq_output_usb")
        case .other: return String(localized: "eq_output_other")
        }
    }

    var defaultCalibration: [Float] {
        switch self {
        case .builtInSpeaker:
            return [-2.8, -1.8, 0.4, 0.8, 0.35, 0, 0.25, 0.2, -0.3, -0.8]
        case .car:
            return [-0.4, 0.25, 0.55, 0.2, -0.45, -0.2, 0.25, 0.3, 0, -0.35]
        case .bluetooth:
            return [-0.2, 0.1, 0.15, 0, -0.1, 0, 0.1, 0.1, 0, -0.15]
        case .wired, .airPlay, .usb, .other:
            return Array(repeating: 0, count: 10)
        }
    }
}

struct EQGraphicGainUserAdjustment {
    let graphicEQMode: GraphicEQMode
    let previousGains: [Float]
    let adjustedGains: [Float]
    let changedAt: Date
}

struct MonoHeadphoneCorrectionProfile: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var matchedDeviceName: String
    var matchedDeviceUID: String
    var gains: [Float]
    var isCustom: Bool
    var sourceName: String?
    var sourceURL: String?
    var author: String?
    var details: String?
    var preampDB: Float?
    var acousticFilters: [MonoAcousticFilter]?

    init(
        id: String,
        name: String,
        matchedDeviceName: String = "",
        matchedDeviceUID: String = "",
        gains: [Float],
        isCustom: Bool = false,
        sourceName: String? = nil,
        sourceURL: String? = nil,
        author: String? = nil,
        details: String? = nil,
        preampDB: Float? = nil,
        acousticFilters: [MonoAcousticFilter]? = nil
    ) {
        self.id = id
        self.name = name
        self.matchedDeviceName = matchedDeviceName
        self.matchedDeviceUID = matchedDeviceUID
        let targetCount = gains.count >= GraphicEQMode.thirtyTwoBand.bandCount
            ? GraphicEQMode.thirtyTwoBand.bandCount
            : GraphicEQMode.tenBand.bandCount
        self.gains = Array(gains.prefix(targetCount))
            + Array(repeating: 0, count: max(0, targetCount - gains.count))
        self.isCustom = isCustom
        self.sourceName = sourceName
        self.sourceURL = sourceURL
        self.author = author
        self.details = details
        self.preampDB = preampDB.map { min(0, max(-18, $0)) }
        self.acousticFilters = acousticFilters
    }
}
