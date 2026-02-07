import SwiftUI

struct PlayingVisualizerView: View {
    let isAnimating: Bool
    let color: Color
    
    @State private var animFlag = false
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<4) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(color)
                    .frame(width: 3, height: 14)
                    .scaleEffect(y: isAnimating ? (animFlag ? randomScale(index: index) : randomScale(index: index + 1)) : 0.3, anchor: .bottom)
                    .animation(
                        isAnimating
                            ? Animation.easeInOut(duration: 0.4)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.1)
                            : .easeOut(duration: 0.2),
                        value: animFlag
                    )
            }
        }
        .frame(width: 20, height: 14)
        .onAppear {
            if isAnimating {
                animFlag = true
            }
        }
        .onChange(of: isAnimating) { animating in
            animFlag = animating
        }
    }
    
    func randomScale(index: Int) -> CGFloat {
        let pattern: [CGFloat] = [0.4, 0.8, 0.5, 0.9, 0.3, 0.7, 0.6, 1.0]
        return pattern[index % pattern.count]
    }
}
