// musicLiveActivity.swift
// 灵动岛 & 锁屏 Live Activity UI
// 纯展示版本 — 不使用 Button(intent:)，避免 App Group 依赖导致崩溃

import ActivityKit
import WidgetKit
import SwiftUI

struct musicLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MusicActivityAttributes.self) { context in
            // MARK: - 锁屏 / 通知横幅视图
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedLeadingView(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedTrailingView(context: context)
                }
                DynamicIslandExpandedRegion(.center) {
                    ExpandedCenterView(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomView(context: context)
                }
            } compactLeading: {
                CompactLeadingView(context: context)
            } compactTrailing: {
                CompactTrailingView(context: context)
            } minimal: {
                MinimalView(context: context)
            }
            .widgetURL(URL(string: "asidemusic://player"))
            .keylineTint(.white.opacity(0.6))
        }
    }
}

// MARK: - 锁屏视图

private struct LockScreenView: View {
    let context: ActivityViewContext<MusicActivityAttributes>
    
    var body: some View {
        HStack(spacing: 12) {
            // 封面占位
            CoverPlaceholder()
                .frame(width: 50, height: 50)
            
            VStack(alignment: .leading, spacing: 4) {
                // 歌名
                Text(context.attributes.songName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                // 歌手
                Text(context.state.artistName)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }
            
            Spacer()
            
            // 播放状态图标
            Image(systemName: context.state.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 20))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.black.opacity(0.85))
        // 进度条
        .overlay(alignment: .bottom) {
            GeometryReader { geo in
                Rectangle()
                    .fill(.white.opacity(0.3))
                    .frame(width: geo.size.width * context.state.progress, height: 3)
            }
            .frame(height: 3)
        }
    }
}

// MARK: - 紧凑模式（灵动岛未展开）

/// 紧凑左侧 — 封面
private struct CompactLeadingView: View {
    let context: ActivityViewContext<MusicActivityAttributes>
    
    var body: some View {
        CoverPlaceholder()
            .frame(width: 26, height: 26)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

/// 紧凑右侧 — 音波动画 / 暂停图标
private struct CompactTrailingView: View {
    let context: ActivityViewContext<MusicActivityAttributes>
    
    var body: some View {
        if context.state.isPlaying {
            // 简易音波指示
            HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(.white)
                        .frame(width: 2, height: CGFloat([8, 12, 6][i]))
                }
            }
            .frame(width: 14, height: 14)
        } else {
            Image(systemName: "pause.fill")
                .font(.system(size: 12))
                .foregroundStyle(.white)
        }
    }
}

/// 最小模式（多个灵动岛时）
private struct MinimalView: View {
    let context: ActivityViewContext<MusicActivityAttributes>
    
    var body: some View {
        CoverPlaceholder()
            .frame(width: 22, height: 22)
            .clipShape(Circle())
    }
}

// MARK: - 展开模式

/// 展开左侧 — 封面
private struct ExpandedLeadingView: View {
    let context: ActivityViewContext<MusicActivityAttributes>
    
    var body: some View {
        CoverPlaceholder()
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

/// 展开右侧 — 播放控制图标
private struct ExpandedTrailingView: View {
    let context: ActivityViewContext<MusicActivityAttributes>
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: context.state.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
            
            Image(systemName: "forward.fill")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.8))
        }
    }
}

/// 展开中间 — 歌名 + 歌手
private struct ExpandedCenterView: View {
    let context: ActivityViewContext<MusicActivityAttributes>
    
    var body: some View {
        VStack(spacing: 2) {
            Text(context.attributes.songName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            
            Text(context.state.artistName)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
        }
    }
}

/// 展开底部 — 进度条 + 时间
private struct ExpandedBottomView: View {
    let context: ActivityViewContext<MusicActivityAttributes>
    
    var body: some View {
        VStack(spacing: 6) {
            // 进度条
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // 背景轨道
                    Capsule()
                        .fill(.white.opacity(0.2))
                        .frame(height: 4)
                    
                    // 已播放进度
                    Capsule()
                        .fill(.white)
                        .frame(width: max(0, geo.size.width * context.state.progress), height: 4)
                }
            }
            .frame(height: 4)
            
            // 时间标签
            HStack {
                Text(formatTime(context.state.currentTime))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
                
                Spacer()
                
                Text(formatTime(context.state.duration))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(.top, 4)
    }
    
    /// 格式化秒数为 mm:ss
    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return "\(mins):\(String(format: "%02d", secs))"
    }
}

// MARK: - 封面占位图

/// 音符图标占位（Widget 中无法使用 AsyncImage 加载网络图片）
private struct CoverPlaceholder: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [.purple.opacity(0.6), .blue.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Image(systemName: "music.note")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
        }
    }
}

// MARK: - 预览

#if DEBUG
struct musicLiveActivity_Previews: PreviewProvider {
    static let attributes = MusicActivityAttributes(
        songName: "测试歌曲名称",
        artistName: "测试歌手",
        albumName: "测试专辑",
        coverUrlString: nil,
        duration: 240
    )
    
    static let state = MusicActivityAttributes.ContentState(
        isPlaying: true,
        currentTime: 67,
        duration: 240,
        artistName: "测试歌手"
    )
    
    static var previews: some View {
        attributes
            .previewContext(state, viewKind: .dynamicIsland(.compact))
            .previewDisplayName("紧凑模式")
        
        attributes
            .previewContext(state, viewKind: .dynamicIsland(.expanded))
            .previewDisplayName("展开模式")
        
        attributes
            .previewContext(state, viewKind: .dynamicIsland(.minimal))
            .previewDisplayName("最小模式")
        
        attributes
            .previewContext(state, viewKind: .content)
            .previewDisplayName("锁屏视图")
    }
}
#endif
