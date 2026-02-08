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

                    AsideLoadingView(text: "加载电台中...")

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
                    Button("重试") {
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
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - 顶部导航栏

    private var topBar: some View {
        HStack {
            AsideBackButton(style: .dismiss)

            Spacer()

            VStack(spacing: 2) {
                Text("电台播放")
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
                .fill(Color.asideCardBackground)
                .frame(width: 240, height: 240)
                .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 8)

            // 封面图
            if let radio = viewModel.radioDetail {
                CachedAsyncImage(url: radio.coverUrl) {
                    Circle()
                        .fill(Color.asideCardBackground)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 220, height: 220)
                .clipShape(Circle())
                .rotationEffect(.degrees(isRadioPlaying ? dialRotation : 0))
            } else {
                Circle()
                    .fill(Color.asideCardBackground)
                    .frame(width: 220, height: 220)
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
        .onAppear {
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                dialRotation = 360
            }
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
                Text(program.name ?? "未知节目")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.asideTextPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                // 时长和播放量
                HStack(spacing: 12) {
                    if !program.durationText.isEmpty {
                        Label(program.durationText, systemImage: "clock")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.asideTextSecondary)
                    }
                    if let listeners = program.listenerCount, listeners > 0 {
                        Label(formatCount(listeners), systemImage: "headphones")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.asideTextSecondary)
                    }
                }
            } else if viewModel.isLoading {
                Text("调频中...")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.asideTextSecondary)
            } else {
                Text("暂无节目")
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
                Text("第 \(currentProgramIndex + 1) / \(total) 期")
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
            .background(Color.asideCardBackground)
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
                        .fill(Color.asideIconBackground)
                        .frame(width: 72, height: 72)
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
            .background(Color.asideCardBackground)
            .clipShape(Circle())
            .buttonStyle(AsideBouncingButtonStyle())
        }
        .padding(.horizontal, 32)
    }

    // MARK: - 节目列表 Sheet

    private var programListSheet: some View {
        NavigationStack {
            ZStack {
                AsideBackground()
                    .ignoresSafeArea()

                if viewModel.programs.isEmpty {
                    VStack(spacing: 12) {
                        AsideIcon(icon: .micSlash, size: 36, color: .asideTextSecondary)
                        Text("暂无节目")
                            .font(.system(size: 15, design: .rounded))
                            .foregroundColor(.asideTextSecondary)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(viewModel.programs.enumerated()), id: \.element.id) { index, program in
                                programSheetRow(program: program, index: index)
                                    .onTapGesture {
                                        playProgramAt(index: index)
                                        showProgramList = false
                                    }

                                if program.id == viewModel.programs.last?.id {
                                    Color.clear.frame(height: 1)
                                        .onAppear { viewModel.loadMorePrograms() }
                                }
                            }

                            if viewModel.isLoadingMore {
                                ProgressView()
                                    .padding(.vertical, 16)
                            }

                            if !viewModel.hasMore && !viewModel.programs.isEmpty {
                                NoMoreDataView()
                            }
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle(viewModel.radioDetail?.name ?? "节目列表")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func programSheetRow(program: RadioProgram, index: Int) -> some View {
        let isCurrent = index == currentProgramIndex && isOwnContent && player.currentSong?.id == program.mainSong?.id

        return HStack(spacing: 14) {
            // 序号或播放指示
            ZStack {
                if isCurrent && isRadioPlaying {
                    AsideIcon(icon: .waveform, size: 14, color: .asideAccentBlue, lineWidth: 1.4)
                        .frame(width: 28)
                } else {
                    Text("\(index + 1)")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.asideTextSecondary)
                        .frame(width: 28)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(program.name ?? "未知节目")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(isCurrent ? .asideAccentBlue : .asideTextPrimary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if !program.durationText.isEmpty {
                        Text(program.durationText)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.asideTextSecondary)
                    }
                }
            }

            Spacer()

            if program.mainSong == nil {
                Text("不可播放")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.asideTextSecondary.opacity(0.5))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
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
