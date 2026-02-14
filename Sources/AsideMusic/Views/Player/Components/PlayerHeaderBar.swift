import SwiftUI
import FFmpegSwiftSDK

/// 播放器共享顶栏
struct PlayerHeaderBar: View {
    @ObservedObject var player = PlayerManager.shared
    
    var contentColor: Color = .asideTextPrimary
    var secondaryColor: Color = .asideTextSecondary
    var isDarkBackground: Bool = false
    var onShowEQ: () -> Void = {}
    var onShowThemePicker: () -> Void = {}
    
    var body: some View {
        HStack {
            AsideBackButton(style: .dismiss, isDarkBackground: isDarkBackground)
            
            Spacer()
            
            VStack(spacing: 2) {
                Text(LocalizedStringKey("player_now_playing"))
                    .font(.rounded(size: 12, weight: .medium))
                    .foregroundColor(secondaryColor)
                    .tracking(1)
                
                if let name = player.currentSong?.name {
                    Text(name)
                        .font(.rounded(size: 13, weight: .semibold))
                        .foregroundColor(secondaryColor)
                        .lineLimit(1)
                }
                
                if let info = player.streamInfo {
                    Text(streamInfoText(info))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(secondaryColor.opacity(0.6))
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // 主题切换按钮
            Button(action: onShowThemePicker) {
                AsideIcon(icon: .equalizer, size: 18, color: contentColor.opacity(0.6))
            }
            .buttonStyle(AsideBouncingButtonStyle())
            .frame(width: 36, height: 36)
            
            // EQ 按钮
            Button(action: onShowEQ) {
                AsideIcon(icon: .equalizer, size: 20, color: contentColor)
            }
            .buttonStyle(AsideBouncingButtonStyle())
            .frame(width: 44, height: 44)
            .background(contentColor.opacity(0.1))
            .clipShape(Circle())
        }
        .padding(.horizontal, 24)
    }
    
    private func streamInfoText(_ info: StreamInfo) -> String {
        var parts: [String] = []
        if let codec = info.audioCodec { parts.append(codec.uppercased()) }
        if let sr = info.sampleRate {
            if sr >= 1000 {
                let khz = Double(sr) / 1000.0
                parts.append(khz == khz.rounded() ? "\(Int(khz))kHz" : String(format: "%.1fkHz", khz))
            } else {
                parts.append("\(sr)Hz")
            }
        }
        if let bd = info.bitDepth, bd > 0 { parts.append("\(bd)bit") }
        if let ch = info.channelCount, ch > 2 { parts.append("\(ch)ch") }
        return parts.joined(separator: " / ")
    }
}
