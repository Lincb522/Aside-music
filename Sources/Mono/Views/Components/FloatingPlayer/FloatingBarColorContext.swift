import SwiftUI

private struct FloatingBarColorRevisionKey: EnvironmentKey {
    static let defaultValue = 0
}

extension EnvironmentValues {
    /// Scope palette invalidation to dock consumers without remounting the dock
    /// or refreshing the navigation stacks when artwork colors arrive.
    var floatingBarColorRevision: Int {
        get { self[FloatingBarColorRevisionKey.self] }
        set { self[FloatingBarColorRevisionKey.self] = newValue }
    }
}
