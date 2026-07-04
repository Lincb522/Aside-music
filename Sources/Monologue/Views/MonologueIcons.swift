import SwiftUI
import HiconIcons
import ZappiconIcons
import LucideIcons
import SolarIcons
import IconExportIcons
import BlobIcons
import doodlePop
import PawPrintIcons
import DotDogSnakeIcons
import MinimalWhiteIcons

// MARK: - Monologue Icon System (Hicon Icons)

struct MonologueIcon: View {
    enum IconType {
        case home
        case homeFilled
        case podcast
        case podcastFilled
        case library
        case libraryFilled
        case search
        case profile
        case profileFilled
        
        case play
        case pause
        case next
        case previous
        case stop
        case repeatMode
        case repeatOne
        case shuffle
        case refresh
        
        case like
        case liked
        case list
        case back
        case more
        case close
        case trash
        case fm
        case bell
        
        case settings
        case download
        case cloud
        case chevronRight
        case chevronLeft
        case chevronDown
        case chevronUp
        case magnifyingGlass
        case xmark
        case fullscreen
        case sparkle
        case soundQuality
        case storage
        case haptic
        case info
        
        case clock
        case musicNoteList
        case chart
        case translate
        case karaoke
        case lock
        case unlock
        case qr
        case phone
        case send
        case musicNote
        case save
        
        case playerDownload
        case comment
        
        case history
        case playCircle
        case warning
        case personEmpty
        case playNext
        case add
        case addToQueue
        
        case radio
        case micSlash
        case waveform
        case skipBack
        case skipForward
        case rewind15
        case forward15
        case xmarkCircle
        case playCircleFill
        case gridSquare
        
        case checkmark
        case shrinkScreen
        case expandScreen
        case headphones
        case heartSlash
        case personCircle
        case album
        case infoCircle
        case arrowDownCircle
        case sun
        case moon
        case halfCircle
        
        case equalizer
        case immersive
        case playerTheme
        
        case catMusic
        case catLife
        case catEmotion
        case catCreate
        case catAcg
        case catEntertain
        case catTalkshow
        case catBook
        case catKnowledge
        case catBusiness
        case catHistory
        case catNews
        case catParenting
        case catTravel
        case catCrosstalk
        case catFood
        case catTech
        case catDefault
        case catPodcast
        case catElectronic
        case catStar
        case catDrama
        case catStory
        case catOther
        case catPublish
        
        case emoji
        
        case share
        case logInfo
        case logDebug
        case logError
        case logNetwork
        case logSuccess
        case arrowDownToLine
        
        case filter
        case microphone
        case fmMode
        case audioWave
        
        case mv
        case layers
        case hitokoto
        case tabBar
        case minimalBar
        case floatingBall
    }
    
    let icon: IconType
    var size: CGFloat = 24
    var color: Color = .primary
    var lineWidth: CGFloat? = nil
    var normalizesBitmapScale: Bool = false
    @AppStorage(AppConfig.StorageKeys.interfaceIconSet) private var iconSetRaw: String = AppInterfaceIconSet.hicon.rawValue
    @AppStorage(AppInterfaceIconSet.zappiconStyleKey) private var zappiconStyleRaw: String = ZappiconIconStyle.light.rawValue
    @AppStorage(AppInterfaceIconSet.solarStyleKey) private var solarStyleRaw: String = SolarIconStyle.line.rawValue
    
    var body: some View {
        Group {
            if icon == .liked {
                likedIcon
            } else {
                iconImage
            }
        }
        .frame(width: size, height: size)
        .foregroundColor(color)
    }

    private var iconSet: AppInterfaceIconSet {
        _ = iconSetRaw
        return AppInterfaceIconSet.selectedFromDefaults
    }

    /// 当前图标的 UIImage — 根据图标集和风格动态选择
    private var currentImage: UIImage {
        switch iconSet {
        case .hicon:
            return icon.hiconImage
        case .zappicon:
            let style = ZappiconIconStyle(rawValue: zappiconStyleRaw) ?? .light
            return icon.zappiconImage(style: style)
        case .lucide:
            return icon.lucideImage
        case .solar:
            let style = SolarIconStyle(rawValue: solarStyleRaw) ?? .line
            return icon.solarImage(style: style)
        case .iconExport:
            return icon.iconExportImage
        case .blobIcons:
            return icon.blobIconImage
        case .doodlePop:
            return icon.doodlePopImage
        case .pawPrint:
            return icon.pawPrintImage
        case .dotDogSnake:
            return icon.dotDogSnakeImage
        case .minimalWhiteIcons:
            return icon.minimalWhiteIconImage
        }
    }

    private var usesOriginalArtwork: Bool {
        iconSet.usesOriginalArtwork
    }

    private var usesBitmapVisualScale: Bool {
        iconSet == .iconExport || iconSet == .blobIcons || iconSet == .doodlePop || iconSet == .pawPrint || iconSet == .dotDogSnake || iconSet == .minimalWhiteIcons
    }

    private var bitmapIconVisualScale: CGFloat {
        switch iconSet {
        case .minimalWhiteIcons:
            return 1.18
        case .doodlePop, .pawPrint, .dotDogSnake:
            switch icon {
            case .karaoke:
                return 1.58
            case .translate:
                return 1.48
            default:
                return 1.45
            }
        case .iconExport:
            return 1.36
        case .blobIcons:
            return 1.36
        default:
            return 1
        }
    }

    private var effectiveBitmapVisualScale: CGFloat {
        guard usesBitmapVisualScale, !normalizesBitmapScale else { return 1 }
        return bitmapIconVisualScale
    }

    private var iconImage: some View {
        rawIconImage(currentImage)
    }

    private func rawIconImage(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .interpolation(.high)
            .antialiased(true)
            .renderingMode(usesOriginalArtwork ? .original : .template)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .scaleEffect(effectiveBitmapVisualScale)
    }
    
    @ViewBuilder
    private var likedIcon: some View {
        if usesOriginalArtwork {
            rawIconImage(iconSet.image(for: .liked))
        } else {
            ZStack {
                Image(uiImage: iconSet.image(for: .like))
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(color.opacity(0.25))
                Image(uiImage: iconSet.image(for: .liked))
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(color)
            }
            .scaleEffect(effectiveBitmapVisualScale)
        }
    }
}

/// Compatibility layer for older call sites that used SF Symbol names.
/// This intentionally renders through the app icon system so new UI does not depend on SF Symbols.
struct MonologueSymbolIcon: View {
    let name: String
    var size: CGFloat = 20
    var color: Color = .primary
    var lineWidth: CGFloat? = nil

    var body: some View {
        if name == "circle" {
            Circle()
                .stroke(color, lineWidth: lineWidth ?? 1.7)
                .frame(width: size, height: size)
        } else if name == "checkmark.circle.fill" {
            ZStack {
                Circle().fill(color)
                MonologueIcon(icon: .checkmark, size: size * 0.56, color: .white, lineWidth: lineWidth)
            }
            .frame(width: size, height: size)
        } else if name == "quote.opening" || name == "text.quote" {
            Text("“")
                .font(.system(size: size * 1.25, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .frame(width: size, height: size)
        } else if AppInterfaceIconSet.selectedFromDefaults == .pawPrint, name == "chevron.down" {
            MonologuePawPrintChevronIcon(direction: .down, size: size, fallbackColor: color)
        } else if AppInterfaceIconSet.selectedFromDefaults == .pawPrint, name == "chevron.up" {
            MonologuePawPrintChevronIcon(direction: .up, size: size, fallbackColor: color)
        } else {
            let mapping = MonologueIcon.IconType.fromSystemName(name)
            MonologueIcon(icon: mapping.icon, size: size, color: color, lineWidth: lineWidth)
                .rotationEffect(mapping.rotation)
        }
    }
}

private struct MonologuePawPrintChevronIcon: View {
    enum Direction {
        case up
        case down

        var assetName: String {
            switch self {
            case .up: return "chevronUp"
            case .down: return "chevronDown"
            }
        }

        var fallbackSystemName: String {
            switch self {
            case .up: return "chevron.up"
            case .down: return "chevron.down"
            }
        }
    }

    let direction: Direction
    var size: CGFloat
    var fallbackColor: Color

    var body: some View {
        platformImage
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var platformImage: some View {
        if let image = UIImage(pawPrintIconId: direction.assetName) {
            Image(uiImage: image)
                .renderingMode(.original)
                .interpolation(.high)
                .antialiased(true)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            fallbackIcon
        }
    }

    private var fallbackIcon: some View {
        let mapping = MonologueIcon.IconType.fromSystemName(direction.fallbackSystemName)
        return MonologueIcon(icon: mapping.icon, size: size, color: fallbackColor)
            .rotationEffect(mapping.rotation)
    }
}

// MARK: - IconType → Hicon Mapping

extension MonologueIcon.IconType {
    static func fromSystemName(_ name: String) -> (icon: MonologueIcon.IconType, rotation: Angle) {
        switch name {
        case "house.fill":
            return (.homeFilled, .zero)
        case "mic.fill", "music.mic":
            return (.microphone, .zero)
        case "square.stack.3d.up.fill", "square.grid.2x2", "square.grid.2x2.fill", "rectangle.stack.fill":
            return (.gridSquare, .zero)
        case "person.fill", "person.2", "person.2.fill", "person.crop.circle.badge.questionmark":
            return (.profileFilled, .zero)
        case "music.note":
            return (.musicNote, .zero)
        case "music.note.list", "list.bullet":
            return (.musicNoteList, .zero)
        case "magnifyingglass":
            return (.magnifyingGlass, .zero)
        case "gearshape.fill":
            return (.settings, .zero)
        case "radio", "dot.radiowaves.left.and.right":
            return (.radio, .zero)
        case "heart", "heart.fill":
            return (.liked, .zero)
        case "star.fill", "star":
            return (.sparkle, .zero)
        case "play.fill", "play.circle.fill":
            return (.play, .zero)
        case "pause.fill":
            return (.pause, .zero)
        case "backward.fill", "backward.end.alt.fill":
            return (.previous, .zero)
        case "forward.fill", "forward.end.alt.fill":
            return (.next, .zero)
        case "chevron.right":
            return (.chevronRight, .zero)
        case "chevron.left":
            return (.chevronLeft, .zero)
        case "chevron.down":
            return (.chevronRight, .degrees(90))
        case "chevron.up":
            return (.chevronRight, .degrees(-90))
        case "ellipsis", "ellipsis.bubble.fill":
            return (.more, .zero)
        case "xmark", "xmark.circle.fill":
            return (.close, .zero)
        case "arrow.down.circle.fill":
            return (.arrowDownCircle, .zero)
        case "arrow.trianglehead.2.clockwise":
            return (.refresh, .zero)
        case "repeat":
            return (.repeatMode, .zero)
        case "repeat.1":
            return (.repeatOne, .zero)
        case "shuffle":
            return (.shuffle, .zero)
        case "waveform":
            return (.waveform, .zero)
        case "tv", "film", "play.tv":
            return (.immersive, .zero)
        case "bubble.left.fill", "bubble.left.and.bubble.right.fill":
            return (.comment, .zero)
        case "cart":
            return (.download, .zero)
        case "trash":
            return (.trash, .zero)
        case "sun.max.fill":
            return (.sun, .zero)
        case "moon.fill":
            return (.moon, .zero)
        case "pencil.and.outline", "hand.draw":
            return (.save, .zero)
        default:
            return (.sparkle, .zero)
        }
    }

    var hiconImage: UIImage {
        switch self {
        // Tab Bar / Navigation
        case .home:             return Hicon.home1
        case .homeFilled:       return Hicon.home2
        case .podcast:          return Hicon.microphone3
        case .podcastFilled:    return Hicon.microphone4
        case .library:          return Hicon.headphone1
        case .libraryFilled:    return Hicon.headphone2
        case .search:           return Hicon.search1
        case .profile:          return Hicon.profile1
        case .profileFilled:    return Hicon.profile1
        
        // Playback Controls
        case .play:             return Hicon.play
        case .pause:            return Hicon.pause
        case .next:             return Hicon.next
        case .previous:         return Hicon.previous
        case .stop:             return Hicon.stop
        case .repeatMode:       return Hicon.repeate1
        case .repeatOne:        return Hicon.repeateOne1
        case .shuffle:          return Hicon.shuffle1
        case .refresh:          return Hicon.refresh1
        
        // Actions
        case .like:             return Hicon.heart2
        case .liked:            return Hicon.heart2
        case .list:             return Hicon.menuHamburger
        case .back:             return Hicon.left2
        case .more:             return Hicon.menuMeatballs
        case .close:            return Hicon.close
        case .trash:            return Hicon.delete1
        case .fm:               return Hicon.radio
        case .bell:             return Hicon.notification1
        
        // Settings & Utility
        case .settings:         return Hicon.setting
        case .download:         return Hicon.download
        case .cloud:            return Hicon.upload
        case .chevronRight:     return Hicon.right2
        case .chevronLeft:      return Hicon.left2
        case .chevronDown:      return Hicon.down2
        case .chevronUp:        return Hicon.up2
        case .magnifyingGlass:  return Hicon.search1
        case .xmark:            return Hicon.close
        case .fullscreen:       return Hicon.zoomIn
        case .sparkle:          return Hicon.star1
        case .soundQuality:     return Hicon.voiceShape1
        case .storage:          return Hicon.flashDisk1
        case .haptic:           return Hicon.activity1
        case .info:             return Hicon.informationCircle
        
        // Media Info
        case .clock:            return Hicon.timeCircle1
        case .musicNoteList:    return Hicon.musicnote
        case .chart:            return Hicon.chart
        case .translate:        return Hicon.text
        case .karaoke:          return Hicon.microphone1
        case .lock:             return Hicon.lock1
        case .unlock:           return Hicon.unlock1
        case .qr:               return Hicon.scan1
        case .phone:            return Hicon.call
        case .send:             return Hicon.send1
        case .musicNote:        return Hicon.music
        case .save:             return Hicon.bookmark1
        
        // Player
        case .playerDownload:   return Hicon.download
        case .comment:          return Hicon.message1
        
        // Library
        case .history:          return Hicon.timeCircle3
        case .playCircle:       return Hicon.playCircle
        case .warning:          return Hicon.dangerTriangle
        case .personEmpty:      return Hicon.profile1
        case .playNext:         return Hicon.addCategory
        case .add:              return Hicon.add
        case .addToQueue:       return Hicon.addCategory
        
        // Podcast
        case .radio:            return Hicon.radio
        case .micSlash:         return Hicon.microphoneOff
        case .waveform:         return Hicon.voiceShape1
        case .skipBack:         return Hicon.backward
        case .skipForward:      return Hicon.forward
        case .rewind15:         return Hicon.backward10Seconds
        case .forward15:        return Hicon.forward10Seconds
        case .xmarkCircle:      return Hicon.closeCircle
        case .playCircleFill:   return Hicon.playCircle
        case .gridSquare:       return Hicon.category
        
        // Symbols
        case .checkmark:        return Hicon.tick
        case .shrinkScreen:     return Hicon.zoomOut
        case .expandScreen:     return Hicon.zoomIn
        case .headphones:       return Hicon.headphone1
        case .heartSlash:       return Hicon.dislike
        case .personCircle:     return Hicon.profileCircle
        case .album:            return Hicon.record
        case .infoCircle:       return Hicon.informationCircle
        case .arrowDownCircle:  return Hicon.downCircle1
        case .sun:              return Hicon.sun1
        case .moon:             return Hicon.moon
        case .halfCircle:       return Hicon.sun2
        
        // Settings Icons
        case .equalizer:        return Hicon.setting
        // 沉浸模式改用电视/影院图标（原为 zoomIn 放大镜样式）
        case .immersive:        return Hicon.tv
        case .playerTheme:      return Hicon.palette
        
        // Podcast Categories
        case .catMusic:         return Hicon.music
        case .catLife:          return Hicon.discovery2
        case .catEmotion:       return Hicon.heart1
        case .catCreate:        return Hicon.pen
        case .catAcg:           return Hicon.ps51
        case .catEntertain:     return Hicon.tv
        case .catTalkshow:      return Hicon.microphone1
        case .catBook:          return Hicon.bookmark1
        case .catKnowledge:     return Hicon.education
        case .catBusiness:      return Hicon.work
        case .catHistory:       return Hicon.timeCircle1
        case .catNews:          return Hicon.documentAlignLeft1
        case .catParenting:     return Hicon.happy1
        case .catTravel:        return Hicon.location
        case .catCrosstalk:     return Hicon.microphone2
        case .catFood:          return Hicon.cupOfTea
        case .catTech:          return Hicon.display1
        case .catDefault:       return Hicon.folder1
        case .catPodcast:       return Hicon.radio
        case .catElectronic:    return Hicon.activity2
        case .catStar:          return Hicon.star1
        case .catDrama:         return Hicon.video1
        case .catStory:         return Hicon.bookmark2
        case .catOther:         return Hicon.moreCircle
        case .catPublish:       return Hicon.documentAlignLeft5
        
        // Emoji & Debug
        case .emoji:            return Hicon.happy1
        case .share:            return Hicon.send2
        case .logInfo:          return Hicon.informationCircle
        case .logDebug:         return Hicon.faqCircle
        case .logError:         return Hicon.dangerCircle
        case .logNetwork:       return Hicon.wifi
        case .logSuccess:       return Hicon.tickCircle
        case .arrowDownToLine:  return Hicon.download
        
        // Filters & Misc
        case .filter:           return Hicon.filter1
        case .microphone:       return Hicon.microphone1
        case .fmMode:           return Hicon.radio
        case .audioWave:        return Hicon.voiceShape2
        
        case .mv:               return Hicon.video1
        
        case .hitokoto:         return Hicon.message1
        
        // Bar Styles
        case .layers:           return Hicon.category
        case .tabBar:           return Hicon.menuHamburger
        case .minimalBar:       return Hicon.minus
        case .floatingBall:     return Hicon.record
        }
    }
}

extension AppInterfaceIconSet {
    func image(for icon: MonologueIcon.IconType) -> UIImage {
        switch self {
        case .hicon:
            return icon.hiconImage
        case .zappicon:
            return icon.zappiconImage(style: AppInterfaceIconSet.selectedZappiconStyle)
        case .lucide:
            return icon.lucideImage
        case .solar:
            return icon.solarImage(style: AppInterfaceIconSet.selectedSolarStyle)
        case .iconExport:
            return icon.iconExportImage
        case .blobIcons:
            return icon.blobIconImage
        case .doodlePop:
            return icon.doodlePopImage
        case .pawPrint:
            return icon.pawPrintImage
        case .dotDogSnake:
            return icon.dotDogSnakeImage
        case .minimalWhiteIcons:
            return icon.minimalWhiteIconImage
        }
    }
}

// MARK: - IconType → Icon Export Mapping

extension MonologueIcon.IconType {
    /// 位图图标包的资源 id。
    /// 沉浸模式改用「mv」视频图标（各包原有的 immersive 资源为放大箭头样式，与影院沉浸含义不符）。
    private var bitmapIconId: String {
        switch self {
        case .immersive: return "mv"
        default: return String(describing: self)
        }
    }

    var iconExportImage: UIImage {
        UIImage(iconExportId: bitmapIconId) ?? hiconImage
    }

    var blobIconImage: UIImage {
        UIImage(blobIconId: bitmapIconId) ?? hiconImage
    }

    var doodlePopImage: UIImage {
        UIImage(doodlePopIconId: bitmapIconId) ?? hiconImage
    }

    var pawPrintImage: UIImage {
        UIImage(pawPrintIconId: bitmapIconId) ?? hiconImage
    }

    var dotDogSnakeImage: UIImage {
        UIImage(dotDogSnakeIconId: bitmapIconId) ?? hiconImage
    }

    var minimalWhiteIconImage: UIImage {
        UIImage(minimalWhiteIconId: bitmapIconId) ?? hiconImage
    }
}

#if os(iOS)
extension UIImage {
    static func monologueSymbol(named name: String) -> UIImage {
        let icon = MonologueIcon.IconType.fromSystemName(name).icon
        let iconSet = AppInterfaceIconSet.selectedFromDefaults
        let renderingMode: UIImage.RenderingMode = iconSet.usesOriginalArtwork ? .alwaysOriginal : .alwaysTemplate
        return iconSet.image(for: icon).withRenderingMode(renderingMode)
    }
}
#endif

// MARK: - IconType → Zappicon Mapping

extension MonologueIcon.IconType {
    /// Zappicon (H173) 图标映射 — 根据用户选择的风格动态加载
    func zappiconImage(style: ZappiconIconStyle) -> UIImage {
        let name: String
        switch self {
        // Tab Bar / Navigation
        case .home:             name = "house"
        case .homeFilled:       name = "house-simple"
        case .podcast:          name = "microphone-stand"
        case .podcastFilled:    name = "microphone-stand"
        case .library:          name = "headphones"
        case .libraryFilled:    name = "headphones"
        case .search:           name = "search"
        case .profile:          name = "user"
        case .profileFilled:    name = "user-circle"

        // Playback Controls
        case .play:             name = "play"
        case .pause:            name = "pause"
        case .next:             name = "forward-step"
        case .previous:         name = "backward-step"
        case .stop:             name = "stop"
        case .repeatMode:       name = "repeat"
        case .repeatOne:        name = "repeat-1"
        case .shuffle:          name = "shuffle"
        case .refresh:          name = "arrows-rotate"

        // Actions
        case .like:             name = "heart"
        case .liked:            name = "heart"
        case .list:             name = "playlist"
        case .back:             name = "angle-left"
        case .more:             name = "menu-bars"
        case .close:            name = "xmark"
        case .trash:            name = "trash"
        case .fm:               name = "radio"
        case .bell:             name = "bell"

        // Settings & Utility
        case .settings:         name = "gear"
        case .download:         name = "download-arrow-down"
        case .cloud:            name = "cloud-upload"
        case .chevronRight:     name = "angle-right"
        case .chevronLeft:      name = "angle-left"
        case .chevronDown:      name = "angle-down"
        case .chevronUp:        name = "angle-up"
        case .magnifyingGlass:  name = "search"
        case .xmark:            name = "xmark"
        case .fullscreen:       name = "arrows-expand"
        case .sparkle:          name = "star"
        case .soundQuality:     name = "waveform-lines"
        case .storage:          name = "folder"
        case .haptic:           name = "waveform"
        case .info:             name = "info-circle"

        // Media Info
        case .clock:            name = "clock"
        case .musicNoteList:    name = "music-list"
        case .chart:            name = "music-list-wave"
        case .translate:        name = "newspaper"
        case .karaoke:          name = "microphone"
        case .lock:             name = "lock"
        case .unlock:           name = "unlock"
        case .qr:               name = "qr-code"
        case .phone:            name = "phone"
        case .send:             name = "send"
        case .musicNote:        name = "music-note"
        case .save:             name = "bookmark"

        // Player
        case .playerDownload:   name = "download-arrow-down"
        case .comment:          name = "comment-smile"

        // Library
        case .history:          name = "time-history"
        case .playCircle:       name = "play-circle"
        case .warning:          name = "exclamation-triangle"
        case .personEmpty:      name = "user"
        case .playNext:         name = "playlist-plus"
        case .add:              name = "plus"
        case .addToQueue:       name = "playlist-plus"

        // Podcast
        case .radio:            name = "radio"
        case .micSlash:         name = "microphone-slash"
        case .waveform:         name = "waveform"
        case .skipBack:         name = "backward"
        case .skipForward:      name = "forward"
        case .rewind15:         name = "time-past-15"
        case .forward15:        name = "time-next-15"
        case .xmarkCircle:      name = "xmark-circle"
        case .playCircleFill:   name = "play-circle"
        case .gridSquare:       name = "grid-square"

        // Symbols
        case .checkmark:        name = "check"
        case .shrinkScreen:     name = "arrows-compress"
        case .expandScreen:     name = "arrows-expand"
        case .headphones:       name = "headphones"
        case .heartSlash:       name = "heart-slash"
        case .personCircle:     name = "user-circle"
        case .album:            name = "music-note-circle"
        case .infoCircle:       name = "info-circle"
        case .arrowDownCircle:  name = "arrow-down-circle"
        case .sun:              name = "sun"
        case .moon:             name = "moon"
        case .halfCircle:       name = "sun"

        // Settings Icons
        case .equalizer:        name = "gear"
        // 沉浸模式改用电视/影院图标（原为 arrows-expand）
        case .immersive:        name = "tv"
        case .playerTheme:      name = "palette"

        // Podcast Categories
        case .catMusic:         name = "music"
        case .catLife:          name = "compass"
        case .catEmotion:       name = "heart"
        case .catCreate:        name = "pen"
        case .catAcg:           name = "game-controller"
        case .catEntertain:     name = "tv"
        case .catTalkshow:      name = "microphone"
        case .catBook:          name = "book"
        case .catKnowledge:     name = "diploma"
        case .catBusiness:      name = "briefcase"
        case .catHistory:       name = "clock"
        case .catNews:          name = "newspaper"
        case .catParenting:     name = "comment-smile"
        case .catTravel:        name = "location-arrow"
        case .catCrosstalk:     name = "microphone"
        case .catFood:          name = "mug-saucer"
        case .catTech:          name = "display"
        case .catDefault:       name = "folder"
        case .catPodcast:       name = "radio"
        case .catElectronic:    name = "waveform"
        case .catStar:          name = "star"
        case .catDrama:         name = "video"
        case .catStory:         name = "book"
        case .catOther:         name = "grid-circle"
        case .catPublish:       name = "send"

        // Emoji & Debug
        case .emoji:            name = "comment-smile"
        case .share:            name = "share"
        case .logInfo:          name = "info-circle"
        case .logDebug:         name = "search"
        case .logError:         name = "exclamation-triangle"
        case .logNetwork:       name = "wifi"
        case .logSuccess:       name = "check-circle"
        case .arrowDownToLine:  name = "download-arrow-down"

        // Filters & Misc
        case .filter:           name = "filter"
        case .microphone:       name = "microphone"
        case .fmMode:           name = "radio"
        case .audioWave:        name = "waveform-lines"
        case .mv:               name = "video"
        case .hitokoto:         name = "chat-dots"

        // Bar Styles
        case .layers:           name = "grid-square"
        case .tabBar:           name = "menu-bars"
        case .minimalBar:       name = "minus"
        case .floatingBall:     name = "record-audio"
        }

        // 拼接风格前缀加载：如 "light-play", "filled-heart"
        let assetName = "\(style.rawValue)-\(name)"
        return UIImage(zappiconId: assetName) ?? UIImage()
    }
}

// MARK: - IconType → Lucide Mapping

extension MonologueIcon.IconType {
    /// Lucide 图标映射
    var lucideImage: UIImage {
        let name: String
        switch self {
        // Tab Bar / Navigation
        case .home:             name = "house"
        case .homeFilled:       name = "house"
        case .podcast:          name = "mic"
        case .podcastFilled:    name = "mic"
        case .library:          name = "headphones"
        case .libraryFilled:    name = "headphones"
        case .search:           name = "search"
        case .profile:          name = "user"
        case .profileFilled:    name = "circle-user"

        // Playback Controls
        case .play:             name = "play"
        case .pause:            name = "pause"
        case .next:             name = "skip-forward"
        case .previous:         name = "skip-back"
        case .stop:             name = "circle-stop"
        case .repeatMode:       name = "repeat"
        case .repeatOne:        name = "repeat-1"
        case .shuffle:          name = "shuffle"
        case .refresh:          name = "refresh-cw"

        // Actions
        case .like:             name = "heart"
        case .liked:            name = "heart"
        case .list:             name = "list-music"
        case .back:             name = "chevron-left"
        case .more:             name = "menu"
        case .close:            name = "x-line-top"
        case .trash:            name = "trash-2"
        case .fm:               name = "radio"
        case .bell:             name = "bell"

        // Settings & Utility
        case .settings:         name = "settings"
        case .download:         name = "download"
        case .cloud:            name = "cloud-upload"
        case .chevronRight:     name = "chevron-right"
        case .chevronLeft:      name = "chevron-left"
        case .chevronDown:      name = "chevron-down"
        case .chevronUp:        name = "chevron-up"
        case .magnifyingGlass:  name = "search"
        case .xmark:            name = "x-line-top"
        case .fullscreen:       name = "maximize-2"
        case .sparkle:          name = "star"
        case .soundQuality:     name = "music"
        case .storage:          name = "hard-drive-download"
        case .haptic:           name = "activity"
        case .info:             name = "info"

        // Media Info
        case .clock:            name = "clock"
        case .musicNoteList:    name = "list-music"
        case .chart:            name = "music-2"
        case .translate:        name = "book-open-text"
        case .karaoke:          name = "mic-vocal"
        case .lock:             name = "lock"
        case .unlock:           name = "lock-open"
        case .qr:               name = "scan-search"
        case .phone:            name = "phone"
        case .send:             name = "send"
        case .musicNote:        name = "music"
        case .save:             name = "bookmark"

        // Player
        case .playerDownload:   name = "download"
        case .comment:          name = "message-circle"

        // Library
        case .history:          name = "clock"
        case .playCircle:       name = "circle-play"
        case .warning:          name = "circle-alert"
        case .personEmpty:      name = "user"
        case .playNext:         name = "list-plus"
        case .add:              name = "plus"
        case .addToQueue:       name = "list-plus"

        // Podcast
        case .radio:            name = "radio"
        case .micSlash:         name = "mic-off"
        case .waveform:         name = "activity"
        case .skipBack:         name = "skip-back"
        case .skipForward:      name = "skip-forward"
        case .rewind15:         name = "skip-back"
        case .forward15:        name = "skip-forward"
        case .xmarkCircle:      name = "circle-x"
        case .playCircleFill:   name = "circle-play"
        case .gridSquare:       name = "grid-2x2"

        // Symbols
        case .checkmark:        name = "check"
        case .shrinkScreen:     name = "minimize-2"
        case .expandScreen:     name = "maximize-2"
        case .headphones:       name = "headphones"
        case .heartSlash:       name = "heart-off"
        case .personCircle:     name = "circle-user"
        case .album:            name = "disc-3"
        case .infoCircle:       name = "info"
        case .arrowDownCircle:  name = "circle-arrow-down"
        case .sun:              name = "sun"
        case .moon:             name = "moon"
        case .halfCircle:       name = "sun-moon"

        // Settings Icons
        case .equalizer:        name = "settings-2"
        // 沉浸模式改用「电视 + 播放」图标（原为 maximize-2）
        case .immersive:        name = "tv-minimal-play"
        case .playerTheme:      name = "palette"

        // Podcast Categories
        case .catMusic:         name = "music"
        case .catLife:          name = "heart-pulse"
        case .catEmotion:       name = "heart"
        case .catCreate:        name = "pen"
        case .catAcg:           name = "disc-2"
        case .catEntertain:     name = "tv"
        case .catTalkshow:      name = "mic"
        case .catBook:          name = "book-open"
        case .catKnowledge:     name = "book-check"
        case .catBusiness:      name = "briefcase"
        case .catHistory:       name = "clock"
        case .catNews:          name = "megaphone"
        case .catParenting:     name = "smile-plus"
        case .catTravel:        name = "map-pin-check"
        case .catCrosstalk:     name = "mic-vocal"
        case .catFood:          name = "concierge-bell"
        case .catTech:          name = "monitor-smartphone"
        case .catDefault:       name = "folder"
        case .catPodcast:       name = "radio"
        case .catElectronic:    name = "activity"
        case .catStar:          name = "star"
        case .catDrama:         name = "tv"
        case .catStory:         name = "book-open"
        case .catOther:         name = "circle-ellipsis"
        case .catPublish:       name = "send"

        // Emoji & Debug
        case .emoji:            name = "smile-plus"
        case .share:            name = "share-2"
        case .logInfo:          name = "info"
        case .logDebug:         name = "search"
        case .logError:         name = "circle-alert"
        case .logNetwork:       name = "wifi-pen"
        case .logSuccess:       name = "circle-check"
        case .arrowDownToLine:  name = "arrow-down-to-line"

        // Filters & Misc
        case .filter:           name = "list-filter"
        case .microphone:       name = "mic"
        case .fmMode:           name = "radio"
        case .audioWave:        name = "music-3"
        case .mv:               name = "video"
        case .hitokoto:         name = "message-circle"

        // Bar Styles
        case .layers:           name = "grid-2x2"
        case .tabBar:           name = "menu"
        case .minimalBar:       name = "minus"
        case .floatingBall:     name = "circle"
        }

        return UIImage(lucideId: name) ?? UIImage()
    }
}

// MARK: - IconType → Solar Mapping

extension MonologueIcon.IconType {
    /// Solar Icons 图标映射 — 根据用户选择的风格动态加载
    func solarImage(style: SolarIconStyle) -> UIImage {
        let name: String
        switch self {
        case .home:             name = "home"
        case .homeFilled:       name = "home-2"
        case .podcast:          name = "microphone"
        case .podcastFilled:    name = "microphone"
        case .library:          name = "headphone"
        case .libraryFilled:    name = "headphone"
        case .search:           name = "search"
        case .profile:          name = "user"
        case .profileFilled:    name = "user-circle"
        case .play:             name = "play"
        case .pause:            name = "pause"
        case .next:             name = "fast-forward"
        case .previous:         name = "fast-backward"
        case .stop:             name = "pause-circle"
        case .repeatMode:       name = "sync"
        case .repeatOne:        name = "arrow-rotate-right"
        case .shuffle:          name = "shuffle"
        case .refresh:          name = "arrow-rotate-right"
        case .like:             name = "heart"
        case .liked:            name = "heart"
        case .list:             name = "list-ui"
        case .back:             name = "angle-left"
        case .more:             name = "3-dots-horizontal"
        case .close:            name = "cancel"
        case .trash:            name = "trash"
        case .fm:               name = "radio"
        case .bell:             name = "bell"
        case .settings:         name = "gear"
        case .download:         name = "download"
        case .cloud:            name = "cloud"
        case .chevronRight:     name = "angle-right"
        case .chevronLeft:      name = "angle-left"
        case .chevronDown:      name = "angle-down"
        case .chevronUp:        name = "angle-up"
        case .magnifyingGlass:  name = "search"
        case .xmark:            name = "cancel"
        case .fullscreen:       name = "expand"
        case .sparkle:          name = "star"
        case .soundQuality:     name = "music-2"
        case .storage:          name = "folder"
        case .haptic:           name = "activity"
        case .info:             name = "info-circle"
        case .clock:            name = "clock"
        case .musicNoteList:    name = "music"
        case .chart:            name = "music-2"
        case .translate:        name = "book-open"
        case .karaoke:          name = "microphone"
        case .lock:             name = "lock"
        case .unlock:           name = "lock-open"
        case .qr:               name = "grid-square"
        case .phone:            name = "phone"
        case .send:             name = "send"
        case .musicNote:        name = "music"
        case .save:             name = "bookmark"
        case .playerDownload:   name = "download"
        case .comment:          name = "comment-dots"
        case .history:          name = "clock"
        case .playCircle:       name = "play-circle"
        case .warning:          name = "info-circle"
        case .personEmpty:      name = "user"
        case .playNext:         name = "forward-circle"
        case .add:              name = "plus"
        case .addToQueue:       name = "forward-circle"
        case .radio:            name = "radio"
        case .micSlash:         name = "microphone"
        case .waveform:         name = "activity"
        case .skipBack:         name = "fast-backward"
        case .skipForward:      name = "fast-forward"
        case .rewind15:         name = "fast-backward"
        case .forward15:        name = "fast-forward"
        case .xmarkCircle:      name = "cancel-circle"
        case .playCircleFill:   name = "play-circle"
        case .gridSquare:       name = "grid-square"
        case .checkmark:        name = "check"
        case .shrinkScreen:     name = "compress"
        case .expandScreen:     name = "expand"
        case .headphones:       name = "headphone"
        case .heartSlash:       name = "heart"
        case .personCircle:     name = "user-circle"
        case .album:            name = "music-2"
        case .infoCircle:       name = "info-circle"
        case .arrowDownCircle:  name = "arrow-down-circle"
        case .sun:              name = "moon"
        case .moon:             name = "moon"
        case .halfCircle:       name = "moon"
        case .equalizer:        name = "gear"
        // 沉浸模式改用电视/影院图标（原为 expand）
        case .immersive:        name = "tv"
        case .playerTheme:      name = "color-palette"
        case .catMusic:         name = "music"
        case .catLife:          name = "compass"
        case .catEmotion:       name = "heart"
        case .catCreate:        name = "pen"
        case .catAcg:           name = "gamepad"
        case .catEntertain:     name = "tv"
        case .catTalkshow:      name = "microphone"
        case .catBook:          name = "book"
        case .catKnowledge:     name = "book-open"
        case .catBusiness:      name = "gear"
        case .catHistory:       name = "clock"
        case .catNews:          name = "megaphone"
        case .catParenting:     name = "heart"
        case .catTravel:        name = "location-pin"
        case .catCrosstalk:     name = "microphone"
        case .catFood:          name = "coffee-cup"
        case .catTech:          name = "tv"
        case .catDefault:       name = "folder"
        case .catPodcast:       name = "radio"
        case .catElectronic:    name = "activity"
        case .catStar:          name = "star"
        case .catDrama:         name = "tv"
        case .catStory:         name = "book"
        case .catOther:         name = "grid-circle"
        case .catPublish:       name = "send"
        case .emoji:            name = "heart"
        case .share:            name = "share-ios"
        case .logInfo:          name = "info-circle"
        case .logDebug:         name = "search"
        case .logError:         name = "cancel-circle"
        case .logNetwork:       name = "wifi"
        case .logSuccess:       name = "check-circle"
        case .arrowDownToLine:  name = "download"
        case .filter:           name = "filter"
        case .microphone:       name = "microphone"
        case .fmMode:           name = "radio"
        case .audioWave:        name = "activity"
        case .mv:               name = "play-circle"
        case .hitokoto:         name = "comment-dots"
        case .layers:           name = "grid-square"
        case .tabBar:           name = "list-ui"
        case .minimalBar:       name = "minus"
        case .floatingBall:     name = "play-circle"
        }

        let assetName = "\(style.rawValue)-\(name)"
        return UIImage(solarId: assetName) ?? UIImage()
    }
}
