import SwiftUI
import Combine

struct WelcomeView: View {
    @Binding var isPresented: Bool
    @AppStorage("isLoggedIn") private var isAppLoggedIn = false
    
    // 初始值设为 true 避免白屏
    @State private var showLogo = true
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0
    
    var body: some View {
        ZStack {
            AsideBackground()
            
            VStack {
                Spacer()
                
                logoView
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                
                Spacer()
            }
            
            VStack {
                Spacer()
                Text("© 2025 ZIJIU STUDIO")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color.gray.opacity(0.4))
                    .padding(.bottom, 40)
                    .opacity(logoOpacity)
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
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white, Color(white: 0.9)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
                )
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            
            VStack(spacing: 6) {
                Text("Aside Music")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.asideTextPrimary)
                
                Text(LocalizedStringKey("welcome_slogan"))
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(.asideTextSecondary)
                    .tracking(1)
            }
        }
    }
    
    // MARK: - Animation Sequence
    
    private func startAnimation() {
        // 立即显示 Logo 动画（无延迟）
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }
        
        // 后台加载数据
        Task {
            await loadDataInBackground()
        }
        
        // 延长展示时间到 2.5 秒，让动画充分展示
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            dismissWelcome()
        }
    }
    
    /// 后台加载数据（不影响动画）
    @MainActor
    private func loadDataInBackground() async {
        // 快速预加载
        await OptimizedCacheManager.shared.quickPreload()
        
        // 如果已登录，触发数据刷新和登录状态检查
        if isAppLoggedIn {
            // 检查登录状态
            do {
                let _ = try await APIService.shared.fetchLoginStatus().async()
            } catch {
                AppLogger.warning("登录状态检查失败: \(error)")
            }
            
            // 触发数据刷新
            let needsRefresh = GlobalRefreshManager.shared.checkDailyRefreshNeeded()
            GlobalRefreshManager.shared.refreshHomePublisher.send(needsRefresh)
            GlobalRefreshManager.shared.refreshLibraryPublisher.send(false)
            GlobalRefreshManager.shared.refreshProfilePublisher.send(false)
        }
    }
    
    private func dismissWelcome() {
        withAnimation(.easeOut(duration: 0.4)) {
            isPresented = false
        }
    }
}
