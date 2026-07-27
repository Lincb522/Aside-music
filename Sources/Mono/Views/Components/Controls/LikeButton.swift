import SwiftUI

/// 红心收藏按钮：带挤压-弹起-粒子环的多阶段点赞动画，
/// 并在需要时弹出"添加到歌单"面板（由 LikeManager 驱动）。
struct LikeButton: View {
    let songId: Int
    var isQQMusic: Bool = false
    var song: Song? = nil
    var size: CGFloat = 24
    var activeColor: Color = .red
    var inactiveColor: Color = .black
    
    @StateObject private var likeManager = LikeManager.shared
    @ObservedObject private var playlistManager = LocalPlaylistManager.shared
    @State private var animationPhase: AnimationPhase = .idle
    
    /// 点赞动画的阶段状态机，按时序依次推进。
    private enum AnimationPhase {
        case idle
        case squishDown
        case squishPeak
        case bounceUp
        case overshoot
        case settle
    }
    
    private var isLiked: Bool {
        likeManager.isLiked(id: songId, isQQMusic: isQQMusic)
    }
    
    var body: some View {
        Button(action: performLike) {
            ZStack {
                MonoIcon(
                    icon: isLiked ? .liked : .like,
                    size: size,
                    color: isLiked ? activeColor : inactiveColor
                )
                .scaleEffect(
                    x: scaleX,
                    y: scaleY
                )
                .rotationEffect(rotation)
                
                if animationPhase == .bounceUp || animationPhase == .overshoot {
                    particleRing
                }
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
    
    private var scaleX: CGFloat {
        switch animationPhase {
        case .idle:       return 1.0
        case .squishDown: return 1.2
        case .squishPeak: return 0.8
        case .bounceUp:   return 1.25
        case .overshoot:  return 0.9
        case .settle:     return 1.0
        }
    }
    
    private var scaleY: CGFloat {
        switch animationPhase {
        case .idle:       return 1.0
        case .squishDown: return 0.8
        case .squishPeak: return 1.2
        case .bounceUp:   return 1.25
        case .overshoot:  return 0.9
        case .settle:     return 1.0
        }
    }
    
    private var rotation: Angle {
        switch animationPhase {
        case .squishDown: return .degrees(-8)
        case .squishPeak: return .degrees(6)
        default:          return .zero
        }
    }
    
    private var particleRing: some View {
        ForEach(0..<6, id: \.self) { i in
            Circle()
                .fill(activeColor.opacity(animationPhase == .overshoot ? 0 : 0.6))
                .frame(width: 3, height: 3)
                .offset(y: animationPhase == .overshoot ? -(size * 0.8) : -(size * 0.4))
                .rotationEffect(.degrees(Double(i) * 60))
        }
    }
    
    /// 切换收藏并播放动画：取消收藏只做轻量回弹，新收藏走完整多阶段序列。
    private func performLike() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        let wasLiked = isLiked
        likeManager.toggleLike(songId: songId, isQQMusic: isQQMusic, song: song)
        
        guard !wasLiked else {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                animationPhase = .squishPeak
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    animationPhase = .idle
                }
            }
            return
        }
        
        withAnimation(.easeIn(duration: 0.08)) {
            animationPhase = .squishDown
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.easeOut(duration: 0.08)) {
                animationPhase = .squishPeak
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) {
                animationPhase = .bounceUp
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                animationPhase = .overshoot
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.44) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                animationPhase = .settle
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            animationPhase = .idle
        }
    }
}
