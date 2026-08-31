import Combine
import SwiftUI

extension PodcastView {
    // MARK: - DJ Banner 轮播

    var mangaPodcastHeader: some View {
        MangaPageHeader(
            eyebrow: "RADIO",
            title: String(localized: "tabbar_podcast"),
            subtitle: ""
        ) {
            NavigationLink(value: PodcastDestination.search) {
                MangaIconBadge(icon: .magnifyingGlass, size: 48, tint: MangaStyle.bubbleBlue)
            }
            .buttonStyle(.plain)
        }
    }

    var petWhitePodcastHeader: some View {
        PetWhitePageHeader(
            eyebrow: "PODCAST",
            title: String(localized: "tabbar_podcast")
        ) {
            NavigationLink(value: PodcastDestination.search) {
                PetWhiteClayPuck(shape: Circle(), tint: PetWhiteStyle.sky)
                    .frame(width: 44, height: 44)
                    .overlay(
                        PetWhitePackIcon(icon: .magnifyingGlass, size: 20, visualScale: 1.05, lineWidth: 1.7)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    var petWhitePodcastSummary: some View {
        HStack(spacing: 10) {
            petWhitePodcastMetric(value: "\(viewModel.personalizedRadios.count)", label: String(localized: "podcast_for_you"), tint: PetWhiteStyle.dogOrange, icon: .podcast)
            petWhitePodcastMetric(value: "\(viewModel.categories.count)", label: String(localized: "podcast_all"), tint: PetWhiteStyle.mint, icon: .gridSquare)
            petWhitePodcastMetric(value: "\(viewModel.broadcastChannels.count)", label: String(localized: "podcast_broadcast"), tint: PetWhiteStyle.sky, icon: .radio)
        }
        .padding(.horizontal, padH)
    }

    func petWhitePodcastMetric(value: String, label: String, tint: Color, icon: MonoIcon.IconType) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                PetWhiteClayPuck(shape: Circle(), tint: tint)
                    .frame(width: 26, height: 26)
                    .overlay(
                        PetWhitePackIcon(icon: icon, size: 13, visualScale: 1.02, lineWidth: 1.6)
                    )

                Text(value)
                    .font(PetWhiteStyle.titleFont(18, weight: .semibold))
                    .foregroundStyle(PetWhiteStyle.ink)
                    .lineLimit(1)
            }

            Text(label)
                .font(PetWhiteStyle.labelFont(10))
                .foregroundStyle(PetWhiteStyle.inkMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 11)
        .background(PetWhiteSurfaceBackground(cornerRadius: PetWhiteStyle.compactRadius, elevated: false, tint: PetWhiteStyle.surfaceRaised, accent: tint))
    }

    var mujiPodcastHeader: some View {
        MujiPageHeader(
            eyebrow: "radio archive",
            title: String(localized: "tabbar_podcast"),
            subtitle: ""
        ) {
            NavigationLink(value: PodcastDestination.search) {
                MujiIconBadge(icon: .search, tint: MujiStyle.indigo, size: 48)
            }
            .buttonStyle(.plain)
        }
    }

    /// Muji：电台数据带 —— 裸排统计签，无卡片
    var mujiPodcastSummary: some View {
        HStack(alignment: .top, spacing: 22) {
            MujiMetricTile(value: "\(viewModel.personalizedRadios.count)", label: String(localized: "podcast_for_you"), tint: MujiStyle.ink)
            MujiMetricTile(value: "\(viewModel.categories.count)", label: String(localized: "podcast_all"), tint: MujiStyle.ink)
            MujiMetricTile(value: "\(viewModel.broadcastChannels.count)", label: String(localized: "podcast_broadcast"), tint: MujiStyle.clay)
        }
        .padding(.horizontal, padH + 8)
    }

    var neumorphicPodcastHeader: some View {
        NeumorphicPageHeader(
            eyebrow: "RADIO",
            title: String(localized: "tabbar_podcast"),
            subtitle: ""
        ) {
            NavigationLink(value: PodcastDestination.search) {
                NeumorphicIconBadge(icon: .magnifyingGlass, tint: NeumorphicStyle.accent, size: 48)
            }
            .buttonStyle(.plain)
        }
    }

    var neumorphicPodcastSummary: some View {
        HStack(spacing: 10) {
            NeumorphicPill(text: "\(viewModel.personalizedRadios.count)", tint: NeumorphicStyle.accent, icon: .podcast, selected: true)
            NeumorphicPill(text: "\(viewModel.categories.count)", tint: NeumorphicStyle.sage, icon: .gridSquare, selected: true)
            NeumorphicPill(text: "\(viewModel.broadcastChannels.count)", tint: NeumorphicStyle.warm, icon: .radio, selected: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(NeumorphicSurfaceBackground(cornerRadius: 20, elevated: true))
        .padding(.horizontal, padH)
    }

    var signalPodcastHeader: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                SignalBreathingIndicator(size: 8)

                Text(String(localized: "tabbar_podcast"))
                    .font(SignalStyle.titleFont(27, weight: .semibold))
                    .foregroundStyle(SignalStyle.ink)
                    .lineLimit(1)

                Spacer(minLength: 10)

                NavigationLink(value: PodcastDestination.categoryBrowse) {
                    MonoIcon(icon: .gridSquare, size: 17, color: SignalStyle.inkSoft, lineWidth: 1.6)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(MonoBouncingButtonStyle(scale: 0.94))

                NavigationLink(value: PodcastDestination.search) {
                    MonoIcon(icon: .magnifyingGlass, size: 17, color: SignalStyle.accent, lineWidth: 1.7)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(MonoBouncingButtonStyle(scale: 0.94))
            }

            HStack(spacing: 12) {
                SignalLevelMeter(
                    activeCount: min(max(viewModel.personalizedRadios.count / 2, 2), 9),
                    barCount: 9,
                    height: 20
                )

                Spacer(minLength: 8)

                signalPodcastMetric(
                    value: "\(viewModel.personalizedRadios.count)",
                    label: String(localized: "podcast_for_you")
                )

                signalPodcastMetric(
                    value: "\(viewModel.categories.count)",
                    label: String(localized: "podcast_all")
                )
            }
            .padding(.vertical, 12)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(SignalStyle.separator.opacity(0.84))
                    .frame(height: 0.65)
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(SignalStyle.separator.opacity(0.52))
                    .frame(height: 0.65)
            }
        }
        .padding(.horizontal, padH)
        .padding(.top, DeviceLayout.headerTopPadding + 4)
        .monoPageHeaderCollapse()
    }

    func signalPodcastMetric(value: String, label: String) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(value)
                .font(SignalStyle.monoFont(12, weight: .bold))
                .foregroundStyle(SignalStyle.ink)
                .monospacedDigit()

            Text(label)
                .font(SignalStyle.labelFont(9, weight: .medium))
                .foregroundStyle(SignalStyle.inkMuted)
                .lineLimit(1)
        }
    }

    var sequoiaPodcastHeader: some View {
        SequoiaPageHeader(
            eyebrow: "RADIO",
            title: String(localized: "tabbar_podcast"),
            subtitle: ""
        ) {
            NavigationLink(value: PodcastDestination.search) {
                SequoiaControlButton(icon: .magnifyingGlass, tint: SequoiaStyle.accent, size: 44, selected: true)
            }
            .buttonStyle(.plain)
        }
    }

    var sequoiaPodcastSummary: some View {
        HStack(spacing: 8) {
            SequoiaPill(text: "\(viewModel.personalizedRadios.count)", icon: .podcast, tint: SequoiaStyle.accent, selected: true, compact: true)
            SequoiaPill(text: "\(viewModel.categories.count)", icon: .gridSquare, tint: SequoiaStyle.aqua, selected: true, compact: true)
            SequoiaPill(text: "\(viewModel.broadcastChannels.count)", icon: .radio, tint: SequoiaStyle.violet, selected: true, compact: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, padH)
    }

    var liquidGlassPodcastHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            LiquidGlassDropletMark(tint: LiquidGlassStyle.violet)

            VStack(alignment: .leading, spacing: 4) {
                Text("PODCAST")
                    .font(LiquidGlassStyle.labelFont(10, weight: .semibold))
                    .foregroundStyle(LiquidGlassStyle.inkMuted)
                    .tracking(1.4)

                Text(String(localized: "tabbar_podcast"))
                    .font(LiquidGlassStyle.titleFont(27, weight: .semibold))
                    .foregroundStyle(LiquidGlassStyle.ink)
            }

            Spacer(minLength: 0)

            NavigationLink(value: PodcastDestination.search) {
                LiquidGlassControlButton(icon: .magnifyingGlass, tint: LiquidGlassStyle.violet, size: 44, selected: true)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, padH)
        .padding(.top, DeviceLayout.headerTopPadding + 8)
    }

    var liquidGlassPodcastConstellation: some View {
        HStack(spacing: 10) {
            liquidGlassPodcastMetric(
                icon: .podcast,
                value: "\(viewModel.personalizedRadios.count)",
                label: String(localized: "podcast_for_you"),
                tint: LiquidGlassStyle.violet
            )
            liquidGlassPodcastMetric(
                icon: .gridSquare,
                value: "\(viewModel.categories.count)",
                label: String(localized: "podcast_all"),
                tint: LiquidGlassStyle.cyan
            )
            liquidGlassPodcastMetric(
                icon: .radio,
                value: "\(viewModel.broadcastChannels.count)",
                label: String(localized: "podcast_broadcast"),
                tint: LiquidGlassStyle.mint
            )
        }
        .padding(12)
        .background(LiquidGlassPrismBand(tint: LiquidGlassStyle.violet, cornerRadius: 28))
        .padding(.horizontal, padH)
    }

    func liquidGlassPodcastMetric(
        icon: MonoIcon.IconType,
        value: String,
        label: String,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                MonoIcon(icon: icon, size: 15, color: tint, lineWidth: 1.6)

                Text(value)
                    .font(LiquidGlassStyle.titleFont(19, weight: .semibold))
                    .foregroundStyle(LiquidGlassStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Text(label)
                .font(LiquidGlassStyle.labelFont(10.5, weight: .medium))
                .foregroundStyle(LiquidGlassStyle.inkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 11)
        .background(LiquidGlassSurfaceBackground(cornerRadius: 20, elevated: false, pressed: true, role: .list))
    }

    @ViewBuilder
    func podcastSectionHeader(
        title: String,
        detail: String? = nil,
        destination: PodcastDestination? = nil
    ) -> some View {
        if MinimalWhiteStyle.isActive {
            MinimalWhiteSectionTitle(title: title) {
                if let destination {
                    NavigationLink(value: destination) {
                        MinimalWhiteDisclosureGlyph()
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, padH)
        } else if MangaStyle.isActive {
            HStack(alignment: .center, spacing: 12) {
                MangaSectionMark(kind: .star, tint: MangaStyle.labelYellow)

                Text(title)
                    .font(MangaStyle.titleFont(18, weight: .black))
                    .foregroundStyle(MangaStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer(minLength: 0)

                if let destination {
                    NavigationLink(value: destination) {
                        MangaLabel(text: String(localized: "view_all"), tint: MangaStyle.decoBlue, small: true)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, padH)
        } else if PetWhiteStyle.isActive {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(PetWhiteStyle.titleFont(20, weight: .bold))
                        .foregroundStyle(PetWhiteStyle.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    if let detail, !detail.isEmpty {
                        Text(detail)
                            .font(PetWhiteStyle.labelFont(11))
                            .foregroundStyle(PetWhiteStyle.inkMuted)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                if let destination {
                    NavigationLink(value: destination) {
                        HStack(spacing: 3) {
                            Text(String(localized: "view_all"))
                                .font(PetWhiteStyle.labelFont(12, weight: .semibold))
                            PetWhitePackIcon(icon: .chevronRight, size: 12, visualScale: 1, fallbackColor: PetWhiteStyle.dogEar)
                        }
                        .foregroundStyle(PetWhiteStyle.dogEar)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, padH)
        } else if MujiStyle.isActive {
            HStack(alignment: .bottom, spacing: 14) {
                MujiSectionTitle(title: title, detail: detail)

                Spacer(minLength: 0)

                if let destination {
                    NavigationLink(value: destination) {
                        MujiPill(text: String(localized: "view_all"), tint: MujiStyle.tea)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, padH)
        } else if NeumorphicStyle.isActive {
            HStack(alignment: .center, spacing: 12) {
                NeumorphicIconBadge(icon: .podcast, tint: NeumorphicStyle.warm, size: 34)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(NeumorphicStyle.titleFont(18, weight: .semibold))
                        .foregroundStyle(NeumorphicStyle.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    if let detail, !detail.isEmpty {
                        Text(detail)
                            .font(NeumorphicStyle.labelFont(11, weight: .medium))
                            .foregroundStyle(NeumorphicStyle.inkMuted)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                if let destination {
                    NavigationLink(value: destination) {
                        NeumorphicPill(text: String(localized: "view_all"), tint: NeumorphicStyle.accent, icon: .chevronRight, selected: true, compact: true)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, padH)
        } else if SignalStyle.isActive {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(SignalStyle.titleFont(18, weight: .semibold))
                        .foregroundStyle(SignalStyle.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    if let detail, !detail.isEmpty {
                        Text(detail)
                            .font(SignalStyle.labelFont(11, weight: .medium))
                            .foregroundStyle(SignalStyle.inkMuted)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                if let destination {
                    NavigationLink(value: destination) {
                        SignalPill(
                            text: String(localized: "view_all"),
                            tint: SignalStyle.accent,
                            icon: .chevronRight,
                            compact: true
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, padH)
        } else if SequoiaStyle.isActive {
            HStack(alignment: .center, spacing: 10) {
                SequoiaIconBadge(icon: .podcast, tint: SequoiaStyle.aqua, size: 32)

                Text(title)
                    .font(SequoiaStyle.titleFont(17, weight: .semibold))
                    .foregroundStyle(SequoiaStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .layoutPriority(1)

                Spacer(minLength: 8)

                if let destination {
                    NavigationLink(value: destination) {
                        SequoiaPill(
                            text: String(localized: "view_all"),
                            icon: .chevronRight,
                            tint: SequoiaStyle.accent,
                            selected: true,
                            compact: true
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, padH)
        } else if LiquidGlassStyle.isActive {
            HStack(alignment: .center, spacing: 10) {
                LiquidGlassDropletMark(tint: LiquidGlassStyle.violet)
                    .frame(width: 22, height: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(LiquidGlassStyle.titleFont(18, weight: .semibold))
                        .foregroundStyle(LiquidGlassStyle.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    if let detail, !detail.isEmpty {
                        Text(detail)
                            .font(LiquidGlassStyle.labelFont(11, weight: .regular))
                            .foregroundStyle(LiquidGlassStyle.inkMuted)
                            .lineLimit(1)
                    }
                }
                .layoutPriority(1)

                Spacer(minLength: 8)

                if let destination {
                    NavigationLink(value: destination) {
                        LiquidGlassPill(
                            text: String(localized: "view_all"),
                            icon: .chevronRight,
                            tint: LiquidGlassStyle.violet,
                            selected: true,
                            compact: true
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, padH)
        } else {
            HStack(alignment: .center, spacing: 8) {
                Capsule()
                    .fill(Color.monoAccent)
                    .frame(width: 3, height: 13)

                Text(title)
                    .font(.rounded(size: 15.5, weight: .bold))
                    .foregroundColor(.monoTextPrimary)
                    .lineLimit(1)
                    .fixedSize()

                Rectangle()
                    .fill(Color.monoSeparator.opacity(0.5))
                    .frame(height: 0.5)

                if let destination {
                    NavigationLink(value: destination) {
                        HStack(spacing: 3) {
                            Text("mv_more_section")
                                .font(.rounded(size: 12, weight: .semibold))
                            MonoIcon(icon: .chevronRight, size: 10, color: .monoTextSecondary.opacity(0.8), lineWidth: 1.7)
                        }
                        .foregroundColor(.monoTextSecondary.opacity(0.85))
                        .fixedSize()
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, padH)
        }
    }

    var bannerSection: some View {
        HomeBannerSection(
            banners: viewModel.djBanners,
            onTap: handleBannerTap
        )
    }

    /// 处理 DJ Banner 点击 — 根据 targetType 跳转
    func handleBannerTap(_ banner: Banner) {
        HapticStyle.light.trigger()
        switch banner.targetType {
        case 1:
            Task {
                do {
                    let songs = try await APIService.shared.fetchSongDetails(ids: [banner.targetId]).async()
                    if let song = songs.first {
                        await MainActor.run {
                            PlayerManager.shared.play(song: song, in: [song])
                        }
                    }
                } catch {
                    AppLogger.error("Banner 歌曲加载失败: \(error)")
                }
            }
        case 60001:
            // DJ 节目 — 通过节目详情获取所属电台 ID
            Task {
                do {
                    let response = try await APIService.shared.ncm.djProgramDetail(id: banner.targetId)
                    if let program = response.body["program"] as? [String: Any],
                       let radio = program["radio"] as? [String: Any],
                       let rid = radio["id"] as? Int
                    {
                        await MainActor.run {
                            radioIdToOpen = rid
                        }
                    }
                } catch {
                    AppLogger.error("Banner 节目详情加载失败: \(error)")
                }
            }
        default:
            if banner.targetId > 0 {
                radioIdToOpen = banner.targetId
            } else if let urlStr = banner.url, let url = URL(string: urlStr) {
                bannerWebURL = url
            }
        }
    }

}
