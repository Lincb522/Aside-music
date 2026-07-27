import SwiftUI

/// 自绘弹窗栈中的单个条目；`isVisible` 驱动出现/退场动画。
struct MonoSheetEntry: Identifiable {
    let id: UUID
    var preset: MonoSheetPreset
    var content: AnyView
    var contentVersion: Int
    var requestDismiss: () -> Void
    var onDismiss: (() -> Void)?
    var isVisible: Bool = false
}

enum MonoSheetAnimation {
    static let present = Animation.spring(response: 0.34, dampingFraction: 0.88)
    static let dismiss = Animation.spring(response: 0.3, dampingFraction: 0.9)
}

/// 自绘（非系统 sheet）弹窗的全局栈管理器：负责条目的插入/更新、
/// 出现与退场动画编排，以及动画结束后的延迟移除（320ms）。
@MainActor
final class MonoSheetManager: ObservableObject {
    static let shared = MonoSheetManager()

    @Published private(set) var entries: [MonoSheetEntry] = []
    private var dismissalTasks: [UUID: Task<Void, Never>] = [:]

    private init() {}

    var hasActiveSheet: Bool {
        !entries.isEmpty
    }

    /// 插入或更新弹窗；已存在时仅在 `refreshContent` 为 true 时替换内容并递增版本号触发重建。
    func upsert(
        id: UUID,
        preset: MonoSheetPreset,
        content: AnyView,
        requestDismiss: @escaping () -> Void,
        onDismiss: (() -> Void)? = nil,
        refreshContent: Bool
    ) {
        dismissalTasks[id]?.cancel()
        dismissalTasks[id] = nil

        if let index = entries.firstIndex(where: { $0.id == id }) {
            entries[index].preset = preset
            entries[index].requestDismiss = requestDismiss
            entries[index].onDismiss = onDismiss
            if refreshContent {
                entries[index].content = content
                entries[index].contentVersion += 1
            }
            if !entries[index].isVisible {
                withAnimation(MonoSheetAnimation.present) {
                    entries[index].isVisible = true
                }
            }
            return
        }

        let entry = MonoSheetEntry(
            id: id,
            preset: preset,
            content: content,
            contentVersion: 0,
            requestDismiss: requestDismiss,
            onDismiss: onDismiss,
            isVisible: false
        )

        entries.append(entry)

        Task { @MainActor [weak self] in
            await Task.yield()
            guard let self, let index = self.entries.firstIndex(where: { $0.id == id }) else { return }

            withAnimation(MonoSheetAnimation.present) {
                self.entries[index].isVisible = true
            }
        }
    }

    func requestDismiss(id: UUID) {
        guard let entry = entries.first(where: { $0.id == id }) else { return }
        entry.requestDismiss()
    }

    /// 启动退场动画，并在动画时长后真正移除条目。
    func beginDismiss(id: UUID, invokeOnDismiss: Bool) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }

        dismissalTasks[id]?.cancel()

        guard entries[index].isVisible else {
            finalizeRemoval(id: id, invokeOnDismiss: invokeOnDismiss)
            return
        }

        withAnimation(MonoSheetAnimation.dismiss) {
            entries[index].isVisible = false
        }

        dismissalTasks[id] = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 320_000_000)
            guard let self else { return }
            self.finalizeRemoval(id: id, invokeOnDismiss: invokeOnDismiss)
        }
    }

    func remove(id: UUID, invokeOnDismiss: Bool) {
        dismissalTasks[id]?.cancel()
        dismissalTasks[id] = nil
        finalizeRemoval(id: id, invokeOnDismiss: invokeOnDismiss)
    }

    private func finalizeRemoval(id: UUID, invokeOnDismiss: Bool) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        dismissalTasks[id] = nil
        let entry = entries.remove(at: index)

        if invokeOnDismiss {
            entry.onDismiss?()
        }
    }
}
