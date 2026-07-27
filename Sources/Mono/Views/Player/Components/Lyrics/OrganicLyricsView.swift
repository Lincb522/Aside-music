import SwiftUI
import Combine

struct OrganicGlyph: Identifiable {
    let id = UUID()
    let char: String
    let startTime: TimeInterval
    let duration: TimeInterval
    let globalIndex: Int
    let wordIndex: Int
}

struct OrganicWordGroup: Identifiable {
    let id = UUID()
    let glyphs: [OrganicGlyph]
}

// MARK: - Organic Lyrics Manager

/// The specialized immersive lyrics view providing fluid, physics-based per-glyph organic animations
struct OrganicLyricsView: View {
    let song: Song
    var onBackgroundTap: (() -> Void)?

    @ObservedObject var player = PlayerManager.shared
    @ObservedObject private var viewModel = LyricViewModel.shared
    @AppStorage("showTranslation") var showTranslation: Bool = true
    @AppStorage("enableKaraoke") private var enableKaraoke = false
    @AppStorage("lyricsForceUppercaseEnglish") private var forceUppercaseEnglish = false
    @AppStorage("playerDisplayFont") private var playerFontRaw = "theme"
    @AppStorage("playerCustomFontID") private var playerCustomFontID = ""
    @AppStorage("playerFontScale") private var playerFontScale = 1.0
    
    @AppStorage(KaraokeWordStyle.storageKey) private var karaokeStyleRaw = KaraokeWordStyle.defaultStyle.rawValue

    @State private var isUserScrolling = false
    @State private var userScrollTimer: Timer?
    
    var body: some View {
        ZStack {
            if viewModel.isLoading {
                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
            } else if !viewModel.hasLyrics {
                Text("No Lyrics Available")
                    .font(.rounded(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onBackgroundTap?()
                    }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 32) {
                            Color.clear.frame(height: 40) // Top padding，减小以让起始第一句正好停在封面下方，而不是屏幕正中间
                            
                            ForEach(Array(viewModel.lyrics.enumerated()), id: \.element.id) { index, line in
                                let isCurrent = index == viewModel.currentLineIndex
                                let distance = abs(index - viewModel.currentLineIndex)
                                let isNearby = distance < 12
                                
                                if isNearby {
                                    Button(action: { player.seek(to: line.time) }) {
                                        OrganicLyricLineViewWrapper(
                                            line: line,
                                            isCurrent: isCurrent,
                                            showTranslation: showTranslation,
                                            enableKaraoke: enableKaraoke,
                                            style: KaraokeWordStyle.resolve(karaokeStyleRaw),
                                            renderIdentity: lyricRenderIdentity
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .id(index)
                                } else {
                                    Color.clear
                                        .frame(height: 80)
                                        .id(index)
                                }
                            }
                            
                            Color.clear.frame(height: 350) // Bottom padding
                        }
                        .padding(.horizontal, 32)
                        .background(GeometryReader { geo in
                            Color.clear.onChange(of: geo.frame(in: .global).minY) { oldVal, newVal in
                                if abs(oldVal - newVal) > 5 && !isUserScrolling {
                                    // User swipe logic placeholder
                                }
                            }
                        })
                    }
                    .scrollIndicators(.hidden)
                    .simultaneousGesture(
                        DragGesture().onChanged { _ in
                            isUserScrolling = true
                            resetScrollTimer()
                        }
                    )
                    .onChange(of: viewModel.currentLineIndex) { _, newIndex in
                        if !isUserScrolling {
                            // 过渡整句上浮切换
                            withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) {
                                proxy.scrollTo(newIndex, anchor: .center)
                            }
                        }
                    }
                    .onAppear {
                        isUserScrolling = false
                        proxy.monoRestoreLyricPosition(isCancelled: { isUserScrolling }) {
                            viewModel.currentLineIndex
                        }
                    }
                }
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black, location: 0.15),
                            .init(color: .black, location: 0.85),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    onBackgroundTap?()
                }
            }
        }
    }

    private var lyricRenderIdentity: String {
        "\(forceUppercaseEnglish)-\(playerFontRaw)-\(playerCustomFontID)-\(playerFontScale)-\(enableKaraoke)-\(karaokeStyleRaw)"
    }
    
    private func resetScrollTimer() {
        userScrollTimer?.invalidate()
        userScrollTimer = Timer.scheduledTimer(withTimeInterval: 3.5, repeats: false) { _ in
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    isUserScrolling = false
                }
            }
        }
    }
}

// MARK: - Line View Wrapper

struct OrganicLyricLineViewWrapper: View {
    let line: LyricLine
    let isCurrent: Bool
    let showTranslation: Bool
    let enableKaraoke: Bool
    var style: KaraokeWordStyle = .flow
    let renderIdentity: String
    
    var body: some View {
        // TimelineView explicitly pauses updates when line is not active, saving up to 99% CPU
        TimelineView(AppFrameRate.throttledTimeline(
            maximumFramesPerSecond: 60,
            paused: !(isCurrent && PlayerManager.shared.isPlaying)
        )) { _ in
            let rawTime = PlayerManager.shared.streamPlayer.currentTime
            let realTime = (rawTime.isFinite && !rawTime.isNaN && rawTime >= 0) ? rawTime : PlaybackTimePublisher.shared.currentTime
            
            OrganicLyricLineView(
                line: line,
                isCurrent: isCurrent,
                currentTime: isCurrent ? realTime : 0.0,
                showTranslation: showTranslation,
                enableKaraoke: enableKaraoke,
                style: style
            )
            .id("\(line.id)-\(renderIdentity)")
        }
    }
}

// MARK: - Line View Core

struct OrganicLyricLineView: View {
    let line: LyricLine
    let isCurrent: Bool
    let currentTime: TimeInterval
    let showTranslation: Bool
    let enableKaraoke: Bool
    var style: KaraokeWordStyle = .flow
    
    @State private var wordGroups: [OrganicWordGroup] = []
    
    var body: some View {
        let mainFont = MonoPlayerFont.activeFont(
            size: isCurrent ? 36 : 28,
            weight: isCurrent ? .heavy : .bold,
            fallback: .system(
                size: isCurrent ? 36 : 28,
                weight: isCurrent ? .heavy : .bold,
                design: .rounded
            )
        )

        VStack(alignment: .leading, spacing: 8) {
            if isCurrent {
                if enableKaraoke && !wordGroups.isEmpty {
                    FlowLayout(spacing: 0) {
                        ForEach(wordGroups) { group in
                            HStack(spacing: 0) {
                                ForEach(group.glyphs) { glyph in
                                    OrganicLyricCharacterView(
                                        glyph: glyph,
                                        isCurrent: isCurrent,
                                        currentTime: currentTime,
                                        font: mainFont,
                                        style: style
                                    )
                                }
                            }
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(line.text.monoLyricDisplayText)
                        .font(mainFont)
                        .foregroundColor(.white)
                }
            } else {
                // 性能优化防御：未唱到的歌词行回退为极简原生单体 Text，砍掉单行几百个遮罩修饰符的巨量开销，秒解滑动掉帧卡顿
                Text(line.text.monoLyricDisplayText)
                    .font(mainFont)
                    .foregroundColor(.white.opacity(0.25))
                    .blur(radius: 2.5) // 全局单次高斯模糊，省GPU
            }
            
            if showTranslation, let rawTranslation = line.translation, !rawTranslation.isEmpty {
                let trans = rawTranslation.monoLyricDisplayText
                let transProgress = calculateTranslationProgress()
                
                if isCurrent {
                    ZStack(alignment: .leading) {
                        Text(trans)
                            .font(
                                MonoPlayerFont.activeFont(
                                    size: 18,
                                    weight: .semibold,
                                    fallback: .system(size: 18, weight: .semibold, design: .rounded)
                                )
                            )
                            .foregroundColor(.white.opacity(0.3)) // 未到翻译字
                        
                        Text(trans)
                            .font(
                                MonoPlayerFont.activeFont(
                                    size: 18,
                                    weight: .semibold,
                                    fallback: .system(size: 18, weight: .semibold, design: .rounded)
                                )
                            )
                            .foregroundColor(.white.opacity(0.8)) // 到的翻译字高亮
                            .mask(
                                GeometryReader { geo in
                                    let w = geo.size.width
                                    let h = geo.size.height
                                    LinearGradient(
                                        stops: [
                                            .init(color: .black, location: 0),
                                            .init(color: .black, location: 0.3),     // 纯黑完全浸没区
                                            .init(color: .black.opacity(0.4), location: 0.6), // 极其宽广柔和的流水前端
                                            .init(color: .clear, location: 0.9)      // 较远距离才完全透明，确保字间融合
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                    .frame(width: w * 5, height: h * 2)     // 极其宽广的遮罩平面
                                    .offset(x: -w * 2.5, y: -h * 0.5)       // 居中校准
                                    // 让极其柔和的半透明过渡带缓缓滑过
                                    .offset(x: -w * 1.5 + (w * 3.5) * transProgress)
                                }
                            )
                    }
                } else {
                    Text(trans)
                        .font(
                            MonoPlayerFont.activeFont(
                                size: 16,
                                weight: .semibold,
                                fallback: .system(size: 16, weight: .semibold, design: .rounded)
                            )
                        )
                        .foregroundColor(.white.opacity(0.3))
                        .blur(radius: 2.0)
                }
            }
        }
        .animation(.easeInOut(duration: 0.4), value: isCurrent) // 整体过渡保护
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            if wordGroups.isEmpty {
                wordGroups = prepareWordGroups(line: line)
            }
        }
    }
    
    private func calculateTranslationProgress() -> CGFloat {
        guard isCurrent, line.duration > 0 else { return 0 }
        let progress = (currentTime - line.time) / line.duration
        return CGFloat(max(0, min(1, progress)))
    }
    
    private func prepareWordGroups(line: LyricLine) -> [OrganicWordGroup] {
        let sourceWords = LyricKaraokeTimeline.resolvedWords(for: line)
        
        var groups: [OrganicWordGroup] = []
        var globalIndex = 0
        var wordGlobalIndex = 0
        
        for word in sourceWords {
            let chars = Array(word.text)
            let totalChars = chars.count
            guard totalChars > 0 else { continue }
            
            let charDuration = word.duration / Double(totalChars)
            var glyphs: [OrganicGlyph] = []
            for (i, char) in chars.enumerated() {
                glyphs.append(OrganicGlyph(
                    char: String(char),
                    startTime: word.startTime + Double(i) * charDuration,
                    duration: charDuration,
                    globalIndex: globalIndex,
                    wordIndex: wordGlobalIndex
                ))
                globalIndex += 1
            }
            groups.append(OrganicWordGroup(glyphs: glyphs))
            wordGlobalIndex += 1
        }
        return groups
    }
}

// MARK: - Character View (Physics Core)

struct OrganicLyricCharacterView: View {
    let glyph: OrganicGlyph
    let isCurrent: Bool
    let currentTime: TimeInterval
    let font: Font
    var style: KaraokeWordStyle = .flow
    
    // 数学旗帜横波偏移量 (数学正弦波随时间传播)
    private var continuousFlagWaveOffset: CGFloat {
        guard isCurrent, currentTime > 0 else { return 0 }
        // 降低频率让波浪变宽长更有飘扬感，同时防抖动
        let waveSpeed: Double = 1.8
        // 恢复空间相位差以保证短句依旧能产生“涟漪飘扬”感。
        // 原先英文撕裂的根本原因是用了 wordIndex，导致整个单词像阶梯一样硬生生断层错位。
        // 现在强制改为 globalIndex 并使用极小的频率 (0.08)，使得无论是长句还是短句，所有字符必然连成一条平滑完美的物理正弦横波（丝带般），绝不断层。
        let spatialFrequency: Double = 0.08
        let phase = currentTime * waveSpeed - Double(glyph.globalIndex) * spatialFrequency
        // 上下飘浮微波动
        return CGFloat(sin(phase)) * 2.5
    }

    var body: some View {
        // 逐字进度交给共享的样式化渲染器：
        // 缓动扫光 + 激活脉冲（托起/回弹/辉光…）替代原先的线性硬扫，消除生硬感
        KaraokeStyledWordView(
            text: glyph.char,
            progress: calculateProgress(),
            font: font,
            style: style,
            inactiveColor: .white.opacity(isCurrent ? 0.35 : 0.25),
            activeColor: .white
        )
        .blur(radius: isCurrent ? 0 : 2.5)
        .offset(y: continuousFlagWaveOffset)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isCurrent)
    }
    
    func calculateProgress() -> CGFloat {
        guard isCurrent else { return 0 }
        guard glyph.duration > 0 else { return currentTime >= glyph.startTime ? 1 : 0 }
        if currentTime < glyph.startTime { return 0 }
        if currentTime >= glyph.startTime + glyph.duration { return 1 }
        return CGFloat((currentTime - glyph.startTime) / glyph.duration)
    }
}
