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
    case typewriter        // 打字机 - 纸页与机械键帽
    case pixel             // 像素 - 8-bit 复古游戏风格
    case aqua              // 水韵 - 水波纹沉浸式播放器
    case breathing         // 呼吸体 - 没有常规控件的声音核心
    case cassette          // 磁带 - 精致复古纯平几何像素风
    case radio             // 收音机 - 横向卡片式复古收音机
    case immersiveLyric    // 沉浸歌词 - 顶部小图大字纯净版

    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .classic:    return String(localized: "经典")
        case .vinyl:      return String(localized: "黑胶")
        case .lyricFocus: return String(localized: "歌词")
        case .card:       return String(localized: "卡片")
        case .neumorphic: return String(localized: "新拟物")
        case .poster:     return String(localized: "海报")
        case .motoPager:  return String(localized: "寻呼机")
        case .typewriter: return String(localized: "打字机")
        case .pixel:      return String(localized: "像素")
        case .aqua:       return String(localized: "水韵")
        case .breathing:  return String(localized: "呼吸体")
        case .cassette:   return String(localized: "磁带")
        case .radio:      return String(localized: "收音机")
        case .immersiveLyric: return String(localized: "沉浸歌词")
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
        case .typewriter: return "keyboard.fill"
        case .pixel:      return "square.grid.3x3.fill"
        case .aqua:       return "drop.fill"
        case .breathing:  return "dot.radiowaves.left.and.right"
        case .cassette:   return "play.rectangle.fill"
        case .radio:      return "radio.fill"
        case .immersiveLyric: return "music.note.list"
        }
    }
    
    var description: String {
        switch self {
        case .classic:    return String(localized: "大封面居中，经典播放器布局")
        case .vinyl:      return String(localized: "黑胶唱片旋转效果，复古氛围")
        case .lyricFocus: return String(localized: "歌词瀑布流，打字机风格，逐字高亮")
        case .card:       return String(localized: "圆形封面卡片，渐变背景")
        case .neumorphic: return String(localized: "新拟物化设计，柔和阴影立体感")
        case .poster:     return String(localized: "全屏封面海报，沉浸式视觉体验")
        case .motoPager:  return String(localized: "复古寻呼机，打印小票式歌词显示")
        case .typewriter: return String(localized: "复古打字机，纸页歌词与机械键帽控制")
        case .pixel:      return String(localized: "8-bit 像素风格，复古游戏机界面")
        case .aqua:       return String(localized: "水波纹沉浸式，如水杯般宁静流动")
        case .breathing:  return "No controls, just a living audio core"
        case .cassette:   return String(localized: "复古扁平磁带，极其精致的纯平几何重构")
        case .radio:      return String(localized: "复古收音机，横向卡片式 LED 点阵与扬声器")
        case .immersiveLyric: return String(localized: "沉浸歌词，顶部小图大字纯净版")
        }
    }
}
