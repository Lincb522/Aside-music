import SwiftUI

struct SoundQualitySheet: View {
    let currentQuality: SoundQuality
    let currentQQQuality: QQMusicQuality
    let isQQMusic: Bool
    let onSelectNetease: (SoundQuality) -> Void
    let onSelectQQ: (QQMusicQuality) -> Void
    var songMid: String? = nil
    var songId: Int? = nil
    var isQishui: Bool = false
    var qishuiTrackId: Int? = nil
    var onSelectQishui: ((QishuiQualityInfo) -> Void)? = nil
    var kugouMode: Bool = false
    var currentKugouQuality: SoundQuality? = nil
    var onSelectKugou: ((SoundQuality) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.monoSheetDismiss) private var monoSheetDismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var player = PlayerManager.shared
    
    private let neteaseQualities: [SoundQuality] = SoundQuality.descendingPreferenceOrder
    
    @State private var availableQualities: [QQSongQualityInfo]?
    @State private var availableNeteaseQualities: [NeteaseSongQualityInfo]?
    @State private var availableQishuiQualities: [QishuiQualityInfo]?
    @State private var availableKugouQualities: [KCMSongQualityInfo]?
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
    
    /// 当前生效音质的展示名，用于头部「当前」行
    private var currentQualityDisplayName: String {
        if isQQMusic {
            return currentQQQuality.displayName
        }
        if isKugou {
            return (currentKugouQuality ?? player.kugouSoundQuality).displayName
        }
        return currentQuality.displayName
    }

    private var isKugou: Bool {
        if kugouMode { return true }
        guard let songId,
              let currentSong = player.currentSong,
              currentSong.id == songId else { return false }
        return currentSong.isKugou
    }

    var body: some View {
        let _ = settings.globalThemeRevision

        ZStack {
            VStack(spacing: 18) {
                header
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    .padding(.top, 6)

                ScrollView {
                    VStack(spacing: 18) {
                        if isKugou {
                            if isLoadingQualities {
                                loadingSkeleton
                            } else {
                                kugouQualityList
                            }
                        } else if isQishui {
                            if isLoadingQualities {
                                loadingSkeleton
                            } else {
                                qishuiQualityList
                            }
                        } else if isQQMusic {
                            if isLoadingQualities {
                                loadingSkeleton
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
                                loadingSkeleton
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
            .themeRenderScrollLayer()
            }
        }
        .alert(String(localized: "risk_control_blocked", defaultValue: "当前环境由于风控限制，高保真音源暂不能使用"), isPresented: $showRiskAlert) {
            Button("好的", role: .cancel) { }
        }
        .task {
            if isKugou, let song = player.currentSong, song.isKugou {
                await loadKugouQualities(song: song)
            } else if isQishui, let trackId = qishuiTrackId, trackId > 0 {
                await loadQishuiQualities(trackId: trackId)
            } else if isQQMusic, let mid = songMid, !mid.isEmpty {
                await loadQQQualities(mid: mid)
            } else if !isQQMusic, let id = songId, id > 0 {
                await loadNeteaseQualities(id: id)
            }
        }
    }

    // MARK: - 头部

    private var headerInk: Color {
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        if SequoiaStyle.isActive { return SequoiaStyle.ink }
        return .monoTextPrimary
    }

    private var headerInkSoft: Color {
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        return .monoTextSecondary
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(LocalizedStringKey("quality_title"))
                        .font(NeumorphicStyle.isActive ? NeumorphicStyle.titleFont(21, weight: .semibold) : (SequoiaStyle.isActive ? SequoiaStyle.titleFont(21, weight: .semibold) : .system(size: 21, weight: .heavy, design: .rounded)))
                        .foregroundColor(headerInk)

                    if isKugou {
                        PlatformBadgeLabel(text: "KCM", source: .kugou)
                    } else if isQishui {
                        PlatformBadgeLabel(text: "QSM", source: .qishui)
                    } else if isQQMusic {
                        PlatformBadgeLabel(text: String(localized: "quality_qq_source"), source: .qqmusic)
                    }
                }

                // 当前生效音质
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.monoAccent)
                        .frame(width: 5, height: 5)

                    Text(String(localized: "quality_current_prefix"))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(headerInkSoft.opacity(0.85))

                    Text(currentQualityDisplayName)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(headerInk.opacity(0.9))
                }
            }

            Spacer(minLength: 0)

            Button(action: { dismissCurrentPresentation(systemDismiss: dismiss, monoSheetDismiss: monoSheetDismiss) }) {
                MonoIcon(icon: .close, size: 14, color: SequoiaStyle.isActive ? SequoiaStyle.inkSoft : .monoTextSecondary)
                    .padding(10)
                    .background { closeButtonBackground }
            }
        }
    }

    // MARK: - 加载骨架

    private var loadingSkeleton: some View {
        QualitySheetSkeleton(
            panelBackground: AnyView(qualityPanelBackground),
            cornerRadius: qualityPanelCornerRadius
        )
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

    private func loadKugouQualities(song: Song) async {
        isLoadingQualities = true
        do {
            let infos = try await APIService.shared.fetchKugouSongQualities(song: song).async()
            await MainActor.run {
                availableKugouQualities = infos
                isLoadingQualities = false
            }
        } catch {
            await MainActor.run {
                availableKugouQualities = nil
                isLoadingQualities = false
            }
        }
    }

    private var kugouQualityList: some View {
        let qualities = availableKugouQualities ?? Self.defaultKugouQualities
        return VStack(spacing: 0) {
            ForEach(Array(qualities.enumerated()), id: \.element.id) { index, info in
                Button(action: {
                    if let onSelectKugou {
                        onSelectKugou(info.quality)
                    } else {
                        player.switchKugouQuality(info.quality)
                    }
                    dismissCurrentPresentation(
                        systemDismiss: dismiss,
                        monoSheetDismiss: monoSheetDismiss
                    )
                }) {
                    let details = [
                        info.bitrate > 0 ? "\(info.bitrate / 1000)kbps" : info.quality.subtitle,
                        info.sizeText,
                    ].filter { !$0.isEmpty }.joined(separator: " · ")
                    qualityRow(
                        name: info.quality.displayName,
                        subtitle: details,
                        badge: info.quality.badgeText,
                        isSelected: (currentKugouQuality ?? player.kugouSoundQuality) == info.quality,
                        isLocked: !info.isAvailable,
                        lockedLabel: info.isAvailable ? nil : String(localized: "quality_unavailable")
                    )
                }
                .buttonStyle(.plain)
                .disabled(!info.isAvailable)

                if index < qualities.count - 1 {
                    Divider().padding(.leading, 65)
                }
            }
        }
        .background(qualityPanelBackground)
        .clipShape(RoundedRectangle(cornerRadius: qualityPanelCornerRadius, style: .continuous))
    }

    private static let defaultKugouQualities: [KCMSongQualityInfo] = [
        .init(quality: .multitrack, code: "multitrack", bitrate: 0, size: 0, isAvailable: true),
        .init(quality: .jymaster, code: "viper_tape", bitrate: 0, size: 0, isAvailable: true),
        .init(quality: .sky, code: "viper_atmos", bitrate: 0, size: 0, isAvailable: true),
        .init(quality: .jyeffect, code: "viper_clear", bitrate: 0, size: 0, isAvailable: true),
        .init(quality: .hires, code: "high", bitrate: 0, size: 0, isAvailable: true),
        .init(quality: .lossless, code: "flac", bitrate: 0, size: 0, isAvailable: true),
        .init(quality: .exhigh, code: "320", bitrate: 320_000, size: 0, isAvailable: true),
        .init(quality: .standard, code: "128", bitrate: 128_000, size: 0, isAvailable: true),
    ]
    
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
                    Divider().padding(.leading, 65)
                }
            }
        }
        .background(
            qualityPanelBackground
        )
        .clipShape(RoundedRectangle(cornerRadius: qualityPanelCornerRadius, style: .continuous))
    }
    
    // MARK: - QQ 音质分组
    
    private static let premiumLocked: Set<QQMusicQuality> = [.master, .atmos2, .atmos51]

    @ViewBuilder
    private func qualityGroup(title: String, qualities: [QQMusicQuality]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Capsule()
                    .fill(rowAccent.opacity(0.85))
                    .frame(width: 3, height: 11)

                Text(title)
                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    .tracking(0.4)
                    .foregroundColor(.monoTextSecondary)

                Rectangle()
                    .fill(Color.monoSeparator.opacity(0.5))
                    .frame(height: 0.5)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
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
                        isLocked: locked,
                        lockedLabel: locked ? String(localized: "quality_qq_risk_restricted") : nil
                    )
                }
                .buttonStyle(.plain)
                // Remove .disabled(locked) so they can tap it to see the toast
                
                if index < qualities.count - 1 {
                    Divider().padding(.leading, 65)
                }
            }
            
            Color.clear.frame(height: 8)
        }
        .background(
            qualityPanelBackground
        )
        .clipShape(RoundedRectangle(cornerRadius: qualityPanelCornerRadius, style: .continuous))
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
                    Divider().padding(.leading, 65)
                }
            }
        }
        .background(
            qualityPanelBackground
        )
        .clipShape(RoundedRectangle(cornerRadius: qualityPanelCornerRadius, style: .continuous))
    }
    
    // MARK: - 音质行

    private var rowAccent: Color {
        if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
        if SequoiaStyle.isActive { return SequoiaStyle.accent }
        if MangaStyle.isActive { return MangaStyle.accentPink }
        if MujiStyle.isActive { return MujiStyle.clay }
        return .monoTextPrimary
    }

    private func qualityRow(
        name: String,
        subtitle: String,
        badge: String?,
        isSelected: Bool,
        isLocked: Bool = false,
        lockedLabel: String? = nil
    ) -> some View {
        HStack(spacing: 13) {
            // 等级字标：badge 文本直接做成方标，一眼分级
            ZStack {
                qualityIconTileBackground(isSelected: isSelected, isLocked: isLocked)

                if let badge, !badge.isEmpty {
                    Text(badge)
                        .font(.system(size: badge.count > 3 ? 8 : 9.5, weight: .heavy, design: .rounded))
                        .tracking(0.3)
                        .foregroundColor(qualityIconColor(isSelected: isSelected, isLocked: isLocked))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal, 3)
                } else {
                    MonoIcon(icon: .soundQuality, size: 16, color: qualityIconColor(isSelected: isSelected, isLocked: isLocked))
                }
            }
            .frame(width: 38, height: 38)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(SequoiaStyle.isActive ? SequoiaStyle.bodyFont(15, weight: .semibold) : .system(size: 15.5, weight: isSelected ? .bold : .semibold, design: .rounded))
                        .foregroundColor(isLocked ? (SequoiaStyle.isActive ? SequoiaStyle.inkMuted.opacity(0.58) : .monoTextSecondary.opacity(0.5)) : (SequoiaStyle.isActive ? SequoiaStyle.ink : .monoTextPrimary))

                    if isLocked, let lockedLabel {
                        Text(lockedLabel)
                            .font(SequoiaStyle.isActive ? SequoiaStyle.labelFont(9, weight: .medium) : .system(size: 9, weight: .medium, design: .rounded))
                            .foregroundColor(SequoiaStyle.isActive ? SequoiaStyle.inkMuted : .monoTextSecondary.opacity(0.5))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(SequoiaStyle.isActive ? SequoiaStyle.materialList : (NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed.opacity(0.78) : Color.monoSeparator.opacity(0.5)))
                            .cornerRadius(4)
                    }
                }

                Text(subtitle)
                    .font(SequoiaStyle.isActive ? SequoiaStyle.labelFont(12, weight: .regular) : .system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(isLocked ? (SequoiaStyle.isActive ? SequoiaStyle.inkMuted.opacity(0.52) : .monoTextSecondary.opacity(0.4)) : (SequoiaStyle.isActive ? SequoiaStyle.inkSoft : .monoTextSecondary))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            Spacer()

            // 单选圈：选中实心，锁定换锁形
            if isLocked {
                MonoIcon(icon: .lock, size: 13, color: .monoTextSecondary.opacity(0.4))
            } else {
                ZStack {
                    Circle()
                        .stroke(
                            isSelected ? rowAccent : Color.monoSeparator.opacity(0.9),
                            lineWidth: isSelected ? 5.5 : 1.4
                        )
                        .frame(width: isSelected ? 14.5 : 19, height: isSelected ? 14.5 : 19)
                }
                .frame(width: 20, height: 20)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            if isSelected && !isLocked {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(rowAccent.opacity(NeumorphicStyle.isActive || SequoiaStyle.isActive ? 0.08 : 0.055))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
            }
        }
        .contentShape(Rectangle())
    }

    private var qualityPanelCornerRadius: CGFloat {
        if SequoiaStyle.isActive { return 22 }
        return NeumorphicStyle.isActive ? 22 : 16
    }

    @ViewBuilder
    private var qualityPanelBackground: some View {
        if NeumorphicStyle.isActive {
            NeumorphicSurfaceBackground(cornerRadius: qualityPanelCornerRadius, elevated: false)
        } else if SequoiaStyle.isActive {
            SequoiaSurfaceBackground(cornerRadius: qualityPanelCornerRadius, elevated: true, role: .chrome)
        } else {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.monoGlassTint)
                .monoGlass(cornerRadius: 20)
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        }
    }

    @ViewBuilder
    private var closeButtonBackground: some View {
        if NeumorphicStyle.isActive {
            NeumorphicSurfaceBackground(cornerRadius: 17, elevated: false, pressed: true, lightweight: true)
                .clipShape(Circle())
        } else if SequoiaStyle.isActive {
            SequoiaSurfaceBackground(cornerRadius: 17, elevated: false, pressed: true, role: .list)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(Color.monoSeparator)
                .monoGlassCircle()
        }
    }

    @ViewBuilder
    private func qualityIconTileBackground(isSelected: Bool, isLocked: Bool) -> some View {
        if NeumorphicStyle.isActive {
            NeumorphicSurfaceBackground(
                cornerRadius: 10,
                elevated: false,
                pressed: isSelected,
                tint: isSelected ? NeumorphicStyle.accent.opacity(0.18) : NeumorphicStyle.surfacePressed.opacity(0.72)
            )
            .opacity(isLocked ? 0.5 : 1)
        } else if SequoiaStyle.isActive {
            SequoiaSurfaceBackground(
                cornerRadius: 10,
                elevated: isSelected,
                pressed: !isSelected,
                fill: isSelected ? SequoiaStyle.accent.opacity(0.13) : SequoiaStyle.materialList,
                role: isSelected ? .selected : .list
            )
            .opacity(isLocked ? 0.5 : 1)
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isLocked ? Color.monoIconBackground.opacity(0.04) : (isSelected ? Color.monoIconBackground : Color.monoIconBackground.opacity(0.08)))
        }
    }

    private func qualityIconColor(isSelected: Bool, isLocked: Bool) -> Color {
        if isLocked { return .monoTextSecondary.opacity(0.4) }
        if MangaStyle.isActive { return isSelected ? MangaStyle.ink : MangaStyle.inkSub }
        if MujiStyle.isActive { return isSelected ? MujiStyle.onTint : MujiStyle.ink }
        if NeumorphicStyle.isActive { return isSelected ? NeumorphicStyle.accent : NeumorphicStyle.ink }
        if SequoiaStyle.isActive { return isSelected ? SequoiaStyle.accent : SequoiaStyle.inkSoft }
        return isSelected ? .monoIconForeground : .monoTextPrimary
    }

}

// MARK: - 加载骨架

/// 音质加载中的占位行：呼吸明暗，尺寸与真实行一致，避免加载完成后跳版
private struct QualitySheetSkeleton: View {
    let panelBackground: AnyView
    let cornerRadius: CGFloat

    @State private var pulsing = false

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0 ..< 4, id: \.self) { index in
                HStack(spacing: 13) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.monoSeparator.opacity(0.45))
                        .frame(width: 38, height: 38)

                    VStack(alignment: .leading, spacing: 6) {
                        Capsule()
                            .fill(Color.monoSeparator.opacity(0.5))
                            .frame(width: 92, height: 9)
                        Capsule()
                            .fill(Color.monoSeparator.opacity(0.32))
                            .frame(width: 150, height: 7)
                    }

                    Spacer()

                    Circle()
                        .stroke(Color.monoSeparator.opacity(0.5), lineWidth: 1.4)
                        .frame(width: 19, height: 19)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)

                if index < 3 {
                    Divider().padding(.leading, 65)
                }
            }
        }
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .opacity(pulsing ? 0.55 : 1)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                pulsing = true
            }
        }
    }
}
