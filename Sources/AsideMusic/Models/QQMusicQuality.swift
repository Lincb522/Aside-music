import Foundation
import QQMusicKit

/// QQ 音乐独立音质体系
/// 包装 QQMusicKit 的 SongFileType，提供 UI 显示信息
enum QQMusicQuality: String, CaseIterable, Codable {
    case master = "MASTER"         // 臻品母带 24Bit 192kHz
    case atmos2 = "ATMOS_2"        // 臻品全景声 16Bit 44.1kHz
    case atmos51 = "ATMOS_51"      // 臻品音质 16Bit 44.1kHz
    case flac = "FLAC"             // FLAC 无损 16Bit~24Bit
    case ogg640 = "OGG_640"        // OGG 640kbps
    case ogg320 = "OGG_320"        // OGG 320kbps
    case ogg192 = "OGG_192"        // OGG 192kbps
    case ogg96 = "OGG_96"          // OGG 96kbps
    case mp3_320 = "MP3_320"       // MP3 320kbps
    case mp3_128 = "MP3_128"       // MP3 128kbps
    case aac192 = "ACC_192"        // AAC 192kbps
    case aac96 = "ACC_96"          // AAC 96kbps
    case aac48 = "ACC_48"          // AAC 48kbps
    
    /// 对应的 QQMusicKit SongFileType
    var fileType: SongFileType {
        switch self {
        case .master:  return .master
        case .atmos2:  return .atmos2
        case .atmos51: return .atmos51
        case .flac:    return .flac
        case .ogg640:  return .ogg640
        case .ogg320:  return .ogg320
        case .ogg192:  return .ogg192
        case .ogg96:   return .ogg96
        case .mp3_320: return .mp3_320
        case .mp3_128: return .mp3_128
        case .aac192:  return .aac192
        case .aac96:   return .aac96
        case .aac48:   return .aac48
        }
    }
    
    var displayName: String {
        switch self {
        case .master:  return "臻品母带"
        case .atmos2:  return "臻品全景声"
        case .atmos51: return "臻品音质"
        case .flac:    return "FLAC 无损"
        case .ogg640:  return "OGG 臻品"
        case .ogg320:  return "OGG 超品"
        case .ogg192:  return "OGG 高品"
        case .ogg96:   return "OGG 标准"
        case .mp3_320: return "MP3 高品"
        case .mp3_128: return "MP3 标准"
        case .aac192:  return "AAC 高品"
        case .aac96:   return "AAC 标准"
        case .aac48:   return "AAC 流畅"
        }
    }
    
    var subtitle: String {
        switch self {
        case .master:  return "24Bit 192kHz"
        case .atmos2:  return "16Bit 44.1kHz 全景声"
        case .atmos51: return "16Bit 44.1kHz"
        case .flac:    return "16Bit~24Bit 无损"
        case .ogg640:  return "640kbps"
        case .ogg320:  return "320kbps"
        case .ogg192:  return "192kbps"
        case .ogg96:   return "96kbps"
        case .mp3_320: return "320kbps"
        case .mp3_128: return "128kbps"
        case .aac192:  return "192kbps"
        case .aac96:   return "96kbps"
        case .aac48:   return "48kbps"
        }
    }
    
    var badgeText: String? {
        switch self {
        case .master:
            return "母带"
        case .atmos2:
            return "全景声"
        case .atmos51:
            return "臻品"
        case .flac, .ogg640:
            return "SQ"
        case .ogg320, .mp3_320, .aac192:
            return "HQ"
        case .ogg192, .ogg96, .mp3_128, .aac96, .aac48:
            return nil
        }
    }
    
    /// 音质等级（用于排序和比较）
    var level: Int {
        switch self {
        case .master:  return 13
        case .atmos2:  return 12
        case .atmos51: return 11
        case .flac:    return 10
        case .ogg640:  return 9
        case .ogg320:  return 8
        case .mp3_320: return 7
        case .ogg192:  return 6
        case .aac192:  return 5
        case .mp3_128: return 4
        case .ogg96:   return 3
        case .aac96:   return 2
        case .aac48:   return 1
        }
    }
    
    /// 常用音质选项（供快速选择使用）
    static var commonOptions: [QQMusicQuality] {
        [.master, .flac, .ogg320, .mp3_320, .mp3_128, .aac96]
    }
}
