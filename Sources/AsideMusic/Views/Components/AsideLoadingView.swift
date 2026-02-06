import SwiftUI

struct AsideLoadingView: View {
    var text: String? = nil
    var centered: Bool = true // 默认居中显示
    
    var body: some View {
        Group {
            if centered {
                loadingContent
                    .frame(maxWidth: .infinity)
                    .frame(height: 200) // 固定高度，避免布局跳动
            } else {
                loadingContent
            }
        }
    }
    
    private var loadingContent: some View {
        VStack(spacing: text != nil ? 20 : 0) {
            // 节奏波浪加载动画
            HStack(spacing: 6) {
                ForEach(0..<4) { index in
                    LoadingBar(delay: Double(index) * 0.12)
                }
            }
            .frame(height: 32)
            
            // 文字
            if let text = text, !text.isEmpty {
                Text(text)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .tracking(2)
                    .foregroundColor(.black.opacity(0.8))
                    .textCase(.uppercase)
            }
        }
    }
}

// 独立的动画条组件，每个条有自己的动画状态
private struct LoadingBar: View {
    let delay: Double
    @State private var isAnimating = false
    
    var body: some View {
        Capsule()
            .fill(Color.black)
            .frame(width: 5, height: 32)
            .scaleEffect(y: isAnimating ? 1.0 : 0.4)
            .opacity(isAnimating ? 1.0 : 0.6)
            .onAppear {
                // 延迟一帧让布局稳定后再启动动画，避免初始跳动
                DispatchQueue.main.async {
                    withAnimation(
                        .easeInOut(duration: 0.45)
                        .repeatForever(autoreverses: true)
                        .delay(delay)
                    ) {
                        isAnimating = true
                    }
                }
            }
    }
}

#Preview {
    AsideLoadingView()
}
