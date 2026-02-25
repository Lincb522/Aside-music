import SwiftUI

/// 播放器共享进度条区域
struct PlayerProgressSection: View {
    @ObservedObject var player = PlayerManager.shared
    
    @Binding var isDragging: Bool
    @Binding var dragValue: Double
    
    var contentColor: Color = .asideTextPrimary
    var secondaryColor: Color = .asideTextSecondary
    /// 是否使用波形进度条（false 则用简单滑条）
    var useWaveform: Bool = true
    
    var body: some View {
        VStack(spacing: 6) {
            if useWaveform {
                FullScreenPlayerView.WaveformProgressBar(
                    currentTime: Binding(
                        get: { isDragging ? dragValue : player.currentTime },
                        set: { _ in }
                    ),
                    duration: player.duration,
                    color: contentColor,
                    isAnimating: player.isPlaying,
                    chorusStart: player.chorusStartTime,
                    chorusEnd: player.chorusEndTime,
                    onSeek: { time in
                        isDragging = true
                        dragValue = time
                    },
                    onCommit: { time in
                        isDragging = false
                        player.seek(to: time)
                    }
                )
                .frame(height: 20)
            } else {
                // 简约滑条
                GeometryReader { geo in
                    let progress = player.duration > 0
                        ? (isDragging ? dragValue : player.currentTime) / player.duration
                        : 0
                    
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(contentColor.opacity(0.15))
                            .frame(height: 3)
                        
                        Capsule()
                            .fill(contentColor)
                            .frame(width: geo.size.width * CGFloat(min(max(progress, 0), 1)), height: 3)
                    }
                    .contentShape(Rectangle())
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
            }
            
            HStack {
                Text(formatTime(isDragging ? dragValue : player.currentTime))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(secondaryColor.opacity(0.08)))
                    .glassEffect(.regular, in: .capsule)
                Spacer()
                Text(formatTime(player.duration))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(secondaryColor.opacity(0.08)))
                    .glassEffect(.regular, in: .capsule)
            }
            .font(.rounded(size: 11, weight: .medium))
            .foregroundColor(secondaryColor)
            .monospacedDigit()
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite else { return "0:00" }
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
