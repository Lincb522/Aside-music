import SwiftUI

struct LyricFocusThemePreview: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var offset: CGFloat = 10
    @State private var activeIndex: Int = 1

    var body: some View {
        ZStack {
            if colorScheme == .dark {
                Color(hex: "1A1A1E")
            } else {
                Color(hex: "F0F0F2")
            }

            VStack(alignment: .leading, spacing: 6) {
                // 模拟歌词行
                Capsule()
                    .fill(Color.monologueTextSecondary.opacity(activeIndex == 0 ? 0.8 : 0.12))
                    .frame(width: 55, height: activeIndex == 0 ? 5 : 3)
                Capsule()
                    .fill(Color.monologueTextPrimary.opacity(activeIndex == 1 ? 0.8 : 0.12))
                    .frame(width: 85, height: activeIndex == 1 ? 5 : 3)
                Capsule()
                    .fill(Color.monologueTextSecondary.opacity(activeIndex == 2 ? 0.8 : 0.12))
                    .frame(width: 45, height: activeIndex == 2 ? 5 : 3)
                Capsule()
                    .fill(Color.monologueTextSecondary.opacity(activeIndex == 3 ? 0.8 : 0.06))
                    .frame(width: 65, height: activeIndex == 3 ? 5 : 3)

                Spacer().frame(height: 8)

                // 进度线
                Rectangle()
                    .fill(Color.monologueTextPrimary.opacity(0.35))
                    .frame(width: 65, height: 1.5)
            }
            .offset(y: offset)
            .padding(.leading, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever()) {
                offset = -10
                activeIndex = 2
            }
        }
    }
}
