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
    @Environment(\.verticalSizeClass) private var verticalSizeClass
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

    private var usesCompactVerticalLayout: Bool {
        verticalSizeClass == .compact
    }

    var body: some View {
        let _ = settings.globalThemeRevision

        ZStack {
            VStack(spacing: usesCompactVerticalLayout ? 8 : 16) {
                header
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    .padding(.top, usesCompactVerticalLayout ? 0 : 4)

                currentQualityHero
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    .iPadContentWidth(500)

                ScrollView {
                    VStack(spacing: 0) {
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
            Button(String(localized: "common_ok"), role: .cancel) { }
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

    private var activeSource: MusicSource {
        if isKugou { return .kugou }
        if isQishui { return .qishui }
        if isQQMusic { return .qqmusic }
        return .netease
    }

    private var currentQualityDetail: String {
        if isQQMusic { return currentQQQuality.subtitle }
        if isKugou { return (currentKugouQuality ?? player.kugouSoundQuality).subtitle }
        return currentQuality.subtitle
    }

    private var currentQualityIntensity: CGFloat {
        if isQQMusic {
            return min(max(CGFloat(currentQQQuality.level + 1) / 16, 0.18), 1)
        }

        let quality = isKugou ? (currentKugouQuality ?? player.kugouSoundQuality) : currentQuality
        switch quality {
        case .none: return 0.18
        case .standard: return 0.24
        case .higher: return 0.34
        case .exhigh: return 0.46
        case .lossless: return 0.62
        case .hires: return 0.78
        case .jyeffect: return 0.7
        case .sky: return 0.84
        case .jymaster: return 1
        case .multitrack: return 0.92
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(LocalizedStringKey("quality_title"))
                .font(NeumorphicStyle.isActive ? NeumorphicStyle.titleFont(25, weight: .semibold) : (SequoiaStyle.isActive ? SequoiaStyle.titleFont(25, weight: .semibold) : .system(size: 25, weight: .bold, design: .rounded)))
                .foregroundColor(headerInk)

            Spacer(minLength: 0)

            Button(action: { dismissCurrentPresentation(systemDismiss: dismiss, monoSheetDismiss: monoSheetDismiss) }) {
                MonoIcon(icon: .close, size: 14, color: SequoiaStyle.isActive ? SequoiaStyle.inkSoft : .monoTextSecondary)
                    .frame(width: 42, height: 42)
                    .background { closeButtonBackground }
            }
            .accessibilityLabel(Text("关闭"))
        }
    }

    private var currentQualityHero: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.monoSheetSurfaceTop)

            QualitySpectrumArtwork(
                tint: activeSource.themedBadgeColor,
                intensity: currentQualityIntensity
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 7) {
                    Text(activeSource.displayName)
                    Text("·")
                    Text(String(localized: "quality_current_prefix"))
                }
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(headerInkSoft)

                Text(currentQualityDisplayName)
                    .font(SequoiaStyle.isActive ? SequoiaStyle.titleFont(24, weight: .semibold) : .system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(headerInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)

                Text(currentQualityDetail)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(headerInkSoft)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
        .frame(height: 118)
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.monoSeparator.opacity(0.45), lineWidth: 0.6)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - 加载骨架

    private var loadingSkeleton: some View {
        QualitySheetSkeleton()
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
                        isSelected: (currentKugouQuality ?? player.kugouSoundQuality) == info.quality,
                        isLocked: !info.isAvailable,
                        lockedLabel: info.isAvailable ? nil : String(localized: "quality_unavailable")
                    )
                }
                .buttonStyle(QualityOptionButtonStyle())
                .disabled(!info.isAvailable)

                if index < qualities.count - 1 {
                    qualityDivider
                }
            }
        }
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
                        isSelected: currentQuality == info.soundQuality
                    )
                }
                .buttonStyle(QualityOptionButtonStyle())
                
                if index < qualities.count - 1 {
                    qualityDivider
                }
            }
        }
    }
    
    // MARK: - QQ 音质分组
    
    private static let premiumLocked: Set<QQMusicQuality> = [.master, .atmos2, .atmos51]

    @ViewBuilder
    private func qualityGroup(title: String, qualities: [QQMusicQuality]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(headerInkSoft)
                .padding(.horizontal, 16)
                .padding(.top, 22)
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
                        isSelected: currentQQQuality == quality,
                        isLocked: locked,
                        lockedLabel: locked ? String(localized: "quality_qq_risk_restricted") : nil
                    )
                }
                .buttonStyle(QualityOptionButtonStyle())
                // Remove .disabled(locked) so they can tap it to see the toast
                
                if index < qualities.count - 1 {
                    qualityDivider
                }
            }
            
            Color.clear.frame(height: 6)
        }
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
                        isSelected: currentQuality == quality
                    )
                }
                .buttonStyle(QualityOptionButtonStyle())
                
                if index < qualities.count - 1 {
                    qualityDivider
                }
            }
        }
    }
    
    // MARK: - 音质行

    private var rowAccent: Color {
        activeSource.themedBadgeColor
    }

    private func qualityRow(
        name: String,
        subtitle: String,
        isSelected: Bool,
        isLocked: Bool = false,
        lockedLabel: String? = nil
    ) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(SequoiaStyle.isActive ? SequoiaStyle.bodyFont(16, weight: isSelected ? .semibold : .medium) : .system(size: 16, weight: isSelected ? .semibold : .medium, design: .rounded))
                        .foregroundColor(isLocked ? lockedRowColor : (SequoiaStyle.isActive ? SequoiaStyle.ink : .monoTextPrimary))
                        .lineLimit(1)

                    if isLocked, let lockedLabel {
                        Text(lockedLabel)
                            .font(SequoiaStyle.isActive ? SequoiaStyle.labelFont(9, weight: .medium) : .system(size: 9, weight: .medium, design: .rounded))
                            .foregroundColor(lockedRowColor)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.monoSeparator.opacity(0.4), in: Capsule())
                    }
                }

                Text(subtitle)
                    .font(SequoiaStyle.isActive ? SequoiaStyle.labelFont(12, weight: .regular) : .system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(isLocked ? lockedRowColor : (SequoiaStyle.isActive ? SequoiaStyle.inkSoft : .monoTextSecondary))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            Spacer()

            if isLocked {
                MonoIcon(icon: .lock, size: 14, color: lockedRowColor)
                    .frame(width: 32, height: 32)
            } else if isSelected {
                ZStack {
                    Circle()
                        .fill(rowAccent)

                    MonoIcon(icon: .checkmark, size: 11, color: selectedMarkColor)
                        .transition(.scale.combined(with: .opacity))
                }
                .frame(width: 26, height: 26)
                .animation(.spring(response: 0.28, dampingFraction: 0.78), value: isSelected)
            } else {
                Color.clear
                    .frame(width: 26, height: 26)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(minHeight: 68)
        .background {
            if isSelected && !isLocked {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(rowAccent.opacity(NeumorphicStyle.isActive || SequoiaStyle.isActive ? 0.11 : 0.08))
            }
        }
        .contentShape(Rectangle())
        .animation(.easeOut(duration: 0.18), value: isSelected)
        .accessibilityElement(children: .combine)
        .accessibilityValue(isSelected ? Text(String(localized: "quality_current_prefix")) : Text(""))
    }

    @ViewBuilder
    private var qualityDivider: some View {
        Divider()
            .padding(.leading, 14)
            .padding(.trailing, 12)
    }

    private var lockedRowColor: Color {
        if SequoiaStyle.isActive { return SequoiaStyle.inkMuted.opacity(0.72) }
        return .monoTextSecondary.opacity(0.7)
    }

    private var selectedMarkColor: Color {
        ThemeColorCustomization.readableForegroundColor(
            on: rowAccent,
            colorScheme: colorScheme
        )
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

}

// MARK: - 当前音质频谱

/// 根据当前音质等级生成不同密度的频谱纹理；它属于界面内容，而不是音质图标。
private struct QualitySpectrumArtwork: View {
    let tint: Color
    let intensity: CGFloat

    var body: some View {
        Canvas { context, size in
            let clampedIntensity = min(max(intensity, 0.12), 1)
            let lineCount = 5 + Int(clampedIntensity * 4)
            let startX = size.width * 0.38
            let drawingWidth = size.width - startX + 20
            let centerY = size.height * 0.52

            for index in 0 ..< lineCount {
                let progress = lineCount > 1 ? CGFloat(index) / CGFloat(lineCount - 1) : 0.5
                let centered = progress - 0.5
                let amplitude = (12 + 22 * clampedIntensity) * (1 - abs(centered) * 0.48)
                let baseline = centerY + centered * (48 + 18 * clampedIntensity)
                let phase = CGFloat(index) * 0.72
                var path = Path()

                for step in 0 ... 48 {
                    let xProgress = CGFloat(step) / 48
                    let x = startX + drawingWidth * xProgress
                    let envelope = sin(.pi * xProgress)
                    let primary = sin(xProgress * .pi * (2.4 + clampedIntensity * 1.8) + phase)
                    let harmonic = sin(xProgress * .pi * 7.2 - phase * 0.7) * 0.22
                    let y = baseline + (primary + harmonic) * amplitude * envelope

                    if step == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }

                let opacity = 0.1 + Double(1 - abs(centered) * 1.35) * 0.2
                context.stroke(
                    path,
                    with: .color(tint.opacity(max(opacity, 0.07))),
                    style: StrokeStyle(lineWidth: index == lineCount / 2 ? 1.8 : 1.05, lineCap: .round)
                )
            }
        }
        .mask {
            LinearGradient(
                colors: [.clear, .white.opacity(0.3), .white],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - 加载骨架

/// 音质加载中的占位行：呼吸明暗，尺寸与真实行一致，避免加载完成后跳版
private struct QualitySheetSkeleton: View {
    @State private var pulsing = false

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0 ..< 4, id: \.self) { index in
                HStack(spacing: 14) {
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
                        .stroke(Color.monoSeparator.opacity(0.5), lineWidth: 1.2)
                        .frame(width: 26, height: 26)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)

                if index < 3 {
                    Divider()
                        .padding(.leading, 14)
                        .padding(.trailing, 12)
                }
            }
        }
    }
}

private struct QualityOptionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed ? 0.992 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
