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

    private var queue: [Song] {
        player.currentContextList.filter { $0.podcastRadioId == nil }
    }

    private var currentIndex: Int? {
        guard let currentId = player.currentSong?.id else { return nil }
        return queue.firstIndex(where: { $0.id == currentId })
    }

    var body: some View {
        GeometryReader { geo in
            // folia 桌面档位的等比缩放：卡片尺寸随可用高度走
            let coverSize = min(geo.size.height * 0.42, 280)
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

                if queue.isEmpty {
                    Text(String(localized: "队列为空"))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                } else {
                    // 封面长廊
                    wall(coverSize: coverSize, pitch: pitch, geo: geo)
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

                // 顶栏：关闭 + 标题
                VStack {
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
                        // 平衡布局的占位
                        Color.clear.frame(width: 44, height: 44)
                    }
                    .padding(.top, DeviceLayout.headerTopPadding)
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    Spacer()
                }
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
        }
    }

    // MARK: 长廊

    @ViewBuilder
    private func wall(coverSize: CGFloat, pitch: CGFloat, geo: GeometryProxy) -> some View {
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
        // 长廊整体略高于几何中心，给下方 caption 留出呼吸
        .offset(y: -18)
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
