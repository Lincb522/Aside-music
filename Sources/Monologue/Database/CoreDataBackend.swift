// CoreDataBackend.swift
// iOS 16 持久化后端：编程式 NSManagedObjectModel + 独立 SQLite 文件。
// 每个实体额外带一个 monoKey 字符串主键，读写全部通过 KVC 快照完成。

import Foundation
import CoreData

@MainActor
final class CoreDataBackend: MonoStoreBackend {
    private let container: NSPersistentContainer
    private let context: NSManagedObjectContext

    /// 每个实体一份唯一键索引
    private var indices: [String: [String: NSManagedObject]] = [:]

    private static let uniqueKeyField = "monoKey"

    static var storeURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        return appSupport.appendingPathComponent("MonologueLocal.sqlite")
    }

    /// iOS 16 时期的 Core Data 存储是否存在（用于升级 iOS 17 后的一次性迁移判断）
    static var storeExists: Bool {
        FileManager.default.fileExists(atPath: storeURL.path)
    }

    static func destroyStore() {
        let base = storeURL
        try? FileManager.default.removeItem(at: base)
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: base.path + "-wal"))
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: base.path + "-shm"))
    }

    private let registeredTypes: [String: any MonoEntity.Type]

    init(entityTypes: [any MonoEntity.Type]) {
        var types: [String: any MonoEntity.Type] = [:]
        for type in entityTypes {
            types[type.monoEntityName] = type
        }
        registeredTypes = types

        let model = Self.makeModel(entityTypes: entityTypes)
        container = NSPersistentContainer(name: "MonologueLocal", managedObjectModel: model)

        let description = NSPersistentStoreDescription(url: Self.storeURL)
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }

        if loadError != nil {
            AppLogger.error("Core Data 初始化失败: \(String(describing: loadError))，尝试重建数据库")
            Self.destroyStore()
            var retryError: Error?
            container.loadPersistentStores { _, error in
                retryError = error
            }
            if retryError != nil {
                AppLogger.error("Core Data 重建失败: \(String(describing: retryError))，降级为内存数据库")
                let memDescription = NSPersistentStoreDescription()
                memDescription.type = NSInMemoryStoreType
                container.persistentStoreDescriptions = [memDescription]
                container.loadPersistentStores { _, error in
                    if let error {
                        preconditionFailure("Core Data 完全不可用: \(error)")
                    }
                }
            } else {
                AppLogger.success("Core Data 重建成功")
            }
        } else {
            AppLogger.success("Core Data 初始化成功")
        }

        context = container.viewContext
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
    }

    // MARK: - 模型构建

    private static func makeModel(entityTypes: [any MonoEntity.Type]) -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        var entities: [NSEntityDescription] = []

        for type in entityTypes {
            let entity = NSEntityDescription()
            entity.name = type.monoEntityName
            entity.managedObjectClassName = "NSManagedObject"

            var properties: [NSPropertyDescription] = []

            let keyAttr = NSAttributeDescription()
            keyAttr.name = uniqueKeyField
            keyAttr.attributeType = .stringAttributeType
            keyAttr.isOptional = false
            properties.append(keyAttr)

            for attribute in type.monoAttributes {
                let attr = NSAttributeDescription()
                attr.name = attribute.name
                attr.isOptional = true
                switch attribute.type {
                case .int, .int64:
                    attr.attributeType = .integer64AttributeType
                case .double:
                    attr.attributeType = .doubleAttributeType
                case .bool:
                    attr.attributeType = .booleanAttributeType
                case .string:
                    attr.attributeType = .stringAttributeType
                case .date:
                    attr.attributeType = .dateAttributeType
                case .data:
                    attr.attributeType = .binaryDataAttributeType
                case .uuid:
                    attr.attributeType = .UUIDAttributeType
                }
                properties.append(attr)
            }

            entity.properties = properties
            entity.uniquenessConstraints = [[uniqueKeyField]]
            entities.append(entity)
        }

        model.entities = entities
        return model
    }

    // MARK: - MonoStoreBackend

    func loadAll(entityName: String) -> [[String: Any?]] {
        guard let type = entityType(named: entityName) else { return [] }
        return index(entityName).values.map { snapshot(from: $0, type: type) }
    }

    func upsert(entityName: String, uniqueKey: String, snapshot: [String: Any?]) {
        guard let type = entityType(named: entityName) else { return }
        var idx = index(entityName)
        let object: NSManagedObject
        if let existing = idx[uniqueKey] {
            object = existing
        } else {
            object = NSEntityDescription.insertNewObject(forEntityName: entityName, into: context)
            object.setValue(uniqueKey, forKey: Self.uniqueKeyField)
            idx[uniqueKey] = object
            indices[entityName] = idx
        }
        apply(snapshot: snapshot, to: object, type: type)
    }

    func delete(entityName: String, uniqueKey: String) {
        var idx = index(entityName)
        if let existing = idx.removeValue(forKey: uniqueKey) {
            context.delete(existing)
            indices[entityName] = idx
        }
    }

    func deleteAll(entityName: String) {
        for object in index(entityName).values {
            context.delete(object)
        }
        indices[entityName] = [:]
    }

    func flush() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            AppLogger.error("Core Data 保存失败: \(error)")
        }
    }

    func storeSizeBytes() -> Int64 {
        let attributes = try? FileManager.default.attributesOfItem(atPath: Self.storeURL.path)
        return (attributes?[.size] as? Int64) ?? 0
    }

    // MARK: - 私有

    private func entityType(named name: String) -> (any MonoEntity.Type)? {
        registeredTypes[name]
    }

    private func index(_ entityName: String) -> [String: NSManagedObject] {
        if let cached = indices[entityName] {
            return cached
        }
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        let all = (try? context.fetch(request)) ?? []
        var idx: [String: NSManagedObject] = [:]
        for object in all {
            if let key = object.value(forKey: Self.uniqueKeyField) as? String {
                idx[key] = object
            }
        }
        indices[entityName] = idx
        return idx
    }

    private func snapshot(from object: NSManagedObject, type: any MonoEntity.Type) -> [String: Any?] {
        var result: [String: Any?] = [:]
        for attribute in type.monoAttributes {
            let raw = object.value(forKey: attribute.name)
            switch attribute.type {
            case .int:
                result[attribute.name] = (raw as? NSNumber)?.intValue
            case .int64:
                result[attribute.name] = (raw as? NSNumber)?.int64Value
            case .double:
                result[attribute.name] = (raw as? NSNumber)?.doubleValue
            case .bool:
                result[attribute.name] = (raw as? NSNumber)?.boolValue
            case .string:
                result[attribute.name] = raw as? String
            case .date:
                result[attribute.name] = raw as? Date
            case .data:
                result[attribute.name] = raw as? Data
            case .uuid:
                result[attribute.name] = raw as? UUID
            }
        }
        return result
    }

    private func apply(snapshot: [String: Any?], to object: NSManagedObject, type: any MonoEntity.Type) {
        for attribute in type.monoAttributes {
            let value = snapshot[attribute.name] ?? nil
            object.setValue(value, forKey: attribute.name)
        }
    }
}
