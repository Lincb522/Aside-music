import SwiftUI

// MARK: - Aside Icon System (Aura Floating Icon Set)

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
        
        // 播放器专用下载图标
        case playerDownload
        
        // 评论图标
        case comment
        
        case history
        case playCircle
        case warning
        case personEmpty
        case playNext
        case add
        case addToQueue
        
        // 播客专用图标
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
        
        // 补齐替换 SF Symbols 的图标
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
        
        // 均衡器图标
        case equalizer
        
        // 沉浸式播放器图标
        case immersive
        
        // 播放器主题图标（四宫格 + 画笔）
        case playerTheme
        
        // 电台分类图标
        case catMusic       // 音乐
        case catLife         // 生活
        case catEmotion      // 情感
        case catCreate       // 创作|翻唱
        case catAcg          // 二次元
        case catEntertain    // 娱乐
        case catTalkshow     // 脱口秀
        case catBook         // 有声书
        case catKnowledge    // 知识
        case catBusiness     // 商业财经
        case catHistory      // 人文历史
        case catNews         // 新闻资讯
        case catParenting    // 亲子
        case catTravel       // 旅途
        case catCrosstalk    // 相声曲艺
        case catFood         // 美食
        case catTech         // 科技
        case catDefault      // 默认分类图标
        case catPodcast      // 音乐播客
        case catElectronic   // 电音
        case catStar         // 明星专区
        case catDrama        // 广播剧
        case catStory        // 故事
        case catOther        // 其他
        case catPublish      // 文学出版
        
        // 表情图标
        case emoji
        
        // 调试日志图标
        case share
        case logInfo
        case logDebug
        case logError
        case logNetwork
        case logSuccess
        case arrowDownToLine
        
        // 筛选图标
        case filter
        
        // 麦克风图标（听歌识曲）
        case microphone
        
        // FM 模式切换图标（旋钮/调频）
        case fmMode
        
        // 听歌识曲图标（声波 + 音符）
        case audioWave
        
        // 悬浮栏样式图标
        case layers       // 统一悬浮栏（层叠）
        case tabBar       // 经典 TabBar
        case minimalBar   // 极简模式
        case floatingBall // 悬浮球
    }
    
    let icon: IconType
    var size: CGFloat = 24
    var color: Color = .black
    var lineWidth: CGFloat = 1.6
    
    private var strokeColor: Color { color }
    private var fillColor: Color { color.opacity(0.15) }
    
    var body: some View {
        ZStack {
            if shouldShowFill {
                fillLayer
            }
            
            strokeLayer
        }
        .frame(width: size, height: size)
    }
    
    private var shouldShowFill: Bool {
        switch icon {
        case .back, .close, .chevronRight, .chevronLeft, .xmark, .list, .more, .pause, .next, .previous, .shuffle, .refresh, .repeatMode, .repeatOne, .add, .playNext, .addToQueue, .waveform, .skipBack, .skipForward, .rewind15, .forward15, .playerDownload, .comment, .checkmark, .shrinkScreen, .expandScreen, .heartSlash, .equalizer, .immersive, .playerTheme, .catDefault, .catMusic, .catLife, .catEmotion, .catCreate, .catAcg, .catEntertain, .catTalkshow, .catBook, .catKnowledge, .catBusiness, .catHistory, .catNews, .catParenting, .catTravel, .catCrosstalk, .catFood, .catTech, .catPodcast, .catElectronic, .catStar, .catDrama, .catStory, .catOther, .catPublish, .emoji, .share, .logInfo, .logDebug, .logError, .logNetwork, .logSuccess, .arrowDownToLine, .filter, .microphone, .fmMode, .audioWave, .layers, .tabBar, .minimalBar, .floatingBall:
            return false
        default:
            return true
        }
    }
    
    @ViewBuilder
    private var fillLayer: some View {
        switch icon {
        case .liked:        LikePath().fill(color.opacity(0.15))
        default:            pathForIcon(icon).fill(fillColor)
        }
    }
    
    @ViewBuilder
    private var strokeLayer: some View {
        let style = StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
        
        switch icon {
        case .liked:
            LikedPath().stroke(strokeColor, style: style)
            ZStack {
                LikePath().stroke(strokeColor, style: style)
                LikePath().fill(color.opacity(0.15))
                Circle().frame(width: size * (3.0/24.0), height: size * (3.0/24.0)).position(x: size * (12.0/24.0), y: size * (10.0/24.0)).foregroundColor(color)
            }
        default:
            pathForIcon(icon).stroke(strokeColor, style: style)
        }
    }
    
    private func pathForIcon(_ icon: IconType) -> some Shape {
        switch icon {
        case .home:         return AnyShape(HomePath())
        case .podcast:      return AnyShape(PodcastPath())
        case .library:      return AnyShape(LibraryPath())
        case .search:       return AnyShape(SearchPath())
        case .profile:      return AnyShape(ProfilePath())
        case .play:         return AnyShape(PlayPath())
        case .pause:        return AnyShape(PausePath())
        case .next:         return AnyShape(NextPath())
        case .previous:     return AnyShape(PreviousPath())
        case .stop:         return AnyShape(StopPath())
        case .like:         return AnyShape(LikePath())
        case .liked:        return AnyShape(LikePath())
        case .list:         return AnyShape(ListPath())
        case .back:         return AnyShape(BackPath())
        case .more:         return AnyShape(MorePath())
        case .close:        return AnyShape(ClosePath())
        case .trash:        return AnyShape(TrashPath())
        case .fm:           return AnyShape(FMPath())
        case .bell:         return AnyShape(BellPath())
        case .settings:     return AnyShape(SettingsPath())
        case .download:     return AnyShape(DownloadPath())
        case .cloud:        return AnyShape(CloudPath())
        case .chevronRight: return AnyShape(ChevronRightPath())
        case .chevronLeft:  return AnyShape(ChevronLeftPath())
        case .magnifyingGlass: return AnyShape(MagnifyingGlassPath())
        case .xmark:        return AnyShape(XmarkPath())
        case .repeatMode:   return AnyShape(RepeatPath())
        case .repeatOne:    return AnyShape(RepeatOnePath())
        case .shuffle:      return AnyShape(ShufflePath())
        case .clock:        return AnyShape(ClockPath())
        case .musicNoteList: return AnyShape(MusicNoteListPath())
        case .chart:        return AnyShape(ChartPath())
        case .refresh:      return AnyShape(RefreshPath())
        case .translate:    return AnyShape(TranslatePath())
        case .karaoke:      return AnyShape(KaraokePath())
        case .lock:         return AnyShape(LockPath())
        case .unlock:       return AnyShape(UnlockPath())
        case .qr:           return AnyShape(QRPath())
        case .phone:        return AnyShape(PhonePath())
        case .send:         return AnyShape(SendPath())
        case .musicNote:    return AnyShape(MusicNotePath())
        case .fullscreen:   return AnyShape(FullscreenPath())
        case .sparkle:      return AnyShape(SparklePath())
        case .soundQuality: return AnyShape(SoundQualityPath())
        case .storage:      return AnyShape(StoragePath())
        case .haptic:       return AnyShape(HapticPath())
        case .info:         return AnyShape(InfoPath())
        case .save:         return AnyShape(SavePath())
        case .playerDownload: return AnyShape(PlayerDownloadPath())
        case .comment:        return AnyShape(CommentPath())
        case .history:      return AnyShape(HistoryPath())
        case .playCircle:   return AnyShape(PlayCirclePath())
        case .warning:      return AnyShape(WarningPath())
        case .personEmpty:  return AnyShape(PersonEmptyPath())
        case .playNext:     return AnyShape(PlayNextPath())
        case .add:          return AnyShape(AddPath())
        case .addToQueue:   return AnyShape(AddToQueuePath())
        case .radio:        return AnyShape(RadioPath())
        case .micSlash:     return AnyShape(MicSlashPath())
        case .waveform:     return AnyShape(WaveformPath())
        case .skipBack:     return AnyShape(SkipBackPath())
        case .skipForward:  return AnyShape(SkipForwardPath())
        case .rewind15:     return AnyShape(Rewind15Path())
        case .forward15:    return AnyShape(Forward15Path())
        case .xmarkCircle:  return AnyShape(XmarkCirclePath())
        case .playCircleFill: return AnyShape(PlayCirclePath())
        case .gridSquare:   return AnyShape(GridSquarePath())
        case .catMusic:     return AnyShape(CatMusicPath())
        case .catLife:      return AnyShape(CatLifePath())
        case .catEmotion:   return AnyShape(CatEmotionPath())
        case .catCreate:    return AnyShape(CatCreatePath())
        case .catAcg:       return AnyShape(CatAcgPath())
        case .catEntertain: return AnyShape(CatEntertainPath())
        case .catTalkshow:  return AnyShape(CatTalkshowPath())
        case .catBook:      return AnyShape(CatBookPath())
        case .catKnowledge: return AnyShape(CatKnowledgePath())
        case .catBusiness:  return AnyShape(CatBusinessPath())
        case .catHistory:   return AnyShape(CatHistoryPath())
        case .catNews:      return AnyShape(CatNewsPath())
        case .catParenting: return AnyShape(CatParentingPath())
        case .catTravel:    return AnyShape(CatTravelPath())
        case .catCrosstalk: return AnyShape(CatCrosstalkPath())
        case .catFood:      return AnyShape(CatFoodPath())
        case .catTech:      return AnyShape(CatTechPath())
        case .catDefault:   return AnyShape(CatDefaultPath())
        case .catPodcast:   return AnyShape(CatPodcastPath())
        case .catElectronic: return AnyShape(CatElectronicPath())
        case .catStar:      return AnyShape(CatStarPath())
        case .catDrama:     return AnyShape(CatDramaPath())
        case .catStory:     return AnyShape(CatStoryPath())
        case .catOther:     return AnyShape(CatOtherPath())
        case .catPublish:   return AnyShape(CatPublishPath())
        case .checkmark:    return AnyShape(CheckmarkPath())
        case .shrinkScreen: return AnyShape(ShrinkScreenPath())
        case .expandScreen: return AnyShape(ExpandScreenPath())
        case .headphones:   return AnyShape(HeadphonesPath())
        case .heartSlash:   return AnyShape(HeartSlashPath())
        case .personCircle: return AnyShape(PersonCirclePath())
        case .album:        return AnyShape(AlbumPath())
        case .infoCircle:   return AnyShape(InfoCirclePath())
        case .arrowDownCircle: return AnyShape(ArrowDownCirclePath())
        case .sun:          return AnyShape(SunPath())
        case .moon:         return AnyShape(MoonPath())
        case .halfCircle:   return AnyShape(HalfCirclePath())
        case .equalizer:    return AnyShape(EqualizerPath())
        case .immersive:    return AnyShape(ImmersivePath())
        case .playerTheme:  return AnyShape(PlayerThemePath())
        case .emoji:        return AnyShape(EmojiPath())
        case .share:        return AnyShape(ShareIconPath())
        case .logInfo:      return AnyShape(LogInfoPath())
        case .logDebug:     return AnyShape(LogDebugPath())
        case .logError:     return AnyShape(LogErrorPath())
        case .logNetwork:   return AnyShape(LogNetworkPath())
        case .logSuccess:   return AnyShape(LogSuccessPath())
        case .arrowDownToLine: return AnyShape(ArrowDownToLinePath())
        case .filter:       return AnyShape(FilterPath())
        case .microphone:   return AnyShape(MicrophonePath())
        case .fmMode:       return AnyShape(FMModePath())
        case .audioWave:    return AnyShape(AudioWavePath())
        case .layers:       return AnyShape(LayersPath())
        case .tabBar:       return AnyShape(TabBarPath())
        case .minimalBar:   return AnyShape(MinimalBarPath())
        case .floatingBall: return AnyShape(FloatingBallPath())
        }
    }
}


struct AnyShape: Shape, @unchecked Sendable {
    private let _path: @Sendable (CGRect) -> Path
    
    init<S: Shape>(_ shape: S) {
        _path = { rect in shape.path(in: rect) }
    }
    
    func path(in rect: CGRect) -> Path {
        _path(rect)
    }
}

// MARK: - Aura Paths

private struct HomePath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        path.move(to: CGPoint(x: 6*s, y: 13*s))
        path.addLine(to: CGPoint(x: 6*s, y: 17*s))
        path.addCurve(to: CGPoint(x: 9*s, y: 20*s), control1: CGPoint(x: 6*s, y: 18.6*s), control2: CGPoint(x: 7.4*s, y: 20*s))
        path.addLine(to: CGPoint(x: 15*s, y: 20*s))
        path.addCurve(to: CGPoint(x: 18*s, y: 17*s), control1: CGPoint(x: 16.6*s, y: 20*s), control2: CGPoint(x: 18*s, y: 18.6*s))
        path.addLine(to: CGPoint(x: 18*s, y: 13*s))
        path.move(to: CGPoint(x: 4*s, y: 11*s))
        path.addLine(to: CGPoint(x: 12*s, y: 4*s))
        path.addLine(to: CGPoint(x: 20*s, y: 11*s))
        
        return path
    }
}

private struct PodcastPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        let capsule = CGRect(x: 10*s, y: 7*s, width: 4*s, height: 8*s)
        path.addRoundedRect(in: capsule, cornerSize: CGSize(width: 2*s, height: 2*s))
        path.move(to: CGPoint(x: 6*s, y: 9*s))
        path.addCurve(to: CGPoint(x: 6*s, y: 15*s), control1: CGPoint(x: 5*s, y: 10.5*s), control2: CGPoint(x: 5*s, y: 13.5*s))
        
        path.move(to: CGPoint(x: 18*s, y: 9*s))
        path.addCurve(to: CGPoint(x: 18*s, y: 15*s), control1: CGPoint(x: 19*s, y: 10.5*s), control2: CGPoint(x: 19*s, y: 13.5*s))
        path.move(to: CGPoint(x: 12*s, y: 18*s))
        path.addLine(to: CGPoint(x: 12*s, y: 20*s))
        
        return path
    }
}

// 设计：唱片堆叠 + 音符元素，体现"音乐库"概念
private struct LibraryPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        // 底部唱片（圆角矩形，略微倾斜感）
        path.move(to: CGPoint(x: 5*s, y: 18*s))
        path.addLine(to: CGPoint(x: 5*s, y: 10*s))
        path.addCurve(to: CGPoint(x: 8*s, y: 7*s), control1: CGPoint(x: 5*s, y: 8.3*s), control2: CGPoint(x: 6.3*s, y: 7*s))
        path.addLine(to: CGPoint(x: 16*s, y: 7*s))
        path.addCurve(to: CGPoint(x: 19*s, y: 10*s), control1: CGPoint(x: 17.7*s, y: 7*s), control2: CGPoint(x: 19*s, y: 8.3*s))
        path.addLine(to: CGPoint(x: 19*s, y: 18*s))
        path.addCurve(to: CGPoint(x: 16*s, y: 21*s), control1: CGPoint(x: 19*s, y: 19.7*s), control2: CGPoint(x: 17.7*s, y: 21*s))
        path.addLine(to: CGPoint(x: 8*s, y: 21*s))
        path.addCurve(to: CGPoint(x: 5*s, y: 18*s), control1: CGPoint(x: 6.3*s, y: 21*s), control2: CGPoint(x: 5*s, y: 19.7*s))
        
        // 中间唱片层（浮动线条 - ghost element）
        path.move(to: CGPoint(x: 7*s, y: 5*s))
        path.addLine(to: CGPoint(x: 17*s, y: 5*s))
        
        // 顶部唱片层（浮动线条）
        path.move(to: CGPoint(x: 9*s, y: 3*s))
        path.addLine(to: CGPoint(x: 15*s, y: 3*s))
        
        // 唱片中心圆（音乐元素）
        path.addEllipse(in: CGRect(x: 10*s, y: 12*s, width: 4*s, height: 4*s))
        
        return path
    }
}

private struct SearchPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        path.addEllipse(in: CGRect(x: 4*s, y: 4*s, width: 12*s, height: 12*s))
        path.move(to: CGPoint(x: 15*s, y: 15*s))
        path.addLine(to: CGPoint(x: 19*s, y: 19*s))
        
        return path
    }
}

private struct ProfilePath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        path.addEllipse(in: CGRect(x: 8.5*s, y: 3.5*s, width: 7*s, height: 7*s))
        
        path.move(to: CGPoint(x: 5*s, y: 20*s))
        path.addCurve(to: CGPoint(x: 12*s, y: 14.5*s), control1: CGPoint(x: 5*s, y: 16.5*s), control2: CGPoint(x: 8*s, y: 14.5*s))
        path.addCurve(to: CGPoint(x: 19*s, y: 20*s), control1: CGPoint(x: 16*s, y: 14.5*s), control2: CGPoint(x: 19*s, y: 16.5*s))
        
        return path
    }
}

private struct BackPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        path.move(to: CGPoint(x: 15*s, y: 5*s))
        path.addLine(to: CGPoint(x: 8*s, y: 12*s))
        path.addLine(to: CGPoint(x: 15*s, y: 19*s))
        
        path.move(to: CGPoint(x: 4*s, y: 12*s))
        path.addLine(to: CGPoint(x: 6*s, y: 12*s))
        
        return path
    }
}

private struct MorePath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        let r = 1.2 * s
        
        path.addEllipse(in: CGRect(x: 12*s - r, y: 5*s - r, width: 2*r, height: 2*r))
        path.addEllipse(in: CGRect(x: 12*s - r, y: 12*s - r, width: 2*r, height: 2*r))
        path.addEllipse(in: CGRect(x: 12*s - r, y: 19*s - r, width: 2*r, height: 2*r))
        
        return path
    }
}

private struct ClosePath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        path.move(to: CGPoint(x: 7*s, y: 7*s)); path.addLine(to: CGPoint(x: 11*s, y: 11*s))
        path.move(to: CGPoint(x: 13*s, y: 13*s)); path.addLine(to: CGPoint(x: 17*s, y: 17*s))
        path.move(to: CGPoint(x: 17*s, y: 7*s)); path.addLine(to: CGPoint(x: 13*s, y: 11*s))
        path.move(to: CGPoint(x: 11*s, y: 13*s)); path.addLine(to: CGPoint(x: 7*s, y: 17*s))
        
        return path
    }
}

private struct PlayPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        path.move(to: CGPoint(x: 8*s, y: 5*s))
        path.addLine(to: CGPoint(x: 18*s, y: 12*s))
        path.addLine(to: CGPoint(x: 8*s, y: 19*s))

        path.move(to: CGPoint(x: 8*s, y: 8*s))
        path.addLine(to: CGPoint(x: 8*s, y: 16*s))
        
        return path
    }
}

private struct PausePath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        path.move(to: CGPoint(x: 8*s, y: 6*s)); path.addLine(to: CGPoint(x: 8*s, y: 18*s))
        path.move(to: CGPoint(x: 16*s, y: 6*s)); path.addLine(to: CGPoint(x: 16*s, y: 18*s))
        
        return path
    }
}

private struct NextPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        path.move(to: CGPoint(x: 6*s, y: 5*s))
        path.addLine(to: CGPoint(x: 14*s, y: 12*s))
        path.addLine(to: CGPoint(x: 6*s, y: 19*s))
        
        path.move(to: CGPoint(x: 18*s, y: 6*s))
        path.addLine(to: CGPoint(x: 18*s, y: 18*s))
        
        return path
    }
}

private struct PreviousPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        path.move(to: CGPoint(x: 18*s, y: 5*s))
        path.addLine(to: CGPoint(x: 10*s, y: 12*s))
        path.addLine(to: CGPoint(x: 18*s, y: 19*s))
        
        path.move(to: CGPoint(x: 6*s, y: 6*s))
        path.addLine(to: CGPoint(x: 6*s, y: 18*s))
        
        return path
    }
}

private struct StopPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        let box = CGRect(x: 6*s, y: 6*s, width: 12*s, height: 12*s)
        path.addRoundedRect(in: box, cornerSize: CGSize(width: 3*s, height: 3*s))
        
        return path
    }
}

private struct RepeatPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        path.move(to: CGPoint(x: 17*s, y: 14*s))
        path.addLine(to: CGPoint(x: 17*s, y: 17*s))
        path.addCurve(to: CGPoint(x: 14*s, y: 20*s), control1: CGPoint(x: 17*s, y: 18.5*s), control2: CGPoint(x: 15.5*s, y: 20*s))
        path.addLine(to: CGPoint(x: 6*s, y: 20*s))
        path.addCurve(to: CGPoint(x: 3*s, y: 17*s), control1: CGPoint(x: 4.5*s, y: 20*s), control2: CGPoint(x: 3*s, y: 18.5*s))
        path.addLine(to: CGPoint(x: 3*s, y: 12*s))
        
        path.move(to: CGPoint(x: 7*s, y: 10*s))
        path.addLine(to: CGPoint(x: 7*s, y: 7*s))
        path.addCurve(to: CGPoint(x: 10*s, y: 4*s), control1: CGPoint(x: 7*s, y: 5.5*s), control2: CGPoint(x: 8.5*s, y: 4*s))
        path.addLine(to: CGPoint(x: 18*s, y: 4*s))
        path.addCurve(to: CGPoint(x: 21*s, y: 7*s), control1: CGPoint(x: 19.5*s, y: 4*s), control2: CGPoint(x: 21*s, y: 5.5*s))
        path.addLine(to: CGPoint(x: 21*s, y: 12*s))
        
        path.move(to: CGPoint(x: 19*s, y: 10*s))
        path.addLine(to: CGPoint(x: 21*s, y: 12*s))
        path.addLine(to: CGPoint(x: 23*s, y: 10*s))
        
        return path
    }
}

private struct ShufflePath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        path.move(to: CGPoint(x: 4*s, y: 17*s))
        path.addLine(to: CGPoint(x: 7*s, y: 17*s))
        path.addCurve(to: CGPoint(x: 11*s, y: 14.5*s), control1: CGPoint(x: 9*s, y: 17*s), control2: CGPoint(x: 10*s, y: 16*s))
        
        path.move(to: CGPoint(x: 13*s, y: 11.5*s))
        path.addLine(to: CGPoint(x: 14.5*s, y: 9.5*s))
        path.addCurve(to: CGPoint(x: 19*s, y: 7*s), control1: CGPoint(x: 15.5*s, y: 8*s), control2: CGPoint(x: 17*s, y: 7*s))
        path.addLine(to: CGPoint(x: 21*s, y: 7*s))
        
        path.move(to: CGPoint(x: 4*s, y: 7*s))
        path.addLine(to: CGPoint(x: 7*s, y: 7*s))
        path.addCurve(to: CGPoint(x: 11*s, y: 9.5*s), control1: CGPoint(x: 9*s, y: 7*s), control2: CGPoint(x: 10*s, y: 8*s))
        path.addLine(to: CGPoint(x: 15*s, y: 15.5*s))
        path.addCurve(to: CGPoint(x: 21*s, y: 18*s), control1: CGPoint(x: 16*s, y: 17*s), control2: CGPoint(x: 17.5*s, y: 18*s))
        
        path.move(to: CGPoint(x: 18*s, y: 4*s)); path.addLine(to: CGPoint(x: 21*s, y: 7*s)); path.addLine(to: CGPoint(x: 18*s, y: 10*s))
        path.move(to: CGPoint(x: 18*s, y: 15*s)); path.addLine(to: CGPoint(x: 21*s, y: 18*s)); path.addLine(to: CGPoint(x: 18*s, y: 21*s))
        
        return path
    }
}

private struct RefreshPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        path.move(to: CGPoint(x: 19*s, y: 10*s))
        path.addCurve(to: CGPoint(x: 12*s, y: 5*s), control1: CGPoint(x: 18*s, y: 7*s), control2: CGPoint(x: 15.5*s, y: 5*s))
        path.addCurve(to: CGPoint(x: 4*s, y: 13*s), control1: CGPoint(x: 7.5*s, y: 5*s), control2: CGPoint(x: 4*s, y: 8.5*s))
        path.addCurve(to: CGPoint(x: 12*s, y: 21*s), control1: CGPoint(x: 4*s, y: 17.5*s), control2: CGPoint(x: 7.5*s, y: 21*s))
        path.addCurve(to: CGPoint(x: 20*s, y: 13*s), control1: CGPoint(x: 16.5*s, y: 21*s), control2: CGPoint(x: 20*s, y: 17.5*s))
        
        path.move(to: CGPoint(x: 17*s, y: 8*s))
        path.addLine(to: CGPoint(x: 19*s, y: 10*s))
        path.addLine(to: CGPoint(x: 21*s, y: 8*s))
        
        return path
    }
}

private struct LikePath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        path.move(to: CGPoint(x: 12*s, y: 19*s))
        path.addLine(to: CGPoint(x: 10.5*s, y: 17.5*s))
        path.addCurve(to: CGPoint(x: 2*s, y: 6*s), control1: CGPoint(x: 5.5*s, y: 13*s), control2: CGPoint(x: 2*s, y: 10*s))
        path.addCurve(to: CGPoint(x: 7.5*s, y: 0.5*s), control1: CGPoint(x: 2*s, y: 3*s), control2: CGPoint(x: 4.5*s, y: 0.5*s))
        path.addCurve(to: CGPoint(x: 12*s, y: 2.5*s), control1: CGPoint(x: 9.2*s, y: 0.5*s), control2: CGPoint(x: 10.8*s, y: 1.3*s))
        path.addCurve(to: CGPoint(x: 16.5*s, y: 0.5*s), control1: CGPoint(x: 13.2*s, y: 1.3*s), control2: CGPoint(x: 14.8*s, y: 0.5*s))
        path.addCurve(to: CGPoint(x: 22*s, y: 6*s), control1: CGPoint(x: 19.5*s, y: 0.5*s), control2: CGPoint(x: 22*s, y: 3*s))
        path.addCurve(to: CGPoint(x: 19*s, y: 12.5*s), control1: CGPoint(x: 22*s, y: 8*s), control2: CGPoint(x: 21*s, y: 10*s))
        
        return path
    }
}

private struct LikedPath: Shape {
    func path(in rect: CGRect) -> Path {
        let path = Path()
        return path
    }
}

private struct FMPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        let box = CGRect(x: 4*s, y: 9*s, width: 16*s, height: 11*s)
        path.addRoundedRect(in: box, cornerSize: CGSize(width: 3*s, height: 3*s))
        
        path.addEllipse(in: CGRect(x: 6*s, y: 12.5*s, width: 4*s, height: 4*s))
        
        path.move(to: CGPoint(x: 13*s, y: 14.5*s))
        path.addLine(to: CGPoint(x: 17*s, y: 14.5*s))
        
        path.move(to: CGPoint(x: 16*s, y: 9*s))
        path.addLine(to: CGPoint(x: 19*s, y: 4*s))
        
        return path
    }
}

private struct BellPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        path.move(to: CGPoint(x: 18*s, y: 13*s))
        path.addCurve(to: CGPoint(x: 12*s, y: 7*s), control1: CGPoint(x: 18*s, y: 9.7*s), control2: CGPoint(x: 15.3*s, y: 7*s))
        path.addCurve(to: CGPoint(x: 6*s, y: 13*s), control1: CGPoint(x: 8.7*s, y: 7*s), control2: CGPoint(x: 6*s, y: 9.7*s))
        path.addLine(to: CGPoint(x: 6*s, y: 17*s))
        path.addLine(to: CGPoint(x: 18*s, y: 17*s))
        path.addLine(to: CGPoint(x: 18*s, y: 13*s))
        path.closeSubpath()
        
        path.move(to: CGPoint(x: 10*s, y: 20*s))
        path.addCurve(to: CGPoint(x: 15*s, y: 20*s), control1: CGPoint(x: 10.5*s, y: 21*s), control2: CGPoint(x: 14.5*s, y: 21*s))
        
        return path
    }
}

private struct TrashPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        path.move(to: CGPoint(x: 6*s, y: 10*s))
        path.addLine(to: CGPoint(x: 6*s, y: 18*s))
        path.addCurve(to: CGPoint(x: 8.5*s, y: 20.5*s), control1: CGPoint(x: 6*s, y: 19.5*s), control2: CGPoint(x: 7*s, y: 20.5*s))
        path.addLine(to: CGPoint(x: 15.5*s, y: 20.5*s))
        path.addCurve(to: CGPoint(x: 18*s, y: 18*s), control1: CGPoint(x: 17*s, y: 20.5*s), control2: CGPoint(x: 18*s, y: 19.5*s))
        path.addLine(to: CGPoint(x: 18*s, y: 10*s))
        
        path.move(to: CGPoint(x: 4*s, y: 7*s)); path.addLine(to: CGPoint(x: 20*s, y: 7*s))
        path.move(to: CGPoint(x: 10*s, y: 7*s)); path.addLine(to: CGPoint(x: 10*s, y: 4*s)); path.addLine(to: CGPoint(x: 14*s, y: 4*s)); path.addLine(to: CGPoint(x: 14*s, y: 7*s))
        
        return path
    }
}

private struct ListPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        path.move(to: CGPoint(x: 8*s, y: 7*s)); path.addLine(to: CGPoint(x: 20*s, y: 7*s))
        path.move(to: CGPoint(x: 8*s, y: 12*s)); path.addLine(to: CGPoint(x: 17*s, y: 12*s))
        path.move(to: CGPoint(x: 8*s, y: 17*s)); path.addLine(to: CGPoint(x: 20*s, y: 17*s))
        
        path.move(to: CGPoint(x: 4*s, y: 7*s)); path.addLine(to: CGPoint(x: 5*s, y: 7*s))
        path.move(to: CGPoint(x: 4*s, y: 12*s)); path.addLine(to: CGPoint(x: 5*s, y: 12*s))
        path.move(to: CGPoint(x: 4*s, y: 17*s)); path.addLine(to: CGPoint(x: 5*s, y: 17*s))
        
        return path
    }
}

private struct SettingsPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        path.addEllipse(in: CGRect(x: 9*s, y: 9*s, width: 6*s, height: 6*s))
        
        path.move(to: CGPoint(x: 12*s, y: 3*s)); path.addLine(to: CGPoint(x: 12*s, y: 5*s))
        path.move(to: CGPoint(x: 12*s, y: 19*s)); path.addLine(to: CGPoint(x: 12*s, y: 21*s))
        path.move(to: CGPoint(x: 3*s, y: 12*s)); path.addLine(to: CGPoint(x: 5*s, y: 12*s))
        path.move(to: CGPoint(x: 19*s, y: 12*s)); path.addLine(to: CGPoint(x: 21*s, y: 12*s))
        
        path.move(to: CGPoint(x: 5.6*s, y: 5.6*s)); path.addLine(to: CGPoint(x: 7*s, y: 7*s))
        path.move(to: CGPoint(x: 17*s, y: 17*s)); path.addLine(to: CGPoint(x: 18.4*s, y: 18.4*s))
        
        return path
    }
}

private struct DownloadPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        path.move(to: CGPoint(x: 12*s, y: 4*s)); path.addLine(to: CGPoint(x: 12*s, y: 13*s))
        path.move(to: CGPoint(x: 12*s, y: 13*s)); path.addLine(to: CGPoint(x: 8*s, y: 9*s))
        path.move(to: CGPoint(x: 12*s, y: 13*s)); path.addLine(to: CGPoint(x: 16*s, y: 9*s))
        
        path.move(to: CGPoint(x: 5*s, y: 17*s))
        path.addCurve(to: CGPoint(x: 8*s, y: 20*s), control1: CGPoint(x: 5*s, y: 18.7*s), control2: CGPoint(x: 6.3*s, y: 20*s))
        path.addLine(to: CGPoint(x: 16*s, y: 20*s))
        path.addCurve(to: CGPoint(x: 19*s, y: 17*s), control1: CGPoint(x: 17.7*s, y: 20*s), control2: CGPoint(x: 19*s, y: 18.7*s))
        
        return path
    }
}

// 播放器专用下载图标：向下箭头 + 底部托盘，纯线条无背景无圆圈
private struct PlayerDownloadPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        // 向下箭头竖线
        path.move(to: CGPoint(x: 12*s, y: 4*s))
        path.addLine(to: CGPoint(x: 12*s, y: 14*s))
        
        // 箭头两翼
        path.move(to: CGPoint(x: 8*s, y: 11*s))
        path.addLine(to: CGPoint(x: 12*s, y: 15*s))
        path.addLine(to: CGPoint(x: 16*s, y: 11*s))
        
        // 底部托盘（U 形）
        path.move(to: CGPoint(x: 5*s, y: 15*s))
        path.addLine(to: CGPoint(x: 5*s, y: 18*s))
        path.addCurve(to: CGPoint(x: 8*s, y: 21*s), control1: CGPoint(x: 5*s, y: 19.7*s), control2: CGPoint(x: 6.3*s, y: 21*s))
        path.addLine(to: CGPoint(x: 16*s, y: 21*s))
        path.addCurve(to: CGPoint(x: 19*s, y: 18*s), control1: CGPoint(x: 17.7*s, y: 21*s), control2: CGPoint(x: 19*s, y: 19.7*s))
        path.addLine(to: CGPoint(x: 19*s, y: 15*s))
        
        return path
    }
}

// 评论图标：气泡 + 三条横线
private struct CommentPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        // 气泡外框
        path.move(to: CGPoint(x: 12*s, y: 21*s))
        path.addLine(to: CGPoint(x: 8*s, y: 17*s))
        path.addLine(to: CGPoint(x: 6*s, y: 17*s))
        path.addCurve(to: CGPoint(x: 3*s, y: 14*s), control1: CGPoint(x: 4.3*s, y: 17*s), control2: CGPoint(x: 3*s, y: 15.7*s))
        path.addLine(to: CGPoint(x: 3*s, y: 7*s))
        path.addCurve(to: CGPoint(x: 6*s, y: 4*s), control1: CGPoint(x: 3*s, y: 5.3*s), control2: CGPoint(x: 4.3*s, y: 4*s))
        path.addLine(to: CGPoint(x: 18*s, y: 4*s))
        path.addCurve(to: CGPoint(x: 21*s, y: 7*s), control1: CGPoint(x: 19.7*s, y: 4*s), control2: CGPoint(x: 21*s, y: 5.3*s))
        path.addLine(to: CGPoint(x: 21*s, y: 14*s))
        path.addCurve(to: CGPoint(x: 18*s, y: 17*s), control1: CGPoint(x: 21*s, y: 15.7*s), control2: CGPoint(x: 19.7*s, y: 17*s))
        path.addLine(to: CGPoint(x: 16*s, y: 17*s))
        path.closeSubpath()
        
        // 三条横线
        path.move(to: CGPoint(x: 8*s, y: 8*s))
        path.addLine(to: CGPoint(x: 16*s, y: 8*s))
        path.move(to: CGPoint(x: 8*s, y: 11*s))
        path.addLine(to: CGPoint(x: 16*s, y: 11*s))
        path.move(to: CGPoint(x: 8*s, y: 14*s))
        path.addLine(to: CGPoint(x: 13*s, y: 14*s))
        
        return path
    }
}

private struct KaraokePath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        let box = CGRect(x: 9*s, y: 4*s, width: 6*s, height: 9*s)
        path.addRoundedRect(in: box, cornerSize: CGSize(width: 3*s, height: 3*s))
        
        path.move(to: CGPoint(x: 6*s, y: 10*s))
        path.addCurve(to: CGPoint(x: 12*s, y: 16*s), control1: CGPoint(x: 6*s, y: 13.3*s), control2: CGPoint(x: 8.7*s, y: 16*s))
        path.addCurve(to: CGPoint(x: 18*s, y: 10*s), control1: CGPoint(x: 15.3*s, y: 16*s), control2: CGPoint(x: 18*s, y: 13.3*s))
        
        path.move(to: CGPoint(x: 12*s, y: 16*s)); path.addLine(to: CGPoint(x: 12*s, y: 20*s))
        path.move(to: CGPoint(x: 9*s, y: 20*s)); path.addLine(to: CGPoint(x: 15*s, y: 20*s))
        
        return path
    }
}

private struct CloudPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        path.move(to: CGPoint(x: 7*s, y: 19*s))
        path.addCurve(to: CGPoint(x: 4*s, y: 16*s), control1: CGPoint(x: 5.3*s, y: 19*s), control2: CGPoint(x: 4*s, y: 17.7*s))
        path.addCurve(to: CGPoint(x: 7*s, y: 13*s), control1: CGPoint(x: 4*s, y: 14.3*s), control2: CGPoint(x: 5.3*s, y: 13*s))
        path.addCurve(to: CGPoint(x: 12*s, y: 8*s), control1: CGPoint(x: 7*s, y: 10.2*s), control2: CGPoint(x: 9.2*s, y: 8*s))
        path.addCurve(to: CGPoint(x: 17*s, y: 13*s), control1: CGPoint(x: 14.8*s, y: 8*s), control2: CGPoint(x: 17*s, y: 10.2*s))
        
        path.move(to: CGPoint(x: 19*s, y: 13*s))
        path.addCurve(to: CGPoint(x: 22*s, y: 16*s), control1: CGPoint(x: 20.7*s, y: 13*s), control2: CGPoint(x: 22*s, y: 14.3*s))
        path.addCurve(to: CGPoint(x: 19*s, y: 19*s), control1: CGPoint(x: 22*s, y: 17.7*s), control2: CGPoint(x: 20.7*s, y: 19*s))
        path.addLine(to: CGPoint(x: 14*s, y: 19*s))
        
        return path
    }
}

private struct ClockPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        path.addEllipse(in: CGRect(x: 4*s, y: 4*s, width: 16*s, height: 16*s))
        
        path.move(to: CGPoint(x: 12*s, y: 8*s))
        path.addLine(to: CGPoint(x: 12*s, y: 12*s))
        path.addLine(to: CGPoint(x: 15*s, y: 14*s))
        
        return path
    }
}

private struct ChartPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        path.move(to: CGPoint(x: 5*s, y: 18*s)); path.addLine(to: CGPoint(x: 5*s, y: 14*s))
        path.move(to: CGPoint(x: 11*s, y: 18*s)); path.addLine(to: CGPoint(x: 11*s, y: 7*s))
        path.move(to: CGPoint(x: 17*s, y: 18*s)); path.addLine(to: CGPoint(x: 17*s, y: 11*s))
        
        path.move(to: CGPoint(x: 4*s, y: 21*s)); path.addLine(to: CGPoint(x: 20*s, y: 21*s))
        
        return path
    }
}

private struct LockPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        let box = CGRect(x: 6*s, y: 11*s, width: 12*s, height: 9*s)
        path.addRoundedRect(in: box, cornerSize: CGSize(width: 3*s, height: 3*s))
        
        path.move(to: CGPoint(x: 9*s, y: 11*s))
        path.addLine(to: CGPoint(x: 9*s, y: 7*s))
        path.addCurve(to: CGPoint(x: 12*s, y: 4*s), control1: CGPoint(x: 9*s, y: 5.3*s), control2: CGPoint(x: 10.3*s, y: 4*s))
        path.addCurve(to: CGPoint(x: 15*s, y: 7*s), control1: CGPoint(x: 13.7*s, y: 4*s), control2: CGPoint(x: 15*s, y: 5.3*s))
        path.addLine(to: CGPoint(x: 15*s, y: 11*s))
        
        return path
    }
}

private struct UnlockPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        // 锁体
        let box = CGRect(x: 6*s, y: 11*s, width: 12*s, height: 9*s)
        path.addRoundedRect(in: box, cornerSize: CGSize(width: 3*s, height: 3*s))
        
        // 开着的锁扣（右侧打开）
        path.move(to: CGPoint(x: 9*s, y: 11*s))
        path.addLine(to: CGPoint(x: 9*s, y: 7*s))
        path.addCurve(to: CGPoint(x: 12*s, y: 4*s), control1: CGPoint(x: 9*s, y: 5.3*s), control2: CGPoint(x: 10.3*s, y: 4*s))
        path.addCurve(to: CGPoint(x: 15*s, y: 7*s), control1: CGPoint(x: 13.7*s, y: 4*s), control2: CGPoint(x: 15*s, y: 5.3*s))
        // 锁扣打开，不连接到锁体
        
        return path
    }
}

private struct QRPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        path.move(to: CGPoint(x: 5*s, y: 9*s)); path.addLine(to: CGPoint(x: 5*s, y: 5*s)); path.addLine(to: CGPoint(x: 9*s, y: 5*s))
        path.move(to: CGPoint(x: 15*s, y: 5*s)); path.addLine(to: CGPoint(x: 19*s, y: 5*s)); path.addLine(to: CGPoint(x: 19*s, y: 9*s))
        path.move(to: CGPoint(x: 19*s, y: 15*s)); path.addLine(to: CGPoint(x: 19*s, y: 19*s)); path.addLine(to: CGPoint(x: 15*s, y: 19*s))
        path.move(to: CGPoint(x: 9*s, y: 19*s)); path.addLine(to: CGPoint(x: 5*s, y: 19*s)); path.addLine(to: CGPoint(x: 5*s, y: 15*s))
        
        let box = CGRect(x: 9*s, y: 9*s, width: 6*s, height: 6*s)
        path.addRoundedRect(in: box, cornerSize: CGSize(width: 1*s, height: 1*s))
        
        return path
    }
}

private struct PhonePath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        path.move(to: CGPoint(x: 18*s, y: 15*s))
        path.addLine(to: CGPoint(x: 15*s, y: 12.5*s))
        path.addLine(to: CGPoint(x: 13*s, y: 14.5*s))
        path.addCurve(to: CGPoint(x: 9*s, y: 10.5*s), control1: CGPoint(x: 11*s, y: 13.5*s), control2: CGPoint(x: 10*s, y: 12.5*s))
        path.addLine(to: CGPoint(x: 11*s, y: 8.5*s))
        path.addLine(to: CGPoint(x: 8.5*s, y: 5.5*s))
        path.addLine(to: CGPoint(x: 5.5*s, y: 8.5*s))
        path.addCurve(to: CGPoint(x: 15.5*s, y: 18.5*s), control1: CGPoint(x: 5.5*s, y: 14.5*s), control2: CGPoint(x: 9.5*s, y: 18.5*s))
        path.addLine(to: CGPoint(x: 18*s, y: 15*s))
        path.closeSubpath()
        
        return path
    }
}

private struct SendPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        path.move(to: CGPoint(x: 21*s, y: 3*s)); path.addLine(to: CGPoint(x: 10*s, y: 14*s))
        path.move(to: CGPoint(x: 21*s, y: 3*s)); path.addLine(to: CGPoint(x: 3*s, y: 10*s)); path.addLine(to: CGPoint(x: 10*s, y: 14*s))
        path.move(to: CGPoint(x: 21*s, y: 3*s)); path.addLine(to: CGPoint(x: 14*s, y: 21*s)); path.addLine(to: CGPoint(x: 10*s, y: 14*s))
        
        return path
    }
}

private struct MusicNotePath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        path.addEllipse(in: CGRect(x: 5*s, y: 14*s, width: 6*s, height: 6*s))
        
        path.move(to: CGPoint(x: 11*s, y: 17*s))
        path.addLine(to: CGPoint(x: 11*s, y: 5*s))
        path.addLine(to: CGPoint(x: 19*s, y: 8*s))
        
        return path
    }
}

private struct MusicNoteListPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        path.move(to: CGPoint(x: 8*s, y: 6*s)); path.addLine(to: CGPoint(x: 8*s, y: 15*s))
        path.addEllipse(in: CGRect(x: 2.5*s, y: 12.5*s, width: 5*s, height: 5*s))
        
        path.move(to: CGPoint(x: 13*s, y: 7*s)); path.addLine(to: CGPoint(x: 20*s, y: 7*s))
        path.move(to: CGPoint(x: 13*s, y: 12*s)); path.addLine(to: CGPoint(x: 19*s, y: 12*s))
        path.move(to: CGPoint(x: 13*s, y: 17*s)); path.addLine(to: CGPoint(x: 20*s, y: 17*s))
        
        return path
    }
}

private struct TranslatePath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        // 文
        path.move(to: CGPoint(x: 4*s, y: 7*s)); path.addLine(to: CGPoint(x: 14*s, y: 7*s))
        path.move(to: CGPoint(x: 9*s, y: 4*s)); path.addLine(to: CGPoint(x: 9*s, y: 7*s))
        path.move(to: CGPoint(x: 12*s, y: 11*s))
        path.addCurve(to: CGPoint(x: 9*s, y: 7*s), control1: CGPoint(x: 11*s, y: 9*s), control2: CGPoint(x: 9*s, y: 7*s))
        path.move(to: CGPoint(x: 9*s, y: 7*s))
        path.addCurve(to: CGPoint(x: 6*s, y: 11*s), control1: CGPoint(x: 7*s, y: 9*s), control2: CGPoint(x: 6*s, y: 11*s))
        
        // A
        path.move(to: CGPoint(x: 14*s, y: 19*s)); path.addLine(to: CGPoint(x: 17*s, y: 12*s)); path.addLine(to: CGPoint(x: 20*s, y: 19*s))
        path.move(to: CGPoint(x: 15.5*s, y: 16*s)); path.addLine(to: CGPoint(x: 18.5*s, y: 16*s))
        
        return path
    }
}

private struct RepeatOnePath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        path.move(to: CGPoint(x: 17*s, y: 14*s))
        path.addLine(to: CGPoint(x: 17*s, y: 17*s))
        path.addCurve(to: CGPoint(x: 14*s, y: 20*s), control1: CGPoint(x: 17*s, y: 18.5*s), control2: CGPoint(x: 15.5*s, y: 20*s))
        path.addLine(to: CGPoint(x: 6*s, y: 20*s))
        path.addCurve(to: CGPoint(x: 3*s, y: 17*s), control1: CGPoint(x: 4.5*s, y: 20*s), control2: CGPoint(x: 3*s, y: 18.5*s))
        path.addLine(to: CGPoint(x: 3*s, y: 12*s))
        
        path.move(to: CGPoint(x: 7*s, y: 10*s))
        path.addLine(to: CGPoint(x: 7*s, y: 7*s))
        path.addCurve(to: CGPoint(x: 10*s, y: 4*s), control1: CGPoint(x: 7*s, y: 5.5*s), control2: CGPoint(x: 8.5*s, y: 4*s))
        path.addLine(to: CGPoint(x: 18*s, y: 4*s))
        path.addCurve(to: CGPoint(x: 21*s, y: 7*s), control1: CGPoint(x: 19.5*s, y: 4*s), control2: CGPoint(x: 21*s, y: 5.5*s))
        path.addLine(to: CGPoint(x: 21*s, y: 12*s))
        
        path.move(to: CGPoint(x: 19*s, y: 10*s))
        path.addLine(to: CGPoint(x: 21*s, y: 12*s))
        path.addLine(to: CGPoint(x: 23*s, y: 10*s))
        
        path.move(to: CGPoint(x: 11*s, y: 10*s))
        path.addLine(to: CGPoint(x: 13*s, y: 9*s))
        path.addLine(to: CGPoint(x: 13*s, y: 15*s))
        
        path.move(to: CGPoint(x: 11*s, y: 15*s))
        path.addLine(to: CGPoint(x: 15*s, y: 15*s))
        
        return path
    }
}

private struct ChevronRightPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        path.move(to: CGPoint(x: 10*s, y: 8*s))
        path.addLine(to: CGPoint(x: 14*s, y: 12*s))
        path.addLine(to: CGPoint(x: 10*s, y: 16*s))
        
        return path
    }
}

private struct ChevronLeftPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        path.move(to: CGPoint(x: 14*s, y: 8*s))
        path.addLine(to: CGPoint(x: 10*s, y: 12*s))
        path.addLine(to: CGPoint(x: 14*s, y: 16*s))
        
        return path
    }
}

private struct MagnifyingGlassPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        path.addEllipse(in: CGRect(x: 4*s, y: 4*s, width: 12*s, height: 12*s))
        path.move(to: CGPoint(x: 14.5*s, y: 14.5*s))
        path.addLine(to: CGPoint(x: 19*s, y: 19*s))
        
        return path
    }
}

private struct XmarkPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        path.move(to: CGPoint(x: 8*s, y: 8*s)); path.addLine(to: CGPoint(x: 16*s, y: 16*s))
        path.move(to: CGPoint(x: 16*s, y: 8*s)); path.addLine(to: CGPoint(x: 8*s, y: 16*s))
        
        return path
    }
}

private struct FullscreenPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        path.move(to: CGPoint(x: 4*s, y: 9*s)); path.addLine(to: CGPoint(x: 4*s, y: 4*s)); path.addLine(to: CGPoint(x: 9*s, y: 4*s))
        path.move(to: CGPoint(x: 15*s, y: 4*s)); path.addLine(to: CGPoint(x: 20*s, y: 4*s)); path.addLine(to: CGPoint(x: 20*s, y: 9*s))
        path.move(to: CGPoint(x: 20*s, y: 15*s)); path.addLine(to: CGPoint(x: 20*s, y: 20*s)); path.addLine(to: CGPoint(x: 15*s, y: 20*s))
        path.move(to: CGPoint(x: 9*s, y: 20*s)); path.addLine(to: CGPoint(x: 4*s, y: 20*s)); path.addLine(to: CGPoint(x: 4*s, y: 15*s))
        
        return path
    }
}

// 液态玻璃效果图标
private struct SparklePath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        // 主星芒
        path.move(to: CGPoint(x: 12*s, y: 3*s))
        path.addLine(to: CGPoint(x: 13.5*s, y: 9*s))
        path.addLine(to: CGPoint(x: 19*s, y: 8*s))
        path.addLine(to: CGPoint(x: 14.5*s, y: 12*s))
        path.addLine(to: CGPoint(x: 18*s, y: 17*s))
        path.addLine(to: CGPoint(x: 12*s, y: 14*s))
        path.addLine(to: CGPoint(x: 6*s, y: 17*s))
        path.addLine(to: CGPoint(x: 9.5*s, y: 12*s))
        path.addLine(to: CGPoint(x: 5*s, y: 8*s))
        path.addLine(to: CGPoint(x: 10.5*s, y: 9*s))
        path.closeSubpath()
        
        // 小星点 (浮动元素)
        path.addEllipse(in: CGRect(x: 17*s, y: 3*s, width: 2.5*s, height: 2.5*s))
        path.addEllipse(in: CGRect(x: 4*s, y: 18*s, width: 2*s, height: 2*s))
        
        return path
    }
}

// 音质图标
private struct SoundQualityPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        // 扬声器主体
        path.move(to: CGPoint(x: 5*s, y: 9*s))
        path.addLine(to: CGPoint(x: 8*s, y: 9*s))
        path.addLine(to: CGPoint(x: 12*s, y: 5*s))
        path.addLine(to: CGPoint(x: 12*s, y: 19*s))
        path.addLine(to: CGPoint(x: 8*s, y: 15*s))
        path.addLine(to: CGPoint(x: 5*s, y: 15*s))
        path.closeSubpath()
        
        // 声波 (浮动弧线)
        path.move(to: CGPoint(x: 15*s, y: 9*s))
        path.addQuadCurve(to: CGPoint(x: 15*s, y: 15*s), control: CGPoint(x: 18*s, y: 12*s))
        
        path.move(to: CGPoint(x: 17*s, y: 6*s))
        path.addQuadCurve(to: CGPoint(x: 17*s, y: 18*s), control: CGPoint(x: 22*s, y: 12*s))
        
        return path
    }
}

// 存储图标
private struct StoragePath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        // 硬盘主体
        path.addRoundedRect(in: CGRect(x: 4*s, y: 6*s, width: 16*s, height: 12*s), cornerSize: CGSize(width: 2*s, height: 2*s))
        
        // 分隔线
        path.move(to: CGPoint(x: 4*s, y: 12*s))
        path.addLine(to: CGPoint(x: 20*s, y: 12*s))
        
        // 指示灯 (浮动元素)
        path.addEllipse(in: CGRect(x: 16*s, y: 8*s, width: 2*s, height: 2*s))
        path.addEllipse(in: CGRect(x: 16*s, y: 14*s, width: 2*s, height: 2*s))
        
        return path
    }
}

// 触感反馈图标
private struct HapticPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        // 手机轮廓
        path.addRoundedRect(in: CGRect(x: 7*s, y: 3*s, width: 10*s, height: 18*s), cornerSize: CGSize(width: 2*s, height: 2*s))
        
        // 震动波纹 (左侧)
        path.move(to: CGPoint(x: 5*s, y: 9*s))
        path.addLine(to: CGPoint(x: 3*s, y: 12*s))
        path.addLine(to: CGPoint(x: 5*s, y: 15*s))
        
        // 震动波纹 (右侧)
        path.move(to: CGPoint(x: 19*s, y: 9*s))
        path.addLine(to: CGPoint(x: 21*s, y: 12*s))
        path.addLine(to: CGPoint(x: 19*s, y: 15*s))
        
        return path
    }
}

// 信息图标
private struct InfoPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        // 圆形背景
        path.addEllipse(in: CGRect(x: 4*s, y: 4*s, width: 16*s, height: 16*s))
        
        // i 的点 (浮动)
        path.addEllipse(in: CGRect(x: 11*s, y: 7*s, width: 2*s, height: 2*s))
        
        // i 的竖线
        path.move(to: CGPoint(x: 12*s, y: 11*s))
        path.addLine(to: CGPoint(x: 12*s, y: 16*s))
        
        return path
    }
}


// 保存图标 - 设计：向下箭头 + 托盘，体现"保存/存储"概念
private struct SavePath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        // 向下箭头主体
        path.move(to: CGPoint(x: 12*s, y: 4*s))
        path.addLine(to: CGPoint(x: 12*s, y: 14*s))
        
        // 箭头头部
        path.move(to: CGPoint(x: 8*s, y: 10*s))
        path.addLine(to: CGPoint(x: 12*s, y: 14*s))
        path.addLine(to: CGPoint(x: 16*s, y: 10*s))
        
        // 托盘/容器 (浮动元素风格)
        path.move(to: CGPoint(x: 5*s, y: 14*s))
        path.addLine(to: CGPoint(x: 5*s, y: 17*s))
        path.addCurve(to: CGPoint(x: 8*s, y: 20*s), control1: CGPoint(x: 5*s, y: 18.7*s), control2: CGPoint(x: 6.3*s, y: 20*s))
        path.addLine(to: CGPoint(x: 16*s, y: 20*s))
        path.addCurve(to: CGPoint(x: 19*s, y: 17*s), control1: CGPoint(x: 17.7*s, y: 20*s), control2: CGPoint(x: 19*s, y: 18.7*s))
        path.addLine(to: CGPoint(x: 19*s, y: 14*s))
        
        return path
    }
}

// 历史记录 - 时钟 + 逆时针箭头
private struct HistoryPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        // 时钟圆形（不完整，留出箭头空间）
        path.addArc(center: CGPoint(x: 12*s, y: 12*s), radius: 7*s, startAngle: .degrees(-60), endAngle: .degrees(240), clockwise: false)
        
        // 逆时针箭头
        path.move(to: CGPoint(x: 5*s, y: 6*s))
        path.addLine(to: CGPoint(x: 8.5*s, y: 6*s))
        path.move(to: CGPoint(x: 5*s, y: 6*s))
        path.addLine(to: CGPoint(x: 5*s, y: 9.5*s))
        
        // 时钟指针
        path.move(to: CGPoint(x: 12*s, y: 12*s))
        path.addLine(to: CGPoint(x: 12*s, y: 9*s))
        path.move(to: CGPoint(x: 12*s, y: 12*s))
        path.addLine(to: CGPoint(x: 15*s, y: 12*s))
        
        return path
    }
}

// 圆形播放按钮
private struct PlayCirclePath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        // 外圆
        path.addEllipse(in: CGRect(x: 3*s, y: 3*s, width: 18*s, height: 18*s))
        
        // 播放三角形
        path.move(to: CGPoint(x: 10*s, y: 8*s))
        path.addLine(to: CGPoint(x: 16*s, y: 12*s))
        path.addLine(to: CGPoint(x: 10*s, y: 16*s))
        path.closeSubpath()
        
        return path
    }
}

// 警告/错误 - 三角形 + 感叹号
private struct WarningPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        // 三角形外框
        path.move(to: CGPoint(x: 12*s, y: 3*s))
        path.addLine(to: CGPoint(x: 21*s, y: 19*s))
        path.addCurve(to: CGPoint(x: 19*s, y: 21*s), control1: CGPoint(x: 21.5*s, y: 20*s), control2: CGPoint(x: 20.5*s, y: 21*s))
        path.addLine(to: CGPoint(x: 5*s, y: 21*s))
        path.addCurve(to: CGPoint(x: 3*s, y: 19*s), control1: CGPoint(x: 3.5*s, y: 21*s), control2: CGPoint(x: 2.5*s, y: 20*s))
        path.addLine(to: CGPoint(x: 12*s, y: 3*s))
        
        // 感叹号竖线
        path.move(to: CGPoint(x: 12*s, y: 9*s))
        path.addLine(to: CGPoint(x: 12*s, y: 14*s))
        
        // 感叹号点（浮动元素）
        path.addEllipse(in: CGRect(x: 11*s, y: 16.5*s, width: 2*s, height: 2*s))
        
        return path
    }
}

// 空用户状态 - 人形 + 斜线
private struct PersonEmptyPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        // 头部
        path.addEllipse(in: CGRect(x: 8.5*s, y: 3*s, width: 7*s, height: 7*s))
        
        // 身体
        path.move(to: CGPoint(x: 5*s, y: 20*s))
        path.addCurve(to: CGPoint(x: 12*s, y: 14*s), control1: CGPoint(x: 5*s, y: 16.5*s), control2: CGPoint(x: 8*s, y: 14*s))
        path.addCurve(to: CGPoint(x: 19*s, y: 20*s), control1: CGPoint(x: 16*s, y: 14*s), control2: CGPoint(x: 19*s, y: 16.5*s))
        
        // 斜线（表示空/无）
        path.move(to: CGPoint(x: 4*s, y: 4*s))
        path.addLine(to: CGPoint(x: 20*s, y: 20*s))
        
        return path
    }
}

// 下一首播放 - 播放三角 + 向前箭头
private struct PlayNextPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        // 播放三角
        path.move(to: CGPoint(x: 4*s, y: 5*s))
        path.addLine(to: CGPoint(x: 12*s, y: 12*s))
        path.addLine(to: CGPoint(x: 4*s, y: 19*s))
        
        // 向前箭头
        path.move(to: CGPoint(x: 14*s, y: 8*s))
        path.addLine(to: CGPoint(x: 20*s, y: 12*s))
        path.addLine(to: CGPoint(x: 14*s, y: 16*s))
        
        // 浮动竖线
        path.move(to: CGPoint(x: 20*s, y: 8*s))
        path.addLine(to: CGPoint(x: 20*s, y: 16*s))
        
        return path
    }
}

// 添加/加号
private struct AddPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        // 横线
        path.move(to: CGPoint(x: 5*s, y: 12*s))
        path.addLine(to: CGPoint(x: 19*s, y: 12*s))
        
        // 竖线
        path.move(to: CGPoint(x: 12*s, y: 5*s))
        path.addLine(to: CGPoint(x: 12*s, y: 19*s))
        
        return path
    }
}

// 添加到队列 - 列表 + 加号
private struct AddToQueuePath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        // 三条列表线
        path.move(to: CGPoint(x: 4*s, y: 6*s))
        path.addLine(to: CGPoint(x: 14*s, y: 6*s))
        
        path.move(to: CGPoint(x: 4*s, y: 11*s))
        path.addLine(to: CGPoint(x: 14*s, y: 11*s))
        
        path.move(to: CGPoint(x: 4*s, y: 16*s))
        path.addLine(to: CGPoint(x: 10*s, y: 16*s))
        
        // 加号（右下角）
        path.move(to: CGPoint(x: 15*s, y: 16*s))
        path.addLine(to: CGPoint(x: 21*s, y: 16*s))
        path.move(to: CGPoint(x: 18*s, y: 13*s))
        path.addLine(to: CGPoint(x: 18*s, y: 19*s))
        
        return path
    }
}


// MARK: - 播客专用图标路径

// 收音机 — 天线 + 圆角矩形机身
private struct RadioPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        // 机身
        let box = CGRect(x: 4*s, y: 10*s, width: 16*s, height: 10*s)
        path.addRoundedRect(in: box, cornerSize: CGSize(width: 3*s, height: 3*s))
        
        // 天线
        path.move(to: CGPoint(x: 8*s, y: 10*s))
        path.addLine(to: CGPoint(x: 16*s, y: 4*s))
        
        // 调谐旋钮
        path.addEllipse(in: CGRect(x: 7*s, y: 13*s, width: 4*s, height: 4*s))
        
        // 扬声器线条
        path.move(to: CGPoint(x: 14*s, y: 14*s))
        path.addLine(to: CGPoint(x: 17*s, y: 14*s))
        path.move(to: CGPoint(x: 14*s, y: 17*s))
        path.addLine(to: CGPoint(x: 17*s, y: 17*s))
        
        return path
    }
}

// 麦克风禁用 — 麦克风 + 斜线
private struct MicSlashPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        // 麦克风胶囊
        let capsule = CGRect(x: 9*s, y: 4*s, width: 6*s, height: 10*s)
        path.addRoundedRect(in: capsule, cornerSize: CGSize(width: 3*s, height: 3*s))
        
        // 弧线支架
        path.move(to: CGPoint(x: 6*s, y: 11*s))
        path.addCurve(to: CGPoint(x: 12*s, y: 17*s), control1: CGPoint(x: 6*s, y: 14.3*s), control2: CGPoint(x: 8.7*s, y: 17*s))
        path.addCurve(to: CGPoint(x: 18*s, y: 11*s), control1: CGPoint(x: 15.3*s, y: 17*s), control2: CGPoint(x: 18*s, y: 14.3*s))
        
        // 底部支柱
        path.move(to: CGPoint(x: 12*s, y: 17*s))
        path.addLine(to: CGPoint(x: 12*s, y: 20*s))
        
        // 斜线（禁用）
        path.move(to: CGPoint(x: 5*s, y: 4*s))
        path.addLine(to: CGPoint(x: 19*s, y: 20*s))
        
        return path
    }
}

// 波形 — 音频波形指示器
private struct WaveformPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        // 五条竖线，高度不同，模拟音频波形
        path.move(to: CGPoint(x: 4*s, y: 10*s)); path.addLine(to: CGPoint(x: 4*s, y: 14*s))
        path.move(to: CGPoint(x: 8*s, y: 7*s)); path.addLine(to: CGPoint(x: 8*s, y: 17*s))
        path.move(to: CGPoint(x: 12*s, y: 5*s)); path.addLine(to: CGPoint(x: 12*s, y: 19*s))
        path.move(to: CGPoint(x: 16*s, y: 8*s)); path.addLine(to: CGPoint(x: 16*s, y: 16*s))
        path.move(to: CGPoint(x: 20*s, y: 10*s)); path.addLine(to: CGPoint(x: 20*s, y: 14*s))
        
        return path
    }
}

// 跳到上一期 — 竖线 + 左三角
private struct SkipBackPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        // 左三角
        path.move(to: CGPoint(x: 18*s, y: 5*s))
        path.addLine(to: CGPoint(x: 10*s, y: 12*s))
        path.addLine(to: CGPoint(x: 18*s, y: 19*s))
        
        // 竖线
        path.move(to: CGPoint(x: 6*s, y: 6*s))
        path.addLine(to: CGPoint(x: 6*s, y: 18*s))
        
        return path
    }
}

// 跳到下一期 — 右三角 + 竖线
private struct SkipForwardPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        // 右三角
        path.move(to: CGPoint(x: 6*s, y: 5*s))
        path.addLine(to: CGPoint(x: 14*s, y: 12*s))
        path.addLine(to: CGPoint(x: 6*s, y: 19*s))
        
        // 竖线
        path.move(to: CGPoint(x: 18*s, y: 6*s))
        path.addLine(to: CGPoint(x: 18*s, y: 18*s))
        
        return path
    }
}

// 后退15秒 — 逆时针开口弧 + 左上箭头 + 居中 "15"
private struct Rewind15Path: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        let cx = 12 * s
        let cy = 12.5 * s
        let r = 8.5 * s

        // 逆时针开口弧（从顶部偏左到顶部偏右，留出缺口）
        path.addArc(center: CGPoint(x: cx, y: cy), radius: r,
                     startAngle: .degrees(-70), endAngle: .degrees(250), clockwise: false)

        // 箭头（弧线起点处，指向逆时针方向）
        let arrowTip = CGPoint(
            x: cx + r * CGFloat(cos(Double.pi * (-70) / 180)),
            y: cy + r * CGFloat(sin(Double.pi * (-70) / 180))
        )
        path.move(to: CGPoint(x: arrowTip.x - 3.5 * s, y: arrowTip.y - 0.5 * s))
        path.addLine(to: arrowTip)
        path.addLine(to: CGPoint(x: arrowTip.x + 0.5 * s, y: arrowTip.y - 3.5 * s))

        // "1" — 居中偏左，简洁竖线带短衬线
        let numY = 10.5 * s
        let numH = 6 * s
        path.move(to: CGPoint(x: 9 * s, y: numY + 1 * s))
        path.addLine(to: CGPoint(x: 10.2 * s, y: numY))
        path.addLine(to: CGPoint(x: 10.2 * s, y: numY + numH))
        // 底部短横线
        path.move(to: CGPoint(x: 8.8 * s, y: numY + numH))
        path.addLine(to: CGPoint(x: 11.6 * s, y: numY + numH))

        // "5" — 居中偏右，圆润的 S 形
        let fx: CGFloat = 13 * s
        path.move(to: CGPoint(x: fx + 3.2 * s, y: numY))
        path.addLine(to: CGPoint(x: fx, y: numY))
        path.addLine(to: CGPoint(x: fx - 0.3 * s, y: numY + 2.6 * s))
        // 5 的圆弧肚子
        path.addCurve(
            to: CGPoint(x: fx + 1.6 * s, y: numY + 2.2 * s),
            control1: CGPoint(x: fx + 0.5 * s, y: numY + 2.2 * s),
            control2: CGPoint(x: fx + 1 * s, y: numY + 2.2 * s)
        )
        path.addCurve(
            to: CGPoint(x: fx + 3 * s, y: numY + 4.2 * s),
            control1: CGPoint(x: fx + 2.8 * s, y: numY + 2.4 * s),
            control2: CGPoint(x: fx + 3.4 * s, y: numY + 3.2 * s)
        )
        path.addCurve(
            to: CGPoint(x: fx - 0.2 * s, y: numY + numH),
            control1: CGPoint(x: fx + 2.6 * s, y: numY + 5.4 * s),
            control2: CGPoint(x: fx + 1.2 * s, y: numY + numH)
        )

        return path
    }
}

// 前进15秒 — 顺时针开口弧 + 右上箭头 + 居中 "15"
private struct Forward15Path: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        let cx = 12 * s
        let cy = 12.5 * s
        let r = 8.5 * s

        // 顺时针开口弧（从顶部偏右到顶部偏左，留出缺口）
        path.addArc(center: CGPoint(x: cx, y: cy), radius: r,
                     startAngle: .degrees(-110), endAngle: .degrees(250), clockwise: true)

        // 箭头（弧线起点处，指向顺时针方向）
        let arrowTip = CGPoint(
            x: cx + r * CGFloat(cos(Double.pi * (-110) / 180)),
            y: cy + r * CGFloat(sin(Double.pi * (-110) / 180))
        )
        path.move(to: CGPoint(x: arrowTip.x + 3.5 * s, y: arrowTip.y - 0.5 * s))
        path.addLine(to: arrowTip)
        path.addLine(to: CGPoint(x: arrowTip.x - 0.5 * s, y: arrowTip.y - 3.5 * s))

        // "1" — 居中偏左
        let numY = 10.5 * s
        let numH = 6 * s
        path.move(to: CGPoint(x: 9 * s, y: numY + 1 * s))
        path.addLine(to: CGPoint(x: 10.2 * s, y: numY))
        path.addLine(to: CGPoint(x: 10.2 * s, y: numY + numH))
        path.move(to: CGPoint(x: 8.8 * s, y: numY + numH))
        path.addLine(to: CGPoint(x: 11.6 * s, y: numY + numH))

        // "5" — 居中偏右
        let fx: CGFloat = 13 * s
        path.move(to: CGPoint(x: fx + 3.2 * s, y: numY))
        path.addLine(to: CGPoint(x: fx, y: numY))
        path.addLine(to: CGPoint(x: fx - 0.3 * s, y: numY + 2.6 * s))
        path.addCurve(
            to: CGPoint(x: fx + 1.6 * s, y: numY + 2.2 * s),
            control1: CGPoint(x: fx + 0.5 * s, y: numY + 2.2 * s),
            control2: CGPoint(x: fx + 1 * s, y: numY + 2.2 * s)
        )
        path.addCurve(
            to: CGPoint(x: fx + 3 * s, y: numY + 4.2 * s),
            control1: CGPoint(x: fx + 2.8 * s, y: numY + 2.4 * s),
            control2: CGPoint(x: fx + 3.4 * s, y: numY + 3.2 * s)
        )
        path.addCurve(
            to: CGPoint(x: fx - 0.2 * s, y: numY + numH),
            control1: CGPoint(x: fx + 2.6 * s, y: numY + 5.4 * s),
            control2: CGPoint(x: fx + 1.2 * s, y: numY + numH)
        )

        return path
    }
}

// 带圆圈的叉号 — 清除按钮
private struct XmarkCirclePath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        // 圆圈
        path.addEllipse(in: CGRect(x: 4*s, y: 4*s, width: 16*s, height: 16*s))
        
        // 叉号
        path.move(to: CGPoint(x: 9*s, y: 9*s)); path.addLine(to: CGPoint(x: 15*s, y: 15*s))
        path.move(to: CGPoint(x: 15*s, y: 9*s)); path.addLine(to: CGPoint(x: 9*s, y: 15*s))
        
        return path
    }
}

// 2x2 网格 — 分类浏览入口
private struct GridSquarePath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        // 左上
        path.addRoundedRect(in: CGRect(x: 4*s, y: 4*s, width: 7*s, height: 7*s), cornerSize: CGSize(width: 2*s, height: 2*s))
        // 右上
        path.addRoundedRect(in: CGRect(x: 13*s, y: 4*s, width: 7*s, height: 7*s), cornerSize: CGSize(width: 2*s, height: 2*s))
        // 左下
        path.addRoundedRect(in: CGRect(x: 4*s, y: 13*s, width: 7*s, height: 7*s), cornerSize: CGSize(width: 2*s, height: 2*s))
        // 右下
        path.addRoundedRect(in: CGRect(x: 13*s, y: 13*s, width: 7*s, height: 7*s), cornerSize: CGSize(width: 2*s, height: 2*s))
        
        return path
    }
}

// MARK: - 电台分类图标 Paths

// MARK: - 电台分类图标 Paths

// 音乐 — 音符 + 弦线（Aura Floating）
private struct CatMusicPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        // 音符头圆
        path.addEllipse(in: CGRect(x: 5*s, y: 13*s, width: 6*s, height: 6*s))
        // 音符杆
        path.move(to: CGPoint(x: 11*s, y: 16*s))
        path.addLine(to: CGPoint(x: 11*s, y: 6*s))
        // 旗帜弦线
        path.addLine(to: CGPoint(x: 18*s, y: 8.5*s))
        return path
    }
}

// 生活 — 咖啡杯（Aura Floating）
private struct CatLifePath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        // 杯身
        path.move(to: CGPoint(x: 5*s, y: 9*s))
        path.addLine(to: CGPoint(x: 5*s, y: 15*s))
        path.addCurve(to: CGPoint(x: 9*s, y: 19*s), control1: CGPoint(x: 5*s, y: 17.2*s), control2: CGPoint(x: 6.8*s, y: 19*s))
        path.addLine(to: CGPoint(x: 13*s, y: 19*s))
        path.addCurve(to: CGPoint(x: 17*s, y: 15*s), control1: CGPoint(x: 15.2*s, y: 19*s), control2: CGPoint(x: 17*s, y: 17.2*s))
        path.addLine(to: CGPoint(x: 17*s, y: 9*s))
        path.addLine(to: CGPoint(x: 5*s, y: 9*s))
        // 把手（半透明）
        path.move(to: CGPoint(x: 17*s, y: 11*s))
        path.addCurve(to: CGPoint(x: 21*s, y: 13*s), control1: CGPoint(x: 19*s, y: 11*s), control2: CGPoint(x: 21*s, y: 11.9*s))
        path.addLine(to: CGPoint(x: 21*s, y: 14*s))
        path.addCurve(to: CGPoint(x: 17*s, y: 16*s), control1: CGPoint(x: 21*s, y: 15.1*s), control2: CGPoint(x: 19*s, y: 16*s))
        return path
    }
}

// 情感 — 半心 + 余韵弧线（Aura Floating）
private struct CatEmotionPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        // 半心（左半，带断裂空气感）
        let sc: CGFloat = 0.85
        let tx: CGFloat = 0
        let ty: CGFloat = 2*s
        path.move(to: CGPoint(x: 12*sc*s + tx, y: 18.5*sc*s + ty))
        path.addLine(to: CGPoint(x: 10.5*sc*s + tx, y: 17.2*sc*s + ty))
        path.addCurve(
            to: CGPoint(x: 2*sc*s + tx, y: 5.5*sc*s + ty),
            control1: CGPoint(x: 5.4*sc*s + tx, y: 12.5*sc*s + ty),
            control2: CGPoint(x: 2*sc*s + tx, y: 9.4*sc*s + ty)
        )
        path.addCurve(
            to: CGPoint(x: 7.5*sc*s + tx, y: 0.5*sc*s + ty),
            control1: CGPoint(x: 2*sc*s + tx, y: 2.4*sc*s + ty),
            control2: CGPoint(x: 4.4*sc*s + tx, y: 0.5*sc*s + ty)
        )
        path.addCurve(
            to: CGPoint(x: 12*sc*s + tx, y: 2*sc*s + ty),
            control1: CGPoint(x: 9.2*sc*s + tx, y: 0.5*sc*s + ty),
            control2: CGPoint(x: 10.9*sc*s + tx, y: 1.3*sc*s + ty)
        )
        // 余韵弧线（半透明）
        path.move(to: CGPoint(x: 16*s, y: 4*s))
        path.addCurve(to: CGPoint(x: 19*s, y: 9*s), control1: CGPoint(x: 18*s, y: 5*s), control2: CGPoint(x: 19*s, y: 7*s))
        return path
    }
}

// 创作|翻唱 — 画笔（Aura Floating）
private struct CatCreatePath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        // 画笔主体
        path.move(to: CGPoint(x: 4*s, y: 16*s))
        path.addLine(to: CGPoint(x: 13*s, y: 7*s))
        path.addLine(to: CGPoint(x: 17*s, y: 11*s))
        path.addLine(to: CGPoint(x: 8*s, y: 20*s))
        path.addLine(to: CGPoint(x: 4*s, y: 20*s))
        path.closeSubpath()
        // 笔尖延伸线（半透明断裂）
        path.move(to: CGPoint(x: 14*s, y: 8*s))
        path.addLine(to: CGPoint(x: 17*s, y: 5*s))
        return path
    }
}

// 二次元 — 猫耳弧线（Aura Floating）
private struct CatAcgPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        // 脸部弧线
        path.addArc(center: CGPoint(x: 12*s, y: 16*s), radius: 7*s, startAngle: .degrees(-160), endAngle: .degrees(-20), clockwise: false)
        // 左猫耳
        path.move(to: CGPoint(x: 4*s, y: 11*s))
        path.addLine(to: CGPoint(x: 7*s, y: 4*s))
        path.addLine(to: CGPoint(x: 10*s, y: 8*s))
        // 右猫耳
        path.move(to: CGPoint(x: 14*s, y: 8*s))
        path.addLine(to: CGPoint(x: 17*s, y: 4*s))
        path.addLine(to: CGPoint(x: 20*s, y: 11*s))
        return path
    }
}

// 娱乐 — 星形 + 中心圆（Aura Floating）
private struct CatEntertainPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        // 星形轮廓（半透明）
        path.move(to: CGPoint(x: 12*s, y: 4*s))
        path.addLine(to: CGPoint(x: 14*s, y: 10*s))
        path.addLine(to: CGPoint(x: 20*s, y: 10*s))
        path.addLine(to: CGPoint(x: 15*s, y: 14*s))
        path.addLine(to: CGPoint(x: 17*s, y: 20*s))
        path.addLine(to: CGPoint(x: 12*s, y: 16*s))
        path.addLine(to: CGPoint(x: 7*s, y: 20*s))
        path.addLine(to: CGPoint(x: 9*s, y: 14*s))
        path.addLine(to: CGPoint(x: 4*s, y: 10*s))
        path.addLine(to: CGPoint(x: 10*s, y: 10*s))
        path.closeSubpath()
        // 中心圆
        path.addEllipse(in: CGRect(x: 9*s, y: 9*s, width: 6*s, height: 6*s))
        return path
    }
}


// 脱口秀 — 气泡对话框 + 三点（Aura Floating，断裂虚线）
private struct CatTalkshowPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        // 对话气泡（带断裂感的弧线）
        path.move(to: CGPoint(x: 20*s, y: 12*s))
        path.addCurve(to: CGPoint(x: 12*s, y: 5*s), control1: CGPoint(x: 20*s, y: 8.1*s), control2: CGPoint(x: 16.4*s, y: 5*s))
        path.addCurve(to: CGPoint(x: 4*s, y: 12*s), control1: CGPoint(x: 7.6*s, y: 5*s), control2: CGPoint(x: 4*s, y: 8.1*s))
        path.addCurve(to: CGPoint(x: 5.5*s, y: 16*s), control1: CGPoint(x: 4*s, y: 13.5*s), control2: CGPoint(x: 4.5*s, y: 14.8*s))
        path.addLine(to: CGPoint(x: 4*s, y: 20*s))
        path.addLine(to: CGPoint(x: 8.5*s, y: 18.5*s))
        path.addCurve(to: CGPoint(x: 12*s, y: 19*s), control1: CGPoint(x: 9.6*s, y: 18.8*s), control2: CGPoint(x: 10.8*s, y: 19*s))
        // 三个对话点
        let dotR: CGFloat = 1*s
        path.addEllipse(in: CGRect(x: 8*s - dotR, y: 12*s - dotR, width: dotR*2, height: dotR*2))
        path.addEllipse(in: CGRect(x: 12*s - dotR, y: 12*s - dotR, width: dotR*2, height: dotR*2))
        path.addEllipse(in: CGRect(x: 16*s - dotR, y: 12*s - dotR, width: dotR*2, height: dotR*2))
        return path
    }
}

// 有声书 — 书本（Aura Floating）
private struct CatBookPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        // 书本主体
        path.move(to: CGPoint(x: 4*s, y: 17*s))
        path.addLine(to: CGPoint(x: 4*s, y: 5*s))
        path.addLine(to: CGPoint(x: 16*s, y: 5*s))
        path.addCurve(to: CGPoint(x: 18*s, y: 7*s), control1: CGPoint(x: 17.1*s, y: 5*s), control2: CGPoint(x: 18*s, y: 5.9*s))
        path.addLine(to: CGPoint(x: 18*s, y: 19*s))
        path.addLine(to: CGPoint(x: 6*s, y: 19*s))
        path.addCurve(to: CGPoint(x: 4*s, y: 17*s), control1: CGPoint(x: 4.9*s, y: 19*s), control2: CGPoint(x: 4*s, y: 18.1*s))
        // 分隔线（半透明）
        path.move(to: CGPoint(x: 4*s, y: 15*s))
        path.addLine(to: CGPoint(x: 18*s, y: 15*s))
        return path
    }
}

// 知识 — 灯泡（Aura Floating）
private struct CatKnowledgePath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        // 灯泡主体
        path.move(to: CGPoint(x: 12*s, y: 5*s))
        path.addCurve(to: CGPoint(x: 7*s, y: 10*s), control1: CGPoint(x: 9*s, y: 5*s), control2: CGPoint(x: 7*s, y: 7*s))
        path.addCurve(to: CGPoint(x: 10*s, y: 16*s), control1: CGPoint(x: 7*s, y: 13*s), control2: CGPoint(x: 10*s, y: 14*s))
        path.addLine(to: CGPoint(x: 14*s, y: 16*s))
        path.addCurve(to: CGPoint(x: 17*s, y: 10*s), control1: CGPoint(x: 14*s, y: 14*s), control2: CGPoint(x: 17*s, y: 13*s))
        path.addCurve(to: CGPoint(x: 12*s, y: 5*s), control1: CGPoint(x: 17*s, y: 7*s), control2: CGPoint(x: 15*s, y: 5*s))
        // 底部横线
        path.move(to: CGPoint(x: 10*s, y: 20*s))
        path.addLine(to: CGPoint(x: 14*s, y: 20*s))
        return path
    }
}

// 商业财经 — 趋势线 + 箭头（Aura Floating）
private struct CatBusinessPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        // 趋势折线
        path.move(to: CGPoint(x: 4*s, y: 17*s))
        path.addLine(to: CGPoint(x: 9*s, y: 12*s))
        path.addLine(to: CGPoint(x: 13*s, y: 16*s))
        path.addLine(to: CGPoint(x: 20*s, y: 9*s))
        // 箭头
        path.move(to: CGPoint(x: 16*s, y: 9*s))
        path.addLine(to: CGPoint(x: 20*s, y: 9*s))
        path.addLine(to: CGPoint(x: 20*s, y: 13*s))
        return path
    }
}

// 人文历史 — 沙漏对称结构（Aura Floating）
private struct CatHistoryPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        // 中轴骨架（半透明）
        path.move(to: CGPoint(x: 7*s, y: 5*s))
        path.addLine(to: CGPoint(x: 17*s, y: 5*s))
        path.move(to: CGPoint(x: 7*s, y: 19*s))
        path.addLine(to: CGPoint(x: 17*s, y: 19*s))
        path.move(to: CGPoint(x: 12*s, y: 12*s))
        path.addLine(to: CGPoint(x: 12*s, y: 5*s))
        path.move(to: CGPoint(x: 12*s, y: 12*s))
        path.addLine(to: CGPoint(x: 12*s, y: 19*s))
        // 沙漏曲线
        path.move(to: CGPoint(x: 7*s, y: 5*s))
        path.addCurve(to: CGPoint(x: 12*s, y: 12*s), control1: CGPoint(x: 7*s, y: 9*s), control2: CGPoint(x: 12*s, y: 9*s))
        path.addCurve(to: CGPoint(x: 17*s, y: 5*s), control1: CGPoint(x: 12*s, y: 9*s), control2: CGPoint(x: 17*s, y: 9*s))
        path.move(to: CGPoint(x: 7*s, y: 19*s))
        path.addCurve(to: CGPoint(x: 12*s, y: 12*s), control1: CGPoint(x: 7*s, y: 15*s), control2: CGPoint(x: 12*s, y: 15*s))
        path.addCurve(to: CGPoint(x: 17*s, y: 19*s), control1: CGPoint(x: 12*s, y: 15*s), control2: CGPoint(x: 17*s, y: 15*s))
        return path
    }
}

// 新闻资讯 — 报纸（Aura Floating，断裂虚线边框）
private struct CatNewsPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        // 报纸边框（圆角矩形）
        path.addRoundedRect(in: CGRect(x: 4*s, y: 5*s, width: 16*s, height: 14*s), cornerSize: CGSize(width: 2*s, height: 2*s))
        // 文字行（半透明）
        path.move(to: CGPoint(x: 7*s, y: 9*s))
        path.addLine(to: CGPoint(x: 13*s, y: 9*s))
        path.move(to: CGPoint(x: 7*s, y: 12*s))
        path.addLine(to: CGPoint(x: 17*s, y: 12*s))
        path.move(to: CGPoint(x: 7*s, y: 15*s))
        path.addLine(to: CGPoint(x: 15*s, y: 15*s))
        return path
    }
}


// 亲子 — 大小圆（Aura Floating）
private struct CatParentingPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        // 大圆（父）
        path.addEllipse(in: CGRect(x: 5.5*s, y: 6.5*s, width: 7*s, height: 7*s))
        // 小圆（子）
        path.addEllipse(in: CGRect(x: 12.5*s, y: 13.5*s, width: 5*s, height: 5*s))
        // 连接弧线（半透明）
        path.move(to: CGPoint(x: 5*s, y: 19*s))
        path.addCurve(to: CGPoint(x: 9*s, y: 15*s), control1: CGPoint(x: 5*s, y: 16*s), control2: CGPoint(x: 7*s, y: 15*s))
        path.move(to: CGPoint(x: 14*s, y: 20*s))
        path.addCurve(to: CGPoint(x: 16*s, y: 18.5*s), control1: CGPoint(x: 14*s, y: 19*s), control2: CGPoint(x: 15*s, y: 18.5*s))
        return path
    }
}

// 旅途 — 纸飞机导航（Aura Floating）
private struct CatTravelPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        // 纸飞机主体
        path.move(to: CGPoint(x: 20*s, y: 4*s))
        path.addLine(to: CGPoint(x: 4*s, y: 11*s))
        path.addLine(to: CGPoint(x: 11*s, y: 14*s))
        path.addLine(to: CGPoint(x: 14*s, y: 21*s))
        path.closeSubpath()
        // 对角线（半透明）
        path.move(to: CGPoint(x: 11*s, y: 14*s))
        path.addLine(to: CGPoint(x: 20*s, y: 4*s))
        return path
    }
}

// 相声曲艺 — 扇形折扇（Aura Floating）
private struct CatCrosstalkPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        // 扇面轮廓（半透明）
        path.move(to: CGPoint(x: 12*s, y: 19*s))
        path.addLine(to: CGPoint(x: 5*s, y: 14*s))
        path.addLine(to: CGPoint(x: 12*s, y: 5*s))
        path.addLine(to: CGPoint(x: 19*s, y: 14*s))
        path.closeSubpath()
        // 扇骨线条
        path.move(to: CGPoint(x: 12*s, y: 19*s))
        path.addLine(to: CGPoint(x: 12*s, y: 5*s))
        path.move(to: CGPoint(x: 12*s, y: 19*s))
        path.addLine(to: CGPoint(x: 7*s, y: 8*s))
        path.move(to: CGPoint(x: 12*s, y: 19*s))
        path.addLine(to: CGPoint(x: 17*s, y: 8*s))
        return path
    }
}

// 美食 — 碗 + 蒸汽（Aura Floating）
private struct CatFoodPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        // 碗（半圆弧）
        path.addArc(center: CGPoint(x: 12*s, y: 11*s), radius: 8*s, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        // 蒸汽线（半透明）
        path.move(to: CGPoint(x: 13*s, y: 3*s))
        path.addLine(to: CGPoint(x: 18*s, y: 9*s))
        path.move(to: CGPoint(x: 10*s, y: 3*s))
        path.addLine(to: CGPoint(x: 15*s, y: 9*s))
        return path
    }
}

// 科技 — 六边形 + 中心圆（Aura Floating）
private struct CatTechPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        // 六边形
        path.move(to: CGPoint(x: 12*s, y: 3*s))
        path.addLine(to: CGPoint(x: 19*s, y: 7*s))
        path.addLine(to: CGPoint(x: 19*s, y: 17*s))
        path.addLine(to: CGPoint(x: 12*s, y: 21*s))
        path.addLine(to: CGPoint(x: 5*s, y: 17*s))
        path.addLine(to: CGPoint(x: 5*s, y: 7*s))
        path.closeSubpath()
        // 中心圆
        path.addEllipse(in: CGRect(x: 9.5*s, y: 9.5*s, width: 5*s, height: 5*s))
        return path
    }
}

// 默认分类 — 四宫格（Aura Floating）
private struct CatDefaultPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        // 左上格
        path.addRoundedRect(in: CGRect(x: 5*s, y: 5*s, width: 6*s, height: 6*s), cornerSize: CGSize(width: 1.5*s, height: 1.5*s))
        // 右下格
        path.addRoundedRect(in: CGRect(x: 13*s, y: 13*s, width: 6*s, height: 6*s), cornerSize: CGSize(width: 1.5*s, height: 1.5*s))
        // 右上格（半透明）
        path.addRoundedRect(in: CGRect(x: 13*s, y: 5*s, width: 6*s, height: 6*s), cornerSize: CGSize(width: 1.5*s, height: 1.5*s))
        // 左下格（半透明）
        path.addRoundedRect(in: CGRect(x: 5*s, y: 13*s, width: 6*s, height: 6*s), cornerSize: CGSize(width: 1.5*s, height: 1.5*s))
        return path
    }
}


// 音乐播客 — 麦克风 + 弧线（Aura Floating）
private struct CatPodcastPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        // 麦克风胶囊
        path.addRoundedRect(in: CGRect(x: 8.5*s, y: 5*s, width: 7*s, height: 10*s), cornerSize: CGSize(width: 3.5*s, height: 3.5*s))
        // 收音弧线
        path.move(to: CGPoint(x: 6*s, y: 11*s))
        path.addCurve(to: CGPoint(x: 12*s, y: 17*s), control1: CGPoint(x: 6*s, y: 14.3*s), control2: CGPoint(x: 8.7*s, y: 17*s))
        path.addCurve(to: CGPoint(x: 19*s, y: 11*s), control1: CGPoint(x: 15.3*s, y: 17*s), control2: CGPoint(x: 19*s, y: 14.3*s))
        // 底部杆（半透明）
        path.move(to: CGPoint(x: 12*s, y: 17*s))
        path.addLine(to: CGPoint(x: 12*s, y: 20*s))
        return path
    }
}

// 电音 — 波形线（Aura Floating）
private struct CatElectronicPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        // 心电图波形
        path.move(to: CGPoint(x: 4*s, y: 12*s))
        path.addLine(to: CGPoint(x: 7*s, y: 12*s))
        path.addLine(to: CGPoint(x: 9*s, y: 6*s))
        path.addLine(to: CGPoint(x: 13*s, y: 18*s))
        path.addLine(to: CGPoint(x: 15*s, y: 12*s))
        path.addLine(to: CGPoint(x: 19*s, y: 12*s))
        return path
    }
}

// 明星专区 — 五角星（Aura Floating，断裂虚线）
private struct CatStarPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        // 五角星
        path.move(to: CGPoint(x: 12*s, y: 4*s))
        path.addLine(to: CGPoint(x: 14.5*s, y: 9.5*s))
        path.addLine(to: CGPoint(x: 20.5*s, y: 10.5*s))
        path.addLine(to: CGPoint(x: 16*s, y: 15*s))
        path.addLine(to: CGPoint(x: 17.5*s, y: 21*s))
        path.addLine(to: CGPoint(x: 12*s, y: 18*s))
        path.addLine(to: CGPoint(x: 6.5*s, y: 21*s))
        path.addLine(to: CGPoint(x: 8*s, y: 15*s))
        path.addLine(to: CGPoint(x: 3.5*s, y: 10.5*s))
        path.addLine(to: CGPoint(x: 9.5*s, y: 9.5*s))
        path.closeSubpath()
        return path
    }
}

// 广播剧 — 笑脸面具（Aura Floating，断裂弧线）
private struct CatDramaPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        // 面具圆弧（断裂虚线感）
        path.addArc(center: CGPoint(x: 12*s, y: 12*s), radius: 7*s, startAngle: .degrees(20), endAngle: .degrees(340), clockwise: false)
        // 左眼
        let eyeR: CGFloat = 0.75*s
        path.addEllipse(in: CGRect(x: 8.5*s - eyeR, y: 10*s - eyeR, width: eyeR*2, height: eyeR*2))
        // 右眼
        path.addEllipse(in: CGRect(x: 14*s - eyeR, y: 10*s - eyeR, width: eyeR*2, height: eyeR*2))
        // 微笑弧线
        path.move(to: CGPoint(x: 9*s, y: 15*s))
        path.addCurve(to: CGPoint(x: 15*s, y: 15*s), control1: CGPoint(x: 10*s, y: 16*s), control2: CGPoint(x: 14*s, y: 16*s))
        return path
    }
}

// 故事 — 翻开的书页（Aura Floating）
private struct CatStoryPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        // 后页（半透明）
        path.move(to: CGPoint(x: 7*s, y: 19*s))
        path.addLine(to: CGPoint(x: 17*s, y: 19*s))
        path.addCurve(to: CGPoint(x: 19*s, y: 17*s), control1: CGPoint(x: 18.1*s, y: 19*s), control2: CGPoint(x: 19*s, y: 18.1*s))
        path.addLine(to: CGPoint(x: 19*s, y: 7*s))
        // 前页（主体）
        path.move(to: CGPoint(x: 5*s, y: 17*s))
        path.addLine(to: CGPoint(x: 8*s, y: 5*s))
        path.addLine(to: CGPoint(x: 15*s, y: 5*s))
        path.addLine(to: CGPoint(x: 12*s, y: 17*s))
        path.closeSubpath()
        return path
    }
}

// 其他 — 三点省略号（Aura Floating）
private struct CatOtherPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        let dotR: CGFloat = 1.2*s
        // 左点
        path.addEllipse(in: CGRect(x: 6*s - dotR, y: 12*s - dotR, width: dotR*2, height: dotR*2))
        // 中点
        path.addEllipse(in: CGRect(x: 12*s - dotR, y: 12*s - dotR, width: dotR*2, height: dotR*2))
        // 右点（半透明）
        path.addEllipse(in: CGRect(x: 18*s - dotR, y: 12*s - dotR, width: dotR*2, height: dotR*2))
        return path
    }
}

// 文学出版 — 羽毛笔 + 文字行（Aura Floating）
private struct CatPublishPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        // 文字行（半透明）
        path.move(to: CGPoint(x: 5*s, y: 19*s))
        path.addLine(to: CGPoint(x: 14*s, y: 19*s))
        path.move(to: CGPoint(x: 5*s, y: 15*s))
        path.addLine(to: CGPoint(x: 17*s, y: 15*s))
        path.move(to: CGPoint(x: 5*s, y: 11*s))
        path.addLine(to: CGPoint(x: 19*s, y: 11*s))
        // 羽毛笔
        path.move(to: CGPoint(x: 16*s, y: 4*s))
        path.addLine(to: CGPoint(x: 16*s, y: 8*s))
        path.move(to: CGPoint(x: 16*s, y: 4*s))
        path.addLine(to: CGPoint(x: 14*s, y: 6*s))
        path.move(to: CGPoint(x: 16*s, y: 4*s))
        path.addLine(to: CGPoint(x: 18*s, y: 6*s))
        return path
    }
}

// MARK: - 补齐 SF Symbols 替换图标

// 对勾 ✓
private struct CheckmarkPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        path.move(to: CGPoint(x: 5*s, y: 12*s))
        path.addLine(to: CGPoint(x: 10*s, y: 17*s))
        path.addLine(to: CGPoint(x: 19*s, y: 7*s))
        return path
    }
}

// 缩小屏幕（退出全屏）— 四角向内箭头
private struct ShrinkScreenPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        // 左上角向内
        path.move(to: CGPoint(x: 4*s, y: 4*s))
        path.addLine(to: CGPoint(x: 10*s, y: 10*s))
        path.move(to: CGPoint(x: 10*s, y: 6*s))
        path.addLine(to: CGPoint(x: 10*s, y: 10*s))
        path.addLine(to: CGPoint(x: 6*s, y: 10*s))
        // 右下角向内
        path.move(to: CGPoint(x: 20*s, y: 20*s))
        path.addLine(to: CGPoint(x: 14*s, y: 14*s))
        path.move(to: CGPoint(x: 14*s, y: 18*s))
        path.addLine(to: CGPoint(x: 14*s, y: 14*s))
        path.addLine(to: CGPoint(x: 18*s, y: 14*s))
        return path
    }
}

// 放大屏幕（进入全屏）— 四角向外箭头
private struct ExpandScreenPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        // 左上角向外
        path.move(to: CGPoint(x: 10*s, y: 10*s))
        path.addLine(to: CGPoint(x: 4*s, y: 4*s))
        path.move(to: CGPoint(x: 4*s, y: 8*s))
        path.addLine(to: CGPoint(x: 4*s, y: 4*s))
        path.addLine(to: CGPoint(x: 8*s, y: 4*s))
        // 右下角向外
        path.move(to: CGPoint(x: 14*s, y: 14*s))
        path.addLine(to: CGPoint(x: 20*s, y: 20*s))
        path.move(to: CGPoint(x: 20*s, y: 16*s))
        path.addLine(to: CGPoint(x: 20*s, y: 20*s))
        path.addLine(to: CGPoint(x: 16*s, y: 20*s))
        return path
    }
}

// 耳机
private struct HeadphonesPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        // 头带弧线
        path.move(to: CGPoint(x: 5*s, y: 13*s))
        path.addCurve(to: CGPoint(x: 19*s, y: 13*s),
                      control1: CGPoint(x: 5*s, y: 5*s),
                      control2: CGPoint(x: 19*s, y: 5*s))
        // 左耳罩
        let leftEar = CGRect(x: 3*s, y: 13*s, width: 4*s, height: 6*s)
        path.addRoundedRect(in: leftEar, cornerSize: CGSize(width: 2*s, height: 2*s))
        // 右耳罩
        let rightEar = CGRect(x: 17*s, y: 13*s, width: 4*s, height: 6*s)
        path.addRoundedRect(in: rightEar, cornerSize: CGSize(width: 2*s, height: 2*s))
        return path
    }
}

// 取消喜欢（心形 + 斜线）
private struct HeartSlashPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        // 心形轮廓
        path.move(to: CGPoint(x: 12*s, y: 19*s))
        path.addCurve(to: CGPoint(x: 3*s, y: 8*s),
                      control1: CGPoint(x: 6*s, y: 15*s),
                      control2: CGPoint(x: 3*s, y: 11*s))
        path.addCurve(to: CGPoint(x: 7.5*s, y: 4*s),
                      control1: CGPoint(x: 3*s, y: 6*s),
                      control2: CGPoint(x: 5*s, y: 4*s))
        path.addCurve(to: CGPoint(x: 12*s, y: 6.5*s),
                      control1: CGPoint(x: 9.5*s, y: 4*s),
                      control2: CGPoint(x: 11*s, y: 5*s))
        path.addCurve(to: CGPoint(x: 16.5*s, y: 4*s),
                      control1: CGPoint(x: 13*s, y: 5*s),
                      control2: CGPoint(x: 14.5*s, y: 4*s))
        path.addCurve(to: CGPoint(x: 21*s, y: 8*s),
                      control1: CGPoint(x: 19*s, y: 4*s),
                      control2: CGPoint(x: 21*s, y: 6*s))
        path.addCurve(to: CGPoint(x: 12*s, y: 19*s),
                      control1: CGPoint(x: 21*s, y: 11*s),
                      control2: CGPoint(x: 18*s, y: 15*s))
        // 斜线
        path.move(to: CGPoint(x: 4*s, y: 4*s))
        path.addLine(to: CGPoint(x: 20*s, y: 20*s))
        return path
    }
}

// 人物 + 圆圈
private struct PersonCirclePath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        // 外圆
        path.addEllipse(in: CGRect(x: 3*s, y: 3*s, width: 18*s, height: 18*s))
        // 头部
        path.addEllipse(in: CGRect(x: 9.5*s, y: 6*s, width: 5*s, height: 5*s))
        // 身体弧线
        path.move(to: CGPoint(x: 7*s, y: 18*s))
        path.addCurve(to: CGPoint(x: 12*s, y: 13.5*s),
                      control1: CGPoint(x: 7*s, y: 15.5*s),
                      control2: CGPoint(x: 9*s, y: 13.5*s))
        path.addCurve(to: CGPoint(x: 17*s, y: 18*s),
                      control1: CGPoint(x: 15*s, y: 13.5*s),
                      control2: CGPoint(x: 17*s, y: 15.5*s))
        return path
    }
}

// 专辑（堆叠方块）
private struct AlbumPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        // 主方块
        let main = CGRect(x: 4*s, y: 8*s, width: 16*s, height: 13*s)
        path.addRoundedRect(in: main, cornerSize: CGSize(width: 2.5*s, height: 2.5*s))
        // 中层
        path.move(to: CGPoint(x: 6*s, y: 5.5*s))
        path.addLine(to: CGPoint(x: 18*s, y: 5.5*s))
        // 顶层
        path.move(to: CGPoint(x: 8*s, y: 3*s))
        path.addLine(to: CGPoint(x: 16*s, y: 3*s))
        return path
    }
}

// 信息圆圈 (i)
private struct InfoCirclePath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        // 外圆
        path.addEllipse(in: CGRect(x: 3*s, y: 3*s, width: 18*s, height: 18*s))
        // i 的点
        path.addEllipse(in: CGRect(x: 11*s, y: 7*s, width: 2*s, height: 2*s))
        // i 的竖线
        path.move(to: CGPoint(x: 12*s, y: 11*s))
        path.addLine(to: CGPoint(x: 12*s, y: 17*s))
        return path
    }
}

// 向下箭头 + 圆圈（下载）
private struct ArrowDownCirclePath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        // 外圆
        path.addEllipse(in: CGRect(x: 3*s, y: 3*s, width: 18*s, height: 18*s))
        // 向下箭头竖线
        path.move(to: CGPoint(x: 12*s, y: 7*s))
        path.addLine(to: CGPoint(x: 12*s, y: 15*s))
        // 箭头两翼
        path.move(to: CGPoint(x: 9*s, y: 13*s))
        path.addLine(to: CGPoint(x: 12*s, y: 16*s))
        path.addLine(to: CGPoint(x: 15*s, y: 13*s))
        return path
    }
}

// 太阳（浅色模式）
private struct SunPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        // 中心圆
        path.addEllipse(in: CGRect(x: 8*s, y: 8*s, width: 8*s, height: 8*s))
        // 光线（上下左右 + 四角）
        let rays: [(CGPoint, CGPoint)] = [
            (CGPoint(x: 12*s, y: 2*s), CGPoint(x: 12*s, y: 5*s)),
            (CGPoint(x: 12*s, y: 19*s), CGPoint(x: 12*s, y: 22*s)),
            (CGPoint(x: 2*s, y: 12*s), CGPoint(x: 5*s, y: 12*s)),
            (CGPoint(x: 19*s, y: 12*s), CGPoint(x: 22*s, y: 12*s)),
            (CGPoint(x: 4.9*s, y: 4.9*s), CGPoint(x: 7*s, y: 7*s)),
            (CGPoint(x: 17*s, y: 17*s), CGPoint(x: 19.1*s, y: 19.1*s)),
            (CGPoint(x: 19.1*s, y: 4.9*s), CGPoint(x: 17*s, y: 7*s)),
            (CGPoint(x: 7*s, y: 17*s), CGPoint(x: 4.9*s, y: 19.1*s)),
        ]
        for (from, to) in rays {
            path.move(to: from)
            path.addLine(to: to)
        }
        return path
    }
}

// 月亮（深色模式）
private struct MoonPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        // 月牙：大弧 + 内凹弧
        path.move(to: CGPoint(x: 16*s, y: 4*s))
        path.addCurve(to: CGPoint(x: 16*s, y: 20*s),
                      control1: CGPoint(x: 8*s, y: 4*s),
                      control2: CGPoint(x: 8*s, y: 20*s))
        path.addCurve(to: CGPoint(x: 16*s, y: 4*s),
                      control1: CGPoint(x: 22*s, y: 20*s),
                      control2: CGPoint(x: 22*s, y: 4*s))
        return path
    }
}

// 半圆（自动模式）
private struct HalfCirclePath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        let center = CGPoint(x: 12*s, y: 12*s)
        let radius = 8*s
        // 完整圆
        path.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius,
                                    width: radius * 2, height: radius * 2))
        // 右半填充竖线（视觉分割）
        path.move(to: CGPoint(x: 12*s, y: 4*s))
        path.addLine(to: CGPoint(x: 12*s, y: 20*s))
        return path
    }
}

// 均衡器图标：三条垂直滑轨 + 圆形滑块，经典 EQ 调节器造型
private struct EqualizerPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        // 左轨道（滑块偏上）
        path.move(to: CGPoint(x: 7*s, y: 4*s))
        path.addLine(to: CGPoint(x: 7*s, y: 20*s))
        path.addEllipse(in: CGRect(x: 5.2*s, y: 7.2*s, width: 3.6*s, height: 3.6*s))
        
        // 中轨道（滑块偏下）
        path.move(to: CGPoint(x: 12*s, y: 4*s))
        path.addLine(to: CGPoint(x: 12*s, y: 20*s))
        path.addEllipse(in: CGRect(x: 10.2*s, y: 13.2*s, width: 3.6*s, height: 3.6*s))
        
        // 右轨道（滑块居中偏上）
        path.move(to: CGPoint(x: 17*s, y: 4*s))
        path.addLine(to: CGPoint(x: 17*s, y: 20*s))
        path.addEllipse(in: CGRect(x: 15.2*s, y: 9.2*s, width: 3.6*s, height: 3.6*s))
        
        return path
    }
}

// 沉浸式播放器图标：星球 + 倾斜轨道环，呼应"星尘宇宙"概念
private struct ImmersivePath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        let cx = 12 * s
        let cy = 12 * s
        
        // 中心星球（圆形）
        path.addEllipse(in: CGRect(x: cx - 4*s, y: cy - 4*s, width: 8*s, height: 8*s))
        
        // 倾斜轨道环（椭圆弧，模拟 3D 透视）
        // 用两段弧线绘制一个倾斜的椭圆环
        // 上半弧（从星球前方经过）
        path.move(to: CGPoint(x: 2.5*s, y: 10*s))
        path.addCurve(
            to: CGPoint(x: 21.5*s, y: 10*s),
            control1: CGPoint(x: 5*s, y: 4*s),
            control2: CGPoint(x: 19*s, y: 4*s)
        )
        // 下半弧（从星球后方经过）
        path.addCurve(
            to: CGPoint(x: 2.5*s, y: 10*s),
            control1: CGPoint(x: 19*s, y: 16*s),
            control2: CGPoint(x: 5*s, y: 16*s)
        )
        
        // 轨道上的小卫星点
        path.addEllipse(in: CGRect(x: 20*s, y: 9*s, width: 2.5*s, height: 2.5*s))
        
        return path
    }
}


// 播放器主题图标：四宫格布局 + 右下角画笔点缀，表达「主题/外观切换」
private struct PlayerThemePath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        // 左上方块（圆角）
        path.addRoundedRect(
            in: CGRect(x: 4*s, y: 4*s, width: 7*s, height: 7*s),
            cornerSize: CGSize(width: 2*s, height: 2*s)
        )
        
        // 右上方块（圆角）
        path.addRoundedRect(
            in: CGRect(x: 13*s, y: 4*s, width: 7*s, height: 7*s),
            cornerSize: CGSize(width: 2*s, height: 2*s)
        )
        
        // 左下方块（圆角）
        path.addRoundedRect(
            in: CGRect(x: 4*s, y: 13*s, width: 7*s, height: 7*s),
            cornerSize: CGSize(width: 2*s, height: 2*s)
        )
        
        // 右下：画笔/调色笔造型（斜向）
        // 笔身
        path.move(to: CGPoint(x: 14*s, y: 19*s))
        path.addLine(to: CGPoint(x: 19*s, y: 14*s))
        // 笔尖
        path.move(to: CGPoint(x: 19*s, y: 14*s))
        path.addLine(to: CGPoint(x: 20.5*s, y: 15.5*s))
        path.addLine(to: CGPoint(x: 15.5*s, y: 20.5*s))
        path.addLine(to: CGPoint(x: 14*s, y: 19*s))
        
        return path
    }
}

// 表情图标：笑脸
private struct EmojiPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        let center = CGPoint(x: 12*s, y: 12*s)
        
        // 外圆
        path.addEllipse(in: CGRect(x: 3*s, y: 3*s, width: 18*s, height: 18*s))
        
        // 左眼
        path.addEllipse(in: CGRect(x: 7.5*s, y: 8.5*s, width: 2.5*s, height: 2.5*s))
        
        // 右眼
        path.addEllipse(in: CGRect(x: 14*s, y: 8.5*s, width: 2.5*s, height: 2.5*s))
        
        // 微笑弧线
        path.move(to: CGPoint(x: 7.5*s, y: 14.5*s))
        path.addQuadCurve(
            to: CGPoint(x: 16.5*s, y: 14.5*s),
            control: CGPoint(x: 12*s, y: 19*s)
        )
        
        return path
    }
}

// MARK: - 调试日志图标 Paths

// 分享图标：square.and.arrow.up 风格
private struct ShareIconPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        // 向上箭头
        path.move(to: CGPoint(x: 12*s, y: 3*s))
        path.addLine(to: CGPoint(x: 12*s, y: 14*s))
        
        // 箭头两翼
        path.move(to: CGPoint(x: 8*s, y: 7*s))
        path.addLine(to: CGPoint(x: 12*s, y: 3*s))
        path.addLine(to: CGPoint(x: 16*s, y: 7*s))
        
        // 底部方框（开口向上）
        path.move(to: CGPoint(x: 7*s, y: 10*s))
        path.addLine(to: CGPoint(x: 7*s, y: 18*s))
        path.addCurve(to: CGPoint(x: 9*s, y: 20*s), control1: CGPoint(x: 7*s, y: 19.1*s), control2: CGPoint(x: 7.9*s, y: 20*s))
        path.addLine(to: CGPoint(x: 15*s, y: 20*s))
        path.addCurve(to: CGPoint(x: 17*s, y: 18*s), control1: CGPoint(x: 16.1*s, y: 20*s), control2: CGPoint(x: 17*s, y: 19.1*s))
        path.addLine(to: CGPoint(x: 17*s, y: 10*s))
        
        return path
    }
}

// 信息图标：i.circle 风格
private struct LogInfoPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        // 外圆
        path.addEllipse(in: CGRect(x: 3*s, y: 3*s, width: 18*s, height: 18*s))
        
        // 字母 i 的点
        path.addEllipse(in: CGRect(x: 11*s, y: 7*s, width: 2*s, height: 2*s))
        
        // 字母 i 的竖线
        path.move(to: CGPoint(x: 12*s, y: 11*s))
        path.addLine(to: CGPoint(x: 12*s, y: 17*s))
        
        return path
    }
}

// 调试图标：magnifyingglass.circle 风格（放大镜 + 圆圈）
private struct LogDebugPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        // 外圆
        path.addEllipse(in: CGRect(x: 3*s, y: 3*s, width: 18*s, height: 18*s))
        
        // 放大镜圆圈
        path.addEllipse(in: CGRect(x: 8*s, y: 7*s, width: 7*s, height: 7*s))
        
        // 放大镜手柄
        path.move(to: CGPoint(x: 14*s, y: 13*s))
        path.addLine(to: CGPoint(x: 16.5*s, y: 15.5*s))
        
        return path
    }
}

// 错误图标：xmark.circle 风格
private struct LogErrorPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        // 外圆
        path.addEllipse(in: CGRect(x: 3*s, y: 3*s, width: 18*s, height: 18*s))
        
        // X 标记
        path.move(to: CGPoint(x: 9*s, y: 9*s))
        path.addLine(to: CGPoint(x: 15*s, y: 15*s))
        
        path.move(to: CGPoint(x: 15*s, y: 9*s))
        path.addLine(to: CGPoint(x: 9*s, y: 15*s))
        
        return path
    }
}

// 网络图标：network 风格（节点连线）
private struct LogNetworkPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        // 中心节点
        path.addEllipse(in: CGRect(x: 10*s, y: 10*s, width: 4*s, height: 4*s))
        
        // 上方节点
        path.addEllipse(in: CGRect(x: 10*s, y: 3*s, width: 4*s, height: 4*s))
        
        // 左下节点
        path.addEllipse(in: CGRect(x: 3*s, y: 17*s, width: 4*s, height: 4*s))
        
        // 右下节点
        path.addEllipse(in: CGRect(x: 17*s, y: 17*s, width: 4*s, height: 4*s))
        
        // 连线：中心到上方
        path.move(to: CGPoint(x: 12*s, y: 10*s))
        path.addLine(to: CGPoint(x: 12*s, y: 7*s))
        
        // 连线：中心到左下
        path.move(to: CGPoint(x: 10.5*s, y: 13.5*s))
        path.addLine(to: CGPoint(x: 6.5*s, y: 17.5*s))
        
        // 连线：中心到右下
        path.move(to: CGPoint(x: 13.5*s, y: 13.5*s))
        path.addLine(to: CGPoint(x: 17.5*s, y: 17.5*s))
        
        return path
    }
}

// 成功图标：checkmark.circle 风格
private struct LogSuccessPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        // 外圆
        path.addEllipse(in: CGRect(x: 3*s, y: 3*s, width: 18*s, height: 18*s))
        
        // 对勾
        path.move(to: CGPoint(x: 8*s, y: 12.5*s))
        path.addLine(to: CGPoint(x: 11*s, y: 15.5*s))
        path.addLine(to: CGPoint(x: 16*s, y: 9*s))
        
        return path
    }
}

// 向下箭头到底线：arrow.down.to.line 风格
private struct ArrowDownToLinePath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        // 向下箭头竖线
        path.move(to: CGPoint(x: 12*s, y: 4*s))
        path.addLine(to: CGPoint(x: 12*s, y: 15*s))
        
        // 箭头两翼
        path.move(to: CGPoint(x: 8*s, y: 12*s))
        path.addLine(to: CGPoint(x: 12*s, y: 16*s))
        path.addLine(to: CGPoint(x: 16*s, y: 12*s))
        
        // 底部横线
        path.move(to: CGPoint(x: 6*s, y: 20*s))
        path.addLine(to: CGPoint(x: 18*s, y: 20*s))
        
        return path
    }
}

// 筛选漏斗图标：三条水平线，从宽到窄
private struct FilterPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        // 顶部最宽线
        path.move(to: CGPoint(x: 4*s, y: 7*s))
        path.addLine(to: CGPoint(x: 20*s, y: 7*s))
        
        // 中间线
        path.move(to: CGPoint(x: 7*s, y: 12*s))
        path.addLine(to: CGPoint(x: 17*s, y: 12*s))
        
        // 底部最窄线
        path.move(to: CGPoint(x: 10*s, y: 17*s))
        path.addLine(to: CGPoint(x: 14*s, y: 17*s))
        
        return path
    }
}

// 麦克风图标：竖直麦克风 + 底部支架
private struct MicrophonePath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        // 麦克风头部（圆角矩形）
        let capsule = CGRect(x: 9*s, y: 3*s, width: 6*s, height: 10*s)
        path.addRoundedRect(in: capsule, cornerSize: CGSize(width: 3*s, height: 3*s))
        
        // 左侧弧线
        path.move(to: CGPoint(x: 6*s, y: 10*s))
        path.addCurve(to: CGPoint(x: 12*s, y: 17*s), control1: CGPoint(x: 6*s, y: 14*s), control2: CGPoint(x: 8.5*s, y: 17*s))
        
        // 右侧弧线
        path.move(to: CGPoint(x: 18*s, y: 10*s))
        path.addCurve(to: CGPoint(x: 12*s, y: 17*s), control1: CGPoint(x: 18*s, y: 14*s), control2: CGPoint(x: 15.5*s, y: 17*s))
        
        // 底部支架
        path.move(to: CGPoint(x: 12*s, y: 17*s))
        path.addLine(to: CGPoint(x: 12*s, y: 21*s))
        
        // 底部横线
        path.move(to: CGPoint(x: 9*s, y: 21*s))
        path.addLine(to: CGPoint(x: 15*s, y: 21*s))
        
        return path
    }
}


// FM 模式切换图标：旋钮 + 刻度线，表示调频/模式切换
private struct FMModePath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        // 外圈（旋钮轮廓）
        path.addEllipse(in: CGRect(x: 4*s, y: 4*s, width: 16*s, height: 16*s))
        
        // 中心点
        path.addEllipse(in: CGRect(x: 10.5*s, y: 10.5*s, width: 3*s, height: 3*s))
        
        // 指针（从中心指向上方，表示当前模式位置）
        path.move(to: CGPoint(x: 12*s, y: 10*s))
        path.addLine(to: CGPoint(x: 12*s, y: 6*s))
        
        // 左刻度
        path.move(to: CGPoint(x: 6.5*s, y: 7*s))
        path.addLine(to: CGPoint(x: 7.5*s, y: 8*s))
        
        // 右刻度
        path.move(to: CGPoint(x: 17.5*s, y: 7*s))
        path.addLine(to: CGPoint(x: 16.5*s, y: 8*s))
        
        // 底部文字线（FM 标识）
        path.move(to: CGPoint(x: 8*s, y: 22*s))
        path.addLine(to: CGPoint(x: 16*s, y: 22*s))
        
        return path
    }
}

// 听歌识曲图标：声波纹 + 音符，表示音乐识别
private struct AudioWavePath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        // 左侧声波弧线（由外到内 3 层）
        path.move(to: CGPoint(x: 3*s, y: 7*s))
        path.addCurve(to: CGPoint(x: 3*s, y: 17*s), control1: CGPoint(x: 0.5*s, y: 10*s), control2: CGPoint(x: 0.5*s, y: 14*s))
        
        path.move(to: CGPoint(x: 6*s, y: 8.5*s))
        path.addCurve(to: CGPoint(x: 6*s, y: 15.5*s), control1: CGPoint(x: 4*s, y: 10.5*s), control2: CGPoint(x: 4*s, y: 13.5*s))
        
        path.move(to: CGPoint(x: 9*s, y: 10*s))
        path.addCurve(to: CGPoint(x: 9*s, y: 14*s), control1: CGPoint(x: 7.5*s, y: 11*s), control2: CGPoint(x: 7.5*s, y: 13*s))
        
        // 右侧音符
        // 音符头（实心椭圆）
        path.addEllipse(in: CGRect(x: 14*s, y: 13*s, width: 4*s, height: 3*s))
        
        // 音符杆
        path.move(to: CGPoint(x: 18*s, y: 14.5*s))
        path.addLine(to: CGPoint(x: 18*s, y: 5*s))
        
        // 音符旗
        path.move(to: CGPoint(x: 18*s, y: 5*s))
        path.addCurve(to: CGPoint(x: 21*s, y: 8*s), control1: CGPoint(x: 20*s, y: 5*s), control2: CGPoint(x: 21*s, y: 6.5*s))
        
        return path
    }
}

// 层叠图标：表示统一悬浮栏（MiniPlayer + TabBar 合一）
private struct LayersPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        // 底层矩形
        path.move(to: CGPoint(x: 4*s, y: 18*s))
        path.addLine(to: CGPoint(x: 20*s, y: 18*s))
        path.addLine(to: CGPoint(x: 20*s, y: 14*s))
        path.addLine(to: CGPoint(x: 4*s, y: 14*s))
        path.closeSubpath()
        
        // 中层矩形
        path.move(to: CGPoint(x: 6*s, y: 12*s))
        path.addLine(to: CGPoint(x: 18*s, y: 12*s))
        path.addLine(to: CGPoint(x: 18*s, y: 8*s))
        path.addLine(to: CGPoint(x: 6*s, y: 8*s))
        path.closeSubpath()
        
        // 顶层矩形
        path.move(to: CGPoint(x: 8*s, y: 6*s))
        path.addLine(to: CGPoint(x: 16*s, y: 6*s))
        
        return path
    }
}

// TabBar 图标：表示经典系统 TabBar
private struct TabBarPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        // 底部栏框架
        let barRect = CGRect(x: 3*s, y: 15*s, width: 18*s, height: 6*s)
        path.addRoundedRect(in: barRect, cornerSize: CGSize(width: 2*s, height: 2*s))
        
        // 四个 tab 点
        path.addEllipse(in: CGRect(x: 5*s, y: 17*s, width: 2*s, height: 2*s))
        path.addEllipse(in: CGRect(x: 9*s, y: 17*s, width: 2*s, height: 2*s))
        path.addEllipse(in: CGRect(x: 13*s, y: 17*s, width: 2*s, height: 2*s))
        path.addEllipse(in: CGRect(x: 17*s, y: 17*s, width: 2*s, height: 2*s))
        
        // 上方内容区域
        path.move(to: CGPoint(x: 5*s, y: 5*s))
        path.addLine(to: CGPoint(x: 19*s, y: 5*s))
        path.addLine(to: CGPoint(x: 19*s, y: 12*s))
        path.addLine(to: CGPoint(x: 5*s, y: 12*s))
        path.closeSubpath()
        
        return path
    }
}

// 极简栏图标：仅 MiniPlayer，无 TabBar
private struct MinimalBarPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        // 单一悬浮条
        let barRect = CGRect(x: 4*s, y: 10*s, width: 16*s, height: 4*s)
        path.addRoundedRect(in: barRect, cornerSize: CGSize(width: 2*s, height: 2*s))
        
        // 播放按钮示意
        path.move(to: CGPoint(x: 7*s, y: 11*s))
        path.addLine(to: CGPoint(x: 9*s, y: 12*s))
        path.addLine(to: CGPoint(x: 7*s, y: 13*s))
        path.closeSubpath()
        
        // 进度条
        path.move(to: CGPoint(x: 11*s, y: 12*s))
        path.addLine(to: CGPoint(x: 17*s, y: 12*s))
        
        return path
    }
}


// 悬浮球图标：圆形 + 中心唱片 + 外圈进度
private struct FloatingBallPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = rect.width / 24.0
        
        // 外圈
        path.addEllipse(in: CGRect(x: 4*s, y: 4*s, width: 16*s, height: 16*s))
        
        // 内圈（唱片）
        path.addEllipse(in: CGRect(x: 8*s, y: 8*s, width: 8*s, height: 8*s))
        
        // 中心点
        path.addEllipse(in: CGRect(x: 11*s, y: 11*s, width: 2*s, height: 2*s))
        
        return path
    }
}
