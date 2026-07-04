// MonoEntity.swift
// 双持久化（SwiftData iOS 17+ / Core Data iOS 16）的统一实体协议。
// 模型类本身是普通 Swift 类，持久化通过快照（属性字典）与后端交换数据。

import Foundation

/// 实体属性类型（用于 iOS 16 Core Data 后端以编程方式构建模型）
enum MonoAttributeType {
    case int
    case int64
    case double
    case bool
    case string
    case date
    case data
    case uuid
}

struct MonoAttribute {
    let name: String
    let type: MonoAttributeType

    init(_ name: String, _ type: MonoAttributeType) {
        self.name = name
        self.type = type
    }
}

/// 可持久化实体协议。快照 key 与属性名一一对应。
protocol MonoEntity: AnyObject {
    static var monoEntityName: String { get }
    static var monoAttributes: [MonoAttribute] { get }

    /// 实体级唯一标识（作为后端主键）
    var monoUniqueKey: String { get }

    /// 导出当前全部存储属性
    func monoSnapshot() -> [String: Any?]

    /// 从快照重建实例
    static func monoMake(from snapshot: [String: Any?]) -> Self
}

// MARK: - 快照取值辅助

enum MonoSnapshotValue {
    static func int(_ s: [String: Any?], _ key: String, default def: Int = 0) -> Int {
        (s[key] as? Int) ?? (s[key] as? Int64).map(Int.init) ?? def
    }

    static func intOpt(_ s: [String: Any?], _ key: String) -> Int? {
        (s[key] as? Int) ?? (s[key] as? Int64).map(Int.init)
    }

    static func int64(_ s: [String: Any?], _ key: String, default def: Int64 = 0) -> Int64 {
        (s[key] as? Int64) ?? (s[key] as? Int).map(Int64.init) ?? def
    }

    static func double(_ s: [String: Any?], _ key: String, default def: Double = 0) -> Double {
        (s[key] as? Double) ?? def
    }

    static func bool(_ s: [String: Any?], _ key: String, default def: Bool = false) -> Bool {
        (s[key] as? Bool) ?? def
    }

    static func string(_ s: [String: Any?], _ key: String, default def: String = "") -> String {
        (s[key] as? String) ?? def
    }

    static func stringOpt(_ s: [String: Any?], _ key: String) -> String? {
        s[key] as? String
    }

    static func date(_ s: [String: Any?], _ key: String, default def: Date = Date()) -> Date {
        (s[key] as? Date) ?? def
    }

    static func dateOpt(_ s: [String: Any?], _ key: String) -> Date? {
        s[key] as? Date
    }

    static func dataOpt(_ s: [String: Any?], _ key: String) -> Data? {
        s[key] as? Data
    }

    static func uuid(_ s: [String: Any?], _ key: String) -> UUID {
        (s[key] as? UUID) ?? (s[key] as? String).flatMap(UUID.init(uuidString:)) ?? UUID()
    }
}

/// 后端存储协议：以实体名 + 唯一键 + 快照为单位读写
@MainActor
protocol MonoStoreBackend {
    /// 加载某实体的全部记录快照
    func loadAll(entityName: String) -> [[String: Any?]]

    /// 插入或按唯一键更新一条记录
    func upsert(entityName: String, uniqueKey: String, snapshot: [String: Any?])

    /// 按唯一键删除
    func delete(entityName: String, uniqueKey: String)

    /// 删除某实体全部记录
    func deleteAll(entityName: String)

    /// 提交底层上下文
    func flush()

    /// 数据库文件大小（字节）
    func storeSizeBytes() -> Int64
}
