// HapticManager.swift
// 全局触觉反馈管理器

import UIKit

/// 触觉反馈管理器 - 统一管理应用内的触觉反馈
@MainActor
final class HapticManager {
    static let shared = HapticManager()
    
    private let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let softGenerator = UIImpactFeedbackGenerator(style: .soft)
    private let rigidGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let notificationGenerator = UINotificationFeedbackGenerator()
    
    /// 是否启用触觉反馈（从 SettingsManager 读取）
    private var isEnabled: Bool {
        SettingsManager.shared.hapticFeedback
    }
    
    private init() {
        // 预热生成器，减少首次触发延迟
        prepareAll()
    }
    
    /// 预热所有生成器
    func prepareAll() {
        lightGenerator.prepare()
        mediumGenerator.prepare()
        selectionGenerator.prepare()
        notificationGenerator.prepare()
    }
    
    // MARK: - 轻触反馈（按钮点击、Tab 切换）
    
    func light() {
        guard isEnabled else { return }
        lightGenerator.impactOccurred()
        lightGenerator.prepare()
    }
    
    // MARK: - 中等反馈（播放/暂停、重要操作）
    
    func medium() {
        guard isEnabled else { return }
        mediumGenerator.impactOccurred()
        mediumGenerator.prepare()
    }
    
    // MARK: - 重反馈（长按、删除等）
    
    func heavy() {
        guard isEnabled else { return }
        heavyGenerator.impactOccurred()
        heavyGenerator.prepare()
    }
    
    // MARK: - 柔和反馈（滑动选择）
    
    func soft() {
        guard isEnabled else { return }
        softGenerator.impactOccurred()
        softGenerator.prepare()
    }
    
    // MARK: - 刚性反馈（碰撞感）
    
    func rigid() {
        guard isEnabled else { return }
        rigidGenerator.impactOccurred()
        rigidGenerator.prepare()
    }
    
    // MARK: - 选择反馈（列表滚动选中）
    
    func selection() {
        guard isEnabled else { return }
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
    }
    
    // MARK: - 通知反馈
    
    func success() {
        guard isEnabled else { return }
        notificationGenerator.notificationOccurred(.success)
        notificationGenerator.prepare()
    }
    
    func warning() {
        guard isEnabled else { return }
        notificationGenerator.notificationOccurred(.warning)
        notificationGenerator.prepare()
    }
    
    func error() {
        guard isEnabled else { return }
        notificationGenerator.notificationOccurred(.error)
        notificationGenerator.prepare()
    }
}
