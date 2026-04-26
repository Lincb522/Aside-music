import SwiftUI

/// 播放器右上角三点菜单 — 全屏遮罩 + 右上角弹出菜单
struct PlayerMoreMenu: View {
    @Binding var isPresented: Bool
    var anchorFrame: CGRect? = nil
    var isDarkBackground: Bool = false
    var onQuality: (() -> Void)? = nil
    var onEQ: () -> Void
    var onTheme: () -> Void
    
    @ObservedObject private var player = PlayerManager.shared
    @ObservedObject private var gameMode = GameModeManager.shared
    @State private var showTimerSheet = false

    private let textColor: Color = .monologueTextPrimary
    
    private var timerStatusText: String? {
        if player.pendingSleepStopAfterCurrentTrack {
            return String(localized: "podcast_timer_pending_short")
        }
        guard let remaining = player.sleepTimerRemaining else { return nil }
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

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
            if !showTimerSheet {
                VStack(spacing: 0) {
                    if let onQuality {
                        menuItem(icon: .soundQuality, title: NSLocalizedString("quality_title", comment: "")) {
                            isPresented = false
                            onQuality()
                        }

                        Rectangle()
                            .fill(Color.monologueSeparator)
                            .frame(height: 0.5)
                    }

                    menuItem(
                        icon: .clock,
                        title: String(localized: "podcast_timer_title"),
                        trailingText: timerStatusText
                    ) {
                        showTimerSheet = true
                    }

                    Rectangle()
                        .fill(Color.monologueSeparator)
                        .frame(height: 0.5)

                    menuItem(icon: .audioWave, title: String(localized: "均衡器")) {
                        isPresented = false
                        onEQ()
                    }

                    Rectangle()
                        .fill(Color.monologueSeparator)
                        .frame(height: 0.5)

                    menuItem(icon: .playerTheme, title: String(localized: "播放器主题")) {
                        isPresented = false
                        onTheme()
                    }

                    Rectangle()
                        .fill(Color.monologueSeparator)
                        .frame(height: 0.5)

                    // 游戏模式快捷开关（边打游戏边听歌）
                    menuItem(
                        icon: .waveform,
                        title: gameMode.isActive
                            ? String(localized: "game_mode_menu_on")
                            : String(localized: "game_mode_menu_off"),
                        trailingText: gameMode.isActive
                            ? String(localized: "game_mode_badge_active")
                            : nil
                    ) {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        gameMode.toggle()
                    }
                }
                .frame(width: 200)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.monologueGlassTint)
                        .monologueGlass(cornerRadius: 14)
                        .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 8)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.top, DeviceLayout.headerTopPadding + 52)
                .padding(.trailing, 20)
            }
        }
        .monologueSheet(isPresented: $showTimerSheet, onDismiss: {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.9)) {
                isPresented = false
            }
        }, preset: .standard){
            PodcastTimerSheet()

        }
    }

    private func menuItem(
        icon: MonologueIcon.IconType,
        title: String,
        trailingText: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                MonologueIcon(icon: icon, size: 18, color: textColor)
                Text(title)
                    .font(.rounded(size: 15, weight: .medium))
                    .foregroundColor(textColor)
                if let trailingText {
                    Spacer(minLength: 8)
                    Text(trailingText)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.monologueTextSecondary)
                        .monospacedDigit()
                } else {
                    Spacer()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
