import SwiftUI

extension View {
    /// 统一的文本输入行为：关闭自动大写与自动纠错（用于搜索词、Key、URL 等字段）。
    func monoTextInputBehavior() -> some View {
        self
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
    }
}
