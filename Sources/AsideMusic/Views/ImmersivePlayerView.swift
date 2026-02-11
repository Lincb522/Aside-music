import SwiftUI

struct ImmersivePlayerView: View {
    @ObservedObject var player = PlayerManager.shared
    @StateObject private var lyricVM = LyricViewModel()
    @Environment(\.dismiss) var dismiss
    
    @AppStorage("showTranslation") var showTranslation: Bool = true
    
    @State private var showControls = false
    @State private var hideControlsTimer: Timer?
    @State private var isDraggingProgress = false
    @State private var dragTimeValue: Double = 0
    
    @State private var currentLineId: Int = -1
    @State private var wordFragments: [WordFragment] = []
    @State private var visibleCount: Int = 0
    @State private var wordTimer: Timer?
    @State private var flashTrigger: Bool = false
    
    @State private var screenFlash: Bool = false
    
    // MARK: - 词片段模型
    
    struct WordFragment: Identifiable {
        let id = UUID()
        let text: String
        let fontSize: CGFloat
        let fontWeight: Font.Weight
        let x: CGFloat          // 0~1 归一化位置
        let y: CGFloat
        let rotation: Double
        let delay: Double        // 出现延迟
        let isAccent: Bool       // 是否重点词（超大）
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()
                
                if screenFlash {
                    Color.white.opacity(0.08)
                        .ignoresSafeArea()
                        .transition(.opacity)
                }
                
                wordFlashLayer(geo: geo)
                
                translationLayer
                
                if showControls {
                    controlsOverlay(geo: geo)
                        .transition(.opacity)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.15)) {
                    showControls.toggle()
                }
                if showControls { scheduleHideControls() }
            }
        }
        .ignoresSafeArea()
        .statusBar(hidden: true)
        .persistentSystemOverlays(.hidden)
        .onAppear {
            player.isTabBarHidden = true
            // 进入横屏沉浸模式
            OrientationManager.shared.enterLandscape()
            if let song = player.currentSong {
                lyricVM.fetchLyrics(for: song.id)
            }
        }
        .onDisappear {
            player.isTabBarHidden = false
            // 退出时恢复竖屏
            OrientationManager.shared.exitLandscape()
            hideControlsTimer?.invalidate()
            wordTimer?.invalidate()
        }
        .onChange(of: player.currentSong?.id) { _, newId in
            if let id = newId {
                lyricVM.fetchLyrics(for: id)
                currentLineId = -1
                wordFragments = []
                visibleCount = 0
            }
        }
        .onChange(of: player.currentTime) { _, time in
            lyricVM.updateCurrentTime(time)
        }
        .onChange(of: lyricVM.currentLineIndex) { _, newIndex in
            if newIndex != currentLineId {
                currentLineId = newIndex
                triggerWordFlash(for: newIndex)
            }
        }
    }
    
    // MARK: - 逐词砸入层
    
    private func wordFlashLayer(geo: GeometryProxy) -> some View {
        ZStack {
            ForEach(Array(wordFragments.enumerated()), id: \.element.id) { index, frag in
                if index < visibleCount {
                    Text(frag.text)
                        .font(.system(
                            size: frag.fontSize,
                            weight: frag.fontWeight,
                            design: .rounded
                        ))
                        .foregroundColor(.white)
                        .shadow(color: .white.opacity(frag.isAccent ? 0.3 : 0.1), radius: frag.isAccent ? 20 : 8)
                        .rotationEffect(.degrees(frag.rotation))
                        .position(
                            x: frag.x * geo.size.width,
                            y: frag.y * geo.size.height
                        )
                        .transition(
                            .asymmetric(
                                insertion: .scale(scale: 2.5)
                                    .combined(with: .opacity),
                                removal: .opacity.animation(.easeOut(duration: 0.05))
                            )
                        )
                        .animation(
                            .spring(response: 0.12, dampingFraction: 0.6),
                            value: visibleCount
                        )
                }
            }
        }
    }
    
    // MARK: - 翻译层
    
    private var translationLayer: some View {
        VStack {
            Spacer()
            if showTranslation,
               currentLineId >= 0,
               currentLineId < lyricVM.lyrics.count,
               let trans = lyricVM.lyrics[currentLineId].translation,
               !trans.isEmpty {
                Text(trans)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.3))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 100)
                    .id(currentLineId)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.2), value: currentLineId)
            }
        }
    }
    
    // MARK: - 快闪触发器
    
    private func triggerWordFlash(for lineIndex: Int) {
        wordTimer?.invalidate()
        
        guard lineIndex >= 0, lineIndex < lyricVM.lyrics.count else {
            wordFragments = []
            visibleCount = 0
            return
        }
        
        let text = lyricVM.lyrics[lineIndex].text
        let words = splitForFlash(text)
        
        let lineDuration: Double
        if lineIndex + 1 < lyricVM.lyrics.count {
            lineDuration = max(lyricVM.lyrics[lineIndex + 1].time - lyricVM.lyrics[lineIndex].time, 0.5)
        } else {
            lineDuration = 3.0
        }
        
        let fragments = generateLayout(words: words)
        
        withAnimation(.easeOut(duration: 0.06)) {
            screenFlash = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            withAnimation(.easeOut(duration: 0.1)) {
                screenFlash = false
            }
        }
        
        withAnimation(.easeOut(duration: 0.05)) {
            visibleCount = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            wordFragments = fragments
            visibleCount = 0
            
            let wordCount = fragments.count
            guard wordCount > 0 else { return }
            
            let totalAnimTime = lineDuration * 0.7
            let interval = min(totalAnimTime / Double(wordCount), 0.25)
            
            var currentWord = 0
            
            withAnimation(.spring(response: 0.12, dampingFraction: 0.55)) {
                visibleCount = 1
            }
            currentWord = 1
            
            if wordCount > 1 {
                wordTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
                    guard currentWord < wordCount else {
                        timer.invalidate()
                        return
                    }
                    withAnimation(.spring(response: 0.12, dampingFraction: 0.55)) {
                        visibleCount = currentWord + 1
                    }
                    currentWord += 1
                }
            }
        }
    }
    
    // MARK: - 分词（为快闪优化）
    
    private func splitForFlash(_ text: String) -> [String] {
        let isChinese = text.unicodeScalars.contains { $0.value >= 0x4E00 && $0.value <= 0x9FFF }
        
        if isChinese {
            // 中文：2~4字一组，短句不拆
            let chars = Array(text)
            if chars.count <= 4 { return [text] }
            
            var result: [String] = []
            let chunkSize: Int
            if chars.count <= 8 {
                chunkSize = 2
            } else if chars.count <= 14 {
                chunkSize = 3
            } else {
                chunkSize = 4
            }
            
            var i = 0
            while i < chars.count {
                let end = min(i + chunkSize, chars.count)
                result.append(String(chars[i..<end]))
                i = end
            }
            return result
        } else {
            // 英文：按空格分词，短词合并
            let rawWords = text.components(separatedBy: " ").filter { !$0.isEmpty }
            if rawWords.count <= 2 { return rawWords.isEmpty ? [text] : rawWords }
            
            var result: [String] = []
            var buffer = ""
            for word in rawWords {
                if buffer.isEmpty {
                    buffer = word
                } else if buffer.count + word.count < 8 {
                    buffer += " " + word
                } else {
                    result.append(buffer)
                    buffer = word
                }
            }
            if !buffer.isEmpty { result.append(buffer) }
            return result
        }
    }
    
    // MARK: - 布局生成器（VJ 风格）
    
    private func generateLayout(words: [String]) -> [WordFragment] {
        let count = words.count
        guard count > 0 else { return [] }
        
        if count == 1 {
            return [WordFragment(
                text: words[0],
                fontSize: CGFloat.random(in: 72...100),
                fontWeight: .black,
                x: 0.5,
                y: CGFloat.random(in: 0.38...0.55),
                rotation: Double.random(in: -3...3),
                delay: 0,
                isAccent: true
            )]
        }
        
        var fragments: [WordFragment] = []
        
        let accentIndex = Int.random(in: 0..<count)
        
        let positions: [(x: ClosedRange<CGFloat>, y: ClosedRange<CGFloat>)] = [
            (0.15...0.85, 0.15...0.35),
            (0.15...0.85, 0.35...0.55),
            (0.15...0.85, 0.55...0.75),
            (0.10...0.45, 0.25...0.65),
            (0.55...0.90, 0.25...0.65),
        ]
        
        for (i, word) in words.enumerated() {
            let isAccent = i == accentIndex
            let posArea = positions[i % positions.count]
            
            let fontSize: CGFloat
            if isAccent {
                fontSize = CGFloat.random(in: 64...90)
            } else if word.count <= 2 {
                fontSize = CGFloat.random(in: 36...52)
            } else {
                fontSize = CGFloat.random(in: 28...44)
            }
            
            let weight: Font.Weight = isAccent
                ? .black
                : [.bold, .heavy, .black, .semibold].randomElement()!
            
            fragments.append(WordFragment(
                text: word,
                fontSize: fontSize,
                fontWeight: weight,
                x: CGFloat.random(in: posArea.x),
                y: CGFloat.random(in: posArea.y),
                rotation: isAccent
                    ? Double.random(in: -5...5)
                    : Double.random(in: -15...15),
                delay: Double(i) * 0.1,
                isAccent: isAccent
            ))
        }
        
        return fragments
    }
    
    // MARK: - 控制层
    
    private func controlsOverlay(geo: GeometryProxy) -> some View {
        VStack {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                
                Spacer()
                
                VStack(spacing: 2) {
                    Text(player.currentSong?.name ?? "")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                    Text(player.currentSong?.artistName ?? "")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                        .lineLimit(1)
                }
                
                Spacer()
                
                Color.clear.frame(width: 36, height: 36)
            }
            .padding(.horizontal, 24)
            .padding(.top, DeviceLayout.headerTopPadding)
            
            Spacer()
            
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Text(formatTime(isDraggingProgress ? dragTimeValue : player.currentTime))
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .foregroundColor(.white.opacity(0.5))
                    
                    GeometryReader { barGeo in
                        let progress = player.duration > 0
                            ? (isDraggingProgress ? dragTimeValue : player.currentTime) / player.duration
                            : 0
                        
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.15)).frame(height: 3)
                            Capsule().fill(Color.white.opacity(0.8))
                                .frame(width: barGeo.size.width * CGFloat(min(max(progress, 0), 1)), height: 3)
                        }
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    isDraggingProgress = true
                                    let p = min(max(value.location.x / barGeo.size.width, 0), 1)
                                    dragTimeValue = Double(p) * player.duration
                                }
                                .onEnded { value in
                                    let p = min(max(value.location.x / barGeo.size.width, 0), 1)
                                    player.seek(to: Double(p) * player.duration)
                                    isDraggingProgress = false
                                }
                        )
                    }
                    .frame(height: 16)
                    
                    Text(formatTime(player.duration))
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .foregroundColor(.white.opacity(0.5))
                }
                
                HStack(spacing: 48) {
                    Button(action: { player.previous() }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Button(action: { player.togglePlayPause() }) {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                            .frame(width: 52, height: 52)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Circle())
                    }
                    
                    Button(action: { player.next() }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, geo.safeAreaInsets.bottom + 12)
        }
        .background(
            LinearGradient(
                colors: [.black.opacity(0.6), .clear, .clear, .black.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
        )
    }
    
    // MARK: - 工具方法
    
    private func scheduleHideControls() {
        hideControlsTimer?.invalidate()
        hideControlsTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.2)) { showControls = false }
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite else { return "0:00" }
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
