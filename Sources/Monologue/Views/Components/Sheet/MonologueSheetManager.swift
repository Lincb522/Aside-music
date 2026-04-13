import SwiftUI

struct MonologueSheetEntry: Identifiable {
    let id: UUID
    var preset: MonologueSheetPreset
    var content: AnyView
    var contentVersion: Int
    var requestDismiss: () -> Void
    var onDismiss: (() -> Void)?
    var isVisible: Bool = false
}

enum MonologueSheetAnimation {
    static let present = Animation.spring(response: 0.34, dampingFraction: 0.88)
    static let dismiss = Animation.spring(response: 0.3, dampingFraction: 0.9)
}

@MainActor
final class MonologueSheetManager: ObservableObject {
    static let shared = MonologueSheetManager()

    @Published private(set) var entries: [MonologueSheetEntry] = []
    private var dismissalTasks: [UUID: Task<Void, Never>] = [:]

    private init() {}

    var hasActiveSheet: Bool {
        !entries.isEmpty
    }

    func upsert(
        id: UUID,
        preset: MonologueSheetPreset,
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
                withAnimation(MonologueSheetAnimation.present) {
                    entries[index].isVisible = true
                }
            }
            return
        }

        let entry = MonologueSheetEntry(
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

            withAnimation(MonologueSheetAnimation.present) {
                self.entries[index].isVisible = true
            }
        }
    }

    func requestDismiss(id: UUID) {
        guard let entry = entries.first(where: { $0.id == id }) else { return }
        entry.requestDismiss()
    }

    func beginDismiss(id: UUID, invokeOnDismiss: Bool) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }

        dismissalTasks[id]?.cancel()

        guard entries[index].isVisible else {
            finalizeRemoval(id: id, invokeOnDismiss: invokeOnDismiss)
            return
        }

        withAnimation(MonologueSheetAnimation.dismiss) {
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
