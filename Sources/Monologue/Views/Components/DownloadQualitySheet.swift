import SwiftUI

struct DownloadQualitySheet: View {
    let song: Song
    let onDownload: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.monologueSheetDismiss) private var monologueSheetDismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var downloadManager = DownloadManager.shared

    private var isQQ: Bool { song.isQQMusic }
    private var isQishui: Bool { song.isQishui }

    private let neteaseQualities: [SoundQuality] = SoundQuality.allCases.filter { $0 != .higher && $0 != .none }

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
                    .font(NeumorphicStyle.isActive ? NeumorphicStyle.titleFont(20, weight: .semibold) : .system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.ink : .monologueTextPrimary)

                Text(song.name)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.monologueTextSecondary)
                    .lineLimit(1)
            }

            Spacer()

            let source = song.source ?? (isQQ ? MusicSource.qqmusic : MusicSource.netease)
            PlatformBadgeLabel(text: source.displayName, source: source)

            Button(action: { dismissCurrentPresentation(systemDismiss: dismiss, monologueSheetDismiss: monologueSheetDismiss) }) {
                MonologueIcon(icon: .close, size: 14, color: .monologueTextSecondary)
                    .padding(10)
                    .background { closeButtonBackground }
            }
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.top, 8)
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
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.monologueTextSecondary)
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
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(isLocked ? .monologueTextSecondary.opacity(0.5) : .monologueTextPrimary)

                    if let badge {
                        Text(badge)
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(qualityBadgeForeground(isLocked: isLocked))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(qualityBadgeBackground(isLocked: isLocked))
                            .cornerRadius(4)
                    }

                    if isLocked {
                        Text("需要开启解密")
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundColor(.monologueTextSecondary.opacity(0.5))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed.opacity(0.78) : Color.monologueSeparator.opacity(0.5))
                            .cornerRadius(4)
                    }
                }

                Text(subtitle)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(isLocked ? .monologueTextSecondary.opacity(0.4) : .monologueTextSecondary)
            }

            Spacer()

            if !isLocked {
                MonologueIcon(icon: .playerDownload, size: 14, color: .monologueTextSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var qualityPanelCornerRadius: CGFloat {
        NeumorphicStyle.isActive ? 22 : 16
    }

    @ViewBuilder
    private var qualityPanelBackground: some View {
        if NeumorphicStyle.isActive {
            NeumorphicSurfaceBackground(cornerRadius: qualityPanelCornerRadius, elevated: false)
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
            NeumorphicSurfaceBackground(cornerRadius: 17, elevated: false, pressed: true)
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
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isLocked ? Color.monologueIconBackground.opacity(0.04) : Color.monologueIconBackground.opacity(0.08))
        }
    }

    private func qualityIconColor(isLocked: Bool) -> Color {
        if isLocked { return .monologueTextSecondary.opacity(0.4) }
        return NeumorphicStyle.isActive ? NeumorphicStyle.ink : .monologueTextPrimary
    }

    private func qualityBadgeForeground(isLocked: Bool) -> Color {
        if isLocked { return .monologueTextSecondary.opacity(0.4) }
        return NeumorphicStyle.isActive ? NeumorphicStyle.accent : .monologueIconForeground
    }

    private func qualityBadgeBackground(isLocked: Bool) -> Color {
        if isLocked { return Color.monologueIconBackground.opacity(0.3) }
        return NeumorphicStyle.isActive ? NeumorphicStyle.accent.opacity(colorScheme == .dark ? 0.18 : 0.13) : .monologueIconBackground
    }
}
