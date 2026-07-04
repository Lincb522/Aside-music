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
    let palette: AriaPalette
    let maxHeight: CGFloat

    @ObservedObject private var player = PlayerManager.shared

    private let panelWidth: CGFloat = 320

    private var queue: [Song] {
        player.currentContextList.filter { $0.podcastRadioId == nil }
    }

    private var currentIndex: Int? {
        guard let currentId = player.currentSong?.id else { return nil }
        return queue.firstIndex(where: { $0.id == currentId })
    }

    var body: some View {
        VStack(spacing: 14) {
            coverBlock
            tabSwitcher

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
                    .font(.system(size: 20, weight: .bold, design: .rounded))
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

    // MARK: 歌架 tab（folia QueueTab）

    @ViewBuilder
    private var queueTab: some View {
        if queue.isEmpty {
            Text(String(localized: "队列为空"))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 8) {
                HStack {
                    Text(String(localized: "歌架"))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                    Text("\(queue.count)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))
                    Spacer()
                }
                .padding(.horizontal, 4)

                trackList
            }
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
    @AppStorage("ariaIntensity") private var intensityRaw = AriaIntensity.normal.rawValue
    @AppStorage("ariaShowTranslation") private var showTranslation = true
    @AppStorage("ariaGeometricBackground") private var geometricBackground = true
    @AppStorage("ariaWordRotation") private var wordRotation = true
    @AppStorage("ariaLyricsFontScale") private var fontScale = 1.0
    @AppStorage("ariaWordSpacing") private var wordSpacing = 0.7
    @AppStorage("ariaBreathing") private var breathingMultiplier = 1.0
    @AppStorage("ariaBackgroundOpacity") private var backgroundOpacity = 0.75

    let palette: AriaPalette

    var body: some View {
        VStack(spacing: 16) {
            intensitySection
            slidersSection
            togglesSection
        }
    }

    // MARK: 动画强度

    private var intensitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel(String(localized: "动画强度"))

            HStack(spacing: 4) {
                ForEach(AriaIntensity.allCases, id: \.rawValue) { level in
                    let selected = intensityRaw == level.rawValue
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            intensityRaw = level.rawValue
                        }
                    } label: {
                        Text(level.label)
                            .font(.system(size: 12, weight: selected ? .bold : .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(selected ? 1 : 0.4))
                            .frame(maxWidth: .infinity)
                            .frame(height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(selected ? Color.white.opacity(0.10) : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )

            Text(intensityCaption)
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.38))
                .animation(.easeOut(duration: 0.2), value: intensityRaw)
        }
    }

    private var intensityCaption: String {
        switch AriaIntensity(rawValue: intensityRaw) ?? .normal {
        case .calm: return String(localized: "词居中排列，无散点与旋转")
        case .normal: return String(localized: "轻度散点与旋转")
        case .chaotic: return String(localized: "大幅散落与错落")
        }
    }

    // MARK: 滑杆组

    private var slidersSection: some View {
        VStack(spacing: 12) {
            tuningSlider(
                title: String(localized: "歌词字号"),
                value: $fontScale,
                range: 0.8...1.3,
                display: String(format: "%.2f×", fontScale)
            )
            tuningSlider(
                title: String(localized: "词间距"),
                value: $wordSpacing,
                range: 0...2,
                display: String(format: "%.1f", wordSpacing)
            )
            tuningSlider(
                title: String(localized: "呼吸幅度"),
                value: $breathingMultiplier,
                range: 0...2,
                display: breathingMultiplier <= 0.01
                    ? String(localized: "关")
                    : String(format: "%.1f×", breathingMultiplier)
            )
            tuningSlider(
                title: String(localized: "背景压暗"),
                value: $backgroundOpacity,
                range: 0.45...0.95,
                display: "\(Int(backgroundOpacity * 100))%"
            )
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

    // MARK: 开关组

    private var togglesSection: some View {
        VStack(spacing: 2) {
            stageToggle(String(localized: "显示翻译"), isOn: $showTranslation)
            stageToggle(String(localized: "词随机旋转"), isOn: $wordRotation)
            stageToggle(String(localized: "几何漂浮背景"), isOn: $geometricBackground)
        }
    }

    private func stageToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
        }
        .tint(palette.accent)
        .controlSize(.mini)
        .padding(.vertical, 4)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(0.85))
    }
}
