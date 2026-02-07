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
        
        case history
        case playCircle
        case warning
        case personEmpty
        case playNext
        case add
        case addToQueue
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
        case .back, .close, .chevronRight, .xmark, .list, .more, .pause, .next, .previous, .shuffle, .refresh, .repeatMode, .repeatOne, .add, .playNext, .addToQueue:
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
        case .history:      return AnyShape(HistoryPath())
        case .playCircle:   return AnyShape(PlayCirclePath())
        case .warning:      return AnyShape(WarningPath())
        case .personEmpty:  return AnyShape(PersonEmptyPath())
        case .playNext:     return AnyShape(PlayNextPath())
        case .add:          return AnyShape(AddPath())
        case .addToQueue:   return AnyShape(AddToQueuePath())
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
        var path = Path()
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
