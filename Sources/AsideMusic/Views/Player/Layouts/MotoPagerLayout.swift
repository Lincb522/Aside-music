import SwiftUI

/// 复古寻呼机风格播放器 (MotoPager)
/// 核心理念：模拟小票打印机/寻呼机的复古质感，歌词像小票一样打印出来
struct MotoPagerLayout: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var player = PlayerManager.shared
    @ObservedObject var lyricVM = LyricViewModel.shared
    
    // MARK: - Colors & Constants
    // 动态配色 - 适配深色/浅色模式
    private var bgColor: Color {
        colorScheme == .dark ? Color(hex: "1a1c20") : Color(hex: "f0f2f5")
    }
    private var deviceBodyColor: Color {
        colorScheme == .dark ? Color(hex: "2a2824") : Color(hex: "f5f0eb")
    }
    private let screenBgColor = Color(hex: "1a1a1a")
    private let screenTextColor = Color(hex: "fca311")
    private var accentColor: Color {
        colorScheme == .dark ? Color.white : Color.black
    }
    private var paperColor: Color {
        colorScheme == .dark ? Color(hex: "e8e4dd") : Color(hex: "fffcf5")
    }
    private var paperTextColor: Color {
        colorScheme == .dark ? Color(hex: "2a2a2a") : Color(hex: "333333")
    }
    private var paperMetaColor: Color {
        colorScheme == .dark ? Color(hex: "7a7570") : Color.gray
    }
    private var paperDashColor: Color {
        colorScheme == .dark ? Color(hex: "4a4540") : Color(hex: "dcdcdc")
    }
    private var controlsBgColor: Color {
        colorScheme == .dark ? Color(hex: "3a3630") : Color(hex: "e8e3dc")
    }
    private var smallBtnColor: Color {
        colorScheme == .dark ? Color(hex: "4a4640") : Color.white
    }
    private var brandSubColor: Color {
        colorScheme == .dark ? Color(hex: "6a665e") : Color(hex: "8a867d")
    }
    private var topBtnBgColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.white.opacity(0.7)
    }
    private var topBtnFgColor: Color {
        colorScheme == .dark ? Color(hex: "b0b0b0") : Color.gray
    }
    
    // 机器主体估算高度（出纸口12 + brand~30 + LCD80 + controls~50 + padding*2 + spacing）
    private let deviceBodyHeight: CGFloat = 280
    
    // 纸张随打字进度推出的量（不再使用，保持固定高度）
    private var paperTypingPush: CGFloat { 0 }
    
    // MARK: - State
    @State private var isAppeared = false
    @State private var printedLyrics: [PrintedLyric] = []
    
    // 打字机状态
    @State private var typingText: String = ""        // LCD 上逐字显示的文字
    @State private var fullLyricText: String = ""     // 当前完整歌词（打字目标）
    @State private var isTyping = false               // 是否正在打字中
    @State private var typingDone = false             // 打字完成，等待下一句弹出
    @State private var showCursor = true              // 闪烁光标
    @State private var typingTask: Task<Void, Never>? // 打字动画任务
    @State private var cursorTask: Task<Void, Never>? // 光标闪烁任务
    
    // 出纸口动画状态
    @State private var paperSlotOffset: CGFloat = 0   // 出纸口纸张的 Y 偏移（0=待机露头，负值=弹出）
    @State private var paperSlotOpacity: Double = 1   // 出纸口纸张透明度
    @State private var pendingEjectText: String = ""  // 待弹出的文字内容
    @State private var isEjecting = false             // 是否正在弹出动画中
    
    // 缝隙位置追踪
    @State private var slotGlobalY: CGFloat = 0
    
    // 交互状态
    @State private var showPlaylist = false
    @State private var showQualitySheet = false
    @State private var showMoreMenu = false
    @State private var showEQSettings = false
    @State private var showThemePicker = false
    @State private var showComments = false

    var body: some View {
        ZStack {
            // 1. 全局背景
            bgColor.ignoresSafeArea()
            
            // 2. 主布局：缝隙 + 机器（固定在底部）
            VStack(spacing: 0) {
                Spacer()
                
                // 缝隙 — 用 overlay 放置纸张，确保位置准确
                slotView
                    .padding(.horizontal, 24)
                    .overlay(alignment: .top) {
                        // 纸张在缝隙正上方，底部被裁掉（模拟藏在机器内部）
                        paperView
                            .frame(height: 55, alignment: .top)
                            .clipped()
                            .offset(x: 0, y: -55 + paperSlotOffset)
                            .opacity(fullLyricText.isEmpty && !isEjecting ? 0 : paperSlotOpacity)
                            .allowsHitTesting(false)
                    }
                
                // 机器主体 — 固定在底部
                deviceBodyView
                    .padding(.bottom, DeviceLayout.playerBottomPadding)
            }
            
            // （不再需要浮动纸张）
            
            // 2b. 便签区 — 固定在顶部，不受机器布局影响
            VStack {
                VStack(spacing: -6) {
                    ForEach(Array(printedLyrics.suffix(3).enumerated()), id: \.element.id) { index, item in
                        ReceiptEntryView(
                            content: item.text, time: item.time, id: item.id,
                            paperColor: paperColor, textColor: paperTextColor,
                            metaColor: paperMetaColor, dashColor: paperDashColor
                        )
                            .zIndex(Double(index))
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .move(edge: .top).combined(with: .opacity)
                            ))
                    }
                }
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: printedLyrics.count)
                .padding(.top, DeviceLayout.safeAreaTop + 10)
                
                Spacer()
            }
            
            // 3. 顶部渐变遮罩 (模拟出纸口阴影)
            VStack {
                LinearGradient(
                    colors: [bgColor, bgColor.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 100)
                Spacer()
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .zIndex(20)
            
            // 4. 顶部导航 (悬浮)
            topBar
                .zIndex(30)
                .padding(.top, DeviceLayout.headerTopPadding)
            
            // 5. 更多菜单
            if showMoreMenu {
                PlayerMoreMenu(
                    isPresented: $showMoreMenu,
                    onEQ: { showEQSettings = true },
                    onTheme: { showThemePicker = true }
                )
                .zIndex(40)
            }
        }
        .onAppear {
            setupLifecycle()
        }
        .onDisappear {
            typingTask?.cancel()
            cursorTask?.cancel()
        }
        .onChange(of: lyricVM.currentLineIndex) { _, newIndex in
            printNewLyric(index: newIndex)
        }
        .onChange(of: player.currentSong?.id) { _, _ in
            // 切歌时清空所有状态
            typingTask?.cancel()
            if !fullLyricText.isEmpty {
                ejectReceipt(text: fullLyricText)
            }
            typingText = ""
            fullLyricText = ""
            isTyping = false
            typingDone = false
            
            // 清空上一首的便签，打印新歌信息
            withAnimation(.easeOut(duration: 0.3)) {
                printedLyrics.removeAll()
            }
            if let song = player.currentSong {
                printedLyrics.append(PrintedLyric(text: "NOW PLAYING: \(song.name)", time: formatTime(Date())))
            }
        }
        .sheet(isPresented: $showPlaylist) {
            PlaylistPopupView().presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showQualitySheet) {
            SoundQualitySheet(
                currentQuality: player.soundQuality, currentKugouQuality: player.kugouQuality,
                isUnblocked: player.isCurrentSongUnblocked,
                onSelectNetease: { q in player.switchQuality(q); showQualitySheet = false },
                onSelectKugou: { q in player.switchKugouQuality(q); showQualitySheet = false }
            ).presentationDetents([.medium]).presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showEQSettings) {
            NavigationStack { EQSettingsView() }.presentationDetents([.large]).presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showThemePicker) {
            PlayerThemePickerSheet().presentationDetents([.medium]).presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showComments) {
            if let song = player.currentSong {
                CommentView(resourceId: song.id, resourceType: .song,
                           songName: song.name, artistName: song.artistName, coverUrl: song.coverUrl)
                .presentationDetents([.large]).presentationDragIndicator(.hidden)
            }
        }
    }
    
    private func setupLifecycle() {
        withAnimation(.easeOut(duration: 0.8)) { isAppeared = true }
        if let song = player.currentSong, lyricVM.currentSongId != song.id {
            lyricVM.fetchLyrics(for: song.id)
        }
        // 欢迎信息
        printedLyrics.append(PrintedLyric(text: "MOTO PAGER READY...", time: formatTime(Date())))
        // 启动光标闪烁
        startCursorBlink()
    }
    
    private func startCursorBlink() {
        cursorTask?.cancel()
        cursorTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                showCursor.toggle()
            }
        }
    }
    
    private func printNewLyric(index: Int) {
        guard index >= 0, index < lyricVM.lyrics.count else { return }
        let line = lyricVM.lyrics[index]
        if line.text.isEmpty { return }
        
        // 取消上一次打字任务
        typingTask?.cancel()
        
        // 如果上一句已经打完或正在打，先弹出便签
        if !fullLyricText.isEmpty {
            ejectReceipt(text: fullLyricText)
        }
        
        fullLyricText = line.text
        typingText = ""
        isTyping = true
        typingDone = false
        
        typingTask = Task { @MainActor in
            let chars = Array(fullLyricText)
            let interval: UInt64 = chars.count > 20 ? 40_000_000 : 60_000_000
            
            for i in 0..<chars.count {
                if Task.isCancelled { return }
                typingText = String(chars[0...i])
                try? await Task.sleep(nanoseconds: interval)
            }
            
            if Task.isCancelled { return }
            
            // 打字完成，保持在 LCD 上等待下一句到来
            isTyping = false
            typingDone = true
        }
    }
    
    /// 将文字从 LCD "吐出"变成纸带上的便签
    private func ejectReceipt(text: String) {
        guard !isEjecting else {
            let newEntry = PrintedLyric(text: text, time: formatTime(Date()))
            printedLyrics.append(newEntry)
            return
        }
        
        isEjecting = true
        pendingEjectText = text
        
        // 阶段1：纸张从出纸口向上滑动 + 淡出（始终保持 clipping）
        withAnimation(.easeOut(duration: 0.5)) {
            paperSlotOffset = -120
            paperSlotOpacity = 0
        }
        
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            // 阶段2：便签加入列表
            let newEntry = PrintedLyric(text: pendingEjectText, time: formatTime(Date()))
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                printedLyrics.append(newEntry)
            }
            
            if printedLyrics.count > 6 {
                printedLyrics.removeFirst()
            }
            
            // 阶段3：重置 — 新纸从缝隙内部冒出
            paperSlotOffset = 30
            paperSlotOpacity = 0
            
            try? await Task.sleep(nanoseconds: 150_000_000)
            
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                paperSlotOffset = 0
                paperSlotOpacity = 1
            }
            
            isEjecting = false
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Device Body (机器主体 — 原始 MotoPager 风格)
extension MotoPagerLayout {
    var deviceBodyView: some View {
        machineBodyContent
            .padding(.horizontal, 24)
    }
    
    // 机器主体内容
    private var machineBodyContent: some View {
        VStack(spacing: 0) {
            // ═══ Brand 区 ═══
            VStack(spacing: 3) {
                HStack(spacing: 0) {
                    Text("MOTO")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(colorScheme == .dark ? Color(hex: "999999") : Color(hex: "555555"))
                    Text("PAGER")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(accentColor)
                }
                .tracking(3)
                
                if let song = player.currentSong {
                    MarqueeText(
                        text: "\(song.artistName) — \(song.name)",
                        font: .system(size: 9, weight: .regular, design: .monospaced),
                        color: brandSubColor,
                        speed: 25
                    )
                    .frame(maxWidth: 200, minHeight: 16)
                } else {
                    Text("— DIGITAL NOTE PRINTER —")
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .foregroundColor(brandSubColor)
                        .opacity(0.6)
                        .tracking(1)
                }
            }
            .padding(.bottom, 15)
            
            // ═══ LCD 屏幕 (CSS: height: 80px, padding: 12px, margin-bottom: 15px) ═══
            ZStack {
                RoundedRectangle(cornerRadius: 15)
                    .fill(screenBgColor)
                    .shadow(color: .black.opacity(0.5), radius: 5, x: 0, y: 2)
                
                RoundedRectangle(cornerRadius: 15)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.black.opacity(0.5), Color.white.opacity(colorScheme == .dark ? 0.03 : 0.08)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 2
                    )
                
                // 扫描线
                VStack(spacing: 3) {
                    ForEach(0..<15, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.white.opacity(0.02))
                            .frame(height: 1)
                        Spacer(minLength: 0)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 13))
                .padding(2)
                .allowsHitTesting(false)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 0) {
                        if typingText.isEmpty && fullLyricText.isEmpty {
                            Text("READY" + (showCursor ? " ▌" : ""))
                                .font(.custom("HYPixel-11px-U", size: 18))
                                .foregroundColor(screenTextColor.opacity(0.5))
                                .lineLimit(2)
                        } else {
                            Text(typingText + (showCursor && (isTyping || typingDone) ? "▌" : ""))
                                .font(.custom("HYPixel-11px-U", size: 20))
                                .foregroundColor(screenTextColor)
                                .shadow(color: screenTextColor.opacity(0.5), radius: 3)
                                .lineLimit(2)
                                .animation(.none, value: typingText)
                        }
                        Spacer()
                    }
                    
                    Spacer(minLength: 0)
                    
                    HStack(spacing: 2) {
                        let totalBars = 20
                        let progress = player.duration > 0 ? player.currentTime / player.duration : 0
                        let filledBars = Int(progress * Double(totalBars))
                        ForEach(0..<totalBars, id: \.self) { i in
                            Rectangle()
                                .fill(i < filledBars ? screenTextColor : screenTextColor.opacity(0.12))
                                .frame(height: 3)
                        }
                    }
                }
                .padding(12)
            }
            .frame(height: 80)
            .padding(.bottom, 15)
            
            // ═══ 控制区 (CSS: .controls) ═══
            HStack {
                // 左侧胶囊 (CSS: .left-decor gap: 5px)
                HStack(spacing: 5) {
                    // LED
                    Circle()
                        .fill(player.isPlaying ? accentColor : accentColor.opacity(0.5))
                        .frame(width: 25, height: 25)
                        .shadow(color: player.isPlaying ? accentColor.opacity(0.6) : .clear, radius: player.isPlaying ? 8 : 0)
                        .overlay(
                            Circle().fill(
                                RadialGradient(colors: [Color.white.opacity(0.35), Color.clear],
                                               center: .topLeading, startRadius: 0, endRadius: 14)
                            )
                        )
                        .overlay(Circle().stroke(Color.black.opacity(0.15), lineWidth: 0.5))
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: player.isPlaying)
                    
                    // 爱心
                    if let song = player.currentSong {
                        LikeButton(songId: song.id, size: 14, activeColor: accentColor, inactiveColor: brandSubColor)
                            .frame(width: 25, height: 25)
                            .background(smallBtnColor)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                    }
                    
                    // 音质
                    Button(action: { showQualitySheet = true }) {
                        Text(player.soundQuality.buttonText)
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(brandSubColor)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.horizontal, 8)
                            .frame(height: 25)
                            .background(smallBtnColor)
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(AsideBouncingButtonStyle())
                    
                    // 上一首
                    Button(action: { player.previous() }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 10))
                            .foregroundColor(brandSubColor)
                            .frame(width: 25, height: 25)
                            .background(smallBtnColor)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                            .contentShape(Circle())
                    }
                    .buttonStyle(AsideBouncingButtonStyle())
                    
                    // 下一首
                    Button(action: { player.next() }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 10))
                            .foregroundColor(brandSubColor)
                            .frame(width: 25, height: 25)
                            .background(smallBtnColor)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                            .contentShape(Circle())
                    }
                    .buttonStyle(AsideBouncingButtonStyle())
                }
                .padding(5)
                .background(controlsBgColor)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)
                
                Spacer()
                
                // PRINT 按钮 (CSS mobile: 60x60)
                Button(action: { player.togglePlayPause() }) {
                    ZStack {
                        Circle()
                            .fill(accentColor)
                            .frame(width: 50, height: 50)
                            .shadow(color: accentColor.opacity(0.3), radius: 0, x: 0, y: 3)
                            .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 6)
                        
                        Text(player.isPlaying ? "PAUSE" : "PRINT")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(colorScheme == .dark ? .black : .white)
                            .tracking(1)
                    }
                    .contentShape(Circle())
                }
                .buttonStyle(AsideBouncingButtonStyle())
            }
        }
        .padding(15)
        .background(
            deviceBodyColor
                .clipShape(RoundedRectangle(cornerRadius: 30))
                .overlay(
                    RoundedRectangle(cornerRadius: 30)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(colorScheme == .dark ? 0.08 : 0.5),
                                    Color.black.opacity(colorScheme == .dark ? 0.3 : 0.05)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.5 : 0.15), radius: 20, x: 0, y: 10)
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.05), radius: 3, x: 0, y: -2)
    }
    
    // 出纸口纸张 — 和便签一样大小，从缝隙里逐渐推出
    // 初始状态：纸张大部分在缝隙下方（机器内部），只露出一小截
    // 打字过程中：纸张逐渐向上推，字从被截断到完整露出
    // 弹出时：纸张完全飞出去
    private var paperView: some View {
        // 纸张内容（和 ReceiptEntryView 类似的样式）
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                // 小票头部信息
                HStack {
                    Text("PRINTING...")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(paperMetaColor)
                    Spacer()
                    Text(formatTime(Date()))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(paperMetaColor)
                }
                
                // 歌词文字
                Text(typingText.isEmpty ? " " : typingText)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(paperTextColor)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 22)
            .background(paperColor)
            
            // 虚线分割
            Rectangle()
                .fill(paperColor)
                .frame(height: 10)
                .overlay(
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: 5))
                        path.addLine(to: CGPoint(x: 280, y: 5))
                    }
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundColor(paperDashColor)
                )
        }
        .frame(width: 280)
        .clipShape(ReceiptShape())
        .shadow(color: .black.opacity(0.08), radius: 2, y: -2)
    }
    
    // 出纸口缝隙 — 模拟真实打印机出纸口，内凹质感
    private var slotView: some View {
        VStack(spacing: 0) {
            // 上唇 — 机器外壳边缘，带高光
            RoundedRectangle(cornerRadius: 1)
                .fill(
                    LinearGradient(
                        colors: colorScheme == .dark
                            ? [Color(hex: "3a3630"), Color(hex: "2a2824")]
                            : [Color(hex: "e8e3dc"), Color(hex: "d8d3cc")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 3)
                .shadow(color: colorScheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.4), radius: 0, x: 0, y: -0.5)
            
            // 缝隙本体 — 窄而深的凹槽
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: colorScheme == .dark
                            ? [Color.black.opacity(0.9), Color(hex: "1a1816").opacity(0.7)]
                            : [Color.black.opacity(0.25), Color.black.opacity(0.08)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 3)
            
            // 下唇 — 带内阴影感
            RoundedRectangle(cornerRadius: 1)
                .fill(
                    LinearGradient(
                        colors: colorScheme == .dark
                            ? [Color(hex: "222020"), Color(hex: "2a2824")]
                            : [Color(hex: "ccc8c0"), Color(hex: "e0dbd5")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 2)
        }
        .padding(.horizontal, 38)
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.08), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Receipt Entry (小票条目)
struct ReceiptEntryView: View {
    let content: String
    let time: String
    let id: String
    var paperColor: Color = Color(hex: "fffcf5")
    var textColor: Color = Color(hex: "333333")
    var metaColor: Color = .gray
    var dashColor: Color = Color(hex: "dcdcdc")
    
    
    
    var body: some View {
        VStack(spacing: 0) {
            // Paper content
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack {
                    Text("ID: \(id)")
                    Spacer()
                    Text(time)
                }
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(metaColor)
                
                // Content
                Text(content)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(textColor)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 22)
            .background(paperColor)
            
            // Dashed Separator
            Rectangle()
                .fill(paperColor)
                .frame(height: 10)
                .overlay(
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: 5))
                        path.addLine(to: CGPoint(x: UIScreen.main.bounds.width, y: 5))
                    }
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundColor(dashColor)
                )
        }
        .frame(width: 280)
        .clipShape(ReceiptShape())
        .shadow(color: .black.opacity(0.08), radius: 2, y: 3)
        .shadow(color: .black.opacity(0.12), radius: 6, y: 5)
    }
}

// MARK: - Top Bar (Minimal)
extension MotoPagerLayout {
    var topBar: some View {
        VStack {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(topBtnFgColor)
                        .frame(width: 40, height: 40)
                        .background(topBtnBgColor)
                        .clipShape(Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(AsideBouncingButtonStyle())
                
                Spacer()
                
                Button(action: { showMoreMenu = true }) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(topBtnFgColor)
                        .frame(width: 40, height: 40)
                        .background(topBtnBgColor)
                        .clipShape(Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(AsideBouncingButtonStyle())
            }
            .padding(.horizontal, 30)
            
            Spacer()
        }
    }
}

// MARK: - PreferenceKey
struct SlotPositionKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Models
struct PrintedLyric: Identifiable {
    let id = UUID().uuidString.prefix(6).uppercased()
    let text: String
    let time: String
}

// MARK: - Helpers
// 锯齿底边小票形状
struct ReceiptShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let toothSize: CGFloat = 4
        
        // 顶部直线
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        
        // 右侧直线
        path.addLine(to: CGPoint(x: rect.width, y: rect.height - toothSize))
        
        // 底部锯齿
        let teeth = Int(rect.width / (toothSize * 2))
        let actualToothWidth = rect.width / CGFloat(teeth)
        for i in 0..<teeth {
            let x = rect.width - CGFloat(i) * actualToothWidth
            path.addLine(to: CGPoint(x: x - actualToothWidth / 2, y: rect.height))
            path.addLine(to: CGPoint(x: x - actualToothWidth, y: rect.height - toothSize))
        }
        
        // 左侧直线回到起点
        path.addLine(to: CGPoint(x: 0, y: 0))
        path.closeSubpath()
        return path
    }
}
