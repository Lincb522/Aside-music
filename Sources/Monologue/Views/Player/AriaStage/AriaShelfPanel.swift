//
//  AriaShelfPanel.swift
//  Monologue
//
//  沉浸舞台统一面板 —— 复刻 folia-major UnifiedPanel：
//  右下角生长出的 320pt 黑玻璃圆角卡片（scale 0.9 → 1 / 右下角锚点），
//  顶部整幅封面，下面一排 pill 式 tab（封面信息 / 歌架 / 舞台调校）。
//  配色克制：chrome 只用白/黑透明度，accent 仅点缀当前曲目与滑杆。
//

import SwiftUI

enum AriaPanelTab {
    case cover
    case queue
    case tuning
}

struct AriaUnifiedPanel: View {
    @Binding var isOpen: Bool
    @Binding var tab: AriaPanelTab
    /// 搜索框聚焦时上抛给舞台：面板改锚到右上角，避开横屏键盘
    @Binding var searchActive: Bool
    let palette: AriaPalette
    let maxHeight: CGFloat

    @ObservedObject private var player = PlayerManager.shared

    // 歌架内搜索：直接搜歌加入歌架（支持三平台切换）
    @State private var searchQuery = ""
    @State private var searchPlatform: MusicSource = .netease
    @State private var searchResults: [Song] = []
    @State private var isSearching = false
    @State private var addedSongIDs: Set<Int> = []
    @FocusState private var searchFocused: Bool

    private let basePanelWidth: CGFloat = 320

    private var queue: [Song] {
        player.currentContextList.filter { $0.podcastRadioId == nil }
    }

    private var trimmedQuery: String {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 歌架搜索态：键盘弹起或已输入关键词。
    /// 此时收起封面（键盘弹起时连 tab 条一起收起），把面板高度全部让给结果列表。
    private var searchMode: Bool {
        tab == .queue && (searchFocused || !trimmedQuery.isEmpty)
    }

    /// 搜索态加宽面板，结果行更完整；横屏宽度充裕，向左生长无遮挡
    private var panelWidth: CGFloat {
        searchMode ? 392 : basePanelWidth
    }

    /// 平台或关键词变化都会取消旧任务重新搜索
    private var searchTaskKey: String {
        "\(searchPlatform.rawValue)|\(trimmedQuery)"
    }

    private var currentIndex: Int? {
        guard let currentId = player.currentSong?.id else { return nil }
        return queue.firstIndex(where: { $0.id == currentId })
    }

    var body: some View {
        VStack(spacing: 14) {
            // 搜索态收起封面，键盘弹起时连 tab 条一起收起：
            // 面板高度全部让给搜索框 + 结果列表
            if !searchMode {
                coverBlock
                    .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .top)))
            }
            if !(searchMode && searchFocused) {
                tabSwitcher
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
            }

            switch tab {
            case .cover:
                coverInfoTab
            case .queue:
                queueTab
            case .tuning:
                tuningTab
            }
        }
        .padding(16)
        .frame(width: panelWidth)
        .frame(maxHeight: maxHeight, alignment: .top)
        .fixedSize(horizontal: false, vertical: tab == .cover)
        .background(panelGlass)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.4), radius: 30, y: 14)
        .animation(.spring(response: 0.36, dampingFraction: 0.86), value: searchMode)
        .animation(.spring(response: 0.36, dampingFraction: 0.86), value: searchFocused)
        .onChange(of: searchFocused) { _, focused in
            withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                searchActive = focused
            }
        }
        .onChange(of: tab) { _, _ in
            searchFocused = false
        }
        .onDisappear {
            searchActive = false
        }
    }

    // folia：bg-black/40 + backdrop-blur-3xl，无描边只留投影
    private var panelGlass: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            Color.black.opacity(0.32)
        }
    }

    // MARK: 封面块（面板顶部整幅封面，高度按屏幕自适应）

    private var coverBlock: some View {
        let side = min(panelWidth - 32, max(120, maxHeight * 0.36))
        return CachedAsyncImage(url: player.currentSong?.coverUrl?.sized(500)) {
            Rectangle().fill(Color.white.opacity(0.06))
                .overlay(
                    MonologueIcon(icon: .album, size: 36, color: .white.opacity(0.2))
                )
        }
        .frame(width: panelWidth - 32, height: side)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
    }

    // MARK: Tab 切换（folia：bg-white/5 容器 + 选中 bg-white/10）

    private var tabSwitcher: some View {
        HStack(spacing: 0) {
            tabButton(.cover, icon: .musicNote)
            tabButton(.queue, icon: .list)
            tabButton(.tuning, icon: .settings)
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }

    private func tabButton(_ target: AriaPanelTab, icon: MonologueIcon.IconType) -> some View {
        let selected = tab == target
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                tab = target
            }
        } label: {
            MonologueIcon(icon: icon, size: 16, color: .white)
                .opacity(selected ? 1 : 0.4)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(selected ? Color.white.opacity(0.10) : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: 封面信息 tab（folia CoverTab：居中大标题 + 弱化歌手/专辑）

    private var coverInfoTab: some View {
        VStack(spacing: 12) {
            VStack(spacing: 4) {
                Text(player.currentSong?.name ?? String(localized: "未在播放"))
                    .monologuePlayerDisplayFont(
                        size: 20,
                        weight: .bold,
                        fallback: .system(size: 20, weight: .bold, design: .rounded)
                    )
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Text(player.currentSong?.artistName ?? "")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            }

            HStack(spacing: 22) {
                if let song = player.currentSong {
                    LikeButton(
                        songId: song.id,
                        isQQMusic: song.isQQMusic,
                        song: song,
                        size: 22,
                        activeColor: .red,
                        inactiveColor: .white.opacity(0.6)
                    )
                }

                Button {
                    player.switchMode()
                } label: {
                    MonologueIcon(icon: player.mode.monologueIcon, size: 20, color: .white.opacity(0.6))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(MonologueBouncingButtonStyle())
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity)
    }

    // MARK: 歌架 tab（folia QueueTab + 架内搜索）

    @ViewBuilder
    private var queueTab: some View {
        VStack(spacing: 8) {
            shelfSearchField

            if !trimmedQuery.isEmpty {
                shelfPlatformSwitcher
                searchResultList
            } else if queue.isEmpty {
                Text(String(localized: "队列为空"))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                trackList
            }
        }
        .task(id: searchTaskKey) {
            await performShelfSearch(trimmedQuery)
        }
    }

    /// NCM / QCM / QSM 平台切换（面板紧凑版）
    private var shelfPlatformSwitcher: some View {
        HStack(spacing: 5) {
            ForEach([MusicSource.netease, .qqmusic, .qishui], id: \.self) { source in
                let isSelected = searchPlatform == source

                Button {
                    guard searchPlatform != source else { return }
                    searchPlatform = source
                    searchResults = []
                } label: {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(source.themedBadgeColor)
                            .frame(width: 4, height: 4)
                            .opacity(isSelected ? 1 : 0.45)

                        Text(source.displayName)
                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(isSelected ? 0.95 : 0.42))
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 25)
                    .background(Capsule().fill(Color.white.opacity(isSelected ? 0.12 : 0.045)))
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: searchPlatform)
    }

    /// 歌架内嵌搜索框：folia 同款黑玻璃圆角
    private var shelfSearchField: some View {
        HStack(spacing: 8) {
            MonologueIcon(icon: .search, size: 13, color: .white.opacity(0.4), lineWidth: 1.7)

            TextField(
                String(localized: "搜索歌曲加入歌架"),
                text: $searchQuery
            )
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(.white)
            .tint(palette.accent)
            .autocorrectionDisabled()
            .submitLabel(.search)
            .focused($searchFocused)
            .onSubmit { searchFocused = false }

            if isSearching {
                ProgressView()
                    .controlSize(.mini)
                    .tint(.white.opacity(0.5))
            } else if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                    searchFocused = false
                } label: {
                    MonologueIcon(icon: .xmark, size: 9, color: .white.opacity(0.45), lineWidth: 1.7)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
            } else if searchFocused {
                // 未输入内容时给一个显式收起键盘的出口
                Button {
                    searchFocused = false
                } label: {
                    MonologueIcon(icon: .chevronDown, size: 11, color: .white.opacity(0.45), lineWidth: 1.7)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
            } else if !queue.isEmpty {
                // 取代原来的「歌架 N」标题行：队列数量收进搜索框尾部
                Text("\(queue.count)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 36)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    /// 搜索结果：与歌架行同布局，行尾加号一键入架
    @ViewBuilder
    private var searchResultList: some View {
        if searchResults.isEmpty, !isSearching {
            Text(String(localized: "没有找到相关歌曲"))
                .font(.system(size: 12.5, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.4))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(searchResults) { song in
                        searchResultRow(song: song)
                    }
                }
                .padding(.bottom, 4)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.immediately)
        }
    }

    private func searchResultRow(song: Song) -> some View {
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
                .frame(width: 38, height: 38)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(song.name)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
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
                .frame(width: 26, height: 26)
                .background(
                    Circle().fill(Color.white.opacity(inShelf ? 0.05 : 0.08))
                )
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

    private var trackList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(queue.enumerated()), id: \.offset) { index, song in
                        shelfRow(song: song, index: index)
                            .id(index)
                    }
                }
                .padding(.bottom, 4)
            }
            .scrollIndicators(.hidden)
            .onAppear {
                guard let current = currentIndex else { return }
                // folia：先无动画跳到目标上方，再平滑滚到中央
                proxy.scrollTo(max(0, current - 8), anchor: .top)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    withAnimation(.easeOut(duration: 0.45)) {
                        proxy.scrollTo(current, anchor: .center)
                    }
                }
            }
            .onChange(of: player.currentSong?.id) { _, _ in
                guard isOpen, let current = currentIndex else { return }
                withAnimation(.easeOut(duration: 0.45)) {
                    proxy.scrollTo(current, anchor: .center)
                }
            }
        }
    }

    @ViewBuilder
    private func shelfRow(song: Song, index: Int) -> some View {
        let isActive = player.currentSong?.id == song.id

        Button {
            player.playFromQueue(song: song)
        } label: {
            HStack(spacing: 10) {
                CachedAsyncImage(url: song.coverUrl?.sized(100)) {
                    Rectangle().fill(Color.white.opacity(0.06))
                }
                .frame(width: 38, height: 38)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(song.name)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(isActive ? palette.accent : .white.opacity(0.9))
                        .lineLimit(1)
                    Text(song.artistName)
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if isActive {
                    MonologueIcon(
                        icon: player.isPlaying ? .waveform : .pause,
                        size: 13,
                        color: palette.accent
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isActive ? Color.white.opacity(0.08) : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: 调校 tab（folia ControlsTab：动画强度 / 滑杆 / 开关）

    private var tuningTab: some View {
        ScrollView {
            AriaTuningControls(palette: palette)
                .padding(.bottom, 4)
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - 舞台调校控件组

struct AriaTuningControls: View {
    @AppStorage("ariaGeometricBackground") private var ambientMotion = true
    @AppStorage("ariaBackgroundOpacity") private var backgroundOpacity = 0.75
    @AppStorage("ariaLyricDepthIntensity") private var lyricDepthIntensity = 0.68
    @AppStorage("immersivePersistent") private var immersivePersistent = false
    @AppStorage("ariaLyricEmboss") private var lyricEmbossEnabled = true

    let palette: AriaPalette

    var body: some View {
        VStack(spacing: 12) {
            tuningSlider(
                title: String(localized: "背景压暗"),
                value: $backgroundOpacity,
                range: 0.45...0.95,
                display: "\(Int(backgroundOpacity * 100))%"
            )
            tuningSlider(
                title: String(localized: "歌词景深"),
                value: $lyricDepthIntensity,
                range: 0.2...1,
                display: "\(Int(lyricDepthIntensity * 100))%"
            )
            stageToggle(String(localized: "立体浮雕"), isOn: $lyricEmbossEnabled)
            stageToggle(String(localized: "动态色彩呼吸"), isOn: $ambientMotion)
            stageToggle(String(localized: "常驻沉浸模式"), isOn: $immersivePersistent)
        }
    }

    private func tuningSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        display: String
    ) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                Spacer()
                Text(display)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
            }
            Slider(value: value, in: range)
                .tint(Color.white.opacity(0.85))
                .controlSize(.mini)
        }
    }

    private func stageToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
        }
        .tint(palette.accent)
        .padding(.vertical, 4)
        .padding(.trailing, 3)
    }

}
