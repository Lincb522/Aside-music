import SwiftUI

struct MonologueLoadingView: View {
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
                    .font(loadingTextFont)
                    .tracking(2)
                    .foregroundColor(loadingTextColor)
                    .textCase(.uppercase)
            }
        }
    }

    private var loadingTextFont: Font {
        if MangaStyle.isActive { return MangaStyle.comicFont(12, weight: .bold) }
        if MujiStyle.isActive { return MujiStyle.labelFont(12, weight: .semibold) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(12, weight: .semibold) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(12, weight: .semibold) }
        return .system(size: 12, weight: .bold, design: .rounded)
    }

    private var loadingTextColor: Color {
        if MangaStyle.isActive { return MangaStyle.ink.opacity(0.84) }
        if MujiStyle.isActive { return MujiStyle.inkSoft }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        return .monologueTextPrimary.opacity(0.8)
    }
}

// 独立的动画条组件，每个条有自己的动画状态
private struct LoadingBar: View {
    let delay: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
            let phase = reduceMotion ? 0.62 : wavePhase(at: context.date)

            Capsule()
                .fill(barColor)
                .frame(width: 5, height: 32)
                .scaleEffect(y: 0.4 + phase * 0.6)
                .opacity(0.6 + phase * 0.4)
        }
    }

    private var barColor: Color {
        if MangaStyle.isActive { return MangaStyle.ink }
        if MujiStyle.isActive { return MujiStyle.clay }
        if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
        if SequoiaStyle.isActive { return SequoiaStyle.accent }
        return .monologueTextPrimary
    }

    private func wavePhase(at date: Date) -> Double {
        let cycle = 0.9
        let time = date.timeIntervalSinceReferenceDate - delay
        let angle = (time / cycle) * .pi * 2 - .pi / 2
        return (sin(angle) + 1) / 2
    }
}

#Preview {
    MonologueLoadingView()
}
