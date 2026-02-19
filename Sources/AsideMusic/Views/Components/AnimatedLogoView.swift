import SwiftUI

/// 动态 Logo 视图 - 耳机 + 音波形变动画
struct AnimatedLogoView: View {
    let size: CGFloat
    var animated: Bool = true
    
    // 颜色配置
    private let headphoneColor = Color(hex: "111111")
    private let barColors: [Color] = [
        Color(hex: "000000"),
        Color(hex: "333333"),
        Color(hex: "555555")
    ]
    private let dotColor = Color(hex: "777777")
    private let glossColor = Color.white.opacity(0.15)
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 1/60, paused: !animated)) { timeline in
            Canvas { context, canvasSize in
                let time = animated ? timeline.date.timeIntervalSinceReferenceDate : 0
                drawLogo(context: context, size: canvasSize, time: time)
            }
        }
        .frame(width: size, height: size)
    }
    
    // MARK: - 绘制
    
    private func drawLogo(context: GraphicsContext, size: CGSize, time: Double) {
        let scale = size.width / 1024
        let center = CGPoint(x: size.width / 2, y: size.height / 2 + 8 * scale)
        
        // 1. 绘制耳机
        drawHeadphones(context: context, center: center, scale: scale)
        
        // 2. 绘制音波条（形变动画）
        drawSoundBars(context: context, center: center, scale: scale, time: time)
        
        // 3. 绘制圆点（脉冲动画）
        drawDots(context: context, center: center, scale: scale, time: time)
    }
    
    // MARK: - 耳机
    
    private func drawHeadphones(context: GraphicsContext, center: CGPoint, scale: CGFloat) {
        // 头带
        let headbandPath = createHeadbandPath(center: center, scale: scale)
        context.fill(headbandPath, with: .color(headphoneColor))
        
        // 左耳罩
        let leftCup = RoundedRectangle(cornerRadius: 40 * scale)
            .path(in: CGRect(
                x: center.x - 420 * scale,
                y: center.y - 20 * scale,
                width: 200 * scale,
                height: 320 * scale
            ))
        context.fill(leftCup, with: .color(headphoneColor))
        
        // 右耳罩
        let rightCup = RoundedRectangle(cornerRadius: 40 * scale)
            .path(in: CGRect(
                x: center.x + 220 * scale,
                y: center.y - 20 * scale,
                width: 200 * scale,
                height: 320 * scale
            ))
        context.fill(rightCup, with: .color(headphoneColor))
        
        // 高光
        let leftGloss = Circle().path(in: CGRect(
            x: center.x - 360 * scale, y: center.y + 100 * scale,
            width: 80 * scale, height: 80 * scale
        ))
        context.fill(leftGloss, with: .color(glossColor))
        
        let rightGloss = Circle().path(in: CGRect(
            x: center.x + 280 * scale, y: center.y + 100 * scale,
            width: 80 * scale, height: 80 * scale
        ))
        context.fill(rightGloss, with: .color(glossColor))
    }
    
    // MARK: - 音波条（形变动画）
    
    private func drawSoundBars(context: GraphicsContext, center: CGPoint, scale: CGFloat, time: Double) {
        let barWidth: CGFloat = 55 * scale
        let cornerRadius: CGFloat = 28 * scale
        let baseY = center.y + 80 * scale
        let spacing: CGFloat = 100 * scale
        
        // 三根音波条，不同频率和相位
        let barConfigs: [(xOffset: CGFloat, baseHeight: CGFloat, freq: Double, phase: Double, color: Color)] = [
            (-spacing, 100, 3.5, 0.0, barColors[1]),      // 左
            (0, 150, 4.0, 0.3, barColors[0]),             // 中（最高）
            (spacing, 100, 3.2, 0.6, barColors[2])        // 右
        ]
        
        for config in barConfigs {
            // 使用正弦波计算高度变化
            let wave = sin(time * config.freq + config.phase * .pi * 2)
            let heightMultiplier = 0.5 + wave * 0.5  // 0~1 范围
            let height = (config.baseHeight + heightMultiplier * 180) * scale
            
            // 形变：顶部和底部的圆角随高度变化
            let topRadius = cornerRadius * (0.8 + heightMultiplier * 0.4)
            
            let barPath = createMorphingBar(
                x: center.x + config.xOffset,
                baseY: baseY,
                width: barWidth,
                height: height,
                topRadius: topRadius,
                bottomRadius: cornerRadius
            )
            
            context.fill(barPath, with: .color(config.color))
        }
    }
    
    /// 创建形变音波条路径
    private func createMorphingBar(x: CGFloat, baseY: CGFloat, width: CGFloat, height: CGFloat, topRadius: CGFloat, bottomRadius: CGFloat) -> Path {
        var path = Path()
        
        let left = x - width / 2
        let right = x + width / 2
        let top = baseY - height
        let bottom = baseY
        
        // 从左下开始，顺时针绘制
        path.move(to: CGPoint(x: left + bottomRadius, y: bottom))
        
        // 底边
        path.addLine(to: CGPoint(x: right - bottomRadius, y: bottom))
        
        // 右下圆角
        path.addQuadCurve(
            to: CGPoint(x: right, y: bottom - bottomRadius),
            control: CGPoint(x: right, y: bottom)
        )
        
        // 右边
        path.addLine(to: CGPoint(x: right, y: top + topRadius))
        
        // 右上圆角
        path.addQuadCurve(
            to: CGPoint(x: right - topRadius, y: top),
            control: CGPoint(x: right, y: top)
        )
        
        // 顶边
        path.addLine(to: CGPoint(x: left + topRadius, y: top))
        
        // 左上圆角
        path.addQuadCurve(
            to: CGPoint(x: left, y: top + topRadius),
            control: CGPoint(x: left, y: top)
        )
        
        // 左边
        path.addLine(to: CGPoint(x: left, y: bottom - bottomRadius))
        
        // 左下圆角
        path.addQuadCurve(
            to: CGPoint(x: left + bottomRadius, y: bottom),
            control: CGPoint(x: left, y: bottom)
        )
        
        path.closeSubpath()
        return path
    }
    
    // MARK: - 圆点（脉冲动画）
    
    private func drawDots(context: GraphicsContext, center: CGPoint, scale: CGFloat, time: Double) {
        let baseY = center.y + 80 * scale
        let baseSize: CGFloat = 30 * scale
        let xOffset: CGFloat = 180 * scale
        
        // 左圆点
        let leftPulse = 1.0 + sin(time * 5.0) * 0.3
        let leftSize = baseSize * leftPulse
        let leftDot = Circle().path(in: CGRect(
            x: center.x - xOffset - leftSize / 2,
            y: baseY - leftSize / 2,
            width: leftSize,
            height: leftSize
        ))
        context.fill(leftDot, with: .color(dotColor.opacity(0.6 + leftPulse * 0.2)))
        
        // 右圆点（相位偏移）
        let rightPulse = 1.0 + sin(time * 5.0 + .pi) * 0.3
        let rightSize = baseSize * rightPulse
        let rightDot = Circle().path(in: CGRect(
            x: center.x + xOffset - rightSize / 2,
            y: baseY - rightSize / 2,
            width: rightSize,
            height: rightSize
        ))
        context.fill(rightDot, with: .color(dotColor.opacity(0.6 + rightPulse * 0.2)))
    }
    
    // MARK: - 头带路径
    
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
}

#Preview {
    ZStack {
        Color(white: 0.95)
        AnimatedLogoView(size: 200)
    }
}
