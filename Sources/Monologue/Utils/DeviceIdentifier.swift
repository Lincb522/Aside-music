// DeviceIdentifier.swift
// 设备唯一标识管理 — 用于一机一码绑定
//
// 设计策略（三层兜底）：
//  Layer 1: Keychain 读取之前保存的 UUID（最稳定，跨卸载保留）
//  Layer 2: IDFV (identifierForVendor) + bundleId 派生稳定 UUID
//     - IDFV 在同一 vendor group 的所有 App 卸载后才重置
//     - 对于单个 App 来说，卸载重装 IDFV 不变
//     - 派生方式：SHA256(IDFV + bundleId + 固定盐) 前 16 字节 → UUID 格式
//  Layer 3: 纯随机 UUID（最不稳定，仅兜底）
//
// 生成结果**写回 Keychain**，后续都优先从 Layer 1 读取。

import Foundation
import UIKit
import CryptoKit

enum DeviceIdentifier {
    private static let deviceUUIDKey = "monologue_device_uuid"
    /// 固定盐值：让派生 UUID 不容易被反向预测
    /// 即使别人知道 IDFV 也无法伪造我们的 UUID（除非拿到这个盐）
    private static let derivationSalt = "mlg-device-seed-v1-salt"

    /// 获取或生成设备唯一标识
    static var uuid: String {
        // Layer 1: Keychain 已有 UUID，直接用
        if let saved = KeychainHelper.loadString(key: deviceUUIDKey),
           !saved.isEmpty {
            return saved
        }

        // Layer 2: 用 IDFV 派生稳定 UUID
        if let idfv = UIDevice.current.identifierForVendor?.uuidString,
           !idfv.isEmpty {
            let derived = deriveUUID(from: idfv)
            KeychainHelper.save(key: deviceUUIDKey, value: derived)
            #if DEBUG
            print("[DeviceIdentifier] 从 IDFV 派生 UUID: \(derived)")
            #endif
            return derived
        }

        // Layer 3: 彻底 fallback（极少触发：连 IDFV 都不可用，几乎不可能）
        let randomUUID = UUID().uuidString
        KeychainHelper.save(key: deviceUUIDKey, value: randomUUID)
        #if DEBUG
        print("[DeviceIdentifier] 连 IDFV 都不可用，fallback 随机 UUID: \(randomUUID)")
        #endif
        return randomUUID
    }

    /// 从 IDFV 派生一个稳定的 UUID 格式字符串
    /// 公式：SHA256(idfv + bundleId + salt) 前 16 字节 → UUID v4 格式
    /// 这样同一设备 + 同一 App 每次都能算出同一个 UUID
    private static func deriveUUID(from idfv: String) -> String {
        let bundleId = Bundle.main.bundleIdentifier ?? "com.monologue.music"
        let input = "\(idfv)|\(bundleId)|\(derivationSalt)"
        let hash = SHA256.hash(data: Data(input.utf8))
        let bytes = Array(hash.prefix(16))

        // 手工拼 UUID 字符串：8-4-4-4-12
        var hex = bytes.map { String(format: "%02X", $0) }.joined()
        // 在正确位置插入 '-'
        hex.insert("-", at: hex.index(hex.startIndex, offsetBy: 8))
        hex.insert("-", at: hex.index(hex.startIndex, offsetBy: 13))
        hex.insert("-", at: hex.index(hex.startIndex, offsetBy: 18))
        hex.insert("-", at: hex.index(hex.startIndex, offsetBy: 23))
        return hex
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
