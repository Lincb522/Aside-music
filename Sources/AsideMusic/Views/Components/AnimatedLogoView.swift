import SwiftUI

/// 动态 Logo 视图 - 基于 AuroraIcon.svg
/// 包含耳机图标和跳动的音波动画
struct AnimatedLogoView: View {
    let size: CGFloat
    
    /// 是否启用动画
    var animated: Bool = true
    
    // 音波条动画状态（0~1 范围）
    @State private var wavePhase: [CGFloat] = [0, 0, 0]
    @State private var dotScale: [CGFloat] = [1, 1]
    
    // 动画是否激活（用于控制动画生命周期）
    @State private var isAnimating = false
    
    // 颜色配置
    private let headphoneColor = Color(hex: "111111")
    private let centerBarColor = Color(hex: "000000")
    private let sideBarColor = Color(hex: "444444")
    private let dotColor = Color(hex: "888888")
    private let glossColor = Color.white.opacity(0.15)
    
    var body: some View {
        ZStack {
            // 耳机主体
            headphonesShape
            
            // 音波动画
            soundwavesView
        }
        .frame(width: size, height: size)
        .onAppear {
            if animated {
                isAnimating = true
                startAnimations()
            }
        }
        .onDisappear {
            isAnimating = false
            stopAnimations()
        }
    }
    
    // MARK: - 耳机形状
    
    private var headphonesShape: some View {
        Canvas { context, canvasSize in
            let scale = canvasSize.width / 1024
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2 + 8 * scale)
            
            // 头带
            let headbandPath = createHeadbandPath(center: center, scale: scale)
            context.fill(headbandPath, with: .color(headphoneColor))
            
            // 左耳罩
            let leftCupPath = createLeftEarCupPath(center: center, scale: scale)
            context.fill(leftCupPath, with: .color(headphoneColor))
            
            // 右耳罩
            let rightCupPath = createRightEarCupPath(center: center, scale: scale)
            context.fill(rightCupPath, with: .color(headphoneColor))
            
            // 高光反射
            let leftGloss = Circle().path(in: CGRect(
                x: center.x - 320 * scale - 40 * scale,
                y: center.y + 140 * scale - 40 * scale,
                width: 80 * scale,
                height: 80 * scale
            ))
            context.fill(leftGloss, with: .color(glossColor))
            
            let rightGloss = Circle().path(in: CGRect(
                x: center.x + 320 * scale - 40 * scale,
                y: center.y + 140 * scale - 40 * scale,
                width: 80 * scale,
                height: 80 * scale
            ))
            context.fill(rightGloss, with: .color(glossColor))
        }
    }
    
    // MARK: - 音波视图（带动画）
    
    private var soundwavesView: some View {
        GeometryReader { geo in
            let scale = geo.size.width / 1024
            let centerX = geo.size.width / 2
            let centerY = geo.size.height / 2 + 60 * scale  // 稍微下移
            
            ZStack {
                // 中间条（最高，动画幅度最大）
                // 基础高度 200，动画增加 180
                RoundedRectangle(cornerRadius: 30 * scale)
                    .fill(centerBarColor)
                    .frame(width: 60 * scale, height: (200 + wavePhase[1] * 180) * scale)
                    .position(x: centerX, y: centerY - wavePhase[1] * 90 * scale)
                
                // 左侧条
                // 基础高度 120，动画增加 120
                RoundedRectangle(cornerRadius: 30 * scale)
                    .fill(sideBarColor)
                    .frame(width: 60 * scale, height: (120 + wavePhase[0] * 120) * scale)
                    .position(x: centerX - 110 * scale, y: centerY - wavePhase[0] * 60 * scale)
                
                // 右侧条
                // 基础高度 120，动画增加 120
                RoundedRectangle(cornerRadius: 30 * scale)
                    .fill(sideBarColor)
                    .frame(width: 60 * scale, height: (120 + wavePhase[2] * 120) * scale)
                    .position(x: centerX + 110 * scale, y: centerY - wavePhase[2] * 60 * scale)
                
                // 左侧圆点
                Circle()
                    .fill(dotColor)
                    .frame(width: 35 * scale * dotScale[0], height: 35 * scale * dotScale[0])
                    .position(x: centerX - 190 * scale, y: centerY)
                
                // 右侧圆点
                Circle()
                    .fill(dotColor)
                    .frame(width: 35 * scale * dotScale[1], height: 35 * scale * dotScale[1])
                    .position(x: centerX + 190 * scale, y: centerY)
            }
        }
    }
    
    // MARK: - 路径创建
    
    private func createHeadbandPath(center: CGPoint, scale: CGFloat) -> Path {
        var path = Path()
        
        path.move(to: CGPoint(x: center.x - 360 * scale, y: center.y - 40 * scale))
        path.addCurve(
            to: CGPoint(x: center.x, y: center.y - 420 * scale),
            control1: CGPoint(x: center.x - 360 * scale, y: center.y - 280 * scale),
            control2: CGPoint(x: center.x - 200 * scale, y: center.y - 420 * scale)
        )
        path.addCurve(
            to: CGPoint(x: center.x + 360 * scale, y: center.y - 40 * scale),
            control1: CGPoint(x: center.x + 200 * scale, y: center.y - 420 * scale),
            control2: CGPoint(x: center.x + 360 * scale, y: center.y - 280 * scale)
        )
        path.addLine(to: CGPoint(x: center.x + 360 * scale, y: center.y + 20 * scale))
        path.addLine(to: CGPoint(x: center.x + 280 * scale, y: center.y + 20 * scale))
        path.addLine(to: CGPoint(x: center.x + 280 * scale, y: center.y - 40 * scale))
        
        path.addCurve(
            to: CGPoint(x: center.x, y: center.y - 340 * scale),
            control1: CGPoint(x: center.x + 280 * scale, y: center.y - 220 * scale),
            control2: CGPoint(x: center.x + 160 * scale, y: center.y - 340 * scale)
        )
        path.addCurve(
            to: CGPoint(x: center.x - 280 * scale, y: center.y - 40 * scale),
            control1: CGPoint(x: center.x - 160 * scale, y: center.y - 340 * scale),
            control2: CGPoint(x: center.x - 280 * scale, y: center.y - 220 * scale)
        )
        path.addLine(to: CGPoint(x: center.x - 280 * scale, y: center.y + 20 * scale))
        path.addLine(to: CGPoint(x: center.x - 360 * scale, y: center.y + 20 * scale))
        path.closeSubpath()
        
        return path
    }
    
    private func createLeftEarCupPath(center: CGPoint, scale: CGFloat) -> Path {
        var path = Path()
        let bigRadius: CGFloat = 40 * scale
        
        let rect = CGRect(
            x: center.x - 420 * scale,
            y: center.y - 20 * scale,
            width: 200 * scale,
            height: 320 * scale
        )
        path.addRoundedRect(in: rect, cornerSize: CGSize(width: bigRadius, height: bigRadius))
        
        return path
    }
    
    private func createRightEarCupPath(center: CGPoint, scale: CGFloat) -> Path {
        var path = Path()
        let bigRadius: CGFloat = 40 * scale
        
        let rect = CGRect(
            x: center.x + 220 * scale,
            y: center.y - 20 * scale,
            width: 200 * scale,
            height: 320 * scale
        )
        path.addRoundedRect(in: rect, cornerSize: CGSize(width: bigRadius, height: bigRadius))
        
        return path
    }
    
    // MARK: - 动画
    
    private func startAnimations() {
        guard isAnimating else { return }
        animateWaves()
        animateDots()
    }
    
    private func animateWaves() {
        guard isAnimating else { return }
        
        // 中间条 - 快速跳动
        withAnimation(.easeInOut(duration: 0.35)) {
            wavePhase[1] = wavePhase[1] < 0.5 ? 1.0 : 0
        }
        
        // 左侧条 - 稍慢，错开节奏
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard self.isAnimating else { return }
            withAnimation(.easeInOut(duration: 0.4)) {
                self.wavePhase[0] = self.wavePhase[0] < 0.5 ? 1.0 : 0
            }
        }
        
        // 右侧条 - 再错开
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            guard self.isAnimating else { return }
            withAnimation(.easeInOut(duration: 0.45)) {
                self.wavePhase[2] = self.wavePhase[2] < 0.5 ? 1.0 : 0
            }
        }
        
        // 循环（更快的节奏）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.animateWaves()
        }
    }
    
    private func animateDots() {
        guard isAnimating else { return }
        
        // 左圆点脉冲
        withAnimation(.easeInOut(duration: 0.5)) {
            dotScale[0] = dotScale[0] < 1.2 ? 1.5 : 1.0
        }
        
        // 右圆点脉冲（错开）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            guard self.isAnimating else { return }
            withAnimation(.easeInOut(duration: 0.5)) {
                self.dotScale[1] = self.dotScale[1] < 1.2 ? 1.5 : 1.0
            }
        }
        
        // 循环
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.animateDots()
        }
    }
    
    private func stopAnimations() {
        withAnimation(.easeOut(duration: 0.2)) {
            wavePhase = [0, 0, 0]
            dotScale = [1, 1]
        }
    }
}

#Preview {
    ZStack {
        Color(white: 0.95)
        AnimatedLogoView(size: 200)
    }
}
