//
//  AriaShelfWall.swift
//  Monologue
//
//  沉浸舞台歌架墙 —— 复刻 folia-major 首页 Grid3DSlider：
//  可惯性拖拽的封面长廊，居中卡片放大（1.22×）、两侧按与中心的
//  像素距离衰减（scale → 0.5 / opacity → 0.15 / y 微抬），
//  点侧边卡片滚到中央、点居中卡片播放；墙下方跟随焦点曲目的
//  大标题 + 等宽小字信息（folia 的 focused item caption）。
//

import SwiftUI

struct AriaShelfWall: View {
    @Binding var isOpen: Bool
    let palette: AriaPalette

    @ObservedObject private var player = PlayerManager.shared

    /// 连续滚动位置（单位：pt，0 = 第一张居中）
    @State private var scrollX: CGFloat = 0
    @State private var dragStartX: CGFloat?

    // 歌架内搜索：三平台搜歌直接入架
    @State private var searchOpen = false
    @State private var searchQuery = ""
    @State private var searchPlatform: MusicSource = .netease
    @State private var searchResults: [Song] = []
    @State private var isSearching = false
    @State private var addedSongIDs: Set<Int> = []
    @FocusState private var searchFieldFocused: Bool
    /// 横屏键盘实际高度：结果列表按此让位（舞台整体不参与系统键盘避让）
    @State private var keyboardHeight: CGFloat = 0

    private var queue: [Song] {
        player.currentContextList.filter { $0.podcastRadioId == nil }
    }

    private var currentIndex: Int? {
        guard let currentId = player.currentSong?.id else { return nil }
        return queue.firstIndex(where: { $0.id == currentId })
    }

    private var trimmedQuery: String {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 平台或关键词变化都会取消旧任务重新搜索
    private var searchTaskKey: String {
        "\(searchPlatform.rawValue)|\(trimmedQuery)"
    }

    var body: some View {
        GeometryReader { geo in
            // 先给顶栏与底部歌名标题预留空间，再按剩余高度定卡片尺寸：
            // 聚焦卡放大 1.22×，若直接按整屏高度取尺寸，横屏手机上
            // 卡片底缘会压到下方的歌名标题（歌架名字与封面重叠）
            let topReserve: CGFloat = DeviceLayout.headerTopPadding + 52
            let captionReserve: CGFloat = 92
            let availableHeight = max(140, geo.size.height - topReserve - captionReserve)
            let coverSize = min(availableHeight / 1.30, 280)
            let wallCenterOffset = (topReserve - captionReserve) / 2
            let pitch = coverSize + 46
            let maxScroll = pitch * CGFloat(max(queue.count - 1, 0))
            let focused = focusedIndex(pitch: pitch)

            ZStack {
                // 玻璃暗幕（folia GridMap：整屏浮层盖在舞台上）
                ZStack {
                    Rectangle().fill(.ultraThinMaterial)
                    Color.black.opacity(0.38)
                }
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { close() }

                if searchOpen {
                    // 搜索态：黑玻璃搜索层盖住长廊
                    searchOverlay(geo: geo)
                } else if queue.isEmpty {
                    Text(String(localized: "队列为空"))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                } else {
                    // 封面长廊（居中在顶栏与底部标题之间的可用带内）
                    wall(coverSize: coverSize, pitch: pitch, geo: geo, centerOffset: wallCenterOffset)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .contentShape(Rectangle())
                        .gesture(dragGesture(pitch: pitch, maxScroll: maxScroll))

                    // 焦点曲目信息（folia：墙下方 2xl 标题 + mono 小字）
                    VStack {
                        Spacer()
                        focusCaption(focused: focused)
                            .padding(.bottom, 26)
                    }
                    .allowsHitTesting(false)
                }

                // 顶栏：普通态是「关闭 + 标题 + 搜索」；
                // 搜索态压成单行「返回 + 搜索框 + 平台切换」，把纵向空间全部让给结果
                VStack {
                    if searchOpen {
                        searchTopBar
                    } else {
                        HStack {
                            closeButton
                            Spacer()
                            Text(String(localized: "歌架"))
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.9))
                            Text("\(queue.count)")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.4))
                            Spacer()
                            searchToggleButton
                        }
                        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    }
                    Spacer()
                }
                .padding(.top, DeviceLayout.headerTopPadding)
            }
            .onAppear {
                if let current = currentIndex {
                    scrollX = pitch * CGFloat(current)
                }
            }
            .onChange(of: player.currentSong?.id) { _, _ in
                guard let current = currentIndex else { return }
                withAnimation(.spring(response: 0.55, dampingFraction: 0.86)) {
                    scrollX = pitch * CGFloat(current)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { note in
                if let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                    withAnimation(.easeOut(duration: 0.22)) { keyboardHeight = frame.height }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation(.easeOut(duration: 0.22)) { keyboardHeight = 0 }
            }
            .task(id: searchTaskKey) {
                await performShelfSearch(trimmedQuery)
            }
        }
    }

    // MARK: 搜索（三平台搜歌直接入架）

    private var searchToggleButton: some View {
        Button {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                searchOpen.toggle()
            }
            if searchOpen {
                searchFieldFocused = true
            } else {
                searchQuery = ""
                searchResults = []
                searchFieldFocused = false
            }
        } label: {
            MonologueIcon(
                icon: searchOpen ? .close : .search,
                size: 15,
                color: .white.opacity(0.9),
                lineWidth: 1.8
            )
            .frame(width: 44, height: 44)
            .background(
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(Circle().fill(Color.black.opacity(0.25)))
            )
            .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
        }
        .buttonStyle(MonologueBouncingButtonStyle())
    }

    /// 搜索态顶栏：返回 + 搜索框 + 平台切换压成一行（横屏宽度充裕），
    /// 原「标题行 + 搜索行 + 平台行」三层结构省出的高度全部给结果列表
    private var searchTopBar: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                    searchOpen = false
                }
                searchQuery = ""
                searchResults = []
                searchFieldFocused = false
            } label: {
                MonologueIcon(icon: .close, size: 14, color: .white.opacity(0.9), lineWidth: 1.8)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay(Circle().fill(Color.black.opacity(0.25)))
                    )
                    .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
            }
            .buttonStyle(MonologueBouncingButtonStyle())

            searchField
                .frame(maxWidth: 420)

            platformSwitcher

            Spacer(minLength: 0)
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
    }

    private func searchOverlay(geo: GeometryProxy) -> some View {
        VStack(spacing: 10) {
            // 给顶栏（返回 + 搜索框 + 平台切换单行）让位
            Color.clear.frame(height: DeviceLayout.headerTopPadding + 48)

            if trimmedQuery.isEmpty {
                VStack(spacing: 7) {
                    MonologueIcon(icon: .search, size: 26, color: .white.opacity(0.16), lineWidth: 2)
                    Text(String(localized: "搜索三平台歌曲，直接加入歌架"))
                        .font(.system(size: 12.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.35))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchResults.isEmpty, !isSearching {
                Text(String(localized: "没有找到相关歌曲"))
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(searchResults) { song in
                            wallSearchResultRow(song: song)
                        }
                    }
                    .padding(.bottom, 12)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.immediately)
            }
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .frame(maxWidth: 620, alignment: .leading)
        // 键盘弹起时结果区整体让位，最后几行不会藏在键盘下面
        .padding(.bottom, keyboardHeight > 0 ? keyboardHeight + 6 : 0)
        .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        .contentShape(Rectangle())
        .onTapGesture { searchFieldFocused = false }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            MonologueIcon(icon: .search, size: 14, color: .white.opacity(0.4), lineWidth: 1.7)

            TextField(String(localized: "搜索歌曲加入歌架"), text: $searchQuery)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .tint(palette.accent)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($searchFieldFocused)

            if isSearching {
                ProgressView()
                    .controlSize(.mini)
                    .tint(.white.opacity(0.5))
            } else if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    MonologueIcon(icon: .xmark, size: 9, color: .white.opacity(0.45), lineWidth: 1.7)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
    }

    /// NCM / QCM / QSM 平台切换：平台色圆点 + 黑玻璃胶囊（顶栏内联紧凑版）
    private var platformSwitcher: some View {
        HStack(spacing: 6) {
            ForEach([MusicSource.netease, .qqmusic, .qishui], id: \.self) { source in
                let isSelected = searchPlatform == source

                Button {
                    guard searchPlatform != source else { return }
                    searchPlatform = source
                    searchResults = []
                } label: {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(source.themedBadgeColor)
                            .frame(width: 5, height: 5)
                            .opacity(isSelected ? 1 : 0.45)

                        Text(source.displayName)
                            .font(.system(size: 11.5, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(isSelected ? 0.95 : 0.45))
                    }
                    .padding(.horizontal, 13)
                    .frame(height: 30)
                    .background(Capsule().fill(Color.white.opacity(isSelected ? 0.13 : 0.05)))
                    .overlay(Capsule().stroke(Color.white.opacity(isSelected ? 0.16 : 0), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: searchPlatform)
    }

    private func wallSearchResultRow(song: Song) -> some View {
        let inShelf = addedSongIDs.contains(song.id)
            || queue.contains(where: { $0.id == song.id })

        return Button {
            guard !inShelf else { return }
            player.addToQueue(song: song)
            addedSongIDs.insert(song.id)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 10) {
                CachedAsyncImage(url: song.coverUrl?.sized(100)) {
                    Rectangle().fill(Color.white.opacity(0.06))
                }
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2.5) {
                    Text(song.name)
                        .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                    Text(song.artistName)
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                MonologueIcon(
                    icon: inShelf ? .checkmark : .add,
                    size: 13,
                    color: inShelf ? palette.accent : .white.opacity(0.6),
                    lineWidth: 1.8
                )
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.white.opacity(inShelf ? 0.05 : 0.08)))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func performShelfSearch(_ keyword: String) async {
        guard !keyword.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }

        // 停顿片刻再搜，避免逐字请求
        try? await Task.sleep(nanoseconds: 380_000_000)
        guard !Task.isCancelled else { return }

        isSearching = true
        defer { isSearching = false }

        do {
            switch searchPlatform {
            case .qqmusic:
                for try await songs in APIService.shared
                    .searchQQSongs(keyword: keyword).values {
                    guard !Task.isCancelled else { return }
                    searchResults = songs
                    break
                }
            case .qishui:
                for try await songs in APIService.shared
                    .searchQishuiSongs(keyword: keyword).values {
                    guard !Task.isCancelled else { return }
                    searchResults = songs
                    break
                }
            default:
                for try await songs in APIService.shared
                    .searchSongs(keyword: keyword).values {
                    guard !Task.isCancelled else { return }
                    searchResults = songs
                    break
                }
            }
        } catch {
            guard !Task.isCancelled else { return }
            searchResults = []
        }
    }

    // MARK: 长廊

    @ViewBuilder
    private func wall(coverSize: CGFloat, pitch: CGFloat, geo: GeometryProxy, centerOffset: CGFloat) -> some View {
        let halfWindow = geo.size.width / 2 + coverSize
        // 只装配视窗附近的卡片（folia 的 LOD/懒加载思路）
        let lower = max(0, Int((scrollX - halfWindow) / pitch))
        let upper = min(queue.count - 1, Int((scrollX + halfWindow) / pitch) + 1)

        ZStack {
            if lower <= upper {
                ForEach(lower...upper, id: \.self) { index in
                    let offset = CGFloat(index) * pitch - scrollX
                    // folia updateCardTransforms：maxDist 600 的距离衰减
                    let t = min(abs(offset) / 600, 1)
                    let scale = 1.22 - 0.72 * t
                    let cardOpacity = max(0.15, 1.0 - 0.85 * t)
                    let lift = -6 * (1 - t)

                    card(song: queue[index], index: index, size: coverSize, pitch: pitch)
                        .scaleEffect(scale)
                        .opacity(cardOpacity)
                        .offset(x: offset, y: lift)
                        .zIndex(Double(10 - 9 * t))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // 长廊居中于顶栏与底部歌名标题之间的可用带，避免与标题重叠
        .offset(y: centerOffset)
    }

    @ViewBuilder
    private func card(song: Song, index: Int, size: CGFloat, pitch: CGFloat) -> some View {
        let isFocused = index == focusedIndex(pitch: pitch)

        CachedAsyncImage(url: song.coverUrl?.sized(500)) {
            Rectangle().fill(Color.white.opacity(0.06))
                .overlay(
                    MonologueIcon(icon: .album, size: 44, color: .white.opacity(0.15))
                )
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    isFocused ? Color.white.opacity(0.30) : Color.white.opacity(0.10),
                    lineWidth: isFocused ? 2 : 1
                )
        )
        .shadow(color: .black.opacity(0.45), radius: 22, y: 12)
        .onTapGesture {
            if isFocused {
                player.playFromQueue(song: song)
            } else {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                    scrollX = pitch * CGFloat(index)
                }
            }
        }
    }

    // MARK: 焦点信息

    @ViewBuilder
    private func focusCaption(focused: Int) -> some View {
        if queue.indices.contains(focused) {
            let song = queue[focused]
            let isCurrent = player.currentSong?.id == song.id

            VStack(spacing: 5) {
                HStack(spacing: 8) {
                    if isCurrent {
                        MonologueIcon(
                            icon: player.isPlaying ? .waveform : .pause,
                            size: 14,
                            color: palette.accent
                        )
                    }
                    Text(song.name)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                Text("\(song.artistName)  ·  \(focused + 1)/\(queue.count)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
            }
            .padding(.horizontal, 40)
            .animation(.easeOut(duration: 0.18), value: focused)
        }
    }

    // MARK: 手势（folia：1.5× 拖拽增益 + 动量投掷 + 吸附）

    private func dragGesture(pitch: CGFloat, maxScroll: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                if dragStartX == nil { dragStartX = scrollX }
                var next = (dragStartX ?? 0) - value.translation.width * 1.15
                // 边缘橡皮筋
                if next < 0 { next *= 0.35 }
                if next > maxScroll { next = maxScroll + (next - maxScroll) * 0.35 }
                scrollX = next
            }
            .onEnded { value in
                dragStartX = nil
                // 用预测终点做动量投掷，再吸附到最近卡位
                let momentum = (value.predictedEndTranslation.width - value.translation.width) * 1.15
                let projected = scrollX - momentum
                let target = min(max(round(projected / pitch), 0), CGFloat(max(queue.count - 1, 0)))
                withAnimation(.spring(response: 0.55, dampingFraction: 0.86)) {
                    scrollX = target * pitch
                }
            }
    }

    // MARK: 工具

    private func focusedIndex(pitch: CGFloat) -> Int {
        guard pitch > 0, !queue.isEmpty else { return 0 }
        return min(max(Int(round(scrollX / pitch)), 0), queue.count - 1)
    }

    private func close() {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
            isOpen = false
        }
    }

    private var closeButton: some View {
        Button {
            close()
        } label: {
            MonologueIcon(icon: .close, size: 16, color: .white.opacity(0.9))
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(Circle().fill(Color.black.opacity(0.25)))
                )
                .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
        }
        .buttonStyle(MonologueBouncingButtonStyle())
    }
}
