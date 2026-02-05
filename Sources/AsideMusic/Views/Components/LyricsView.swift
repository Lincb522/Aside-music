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
    var duration: TimeInterval = 0 // Duration of this line
    var words: [LyricWord] = [] // YRC Words
}

class LyricViewModel: ObservableObject {
    @Published var lyrics: [LyricLine] = []
    @Published var isLoading = false
    @Published var currentLineIndex: Int = 0
    @Published var hasLyrics = false
    
    // For Karaoke Effect (Fallback)
    @Published var currentLineProgress: Double = 0.0
    
    private var cancellables = Set<AnyCancellable>()
    private var translations: [TimeInterval: String] = [:]
    
    func fetchLyrics(for songId: Int) {
        isLoading = true
        lyrics = []
        hasLyrics = false
        currentLineIndex = 0
        currentLineProgress = 0.0
        translations = [:]
        
        APIService.shared.fetchLyric(id: songId)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    print("Failed to fetch lyrics: \(error)")
                    self?.isLoading = false
                }
            }, receiveValue: { [weak self] response in
                guard let self = self else { return }
                
                // Parse Translations first
                if let tlyric = response.tlyric?.lyric {
                    self.parseTranslations(tlyric)
                }
                
                // Parse Lyrics (Priority: YRC > LRC)
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
        // YRC Format: [start,duration](start,duration,0)Word(start,duration,0)Word...
        // Assuming JSON-like structure inside string or standard YRC
        // Netease YRC is often just text with tags.
        
        var parsedLines: [LyricLine] = []
        let lines = text.components(separatedBy: .newlines)
        
        for line in lines {
            // Very basic YRC parser for Netease
            // Check for line timing [123,456]
            // Note: Netease YRC usually uses JSON format in 'yrc' field, 
            // but sometimes it's a string with [time] tags.
            // Let's assume standard YRC string format for now.
            
            // If the format is JSON string, we might need different parsing.
            // But based on typical API wrappers, it returns a string similar to LRC but with word tags.
            
            // Example: [1000,2000](1000,200,0)W(1200,200,0)o(1400,200,0)rd
            
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
            
            // Simple scanner for (s,d,t)Word
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
                        // Read until end if no more (
                         wText = String(contentPart.suffix(from: contentPart.index(contentPart.startIndex, offsetBy: scanner.currentIndex.utf16Offset(in: contentPart))))
                         // Reset scanner to end to avoid loop? 
                         // Actually scanUpToString reads until it finds ( or end.
                         // But if no (, it reads nothing? No, it reads everything.
                         // Wait, scanUpToString returns string up to target.
                         // If target not found, it returns the rest of string.
                    }
                    
                    // Workaround for scanner behavior
                    if wText.isEmpty && !scanner.isAtEnd {
                        // consume one char?
                        if let char = scanner.scanCharacter() {
                            wText = String(char)
                            // read rest?
                             if let rest = scanner.scanUpToString("(") {
                                 wText += rest
                             }
                        }
                    }

                    
                    let word = LyricWord(text: wText, startTime: wStartMs / 1000.0, duration: wDurMs / 1000.0)
                    words.append(word)
                    plainText += wText
                } else {
                    // Skip or read plain text
                     _ = scanner.scanCharacter()
                }
            }
            
            if words.isEmpty {
                plainText = String(contentPart)
            }
            
            let translation = translations[startTime] // Approx match might be needed
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
        
        // Sort lines
        parsedLines.sort { $0.time < $1.time }
        
        // Calculate durations
        for i in 0..<parsedLines.count {
            if i < parsedLines.count - 1 {
                parsedLines[i].duration = parsedLines[i+1].time - parsedLines[i].time
            } else {
                parsedLines[i].duration = 5.0 // Default duration for last line
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
        
        // Find the last line that has start time <= current time
        if let index = lyrics.lastIndex(where: { $0.time <= time }) {
            if index != currentLineIndex {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentLineIndex = index
                }
            }
            
            // Calculate progress for current line (Fallback)
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
    
    var body: some View {
        let progress = calculateProgress()
        
        Text(word.text)
            .font(.rounded(size: 26, weight: .bold)) // Slightly smaller than 28, but bigger than 20
            .foregroundColor(.gray.opacity(0.3)) // Background
            .overlay(
                GeometryReader { geo in
                    Text(word.text)
                        .font(.rounded(size: 26, weight: .bold))
                        .foregroundColor(.black) // Foreground Color (Active)
                        .frame(width: geo.size.width * progress, alignment: .leading)
                        .clipped()
                        .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.9, blendDuration: 0.1), value: progress) // Fluid liquid effect
                }
            )
            .fixedSize(horizontal: true, vertical: false)
    }
    
    func calculateProgress() -> CGFloat {
        if currentTime < word.startTime { return 0 }
        if currentTime >= word.startTime + word.duration { return 1 }
        
        // Ease In Out for smoother filling effect inside the word
        // Or keep linear for accuracy.
        // Let's try a slight ease out to make it feel like "liquid filling"
        let rawProgress = CGFloat((currentTime - word.startTime) / word.duration)
        return rawProgress
    }
}

// Simple FlowLayout to handle word wrapping
struct FlowLayout: Layout {
    var spacing: CGFloat = 4
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrangeSubviews(proposal: proposal, subviews: subviews)
        return rows.last?.maxY ?? .zero
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
        var maxY: CGSize { CGSize(width: 0, height: y + height) }
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
                // New Row
                rows.append(Row(y: currentRowY, height: currentRowHeight, items: currentItems))
                currentRowY += currentRowHeight
                currentX = 0
                currentRowHeight = 0
                currentItems = []
            }
            
            currentItems.append(Item(view: view, x: currentX))
            currentX += viewSize.width + spacing
            currentRowHeight = max(currentRowHeight, viewSize.height)
        }
        
        if !currentItems.isEmpty {
            rows.append(Row(y: currentRowY, height: currentRowHeight, items: currentItems))
        }
        
        return rows
    }
}

struct KaraokeLineView: View {
    let line: LyricLine
    let isCurrent: Bool
    let currentTime: TimeInterval
    let progress: Double // Fallback progress
    let showTranslation: Bool
    let enableKaraoke: Bool // New Prop
    
    var body: some View {
        VStack(spacing: 6) {
            if isCurrent {
                if enableKaraoke && !line.words.isEmpty {
                    // Real Karaoke Mode (YRC) with Smooth Filling
                    if #available(iOS 16.0, macOS 13.0, *) {
                        FlowLayout(spacing: 0) {
                            ForEach(line.words) { word in
                                KaraokeWordView(word: word, currentTime: currentTime)
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
                } else {
                    // Fallback Mode (Linear) - Also used when Karaoke is disabled but line is active
                    // If enableKaraoke is false, we still want highlight but maybe not word-by-word if YRC exists?
                    // Actually, if karaoke is disabled, users usually expect just line highlight, not word filling.
                    // But here 'progress' is linear fallback.
                    
                    if enableKaraoke {
                        constructFallbackText()
                            .multilineTextAlignment(.center)
                            .scaleEffect(1.05)
                            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isCurrent)
                    } else {
                        // Simple Highlight without progress filling
                        Text(line.text)
                            .font(.rounded(size: 26, weight: .bold)) // Match size
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                            .scaleEffect(1.05)
                            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isCurrent)
                    }
                }
            } else {
                Text(line.text)
                    .font(.rounded(size: 16, weight: .medium)) // Reduced from 18
                    .foregroundColor(.gray.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .blur(radius: 0.5)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isCurrent)
            }
            
            if showTranslation, let trans = line.translation, !trans.isEmpty {
                Text(trans)
                    .font(.rounded(size: isCurrent ? 15 : 13, weight: .regular)) // Reduced
                    .foregroundColor(isCurrent ? .black.opacity(0.8) : .gray.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .blur(radius: isCurrent ? 0 : 0.3)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isCurrent)
                    .transition(.opacity)
            }
        }
    }
    
    private func constructYRCText() -> Text {
        var combined = Text("")
        for word in line.words {
            let isSung = currentTime >= (word.startTime + word.duration)
            let isSinging = currentTime >= word.startTime && currentTime < (word.startTime + word.duration)
            let color: Color = (isSung || isSinging) ? .black : .gray.opacity(0.3)
            combined = combined + Text(word.text)
                .font(.rounded(size: 26, weight: .bold)) // Match word view size
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
            let color: Color = isActive ? .black : .gray.opacity(0.3)
            combined = combined + Text(String(char))
                .font(.rounded(size: 26, weight: .bold)) // Match word view size
                .foregroundColor(color)
        }
        return combined
    }
}

struct LyricsView: View {
    let song: Song
    var onBackgroundTap: (() -> Void)? // Added callback
    @ObservedObject var player = PlayerManager.shared
    @StateObject private var viewModel = LyricViewModel()
    
    // Auto-scroll state
    @State private var isUserScrolling = false
    @State private var userScrollTimer: Timer?
    
    // Settings
    @AppStorage("showTranslation") var showTranslation: Bool = true
    @AppStorage("enableKaraoke") var enableKaraoke: Bool = true
    
    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            } else if !viewModel.hasLyrics {
                Text("No Lyrics Available")
                    .font(.rounded(size: 18, weight: .medium))
                    .foregroundColor(.black.opacity(0.6))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onBackgroundTap?()
                    }
            } else {
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 24) {
                            // Top padding
                            Color.clear.frame(height: 200)
                            
                            ForEach(Array(viewModel.lyrics.enumerated()), id: \.element.id) { index, line in
                                Button(action: {
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
                                    .id(index) // For scroll to
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            
                            // Bottom padding
                            Color.clear.frame(height: 300)
                        }
                        .frame(maxWidth: .infinity) // Ensure VStack fills width
                        .contentShape(Rectangle()) // Make empty space tappable
                    }
                    // Detect Scroll Drag
                    .simultaneousGesture(
                        DragGesture().onChanged { _ in
                            isUserScrolling = true
                            resetScrollTimer()
                        }
                    )
                    .onChange(of: viewModel.currentLineIndex) { newIndex in
                        if !isUserScrolling {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                proxy.scrollTo(newIndex, anchor: .center)
                            }
                        }
                    }
                    .onTapGesture {
                        // Resume auto scroll on tap AND trigger background tap
                        isUserScrolling = false
                        onBackgroundTap?()
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
            viewModel.fetchLyrics(for: song.id)
        }
        .onChange(of: song.id) { newId in
            viewModel.fetchLyrics(for: newId)
        }
        .onChange(of: player.currentTime) { time in
            viewModel.updateCurrentTime(time)
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
