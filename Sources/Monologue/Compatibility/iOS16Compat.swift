// iOS16Compat.swift
// iOS 16 兼容层：为 iOS 17+ 的 SwiftUI API 提供向下兼容实现。
// 原则：iOS 17+ 运行时走系统原生实现，行为与迁移前完全一致；
//      iOS 16 运行时提供等价或优雅降级的实现。

import SwiftUI

// MARK: - onChange(of:initial:_:) 双参数/无参数回调（iOS 17 API 的 iOS 16 回退）

/// 基于旧版 onChange(of:perform:) 实现新版语义（携带旧值 + initial 触发）
private struct OnChangeCompatModifier<Value: Equatable>: ViewModifier {
    let value: Value
    let initial: Bool
    let action: (Value, Value) -> Void

    @State private var previousValue: Value?

    func body(content: Content) -> some View {
        content
            .onAppear {
                if previousValue == nil {
                    previousValue = value
                    if initial {
                        action(value, value)
                    }
                }
            }
            .onChange(of: value) { newValue in
                let old = previousValue ?? newValue
                previousValue = newValue
                action(old, newValue)
            }
    }
}

extension View {
    /// iOS 17 `onChange(of:initial:_: (V, V) -> Void)` 的兼容版本。
    /// 部署目标为 iOS 16 时，编译器会优先选择本重载（系统版本要求 iOS 17）；
    /// 将来部署目标升到 17 后本重载自动失效（obsoleted），无缝切回系统实现。
    @available(iOS, introduced: 14.0, obsoleted: 17.0)
    @MainActor public func onChange<V: Equatable>(
        of value: V,
        initial: Bool = false,
        _ action: @escaping (V, V) -> Void
    ) -> some View {
        modifier(OnChangeCompatModifier(value: value, initial: initial, action: action))
    }

    /// iOS 17 `onChange(of:initial:_: () -> Void)` 的兼容版本。
    @available(iOS, introduced: 14.0, obsoleted: 17.0)
    @MainActor public func onChange<V: Equatable>(
        of value: V,
        initial: Bool = false,
        _ action: @escaping () -> Void
    ) -> some View {
        modifier(OnChangeCompatModifier(value: value, initial: initial, action: { _, _ in action() }))
    }
}

// MARK: - scrollTransition 兼容

/// 记录 scrollTransition 闭包中施加的视觉变换（iOS 16 上直接忽略）
struct CompatScrollEffect {
    var scale: CGFloat = 1
    var opacityValue: Double = 1
    var offsetX: CGFloat = 0
    var offsetY: CGFloat = 0
    var rotation: Angle = .zero

    func scaleEffect(_ scale: CGFloat) -> CompatScrollEffect {
        var copy = self; copy.scale = scale; return copy
    }

    func opacity(_ opacity: Double) -> CompatScrollEffect {
        var copy = self; copy.opacityValue = opacity; return copy
    }

    func offset(x: CGFloat = 0, y: CGFloat = 0) -> CompatScrollEffect {
        var copy = self; copy.offsetX = x; copy.offsetY = y; return copy
    }

    func rotationEffect(_ angle: Angle) -> CompatScrollEffect {
        var copy = self; copy.rotation = angle; return copy
    }
}

/// scrollTransition phase 的兼容镜像（isIdentity / value）
struct CompatScrollPhase {
    let isIdentity: Bool
    let value: Double
}

extension View {
    /// iOS 17 `scrollTransition(.animated(...))` 的兼容包装。
    /// iOS 17+ 转发到系统实现；iOS 16 返回原视图（无滚动过渡效果）。
    @ViewBuilder
    func compatScrollTransition(
        animation: Animation,
        _ transform: @escaping (CompatScrollEffect, CompatScrollPhase) -> CompatScrollEffect
    ) -> some View {
        if #available(iOS 17.0, *) {
            self.scrollTransition(.animated(animation)) { content, phase in
                let effect = transform(
                    CompatScrollEffect(),
                    CompatScrollPhase(isIdentity: phase.isIdentity, value: phase.value)
                )
                return content
                    .scaleEffect(effect.scale)
                    .opacity(effect.opacityValue)
                    .offset(x: effect.offsetX, y: effect.offsetY)
                    .rotationEffect(effect.rotation)
            }
        } else {
            self
        }
    }
}

// MARK: - scrollTargetLayout / scrollTargetBehavior / scrollClipDisabled 兼容

extension View {
    /// iOS 17 `scrollTargetLayout()` 兼容包装；iOS 16 无对齐布局（正常滚动）。
    @ViewBuilder
    func compatScrollTargetLayout() -> some View {
        if #available(iOS 17.0, *) {
            self.scrollTargetLayout()
        } else {
            self
        }
    }

    /// iOS 17 `scrollTargetBehavior(.viewAligned)` 兼容包装。
    @ViewBuilder
    func compatViewAlignedScrollBehavior(limitNever: Bool = false) -> some View {
        if #available(iOS 17.0, *) {
            if limitNever {
                self.scrollTargetBehavior(.viewAligned(limitBehavior: .never))
            } else {
                self.scrollTargetBehavior(.viewAligned)
            }
        } else {
            self
        }
    }

    /// iOS 17 `scrollClipDisabled()` 兼容包装。
    @ViewBuilder
    func compatScrollClipDisabled() -> some View {
        if #available(iOS 17.0, *) {
            self.scrollClipDisabled()
        } else {
            self
        }
    }
}

// MARK: - sensoryFeedback 兼容

enum CompatImpactWeight {
    case light, medium, heavy

    var uiKitStyle: UIImpactFeedbackGenerator.FeedbackStyle {
        switch self {
        case .light: return .light
        case .medium: return .medium
        case .heavy: return .heavy
        }
    }
}

extension View {
    /// iOS 17 `sensoryFeedback(.impact(weight:), trigger:)` 兼容包装。
    /// iOS 16 使用 UIImpactFeedbackGenerator 在 trigger 变化时给出等价触感。
    @ViewBuilder
    func compatImpactFeedback<T: Equatable>(weight: CompatImpactWeight, trigger: T) -> some View {
        if #available(iOS 17.0, *) {
            switch weight {
            case .light: self.sensoryFeedback(.impact(weight: .light), trigger: trigger)
            case .medium: self.sensoryFeedback(.impact(weight: .medium), trigger: trigger)
            case .heavy: self.sensoryFeedback(.impact(weight: .heavy), trigger: trigger)
            }
        } else {
            self.onChange(of: trigger) { _ in
                UIImpactFeedbackGenerator(style: weight.uiKitStyle).impactOccurred()
            }
        }
    }
}

// MARK: - symbolEffect 兼容

extension View {
    /// iOS 17 `symbolEffect(.bounce, value:)` 兼容包装；iOS 16 无符号动画。
    @ViewBuilder
    func compatSymbolBounce<T: Equatable>(value: T) -> some View {
        if #available(iOS 17.0, *) {
            self.symbolEffect(.bounce, value: value)
        } else {
            self
        }
    }
}

// MARK: - contentTransition(.numericText(countsDown:)) 兼容

extension View {
    /// iOS 17 `contentTransition(.numericText(countsDown:))` 兼容包装；
    /// iOS 16 回退到不带方向的 numericText。
    @ViewBuilder
    func compatNumericTextTransition(countsDown: Bool) -> some View {
        if #available(iOS 17.0, *) {
            self.contentTransition(.numericText(countsDown: countsDown))
        } else {
            self.contentTransition(.numericText())
        }
    }
}

// MARK: - presentationCornerRadius 兼容（iOS 16.4+）

extension View {
    /// `presentationCornerRadius` 需要 iOS 16.4；16.0–16.3 使用系统默认圆角。
    @ViewBuilder
    nonisolated func compatPresentationCornerRadius(_ radius: CGFloat) -> some View {
        if #available(iOS 16.4, *) {
            self.presentationCornerRadius(radius)
        } else {
            self
        }
    }
}

// MARK: - 闪烁光标兼容（phaseAnimator 替代）

/// iOS 17 `phaseAnimator` 的闪烁场景兼容：iOS 16 用 repeatForever 动画实现同样的闪烁。
struct CompatBlinkModifier: ViewModifier {
    let dimOpacity: Double
    let duration: Double

    @State private var dimmed = false

    func body(content: Content) -> some View {
        content
            .opacity(dimmed ? dimOpacity : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                    dimmed = true
                }
            }
    }
}

extension View {
    @ViewBuilder
    func compatBlink(dimOpacity: Double, duration: Double) -> some View {
        if #available(iOS 17.0, *) {
            self.phaseAnimator([false, true]) { content, phase in
                content.opacity(phase ? dimOpacity : 1.0)
            } animation: { _ in .easeInOut(duration: duration) }
        } else {
            self.modifier(CompatBlinkModifier(dimOpacity: dimOpacity, duration: duration))
        }
    }
}

// MARK: - fontDesign（iOS 16.1）兼容

extension View {
    /// iOS 16.0 无 `fontDesign`，直接跳过（不影响功能，仅字体外观回退系统默认）
    @ViewBuilder
    func compatFontDesign(_ design: Font.Design?) -> some View {
        if #available(iOS 16.1, *) {
            self.fontDesign(design)
        } else {
            self
        }
    }
}

// MARK: - buttonBorderShape(.circle)（iOS 17）兼容

extension View {
    /// iOS 16 无 `.circle`，降级为视觉最接近的 `.capsule`
    @ViewBuilder
    func compatCircleButtonBorderShape() -> some View {
        if #available(iOS 17.0, *) {
            self.buttonBorderShape(.circle)
        } else {
            self.buttonBorderShape(.capsule)
        }
    }
}
