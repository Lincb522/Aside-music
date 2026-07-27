import Foundation

enum SoundQuality: String, CaseIterable, Codable, Sendable {
    case standard = "standard" // 标准
    case higher = "higher"     // 较高
    case exhigh = "exhigh"     // 极高
    case lossless = "lossless" // 无损
    case hires = "hires"       // Hi-Res
    case jyeffect = "jyeffect" // 高清臻音
    case sky = "sky"           // 沉浸环绕声
    case jymaster = "jymaster" // 超清母带
    case multitrack = "multitrack" // 多音轨
    case none = "none"
    
    var displayName: String {
        switch self {
        case .standard: return String(localized: "quality_standard")
        case .higher: return String(localized: "高音质")
        case .exhigh: return String(localized: "极高音质 (HQ)")
        case .lossless: return String(localized: "无损音质 (SQ)")
        case .hires: return String(localized: "Hi-Res 音质")
        case .jyeffect: return String(localized: "高清臻音")
        case .sky: return String(localized: "沉浸环绕声")
        case .jymaster: return String(localized: "超清母带")
        case .multitrack: return String(localized: "quality_kcm_multitrack")
        case .none: return String(localized: "未知")
        }
    }
    
    var buttonText: String {
        switch self {
        case .standard: return "Standard"
        case .higher: return "Higher"
        case .exhigh: return "HQ"
        case .lossless: return "SQ"
        case .hires: return "Hi-Res"
        case .jyeffect: return "Spatial"
        case .sky: return "Surround"
        case .jymaster: return "Master"
        case .multitrack: return "Multi"
        case .none: return ""
        }
    }
    
    var subtitle: String {
        switch self {
        case .standard: return "128kbps"
        case .higher: return "192kbps"
        case .exhigh: return String(localized: "最高320kbps")
        case .lossless: return String(localized: "最高48kHz/16bit")
        case .hires: return String(localized: "最高192kHz/24bit")
        case .jyeffect: return String(localized: "清晰沉浸感")
        case .sky: return String(localized: "最高5.1声道")
        case .jymaster: return String(localized: "极致细节")
        case .multitrack: return String(localized: "quality_kcm_multitrack_subtitle")
        case .none: return ""
        }
    }
    
    var isVIP: Bool {
        return self != .standard && self != .higher && self != .exhigh && self != .none
    }

    var badgeText: String? {
        switch self {
        case .standard: return "Standard"
        case .higher: return "Higher"
        case .none: return nil
        case .exhigh: return "HQ"
        case .lossless: return "SQ"
        case .hires: return "Hi-Res"
        case .jyeffect: return String(localized: "高清臻音")
        case .sky: return String(localized: "沉浸环绕声")
        case .jymaster: return String(localized: "超清母带")
        case .multitrack: return "Multi"
        }
    }
    
    var isBadgeChinese: Bool {
        switch self {
        case .jyeffect, .sky, .jymaster: return true
        default: return false
        }
    }

    static let descendingPreferenceOrder: [SoundQuality] = [
        .jymaster, .sky, .jyeffect, .hires, .lossless, .exhigh, .higher, .standard
    ]
    
    static func fallbackCandidates(from preferred: SoundQuality?) -> [SoundQuality] {
        let order = descendingPreferenceOrder
        
        guard let preferred else {
            return order
        }

        if preferred == .multitrack {
            return [.multitrack] + order
        }
        
        guard let startIndex = order.firstIndex(of: preferred) else {
            return order
        }
        
        return Array(order[startIndex...])
    }
    
    static func nextLower(than quality: SoundQuality) -> SoundQuality? {
        let candidates = fallbackCandidates(from: quality)
        guard candidates.count > 1 else { return nil }
        return candidates[1]
    }

    static func highest(from qualities: [SoundQuality]) -> SoundQuality? {
        let available = Set(qualities.filter { $0 != .none })
        return descendingPreferenceOrder.first(where: available.contains)
    }
}

/// ncm歌曲可用音质信息
struct NeteaseSongQualityInfo: Identifiable, Sendable {
    let quality: SoundQuality
    let name: String
    let bitrate: Int
    let size: Int
    
    var id: String { quality.rawValue }
    
    var sizeText: String {
        if size >= 1_048_576 {
            return String(format: "%.1f MB", Double(size) / 1_048_576)
        } else if size >= 1024 {
            return String(format: "%.0f KB", Double(size) / 1024)
        } else if size > 0 {
            return "\(size) B"
        }
        return ""
    }
}
