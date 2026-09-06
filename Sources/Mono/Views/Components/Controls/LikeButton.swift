import SwiftUI

/// 红心收藏按钮。收藏成功使用统一关键帧与短时粒子反馈，取消收藏仅更新状态；
/// 动画由真实收藏结果触发，不再维护多段延迟状态机。
struct LikeButton: View {
    let songId: Int
    var isQQMusic: Bool = false
    var song: Song? = nil
    var size: CGFloat = 24
    var activeColor: Color = .red
    var inactiveColor: Color = .black
    
    @StateObject private var likeManager = LikeManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var completionTrigger = 0
    
    private var isLiked: Bool {
        likeManager.isLiked(id: songId, source: song?.musicSource ?? (isQQMusic ? .qqmusic : .netease))
    }
    
    var body: some View {
        Button(action: performLike) {
            ZStack {
                MonoIcon(
                    icon: isLiked ? .liked : .like,
                    size: size,
                    color: isLiked ? activeColor : inactiveColor
                )
                .monoCompletionMotion(
                    trigger: completionTrigger,
                    reduceMotion: reduceMotion
                )

                MonoCompletionBurst(
                    trigger: completionTrigger,
                    tint: activeColor,
                    radius: size * 0.88
                )
            }
            .frame(width: 36, height: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .monoSheet(isPresented: $likeManager.showPlaylistPicker, preset: .standard){
            if let pendingSong = likeManager.pendingLikeSong {
                AddToPlaylistSheet(song: pendingSong)

            }
        }
    }

    private func performLike() {
        HapticManager.shared.medium()
        
        let wasLiked = isLiked
        likeManager.toggleLike(songId: songId, isQQMusic: isQQMusic, song: song)
        if !wasLiked {
            completionTrigger += 1
        }
    }
}
