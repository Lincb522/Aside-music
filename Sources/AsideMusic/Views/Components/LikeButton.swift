import SwiftUI

struct LikeButton: View {
    let songId: Int
    var size: CGFloat = 24
    var activeColor: Color = .red
    var inactiveColor: Color = .black // Default, can be overridden
    
    @StateObject private var likeManager = LikeManager.shared
    @State private var isAnimating = false
    
    var body: some View {
        Button(action: {
            // Haptic Feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
            // Animation
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                isAnimating = true
            }
            
            // Action
            likeManager.toggleLike(songId: songId)
            
            // Reset Animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isAnimating = false
            }
        }) {
            ZStack {
                if likeManager.isLiked(id: songId) {
                    AsideIcon(icon: .liked, size: size, color: activeColor)
                        .scaleEffect(isAnimating ? 1.3 : 1.0)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    AsideIcon(icon: .like, size: size, color: inactiveColor)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: likeManager.isLiked(id: songId))
    }
}
