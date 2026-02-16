import SwiftUI

struct SoundQualitySheet: View {
    let currentQuality: SoundQuality
    let currentKugouQuality: KugouQuality
    let currentQQQuality: QQMusicQuality
    let isUnblocked: Bool
    let isQQMusic: Bool
    let onSelectNetease: (SoundQuality) -> Void
    let onSelectKugou: (KugouQuality) -> Void
    let onSelectQQ: (QQMusicQuality) -> Void
    @Environment(\.dismiss) private var dismiss
    
    private let neteaseQualities: [SoundQuality] = SoundQuality.allCases.filter { $0 != .none && $0 != .higher }
    private let kugouQualities: [KugouQuality] = KugouQuality.allCases
    private let qqQualities: [QQMusicQuality] = QQMusicQuality.allCases
    
    var body: some View {
        ZStack {
            AsideBackground()
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                HStack {
                    Text("音质选择")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.asideTextPrimary)
                    
                    if isUnblocked {
                        Text("酷狗源")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.asideIconForeground)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.asideIconBackground)
                            .cornerRadius(4)
                    } else if isQQMusic {
                        Text("QQ音乐")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.asideIconForeground)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.asideIconBackground)
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                    Button(action: { dismiss() }) {
                        AsideIcon(icon: .close, size: 14, color: .asideTextSecondary)
                            .padding(10)
                            .background(Color.asideSeparator)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        if isQQMusic {
                            // QQ 音乐歌曲：显示 QQ 音乐音质
                            ForEach(Array(qqQualities.enumerated()), id: \.element) { index, quality in
                                Button(action: { onSelectQQ(quality) }) {
                                    qualityRow(
                                        name: quality.displayName,
                                        subtitle: quality.subtitle,
                                        badge: quality.badgeText,
                                        isSelected: currentQQQuality == quality
                                    )
                                }
                                .buttonStyle(.plain)
                                
                                if index < qqQualities.count - 1 {
                                    Divider().padding(.leading, 56)
                                }
                            }
                        } else if isUnblocked {
                            // 解灰歌曲：显示酷狗音质
                            ForEach(Array(kugouQualities.enumerated()), id: \.element) { index, quality in
                                Button(action: { onSelectKugou(quality) }) {
                                    qualityRow(
                                        name: quality.displayName,
                                        subtitle: quality.subtitle,
                                        badge: quality.badgeText,
                                        isSelected: currentKugouQuality == quality
                                    )
                                }
                                .buttonStyle(.plain)
                                
                                if index < kugouQualities.count - 1 {
                                    Divider().padding(.leading, 56)
                                }
                            }
                        } else {
                            // 正常歌曲：显示网易云音质
                            ForEach(Array(neteaseQualities.enumerated()), id: \.element) { index, quality in
                                Button(action: { onSelectNetease(quality) }) {
                                    qualityRow(
                                        name: quality.displayName,
                                        subtitle: quality.subtitle,
                                        badge: quality.badgeText,
                                        isSelected: currentQuality == quality
                                    )
                                }
                                .buttonStyle(.plain)
                                
                                if index < neteaseQualities.count - 1 {
                                    Divider().padding(.leading, 56)
                                }
                            }
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.ultraThinMaterial).overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.asideGlassOverlay)).shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 20)
                }
            }
        }
    }
    
    private func qualityRow(name: String, subtitle: String, badge: String?, isSelected: Bool) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.asideIconBackground : Color.asideIconBackground.opacity(0.08))
                    .frame(width: 32, height: 32)
                
                AsideIcon(icon: .soundQuality, size: 16, color: isSelected ? .asideIconForeground : .asideTextPrimary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.asideTextPrimary)
                    
                    if let badge = badge {
                        Text(badge)
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(.asideIconForeground)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.asideIconBackground)
                            .cornerRadius(4)
                    }
                }
                
                Text(subtitle)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(.asideTextSecondary)
            }
            
            Spacer()
            
            if isSelected {
                AsideIcon(icon: .checkmark, size: 14, color: .asideTextPrimary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
