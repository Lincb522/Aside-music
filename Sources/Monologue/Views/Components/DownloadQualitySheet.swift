import SwiftUI

struct DownloadQualitySheet: View {
    let song: Song
    let onDownload: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.monologueSheetDismiss) private var monologueSheetDismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var downloadManager = DownloadManager.shared
    @ObservedObject private var settings = SettingsManager.shared

    private var isQQ: Bool { song.isQQMusic }
    private var isQishui: Bool { song.isQishui }

    private let neteaseQualities: [SoundQuality] = SoundQuality.descendingPreferenceOrder.filter { $0 != .higher }

    private let qqPremiumQualities: [QQMusicQuality] = [.master, .atmos2, .atmos51]
    private let qqLosslessQualities: [QQMusicQuality] = [.flac, .ogg640]
    private let qqHighQualities: [QQMusicQuality] = [.ogg320, .mp3_320, .ogg192, .aac192]
    private let qqStandardQualities: [QQMusicQuality] = [.mp3_128, .ogg96, .aac96, .aac48]

    @State private var availableQQQualities: Set<String>?
    @State private var availableNeteaseQualities: Set<String>?
    @State private var availableQishuiQualities: [QishuiQualityInfo]?
    @State private var isLoadingQualities = false
    @State private var showDecryptAlert = false
    @AppStorage("qmcDecryptEnabled") private var qmcDecryptEnabled: Bool = false

    private func filterQQ(_ qualities: [QQMusicQuality]) -> [QQMusicQuality] {
        guard let codes = availableQQQualities else { return qualities }
        return qualities.filter { codes.contains($0.rawValue) }
    }
    
    private func filterNetease(_ qualities: [SoundQuality]) -> [SoundQuality] {
        guard let levels = availableNeteaseQualities else { return qualities }
        return qualities.filter { levels.contains($0.rawValue) }
    }
    
    // Always include premium qualities in UI, even if API doesn't report them
    private func filterQQForUI(_ qualities: [QQMusicQuality]) -> [QQMusicQuality] {
        let premiumList: Set<QQMusicQuality> = [.master, .atmos2, .atmos51]
        guard let codes = availableQQQualities else { return qualities }
        return qualities.filter { codes.contains($0.rawValue) || premiumList.contains($0) }
    }

    var body: some View {
        let _ = settings.globalThemeRevision

        VStack(spacing: 20) {
            header
            ScrollView {
                VStack(spacing: 16) {
                    if isLoadingQualities {
                        ProgressView().padding(.vertical, 40)
                    } else if isQishui {
                        qishuiSection
                    } else if isQQ {
                        let premium = filterQQForUI(qqPremiumQualities)
                        let lossless = filterQQForUI(qqLosslessQualities)
                        let high = filterQQForUI(qqHighQualities)
                        let standard = filterQQForUI(qqStandardQualities)
                        if !premium.isEmpty { qqGroup(title: String(localized: "quality_premium"), qualities: premium) }
                        if !lossless.isEmpty { qqGroup(title: String(localized: "quality_lossless"), qualities: lossless) }
                        if !high.isEmpty { qqGroup(title: String(localized: "quality_high"), qualities: high) }
                        if !standard.isEmpty { qqGroup(title: String(localized: "quality_standard"), qualities: standard) }
                    } else {
                        neteaseSection
                    }
                }
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.bottom, 30)
                .iPadContentWidth(500)
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
        .alert(String(localized: "需要开启QMC解密", defaultValue: "此音质为加密格式，请在播放设置中开启「QMC本地解密播放」后方可下载"), isPresented: $showDecryptAlert) {
            Button("好的", role: .cancel) { }
        }
        .task {
            await loadAvailableQualities()
        }
    }
    
    private func loadAvailableQualities() async {
        isLoadingQualities = true
        defer { isLoadingQualities = false }
        if isQishui, let trackId = song.qishuiTrackId {
            do {
                let infos = try await APIService.shared.fetchQishuiTrackQualities(trackId: trackId).async()
                var seen = Set<String>()
                availableQishuiQualities = infos.filter { seen.insert($0.quality).inserted }
            } catch {
                availableQishuiQualities = nil
            }
        } else if isQQ, let mid = song.qqMid {
            do {
                let infos = try await APIService.shared.prefetchQQQualities(mid: mid)
                availableQQQualities = Set(infos.map { $0.quality.rawValue })
            } catch {
                availableQQQualities = nil
            }
        } else if !isQQ {
            do {
                let infos = try await APIService.shared.prefetchNeteaseQualities(id: song.id)
                availableNeteaseQualities = Set(infos.map { $0.quality.rawValue })
            } catch {
                availableNeteaseQualities = nil
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "download_quality_title"))
                    .font(headerTitleFont)
                    .foregroundColor(headerTitleColor)

                Text(song.name)
                    .font(headerSubtitleFont)
                    .foregroundColor(headerSubtitleColor)
                    .lineLimit(1)
            }

            Spacer()

            let source = song.source ?? (isQQ ? MusicSource.qqmusic : MusicSource.netease)
            PlatformBadgeLabel(text: source.displayName, source: source)

            Button(action: { dismissCurrentPresentation(systemDismiss: dismiss, monologueSheetDismiss: monologueSheetDismiss) }) {
                MonologueIcon(icon: .close, size: 14, color: headerSubtitleColor)
                    .padding(10)
                    .background { closeButtonBackground }
            }
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.top, 8)
    }

    private var headerTitleFont: Font {
        if NeumorphicStyle.isActive { return NeumorphicStyle.titleFont(20, weight: .semibold) }
        if SequoiaStyle.isActive { return SequoiaStyle.titleFont(20, weight: .semibold) }
        return .system(size: 20, weight: .bold, design: .rounded)
    }

    private var headerSubtitleFont: Font {
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(13, weight: .regular) }
        return .system(size: 13, weight: .medium, design: .rounded)
    }

    private var headerTitleColor: Color {
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        if SequoiaStyle.isActive { return SequoiaStyle.ink }
        return .monologueTextPrimary
    }

    private var headerSubtitleColor: Color {
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        return .monologueTextSecondary
    }

    private var groupTitleFont: Font {
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(13, weight: .semibold) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(13, weight: .semibold) }
        return .system(size: 13, weight: .semibold, design: .rounded)
    }

    private var groupTitleColor: Color {
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        return .monologueTextSecondary
    }

    // MARK: - ncm

    private var neteaseSection: some View {
        let filtered = filterNetease(neteaseQualities)
        return VStack(spacing: 0) {
            ForEach(Array(filtered.enumerated()), id: \.element) { index, quality in
                Button {
                    downloadManager.download(song: song, quality: quality)
                    HapticManager.shared.success()
                    dismissCurrentPresentation(systemDismiss: dismiss, monologueSheetDismiss: monologueSheetDismiss)
                } label: {
                    qualityRow(
                        name: quality.displayName,
                        subtitle: quality.subtitle,
                        badge: quality.badgeText
                    )
                }
                .buttonStyle(.plain)

                if index < filtered.count - 1 {
                    Divider().padding(.leading, 56)
                }
            }
        }
        .background(
            qualityPanelBackground
        )
        .clipShape(RoundedRectangle(cornerRadius: qualityPanelCornerRadius, style: .continuous))
    }

    // MARK: - qcm

    @ViewBuilder
    private func qqGroup(title: String, qualities: [QQMusicQuality]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(groupTitleFont)
                .foregroundColor(groupTitleColor)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            ForEach(Array(qualities.enumerated()), id: \.element) { index, quality in
                let locked = !qmcDecryptEnabled && quality.isEncrypted
                Button {
                    if locked {
                        showDecryptAlert = true
                    } else {
                        downloadManager.downloadQQ(song: song, quality: quality)
                        HapticManager.shared.success()
                        dismissCurrentPresentation(systemDismiss: dismiss, monologueSheetDismiss: monologueSheetDismiss)
                    }
                } label: {
                    qualityRow(
                        name: quality.displayName,
                        subtitle: quality.subtitle,
                        badge: quality.badgeText,
                        isLocked: locked
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
            qualityPanelBackground
        )
        .clipShape(RoundedRectangle(cornerRadius: qualityPanelCornerRadius, style: .continuous))
    }

    // MARK: - QSM

    private var qishuiSection: some View {
        let qualities = availableQishuiQualities ?? []
        return VStack(spacing: 0) {
            ForEach(Array(qualities.enumerated()), id: \.element.id) { index, info in
                Button {
                    downloadManager.downloadQishui(song: song, quality: info.quality)
                    HapticManager.shared.success()
                    dismissCurrentPresentation(systemDismiss: dismiss, monologueSheetDismiss: monologueSheetDismiss)
                } label: {
                    qualityRow(
                        name: info.displayName,
                        subtitle: "\(info.codec.uppercased()) · \(info.bitrate / 1000)kbps · \(info.sizeText)",
                        badge: info.soundQuality.badgeText
                    )
                }
                .buttonStyle(.plain)

                if index < qualities.count - 1 {
                    Divider().padding(.leading, 56)
                }
            }
        }
        .background(
            qualityPanelBackground
        )
        .clipShape(RoundedRectangle(cornerRadius: qualityPanelCornerRadius, style: .continuous))
    }

    // MARK: - Row

    private func qualityRow(name: String, subtitle: String, badge: String?, isLocked: Bool = false) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.clear)
                    .frame(width: 32, height: 32)
                    .background {
                        qualityIconTileBackground(isLocked: isLocked)
                    }

                MonologueIcon(icon: isLocked ? .lock : .playerDownload, size: 16, color: qualityIconColor(isLocked: isLocked))
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(qualityNameFont)
                        .foregroundColor(qualityNameColor(isLocked: isLocked))

                    if let badge {
                        Text(badge)
                            .font(qualityBadgeFont)
                            .foregroundColor(qualityBadgeForeground(isLocked: isLocked))
                            .tracking(MujiStyle.isActive ? 0.5 : 0)
                            .padding(.horizontal, qualityBadgeHorizontalPadding)
                            .padding(.vertical, qualityBadgeVerticalPadding)
                            .background {
                                qualityBadgeBackground(isLocked: isLocked)
                            }
                            .overlay {
                                qualityBadgeStroke(isLocked: isLocked)
                            }
                    }

                    if isLocked {
                        Text("需要开启解密")
                            .font(SequoiaStyle.isActive ? SequoiaStyle.labelFont(9, weight: .medium) : .system(size: 9, weight: .medium, design: .rounded))
                            .foregroundColor(lockedTextColor)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(lockBadgeBackground)
                            .cornerRadius(4)
                    }
                }

                Text(subtitle)
                    .font(qualitySubtitleFont)
                    .foregroundColor(isLocked ? lockedTextColor.opacity(0.8) : qualitySubtitleColor)
            }

            Spacer()

            if !isLocked {
                MonologueIcon(icon: .playerDownload, size: 14, color: qualitySubtitleColor)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var qualityNameFont: Font {
        if SequoiaStyle.isActive { return SequoiaStyle.bodyFont(16, weight: .medium) }
        return .system(size: 16, weight: .medium, design: .rounded)
    }

    private var qualitySubtitleFont: Font {
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(12, weight: .regular) }
        return .system(size: 12, weight: .regular, design: .rounded)
    }

    private func qualityNameColor(isLocked: Bool) -> Color {
        if isLocked { return lockedTextColor }
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        if SequoiaStyle.isActive { return SequoiaStyle.ink }
        return .monologueTextPrimary
    }

    private var qualitySubtitleColor: Color {
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        return .monologueTextSecondary
    }

    private var lockedTextColor: Color {
        if SequoiaStyle.isActive { return SequoiaStyle.inkMuted.opacity(0.72) }
        return .monologueTextSecondary.opacity(0.5)
    }

    private var lockBadgeBackground: Color {
        if NeumorphicStyle.isActive { return NeumorphicStyle.surfacePressed.opacity(0.78) }
        if SequoiaStyle.isActive { return SequoiaStyle.materialList.opacity(0.78) }
        return Color.monologueSeparator.opacity(0.5)
    }

    private var qualityPanelCornerRadius: CGFloat {
        (NeumorphicStyle.isActive || SequoiaStyle.isActive) ? 22 : 16
    }

    @ViewBuilder
    private var qualityPanelBackground: some View {
        if NeumorphicStyle.isActive {
            NeumorphicSurfaceBackground(cornerRadius: qualityPanelCornerRadius, elevated: false)
        } else if SequoiaStyle.isActive {
            SequoiaSurfaceBackground(cornerRadius: qualityPanelCornerRadius, elevated: false, role: .list)
        } else {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.monologueGlassTint)
                .monologueGlass(cornerRadius: 20)
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
                .fill(Color.monologueSeparator)
                .monologueGlassCircle()
        }
    }

    @ViewBuilder
    private func qualityIconTileBackground(isLocked: Bool) -> some View {
        if NeumorphicStyle.isActive {
            NeumorphicSurfaceBackground(
                cornerRadius: 10,
                elevated: false,
                pressed: false,
                tint: NeumorphicStyle.surfacePressed.opacity(0.72)
            )
            .opacity(isLocked ? 0.5 : 1)
        } else if SequoiaStyle.isActive {
            SequoiaSurfaceBackground(
                cornerRadius: 10,
                elevated: false,
                pressed: isLocked,
                fill: SequoiaStyle.accent.opacity(isLocked ? 0.04 : 0.10),
                role: .selected
            )
            .opacity(isLocked ? 0.55 : 1)
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isLocked ? Color.monologueIconBackground.opacity(0.04) : Color.monologueIconBackground.opacity(0.08))
        }
    }

    private func qualityIconColor(isLocked: Bool) -> Color {
        if isLocked { return SequoiaStyle.isActive ? SequoiaStyle.inkMuted.opacity(0.5) : .monologueTextSecondary.opacity(0.4) }
        if MangaStyle.isActive { return MangaStyle.inkSub }
        if MujiStyle.isActive { return MujiStyle.ink }
        if SequoiaStyle.isActive { return SequoiaStyle.accent }
        return NeumorphicStyle.isActive ? NeumorphicStyle.ink : .monologueTextPrimary
    }

    private var qualityBadgeFont: Font {
        if MangaStyle.isActive { return MangaStyle.labelFont(9.5, weight: .black) }
        if MujiStyle.isActive { return MujiStyle.labelFont(9, weight: .semibold) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(9, weight: .semibold) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(9, weight: .semibold) }
        return .system(size: 9, weight: .bold, design: .rounded)
    }

    private var qualityBadgeHorizontalPadding: CGFloat {
        MangaStyle.isActive ? 6 : 5
    }

    private var qualityBadgeVerticalPadding: CGFloat {
        MangaStyle.isActive ? 2.5 : 2
    }

    private var qualityBadgeCornerRadius: CGFloat {
        if MangaStyle.isActive { return 6 }
        if MujiStyle.isActive { return 5 }
        if NeumorphicStyle.isActive { return 6 }
        if SequoiaStyle.isActive { return 6 }
        return 4
    }

    private func qualityBadgeForeground(isLocked: Bool) -> Color {
        if isLocked { return .monologueTextSecondary.opacity(0.4) }
        if MangaStyle.isActive { return MangaStyle.ink }
        if MujiStyle.isActive { return MujiStyle.clay }
        if SequoiaStyle.isActive { return SequoiaStyle.onAccent }
        return NeumorphicStyle.isActive ? NeumorphicStyle.accent : .monologueIconForeground
    }

    @ViewBuilder
    private func qualityBadgeBackground(isLocked: Bool) -> some View {
        let tint = MangaStyle.isActive ? MangaStyle.labelYellow : (MujiStyle.isActive ? MujiStyle.clay : (NeumorphicStyle.isActive ? NeumorphicStyle.accent : (SequoiaStyle.isActive ? SequoiaStyle.accent : Color.monologueIconBackground)))
        if isLocked {
            RoundedRectangle(cornerRadius: qualityBadgeCornerRadius, style: .continuous)
                .fill(Color.monologueIconBackground.opacity(0.3))
        } else if NeumorphicStyle.isActive {
            NeumorphicSurfaceBackground(
                cornerRadius: qualityBadgeCornerRadius,
                elevated: false,
                pressed: true,
                tint: tint.opacity(colorScheme == .dark ? 0.18 : 0.13)
            )
        } else if SequoiaStyle.isActive {
            RoundedRectangle(cornerRadius: qualityBadgeCornerRadius, style: .continuous)
                .fill(tint.opacity(0.92))
        } else {
            RoundedRectangle(cornerRadius: qualityBadgeCornerRadius, style: .continuous)
                .fill(tint.opacity(MangaStyle.isActive ? 0.26 : (MujiStyle.isActive ? 0.10 : 1)))
        }
    }

    @ViewBuilder
    private func qualityBadgeStroke(isLocked: Bool) -> some View {
        let tint = MangaStyle.isActive ? MangaStyle.strokeInk : (MujiStyle.isActive ? MujiStyle.clay : (NeumorphicStyle.isActive ? NeumorphicStyle.accent : (SequoiaStyle.isActive ? SequoiaStyle.accent : Color.clear)))
        if MangaStyle.isActive {
            RoundedRectangle(cornerRadius: qualityBadgeCornerRadius, style: .continuous)
                .stroke(tint, lineWidth: MangaStyle.fineStrokeWidth)
        } else if MujiStyle.isActive || NeumorphicStyle.isActive || SequoiaStyle.isActive {
            RoundedRectangle(cornerRadius: qualityBadgeCornerRadius, style: .continuous)
                .stroke(tint.opacity(isLocked ? 0.12 : 0.28), lineWidth: 0.6)
        }
    }
}
