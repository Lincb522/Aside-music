import Foundation

enum SoundQuality: String, CaseIterable, Codable {
    case standard = "standard" // 标准
    case higher = "higher"     // 较高
    case exhigh = "exhigh"     // 极高
    case lossless = "lossless" // 无损
    case hires = "hires"       // Hi-Res
    case jyeffect = "jyeffect" // 高清臻音
    case sky = "sky"           // 沉浸环绕声
    case jymaster = "jymaster" // 超清母带
    case none = "none"
    
    var displayName: String {
        switch self {
        case .standard: return "标准音质"
        case .higher: return "较高音质"
        case .exhigh: return "极高音质 (HQ)"
        case .lossless: return "无损音质 (SQ)"
        case .hires: return "Hi-Res 音质"
        case .jyeffect: return "高清臻音"
        case .sky: return "沉浸环绕声"
        case .jymaster: return "超清母带"
        case .none: return "未知"
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
        case .none: return ""
        }
    }
    
    var subtitle: String {
        switch self {
        case .standard: return "128kbps"
        case .higher: return "192kbps"
        case .exhigh: return "最高320kbps"
        case .lossless: return "最高48kHz/16bit"
        case .hires: return "最高192kHz/24bit"
        case .jyeffect: return "清晰沉浸感"
        case .sky: return "最高5.1声道"
        case .jymaster: return "极致细节"
        case .none: return ""
        }
    }
    
    var isVIP: Bool {
        return self != .standard && self != .higher && self != .exhigh && self != .none
    }
    
    var badgeText: String? {
        switch self {
        case .standard, .higher, .none: return nil
        case .exhigh: return "HQ"
        case .lossless: return "SQ"
        case .hires: return "Hi-Res"
        case .jyeffect: return "高清臻音"
        case .sky: return "沉浸环绕声"
        case .jymaster: return "超清母带"
        }
    }
    
    var isBadgeChinese: Bool {
        switch self {
        case .jyeffect, .sky, .jymaster: return true
        default: return false
        }
    }
}
