// DeviceIdentifier.swift
// 设备唯一标识管理 — 用于一机一码绑定

import Foundation
import UIKit

/// 设备标识管理器
/// 生成并持久化设备唯一标识，用于 token 绑定验证
enum DeviceIdentifier {
    private static let deviceUUIDKey = "monologue_device_uuid"

    /// 获取或生成设备唯一标识
    /// 优先使用 Keychain 中存储的 UUID，不存在则生成新的并持久化
    static var uuid: String {
        // 1. 尝试从 Keychain 读取
        if let saved = KeychainHelper.loadString(key: deviceUUIDKey),
           !saved.isEmpty {
            return saved
        }

        // 2. 尝试使用系统 identifierForVendor（卸载重装会变化）
        // 作为种子，但不直接使用，避免隐私问题
        let vendorId = UIDevice.current.identifierForVendor?.uuidString ?? ""

        // 3. 生成新的 UUID 并持久化到 Keychain
        let newUUID = UUID().uuidString
        KeychainHelper.save(key: deviceUUIDKey, value: newUUID)

        #if DEBUG
        print("[DeviceIdentifier] 生成新设备 UUID: \(newUUID)")
        if !vendorId.isEmpty {
            print("[DeviceIdentifier] 系统 Vendor ID: \(vendorId)")
        }
        #endif

        return newUUID
    }

    /// 设备信息摘要（用于上报到服务端）
    static var deviceInfo: [String: Any] {
        var info: [String: Any] = [
            "device_uuid": uuid,
            "device_model": deviceModel,
            "device_name": UIDevice.current.name,
            "system_name": UIDevice.current.systemName,
            "system_version": UIDevice.current.systemVersion,
            "app_version": appVersion,
            "bundle_id": Bundle.main.bundleIdentifier ?? "unknown"
        ]

        // 添加 Vendor ID（可选，用于服务端反欺诈检测）
        if let vendorId = UIDevice.current.identifierForVendor?.uuidString {
            info["vendor_id"] = vendorId
        }

        return info
    }

    /// 重置设备标识（仅用于测试或用户主动解绑）
    static func reset() {
        KeychainHelper.delete(key: deviceUUIDKey)
        #if DEBUG
        print("[DeviceIdentifier] 设备 UUID 已重置")
        #endif
    }

    // MARK: - 私有辅助方法

    private static var deviceModel: String {
        let id = deviceModelIdentifier
        if let sim = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return modelMap[sim] ?? sim
        }
        return modelMap[id] ?? id
    }

    private static var deviceModelIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? "Unknown"
            }
        }
    }

    private static var appVersion: String {
        let ver = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(ver) (\(build))"
    }

    private static let modelMap: [String: String] = [
        // iPhone
        "iPhone8,1": "iPhone 6s", "iPhone8,2": "iPhone 6s Plus",
        "iPhone8,4": "iPhone SE (1st)",
        "iPhone9,1": "iPhone 7", "iPhone9,3": "iPhone 7",
        "iPhone9,2": "iPhone 7 Plus", "iPhone9,4": "iPhone 7 Plus",
        "iPhone10,1": "iPhone 8", "iPhone10,4": "iPhone 8",
        "iPhone10,2": "iPhone 8 Plus", "iPhone10,5": "iPhone 8 Plus",
        "iPhone10,3": "iPhone X", "iPhone10,6": "iPhone X",
        "iPhone11,2": "iPhone XS",
        "iPhone11,4": "iPhone XS Max", "iPhone11,6": "iPhone XS Max",
        "iPhone11,8": "iPhone XR",
        "iPhone12,1": "iPhone 11",
        "iPhone12,3": "iPhone 11 Pro",
        "iPhone12,5": "iPhone 11 Pro Max",
        "iPhone12,8": "iPhone SE (2nd)",
        "iPhone13,1": "iPhone 12 mini",
        "iPhone13,2": "iPhone 12",
        "iPhone13,3": "iPhone 12 Pro",
        "iPhone13,4": "iPhone 12 Pro Max",
        "iPhone14,2": "iPhone 13 Pro",
        "iPhone14,3": "iPhone 13 Pro Max",
        "iPhone14,4": "iPhone 13 mini",
        "iPhone14,5": "iPhone 13",
        "iPhone14,6": "iPhone SE (3rd)",
        "iPhone14,7": "iPhone 14",
        "iPhone14,8": "iPhone 14 Plus",
        "iPhone15,2": "iPhone 14 Pro",
        "iPhone15,3": "iPhone 14 Pro Max",
        "iPhone15,4": "iPhone 15",
        "iPhone15,5": "iPhone 15 Plus",
        "iPhone16,1": "iPhone 15 Pro",
        "iPhone16,2": "iPhone 15 Pro Max",
        "iPhone17,1": "iPhone 16 Pro",
        "iPhone17,2": "iPhone 16 Pro Max",
        "iPhone17,3": "iPhone 16",
        "iPhone17,4": "iPhone 16 Plus",

        // iPad
        "iPad11,1": "iPad mini (5th)", "iPad11,2": "iPad mini (5th)",
        "iPad11,3": "iPad Air (3rd)", "iPad11,4": "iPad Air (3rd)",
        "iPad13,1": "iPad Air (4th)", "iPad13,2": "iPad Air (4th)",
        "iPad14,1": "iPad mini (6th)", "iPad14,2": "iPad mini (6th)",
        "iPad16,3": "iPad Pro 11-inch (M4)", "iPad16,4": "iPad Pro 11-inch (M4)",
        "iPad16,5": "iPad Pro 13-inch (M4)", "iPad16,6": "iPad Pro 13-inch (M4)",
    ]
}
