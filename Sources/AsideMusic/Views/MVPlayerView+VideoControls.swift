// MVPlayerView+VideoControls.swift
// MV 播放器视频控件覆盖层

import SwiftUI
import FFmpegSwiftSDK

// MARK: - 视频控件覆盖层

struct MVVideoControlsOverlay: View {
    let fullscreen: Bool
    let showControls: Bool
    let isPlaying: Bool
    let isSeeking: Bool
    let seekValue: Double
    let mvCurrentTime: TimeInterval
    let mvDuration: TimeInterval
    let mvName: String?
    let mvPlayer: StreamPlayer

    var onTogglePlayback: () -> Void
    var onToggleControlsVisibility: () -> Void
    var onScheduleControlsHide: () -> Void
    var onEnterFullscreen: () -> Void
    var onExitFullscreen: () -> Void
    var onSeekChanged: (Double) -> Void
    var onSeekEnded: (Double) -> Void

    var body: some View {
        ZStack {
            // 点击区域：切换控件显隐
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { onToggleControlsVisibility() }

            if showControls || !isPlaying {
                // 半透明渐变遮罩
                VStack(spacing: 0) {
                    // 顶部渐变
                    LinearGradient(colors: [.black.opacity(0.5), .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: fullscreen ? 80 : 50)
                    Spacer()
                    // 底部渐变
                    LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                        .frame(height: fullscreen ? 100 : 70)
                }
                .allowsHitTesting(false)

                // 中央播放/暂停
                Button(action: { onTogglePlayback(); onScheduleControlsHide() }) {
                    ZStack {
                        Circle()
                            .fill(Color.asideMilk)
                            .glassEffect(.regular, in: .circle)
                            .frame(width: fullscreen ? 64 : 52, height: fullscreen ? 64 : 52)
                        AsideIcon(
                            icon: isPlaying ? .pause : .play,
                            size: fullscreen ? 26 : 22,
                            color: .white
                        )
                        .offset(x: isPlaying ? 0 : 2)
                    }
                }
                .buttonStyle(AsideBouncingButtonStyle(scale: 0.9))

                // 顶部栏
                VStack {
                    HStack {
                        if fullscreen {
                            Button(action: onExitFullscreen) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white.opacity(0.15))
                                        .frame(width: 38, height: 38)
                                    AsideIcon(icon: .shrinkScreen, size: 15, color: .white)
                                }
                            }
                            .buttonStyle(AsideBouncingButtonStyle())

                            if let name = mvName {
                                Text(name)
                                    .font(.rounded(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .padding(.leading, 6)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, fullscreen ? 20 : 12)
                    .padding(.top, fullscreen ? 12 : 8)
                    Spacer()
                }

                // 底部控件栏
                VStack {
                    Spacer()
                    VStack(spacing: fullscreen ? 10 : 6) {
                        // 进度条
                        MVProgressBar(
                            fullscreen: fullscreen,
                            isSeeking: isSeeking,
                            seekValue: seekValue,
                            mvCurrentTime: mvCurrentTime,
                            mvDuration: mvDuration,
                            onSeekChanged: onSeekChanged,
                            onSeekEnded: onSeekEnded,
                            onScheduleControlsHide: onScheduleControlsHide
                        )

                        // 时间 + 全屏按钮
                        HStack(spacing: 8) {
                            Text(MVTimeFormatter.format(isSeeking ? seekValue : mvCurrentTime))
                                .font(.system(size: fullscreen ? 12 : 10, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.9))

                            Text("/")
                                .font(.system(size: fullscreen ? 11 : 9, design: .monospaced))
                                .foregroundColor(.white.opacity(0.4))

                            Text(MVTimeFormatter.format(mvDuration))
                                .font(.system(size: fullscreen ? 12 : 10, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.5))

                            Spacer()

                            Button(action: { fullscreen ? onExitFullscreen() : onEnterFullscreen() }) {
                                AsideIcon(
                                    icon: fullscreen ? .shrinkScreen : .expandScreen,
                                    size: fullscreen ? 16 : 14,
                                    color: .white.opacity(0.9)
                                )
                                .frame(width: 32, height: 32)
                            }
                            .buttonStyle(AsideBouncingButtonStyle())
                        }
                    }
                    .padding(.horizontal, fullscreen ? 20 : 12)
                    .padding(.bottom, fullscreen ? 16 : 8)
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showControls)
    }
}

// MARK: - 进度条

struct MVProgressBar: View {
    let fullscreen: Bool
    let isSeeking: Bool
    let seekValue: Double
    let mvCurrentTime: TimeInterval
    let mvDuration: TimeInterval
    var onSeekChanged: (Double) -> Void
    var onSeekEnded: (Double) -> Void
    var onScheduleControlsHide: () -> Void

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let barHeight: CGFloat = fullscreen ? 4 : 3
            let progress = mvDuration > 0 ? (isSeeking ? seekValue : mvCurrentTime) / mvDuration : 0
            let thumbSize: CGFloat = isSeeking ? (fullscreen ? 16 : 14) : (fullscreen ? 10 : 8)

            ZStack(alignment: .leading) {
                // 轨道背景
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: barHeight)

                // 已播放进度
                Capsule()
                    .fill(Color.asideAccent)
                    .frame(width: max(0, width * CGFloat(progress)), height: barHeight)

                // 拖拽拇指
                Circle()
                    .fill(Color.white)
                    .frame(width: thumbSize, height: thumbSize)
                    .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                    .offset(x: max(0, min(width * CGFloat(progress) - thumbSize / 2, width - thumbSize)))
            }
            .frame(height: max(barHeight, thumbSize))
            .contentShape(Rectangle().inset(by: -12))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let ratio = max(0, min(value.location.x / width, 1))
                        onSeekChanged(Double(ratio) * mvDuration)
                        onScheduleControlsHide()
                    }
                    .onEnded { value in
                        let ratio = max(0, min(value.location.x / width, 1))
                        onSeekEnded(Double(ratio) * mvDuration)
                        onScheduleControlsHide()
                    }
            )
        }
        .frame(height: fullscreen ? 16 : 14)
    }
}

// MARK: - 时间格式化工具

enum MVTimeFormatter {
    static func format(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite && !seconds.isNaN else { return "0:00" }
        let total = Int(max(0, seconds))
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}
