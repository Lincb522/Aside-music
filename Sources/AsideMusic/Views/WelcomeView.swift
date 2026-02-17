import SwiftUI
import Combine

struct WelcomeView: View {
    @Binding var isPresented: Bool
    @AppStorage("isLoggedIn") private var isAppLoggedIn = false
    
    // 初始值设为 true 避免白屏
    @State private var showLogo = true
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0
    @State private var showUserGreeting = false
    @State private var userProfile: UserProfile?
    
    // 缓存的头像 URL（预加载）
    @State private var cachedAvatarImage: UIImage?
    
    var body: some View {
        ZStack {
            AsideBackground()
            
            VStack {
                Spacer()
                
                ZStack {
                    if showLogo && !showUserGreeting {
                        logoView
                            .scaleEffect(logoScale)
                            .opacity(logoOpacity)
                    }
                    
                    if showUserGreeting {
                        greetingView
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.9).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }
                }
                
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
        HStack(alignment: .center, spacing: 20) {
            Image("AppLogo")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 64, height: 64)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Aside Music")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.asideTextPrimary)
                
                Text(LocalizedStringKey("welcome_slogan"))
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(.asideTextSecondary)
                    .tracking(1)
            }
        }
    }
    
    private var greetingView: some View {
        VStack(spacing: 16) {
            // 使用预加载的头像或占位符
            if let cachedImage = cachedAvatarImage {
                Image(uiImage: cachedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 3))
                    .shadow(color: Color.black.opacity(0.1), radius: 10, y: 5)
            } else {
                Circle()
                    .fill(Color.asideCardBackground)
                    .frame(width: 80, height: 80)
                    .overlay(AsideIcon(icon: .profile, size: 30, color: .asideTextSecondary))
                    .shadow(color: Color.black.opacity(0.1), radius: 10, y: 5)
            }
            
            Text(String(format: String(localized: "welcome_back"), userProfile?.nickname ?? String(localized: "welcome_user")))
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(.asideTextPrimary.opacity(0.8))
        }
    }
    
    // MARK: - Animation Sequence
    
    private func startAnimation() {
        // 立即显示 Logo 动画（无延迟）
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }
        
        // 后台加载数据（不阻塞动画）
        Task.detached(priority: .background) {
            await loadDataInBackground()
        }
        
        // 如果已登录，获取用户信息
        if isAppLoggedIn {
            fetchUserProfile()
        } else {
            // 未登录，1.2秒后直接关闭
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                dismissWelcome()
            }
        }
    }
    
    /// 后台加载数据（不影响动画）
    @MainActor
    private func loadDataInBackground() async {
        // 快速预加载
        await OptimizedCacheManager.shared.quickPreload()
        
        // 如果已登录，触发数据刷新
        if isAppLoggedIn {
            let needsRefresh = GlobalRefreshManager.shared.checkDailyRefreshNeeded()
            GlobalRefreshManager.shared.refreshHomePublisher.send(needsRefresh)
            GlobalRefreshManager.shared.refreshLibraryPublisher.send(false)
            GlobalRefreshManager.shared.refreshProfilePublisher.send(false)
        }
    }
    
    /// 获取用户信息
    private func fetchUserProfile() {
        Task { @MainActor in
            do {
                let status = try await APIService.shared.fetchLoginStatus().async()
                if let profile = status.data.profile {
                    self.userProfile = profile
                    
                    let avatarUrl = profile.avatarUrl
                    if let avatarUrl = avatarUrl, !avatarUrl.isEmpty, let url = URL(string: avatarUrl) {
                        self.preloadAvatar(url: url)
                    } else {
                        self.showGreetingAndDismiss()
                    }
                } else {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    self.dismissWelcome()
                }
            } catch {
                try? await Task.sleep(nanoseconds: 500_000_000)
                self.dismissWelcome()
            }
        }
    }
    
    /// 预加载头像图片
    private func preloadAvatar(url: URL) {
        URLSession.shared.dataTask(with: url) { data, _, _ in
            DispatchQueue.main.async {
                if let data = data, let image = UIImage(data: data) {
                    self.cachedAvatarImage = image
                }
                self.showGreetingAndDismiss()
            }
        }.resume()
    }
    
    /// 显示问候语并关闭
    private func showGreetingAndDismiss() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showUserGreeting = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            dismissWelcome()
        }
    }
    
    private func dismissWelcome() {
        withAnimation(.easeOut(duration: 0.4)) {
            isPresented = false
        }
    }
}
