import SwiftUI

struct SoundQualitySheet: View {
    let currentQuality: SoundQuality
    let currentQQQuality: QQMusicQuality
    let isUnblocked: Bool
    let isQQMusic: Bool
    let onSelectNetease: (SoundQuality) -> Void
    let onSelectQQ: (QQMusicQuality) -> Void
    var songMid: String? = nil
    var songId: Int? = nil
    var isQishui: Bool = false
    var qishuiTrackId: Int? = nil
    var onSelectQishui: ((QishuiQualityInfo) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.monologueSheetDismiss) private var monologueSheetDismiss
    
    private let neteaseQualities: [SoundQuality] = SoundQuality.allCases.filter { $0 != .none }
    
    @State private var availableQualities: [QQSongQualityInfo]?
    @State private var availableNeteaseQualities: [NeteaseSongQualityInfo]?
    @State private var availableQishuiQualities: [QishuiQualityInfo]?
    @State private var isLoadingQualities = false
    @State private var showRiskAlert = false
    
    private let qqPremiumQualities: [QQMusicQuality] = [.master, .atmos2, .atmos51]
    private let qqLosslessQualities: [QQMusicQuality] = [.flac, .ogg640]
    private let qqHighQualities: [QQMusicQuality] = [.ogg320, .mp3_320, .ogg192, .aac192]
    private let qqStandardQualities: [QQMusicQuality] = [.mp3_128, .ogg96, .aac96, .aac48]
    
    @AppStorage("qqPremiumBlocked") private var qqPremiumBlocked: Bool = true
    
    private var availableQualityCodes: Set<String>? {
        availableQualities.map { Set($0.map { $0.quality.rawValue }) }
    }
    
    private func filterQualities(_ qualities: [QQMusicQuality]) -> [QQMusicQuality] {
        let premiumList: Set<QQMusicQuality> = [.master, .atmos2, .atmos51]
        guard let codes = availableQualityCodes else { return qualities }
        return qualities.filter { codes.contains($0.rawValue) || premiumList.contains($0) }
    }
    
    private func qualityInfo(for quality: QQMusicQuality) -> QQSongQualityInfo? {
        availableQualities?.first { $0.quality == quality }
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 20) {
                HStack {
                    Text(LocalizedStringKey("quality_title"))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.monologueTextPrimary)
                    
                    if isQishui {
                        Text("QSM")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.monologueIconForeground)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.monologueIconBackground)
                            .cornerRadius(4)
                    } else if isUnblocked || isQQMusic {
                        Text(LocalizedStringKey("quality_qq_source"))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.monologueIconForeground)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.monologueIconBackground)
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                    Button(action: { dismissCurrentPresentation(systemDismiss: dismiss, monologueSheetDismiss: monologueSheetDismiss) }) {
                        MonologueIcon(icon: .close, size: 14, color: .monologueTextSecondary)
                            .padding(10)
                            .background(Color.monologueSeparator)
                            .clipShape(Circle())
                            .monologueGlassCircle()
                    }
                }
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.top, 8)

                ScrollView {
                    VStack(spacing: 16) {
                        if isQishui {
                            if isLoadingQualities {
                                ProgressView()
                                    .padding(.vertical, 40)
                            } else {
                                qishuiQualityList
                            }
                        } else if isQQMusic || isUnblocked {
                            if isLoadingQualities {
                                ProgressView()
                                    .padding(.vertical, 40)
                            } else {
                                let premium = filterQualities(qqPremiumQualities)
                                let lossless = filterQualities(qqLosslessQualities)
                                let high = filterQualities(qqHighQualities)
                                let standard = filterQualities(qqStandardQualities)
                                
                                if !premium.isEmpty {
                                    qualityGroup(title: NSLocalizedString("quality_premium", comment: ""), qualities: premium)
                                }
                                if !lossless.isEmpty {
                                    qualityGroup(title: NSLocalizedString("quality_lossless", comment: ""), qualities: lossless)
                                }
                                if !high.isEmpty {
                                    qualityGroup(title: NSLocalizedString("quality_high", comment: ""), qualities: high)
                                }
                                if !standard.isEmpty {
                                    qualityGroup(title: NSLocalizedString("quality_standard", comment: ""), qualities: standard)
                                }
                            }
                        } else {
                            if isLoadingQualities {
                                ProgressView()
                                    .padding(.vertical, 40)
                            } else {
                                neteaseQualityList
                            }
                        }
                    }
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    .padding(.bottom, 20)
                    .iPadContentWidth(500)
                }
                .scrollIndicators(.hidden)
            }
        }
        .alert(String(localized: "risk_control_blocked", defaultValue: "当前环境由于风控限制，高保真音源暂不能使用"), isPresented: $showRiskAlert) {
            Button("好的", role: .cancel) { }
        }
        .task {
            if isQishui, let trackId = qishuiTrackId, trackId > 0 {
                await loadQishuiQualities(trackId: trackId)
            } else if (isQQMusic || isUnblocked), let mid = songMid, !mid.isEmpty {
                await loadQQQualities(mid: mid)
            } else if !isQQMusic && !isUnblocked, let id = songId, id > 0 {
                await loadNeteaseQualities(id: id)
            }
        }
    }
    
    private func loadQQQualities(mid: String) async {
        isLoadingQualities = true
        do {
            let infos = try await APIService.shared.fetchQQSongQualities(mid: mid).async()
            await MainActor.run {
                availableQualities = infos
                isLoadingQualities = false
            }
        } catch {
            await MainActor.run {
                availableQualities = nil
                isLoadingQualities = false
            }
        }
    }
    
    private func loadNeteaseQualities(id: Int) async {
        isLoadingQualities = true
        do {
            let infos = try await APIService.shared.fetchSongQualities(id: id).async()
            await MainActor.run {
                availableNeteaseQualities = infos
                isLoadingQualities = false
            }
        } catch {
            await MainActor.run {
                availableNeteaseQualities = nil
                isLoadingQualities = false
            }
        }
    }
    
    // MARK: - 汽水音乐音质加载
    
    private func loadQishuiQualities(trackId: Int) async {
        isLoadingQualities = true
        do {
            let infos = try await APIService.shared.fetchQishuiTrackQualities(trackId: trackId).async()
            await MainActor.run {
                var seen = Set<String>()
                availableQishuiQualities = infos.filter { seen.insert($0.quality).inserted }
                isLoadingQualities = false
            }
        } catch {
            await MainActor.run {
                availableQishuiQualities = nil
                isLoadingQualities = false
            }
        }
    }
    
    // MARK: - 汽水音乐音质列表
    
    private var qishuiQualityList: some View {
        let qualities = availableQishuiQualities ?? []
        return VStack(spacing: 0) {
            ForEach(Array(qualities.enumerated()), id: \.element.id) { index, info in
                Button(action: { onSelectQishui?(info) }) {
                    qualityRow(
                        name: info.displayName,
                        subtitle: "\(info.codec.uppercased()) · \(info.bitrate / 1000)kbps · \(info.sizeText)",
                        badge: info.soundQuality.badgeText,
                        isSelected: currentQuality == info.soundQuality
                    )
                }
                .buttonStyle(.plain)
                
                if index < qualities.count - 1 {
                    Divider().padding(.leading, 56)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.monologueGlassTint)
                .monologueGlass(cornerRadius: 20)
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    // MARK: - QQ 音质分组
    
    private static let premiumLocked: Set<QQMusicQuality> = [.master, .atmos2, .atmos51]

    @ViewBuilder
    private func qualityGroup(title: String, qualities: [QQMusicQuality]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.monologueTextSecondary)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
            
            ForEach(Array(qualities.enumerated()), id: \.element) { index, quality in
                let locked = qqPremiumBlocked && Self.premiumLocked.contains(quality)
                Button(action: { 
                    if locked { 
                        showRiskAlert = true
                    } else { 
                        onSelectQQ(quality) 
                    } 
                }) {
                    let info = qualityInfo(for: quality)
                    qualityRow(
                        name: quality.displayName,
                        subtitle: info.map { "\(quality.subtitle) · \($0.sizeText)" } ?? quality.subtitle,
                        badge: quality.badgeText,
                        isSelected: currentQQQuality == quality,
                        isLocked: locked
                    )
                }
                .buttonStyle(.plain)
                // Remove .disabled(locked) so they can tap it to see the toast
                
                if index < qualities.count - 1 {
                    Divider().padding(.leading, 56)
                }
            }
            
            Color.clear.frame(height: 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.monologueGlassTint)
                .monologueGlass(cornerRadius: 20)
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    // MARK: - ncm音质列表
    
    private var filteredNeteaseQualities: [SoundQuality] {
        guard let available = availableNeteaseQualities else { return neteaseQualities }
        let availableLevels = Set(available.map { $0.quality })
        return neteaseQualities.filter { availableLevels.contains($0) }
    }
    
    private func neteaseQualityInfo(for quality: SoundQuality) -> NeteaseSongQualityInfo? {
        availableNeteaseQualities?.first { $0.quality == quality }
    }
    
    private var neteaseQualityList: some View {
        let qualities = filteredNeteaseQualities
        return VStack(spacing: 0) {
            ForEach(Array(qualities.enumerated()), id: \.element) { index, quality in
                Button(action: { onSelectNetease(quality) }) {
                    let info = neteaseQualityInfo(for: quality)
                    let subtitleText: String = {
                        if let info = info, !info.sizeText.isEmpty {
                            return "\(quality.subtitle) · \(info.sizeText)"
                        }
                        return quality.subtitle
                    }()
                    qualityRow(
                        name: quality.displayName,
                        subtitle: subtitleText,
                        badge: quality.badgeText,
                        isSelected: currentQuality == quality
                    )
                }
                .buttonStyle(.plain)
                
                if index < qualities.count - 1 {
                    Divider().padding(.leading, 56)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.monologueGlassTint)
                .monologueGlass(cornerRadius: 20)
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    // MARK: - 音质行
    
    private func qualityRow(name: String, subtitle: String, badge: String?, isSelected: Bool, isLocked: Bool = false) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isLocked ? Color.monologueIconBackground.opacity(0.04) : (isSelected ? Color.monologueIconBackground : Color.monologueIconBackground.opacity(0.08)))
                    .frame(width: 32, height: 32)
                
                MonologueIcon(icon: .soundQuality, size: 16, color: isLocked ? .monologueTextSecondary.opacity(0.4) : (isSelected ? .monologueIconForeground : .monologueTextPrimary))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(isLocked ? .monologueTextSecondary.opacity(0.5) : .monologueTextPrimary)
                    
                    if let badge = badge {
                        Text(badge)
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(isLocked ? .monologueTextSecondary.opacity(0.4) : .monologueIconForeground)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(isLocked ? Color.monologueIconBackground.opacity(0.3) : Color.monologueIconBackground)
                            .cornerRadius(4)
                    }

                    if isLocked {
                        Text("风控限制")
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundColor(.monologueTextSecondary.opacity(0.5))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.monologueSeparator.opacity(0.5))
                            .cornerRadius(4)
                    }
                }
                
                Text(subtitle)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(isLocked ? .monologueTextSecondary.opacity(0.4) : .monologueTextSecondary)
            }
            
            Spacer()
            
            if isSelected && !isLocked {
                MonologueIcon(icon: .checkmark, size: 14, color: .monologueTextPrimary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
