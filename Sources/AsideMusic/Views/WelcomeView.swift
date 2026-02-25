import SwiftUI
import Combine

struct WelcomeView: View {
    @Binding var isPresented: Bool
    @AppStorage("isLoggedIn") private var isAppLoggedIn = false
    
    // 动画状态
    @State private var logoScale: CGFloat = 0.3
    @State private var logoOpacity: Double = 0
    @State private var logoRotation: Double = -15
    @State private var textOffset: CGFloat = 30
    @State private var textOpacity: Double = 0
    @State private var copyrightOpacity: Double = 0
    @State private var glowOpacity: Double = 0
    
    var body: some View {
        ZStack {
            AsideBackground()
            
            // 背景光晕效果 — 跟随主题的柔和光晕
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.asideTextPrimary.opacity(0.06),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .opacity(glowOpacity)
                .blur(radius: 60)
            
            VStack {
                Spacer()
                
                logoView
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                    .rotation3DEffect(.degrees(logoRotation), axis: (x: 0, y: 1, z: 0))
                
                Spacer()
            }
            
            VStack {
                Spacer()
                Text("© 2026 ZIJIU STUDIO")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color.gray.opacity(0.5))
                    .padding(.bottom, 40)
                    .opacity(copyrightOpacity)
            }
        }
        .onAppear {
            startAnimation()
        }
    }
    
    // MARK: - Subviews
    
    private var logoView: some View {
        VStack(spacing: 24) {
            // 动态 Logo
            AnimatedLogoView(size: 120, animated: true)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white, Color(white: 0.92)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        // 内发光
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.8),
                                        Color.white.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .shadow(color: .black.opacity(0.15), radius: 25, x: 0, y: 12)
                )
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            
            VStack(spacing: 8) {
                Text("Aside Music")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.asideTextPrimary)
                    .offset(y: textOffset)
                    .opacity(textOpacity)
                
                Text(LocalizedStringKey("welcome_slogan"))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.asideTextSecondary)
                    .tracking(1.5)
                    .offset(y: textOffset)
                    .opacity(textOpacity)
            }
        }
    }
    
    // MARK: - Animation Sequence
    
    private func startAnimation() {
        // 阶段 1: Logo 弹入 + 旋转
        withAnimation(AsideAnimation.bouncy) {
            logoScale = 1.0
            logoOpacity = 1.0
            logoRotation = 0
        }
        
        // 阶段 2: 背景光晕
        withAnimation(AsideAnimation.contentAppear) {
            glowOpacity = 1.0
        }
        
        // 阶段 3: 文字滑入
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(AsideAnimation.smooth) {
                textOffset = 0
                textOpacity = 1.0
            }
        }
        
        // 阶段 4: 版权信息淡入
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(AsideAnimation.contentAppear) {
                copyrightOpacity = 1.0
            }
        }
        
        // 后台加载数据
        Task {
            await loadDataInBackground()
        }
        
        // 展示 3.5 秒后消失
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            dismissWelcome()
        }
    }
    
    /// 后台加载数据（不影响动画）
    @MainActor
    private func loadDataInBackground() async {
        await OptimizedCacheManager.shared.quickPreload()
        
        if isAppLoggedIn {
            do {
                let _ = try await APIService.shared.fetchLoginStatus().async()
            } catch {
                AppLogger.warning("登录状态检查失败: \(error)")
            }
            
            let needsRefresh = GlobalRefreshManager.shared.checkDailyRefreshNeeded()
            GlobalRefreshManager.shared.refreshHomePublisher.send(needsRefresh)
            GlobalRefreshManager.shared.refreshLibraryPublisher.send(false)
            GlobalRefreshManager.shared.refreshProfilePublisher.send(false)
        }
    }
    
    private func dismissWelcome() {
        // 淡出动画
        withAnimation(AsideAnimation.contentAppear) {
            logoOpacity = 0
            logoScale = 1.1
            textOpacity = 0
            copyrightOpacity = 0
            glowOpacity = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isPresented = false
        }
    }
}
