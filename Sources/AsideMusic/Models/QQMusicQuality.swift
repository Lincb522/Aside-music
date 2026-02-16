import Foundation
import QQMusicKit

/// QQ 音乐独立音质体系
/// 包装 QQMusicKit 的 SongFileType，提供 UI 显示信息
enum QQMusicQuality: String, CaseIterable, Codable {
    case aac48 = "aac_48"          // AAC 48kbps
    case aac96 = "aac_96"          // AAC 96kbps
    case aac192 = "aac_192"        // AAC 192kbps
    case mp3_128 = "mp3_128"       // MP3 128kbps
    case mp3_320 = "mp3_320"       // MP3 320kbps
    case ogg96 = "ogg_96"          // OGG 96kbps
    case ogg192 = "ogg_192"        // OGG 192kbps
    case ogg320 = "ogg_320"        // OGG 320kbps
    case ogg640 = "ogg_640"        // OGG 640kbps
    case flac = "flac"             // FLAC 无损
    case atmos51 = "atmos_51"      // 臻品音质
    case atmos2 = "atmos_2"        // 臻品全景声
    case master = "master"         // 臻品母带
    
    /// 对应的 QQMusicKit SongFileType
    var fileType: SongFileType {
        switch self {
        case .aac48:   return .aac48
        case .aac96:   return .aac96
        case .aac192:  return .aac192
        case .mp3_128: return .mp3_128
        case .mp3_320: return .mp3_320
        case .ogg96:   return .ogg96
        case .ogg192:  return .ogg192
        case .ogg320:  return .ogg320
        case .ogg640:  return .ogg640
        case .flac:    return .flac
        case .atmos51: return .atmos51
        case .atmos2:  return .atmos2
        case .master:  return .master
        }
    }
    
    var displayName: String {
        switch self {
        case .aac48:   return "AAC 流畅"
        case .aac96:   return "AAC 标准"
        case .aac192:  return "AAC 高品"
        case .mp3_128: return "MP3 标准"
        case .mp3_320: return "MP3 高品"
        case .ogg96:   return "OGG 标准"
        case .ogg192:  return "OGG 高品"
        case .ogg320:  return "OGG 超品"
        case .ogg640:  return "OGG 臻品"
        case .flac:    return "FLAC 无损"
        case .atmos51: return "臻品音质"
        case .atmos2:  return "臻品全景声"
        case .master:  return "臻品母带"
        }
    }
    
    var subtitle: String {
        switch self {
        case .aac48:   return "48kbps"
        case .aac96:   return "96kbps"
        case .aac192:  return "192kbps"
        case .mp3_128: return "128kbps"
        case .mp3_320: return "320kbps"
        case .ogg96:   return "96kbps"
        case .ogg192:  return "192kbps"
        case .ogg320:  return "320kbps"
        case .ogg640:  return "640kbps"
        case .flac:    return "16Bit~24Bit 无损"
        case .atmos51: return "16Bit 44.1kHz"
        case .atmos2:  return "16Bit 44.1kHz 全景声"
        case .master:  return "24Bit 192kHz"
        }
    }
    
    var badgeText: String? {
        switch self {
        case .aac48, .aac96, .mp3_128, .ogg96:
            return nil
        case .aac192, .ogg192:
            return "HQ"
        case .mp3_320, .ogg320:
            return "HQ"
        case .ogg640:
            return "SQ"
        case .flac:
            return "SQ"
        case .atmos51:
            return "臻品"
        case .atmos2:
            return "全景声"
        case .master:
            return "母带"
        }
    }
}
