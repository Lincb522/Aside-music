import SwiftUI
import UIKit

/// Global Animation System for AsideMusic
struct AsideAnimation {
    
    // MARK: - Standard Curves
    
    /// Standard bouncy spring for interactive elements
    static let bouncy = Animation.spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0)
    
    /// Softer spring for larger transitions
    static let smooth = Animation.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0)
    
    /// Snappy spring for quick feedback
    static let snappy = Animation.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0)
    
    /// Standard ease-out for enter/exit
    static let easeOut = Animation.easeOut(duration: 0.25)
}

// MARK: - Button Styles

/// A button style that scales down when pressed without haptic feedback
struct AsideBouncingButtonStyle: ButtonStyle {
    
    var scale: CGFloat = 0.95
    var opacity: CGFloat = 0.9
    // var hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle = .medium // Haptics disabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .opacity(configuration.isPressed ? opacity : 1.0)
            .animation(AsideAnimation.bouncy, value: configuration.isPressed)
            // Haptic feedback removed
            /*
            .onChange(of: configuration.isPressed) { pressed in
                if pressed {
                    let generator = UIImpactFeedbackGenerator(style: hapticStyle)
                    generator.impactOccurred()
                }
            }
            */
    }
}

// MARK: - Extensions

extension View {
    /// Applies the standard Aside bouncing button style
    func asideBouncing() -> some View {
        self.buttonStyle(AsideBouncingButtonStyle())
    }
}
