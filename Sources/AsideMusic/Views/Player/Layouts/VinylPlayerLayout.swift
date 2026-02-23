import SwiftUI
import FFmpegSwiftSDK

/// 黑胶唱片布局 - 浅色背景 + 超大唱片 + 白色唱臂 + Apple 风格极简控制
struct VinylPlayerLayout: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var player = PlayerManager.shared
    @ObservedObject var downloadManager = DownloadManager.shared
    @ObservedObject var lyricVM = LyricViewModel.shared

    // MARK: - 状态
    @State private var isDragging = false
    @State private var dragValue: Double = 0
    @State private var tonearmAngle: Double = -38
    @State private var showPlaylist = false
    @State private var showLyrics = false
    @State private var showQualitySheet = false
    @State private var showComments = false
    @State private var showEQSettings = false
    @State private var showThemePicker = false
    @State private var showMoreMenu = false
    @State private var isAppeared = false

    /// 唱片旋转角度 — 匀速自旋转
    @State private var discRotation: Double = 0
    @State private var isSpinning = false
    
    /// 切歌动画状态
    @State private var isChangingSong = false
    @State private var discOffset: CGFloat = 0
    @State private var discOpacity: Double = 1
    /// 记录上一首歌的 ID，用于检测切歌
    @State private var lastSongId: Int? = nil

    @Environment(\.colorScheme) private var colorScheme

    private var contentColor: Color {
        colorScheme == .dark ? .white : Color(hex: "1A1A1A")
    }
    private var secondaryColor: Color {
        contentColor.opacity(0.45)
    }

    // MARK: - Body
    var body: some View {
        GeometryReader { geo in
            let discSize = min(geo.size.width * 0.88, 360)

            ZStack {
                // 通用弥散背景
                AsideBackground().ignoresSafeArea()

                VStack(spacing: 0) {
                    // 顶栏（极简）
                    headerBar
                        .padding(.top, DeviceLayout.headerTopPadding)
                        .padding(.bottom, 4)

                    // 唱片 + 唱臂 / 歌词 切换区域
                    ZStack {
                        if showLyrics {
                            // 歌词模式
                            if let song = player.currentSong {
                                LyricsView(song: song, onBackgroundTap: {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        showLyrics = false
                                    }
                                })
                            }
                        } else {
                            // 唱片模式
                            ZStack {
                                vinylDisc(size: discSize)
                                tonearm(discSize: discSize)
                            }
                            .onTapWithHaptic {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    showLyrics = true
                                }
                            }
                        }
                    }
                    .frame(width: geo.size.width, height: discSize + 30)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showLyrics)

                    Spacer()

                    // 歌曲信息 — 左对齐
                    songInfoSection
                        .padding(.horizontal, 28)
                        .padding(.bottom, 12)

                    // 进度条
                    progressSection
                        .padding(.horizontal, 28)
                        .padding(.bottom, 20)

                    // 底部控制按钮 — 圆角矩形风格
                    controlsSection
                        .padding(.horizontal, 28)
                        .padding(.bottom, DeviceLayout.playerBottomPadding)
                }

                if showMoreMenu {
                    PlayerMoreMenu(
                        isPresented: $showMoreMenu,
                        onEQ: { showEQSettings = true },
                        onTheme: { showThemePicker = true }
                    )
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { isAppeared = true }
            updateTonearm()
            lastSongId = player.currentSong?.id
            // 预加载歌词，确保切换到歌词视图时已准备好
            if let song = player.currentSong, lyricVM.currentSongId != song.id {
                if song.isQQMusic, let mid = song.qqMid {
                    lyricVM.fetchQQLyrics(mid: mid, songId: song.id)
                } else {
                    lyricVM.fetchLyrics(for: song.id)
                }
            }
        }
        .onChange(of: player.isPlaying) { _, _ in
            updateTonearm()
        }
        .onChange(of: player.currentSong?.id) { oldId, newId in
            // 检测切歌，触发动画
            if let old = oldId, let new = newId, old != new {
                triggerSongChangeAnimation()
            }
            lastSongId = newId
        }
        .sheet(isPresented: $showPlaylist) {
            PlaylistPopupView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showQualitySheet) {
            SoundQualitySheet(
                currentQuality: player.soundQuality,
                currentKugouQuality: player.kugouQuality,
                currentQQQuality: player.qqMusicQuality,
                isUnblocked: player.isCurrentSongUnblocked,
                isQQMusic: player.currentSong?.isQQMusic == true,
                onSelectNetease: { q in player.switchQuality(q); showQualitySheet = false },
                onSelectKugou: { q in player.switchKugouQuality(q); showQualitySheet = false },
                onSelectQQ: { q in player.switchQQMusicQuality(q); showQualitySheet = false }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showEQSettings) {
            NavigationStack { EQSettingsView() }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showThemePicker) {
            PlayerThemePickerSheet()
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showComments) {
            if let song = player.currentSong {
                CommentView(resourceId: song.id, resourceType: .song,
                           songName: song.name, artistName: song.artistName, coverUrl: song.coverUrl)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
            }
        }
    }
}

// MARK: - 顶栏
extension VinylPlayerLayout {

    var headerBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                AsideIcon(icon: .chevronRight, size: 18, color: contentColor.opacity(0.5))
                    .rotationEffect(.degrees(90))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(AsideBouncingButtonStyle())

            Spacer()

            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                    showMoreMenu.toggle()
                }
            }) {
                AsideIcon(icon: .more, size: 18, color: contentColor.opacity(0.5))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(AsideBouncingButtonStyle())
        }
        .padding(.horizontal, 20)
        .zIndex(1)
    }
}

// MARK: - 黑胶唱片
extension VinylPlayerLayout {

    func vinylDisc(size: CGFloat) -> some View {
        // 深色模式下唱片阴影更明显，浅色模式下柔和
        let shadowOpacity = colorScheme == .dark ? 0.5 : 0.08
        let edgeHighlight = colorScheme == .dark ? 0.12 : 0.15
        let grooveHighlight = colorScheme == .dark ? 0.08 : 0.06

        return ZStack {
            // 唱片柔和阴影
            Circle()
                .fill(Color.black.opacity(shadowOpacity))
                .frame(width: size * 0.85, height: size * 0.25)
                .blur(radius: 25)
                .offset(y: size * 0.5)

            // 唱片外圈光泽（模拟边缘厚度）
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "3A3A3A"),
                            Color(hex: "1A1A1A")
                        ],
                        center: .center,
                        startRadius: size * 0.45,
                        endRadius: size * 0.5
                    )
                )
                .frame(width: size, height: size)

            // 唱片主体
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "2A2A2A"),
                            Color(hex: "1C1C1C"),
                            Color(hex: "252525"),
                            Color(hex: "1A1A1A"),
                            Color(hex: "222222")
                        ],
                        center: .center,
                        startRadius: size * 0.12,
                        endRadius: size * 0.48
                    )
                )
                .frame(width: size * 0.96, height: size * 0.96)
                .overlay(vinylGrooves(size: size * 0.96))

            // 唱片边缘高光（旋转的光泽效果）— 深色模式下更亮
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            .white.opacity(edgeHighlight),
                            .clear,
                            .white.opacity(grooveHighlight),
                            .clear,
                            .white.opacity(edgeHighlight * 0.8),
                            .clear,
                            .white.opacity(grooveHighlight * 1.2),
                            .clear
                        ],
                        center: .center
                    ),
                    lineWidth: 1.5
                )
                .frame(width: size - 2, height: size - 2)

            // 唱片内圈装饰环（标签边缘）
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color(hex: "444444"), Color(hex: "333333"), Color(hex: "444444")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .frame(width: size * 0.44, height: size * 0.44)

            // 封面（圆形居中）
            if let song = player.currentSong {
                CachedAsyncImage(url: song.coverUrl?.sized(800)) { Color.gray.opacity(0.3) }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size * 0.40, height: size * 0.40)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color(hex: "555555"), Color(hex: "333333")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 3
                            )
                    )
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.5 : 0.3), radius: 4, x: 0, y: 2)
            } else {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: "3A3A3A"), Color(hex: "2A2A2A")],
                            center: .center,
                            startRadius: 0,
                            endRadius: size * 0.2
                        )
                    )
                    .frame(width: size * 0.40, height: size * 0.40)
            }

            // 中心轴孔
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: "2A2A2A"), Color(hex: "1A1A1A")],
                            center: .center,
                            startRadius: 0,
                            endRadius: 8
                        )
                    )
                    .frame(width: 16, height: 16)
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Color(hex: "555555"), Color(hex: "333333")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .frame(width: 16, height: 16)
                Circle()
                    .fill(Color(hex: "111111"))
                    .frame(width: 6, height: 6)
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 2, height: 2)
                    .offset(x: -1, y: -1)
            }
        }
        .rotationEffect(.degrees(discRotation))
        .offset(x: discOffset)
        .opacity(discOpacity)
        .onAppear {
            if player.isPlaying { startSpinning() }
        }
        .onChange(of: player.isPlaying) { _, isPlaying in
            if isPlaying {
                startSpinning()
            } else {
                isSpinning = false
            }
        }
        .opacity(isAppeared ? 1 : 0)
        .scaleEffect(isAppeared ? 1 : 0.9)
    }

    /// 唱片沟槽（更丰富的纹理）
    func vinylGrooves(size: CGFloat) -> some View {
        ZStack {
            // 主沟槽
            ForEach(0..<18, id: \.self) { i in
                let ratio = 0.22 + CGFloat(i) * 0.038
                Circle()
                    .stroke(
                        Color.white.opacity(i % 4 == 0 ? 0.06 : (i % 2 == 0 ? 0.03 : 0.015)),
                        lineWidth: i % 3 == 0 ? 0.6 : 0.3
                    )
                    .frame(width: size * ratio, height: size * ratio)
            }
            
            // 反光带（模拟光线照射）
            Circle()
                .trim(from: 0.1, to: 0.3)
                .stroke(
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.04), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: size * 0.15
                )
                .frame(width: size * 0.7, height: size * 0.7)
                .rotationEffect(.degrees(-30))
            
            // 封面与纹路之间的暗环
            Circle()
                .stroke(Color.black.opacity(0.5), lineWidth: 4)
                .frame(width: size * 0.44, height: size * 0.44)
        }
    }
    
    /// 切歌动画
    func triggerSongChangeAnimation() {
        isChangingSong = true
        
        // 唱臂先抬起
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            tonearmAngle = -38
        }
        
        // 唱片滑出
        withAnimation(.easeIn(duration: 0.25).delay(0.1)) {
            discOffset = -80
            discOpacity = 0
        }
        
        // 新唱片滑入
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            // 先移到右侧（不带动画）
            discOffset = 80
            
            // 滑入动画
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                discOffset = 0
                discOpacity = 1
            }
            
            // 唱臂落下
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isChangingSong = false
                if player.isPlaying {
                    withAnimation(.spring(response: 0.7, dampingFraction: 0.65)) {
                        tonearmAngle = -8
                    }
                }
            }
        }
    }
}

// MARK: - 唱臂（白色/银色，底座在唱片右上方，唱头落在唱片上）
extension VinylPlayerLayout {

    func tonearm(discSize: CGFloat) -> some View {
        let armLength = discSize * 0.5
        let pivotX = discSize * 0.35
        let pivotY = -discSize * 0.35
        // 深色模式下唱臂更亮
        let armLight = colorScheme == .dark ? Color(hex: "D0D0D0") : Color(hex: "E0E0E0")
        let armMid = colorScheme == .dark ? Color(hex: "A0A0A0") : Color(hex: "C0C0C0")
        let baseFill1 = colorScheme == .dark ? Color(hex: "D5D5D5") : Color(hex: "F0F0F0")
        let baseFill2 = colorScheme == .dark ? Color(hex: "B0B0B0") : Color(hex: "D5D5D5")
        let baseDot = colorScheme == .dark ? Color(hex: "999999") : Color(hex: "BBBBBB")
        let armShadow = colorScheme == .dark ? 0.3 : 0.1

        return ZStack {
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [armLight, armMid, armLight],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 4.5, height: armLength)
                    .shadow(color: .black.opacity(armShadow), radius: 3, x: 1, y: 1)

                VStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [baseFill1, baseFill2],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 10, height: 16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color(hex: "999999"))
                                .frame(width: 3, height: 7)
                                .offset(y: 3)
                        )
                }
            }
            .offset(y: armLength / 2 + 8)
            .rotationEffect(.degrees(tonearmAngle), anchor: .top)
            .offset(x: pivotX, y: pivotY)

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [baseFill1, baseFill2],
                            center: .center,
                            startRadius: 0,
                            endRadius: 20
                        )
                    )
                    .frame(width: 40, height: 40)
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.4 : 0.12), radius: 5, x: 0, y: 2)

                Circle()
                    .fill(baseDot)
                    .frame(width: 8, height: 8)
            }
            .offset(x: pivotX, y: pivotY)
        }
    }

    func updateTonearm() {
        withAnimation(.spring(response: 0.7, dampingFraction: 0.65)) {
            // 播放时唱臂落下，暂停时收回
            tonearmAngle = player.isPlaying ? -8 : -38
        }
    }
}

// MARK: - 歌曲信息
extension VinylPlayerLayout {

    var songInfoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(player.currentSong?.name ?? "")
                .font(.system(size: 24, weight: .bold, design: .default))
                .foregroundColor(contentColor)
                .lineLimit(1)

            HStack(spacing: 10) {
                Text(player.currentSong?.artistName ?? "")
                    .font(.system(size: 16, weight: .regular, design: .default))
                    .foregroundColor(secondaryColor)
                    .lineLimit(1)

                Button(action: { showQualitySheet = true }) {
                    Text(player.qualityButtonText)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(secondaryColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(secondaryColor.opacity(0.5), lineWidth: 0.8)
                        )
                }

                if let info = player.streamInfo {
                    Text(streamInfoText(info))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(secondaryColor.opacity(0.7))
                        .lineLimit(1)
                }

                Spacer()

                if let song = player.currentSong {
                    LikeButton(songId: song.id, isQQMusic: song.isQQMusic, size: 20, activeColor: .red, inactiveColor: secondaryColor)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 进度条
extension VinylPlayerLayout {

    var progressSection: some View {
        VStack(spacing: 5) {
            GeometryReader { geo in
                let progress = player.duration > 0
                    ? (isDragging ? dragValue : player.currentTime) / player.duration
                    : 0

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(contentColor.opacity(0.08))
                        .frame(height: 3)

                    Capsule()
                        .fill(contentColor.opacity(0.5))
                        .frame(
                            width: geo.size.width * CGFloat(min(max(progress, 0), 1)),
                            height: 3
                        )
                }
                .contentShape(Rectangle().inset(by: -12))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            let p = min(max(value.location.x / geo.size.width, 0), 1)
                            dragValue = p * player.duration
                        }
                        .onEnded { value in
                            isDragging = false
                            let p = min(max(value.location.x / geo.size.width, 0), 1)
                            player.seek(to: p * player.duration)
                        }
                )
            }
            .frame(height: 20)

            HStack {
                Text(formatTime(isDragging ? dragValue : player.currentTime))
                Spacer()
                Text(formatTime(player.duration))
            }
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundColor(secondaryColor)
        }
    }
}

// MARK: - 控制按钮（圆角矩形风格）
extension VinylPlayerLayout {

    var controlsSection: some View {
        HStack(spacing: 12) {
            // PLAY 按钮 — 大圆角矩形
            Button(action: { player.togglePlayPause() }) {
                HStack(spacing: 8) {
                    if player.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .asideIconForeground))
                            .scaleEffect(0.8)
                    } else {
                        AsideIcon(
                            icon: player.isPlaying ? .pause : .play,
                            size: 18,
                            color: .asideIconForeground
                        )
                    }
                    Text(player.isPlaying ? "PAUSE" : "PLAY")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.asideIconForeground)
                        .tracking(1)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .asideGlass(cornerRadius: 16)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.08), radius: 8, y: 4)
            }
            .buttonStyle(AsideBouncingButtonStyle(scale: 0.95))

            // 上一首
            Button(action: { player.previous() }) {
                AsideIcon(icon: .previous, size: 22, color: contentColor)
                    .frame(width: 50, height: 50)
                    .asideGlass(cornerRadius: 16)
            }
            .buttonStyle(AsideBouncingButtonStyle())

            // 下一首
            Button(action: { player.next() }) {
                AsideIcon(icon: .next, size: 22, color: contentColor)
                    .frame(width: 50, height: 50)
                    .asideGlass(cornerRadius: 16)
            }
            .buttonStyle(AsideBouncingButtonStyle())
        }
    }
}

// MARK: - 辅助
extension VinylPlayerLayout {

    func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite else { return "0:00" }
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// 启动匀速旋转 — 每 8 秒转一圈，无限循环
    func startSpinning() {
        guard !isSpinning else { return }
        isSpinning = true
        // 先设置目标角度（当前 + 360°），用线性动画
        // 通过递归调用实现无限旋转
        spinOnce()
    }

    private func spinOnce() {
        guard isSpinning else { return }
        withAnimation(.linear(duration: 8)) {
            discRotation += 360
        }
        // 8 秒后继续下一圈
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
            spinOnce()
        }
    }

    func streamInfoText(_ info: StreamInfo) -> String {
        var parts: [String] = []
        if let codec = info.audioCodec { parts.append(codec.uppercased()) }
        if let sr = info.sampleRate {
            if sr >= 1000 {
                let khz = Double(sr) / 1000.0
                parts.append(khz == khz.rounded() ? "\(Int(khz))kHz" : String(format: "%.1fkHz", khz))
            } else { parts.append("\(sr)Hz") }
        }
        if let bd = info.bitDepth, bd > 0 { parts.append("\(bd)bit") }
        if let ch = info.channelCount, ch > 2 { parts.append("\(ch)ch") }
        return parts.joined(separator: " · ")
    }
}
