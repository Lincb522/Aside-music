import SwiftUI

/// 播放器共享顶栏
struct PlayerHeaderBar: View {
    @ObservedObject var player = PlayerManager.shared
    
    var contentColor: Color = .monoTextPrimary
    var secondaryColor: Color = .monoTextSecondary
    var isDarkBackground: Bool = false
    var onShowEQ: () -> Void = {}
    var onShowThemePicker: () -> Void = {}
    
    var body: some View {
        HStack {
            MonoBackButton(style: .dismiss, isDarkBackground: isDarkBackground)
            
            Spacer()
            
            VStack(spacing: 2) {
                Text(LocalizedStringKey("player_now_playing"))
                    .font(.rounded(size: 12, weight: .medium))
                    .foregroundColor(secondaryColor)
                    .tracking(1)
                
                if let name = player.currentSong?.name {
                    Text(name)
                        .monoPlayerDisplayFont(
                            size: 13,
                            weight: .semibold,
                            fallback: .rounded(size: 13, weight: .semibold)
                        )
                        .foregroundColor(secondaryColor)
                        .lineLimit(1)
                }
                
                if let qualityInfoText = player.qualityInfoText {
                    Text(qualityInfoText)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(secondaryColor.opacity(0.6))
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // 主题切换按钮
            Button(action: onShowThemePicker) {
                MonoIcon(icon: .equalizer, size: 18, color: contentColor.opacity(0.6))
            }
            .buttonStyle(MonoBouncingButtonStyle())
            .frame(width: 36, height: 36)
            
            // EQ 按钮
            Button(action: onShowEQ) {
                MonoIcon(icon: .equalizer, size: 20, color: contentColor)
            }
            .buttonStyle(MonoBouncingButtonStyle())
            .frame(width: 44, height: 44)
            .background(contentColor.opacity(0.1))
            .clipShape(Circle())
            .monoGlassCircle()
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
    }
}
