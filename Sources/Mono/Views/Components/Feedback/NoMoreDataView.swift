import SwiftUI

/// 全局"没有更多了"提示组件
struct NoMoreDataView: View {
    var text: String = String(localized: "没有更多了")

    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(Color.monoSeparator)
                .frame(height: 0.5)
            Text(text)
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.monoTextSecondary)
                .layoutPriority(1)
            Rectangle()
                .fill(Color.monoSeparator)
                .frame(height: 0.5)
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 20)
    }
}
