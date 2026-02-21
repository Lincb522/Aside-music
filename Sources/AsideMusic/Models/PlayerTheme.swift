import Foundation

/// 播放器主题枚举
enum PlayerTheme: String, Codable, CaseIterable, Identifiable {
    case classic     // 经典 - 大封面居中
    case vinyl       // 黑胶唱片 - 旋转唱片效果
    case lyricFocus  // 歌词 - 歌词瀑布流 + 打字机风格
    case card        // 卡片 - 圆形封面 + 白色卡片 + 渐变背景
    case neumorphic        // 新拟物 - 柔和阴影立体感
    case poster            // 海报 - 全屏封面海报风格
    case motoPager         // 寻呼机 - 复古小票打印风格
    case pixel             // 像素 - 8-bit 复古游戏风格
    case aqua              // 水韵 - 水波纹沉浸式播放器
    case cassette          // 磁带 - 精致复古纯平几何像素风

    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .classic:    return "经典"
        case .vinyl:      return "黑胶"
        case .lyricFocus: return "歌词"
        case .card:       return "卡片"
        case .neumorphic: return "新拟物"
        case .poster:     return "海报"
        case .motoPager:  return "寻呼机"
        case .pixel:      return "像素"
        case .aqua:       return "水韵"
        case .cassette:   return "磁带"
        }
    }
    
    var iconName: String {
        switch self {
        case .classic:    return "square.fill"
        case .vinyl:      return "record.circle"
        case .lyricFocus: return "text.quote"
        case .card:       return "rectangle.portrait.fill"
        case .neumorphic: return "circle.circle"
        case .poster:     return "photo.fill"
        case .motoPager:  return "printer.fill"
        case .pixel:      return "square.grid.3x3.fill"
        case .aqua:       return "drop.fill"
        case .cassette:   return "play.rectangle.fill"
        }
    }
    
    var description: String {
        switch self {
        case .classic:    return "大封面居中，经典播放器布局"
        case .vinyl:      return "黑胶唱片旋转效果，复古氛围"
        case .lyricFocus: return "歌词瀑布流，打字机风格，逐字高亮"
        case .card:       return "圆形封面卡片，渐变背景"
        case .neumorphic: return "新拟物化设计，柔和阴影立体感"
        case .poster:     return "全屏封面海报，沉浸式视觉体验"
        case .motoPager:  return "复古寻呼机，打印小票式歌词显示"
        case .pixel:      return "8-bit 像素风格，复古游戏机界面"
        case .aqua:       return "水波纹沉浸式，如水杯般宁静流动"
        case .cassette:   return "复古扁平磁带，极其精致的纯平几何重构"
        }
    }
}
