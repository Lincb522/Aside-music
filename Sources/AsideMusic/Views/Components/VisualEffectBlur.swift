//
//  VisualEffectBlur.swift
//  AsideMusic
//
//  统一的毛玻璃效果组件 - 使用 LiquidGlassEffect 库
//

import UIKit
import SwiftUI
import LiquidGlassEffect

// MARK: - Basic Visual Effect Blur (UIKit)
struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style
    var cornerRadius: CGFloat = 0
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
        view.layer.cornerRadius = cornerRadius
        view.layer.cornerCurve = .continuous
        view.clipsToBounds = true
        return view
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: blurStyle)
        uiView.layer.cornerRadius = cornerRadius
    }
}

// MARK: - Simple Blur Fallback
struct LiquidGlassBlur: View {
    var cornerRadius: CGFloat = 0
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
    }
}

// MARK: - Aside Liquid Glass Card (本地版本，支持 fallback)
struct AsideLiquidCard<Content: View>: View {
    let cornerRadius: CGFloat
    let useMetal: Bool
    let content: Content
    
    init(cornerRadius: CGFloat = 20, useMetal: Bool = true, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.useMetal = useMetal
        self.content = content()
    }
    
    var body: some View {
        content
            .background {
                if useMetal {
                    LiquidGlassMetalView(cornerRadius: cornerRadius)
                } else {
                    LiquidGlassBlur(cornerRadius: cornerRadius)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

// MARK: - View Extensions
extension View {
    func liquidGlassBackground(cornerRadius: CGFloat = 16) -> some View {
        self.background(LiquidGlassBlur(cornerRadius: cornerRadius))
    }
    
    func liquidGlassMetal(cornerRadius: CGFloat = 20) -> some View {
        self.background(LiquidGlassMetalView(cornerRadius: cornerRadius))
    }
    
    func liquidGlassStyle(cornerRadius: CGFloat = 20, useMetal: Bool = true) -> some View {
        AsideLiquidCard(cornerRadius: cornerRadius, useMetal: useMetal) {
            self
        }
    }
}
