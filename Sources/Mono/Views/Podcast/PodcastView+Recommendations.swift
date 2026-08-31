import Combine
import SwiftUI

extension PodcastView {
    // MARK: - 为你推荐（自适应网格）

    var personalizedSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            podcastSectionHeader(
                title: String(localized: "podcast_for_you"),
                destination: PodcastDestination.topList(String(localized: "podcast_hot_radios"), .hot)
            )

            let columns: [GridItem] = DeviceLayout.isPad
                ? Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)
                : [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

            LazyVGrid(columns: columns, spacing: DeviceLayout.isPad ? 16 : 14) {
                ForEach(viewModel.personalizedRadios) { radio in
                    Button {
                        HapticStyle.light.trigger()
                        radioIdToOpen = radio.id
                    } label: {
                        radioGridCard(radio: radio)
                    }
                    .buttonStyle(MonoBouncingButtonStyle())
                }
            }
            .padding(.horizontal, padH)
        }
    }

    // MARK: - 今日优选

    var todayPerferedSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            podcastSectionHeader(
                title: String(localized: "podcast_today_pick"),
                destination: PodcastDestination.topList(String(localized: "podcast_today_pick"), .hot)
            )

            ScrollView(.horizontal) {
                LazyHStack(spacing: 14) {
                    ForEach(viewModel.todayPerfered) { radio in
                        Button {
                            HapticStyle.light.trigger()
                            radioIdToOpen = radio.id
                        } label: {
                            todayPickCard(radio: radio)
                        }
                        .buttonStyle(MonoBouncingButtonStyle())
                        .compatScrollTransition(animation: .spring(response: 0.35)) { content, phase in
                            content
                                .scaleEffect(phase.isIdentity ? 1 : 0.93)
                                .opacity(phase.isIdentity ? 1 : 0.5)
                                .offset(y: phase.isIdentity ? 0 : phase.value * 8)
                        }
                    }
                }
                .compatScrollTargetLayout()
                .padding(.horizontal, padH)
            }
            .compatViewAlignedScrollBehavior(limitNever: true)
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
    }

    func todayPickCard(radio: RadioStation) -> AnyView {
        if PetWhiteStyle.isActive {
            return AnyView(petWhiteTodayPickCard(radio: radio))
        }
        if SignalStyle.isActive {
            return AnyView(signalTodayPickCard(radio: radio))
        }
        if isAside {
            return AnyView(asideTodayPickCard(radio: radio))
        }

        let cardWidth: CGFloat = DeviceLayout.isPad ? 340 : 280
        let cardHeight: CGFloat = DeviceLayout.isPad ? 110 : 96
        let cr: CGFloat = MangaStyle.isActive ? MangaStyle.cardRadius : (MujiStyle.isActive ? 10 : ((NeumorphicStyle.isActive || SequoiaStyle.isActive) ? 18 : (DeviceLayout.isPad ? 18 : 16)))
        let titleFont: Font
        if MangaStyle.isActive {
            titleFont = MangaStyle.bodyFont(15, weight: .black)
        } else if MujiStyle.isActive {
            titleFont = MujiStyle.bodyFont(15, weight: .regular)
        } else if NeumorphicStyle.isActive {
            titleFont = NeumorphicStyle.bodyFont(15, weight: .semibold)
        } else if SequoiaStyle.isActive {
            titleFont = SequoiaStyle.bodyFont(15, weight: .semibold)
        } else {
            titleFont = .system(size: 15, weight: .semibold, design: .rounded)
        }

        let subtitleFont: Font
        if MangaStyle.isActive {
            subtitleFont = MangaStyle.bodyFont(12, weight: .bold)
        } else if MujiStyle.isActive {
            subtitleFont = MujiStyle.labelFont(12, weight: .regular)
        } else if NeumorphicStyle.isActive {
            subtitleFont = NeumorphicStyle.labelFont(12, weight: .medium)
        } else if SequoiaStyle.isActive {
            subtitleFont = SequoiaStyle.labelFont(12, weight: .regular)
        } else {
            subtitleFont = .system(size: 12, design: .rounded)
        }

        let metadataFont: Font = SequoiaStyle.isActive
            ? SequoiaStyle.labelFont(11, weight: .regular)
            : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(11, weight: .medium) : .system(size: 11, design: .rounded))
        let primaryColor: Color = SequoiaStyle.isActive ? SequoiaStyle.ink : (NeumorphicStyle.isActive ? NeumorphicStyle.ink : .monoTextPrimary)
        let secondaryColor: Color = SequoiaStyle.isActive ? SequoiaStyle.inkSoft : (NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : .monoTextSecondary)
        let placeholderFill: Color = SequoiaStyle.isActive ? SequoiaStyle.materialList : (NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.monoGlassTint)
        let playForeground: Color = (NeumorphicStyle.isActive || SequoiaStyle.isActive) ? (SequoiaStyle.isActive ? SequoiaStyle.onAccent : Color(light: .white, dark: .black)) : .monoIconForeground
        let playBackground: Color = SequoiaStyle.isActive ? SequoiaStyle.accent : (NeumorphicStyle.isActive ? NeumorphicStyle.accent : Color.monoIconBackground)
        let cardFill: Color = SequoiaStyle.isActive ? .clear : (NeumorphicStyle.isActive ? NeumorphicStyle.surface : Color.monoGlassTint)

        return AnyView(HStack(spacing: 0) {
            CachedAsyncImage(url: radio.coverUrl) {
                RoundedRectangle(cornerRadius: 0)
                    .fill(placeholderFill)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: cardHeight, height: cardHeight)
            .clipped()

            VStack(alignment: .leading, spacing: 6) {
                Text(radio.name)
                    .font(titleFont)
                    .foregroundColor(primaryColor)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if let dj = radio.dj?.nickname {
                    Text(dj)
                        .font(subtitleFont)
                        .foregroundColor(secondaryColor)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                HStack(spacing: 6) {
                    if let count = radio.programCount, count > 0 {
                        Text(String(format: String(localized: "podcast_episode_count"), count))
                            .font(metadataFont)
                            .foregroundColor(secondaryColor)
                    }
                    Spacer()
                    MonoIcon(icon: .play, size: 12, color: playForeground, lineWidth: 2)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(playBackground))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: cardWidth, height: cardHeight)
        .background(cardFill)
        .clipShape(RoundedRectangle(cornerRadius: cr, style: .continuous))
        .themedPageSurface(cornerRadius: cr, elevated: false))
    }

    func signalTodayPickCard(radio: RadioStation) -> some View {
        let cardWidth: CGFloat = DeviceLayout.isPad ? 340 : 286
        let cardHeight: CGFloat = DeviceLayout.isPad ? 112 : 98

        return HStack(spacing: 12) {
            CachedAsyncImage(url: radio.coverUrl) {
                SignalStyle.controlPressed
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: cardHeight - 16, height: cardHeight - 16)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(radio.name)
                    .font(SignalStyle.bodyFont(15, weight: .semibold))
                    .foregroundStyle(SignalStyle.ink)
                    .lineLimit(2)

                Text(radio.dj?.nickname ?? radio.category ?? " ")
                    .font(SignalStyle.labelFont(11, weight: .medium))
                    .foregroundStyle(SignalStyle.inkSoft)
                    .lineLimit(1)

                Spacer(minLength: 0)

                HStack(spacing: 7) {
                    SignalLevelMeter(activeCount: 4, barCount: 7, tint: SignalStyle.inkSoft, height: 14)
                    Spacer(minLength: 0)
                    MonoIcon(icon: .play, size: 11, color: SignalStyle.onAccent, lineWidth: 1.9)
                        .frame(width: 30, height: 30)
                        .background(SignalStyle.accent, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
            }
            .padding(.vertical, 1)
        }
        .frame(width: cardWidth, height: cardHeight, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(SignalStyle.separator.opacity(0.55))
                .frame(height: 0.65)
        }
    }

    /// aside 今日优选卡：发丝描边横卡
    func asideTodayPickCard(radio: RadioStation) -> some View {
        let cardWidth: CGFloat = DeviceLayout.isPad ? 340 : 280
        let coverSide: CGFloat = DeviceLayout.isPad ? 80 : 70

        return HStack(spacing: 13) {
            CachedAsyncImage(url: radio.coverUrl) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.monoSeparator.opacity(0.35))
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: coverSide, height: coverSide)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.monoTextPrimary.opacity(0.08), lineWidth: 0.8)
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(radio.name)
                    .font(.rounded(size: 14.5, weight: .semibold))
                    .foregroundColor(.monoTextPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 6) {
                    if let dj = radio.dj?.nickname {
                        Text(dj)
                            .font(.rounded(size: 11.5, weight: .medium))
                            .foregroundColor(.monoTextSecondary)
                            .lineLimit(1)
                    }

                    if let count = radio.programCount, count > 0 {
                        Circle()
                            .fill(Color.monoTextSecondary.opacity(0.45))
                            .frame(width: 2.5, height: 2.5)

                        Text(String(format: String(localized: "podcast_episode_count"), count))
                            .font(.rounded(size: 11, weight: .medium))
                            .foregroundColor(.monoTextSecondary.opacity(0.85))
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 0)

            MonoIcon(icon: .play, size: 11, color: .monoTextPrimary, lineWidth: 1.9)
                .frame(width: 30, height: 30)
                .overlay(Circle().stroke(Color.monoTextPrimary.opacity(0.28), lineWidth: 0.9))
        }
        .padding(12)
        .frame(width: cardWidth)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.monoSeparator.opacity(0.85), lineWidth: 0.8)
        )
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    func petWhiteTodayPickCard(radio: RadioStation) -> some View {
        HStack(spacing: 12) {
            CachedAsyncImage(url: radio.coverUrl) {
                PetWhiteMascotMark(kind: .dog, size: 52)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(PetWhiteStyle.surfacePressed)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: DeviceLayout.isPad ? 92 : 82, height: DeviceLayout.isPad ? 92 : 82)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(PetWhiteStyle.stroke, lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 6) {
                PetWhitePill(text: "PICK", tint: PetWhiteStyle.butter)

                Text(radio.name)
                    .font(PetWhiteStyle.titleFont(16, weight: .black))
                    .foregroundStyle(PetWhiteStyle.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(radio.dj?.nickname ?? radio.category ?? " ")
                    .font(PetWhiteStyle.labelFont(11, weight: .semibold))
                    .foregroundStyle(PetWhiteStyle.inkSoft)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            PetWhitePackIcon(icon: .play, size: 18, visualScale: 1.08)
                .frame(width: 34, height: 34)
                .background(PetWhiteStyle.dogOrange, in: Circle())
                .overlay(Circle().stroke(PetWhiteStyle.stroke, lineWidth: 1))
        }
        .padding(12)
        .frame(width: DeviceLayout.isPad ? 348 : 292, height: DeviceLayout.isPad ? 116 : 106)
        .background(PetWhiteSurfaceBackground(cornerRadius: PetWhiteStyle.cardRadius, elevated: true, tint: PetWhiteStyle.surfaceRaised, accent: PetWhiteStyle.butter))
    }

    // MARK: - 精选电台（列表）

    var recommendSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            podcastSectionHeader(
                title: String(localized: "podcast_featured"),
                destination: PodcastDestination.topList(String(localized: "podcast_featured"), .toplist)
            )

            VStack(spacing: 0) {
                ForEach(Array(viewModel.recommendRadios.enumerated()), id: \.element.id) { index, radio in
                    Button {
                        HapticStyle.light.trigger()
                        radioIdToOpen = radio.id
                    } label: {
                        radioListRow(radio: radio)
                    }
                    .buttonStyle(MonoBouncingButtonStyle(scale: 0.98))

                    if index < viewModel.recommendRadios.count - 1 {
                        Divider()
                            .foregroundColor(.monoSeparator)
                            .padding(.leading, padH + (DeviceLayout.isPad ? 86 : 76))
                            .padding(.trailing, padH)
                    }
                }
            }
        }
    }

    // MARK: - 上新佳作

    var newestSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            podcastSectionHeader(title: String(localized: "podcast_latest_voices"))

            ScrollView(.horizontal) {
                LazyHStack(spacing: 14) {
                    ForEach(Array(viewModel.newestPrograms.enumerated()), id: \.offset) { _, program in
                        Button {
                            HapticStyle.light.trigger()
                            if let radioId = program.creativeExtInfoVO?.djProgram?.radio?.id {
                                radioIdToOpen = radioId
                            } else if let radioId = program.creativeExtInfoVO?.radio?.id {
                                radioIdToOpen = radioId
                            }
                        } label: {
                            creativeCompactCard(creative: program)
                        }
                        .buttonStyle(MonoBouncingButtonStyle())
                        .compatScrollTransition(animation: .spring(response: 0.35)) { content, phase in
                            content
                                .scaleEffect(phase.isIdentity ? 1 : 0.93)
                                .opacity(phase.isIdentity ? 1 : 0.8)
                        }
                    }
                }
                .padding(.horizontal, padH)
            }
            .themeRenderScrollLayer()
            .compatViewAlignedScrollBehavior()
            .compatScrollClipDisabled()
        }
    }

    // MARK: - 音乐播客榜

    var chartSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            podcastSectionHeader(title: String(localized: "podcast_music_chart"))

            ScrollView(.horizontal) {
                LazyHStack(spacing: 14) {
                    ForEach(Array(viewModel.chartPrograms.enumerated()), id: \.offset) { index, program in
                        Button {
                            HapticStyle.light.trigger()
                            if let radioId = program.creativeExtInfoVO?.djProgram?.radio?.id {
                                radioIdToOpen = radioId
                            } else if let radioId = program.creativeExtInfoVO?.radio?.id {
                                radioIdToOpen = radioId
                            }
                        } label: {
                            creativeCompactCard(creative: program, rank: index + 1)
                        }
                        .buttonStyle(MonoBouncingButtonStyle())
                        .compatScrollTransition(animation: .spring(response: 0.35)) { content, phase in
                            content
                                .scaleEffect(phase.isIdentity ? 1 : 0.93)
                                .opacity(phase.isIdentity ? 1 : 0.8)
                        }
                    }
                }
                .padding(.horizontal, padH)
            }
            .themeRenderScrollLayer()
            .compatViewAlignedScrollBehavior()
            .compatScrollClipDisabled()
        }
    }

    func creativeCompactCard(creative: PodcastCreative, rank: Int? = nil) -> AnyView {
        if PetWhiteStyle.isActive {
            return AnyView(petWhiteCreativeCompactCard(creative: creative, rank: rank))
        }
        if SignalStyle.isActive {
            let title = creative.uiElement?.mainTitle?.title ?? creative.creativeExtInfoVO?.djProgram?.name ?? "(无标题)"
            let subtitle = creative.creativeExtInfoVO?.djProgram?.radio?.name ?? creative.creativeExtInfoVO?.djProgram?.dj?.nickname ?? " "
            var coverURL: URL?
            if let url = creative.uiElement?.image?.imageUrl {
                coverURL = URL(string: url)
            } else if let url = creative.creativeExtInfoVO?.djProgram?.coverUrl {
                coverURL = URL(string: url)
            } else {
                coverURL = creative.creativeExtInfoVO?.djProgram?.mainSong?.coverUrl
            }
            return AnyView(
                signalCompactCard(
                    coverURL: coverURL,
                    title: title,
                    subtitle: subtitle,
                    rank: rank
                )
            )
        }
        if isAside {
            let title = creative.uiElement?.mainTitle?.title ?? creative.creativeExtInfoVO?.djProgram?.name ?? "(无标题)"
            let subTitle = creative.creativeExtInfoVO?.djProgram?.radio?.name ?? creative.creativeExtInfoVO?.djProgram?.dj?.nickname ?? " "
            var coverUrl: URL? = nil
            if let urlStr = creative.uiElement?.image?.imageUrl {
                coverUrl = URL(string: urlStr)
            } else if let urlStr = creative.creativeExtInfoVO?.djProgram?.coverUrl {
                coverUrl = URL(string: urlStr)
            } else if let urlStr = creative.creativeExtInfoVO?.djProgram?.mainSong?.coverUrl?.absoluteString {
                coverUrl = URL(string: urlStr)
            }
            return AnyView(asideCompactCard(coverUrl: coverUrl, title: title, subtitle: subTitle, rank: rank))
        }

        let s = compactCardSize
        let cr: CGFloat = MangaStyle.isActive ? MangaStyle.cardRadius : (MujiStyle.isActive ? 8 : ((NeumorphicStyle.isActive || SequoiaStyle.isActive) ? 16 : (DeviceLayout.isPad ? 18 : 16)))

        let title = creative.uiElement?.mainTitle?.title ?? creative.creativeExtInfoVO?.djProgram?.name ?? "(无标题)"
        let subTitle = creative.creativeExtInfoVO?.djProgram?.radio?.name ?? creative.creativeExtInfoVO?.djProgram?.dj?.nickname ?? " "
        var coverUrl: URL? = nil
        if let urlStr = creative.uiElement?.image?.imageUrl {
            coverUrl = URL(string: urlStr)
        } else if let urlStr = creative.creativeExtInfoVO?.djProgram?.coverUrl {
            coverUrl = URL(string: urlStr)
        } else if let urlStr = creative.creativeExtInfoVO?.djProgram?.mainSong?.coverUrl?.absoluteString {
            coverUrl = URL(string: urlStr)
        }

        let placeholderFill: Color = SequoiaStyle.isActive ? SequoiaStyle.materialList : (NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.monoGlassTint)
        let titleFont: Font
        if MangaStyle.isActive {
            titleFont = MangaStyle.bodyFont(DeviceLayout.isPad ? 14 : 13, weight: .black)
        } else if MujiStyle.isActive {
            titleFont = MujiStyle.bodyFont(DeviceLayout.isPad ? 14 : 13, weight: .regular)
        } else if NeumorphicStyle.isActive {
            titleFont = NeumorphicStyle.bodyFont(DeviceLayout.isPad ? 14 : 13, weight: .semibold)
        } else if SequoiaStyle.isActive {
            titleFont = SequoiaStyle.bodyFont(DeviceLayout.isPad ? 14 : 13, weight: .semibold)
        } else {
            titleFont = .system(size: DeviceLayout.isPad ? 14 : 13, weight: .medium, design: .rounded)
        }
        let subtitleFont: Font
        if MangaStyle.isActive {
            subtitleFont = MangaStyle.bodyFont(DeviceLayout.isPad ? 12 : 11, weight: .bold)
        } else if MujiStyle.isActive {
            subtitleFont = MujiStyle.labelFont(DeviceLayout.isPad ? 12 : 11, weight: .regular)
        } else if NeumorphicStyle.isActive {
            subtitleFont = NeumorphicStyle.labelFont(DeviceLayout.isPad ? 12 : 11, weight: .medium)
        } else if SequoiaStyle.isActive {
            subtitleFont = SequoiaStyle.labelFont(DeviceLayout.isPad ? 12 : 11, weight: .regular)
        } else {
            subtitleFont = .system(size: DeviceLayout.isPad ? 12 : 11, design: .rounded)
        }
        let titleColor: Color = SequoiaStyle.isActive ? SequoiaStyle.ink : (NeumorphicStyle.isActive ? NeumorphicStyle.ink : .monoTextPrimary)
        let subtitleColor: Color = SequoiaStyle.isActive ? SequoiaStyle.inkSoft : (NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : .monoTextSecondary)
        let isRankTop = (rank ?? 4) <= 3
        let rankForeground: Color = SequoiaStyle.isActive
            ? (isRankTop ? SequoiaStyle.onAccent : SequoiaStyle.ink)
            : (isRankTop ? .monoIconForeground : .monoTextPrimary)
        let rankBackground: Color = SequoiaStyle.isActive
            ? (isRankTop ? SequoiaStyle.accent : SequoiaStyle.materialList)
            : (isRankTop ? Color.monoIconBackground : Color.monoGlassTint)

        return AnyView(VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                CachedAsyncImage(url: coverUrl) {
                    RoundedRectangle(cornerRadius: cr)
                        .fill(placeholderFill)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: s, height: s)
                .clipShape(RoundedRectangle(cornerRadius: cr, style: .continuous))

                if let rank = rank {
                    Text("\(rank)")
                        .font(SequoiaStyle.isActive ? SequoiaStyle.labelFont(12, weight: .semibold) : .system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundColor(rankForeground)
                        .frame(width: 26, height: 26)
                        .background(
                            Circle().fill(NeumorphicStyle.isActive ? (rank <= 3 ? NeumorphicStyle.accent : NeumorphicStyle.surfacePressed) : rankBackground)
                        )
                        .monoGlassCircle()
                        .padding(8)
                }
            }

            Text(title)
                .font(titleFont)
                .foregroundColor(titleColor)
                .lineLimit(2)
                .frame(width: s, height: 34, alignment: .topLeading)

            Text(subTitle)
                .font(subtitleFont)
                .foregroundColor(subtitleColor)
                .lineLimit(1)
                .frame(width: s, alignment: .leading)
        }
        .frame(width: s)
        .padding(ThemedPageStyle.isActive && !MujiStyle.isActive && !MangaStyle.isActive ? 8 : 0)
        .background {
            if MangaStyle.isActive {
                // 去卡片化：播客小格直接排在纸上
                EmptyView()
            } else if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(cornerRadius: 18, elevated: true)
            } else if SequoiaStyle.isActive {
                SequoiaSurfaceBackground(cornerRadius: 18, elevated: false, role: .list)
            }
        })
    }

    /// aside 竖版小卡：封面发丝描边 + 期刊式排名角标
    func asideCompactCard(coverUrl: URL?, title: String, subtitle: String, rank: Int?) -> some View {
        let s = compactCardSize

        return VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                CachedAsyncImage(url: coverUrl) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.monoSeparator.opacity(0.35))
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: s, height: s)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.monoTextPrimary.opacity(0.08), lineWidth: 0.8)
                )

                if let rank {
                    Text(String(format: "%02d", rank))
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .tracking(0.6)
                        .monospacedDigit()
                        .foregroundColor(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .background(
                            Capsule().fill(rank <= 3 ? Color.monoAccent.opacity(0.92) : Color.black.opacity(0.38))
                        )
                        .padding(7)
                }
            }

            Text(title)
                .font(.rounded(size: 13, weight: .semibold))
                .foregroundColor(.monoTextPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(width: s, height: 34, alignment: .topLeading)
                .padding(.top, 8)

            Text(subtitle)
                .font(.rounded(size: 11, weight: .medium))
                .foregroundColor(.monoTextSecondary.opacity(0.85))
                .lineLimit(1)
                .frame(width: s, alignment: .leading)
                .padding(.top, 3)
        }
        .frame(width: s)
    }

    func petWhiteCreativeCompactCard(creative: PodcastCreative, rank: Int? = nil) -> some View {
        let s = compactCardSize
        let title = creative.uiElement?.mainTitle?.title ?? creative.creativeExtInfoVO?.djProgram?.name ?? "Paw Pick"
        let subTitle = creative.creativeExtInfoVO?.djProgram?.radio?.name ?? creative.creativeExtInfoVO?.djProgram?.dj?.nickname ?? " "
        let coverUrl: URL? = {
            if let urlStr = creative.uiElement?.image?.imageUrl {
                return URL(string: urlStr)
            }
            if let urlStr = creative.creativeExtInfoVO?.djProgram?.coverUrl {
                return URL(string: urlStr)
            }
            if let urlStr = creative.creativeExtInfoVO?.djProgram?.mainSong?.coverUrl?.absoluteString {
                return URL(string: urlStr)
            }
            return nil
        }()

        return VStack(alignment: .leading, spacing: 8) {
            CachedAsyncImage(url: coverUrl) {
                PetWhiteMascotMark(kind: rank.map { $0.isMultiple(of: 2) ? .cat : .dog } ?? .pair, size: 50)
                    .frame(width: s, height: s)
                    .background(PetWhiteStyle.surfacePressed)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: s, height: s)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(PetWhiteStyle.stroke, lineWidth: 1)
            )
            .overlay(alignment: .topTrailing) {
                if let rank {
                    Text("\(rank)")
                        .font(PetWhiteStyle.labelFont(11, weight: .black))
                        .foregroundStyle(PetWhiteStyle.ink)
                        .frame(width: 24, height: 24)
                        .background(PetWhiteStyle.butter, in: Circle())
                        .overlay(Circle().stroke(PetWhiteStyle.stroke, lineWidth: 1.1))
                        .padding(8)
                }
            }

            Text(title)
                .font(PetWhiteStyle.bodyFont(DeviceLayout.isPad ? 14 : 13, weight: .black))
                .foregroundStyle(PetWhiteStyle.ink)
                .lineLimit(2)
                .frame(width: s, height: 34, alignment: .topLeading)

            Text(subTitle)
                .font(PetWhiteStyle.labelFont(11, weight: .semibold))
                .foregroundStyle(PetWhiteStyle.inkSoft)
                .lineLimit(1)
                .frame(width: s, alignment: .leading)
        }
        .frame(width: s)
        .padding(9)
        .background(PetWhiteSurfaceBackground(cornerRadius: PetWhiteStyle.cardRadius, elevated: true, tint: PetWhiteStyle.surfaceRaised, accent: rank.map { $0 <= 3 ? PetWhiteStyle.dogOrange : PetWhiteStyle.sky } ?? PetWhiteStyle.mint))
    }

    // MARK: - 新人电台榜

    var newcomerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            podcastSectionHeader(
                title: String(localized: "podcast_newcomer"),
                destination: PodcastDestination.topList(String(localized: "podcast_newcomer"), .toplist)
            )

            ScrollView(.horizontal) {
                LazyHStack(spacing: 14) {
                    ForEach(Array(viewModel.newcomerRadios.enumerated()), id: \.element.id) { index, radio in
                        Button {
                            HapticStyle.light.trigger()
                            radioIdToOpen = radio.id
                        } label: {
                            rankedCompactCard(radio: radio, rank: index + 1)
                        }
                        .buttonStyle(MonoBouncingButtonStyle())
                        .compatScrollTransition(animation: .spring(response: 0.35)) { content, phase in
                            content
                                .scaleEffect(phase.isIdentity ? 1 : 0.93)
                                .opacity(phase.isIdentity ? 1 : 0.5)
                                .offset(y: phase.isIdentity ? 0 : phase.value * 8)
                        }
                    }
                }
                .compatScrollTargetLayout()
                .padding(.horizontal, padH)
            }
            .compatViewAlignedScrollBehavior(limitNever: true)
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
    }

    func rankedCompactCard(radio: RadioStation, rank: Int) -> AnyView {
        if PetWhiteStyle.isActive {
            return AnyView(petWhiteRankedCompactCard(radio: radio, rank: rank))
        }
        if SignalStyle.isActive {
            return AnyView(
                signalCompactCard(
                    coverURL: radio.coverUrl,
                    title: radio.name,
                    subtitle: radio.dj?.nickname ?? radio.category ?? " ",
                    rank: rank
                )
            )
        }
        if isAside {
            return AnyView(asideCompactCard(coverUrl: radio.coverUrl, title: radio.name, subtitle: radio.dj?.nickname ?? radio.category ?? " ", rank: rank))
        }

        let s = compactCardSize
        let cr: CGFloat = MangaStyle.isActive ? MangaStyle.cardRadius : (MujiStyle.isActive ? 8 : ((NeumorphicStyle.isActive || SequoiaStyle.isActive) ? 16 : (DeviceLayout.isPad ? 18 : 16)))
        let placeholderFill: Color = SequoiaStyle.isActive ? SequoiaStyle.materialList : (NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.monoGlassTint)
        let titleFont: Font = SequoiaStyle.isActive
            ? SequoiaStyle.bodyFont(DeviceLayout.isPad ? 14 : 13, weight: .semibold)
            : (MangaStyle.isActive ? MangaStyle.bodyFont(DeviceLayout.isPad ? 14 : 13, weight: .black) : (MujiStyle.isActive ? MujiStyle.bodyFont(DeviceLayout.isPad ? 14 : 13, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.bodyFont(DeviceLayout.isPad ? 14 : 13, weight: .semibold) : .system(size: DeviceLayout.isPad ? 14 : 13, weight: .medium, design: .rounded))))
        let subtitleFont: Font = SequoiaStyle.isActive
            ? SequoiaStyle.labelFont(DeviceLayout.isPad ? 12 : 11, weight: .regular)
            : (MangaStyle.isActive ? MangaStyle.bodyFont(DeviceLayout.isPad ? 12 : 11, weight: .bold) : (MujiStyle.isActive ? MujiStyle.labelFont(DeviceLayout.isPad ? 12 : 11, weight: .regular) : .system(size: DeviceLayout.isPad ? 12 : 11, design: .rounded)))
        let titleColor: Color = SequoiaStyle.isActive ? SequoiaStyle.ink : (NeumorphicStyle.isActive ? NeumorphicStyle.ink : .monoTextPrimary)
        let subtitleColor: Color = SequoiaStyle.isActive ? SequoiaStyle.inkSoft : (NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : .monoTextSecondary)
        let rankForeground: Color = SequoiaStyle.isActive ? (rank <= 3 ? SequoiaStyle.onAccent : SequoiaStyle.ink) : (rank <= 3 ? .monoIconForeground : .monoTextPrimary)
        let rankBackground: Color = SequoiaStyle.isActive ? (rank <= 3 ? SequoiaStyle.accent : SequoiaStyle.materialList) : (rank <= 3 ? Color.monoIconBackground : Color.monoGlassTint)
        return AnyView(VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                CachedAsyncImage(url: radio.coverUrl) {
                    RoundedRectangle(cornerRadius: cr)
                        .fill(placeholderFill)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: s, height: s)
                .clipShape(RoundedRectangle(cornerRadius: cr, style: .continuous))

                Text("\(rank)")
                    .font(SequoiaStyle.isActive ? SequoiaStyle.labelFont(12, weight: .semibold) : .system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundColor(rankForeground)
                    .frame(width: 26, height: 26)
                    .background(
                        Circle().fill(NeumorphicStyle.isActive ? (rank <= 3 ? NeumorphicStyle.accent : NeumorphicStyle.surfacePressed) : rankBackground)
                    )
                    .monoGlassCircle()
                    .padding(8)
            }

            Text(radio.name)
                .font(titleFont)
                .foregroundColor(titleColor)
                .lineLimit(2)
                .frame(width: s, height: 34, alignment: .topLeading)

            if let dj = radio.dj?.nickname {
                Text(dj)
                    .font(subtitleFont)
                    .foregroundColor(subtitleColor)
                    .lineLimit(1)
                    .frame(width: s, alignment: .leading)
            } else {
                Text(" ")
                    .font(.system(size: 11, design: .rounded))
                    .frame(width: s, alignment: .leading)
            }
        }
        .frame(width: s)
        .padding(ThemedPageStyle.isActive && !MujiStyle.isActive && !MangaStyle.isActive ? 8 : 0)
        .background {
            if MangaStyle.isActive {
                // 去卡片化：播客小格直接排在纸上
                EmptyView()
            } else if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(cornerRadius: 18, elevated: true)
            } else if SequoiaStyle.isActive {
                SequoiaSurfaceBackground(cornerRadius: 18, elevated: false, role: .list)
            }
        })
    }

    func signalCompactCard(
        coverURL: URL?,
        title: String,
        subtitle: String,
        rank: Int?
    ) -> some View {
        let size = compactCardSize

        return VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                CachedAsyncImage(url: coverURL) {
                    SignalStyle.controlPressed
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(SignalStyle.separator.opacity(0.7), lineWidth: 0.8)
                )

                if let rank {
                    Text(String(format: "%02d", rank))
                        .font(SignalStyle.monoFont(10, weight: .bold))
                        .foregroundStyle(rank <= 3 ? SignalStyle.onAccent : SignalStyle.ink)
                        .monospacedDigit()
                        .frame(width: 30, height: 24)
                        .background(
                            rank <= 3 ? SignalStyle.accent : SignalStyle.control,
                            in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                        )
                        .padding(7)
                }
            }

            Text(title)
                .font(SignalStyle.bodyFont(DeviceLayout.isPad ? 14 : 13, weight: .semibold))
                .foregroundStyle(SignalStyle.ink)
                .lineLimit(2)
                .frame(width: size, height: 34, alignment: .topLeading)

            Text(subtitle)
                .font(SignalStyle.labelFont(DeviceLayout.isPad ? 12 : 11, weight: .medium))
                .foregroundStyle(SignalStyle.inkSoft)
                .lineLimit(1)
                .frame(width: size, alignment: .leading)
        }
        .frame(width: size)
        .padding(8)
        .background(SignalSurfaceBackground(cornerRadius: 14, elevated: false, fill: SignalStyle.surface))
    }

    func petWhiteRankedCompactCard(radio: RadioStation, rank: Int) -> some View {
        let size = compactCardSize

        return VStack(alignment: .leading, spacing: 9) {
            ZStack(alignment: .topLeading) {
                CachedAsyncImage(url: radio.coverUrl) {
                    PetWhiteMascotMark(kind: rank.isMultiple(of: 2) ? .cat : .dog, size: 54)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(PetWhiteStyle.surfacePressed)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 23, style: .continuous)
                        .stroke(PetWhiteStyle.stroke, lineWidth: 1)
                )

                Text("\(rank)")
                    .font(PetWhiteStyle.labelFont(12, weight: .black))
                    .foregroundStyle(PetWhiteStyle.ink)
                    .frame(width: 28, height: 28)
                    .background(rank <= 3 ? PetWhiteStyle.dogOrange : PetWhiteStyle.surfaceRaised, in: Circle())
                    .overlay(Circle().stroke(PetWhiteStyle.stroke, lineWidth: 1.1))
                    .padding(8)
            }

            Text(radio.name)
                .font(PetWhiteStyle.bodyFont(DeviceLayout.isPad ? 14 : 13, weight: .black))
                .foregroundStyle(PetWhiteStyle.ink)
                .lineLimit(2)
                .frame(width: size, height: 36, alignment: .topLeading)

            Text(radio.dj?.nickname ?? radio.category ?? " ")
                .font(PetWhiteStyle.labelFont(11, weight: .semibold))
                .foregroundStyle(PetWhiteStyle.inkSoft)
                .lineLimit(1)
                .frame(width: size, alignment: .leading)
        }
        .frame(width: size)
        .padding(9)
        .background(PetWhiteSurfaceBackground(cornerRadius: PetWhiteStyle.cardRadius, elevated: true, tint: PetWhiteStyle.surfaceRaised, accent: rank <= 3 ? PetWhiteStyle.dogOrange : PetWhiteStyle.sky))
    }

    // MARK: - 节目榜

    var programToplistSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            podcastSectionHeader(
                title: String(localized: "podcast_program_toplist"),
                destination: PodcastDestination.topList(String(localized: "podcast_program_toplist"), .toplist)
            )

            VStack(spacing: 0) {
                ForEach(Array(viewModel.programToplist.enumerated()), id: \.element.id) { index, program in
                    Button {
                        HapticStyle.light.trigger()
                        if let radioId = program.radio?.id {
                            radioIdToOpen = radioId
                        }
                    } label: {
                        programListRow(program: program, rank: index + 1)
                    }
                    .buttonStyle(MonoBouncingButtonStyle(scale: 0.98))

                    if index < viewModel.programToplist.count - 1 {
                        Divider()
                            .foregroundColor(.monoSeparator)
                            .padding(.leading, padH + 28 + 14 + (DeviceLayout.isPad ? 60 : 50))
                            .padding(.trailing, padH)
                    }
                }
            }
        }
    }

}
