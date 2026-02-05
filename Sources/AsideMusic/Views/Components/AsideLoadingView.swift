import SwiftUI

struct AsideLoadingView: View {
    var text: String? = nil
    var centered: Bool = true // 默认居中显示
    @State private var isAnimating = false
    
    var body: some View {
        Group {
            if centered {
                VStack {
                    Spacer()
                    loadingContent
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                loadingContent
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
    
    private var loadingContent: some View {
        VStack(spacing: text != nil ? 20 : 0) {
            // Redesigned Loading Animation: Rhythmic Wave
            HStack(spacing: 6) {
                ForEach(0..<4) { index in
                    Capsule()
                        .fill(Color.black)
                        .frame(width: 5, height: 32)
                        .scaleEffect(y: isAnimating ? 1.0 : 0.4)
                        .opacity(isAnimating ? 1.0 : 0.6)
                        .animation(
                            Animation.easeInOut(duration: 0.45)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.12),
                            value: isAnimating
                        )
                }
            }
            .frame(height: 32)
            
            // Text
            if let text = text, !text.isEmpty {
                Text(text)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .tracking(2) // Wide letter spacing
                    .foregroundColor(.black.opacity(0.8))
                    .textCase(.uppercase)
            }
        }
    }
}

#Preview {
    AsideLoadingView()
}
