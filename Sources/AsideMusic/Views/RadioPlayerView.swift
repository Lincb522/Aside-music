import SwiftUI
import Combine

/// 收音机风格的播客播放器
struct RadioPlayerView: View {
    let radioId: Int
    @StateObject private var viewModel: RadioDetailViewModel
    @ObservedObject private var player = PlayerManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var currentProgramIndex: Int = 0
    @State private var isDialAnimating = false
    @State private var dialRotation: Double = 0
    @State private var showProgramList = false
    @State private var pulseScale: CGFloat = 1.0

    init(radioId: Int) {
        self.radioId = radioId
        _viewModel = StateObject(wrappedValue: RadioDetailViewModel(radioId: radioId))
    }

    var body: some View {
        ZStack {
            // 背景
            AsideBackground()
                .ignoresSafeArea()

            if viewModel.isLoading && viewModel.radioDetail == nil {
                // 加载中状态
                VStack(spacing: 16) {
                    // 顶部导航栏（始终显示，方便用户返回）
                    topBar
                        .padding(.top, DeviceLayout.headerTopPadding)

                    Spacer()

                    AsideLoadingView(text: "TUNING RADIO")

                    Spacer()
                }
            } else if let error = viewModel.errorMessage, viewModel.radioDetail == nil {
                // 错误状态
                VStack(spacing: 16) {
                    topBar
                        .padding(.top, DeviceLayout.headerTopPadding)

                    Spacer()

                    AsideIcon(icon: .warning, size: 40, color: .asideTextSecondary)
                    Text(error)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.asideTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Button(String(localized: "radio_retry")) {
                        viewModel.fetchDetail()
                    }
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.asideIconForeground)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.asideIconBackground)
                    .clipShape(Capsule())

                    Spacer()
                }
            } else {
                VStack(spacing: 0) {
                    // 顶部导航栏
                    topBar
                        .padding(.top, DeviceLayout.headerTopPadding)

                    Spacer()

                    // 收音机主体
                    radioBody

                    Spacer()

                    // 节目信息
                    programInfo
                        .padding(.bottom, 16)

                    // 频率刻度条
                    frequencyBar
                        .padding(.bottom, 24)

                    // 控制按钮
                    controlButtons
                        .padding(.bottom, 50)
                }
            }
        }
        .onAppear {
            player.isTabBarHidden = true
            viewModel.fetchDetail()
        }
        .onDisappear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                player.isTabBarHidden = false
            }
        }
        .sheet(isPresented: $showProgramList) {
            programListSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
        }
    }

    // MARK: - 顶部导航栏

    private var topBar: some View {
        HStack {
            AsideBackButton(style: .dismiss)

            Spacer()

            VStack(spacing: 2) {
                Text("radio_playing")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.asideTextSecondary)
                    .tracking(1)
                    .textCase(.uppercase)
            }

            Spacer()

            // 节目列表按钮
            Button(action: { showProgramList = true }) {
                AsideIcon(icon: .list, size: 18, color: .asideTextPrimary, lineWidth: 1.4)
                    .frame(width: 40, height: 40)
                    .background(Color.asideSeparator)
                    .clipShape(Circle())
            }
            .buttonStyle(AsideBouncingButtonStyle())
        }
        .padding(.horizontal, 24)
    }

    // MARK: - 收音机主体（圆形封面 + 旋转光环）

    private var radioBody: some View {
        ZStack {
            // 播放时的脉冲光圈
            if isRadioPlaying {
                Circle()
                    .stroke(Color.asideAccentBlue.opacity(0.15), lineWidth: 2)
                    .frame(width: 280, height: 280)
                    .scaleEffect(pulseScale)
                    .opacity(2.0 - Double(pulseScale))
            }

            // 外圈光环
            Circle()
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color.asideAccentBlue.opacity(0.3),
                            Color.asideAccentGreen.opacity(0.2),
                            Color.asideAccentYellow.opacity(0.3),
                            Color.asideAccentBlue.opacity(0.3)
                        ]),
                        center: .center
                    ),
                    lineWidth: 3
                )
                .frame(width: 260, height: 260)
                .rotationEffect(.degrees(dialRotation))

            // 中圈
            Circle()
                .fill(.clear)
                .frame(width: 240, height: 240)
                .glassEffect(.regular, in: .circle)
                .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 8)

            // 封面图
            if let radio = viewModel.radioDetail {
                CachedAsyncImage(url: radio.coverUrl) {
                    Circle()
                        .fill(.clear)
                        .glassEffect(.regular, in: .circle)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 220, height: 220)
                .clipShape(Circle())
                .rotationEffect(.degrees(isRadioPlaying ? dialRotation : 0))
            } else {
                Circle()
                    .fill(.clear)
                    .frame(width: 220, height: 220)
                    .glassEffect(.regular, in: .circle)
                    .overlay(
                        AsideIcon(icon: .radio, size: 56, color: .asideTextSecondary.opacity(0.3), lineWidth: 1.2)
                    )
            }

            // 中心圆点
            Circle()
                .fill(Color.asideIconBackground)
                .frame(width: 16, height: 16)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        }
        .onChange(of: isRadioPlaying) { _, playing in
            if playing {
                startAnimations()
            } else {
                stopPulse()
            }
        }
        .onAppear {
            // 光环始终旋转
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                dialRotation = 360
            }
            if isRadioPlaying {
                startAnimations()
            }
        }
    }

    // MARK: - 动画控制

    private func startAnimations() {
        pulseScale = 1.0
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
            pulseScale = 1.4
        }
    }

    private func stopPulse() {
        withAnimation(.easeOut(duration: 0.3)) {
            pulseScale = 1.0
        }
    }

    // MARK: - 节目信息

    private var programInfo: some View {
        VStack(spacing: 8) {
            // 电台名称
            if let radio = viewModel.radioDetail {
                Text(radio.name)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.asideTextSecondary)
            }

            // 当前节目名称
            if let program = currentProgram {
                Text(program.name ?? String(localized: "radio_unknown_program"))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.asideTextPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                // 时长和播放量
                HStack(spacing: 12) {
                    if !program.durationText.isEmpty {
                        HStack(spacing: 4) {
                            AsideIcon(icon: .clock, size: 12, color: .asideTextSecondary)
                            Text(program.durationText)
                        }
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.asideTextSecondary)
                    }
                    if let listeners = program.listenerCount, listeners > 0 {
                        HStack(spacing: 4) {
                            AsideIcon(icon: .headphones, size: 12, color: .asideTextSecondary)
                            Text(formatCount(listeners))
                        }
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.asideTextSecondary)
                    }
                }
            } else if viewModel.isLoading {
                Text("radio_tuning")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.asideTextSecondary)
            } else {
                Text("radio_no_programs")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.asideTextSecondary)
            }
        }
        .padding(.horizontal, 40)
    }

    // MARK: - 频率刻度条（模拟收音机调频）

    private var frequencyBar: some View {
        VStack(spacing: 8) {
            // 刻度线
            GeometryReader { geo in
                let totalPrograms = viewModel.radioDetail?.programCount ?? max(viewModel.programs.count, 1)
                let progress = totalPrograms > 1
                    ? CGFloat(currentProgramIndex) / CGFloat(totalPrograms - 1)
                    : 0.5

                ZStack(alignment: .leading) {
                    // 刻度背景
                    HStack(spacing: 0) {
                        ForEach(0..<40, id: \.self) { i in
                            let isMajor = i % 5 == 0
                            Rectangle()
                                .fill(Color.asideTextSecondary.opacity(isMajor ? 0.4 : 0.15))
                                .frame(width: 1, height: isMajor ? 16 : 8)
                            if i < 39 {
                                Spacer()
                            }
                        }
                    }

                    // 指示器
                    Circle()
                        .fill(Color.asideAccentRed)
                        .frame(width: 10, height: 10)
                        .shadow(color: .asideAccentRed.opacity(0.5), radius: 4)
                        .offset(x: progress * (geo.size.width - 10))
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: currentProgramIndex)
                }
                .frame(height: 16)
            }
            .frame(height: 16)
            .padding(.horizontal, 40)

            // 节目序号 — 使用电台总节目数
            if !viewModel.programs.isEmpty {
                let total = viewModel.radioDetail?.programCount ?? viewModel.programs.count
                Text(String(format: String(localized: "radio_episode_format"), currentProgramIndex + 1, total))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.asideTextSecondary)
            }
        }
    }

    // MARK: - 控制按钮

    private var controlButtons: some View {
        HStack(spacing: 0) {
            // 上一期
            Button(action: { previousProgram() }) {
                AsideIcon(icon: .skipBack, size: 22, color: .asideTextPrimary, lineWidth: 1.6)
            }
            .frame(width: 50, height: 50)
            .background(Circle().fill(.clear).glassEffect(.regular, in: .circle))
            .clipShape(Circle())
            .buttonStyle(AsideBouncingButtonStyle())

            Spacer()

            // 后退 15 秒
            Button(action: {
                if isOwnContent { player.seekBackward(seconds: 15) }
            }) {
                AsideIcon(icon: .rewind15, size: 22, color: .asideTextPrimary, lineWidth: 1.4)
            }
            .frame(width: 44, height: 44)
            .buttonStyle(AsideBouncingButtonStyle())

            Spacer()

            // 播放/暂停
            Button(action: { handlePlayPause() }) {
                ZStack {
                    Circle()
                        .fill(.clear)
                        .frame(width: 72, height: 72)
                        .glassEffect(.regular, in: .circle)
                        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)

                    if isRadioLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .asideIconForeground))
                            .scaleEffect(1.2)
                    } else {
                        AsideIcon(icon: isRadioPlaying ? .pause : .play, size: 28, color: .asideIconForeground, lineWidth: 2.0)
                            .offset(x: isRadioPlaying ? 0 : 2)
                    }
                }
            }
            .buttonStyle(AsideBouncingButtonStyle(scale: 0.9))

            Spacer()

            // 前进 15 秒
            Button(action: {
                if isOwnContent { player.seekForward(seconds: 15) }
            }) {
                AsideIcon(icon: .forward15, size: 22, color: .asideTextPrimary, lineWidth: 1.4)
            }
            .frame(width: 44, height: 44)
            .buttonStyle(AsideBouncingButtonStyle())

            Spacer()

            // 下一期
            Button(action: { nextProgram() }) {
                AsideIcon(icon: .skipForward, size: 22, color: .asideTextPrimary, lineWidth: 1.6)
            }
            .frame(width: 50, height: 50)
            .background(Circle().fill(.clear).glassEffect(.regular, in: .circle))
            .clipShape(Circle())
            .buttonStyle(AsideBouncingButtonStyle())
        }
        .padding(.horizontal, 32)
    }

    // MARK: - 节目列表 Sheet

    private var programListSheet: some View {
        VStack(spacing: 0) {
            // 头部：封面 + 电台信息 + 当前播放
            programListHeader
            
            // 分隔线
            Rectangle()
                .fill(Color.asideSeparator)
                .frame(height: 0.5)

            // 节目列表
            if viewModel.programs.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    AsideIcon(icon: .micSlash, size: 44, color: .asideTextSecondary.opacity(0.3))
                    Text("radio_no_programs")
                        .font(.rounded(size: 15, weight: .medium))
                        .foregroundColor(.asideTextSecondary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(viewModel.programs.enumerated()), id: \.element.id) { index, program in
                            programSheetRow(program: program, index: index)
                                .onTapWithHaptic {
                                    playProgramAt(index: index)
                                    showProgramList = false
                                }

                            if program.id == viewModel.programs.last?.id {
                                Color.clear.frame(height: 1)
                                    .onAppear { viewModel.loadMorePrograms() }
                            }
                        }

                        if viewModel.isLoadingMore {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("mv_loading_more")
                                    .font(.rounded(size: 13))
                                    .foregroundColor(.asideTextSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                        }

                        if !viewModel.hasMore && !viewModel.programs.isEmpty {
                            NoMoreDataView()
                        }
                    }
                    .padding(.top, 6)
                    .padding(.bottom, 30)
                }
            }
        }
        .background {
            Rectangle()
                .fill(.clear)
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
        }
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - 节目列表头部

    private var programListHeader: some View {
        VStack(spacing: 14) {
            // 拖拽指示条
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.asideTextSecondary.opacity(0.25))
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            HStack(spacing: 14) {
                // 电台封面
                if let radio = viewModel.radioDetail {
                    CachedAsyncImage(url: radio.coverUrl) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.asideTextSecondary.opacity(0.08))
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.radioDetail?.name ?? String(localized: "radio_program_list"))
                        .font(.rounded(size: 17, weight: .bold))
                        .foregroundColor(.asideTextPrimary)
                        .lineLimit(1)

                    // 当前播放状态
                    if let program = currentProgram {
                        HStack(spacing: 6) {
                            // 迷你波形
                            if isRadioPlaying {
                                HStack(spacing: 1.5) {
                                    ForEach(0..<3, id: \.self) { i in
                                        RoundedRectangle(cornerRadius: 0.5)
                                            .fill(Color.asideAccentBlue)
                                            .frame(width: 2, height: isRadioPlaying ? CGFloat([5, 10, 7][i]) : 3)
                                            .animation(
                                                .easeInOut(duration: 0.4).repeatForever().delay(Double(i) * 0.12),
                                                value: isRadioPlaying
                                            )
                                    }
                                }
                                .frame(height: 10)
                            }

                            Text(program.name ?? String(localized: "radio_unknown_program"))
                                .font(.rounded(size: 13))
                                .foregroundColor(.asideTextSecondary)
                                .lineLimit(1)
                        }
                    } else {
                        if let count = viewModel.radioDetail?.programCount {
                            Text(String(format: String(localized: "radio_total_episodes"), count))
                                .font(.rounded(size: 13))
                                .foregroundColor(.asideTextSecondary)
                        }
                    }
                }

                Spacer()

                // 节目总数胶囊
                if let count = viewModel.radioDetail?.programCount {
                    Text(String(format: String(localized: "radio_episode_count"), count))
                        .font(.rounded(size: 12, weight: .medium))
                        .foregroundColor(.asideTextSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.asideSeparator)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)
        }
    }

    // MARK: - 节目行

    private func programSheetRow(program: RadioProgram, index: Int) -> some View {
        let isCurrent = index == currentProgramIndex && isOwnContent && player.currentSong?.id == program.mainSong?.id

        return HStack(spacing: 14) {
            // 序号或播放波形
            ZStack {
                if isCurrent && isRadioPlaying {
                    // 迷你波形动画
                    HStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color.asideAccentBlue)
                                .frame(width: 2.5, height: isRadioPlaying ? CGFloat([6, 12, 8][i]) : 3)
                                .animation(
                                    .easeInOut(duration: 0.4).repeatForever().delay(Double(i) * 0.1),
                                    value: isRadioPlaying
                                )
                        }
                    }
                } else if isCurrent {
                    AsideIcon(icon: .pause, size: 14, color: .asideAccentBlue, lineWidth: 1.6)
                } else {
                    Text("\(index + 1)")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(.asideTextSecondary.opacity(0.5))
                }
            }
            .frame(width: 28)

            // 节目信息
            VStack(alignment: .leading, spacing: 3) {
                Text(program.name ?? String(localized: "radio_unknown_program"))
                    .font(.rounded(size: 15, weight: isCurrent ? .semibold : .regular))
                    .foregroundColor(isCurrent ? .asideAccentBlue : .asideTextPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if !program.durationText.isEmpty {
                        Text(program.durationText)
                            .font(.rounded(size: 11))
                            .foregroundColor(.asideTextSecondary.opacity(0.7))
                    }
                    if let listeners = program.listenerCount, listeners > 0 {
                        Circle()
                            .fill(Color.asideTextSecondary.opacity(0.3))
                            .frame(width: 3, height: 3)
                        Text("\(formatCount(listeners))" + String(localized: "radio_play_suffix"))
                            .font(.rounded(size: 11))
                            .foregroundColor(.asideTextSecondary.opacity(0.7))
                    }
                }
            }

            Spacer(minLength: 0)

            // 右侧：当前播放标记 或 时长胶囊
            if isCurrent {
                Text("radio_now_playing")
                    .font(.rounded(size: 10, weight: .semibold))
                    .foregroundColor(.asideAccentBlue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.asideAccentBlue.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 24)
        .contentShape(Rectangle())
    }

    // MARK: - 播放逻辑

    /// 当前 player 是否正在播放本电台的内容
    private var isOwnContent: Bool {
        if case .podcast(let id) = player.playSource, id == radioId {
            return true
        }
        return false
    }

    /// 本电台是否正在播放（只有播放源匹配时才为 true）
    private var isRadioPlaying: Bool {
        isOwnContent && player.isPlaying
    }

    /// 本电台是否正在加载
    private var isRadioLoading: Bool {
        isOwnContent && player.isLoading
    }

    private var currentProgram: RadioProgram? {
        guard !viewModel.programs.isEmpty,
              currentProgramIndex >= 0,
              currentProgramIndex < viewModel.programs.count else { return nil }
        return viewModel.programs[currentProgramIndex]
    }

    private func handlePlayPause() {
        if isOwnContent && player.currentSong != nil {
            // 当前播放的是本电台内容，直接切换播放/暂停
            player.togglePlayPause()
        } else if let program = currentProgram, let song = program.mainSong {
            // 当前不是本电台内容，或者还没开始播放，启动播客播放
            let songs = viewModel.songsFromPrograms()
            player.playPodcast(song: song, in: songs, radioId: radioId)
        }
    }

    private func playProgramAt(index: Int) {
        guard index >= 0, index < viewModel.programs.count else { return }
        let program = viewModel.programs[index]
        guard let song = program.mainSong else { return }

        currentProgramIndex = index
        let songs = viewModel.songsFromPrograms()
        player.playPodcast(song: song, in: songs, radioId: radioId)
    }

    private func nextProgram() {
        let nextIndex = currentProgramIndex + 1
        if nextIndex < viewModel.programs.count {
            playProgramAt(index: nextIndex)
        }
        // 接近末尾时加载更多
        if nextIndex >= viewModel.programs.count - 3 {
            viewModel.loadMorePrograms()
        }
    }

    private func previousProgram() {
        let prevIndex = currentProgramIndex - 1
        if prevIndex >= 0 {
            playProgramAt(index: prevIndex)
        }
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 100_000_000 {
            return String(format: "%.1f亿", Double(count) / 100_000_000)
        } else if count >= 10_000 {
            return String(format: "%.1f万", Double(count) / 10_000)
        }
        return "\(count)"
    }
}
