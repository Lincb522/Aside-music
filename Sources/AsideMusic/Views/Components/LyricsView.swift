import SwiftUI
import Combine

// MARK: - Lyric Parser

struct LyricWord: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let startTime: TimeInterval
    let duration: TimeInterval
}

struct LyricLine: Identifiable, Equatable {
    let id = UUID()
    let time: TimeInterval
    let text: String
    let translation: String?
    var duration: TimeInterval = 0
    var words: [LyricWord] = []
}

@MainActor
class LyricViewModel: ObservableObject {
    static let shared = LyricViewModel()
    
    @Published var lyrics: [LyricLine] = []
    @Published var isLoading = false
    @Published var currentLineIndex: Int = 0
    @Published var hasLyrics = false
    
    @Published var currentLineProgress: Double = 0.0
    
    /// 当前已加载歌词的歌曲 ID（防止重复请求）
    private(set) var currentSongId: Int?
    
    private var cancellables = Set<AnyCancellable>()
    private var translations: [TimeInterval: String] = [:]
    /// 当前歌词请求的会话 ID，防止旧请求回调覆盖新歌词
    private var lyricSessionId: Int = 0
    
    func fetchLyrics(for songId: Int) {
        // 如果已经加载了同一首歌的歌词且有内容，跳过
        guard songId != currentSongId || (!hasLyrics && !isLoading) else { return }
        
        lyricSessionId += 1
        let sessionId = lyricSessionId
        
        currentSongId = songId
        isLoading = true
        lyrics = []
        hasLyrics = false
        currentLineIndex = 0
        currentLineProgress = 0.0
        translations = [:]
        
        APIService.shared.fetchLyric(id: songId)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self = self, self.lyricSessionId == sessionId else { return }
                if case .failure(let error) = completion {
                    AppLogger.error("Failed to fetch lyrics: \(error)")
                    self.isLoading = false
                    // 请求失败时清除 currentSongId，允许下次重试
                    self.currentSongId = nil
                }
            }, receiveValue: { [weak self] response in
                guard let self = self, self.lyricSessionId == sessionId else { return }
                
                if let tlyric = response.tlyric?.lyric {
                    self.parseTranslations(tlyric)
                }
                
                if let yrc = response.yrc?.lyric {
                    self.parseYRC(yrc)
                    self.hasLyrics = !self.lyrics.isEmpty
                } else if let lrc = response.lrc?.lyric {
                    self.parseLyrics(lrc)
                    self.hasLyrics = !self.lyrics.isEmpty
                } else {
                    self.hasLyrics = false
                }
                
                self.isLoading = false
            })
            .store(in: &cancellables)
    }
    
    /// 获取 QQ 音乐歌词
    func fetchQQLyrics(mid: String, songId: Int) {
        // 用 songId 做去重标识
        guard songId != currentSongId || (!hasLyrics && !isLoading) else { return }
        
        lyricSessionId += 1
        let sessionId = lyricSessionId
        
        currentSongId = songId
        isLoading = true
        lyrics = []
        hasLyrics = false
        currentLineIndex = 0
        currentLineProgress = 0.0
        translations = [:]
        
        APIService.shared.fetchQQLyric(mid: mid)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self = self, self.lyricSessionId == sessionId else { return }
                if case .failure(let error) = completion {
                    AppLogger.error("[QQMusic] 获取歌词失败: \(error)")
                    self.isLoading = false
                    // 请求失败时清除 currentSongId，允许下次重试
                    self.currentSongId = nil
                }
            }, receiveValue: { [weak self] response in
                guard let self = self, self.lyricSessionId == sessionId else { return }
                
                if let trans = response.trans {
                    self.parseTranslations(trans)
                }
                
                if let lrc = response.lyric {
                    self.parseLyrics(lrc)
                    self.hasLyrics = !self.lyrics.isEmpty
                } else {
                    self.hasLyrics = false
                }
                
                self.isLoading = false
            })
            .store(in: &cancellables)
    }
    
    private func parseTranslations(_ text: String) {
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let (time, content) = parseLine(line)
            if let time = time, !content.isEmpty {
                translations[time] = content
            }
        }
    }
    
    private func parseYRC(_ text: String) {
        var parsedLines: [LyricLine] = []
        let lines = text.components(separatedBy: .newlines)
        
        for line in lines {
            guard let closeBracket = line.firstIndex(of: "]"),
                  line.hasPrefix("[") else { continue }
            
            let timePart = line[line.index(after: line.startIndex)..<closeBracket]
            let contentPart = line[line.index(after: closeBracket)...]
            
            let times = timePart.components(separatedBy: ",")
            guard times.count >= 2,
                  let startMs = Double(times[0]),
                  let durationMs = Double(times[1]) else { continue }
            
            let startTime = startMs / 1000.0
            let duration = durationMs / 1000.0
            
            var words: [LyricWord] = []
            var plainText = ""
            
            let scanner = Scanner(string: String(contentPart))
            scanner.charactersToBeSkipped = nil
            
            while !scanner.isAtEnd {
                if scanner.scanString("(") != nil {
                    guard let wStartMs = scanner.scanDouble(),
                          let _ = scanner.scanString(","),
                          let wDurMs = scanner.scanDouble(),
                          let _ = scanner.scanString(","),
                          let _ = scanner.scanInt(), // type
                          let _ = scanner.scanString(")") else {
                        break
                    }
                    
                    var wText = ""
                    if let text = scanner.scanUpToString("(") {
                        wText = text
                    } else {
                         wText = String(contentPart.suffix(from: contentPart.index(contentPart.startIndex, offsetBy: scanner.currentIndex.utf16Offset(in: contentPart))))
                    }
                    
                    if wText.isEmpty && !scanner.isAtEnd {
                        if let char = scanner.scanCharacter() {
                            wText = String(char)
                             if let rest = scanner.scanUpToString("(") {
                                 wText += rest
                             }
                        }
                    }

                    
                    let word = LyricWord(text: wText, startTime: wStartMs / 1000.0, duration: wDurMs / 1000.0)
                    words.append(word)
                    plainText += wText
                } else {
                     _ = scanner.scanCharacter()
                }
            }
            
            if words.isEmpty {
                plainText = String(contentPart)
            }
            
            let translation = translations[startTime]
            parsedLines.append(LyricLine(time: startTime, text: plainText, translation: translation, duration: duration, words: words))
        }
        
        self.lyrics = parsedLines.sorted { $0.time < $1.time }
    }
    
    private func parseLyrics(_ text: String) {
        var parsedLines: [LyricLine] = []
        let lines = text.components(separatedBy: .newlines)
        
        for line in lines {
            let (time, content) = parseLine(line)
            if let time = time {
                let translation = translations[time]
                parsedLines.append(LyricLine(time: time, text: content, translation: translation))
            }
        }
        
        parsedLines.sort { $0.time < $1.time }
        
        for i in 0..<parsedLines.count {
            if i < parsedLines.count - 1 {
                parsedLines[i].duration = parsedLines[i+1].time - parsedLines[i].time
            } else {
                parsedLines[i].duration = 5.0
            }
        }
        
        self.lyrics = parsedLines
    }
    
    private func parseLine(_ line: String) -> (TimeInterval?, String) {
        guard let bracketCloseIndex = line.firstIndex(of: "]") else { return (nil, line) }
        
        let timeString = String(line[line.index(after: line.startIndex)..<bracketCloseIndex])
        let content = String(line[line.index(after: bracketCloseIndex)...]).trimmingCharacters(in: .whitespaces)
        
        let timeParts = timeString.components(separatedBy: ":")
        guard timeParts.count >= 2,
              let min = Double(timeParts[0]),
              let sec = Double(timeParts[1]) else {
            return (nil, content)
        }
        
        let totalTime = min * 60 + sec
        return (totalTime, content)
    }
    
    func updateCurrentTime(_ time: TimeInterval) {
        guard !lyrics.isEmpty else { return }
        
        if let index = lyrics.lastIndex(where: { $0.time <= time }) {
            if index != currentLineIndex {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentLineIndex = index
                }
            }
            
            let line = lyrics[index]
            let elapsed = time - line.time
            currentLineProgress = min(max(elapsed / line.duration, 0.0), 1.0)
            
        } else {
            currentLineIndex = 0
            currentLineProgress = 0.0
        }
    }
}

// MARK: - Karaoke Components

struct KaraokeWordView: View {
    let word: LyricWord
    let currentTime: TimeInterval
    var font: Font = .rounded(size: 26, weight: .bold)
    var activeColor: Color = .asideTextPrimary
    var inactiveColor: Color = .gray.opacity(0.3)
    
    var body: some View {
        let progress = calculateProgress()
        
        Text(word.text)
            .font(font)
            .foregroundColor(inactiveColor)
            .overlay(
                GeometryReader { geo in
                    Text(word.text)
                        .font(font)
                        .foregroundColor(activeColor)
                        .frame(width: geo.size.width * progress, alignment: .leading)
                        .clipped()
                        .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.9, blendDuration: 0.1), value: progress)
                }
            )
            .fixedSize(horizontal: true, vertical: false)
    }
    
    func calculateProgress() -> CGFloat {
        if currentTime < word.startTime { return 0 }
        if currentTime >= word.startTime + word.duration { return 1 }
        
        let rawProgress = CGFloat((currentTime - word.startTime) / word.duration)
        return rawProgress
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 4
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrangeSubviews(proposal: proposal, subviews: subviews)
        let maxWidth = rows.map(\.maxX).max() ?? 0
        let totalHeight = rows.last.map { $0.y + $0.height } ?? 0
        return CGSize(width: maxWidth, height: totalHeight)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrangeSubviews(proposal: proposal, subviews: subviews)
        for row in rows {
            for item in row.items {
                item.view.place(at: CGPoint(x: bounds.minX + item.x, y: bounds.minY + row.y), proposal: .unspecified)
            }
        }
    }
    
    struct Row {
        var y: CGFloat
        var height: CGFloat
        var items: [Item]
        var maxX: CGFloat = 0
    }
    
    struct Item {
        var view: LayoutSubview
        var x: CGFloat
    }
    
    func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var currentRowY: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        var currentX: CGFloat = 0
        var currentItems: [Item] = []
        
        let maxWidth = proposal.width ?? .infinity
        
        for view in subviews {
            let viewSize = view.sizeThatFits(.unspecified)
            
            if currentX + viewSize.width > maxWidth && !currentItems.isEmpty {
                rows.append(Row(y: currentRowY, height: currentRowHeight, items: currentItems, maxX: currentX - spacing))
                currentRowY += currentRowHeight + spacing
                currentX = 0
                currentRowHeight = 0
                currentItems = []
            }
            
            currentItems.append(Item(view: view, x: currentX))
            currentX += viewSize.width + spacing
            currentRowHeight = max(currentRowHeight, viewSize.height)
        }
        
        if !currentItems.isEmpty {
            rows.append(Row(y: currentRowY, height: currentRowHeight, items: currentItems, maxX: currentX - spacing))
        }
        
        return rows
    }
}

struct KaraokeLineView: View {
    let line: LyricLine
    let isCurrent: Bool
    let currentTime: TimeInterval
    let progress: Double
    let showTranslation: Bool
    let enableKaraoke: Bool
    
    @Environment(\.colorScheme) private var colorScheme
    
    // 大字报主题判断
    private var isPoster: Bool {
        PlayerThemeManager.shared.currentTheme == .poster
    }
    
    // 水韵主题判断
    private var isAqua: Bool {
        PlayerThemeManager.shared.currentTheme == .aqua
    }
    
    // 字魂半天云魅黑手书字体
    private let posterFont = "zihunbantianyunmeiheishoushu"
    
    // 文道泡泡体（水韵主题）
    private let aquaFont = "WDPPT"
    
    // 当前行字体
    private var currentLineFont: Font {
        if isPoster {
            return .custom(posterFont, size: 28)
        } else if isAqua {
            return .custom(aquaFont, size: 26)
        }
        return .rounded(size: 26, weight: .bold)
    }
    
    // 非当前行字体
    private var normalLineFont: Font {
        if isPoster {
            return .custom(posterFont, size: 16)
        } else if isAqua {
            return .custom(aquaFont, size: 16)
        }
        return .rounded(size: 16, weight: .medium)
    }
    
    // 翻译字体
    private func translationFont(isCurrent: Bool) -> Font {
        if isPoster {
            return .custom(posterFont, size: isCurrent ? 16 : 12)
        } else if isAqua {
            return .custom(aquaFont, size: isCurrent ? 15 : 13)
        }
        return .rounded(size: isCurrent ? 15 : 13, weight: .regular)
    }
    
    // 大字报当前行颜色
    private var posterActiveColor: Color {
        Color(hex: "FF0000")
    }
    
    var body: some View {
        VStack(spacing: isPoster ? 4 : 6) {
            if isPoster {
                // 大字报歌词 — 黑条从左滑入
                posterLyricContent
            } else {
                // 默认歌词样式
                defaultLyricContent
            }
            
            // 翻译
            if showTranslation, let trans = line.translation, !trans.isEmpty {
                if isPoster {
                    let transColor: Color = isCurrent
                        ? (colorScheme == .dark ? .black.opacity(0.7) : .white.opacity(0.7))
                        : .asideTextPrimary.opacity(0.12)
                    Text(trans)
                        .font(translationFont(isCurrent: isCurrent))
                        .foregroundColor(transColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, isCurrent ? 12 : 0)
                        .padding(.vertical, isCurrent ? 6 : 0)
                        .background(isCurrent ? Color(hex: "FF0000").opacity(0.8) : .clear)
                } else {
                    Text(trans)
                        .font(translationFont(isCurrent: isCurrent))
                        .foregroundColor(isCurrent ? .asideTextPrimary.opacity(0.8) : .gray.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .blur(radius: isCurrent ? 0 : 0.3)
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isCurrent)
                        .transition(.opacity)
                }
            }
        }
    }
    
    // MARK: - 大字报歌词样式
    @ViewBuilder
    private var posterLyricContent: some View {
        if isCurrent && !line.text.trimmingCharacters(in: .whitespaces).isEmpty {
            // 当前行 — 黑条贴左边缘，和屏幕左边连成一体，支持自动换行
            HStack(spacing: 0) {
                currentPosterLine
                    .padding(.leading, 32)
                    .padding(.trailing, 16)
                    .padding(.vertical, 12)
                    .background(Color.asideTextPrimary)
                
                Spacer(minLength: 0)
            }
            .padding(.leading, -32)
            .transition(.asymmetric(
                insertion: .move(edge: .leading),
                removal: .opacity
            ))
            .id("poster_\(line.time)")
        } else {
            // 非当前行
            Text(line.text)
                .font(normalLineFont)
                .foregroundColor(.asideTextPrimary.opacity(0.15))
                .tracking(1)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    /// 大字报当前行内容 — 使用字魂字体，支持自动换行
    @ViewBuilder
    private var currentPosterLine: some View {
        // 大字报当前行：背景是 fg（深色=白，浅色=黑），文字需要反色
        let invertedFg: Color = colorScheme == .dark ? .black : .white
        
        Text(line.text)
            .font(currentLineFont)
            .foregroundColor(invertedFg)
            .tracking(-1)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - 默认歌词样式
    @ViewBuilder
    private var defaultLyricContent: some View {
        if isCurrent {
            if enableKaraoke && !line.words.isEmpty {
                if #available(iOS 16.0, macOS 13.0, *) {
                    FlowLayout(spacing: 0) {
                        ForEach(line.words) { word in
                            KaraokeWordView(word: word, currentTime: currentTime, font: currentLineFont)
                        }
                    }
                    .scaleEffect(1.05)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isCurrent)
                    .transition(.opacity)
                } else {
                    constructYRCText()
                        .multilineTextAlignment(.center)
                        .scaleEffect(1.05)
                }
            } else if enableKaraoke {
                constructFallbackText()
                    .multilineTextAlignment(.center)
                    .scaleEffect(1.05)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isCurrent)
            } else {
                Text(line.text)
                    .font(currentLineFont)
                    .foregroundColor(.asideTextPrimary)
                    .multilineTextAlignment(.center)
                    .scaleEffect(1.05)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isCurrent)
            }
        } else {
            Text(line.text)
                .font(normalLineFont)
                .foregroundColor(.gray.opacity(0.6))
                .multilineTextAlignment(.center)
                .blur(radius: 0.5)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isCurrent)
        }
    }
    
    private func constructYRCText() -> Text {
        var combined = Text("")
        for word in line.words {
            let isSung = currentTime >= (word.startTime + word.duration)
            let isSinging = currentTime >= word.startTime && currentTime < (word.startTime + word.duration)
            let color: Color = (isSung || isSinging) ? .asideTextPrimary : .gray.opacity(0.3)
            combined = combined + Text(word.text)
                .font(currentLineFont)
                .foregroundColor(color)
        }
        return combined
    }
    
    private func constructFallbackText() -> Text {
        let chars = Array(line.text)
        let threshold = Int(Double(chars.count) * progress)
        
        var combined = Text("")
        for (index, char) in chars.enumerated() {
            let isActive = index <= threshold && progress > 0
            let color: Color = isActive ? .asideTextPrimary : .gray.opacity(0.3)
            combined = combined + Text(String(char))
                .font(currentLineFont)
                .foregroundColor(color)
        }
        return combined
    }
    
}

struct LyricsView: View {
    let song: Song
    var onBackgroundTap: (() -> Void)?
    @ObservedObject var player = PlayerManager.shared
    @ObservedObject private var viewModel = LyricViewModel.shared
    
    @State private var isUserScrolling = false
    @State private var userScrollTimer: Timer?
    
    @AppStorage("showTranslation") var showTranslation: Bool = true
    @AppStorage("enableKaraoke") var enableKaraoke: Bool = true
    
    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .asideTextPrimary))
            } else if !viewModel.hasLyrics {
                Text("No Lyrics Available")
                    .font(.rounded(size: 18, weight: .medium))
                    .foregroundColor(.asideTextPrimary.opacity(0.6))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onBackgroundTap?()
                    }
            } else {
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 24) {
                            Color.clear.frame(height: 200)
                            
                            ForEach(Array(viewModel.lyrics.enumerated()), id: \.element.id) { index, line in
                                Button(action: {
                                    HapticManager.shared.light()
                                    player.seek(to: line.time)
                                }) {
                                    KaraokeLineView(
                                        line: line,
                                        isCurrent: index == viewModel.currentLineIndex,
                                        currentTime: player.currentTime,
                                        progress: index == viewModel.currentLineIndex ? viewModel.currentLineProgress : 0.0,
                                        showTranslation: showTranslation,
                                        enableKaraoke: enableKaraoke
                                    )
                                    .frame(maxWidth: .infinity)
                                    .padding(.horizontal, 32)
                                    .animation(.easeInOut(duration: 0.3), value: viewModel.currentLineIndex)
                                    .id(index)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            
                            Color.clear.frame(height: 300)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }

                    .simultaneousGesture(
                        DragGesture().onChanged { _ in
                            isUserScrolling = true
                            resetScrollTimer()
                        }
                    )
                    .onChange(of: viewModel.currentLineIndex) { _, newIndex in
                        if !isUserScrolling {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                proxy.scrollTo(newIndex, anchor: .center)
                            }
                        }
                    }
                    .onTapGesture {
                        isUserScrolling = false
                        onBackgroundTap?()
                    }
                    .onAppear {
                        // 视图出现时立即无动画跳转到当前行，做到无缝定位
                        isUserScrolling = false
                        proxy.scrollTo(viewModel.currentLineIndex, anchor: .center)
                    }
                }
                .mask(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black, location: 0.15),
                            .init(color: .black, location: 0.85),
                            .init(color: .clear, location: 1.0)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                
            }
        }
        .onAppear {
            // 确保歌词已加载（如果还没加载的话），区分来源
            if viewModel.currentSongId != song.id {
                if song.isQQMusic, let mid = song.qqMid {
                    viewModel.fetchQQLyrics(mid: mid, songId: song.id)
                } else {
                    viewModel.fetchLyrics(for: song.id)
                }
            }
        }
    }
    
    private func resetScrollTimer() {
        userScrollTimer?.invalidate()
        userScrollTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            withAnimation {
                isUserScrolling = false
            }
        }
    }
}
