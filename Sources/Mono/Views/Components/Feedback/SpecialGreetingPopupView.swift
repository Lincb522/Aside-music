//  浆糊专属弹窗 —— 独立于全局主题的暖色情书卡片：
//  · 日常卡：大号衬线天数计数 + 悄悄话，背景漂浮小心形；
//  · 生日卡：阳历 12/1 与农历十月十七触发，彩纸屑 + 祝福语。

import SwiftUI

// MARK: - 覆盖层

/// 挂在主界面最上层；`SpecialGreetingManager.pending` 非空时弹出。
struct SpecialGreetingOverlay: View {
    @ObservedObject private var manager = SpecialGreetingManager.shared

    var body: some View {
        ZStack {
            if let greeting = manager.pending {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture { manager.dismiss() }

                SpecialGreetingCard(greeting: greeting) {
                    manager.dismiss()
                }
                .transition(
                    .asymmetric(
                        insertion: .scale(scale: 0.86).combined(with: .opacity),
                        removal: .scale(scale: 0.94).combined(with: .opacity)
                    )
                )
            }
        }
        .animation(
            .spring(response: 0.5, dampingFraction: 0.82),
            value: manager.pending?.animationKey
        )
    }
}

// MARK: - 卡片

private struct SpecialGreetingCard: View {
    let greeting: SpecialGreetingManager.Greeting
    let onDismiss: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var revealed = false

    // 独立暖色系：不跟随全局主题，保证这张卡在任何主题下都是同一封信
    private var rose: Color { Color(red: 0.93, green: 0.42, blue: 0.53) }
    private var roseDeep: Color { Color(red: 0.85, green: 0.30, blue: 0.44) }
    private var ink: Color {
        colorScheme == .dark
            ? Color(red: 0.96, green: 0.92, blue: 0.90)
            : Color(red: 0.26, green: 0.19, blue: 0.18)
    }
    private var inkSoft: Color { ink.opacity(0.62) }

    private var isBirthday: Bool {
        if case .birthday = greeting { return true }
        return false
    }

    private var dayCount: Int {
        switch greeting {
        case .daily(let day, _): return day
        case .birthday(let day, _, _): return day
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            eyebrow
                .padding(.top, 26)

            Group {
                if case .birthday(_, let isLunar, _) = greeting {
                    birthdayHero(isLunar: isLunar)
                } else {
                    dailyHero
                }
            }
            .padding(.top, 18)

            divider
                .padding(.horizontal, 44)
                .padding(.top, 20)

            message
                .padding(.horizontal, 32)
                .padding(.top, 16)

            dismissButton
                .padding(.horizontal, 24)
                .padding(.top, 22)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: 334)
        .background(cardBackdrop)
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.14 : 0.75),
                            rose.opacity(0.22),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: roseDeep.opacity(0.22), radius: 44, x: 0, y: 20)
        .padding(.horizontal, 30)
        .scaleEffect(revealed ? 1 : 0.97)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.75).delay(0.08)) {
                revealed = true
            }
        }
    }

    // MARK: - 眉头（日期行）

    private var eyebrow: some View {
        HStack(spacing: 7) {
            Image(systemName: "heart.fill")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(rose)

            Text(eyebrowText)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(inkSoft)

            Image(systemName: "heart.fill")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(rose)
        }
    }

    private var eyebrowText: String {
        switch greeting {
        case .daily:
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "M月d日 · EEEE"
            return formatter.string(from: Date())
        case .birthday(_, let isLunar, _):
            return isLunar ? "农历十月十七" : "12月1日"
        }
    }

    // MARK: - 日常主体（大号天数）

    private var dailyHero: some View {
        VStack(spacing: 10) {
            Text("今天是喜欢浆糊的")
                .font(.system(size: 15.5, weight: .medium, design: .serif))
                .foregroundStyle(ink.opacity(0.85))

            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text("第")
                    .font(.system(size: 21, weight: .semibold, design: .serif))
                    .foregroundStyle(ink.opacity(0.8))

                Text("\(dayCount)")
                    .font(.system(size: 62, weight: .heavy, design: .serif))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [rose, roseDeep],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: rose.opacity(0.35), radius: 16, x: 0, y: 6)
                    .contentTransition(.numericText())

                Text("天")
                    .font(.system(size: 21, weight: .semibold, design: .serif))
                    .foregroundStyle(ink.opacity(0.8))
            }
        }
    }

    // MARK: - 生日主体

    private func birthdayHero(isLunar: Bool) -> some View {
        VStack(spacing: 14) {
            Text("浆糊，生日快乐")
                .font(.system(size: 34, weight: .heavy, design: .serif))
                .foregroundStyle(
                    LinearGradient(
                        colors: [rose, roseDeep],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: rose.opacity(0.3), radius: 14, x: 0, y: 6)

            HStack(spacing: 6) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(rose.opacity(0.9))
                Text("喜欢浆糊的第 \(dayCount) 天")
                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    .foregroundStyle(ink.opacity(0.75))
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 6.5)
            .background(
                Capsule()
                    .fill(rose.opacity(colorScheme == .dark ? 0.16 : 0.10))
                    .overlay(Capsule().stroke(rose.opacity(0.28), lineWidth: 0.8))
            )
        }
    }

    // MARK: - 分隔 & 正文

    private var divider: some View {
        HStack(spacing: 10) {
            line
            Image(systemName: "sparkle")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(rose.opacity(0.75))
            line
        }
    }

    private var line: some View {
        LinearGradient(
            colors: [ink.opacity(0), ink.opacity(0.22), ink.opacity(0)],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: 1)
    }

    private var message: some View {
        Text(messageText)
            .font(.system(size: 15, weight: .medium, design: .serif))
            .foregroundStyle(ink.opacity(0.9))
            .multilineTextAlignment(.center)
            .lineSpacing(7)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var messageText: String {
        switch greeting {
        case .daily(_, let message), .birthday(_, _, let message):
            return message
        }
    }

    // MARK: - 按钮

    private var dismissButton: some View {
        Button(action: onDismiss) {
            Text(isBirthday ? "开心收下" : "好呀")
                .font(.system(size: 15.5, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [rose, roseDeep],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: roseDeep.opacity(0.4), radius: 14, x: 0, y: 7)
                )
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.96))
    }

    // MARK: - 背景（暖纸 + 光晕 + 漂浮粒子）

    private var cardBackdrop: some View {
        ZStack {
            // 暖色纸面
            LinearGradient(
                colors: colorScheme == .dark
                    ? [
                        Color(red: 0.17, green: 0.12, blue: 0.13),
                        Color(red: 0.13, green: 0.09, blue: 0.11),
                    ]
                    : [
                        Color(red: 1.0, green: 0.97, blue: 0.95),
                        Color(red: 1.0, green: 0.93, blue: 0.92),
                    ],
                startPoint: .top,
                endPoint: .bottom
            )

            // 顶部玫瑰光晕
            Circle()
                .fill(rose.opacity(colorScheme == .dark ? 0.24 : 0.16))
                .frame(width: 210, height: 210)
                .blur(radius: 58)
                .offset(x: -76, y: -128)

            Circle()
                .fill(Color(red: 1.0, green: 0.72, blue: 0.48).opacity(colorScheme == .dark ? 0.12 : 0.14))
                .frame(width: 170, height: 170)
                .blur(radius: 54)
                .offset(x: 104, y: 130)

            // 漂浮层：日常小心形 / 生日彩纸屑
            GreetingParticleField(style: isBirthday ? .confetti : .hearts, tint: rose)
                .allowsHitTesting(false)
        }
    }
}

// MARK: - 漂浮粒子层

/// 卡片内的轻量装饰粒子：日常卡向上漂浮的小心形，生日卡缓落的彩纸屑。
/// 粒子参数由固定种子生成，Canvas 单层绘制，规模很小（16 枚）。
private struct GreetingParticleField: View {
    enum Style {
        case hearts
        case confetti
    }

    let style: Style
    let tint: Color

    private struct Particle {
        let anchorX: CGFloat      // 0~1 相对横向位置
        let phase: Double         // 相位偏移
        let speed: Double         // 漂浮速度
        let size: CGFloat
        let sway: CGFloat         // 横向摆幅
        let opacity: Double
        let colorIndex: Int
    }

    private static let particles: [Particle] = {
        var seed: UInt64 = 0x9E37_79B9_7F4A_7C15
        func next() -> Double {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(seed >> 33) / Double(UInt64(1) << 31)
        }
        return (0..<16).map { index in
            Particle(
                anchorX: CGFloat(0.06 + next() * 0.88),
                phase: next() * 10,
                speed: 0.5 + next() * 0.7,
                size: CGFloat(7 + next() * 7),
                sway: CGFloat(6 + next() * 14),
                opacity: 0.10 + next() * 0.2,
                colorIndex: index % 4
            )
        }
    }()

    private var confettiPalette: [Color] {
        [
            tint,
            Color(red: 0.98, green: 0.72, blue: 0.35),
            Color(red: 0.48, green: 0.72, blue: 0.94),
            Color(red: 0.62, green: 0.55, blue: 0.92),
        ]
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate

                for particle in Self.particles {
                    // 垂直循环：日常心形向上飘，生日彩纸向下落
                    let cycle = 26.0 / particle.speed
                    let progress = (time / cycle + particle.phase).truncatingRemainder(dividingBy: 1)
                    let travel = size.height + 40
                    let y: CGFloat = style == .hearts
                        ? size.height + 20 - CGFloat(progress) * travel
                        : CGFloat(progress) * travel - 20

                    let swayOffset = CGFloat(sin(time * 0.8 * particle.speed + particle.phase * 6)) * particle.sway
                    let x = particle.anchorX * size.width + swayOffset

                    // 出入场淡入淡出
                    let edgeFade = min(progress, 1 - progress) * 6
                    let alpha = particle.opacity * min(1, Double(edgeFade))
                    guard alpha > 0.004 else { continue }

                    switch style {
                    case .hearts:
                        let symbol = context.resolve(
                            Image(systemName: "heart.fill")
                                .symbolRenderingMode(.monochrome)
                        )
                        context.opacity = alpha
                        context.draw(
                            symbol,
                            in: CGRect(x: x, y: y, width: particle.size, height: particle.size)
                        )
                        context.opacity = 1

                    case .confetti:
                        let rect = CGRect(
                            x: -particle.size / 2,
                            y: -particle.size / 3.4,
                            width: particle.size,
                            height: particle.size / 1.7
                        )
                        var piece = context
                        piece.translateBy(x: x, y: y)
                        piece.rotate(by: .radians(time * Double(particle.speed) * 1.6 + particle.phase * 4))
                        piece.opacity = alpha * 2.2
                        piece.fill(
                            Path(roundedRect: rect, cornerRadius: 1.6),
                            with: .color(confettiPalette[particle.colorIndex])
                        )
                    }
                }
            }
            .foregroundStyle(tint)
        }
    }
}
