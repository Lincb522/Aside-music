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
    
    // QQ 音质分组
    private let qqPremiumQualities: [QQMusicQuality] = [.master, .atmos2, .atmos51]
    private let qqLosslessQualities: [QQMusicQuality] = [.flac, .ogg640]
    private let qqHighQualities: [QQMusicQuality] = [.ogg320, .mp3_320, .ogg192, .aac192]
    private let qqStandardQualities: [QQMusicQuality] = [.mp3_128, .ogg96, .aac96, .aac48]
    
    var body: some View {
        ZStack {
            AsideBackground()
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                HStack {
                    Text(LocalizedStringKey("quality_title"))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.asideTextPrimary)
                    
                    if isUnblocked {
                        Text(LocalizedStringKey("quality_kugou_source"))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.asideIconForeground)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.asideIconBackground)
                            .cornerRadius(4)
                    } else if isQQMusic {
                        Text(LocalizedStringKey("quality_qq_source"))
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
                    VStack(spacing: 16) {
                        if isQQMusic {
                            // QQ 音乐歌曲：分组显示音质
                            qualityGroup(title: NSLocalizedString("quality_premium", comment: ""), qualities: qqPremiumQualities)
                            qualityGroup(title: NSLocalizedString("quality_lossless", comment: ""), qualities: qqLosslessQualities)
                            qualityGroup(title: NSLocalizedString("quality_high", comment: ""), qualities: qqHighQualities)
                            qualityGroup(title: NSLocalizedString("quality_standard", comment: ""), qualities: qqStandardQualities)
                        } else if isUnblocked {
                            // 解灰歌曲：显示酷狗音质
                            qualityList(kugouQualities)
                        } else {
                            // 正常歌曲：显示网易云音质
                            qualityList(neteaseQualities)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
    }
    
    // MARK: - QQ 音质分组
    
    @ViewBuilder
    private func qualityGroup(title: String, qualities: [QQMusicQuality]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.asideTextSecondary)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
            
            ForEach(Array(qualities.enumerated()), id: \.element) { index, quality in
                Button(action: { onSelectQQ(quality) }) {
                    qualityRow(
                        name: quality.displayName,
                        subtitle: quality.subtitle,
                        badge: quality.badgeText,
                        isSelected: currentQQQuality == quality
                    )
                }
                .buttonStyle(.plain)
                
                if index < qualities.count - 1 {
                    Divider().padding(.leading, 56)
                }
            }
            
            Color.clear.frame(height: 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.asideMilk)
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    // MARK: - 通用音质列表
    
    @ViewBuilder
    private func qualityList<T: Hashable>(_ qualities: [T]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(qualities.enumerated()), id: \.element) { index, quality in
                Button(action: {
                    if let kugouQuality = quality as? KugouQuality {
                        onSelectKugou(kugouQuality)
                    } else if let neteaseQuality = quality as? SoundQuality {
                        onSelectNetease(neteaseQuality)
                    }
                }) {
                    if let kugouQuality = quality as? KugouQuality {
                        qualityRow(
                            name: kugouQuality.displayName,
                            subtitle: kugouQuality.subtitle,
                            badge: kugouQuality.badgeText,
                            isSelected: currentKugouQuality == kugouQuality
                        )
                    } else if let neteaseQuality = quality as? SoundQuality {
                        qualityRow(
                            name: neteaseQuality.displayName,
                            subtitle: neteaseQuality.subtitle,
                            badge: neteaseQuality.badgeText,
                            isSelected: currentQuality == neteaseQuality
                        )
                    }
                }
                .buttonStyle(.plain)
                
                if index < qualities.count - 1 {
                    Divider().padding(.leading, 56)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.asideMilk)
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    // MARK: - 音质行
    
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
