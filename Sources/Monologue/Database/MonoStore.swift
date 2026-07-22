// MonoStore.swift
// 统一持久化门面：内存中维护每个实体的规范对象表，
// save() 时通过快照 diff 找出变更并写入后端（SwiftData 或 Core Data）。

import Foundation

@MainActor
final class MonoStore {
    private let backend: MonoStoreBackend

    /// 每个实体一张表：uniqueKey -> (规范对象, 上次持久化的快照)
    private final class Row {
        let object: AnyObject
        var lastSnapshot: NSDictionary?

        init(object: AnyObject, lastSnapshot: NSDictionary?) {
            self.object = object
            self.lastSnapshot = lastSnapshot
        }
    }

    private var tables: [String: [String: Row]] = [:]
    private var loadedEntities: Set<String> = []
    private var hasPendingDeletes = false

    init(backend: MonoStoreBackend) {
        self.backend = backend
    }

    // MARK: - 加载

    private func ensureLoaded<T: MonoEntity>(_ type: T.Type) {
        let name = T.monoEntityName
        guard !loadedEntities.contains(name) else { return }
        loadedEntities.insert(name)

        var table = tables[name] ?? [:]
        for snapshot in backend.loadAll(entityName: name) {
            let obj = T.monoMake(from: snapshot)
            let key = obj.monoUniqueKey
            // 已在内存中（先插入后加载的场景）时保留内存版本
            if table[key] == nil {
                table[key] = Row(object: obj, lastSnapshot: Self.bridge(snapshot))
            }
        }
        tables[name] = table
    }

    // MARK: - 查询

    func fetchAll<T: MonoEntity>(_ type: T.Type) -> [T] {
        ensureLoaded(type)
        let table = tables[T.monoEntityName] ?? [:]
        return table.values.compactMap { $0.object as? T }
    }

    func fetch<T: MonoEntity>(
        _ type: T.Type,
        where predicate: ((T) -> Bool)? = nil,
        sortBy areInIncreasingOrder: ((T, T) -> Bool)? = nil,
        limit: Int? = nil
    ) -> [T] {
        var results = fetchAll(type)
        if let predicate {
            results = results.filter(predicate)
        }
        if let areInIncreasingOrder {
            results.sort(by: areInIncreasingOrder)
        }
        if let limit, results.count > limit {
            results = Array(results.prefix(limit))
        }
        return results
    }

    func first<T: MonoEntity>(_ type: T.Type, where predicate: (T) -> Bool) -> T? {
        fetchAll(type).first(where: predicate)
    }

    func count<T: MonoEntity>(_ type: T.Type, where predicate: ((T) -> Bool)? = nil) -> Int {
        if let predicate {
            return fetchAll(type).filter(predicate).count
        }
        return fetchAll(type).count
    }

    // MARK: - 写入

    func insert<T: MonoEntity>(_ object: T) {
        ensureLoaded(T.self)
        let name = T.monoEntityName
        var table = tables[name] ?? [:]
        // lastSnapshot 为 nil 表示尚未持久化，save() 时必写
        table[object.monoUniqueKey] = Row(object: object, lastSnapshot: nil)
        tables[name] = table
    }

    func delete<T: MonoEntity>(_ object: T) {
        ensureLoaded(T.self)
        let name = T.monoEntityName
        guard var table = tables[name] else { return }
        let key = object.monoUniqueKey
        if table.removeValue(forKey: key) != nil {
            backend.delete(entityName: name, uniqueKey: key)
            hasPendingDeletes = true
        }
        tables[name] = table
    }

    func deleteAll<T: MonoEntity>(_ type: T.Type, where predicate: ((T) -> Bool)? = nil) {
        ensureLoaded(type)
        let name = T.monoEntityName

        if predicate == nil {
            tables[name] = [:]
            backend.deleteAll(entityName: name)
            hasPendingDeletes = true
            return
        }

        guard var table = tables[name], let predicate else { return }
        for (key, row) in table {
            if let obj = row.object as? T, predicate(obj) {
                table.removeValue(forKey: key)
                backend.delete(entityName: name, uniqueKey: key)
                hasPendingDeletes = true
            }
        }
        tables[name] = table
    }

    // MARK: - 保存

    /// 将所有内存变更（新增 / 属性修改 / 删除）落盘
    func save() {
        var didChange = hasPendingDeletes
        for name in loadedEntities {
            guard var table = tables[name] else { continue }
            for (key, row) in table {
                guard let entity = row.object as? any MonoEntity else { continue }
                let snapshot = entity.monoSnapshot()
                let bridged = Self.bridge(snapshot)
                if row.lastSnapshot == nil || !bridged.isEqual(row.lastSnapshot) {
                    backend.upsert(entityName: name, uniqueKey: key, snapshot: snapshot)
                    row.lastSnapshot = bridged
                    didChange = true
                }
                // uniqueKey 属性本身被修改的场景：重新挂到新 key 下
                let currentKey = entity.monoUniqueKey
                if currentKey != key {
                    table.removeValue(forKey: key)
                    table[currentKey] = row
                    backend.delete(entityName: name, uniqueKey: key)
                }
            }
            tables[name] = table
        }
        if didChange {
            backend.flush()
            hasPendingDeletes = false
        }
    }

    // MARK: - 其他

    func storeSizeBytes() -> Int64 {
        backend.storeSizeBytes()
    }

    /// 快照桥接为 NSDictionary（nil -> NSNull），用于变更对比
    private static func bridge(_ snapshot: [String: Any?]) -> NSDictionary {
        let dict = NSMutableDictionary()
        for (key, value) in snapshot {
            dict[key] = value ?? NSNull()
        }
        return dict
    }
}
