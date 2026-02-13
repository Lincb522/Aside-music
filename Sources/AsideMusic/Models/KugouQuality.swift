import Foundation

/// 酷狗音源独立音质体系
/// rawValue 对应服务端 search_with_url 的 quality 参数
/// 常规音质通过 hashField 选择不同品质的 hash，蝰蛇音效额外传 quality 参数给 song_url
enum KugouQuality: String, CaseIterable, Codable {
    // 常规音质（rawValue = 服务端 hashField key）
    case normal = "normal"              // 标准 128kbps → FileHash
    case high = "high"                  // 高品 320kbps → HQFileHash
    case sq = "sq"                      // 无损 FLAC → SQFileHash
    case res = "res"                    // 高解析度 → ResFileHash
    // 蝰蛇音效（rawValue 直接传给 song_url quality 参数）
    case viperAtmos = "viper_atmos"     // 蝰蛇全景声
    case viperTape = "viper_tape"       // 蝰蛇母带
    case viperClear = "viper_clear"     // 蝰蛇纯净
    
    var displayName: String {
        switch self {
        case .normal:      return "标准音质"
        case .high:        return "高品音质"
        case .sq:          return "无损音质"
        case .res:         return "高解析度"
        case .viperAtmos:  return "蝰蛇全景声"
        case .viperTape:   return "蝰蛇母带"
        case .viperClear:  return "蝰蛇纯净"
        }
    }
    
    var subtitle: String {
        switch self {
        case .normal:      return "128kbps"
        case .high:        return "320kbps"
        case .sq:          return "FLAC 无损"
        case .res:         return "高解析度音频"
        case .viperAtmos:  return "全景声效果"
        case .viperTape:   return "母带级音质"
        case .viperClear:  return "纯净人声"
        }
    }
    
    var badgeText: String? {
        switch self {
        case .normal:      return nil
        case .high:        return "HQ"
        case .sq:          return "SQ"
        case .res:         return "Hi-Res"
        case .viperAtmos:  return "全景声"
        case .viperTape:   return "母带"
        case .viperClear:  return "纯净"
        }
    }
}
