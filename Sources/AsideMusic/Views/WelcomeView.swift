import SwiftUI
import Combine

/// 欢迎启动画面
/// 只负责显示 Logo 动画，数据加载在后台进行
struct WelcomeView: View {
    @Binding var isPresented: Bool
    @AppStorage("isLoggedIn") private var isAppLoggedIn = false
    
    // Animation States - 初始值设为 true 避免白屏
    @State private var showLogo = true
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0
    @State private var showUserGreeting = false
    @State private var userProfile: UserProfile?
    @State private var cancellables = Set<AnyCancellable>()
    
    // 缓存的头像 URL（预加载）
    @State private var cachedAvatarImage: UIImage?
    
    var body: some View {
        ZStack {
            // Background - 立即显示
            AsideBackground()
            
            // Centered Content
            VStack {
                Spacer()
                
                ZStack {
                    // Logo
                    if showLogo && !showUserGreeting {
                        logoView
                            .scaleEffect(logoScale)
                            .opacity(logoOpacity)
                    }
                    
                    // Greeting (已登录用户)
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
            
            // Footer
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
            // Icon - 从 Asset Catalog 加载 AppLogo
            Image("AppLogo")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 64, height: 64)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
            
            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text("Aside Music")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                
                Text("乐章之外，心之独白")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(.gray)
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
                    .fill(Color.white)
                    .frame(width: 80, height: 80)
                    .overlay(AsideIcon(icon: .profile, size: 30, color: .gray))
                    .shadow(color: Color.black.opacity(0.1), radius: 10, y: 5)
            }
            
            Text("欢迎回来, \(userProfile?.nickname ?? "用户")")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(.black.opacity(0.8))
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
        APIService.shared.fetchLoginStatus()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure = completion {
                    // 获取失败，直接关闭
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.dismissWelcome()
                    }
                }
            }, receiveValue: { status in
                if let profile = status.data.profile {
                    self.userProfile = profile
                    
                    // 预加载头像
                    let avatarUrl = profile.avatarUrl
                    if !avatarUrl.isEmpty, let url = URL(string: avatarUrl) {
                        self.preloadAvatar(url: url)
                    } else {
                        self.showGreetingAndDismiss()
                    }
                } else {
                    // 没有 profile，直接关闭
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.dismissWelcome()
                    }
                }
            })
            .store(in: &cancellables)
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
        // 显示问候语
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showUserGreeting = true
        }
        
        // 0.8秒后关闭
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
