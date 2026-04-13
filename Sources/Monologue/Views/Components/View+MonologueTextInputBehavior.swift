import SwiftUI

extension View {
    func monologueTextInputBehavior() -> some View {
        self
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
    }
}
