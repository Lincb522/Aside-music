import Combine
import SwiftUI

extension PodcastView {
    // MARK: - 网格卡片

    func radioGridCard(radio: RadioStation) -> AnyView {
        if PetWhiteStyle.isActive {
            return AnyView(petWhiteRadioGridCard(radio: radio))
        }
        if SignalStyle.isActive {
            return AnyView(signalRadioGridCard(radio: radio))
        }
        if SequoiaStyle.isActive {
            return AnyView(sequoiaRadioGridCard(radio: radio))
        }
        if NeumorphicStyle.isActive {
            return AnyView(neumorphicRadioGridCard(radio: radio))
        }
        if isAside {
            return AnyView(asideRadioGridCard(radio: radio))
        }

        let cr: CGFloat = MinimalWhiteStyle.isActive ? 12 : (MujiStyle.isActive ? 8 : (DeviceLayout.usesExpandedLayout ? 18 : 16))
        let cardPadding: CGFloat = (MinimalWhiteStyle.isActive || MujiStyle.isActive) ? 9 : 0

        return AnyView(
            VStack(alignment: .leading, spacing: 0) {
                GeometryReader { _ in
                    CachedAsyncImage(url: radio.coverUrl) {
                        RoundedRectangle(cornerRadius: cr)
                            .fill(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.controlGlassFill : Color.monoGlassTint)
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: cr))
                }
                .aspectRatio(1, contentMode: .fit)
                .overlay(
                    (MinimalWhiteStyle.isActive
                        ? LinearGradient(colors: [.clear], startPoint: .top, endPoint: .bottom)
                        : LinearGradient(
                            colors: [.clear, .clear, .black.opacity(0.35)],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                    .clipShape(RoundedRectangle(cornerRadius: cr))
                )
                .overlay(alignment: .bottomTrailing) {
                    MonoIcon(icon: .play, size: 14, color: .white, lineWidth: 2)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.black.opacity(0.15)))
                        .monoGlassCircle()
                        .padding(8)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(radio.name)
                        .font(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.bodyFont(14, weight: .medium) : (MujiStyle.isActive ? MujiStyle.bodyFont(14, weight: .regular) : .system(size: 14, weight: .semibold, design: .rounded)))
                        .foregroundColor(.monoTextPrimary)
                        .lineLimit(2, reservesSpace: true)
                        .minimumScaleFactor(0.86)
                        .allowsTightening(true)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, minHeight: 36, alignment: .topLeading)

                    Text(radio.dj?.nickname ?? " ")
                        .font(MinimalWhiteStyle.isActive ? MinimalWhiteStyle.labelFont(12, weight: .regular) : (MujiStyle.isActive ? MujiStyle.labelFont(12, weight: .regular) : .system(size: 12, design: .rounded)))
                        .foregroundColor(.monoTextSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                        .allowsTightening(true)
                }
                .padding(.top, 8)
                .padding(.horizontal, 2)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .padding(cardPadding)
            .background {
                if MinimalWhiteStyle.isActive {
                    MinimalWhiteSurfaceBackground(
                        cornerRadius: 14,
                        elevated: false,
                        tint: MinimalWhiteStyle.glassFill
                    )
                }
            }
        )
    }

    func signalRadioGridCard(radio: RadioStation) -> some View {
        let metadata = radio.dj?.nickname ?? radio.category ?? " "

        return VStack(alignment: .leading, spacing: 9) {
            ZStack(alignment: .bottomTrailing) {
                CachedAsyncImage(url: radio.coverUrl) {
                    SignalStyle.controlPressed
                        .overlay(
                            MonoIcon(icon: .podcast, size: 28, color: SignalStyle.inkMuted, lineWidth: 1.45)
                        )
                }
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(SignalStyle.separator.opacity(0.72), lineWidth: 0.8)
                )

                MonoIcon(icon: .play, size: 12, color: SignalStyle.onAccent, lineWidth: 1.9)
                    .frame(width: 32, height: 32)
                    .background(SignalStyle.accent, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .padding(8)
            }
            .aspectRatio(1, contentMode: .fit)

            Text(radio.name)
                .font(SignalStyle.bodyFont(14, weight: .semibold))
                .foregroundStyle(SignalStyle.ink)
                .lineLimit(2, reservesSpace: true)
                .frame(maxWidth: .infinity, minHeight: 36, alignment: .topLeading)

            HStack(spacing: 6) {
                SignalBreathingIndicator(size: 5)

                Text(metadata)
                    .font(SignalStyle.labelFont(11, weight: .medium))
                    .foregroundStyle(SignalStyle.inkSoft)
                    .lineLimit(1)

                Spacer(minLength: 0)

                if let count = radio.programCount, count > 0 {
                    Text("\(count)")
                        .font(SignalStyle.monoFont(10, weight: .semibold))
                        .foregroundStyle(SignalStyle.inkMuted)
                        .monospacedDigit()
                }
            }
        }
        .contentShape(Rectangle())
    }

    /// aside 网格卡：平铺封面 + 发丝描边 + 编辑部排印
    func asideRadioGridCard(radio: RadioStation) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            GeometryReader { _ in
                CachedAsyncImage(url: radio.coverUrl) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.monoSeparator.opacity(0.35))
                        .overlay(
                            MonoIcon(icon: .podcast, size: 26, color: .monoTextSecondary.opacity(0.35), lineWidth: 1.4)
                        )
                }
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .aspectRatio(1, contentMode: .fit)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.monoTextPrimary.opacity(0.08), lineWidth: 0.8)
            )

            Text(radio.name)
                .font(.rounded(size: 14, weight: .semibold))
                .foregroundColor(.monoTextPrimary)
                .lineLimit(2, reservesSpace: true)
                .minimumScaleFactor(0.86)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.top, 9)

            HStack(spacing: 5) {
                Circle()
                    .fill(Color.monoAccent)
                    .frame(width: 3.5, height: 3.5)

                Text(radio.dj?.nickname ?? radio.category ?? " ")
                    .font(.rounded(size: 11, weight: .medium))
                    .foregroundColor(.monoTextSecondary.opacity(0.85))
                    .lineLimit(1)
            }
            .padding(.top, 5)
        }
    }

    func petWhiteRadioGridCard(radio: RadioStation) -> some View {
        let coverRadius: CGFloat = DeviceLayout.usesExpandedLayout ? 24 : 22
        let metadata = radio.dj?.nickname ?? radio.category ?? " "

        return VStack(alignment: .leading, spacing: 9) {
            ZStack(alignment: .bottomTrailing) {
                CachedAsyncImage(url: radio.coverUrl) {
                    PetWhiteMascotMark(kind: .cat, size: 58)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(PetWhiteStyle.surfacePressed)
                }
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: coverRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: coverRadius, style: .continuous)
                        .stroke(PetWhiteStyle.stroke, lineWidth: 1)
                )

                PetWhitePackIcon(icon: .play, size: 15, visualScale: 1.08)
                    .frame(width: 34, height: 34)
                    .background(PetWhiteStyle.butter, in: Circle())
                    .overlay(Circle().stroke(PetWhiteStyle.stroke, lineWidth: 1))
                    .padding(8)
            }
            .aspectRatio(1, contentMode: .fit)

            VStack(alignment: .leading, spacing: 5) {
                Text(radio.name)
                    .font(PetWhiteStyle.bodyFont(DeviceLayout.usesExpandedLayout ? 15 : 14, weight: .black))
                    .foregroundStyle(PetWhiteStyle.ink)
                    .lineLimit(2, reservesSpace: true)
                    .minimumScaleFactor(0.82)

                Text(metadata)
                    .font(PetWhiteStyle.labelFont(11, weight: .semibold))
                    .foregroundStyle(PetWhiteStyle.inkSoft)
                    .lineLimit(1)
            }
        }
        .padding(10)
        .background(PetWhiteSurfaceBackground(cornerRadius: PetWhiteStyle.cardRadius, elevated: true, tint: PetWhiteStyle.surfaceRaised, accent: PetWhiteStyle.mint))
    }

    func sequoiaRadioGridCard(radio: RadioStation) -> some View {
        let outerRadius: CGFloat = DeviceLayout.usesExpandedLayout ? 20 : 18
        let coverRadius: CGFloat = DeviceLayout.usesExpandedLayout ? 16 : 14
        let titleHeight: CGFloat = DeviceLayout.usesExpandedLayout ? 38 : 36
        let metadata = radio.dj?.nickname ?? radio.category ?? " "

        return VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                GeometryReader { proxy in
                    CachedAsyncImage(url: radio.coverUrl) {
                        RoundedRectangle(cornerRadius: coverRadius, style: .continuous)
                            .fill(SequoiaStyle.materialList)
                            .overlay(
                                MonoIcon(
                                    icon: .podcast,
                                    size: 28,
                                    color: SequoiaStyle.inkMuted.opacity(0.42),
                                    lineWidth: 1.45
                                )
                            )
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipShape(RoundedRectangle(cornerRadius: coverRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: coverRadius, style: .continuous)
                            .stroke(SequoiaStyle.separator.opacity(0.78), lineWidth: 0.6)
                    )
                }

                MonoIcon(icon: .play, size: 12, color: SequoiaStyle.onAccent, lineWidth: 1.85)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(SequoiaStyle.accent))
                    .shadow(color: SequoiaStyle.accent.opacity(0.18), radius: 8, x: 0, y: 4)
                    .padding(8)
            }
            .aspectRatio(1, contentMode: .fit)

            VStack(alignment: .leading, spacing: 5) {
                Text(radio.name)
                    .font(SequoiaStyle.bodyFont(DeviceLayout.usesExpandedLayout ? 15 : 14, weight: .semibold))
                    .foregroundStyle(SequoiaStyle.ink)
                    .lineLimit(2, reservesSpace: true)
                    .minimumScaleFactor(0.82)
                    .allowsTightening(true)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, minHeight: titleHeight, alignment: .topLeading)

                Text(metadata)
                    .font(SequoiaStyle.labelFont(11, weight: .regular))
                    .foregroundStyle(SequoiaStyle.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.84)
                    .allowsTightening(true)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .padding(8)
        .background(
            SequoiaSurfaceBackground(
                cornerRadius: outerRadius,
                elevated: false,
                role: .list
            )
        )
        .contentShape(RoundedRectangle(cornerRadius: outerRadius, style: .continuous))
        .themeRenderInteractiveLayer()
    }

    func neumorphicRadioGridCard(radio: RadioStation) -> some View {
        let outerRadius: CGFloat = DeviceLayout.usesExpandedLayout ? 20 : 18
        let coverRadius: CGFloat = DeviceLayout.usesExpandedLayout ? 16 : 14
        let titleHeight: CGFloat = DeviceLayout.usesExpandedLayout ? 45 : 43
        let metadata = radio.dj?.nickname ?? radio.category ?? " "

        return VStack(alignment: .leading, spacing: 7) {
            ZStack(alignment: .bottomTrailing) {
                NeumorphicSurfaceBackground(
                    cornerRadius: coverRadius + 4,
                    elevated: false,
                    pressed: true,
                    tint: NeumorphicStyle.surfacePressed,
                    lightweight: true
                )

                GeometryReader { proxy in
                    let side = max(0, min(proxy.size.width, proxy.size.height) - 9)

                    CachedAsyncImage(url: radio.coverUrl) {
                        RoundedRectangle(cornerRadius: coverRadius, style: .continuous)
                            .fill(NeumorphicStyle.surfacePressed)
                            .overlay(
                                MonoIcon(
                                    icon: .podcast,
                                    size: 30,
                                    color: NeumorphicStyle.inkMuted.opacity(0.42),
                                    lineWidth: 1.45
                                )
                            )
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: side, height: side)
                    .clipShape(RoundedRectangle(cornerRadius: coverRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: coverRadius, style: .continuous)
                            .stroke(NeumorphicStyle.separator.opacity(0.46), lineWidth: 0.8)
                    )
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                }
                .padding(0)

                MonoIcon(
                    icon: .play,
                    size: 13,
                    color: Color(light: .white, dark: .black),
                    lineWidth: 2
                )
                .frame(width: 34, height: 34)
                .background(Circle().fill(NeumorphicStyle.accent))
                .shadow(color: NeumorphicStyle.accent.opacity(0.2), radius: 7, x: 0, y: 4)
                .padding(8)
            }
            .aspectRatio(0.96, contentMode: .fit)

            VStack(alignment: .leading, spacing: 5) {
                Text(radio.name)
                    .font(NeumorphicStyle.bodyFont(DeviceLayout.usesExpandedLayout ? 14 : 13, weight: .semibold))
                    .foregroundStyle(NeumorphicStyle.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.74)
                    .allowsTightening(true)
                    .multilineTextAlignment(.leading)
                    .frame(height: titleHeight, alignment: .topLeading)
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                Text(metadata)
                    .font(NeumorphicStyle.labelFont(11, weight: .medium))
                    .foregroundStyle(NeumorphicStyle.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.84)
                    .allowsTightening(true)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .padding(8)
        .background(
            NeumorphicSurfaceBackground(
                cornerRadius: outerRadius,
                elevated: true,
                tint: NeumorphicStyle.surfaceRaised
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
                .stroke(NeumorphicStyle.separator.opacity(0.18), lineWidth: 0.7)
        )
        .contentShape(RoundedRectangle(cornerRadius: outerRadius, style: .continuous))
        .themeRenderInteractiveLayer()
    }

    // MARK: - 列表行

    func radioListRow(radio: RadioStation) -> AnyView {
        if PetWhiteStyle.isActive {
            return AnyView(petWhiteRadioListRow(radio: radio))
        }
        if SignalStyle.isActive {
            return AnyView(signalRadioListRow(radio: radio))
        }
        if isAside {
            return AnyView(asideRadioListRow(radio: radio))
        }

        let rowImg: CGFloat = DeviceLayout.usesExpandedLayout ? 72 : 60
        let themedInset = MinimalWhiteStyle.isActive || MujiStyle.isActive || NeumorphicStyle.isActive || SequoiaStyle.isActive
        let cr: CGFloat = MinimalWhiteStyle.isActive ? 12 : (MujiStyle.isActive ? 8 : ((NeumorphicStyle.isActive || SequoiaStyle.isActive) ? 16 : 16))
        let placeholderFill: Color = MinimalWhiteStyle.isActive ? MinimalWhiteStyle.controlGlassFill : (SequoiaStyle.isActive ? SequoiaStyle.materialList : (NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.monoGlassTint))
        let titleFont: Font
        if MinimalWhiteStyle.isActive {
            titleFont = MinimalWhiteStyle.bodyFont(15, weight: .medium)
        } else if MujiStyle.isActive {
            titleFont = MujiStyle.bodyFont(15, weight: .regular)
        } else if NeumorphicStyle.isActive {
            titleFont = NeumorphicStyle.bodyFont(15, weight: .semibold)
        } else if SequoiaStyle.isActive {
            titleFont = SequoiaStyle.bodyFont(15, weight: .semibold)
        } else {
            titleFont = .system(size: 15, weight: .medium, design: .rounded)
        }
        let secondaryFont: Font = MinimalWhiteStyle.isActive ? MinimalWhiteStyle.labelFont(12, weight: .regular) : (SequoiaStyle.isActive ? SequoiaStyle.labelFont(12, weight: .regular) : .system(size: 12, design: .rounded))
        let primaryColor: Color = MinimalWhiteStyle.isActive ? MinimalWhiteStyle.ink : (SequoiaStyle.isActive ? SequoiaStyle.ink : (NeumorphicStyle.isActive ? NeumorphicStyle.ink : .monoTextPrimary))
        let secondaryColor: Color = MinimalWhiteStyle.isActive ? MinimalWhiteStyle.inkMuted : (SequoiaStyle.isActive ? SequoiaStyle.inkSoft : (NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : .monoTextSecondary))
        let playForeground: Color = MinimalWhiteStyle.isActive ? MinimalWhiteStyle.ink : (SequoiaStyle.isActive ? SequoiaStyle.onAccent : (NeumorphicStyle.isActive ? Color(light: .white, dark: .black) : .monoIconForeground))
        let playBackground: Color = MinimalWhiteStyle.isActive ? MinimalWhiteStyle.controlGlassFill : (SequoiaStyle.isActive ? SequoiaStyle.accent : (NeumorphicStyle.isActive ? NeumorphicStyle.accent : Color.monoIconBackground))

        return AnyView(HStack(spacing: 14) {
            CachedAsyncImage(url: radio.coverUrl) {
                RoundedRectangle(cornerRadius: cr)
                    .fill(placeholderFill)
            }
            .frame(width: rowImg, height: rowImg)
            .clipShape(RoundedRectangle(cornerRadius: cr, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(radio.name)
                    .font(titleFont)
                    .foregroundColor(primaryColor)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let dj = radio.dj?.nickname {
                        Text(dj)
                            .font(secondaryFont)
                            .foregroundColor(secondaryColor)
                    }
                    if let count = radio.programCount, count > 0 {
                        Text("·")
                            .foregroundColor(secondaryColor)
                        Text(String(format: String(localized: "podcast_episode_count"), count))
                            .font(secondaryFont)
                            .foregroundColor(secondaryColor)
                    }
                }
            }

            Spacer()

            MonoIcon(icon: .play, size: 12, color: playForeground, lineWidth: 2)
                .frame(width: 30, height: 30)
                .background(Circle().fill(playBackground))
        }
        .padding(.horizontal, themedInset ? 14 : padH)
        .padding(.vertical, themedInset ? 12 : 10)
        .background {
            if MujiStyle.isActive {
                VStack {
                    Spacer()
                    MujiListDivider()
                }
            } else if MinimalWhiteStyle.isActive {
                MinimalWhiteSurfaceBackground(cornerRadius: 14, elevated: false, tint: MinimalWhiteStyle.glassFill)
            } else if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(cornerRadius: 18, elevated: false)
            } else if SequoiaStyle.isActive {
                SequoiaSurfaceBackground(cornerRadius: 18, elevated: false, role: .list)
            }
        }
        .padding(.horizontal, themedInset ? padH : 0)
        .padding(.vertical, themedInset ? 5 : 0)
        .contentShape(Rectangle()))
    }

    func signalRadioListRow(radio: RadioStation) -> some View {
        HStack(spacing: 12) {
            CachedAsyncImage(url: radio.coverUrl) {
                SignalStyle.controlPressed
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 58, height: 58)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(SignalStyle.separator.opacity(0.7), lineWidth: 0.8)
            )

            VStack(alignment: .leading, spacing: 5) {
                Text(radio.name)
                    .font(SignalStyle.bodyFont(15, weight: .semibold))
                    .foregroundStyle(SignalStyle.ink)
                    .lineLimit(1)

                Text(radio.dj?.nickname ?? radio.category ?? " ")
                    .font(SignalStyle.labelFont(11, weight: .medium))
                    .foregroundStyle(SignalStyle.inkSoft)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            SignalLevelMeter(
                activeCount: min(max((radio.programCount ?? 0) % 7 + 2, 2), 8),
                barCount: 8,
                tint: SignalStyle.inkSoft,
                height: 19
            )

            MonoIcon(icon: .play, size: 12, color: SignalStyle.onAccent, lineWidth: 1.9)
                .frame(width: 34, height: 34)
                .background(SignalStyle.accent, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(11)
        .background(SignalSurfaceBackground(cornerRadius: 14, elevated: false, fill: SignalStyle.surface))
        .padding(.horizontal, padH)
        .padding(.vertical, 4)
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// aside 精选电台行：发丝分隔列表行
    func asideRadioListRow(radio: RadioStation) -> some View {
        let rowImg: CGFloat = DeviceLayout.usesExpandedLayout ? 66 : 56

        return HStack(spacing: 13) {
            CachedAsyncImage(url: radio.coverUrl) {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Color.monoSeparator.opacity(0.35))
            }
            .frame(width: rowImg, height: rowImg)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(Color.monoTextPrimary.opacity(0.08), lineWidth: 0.8)
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(radio.name)
                    .font(.rounded(size: 15, weight: .semibold))
                    .foregroundColor(.monoTextPrimary)
                    .lineLimit(1)

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

            Spacer(minLength: 8)

            MonoIcon(icon: .play, size: 11, color: .monoTextPrimary, lineWidth: 1.9)
                .frame(width: 30, height: 30)
                .overlay(Circle().stroke(Color.monoTextPrimary.opacity(0.28), lineWidth: 0.9))
        }
        .padding(.horizontal, padH)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }

    func petWhiteRadioListRow(radio: RadioStation) -> some View {
        HStack(spacing: 12) {
            CachedAsyncImage(url: radio.coverUrl) {
                PetWhiteMascotMark(kind: .dog, size: 46)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(PetWhiteStyle.surfacePressed)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: DeviceLayout.usesExpandedLayout ? 66 : 58, height: DeviceLayout.usesExpandedLayout ? 66 : 58)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(PetWhiteStyle.stroke, lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 5) {
                Text(radio.name)
                    .font(PetWhiteStyle.bodyFont(15, weight: .black))
                    .foregroundStyle(PetWhiteStyle.ink)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(radio.dj?.nickname ?? radio.category ?? " ")
                        .font(PetWhiteStyle.labelFont(11, weight: .semibold))
                        .foregroundStyle(PetWhiteStyle.inkSoft)
                        .lineLimit(1)

                    if let count = radio.programCount, count > 0 {
                        Text(String(format: String(localized: "podcast_episode_count"), count))
                            .font(PetWhiteStyle.labelFont(11, weight: .semibold))
                            .foregroundStyle(PetWhiteStyle.inkMuted)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 8)

            PetWhitePackIcon(icon: .play, size: 16, visualScale: 1.08)
                .frame(width: 32, height: 32)
                .background(PetWhiteStyle.mint, in: Circle())
                .overlay(Circle().stroke(PetWhiteStyle.stroke, lineWidth: 1.1))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(PetWhiteSurfaceBackground(cornerRadius: 22, elevated: false, tint: PetWhiteStyle.surfaceRaised, accent: PetWhiteStyle.mint))
        .padding(.horizontal, padH)
    }

    // MARK: - 节目榜行

    func programListRow(program: RadioProgram, rank: Int) -> AnyView {
        if PetWhiteStyle.isActive {
            return AnyView(petWhiteProgramListRow(program: program, rank: rank))
        }
        if SignalStyle.isActive {
            return AnyView(signalProgramListRow(program: program, rank: rank))
        }
        if isAside {
            return AnyView(asideProgramListRow(program: program, rank: rank))
        }

        let isTop3 = rank <= 3
        let coverSize: CGFloat = DeviceLayout.usesExpandedLayout ? 60 : 50
        let themedInset = MinimalWhiteStyle.isActive || MujiStyle.isActive || NeumorphicStyle.isActive || SequoiaStyle.isActive
        let cr: CGFloat = MinimalWhiteStyle.isActive ? 12 : (MujiStyle.isActive ? 8 : ((NeumorphicStyle.isActive || SequoiaStyle.isActive) ? 15 : 14))
        let placeholderFill: Color = MinimalWhiteStyle.isActive ? MinimalWhiteStyle.controlGlassFill : (SequoiaStyle.isActive ? SequoiaStyle.materialList : (NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.monoGlassTint))
        let rankFont: Font = MinimalWhiteStyle.isActive
            ? MinimalWhiteStyle.titleFont(isTop3 ? 18 : 15, weight: .semibold)
            : (SequoiaStyle.isActive
            ? SequoiaStyle.titleFont(isTop3 ? 19 : 16, weight: .semibold)
            : (NeumorphicStyle.isActive ? NeumorphicStyle.titleFont(isTop3 ? 20 : 16, weight: .semibold) : .system(size: isTop3 ? 20 : 16, weight: .heavy, design: .rounded)))
        let titleFont: Font
        if MinimalWhiteStyle.isActive {
            titleFont = MinimalWhiteStyle.bodyFont(isTop3 ? 15 : 14, weight: isTop3 ? .medium : .regular)
        } else if MujiStyle.isActive {
            titleFont = MujiStyle.bodyFont(isTop3 ? 15 : 14, weight: isTop3 ? .medium : .regular)
        } else if NeumorphicStyle.isActive {
            titleFont = NeumorphicStyle.bodyFont(isTop3 ? 15 : 14, weight: isTop3 ? .semibold : .medium)
        } else if SequoiaStyle.isActive {
            titleFont = SequoiaStyle.bodyFont(isTop3 ? 15 : 14, weight: isTop3 ? .semibold : .medium)
        } else {
            titleFont = .system(size: isTop3 ? 15 : 14, weight: isTop3 ? .semibold : .medium, design: .rounded)
        }
        let subtitleFont: Font = MinimalWhiteStyle.isActive ? MinimalWhiteStyle.labelFont(12, weight: .regular) : (SequoiaStyle.isActive ? SequoiaStyle.labelFont(12, weight: .regular) : .system(size: 12, design: .rounded))
        let primaryColor: Color = MinimalWhiteStyle.isActive ? MinimalWhiteStyle.ink : (SequoiaStyle.isActive ? SequoiaStyle.ink : (NeumorphicStyle.isActive ? NeumorphicStyle.ink : .monoTextPrimary))
        let secondaryColor: Color = MinimalWhiteStyle.isActive ? MinimalWhiteStyle.inkMuted : (SequoiaStyle.isActive ? SequoiaStyle.inkSoft : (NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : .monoTextSecondary))
        let rankColor: Color = MinimalWhiteStyle.isActive ? (isTop3 ? MinimalWhiteStyle.ink : MinimalWhiteStyle.inkMuted) : (isTop3 ? (SequoiaStyle.isActive ? SequoiaStyle.accent : (NeumorphicStyle.isActive ? NeumorphicStyle.accent : .monoIconBackground)) : (SequoiaStyle.isActive ? SequoiaStyle.inkMuted : (NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : .monoTextSecondary)))

        return AnyView(HStack(spacing: 14) {
            Text("\(rank)")
                .font(rankFont)
                .foregroundColor(rankColor)
                .frame(width: 28)

            CachedAsyncImage(url: program.programCoverUrl) {
                RoundedRectangle(cornerRadius: cr)
                    .fill(placeholderFill)
            }
            .frame(width: coverSize, height: coverSize)
            .clipShape(RoundedRectangle(cornerRadius: cr, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(program.name ?? "")
                    .font(titleFont)
                    .foregroundColor(primaryColor)
                    .lineLimit(1)

                if let radioName = program.radio?.name {
                    Text(radioName)
                        .font(subtitleFont)
                        .foregroundColor(secondaryColor)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let count = program.listenerCount, count > 0 {
                HStack(spacing: 3) {
                    MonoIcon(icon: .headphones, size: 11, color: secondaryColor, lineWidth: 1.2)
                    Text(formatCount(count))
                        .font(SequoiaStyle.isActive ? SequoiaStyle.labelFont(11, weight: .regular) : .system(size: 11, design: .rounded))
                        .foregroundColor(secondaryColor)
                }
            }
        }
        .padding(.horizontal, themedInset ? 14 : padH)
        .padding(.vertical, themedInset ? 12 : (isTop3 ? 10 : 8))
        .background {
            if MujiStyle.isActive {
                VStack {
                    Spacer()
                    MujiListDivider()
                }
            } else if MinimalWhiteStyle.isActive {
                MinimalWhiteSurfaceBackground(cornerRadius: 14, elevated: isTop3, tint: MinimalWhiteStyle.glassFill)
            } else if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(cornerRadius: 18, elevated: isTop3)
            } else if SequoiaStyle.isActive {
                SequoiaSurfaceBackground(cornerRadius: 18, elevated: isTop3, role: isTop3 ? .selected : .list)
            }
        }
        .padding(.horizontal, themedInset ? padH : 0)
        .padding(.vertical, themedInset ? 5 : 0)
        .contentShape(Rectangle()))
    }

    func signalProgramListRow(program: RadioProgram, rank: Int) -> some View {
        let isTop3 = rank <= 3

        return HStack(spacing: 12) {
            Text(String(format: "%02d", rank))
                .font(SignalStyle.monoFont(11, weight: .bold))
                .foregroundStyle(isTop3 ? SignalStyle.accent : SignalStyle.inkMuted)
                .monospacedDigit()
                .frame(width: 26, alignment: .leading)

            CachedAsyncImage(url: program.programCoverUrl) {
                SignalStyle.controlPressed
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(program.name ?? "")
                    .font(SignalStyle.bodyFont(14, weight: .semibold))
                    .foregroundStyle(SignalStyle.ink)
                    .lineLimit(1)

                Text(program.radio?.name ?? " ")
                    .font(SignalStyle.labelFont(11, weight: .medium))
                    .foregroundStyle(SignalStyle.inkSoft)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            if let count = program.listenerCount, count > 0 {
                Text(formatCount(count))
                    .font(SignalStyle.monoFont(10, weight: .semibold))
                    .foregroundStyle(SignalStyle.inkMuted)
                    .monospacedDigit()
            }
        }
        .padding(11)
        .background(
            SignalSurfaceBackground(
                cornerRadius: 13,
                elevated: isTop3,
                fill: isTop3 ? SignalStyle.surfaceRaised : SignalStyle.surface
            )
        )
        .padding(.horizontal, padH)
        .padding(.vertical, 4)
        .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    /// aside 节目榜行：期刊式序号 + 发丝封面
    func asideProgramListRow(program: RadioProgram, rank: Int) -> some View {
        let isTop3 = rank <= 3
        let coverSize: CGFloat = DeviceLayout.usesExpandedLayout ? 56 : 48

        return HStack(spacing: 13) {
            Text(String(format: "%02d", rank))
                .font(.system(size: 11.5, weight: .heavy, design: .rounded))
                .tracking(0.8)
                .monospacedDigit()
                .foregroundColor(isTop3 ? .monoAccent : .monoTextSecondary.opacity(0.5))
                .frame(width: 26, alignment: .leading)

            CachedAsyncImage(url: program.programCoverUrl) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.monoSeparator.opacity(0.35))
            }
            .frame(width: coverSize, height: coverSize)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.monoTextPrimary.opacity(0.08), lineWidth: 0.8)
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(program.name ?? "")
                    .font(.rounded(size: 14.5, weight: isTop3 ? .semibold : .medium))
                    .foregroundColor(.monoTextPrimary)
                    .lineLimit(1)

                if let radioName = program.radio?.name {
                    Text(radioName)
                        .font(.rounded(size: 11.5, weight: .medium))
                        .foregroundColor(.monoTextSecondary.opacity(0.9))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            if let count = program.listenerCount, count > 0 {
                HStack(spacing: 3) {
                    MonoIcon(icon: .headphones, size: 10, color: .monoTextSecondary.opacity(0.75), lineWidth: 1.3)
                    Text(formatCount(count))
                        .font(.rounded(size: 10.5, weight: .medium))
                        .monospacedDigit()
                        .foregroundColor(.monoTextSecondary.opacity(0.85))
                }
            }
        }
        .padding(.horizontal, padH)
        .padding(.vertical, 9)
        .contentShape(Rectangle())
    }

    func petWhiteProgramListRow(program: RadioProgram, rank: Int) -> some View {
        let isTop3 = rank <= 3

        return HStack(spacing: 12) {
            Text("\(rank)")
                .font(PetWhiteStyle.titleFont(isTop3 ? 20 : 16, weight: .black))
                .foregroundStyle(isTop3 ? PetWhiteStyle.dogOrange : PetWhiteStyle.inkMuted)
                .frame(width: 30)

            CachedAsyncImage(url: program.programCoverUrl) {
                PetWhiteMascotMark(kind: isTop3 ? .dog : .cat, size: 42)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(PetWhiteStyle.surfacePressed)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 54, height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(PetWhiteStyle.stroke, lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(program.name ?? "")
                    .font(PetWhiteStyle.bodyFont(14, weight: .black))
                    .foregroundStyle(PetWhiteStyle.ink)
                    .lineLimit(1)

                Text(program.radio?.name ?? " ")
                    .font(PetWhiteStyle.labelFont(11, weight: .semibold))
                    .foregroundStyle(PetWhiteStyle.inkSoft)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if let count = program.listenerCount, count > 0 {
                HStack(spacing: 4) {
                    PetWhitePackIcon(icon: .headphones, size: 13, visualScale: 1.04)
                    Text(formatCount(count))
                        .font(PetWhiteStyle.labelFont(11, weight: .black))
                }
                .foregroundStyle(PetWhiteStyle.inkSoft)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .padding(.horizontal, padH)
        .background(PetWhiteSurfaceBackground(cornerRadius: 22, elevated: isTop3, tint: PetWhiteStyle.surfaceRaised, accent: isTop3 ? PetWhiteStyle.butter : PetWhiteStyle.sky))
    }

}
