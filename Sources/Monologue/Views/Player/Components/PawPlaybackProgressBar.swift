import SwiftUI

/// paw 主题专属播放进度条
/// 从 `PawcelainPlayerLayout` 抽出，供全屏播放器、FM 界面等场景复用，
/// 保证 paw 主题里所有播放器入口的进度条视觉/手势保持一致。
///
/// - 直接订阅 `PlaybackTimePublisher.shared`，调用方无需自行接线
/// - 通过 `onSeek` 外置 seek 行为（FM 界面会做 isOwnFMContent 守卫）
/// - `showsTimeLabels` 控制下方两枚时间胶囊；FM 界面布局紧凑可设为 false
struct PawPlaybackProgressBar: View {
    @ObservedObject private var timePublisher = PlaybackTimePublisher.shared

    @Binding var isDragging: Bool
    @Binding var dragValue: Double

    var showsTimeLabels: Bool = true
    var railHeight: CGFloat = 34
    /// 是否使用胶囊容器包裹（paw 全屏播放器是 true；FM 卡片下方传 false 显得轻盈）
    var hasContainer: Bool = true
    var onSeek: (Double) -> Void

    var body: some View {
        if hasContainer {
            VStack(spacing: 10) {
                rail
                if showsTimeLabels {
                    timeLabels
                }
            }
            .padding(12)
            .background(
                PetWhiteSurfaceBackground(
                    cornerRadius: 24,
                    elevated: false,
                    tint: PetWhiteStyle.surfacePressed,
                    accent: PetWhiteStyle.butter
                )
            )
        } else {
            VStack(spacing: 8) {
                rail
                if showsTimeLabels {
                    timeLabels
                }
            }
        }
    }

    // MARK: - Rail

    private var rail: some View {
        GeometryReader { proxy in
            let current = isDragging ? dragValue : timePublisher.currentTime
            let progress = timePublisher.duration > 0
                ? min(max(current / timePublisher.duration, 0), 1)
                : 0
            let fillWidth = proxy.size.width * CGFloat(progress)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(PetWhiteStyle.surfaceRaised)
                    .overlay(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .stroke(PetWhiteStyle.stroke, lineWidth: 1.4)
                    )
                    .shadow(color: PetWhiteStyle.stroke.opacity(0.08), radius: 8, x: 0, y: 4)

                Capsule()
                    .fill(PetWhiteStyle.separator.opacity(0.72))
                    .frame(height: 8)
                    .padding(.horizontal, 13)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: PetWhiteStyle.accentGradient,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(8, fillWidth - 26), height: 8)
                    .padding(.leading, 13)

                HStack(spacing: 0) {
                    ForEach(0..<5, id: \.self) { index in
                        PetWhiteMascotMark(kind: .dog, size: index.isMultiple(of: 2) ? 15 : 12)
                            .frame(width: 18, height: 18)
                            .opacity(progress >= Double(index + 1) / 5.0 ? 0.82 : 0.22)
                            .scaleEffect(progress >= Double(index + 1) / 5.0 ? 1 : 0.92)
                            .rotationEffect(.degrees(index.isMultiple(of: 2) ? -8 : 8))

                        if index < 4 {
                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(.horizontal, 24)

                Circle()
                    .fill(PetWhiteStyle.butter)
                    .frame(width: 25, height: 25)
                    .overlay(
                        PetWhiteMascotMark(kind: .dog, size: 18)
                    )
                    .overlay(Circle().stroke(PetWhiteStyle.stroke, lineWidth: 1.4))
                    .shadow(color: PetWhiteStyle.stroke.opacity(0.14), radius: 6, x: 0, y: 3)
                    .offset(x: min(max(fillWidth - 12.5, 0), max(proxy.size.width - 25, 0)))
                    .animation(.spring(response: 0.28, dampingFraction: 0.78), value: progress)
            }
            .contentShape(Rectangle().inset(by: -10))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        let ratio = min(max(value.location.x / proxy.size.width, 0), 1)
                        dragValue = ratio * timePublisher.duration
                    }
                    .onEnded { value in
                        isDragging = false
                        let ratio = min(max(value.location.x / proxy.size.width, 0), 1)
                        onSeek(ratio * timePublisher.duration)
                    }
            )
        }
        .frame(height: railHeight)
    }

    // MARK: - Time labels

    private var timeLabels: some View {
        HStack {
            PawTimePill(
                text: Self.formatTime(isDragging ? dragValue : timePublisher.currentTime),
                tint: PetWhiteStyle.sky
            )
            Spacer()
            PawTimePill(
                text: Self.formatTime(timePublisher.duration),
                tint: PetWhiteStyle.mint
            )
        }
    }

    static func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite else { return "0:00" }
        let total = max(Int(seconds), 0)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

/// paw 主题时间胶囊（小尺寸版，带 mascot 标记）
struct PawTimePill: View {
    let text: String
    var tint: Color = PetWhiteStyle.sky

    var body: some View {
        HStack(spacing: 5) {
            PetWhiteMascotMark(kind: .dog, size: 12)
            Text(text)
                .font(.system(size: 11, weight: .black, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(PetWhiteStyle.inkSoft)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(tint.opacity(0.62), in: Capsule())
        .overlay(Capsule().stroke(PetWhiteStyle.stroke.opacity(0.8), lineWidth: 1))
    }
}
