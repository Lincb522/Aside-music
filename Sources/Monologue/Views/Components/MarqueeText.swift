import SwiftUI

/// 跑马灯文字 — 文字超出容器宽度时自动循环滚动，短文字静态居中
/// 优化：使用 TimelineView 替代 repeatForever 动画，避免动画中断和闪烁
struct MarqueeText: View {
    let text: String
    var font: Font = .system(size: 13, weight: .semibold, design: .rounded)
    var color: Color = .secondary
    var speed: Double = 30 // 每秒滚动的点数
    var delayBeforeScroll: Double = 1.5 // 开始滚动前的停顿
    var spacing: CGFloat = 40 // 两段文字之间的间距
    var alignment: Alignment = .leading // 静态模式下的对齐方式

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var animationStart = Date().timeIntervalSinceReferenceDate
    @State private var textId = UUID() // 用于强制重新测量

    /// 是否需要滚动
    private var needsScroll: Bool { textWidth > containerWidth + 2 } // 加 2pt 容差

    var body: some View {
        GeometryReader { geo in
            let cw = geo.size.width
            ZStack {
                if needsScroll {
                    TimelineView(.animation) { context in
                        HStack(spacing: spacing) {
                            textView
                            textView
                        }
                        .offset(x: marqueeOffset(at: context.date.timeIntervalSinceReferenceDate))
                        .frame(width: cw, alignment: .leading)
                    }
                    .onAppear {
                        containerWidth = cw
                        resetAnimationClock()
                    }
                    .onChange(of: text) { _, _ in
                        textId = UUID()
                        resetAndMeasure(containerWidth: cw)
                    }
                } else {
                    // 静态模式：按指定对齐方式显示
                    textView
                        .frame(width: cw, alignment: alignment)
                }
            }
            .clipped()
            .onAppear {
                containerWidth = cw
            }
        }
        .frame(height: textHeight)
        .background(
            // 隐藏测量文字宽度
            textView
                .id(textId)
                .fixedSize()
                .background(
                    GeometryReader { proxy in
                        Color.clear.onAppear {
                            textWidth = proxy.size.width
                        }
                        .onChange(of: text) { _, _ in
                            textWidth = proxy.size.width
                        }
                    }
                )
                .hidden()
        )
    }

    private var textView: some View {
        Text(text)
            .font(font)
            .foregroundColor(color)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    /// 文字高度估算
    private var textHeight: CGFloat { 20 }

    private func marqueeOffset(at time: TimeInterval) -> CGFloat {
        guard needsScroll else { return 0 }

        let scrollDistance = max(textWidth + spacing, 1)
        let scrollDuration = max(scrollDistance / max(speed, 1), 0.1)
        let elapsed = max(time - animationStart, 0)

        guard elapsed > delayBeforeScroll else { return 0 }

        let cycleElapsed = (elapsed - delayBeforeScroll).truncatingRemainder(dividingBy: scrollDuration)
        return -scrollDistance * CGFloat(cycleElapsed / scrollDuration)
    }

    private func resetAnimationClock() {
        animationStart = Date().timeIntervalSinceReferenceDate
    }

    private func resetAndMeasure(containerWidth: CGFloat) {
        self.containerWidth = containerWidth
        resetAnimationClock()
    }
}
