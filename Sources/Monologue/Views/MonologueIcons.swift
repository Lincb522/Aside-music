import SwiftUI
import HiconIcons

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
    
    var body: some View {
        Group {
            if icon == .liked {
                likedIcon
        } else {
                Image(uiImage: icon.hiconImage)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
        .frame(width: size, height: size)
        .foregroundColor(color)
    }
    
    private var likedIcon: some View {
            ZStack {
            Image(uiImage: Hicon.heart2)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundColor(color.opacity(0.25))
            Image(uiImage: Hicon.heart2)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundColor(color)
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
        } else {
            let mapping = MonologueIcon.IconType.fromSystemName(name)
            MonologueIcon(icon: mapping.icon, size: size, color: color, lineWidth: lineWidth)
                .rotationEffect(mapping.rotation)
        }
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
        case .immersive:        return Hicon.zoomIn
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
        
        case .mv:               return Hicon.tv
        
        case .hitokoto:         return Hicon.message1
        
        // Bar Styles
        case .layers:           return Hicon.category
        case .tabBar:           return Hicon.menuHamburger
        case .minimalBar:       return Hicon.minus
        case .floatingBall:     return Hicon.record
        }
    }
}

#if os(iOS)
extension UIImage {
    static func monologueSymbol(named name: String) -> UIImage {
        MonologueIcon.IconType.fromSystemName(name).icon.hiconImage.withRenderingMode(.alwaysTemplate)
    }
}
#endif
