import SwiftUI
import UIKit

struct AsideAnimation {
    
    // MARK: - Standard Curves
    
    static let bouncy = Animation.spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0)
    static let smooth = Animation.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0)
    static let snappy = Animation.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0)
    static let easeOut = Animation.easeOut(duration: 0.25)
}

// MARK: - Button Styles

/// A button style that scales down when pressed
struct AsideBouncingButtonStyle: ButtonStyle {
    
    var scale: CGFloat = 0.95
    var opacity: CGFloat = 0.9
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .opacity(configuration.isPressed ? opacity : 1.0)
            .animation(AsideAnimation.bouncy, value: configuration.isPressed)
    }
}

// MARK: - Extensions

extension View {
    func asideBouncing() -> some View {
        self.buttonStyle(AsideBouncingButtonStyle())
    }
}
