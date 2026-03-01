import SwiftUI
import HiconIcons

// MARK: - Aside Icon System (Hicon Icons)

struct AsideIcon: View {
    enum IconType {
        case home
        case podcast
        case library
        case search
        case profile
        
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
        
        case layers
        case tabBar
        case minimalBar
        case floatingBall
    }
    
    let icon: IconType
    var size: CGFloat = 24
    var color: Color = .black
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
            Image(uiImage: Hicon.heart1)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundColor(color.opacity(0.25))
            Image(uiImage: Hicon.heart1)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundColor(color)
        }
    }
}

// MARK: - IconType → Hicon Mapping

extension AsideIcon.IconType {
    var hiconImage: UIImage {
        switch self {
        // Tab Bar / Navigation
        case .home:             return Hicon.home1
        case .podcast:          return Hicon.radio
        case .library:          return Hicon.category
        case .search:           return Hicon.search1
        case .profile:          return Hicon.profile1
        
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
        case .like:             return Hicon.heart1
        case .liked:            return Hicon.heart1
        case .list:             return Hicon.menuHamburger
        case .back:             return Hicon.left2
        case .more:             return Hicon.moreCircle
        case .close:            return Hicon.close
        case .trash:            return Hicon.delete1
        case .fm:               return Hicon.discovery1
        case .bell:             return Hicon.notification1
        
        // Settings & Utility
        case .settings:         return Hicon.setting
        case .download:         return Hicon.download
        case .cloud:            return Hicon.upload
        case .chevronRight:     return Hicon.right1
        case .chevronLeft:      return Hicon.left1
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
        
        // Bar Styles
        case .layers:           return Hicon.category
        case .tabBar:           return Hicon.menuHamburger
        case .minimalBar:       return Hicon.minus
        case .floatingBall:     return Hicon.record
        }
    }
}
