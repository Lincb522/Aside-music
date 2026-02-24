import SwiftUI

/// 播放器右上角三点菜单 — 全屏遮罩 + 右上角弹出菜单
struct PlayerMoreMenu: View {
    @Binding var isPresented: Bool
    var isDarkBackground: Bool = false
    var onEQ: () -> Void
    var onTheme: () -> Void

    private let textColor: Color = .asideTextPrimary

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // 半透明遮罩，点击关闭
            Color.black.opacity(0.01)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.9)) {
                        isPresented = false
                    }
                }

            // 菜单卡片，紧贴右上角
            VStack(spacing: 0) {
                menuItem(icon: .equalizer, title: "均衡器") {
                    isPresented = false
                    onEQ()
                }

                Rectangle()
                    .fill(Color.asideSeparator)
                    .frame(height: 0.5)

                menuItem(icon: .playerTheme, title: "播放器主题") {
                    isPresented = false
                    onTheme()
                }
            }
            .frame(width: 170)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.asideMilk)
                    .glassEffect(.regular, in: .rect(cornerRadius: 14))
                    .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 8)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.top, DeviceLayout.headerTopPadding + 52)
            .padding(.trailing, 20)
        }
    }

    private func menuItem(icon: AsideIcon.IconType, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                AsideIcon(icon: icon, size: 18, color: textColor)
                Text(title)
                    .font(.rounded(size: 15, weight: .medium))
                    .foregroundColor(textColor)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
