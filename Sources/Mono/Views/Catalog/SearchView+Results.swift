import SwiftUI

extension SearchView {
    // MARK: - 搜索内容区域

    @ViewBuilder
    var searchContentView: some View {
        if viewModel.hasSearched {
            searchedResultsScrollView
        } else if viewModel.query.isEmpty {
            emptySearchView
        }
    }

    var searchedResultsScrollView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if !MinimalWhiteStyle.isActive {
                    searchBarSection
                }

                if CapsuleStyle.isActive {
                    capsuleSearchCommandBoard
                } else {
                    if !MinimalWhiteStyle.isActive {
                        if MangaStyle.isActive {
                            mangaResultConsole
                        } else if MujiStyle.isActive {
                            mujiResultConsole
                        } else if NeumorphicStyle.isActive {
                            neumorphicResultConsole
                        } else if SignalStyle.isActive {
                            signalResultConsole
                        } else if SequoiaStyle.isActive {
                            sequoiaResultConsole
                        } else if LiquidGlassStyle.isActive {
                            liquidGlassResultConsole
                        } else {
                            defaultResultConsole
                        }
                    }

                    searchTabBar
                    platformTabBar
                }

                let platformLoading = isPlatformLoading
                let platformEmpty = isPlatformEmpty

                if platformLoading && platformEmpty {
                    searchLoadingState
                } else if platformEmpty {
                    searchEmptyState
                } else {
                    if viewModel.currentTab == .songs {
                        searchSongsToolbarView
                    }

                    platformResultsRows
                }

                FloatingBarBottomSpacer()
            }
            .padding(.bottom, 8)
        }
        .scrollIndicators(.hidden)
        .themeRenderScrollLayer()
        .simultaneousGesture(DragGesture().onChanged { _ in
            isFocused = false
        })
    }

    var neumorphicResultConsole: some View {
        HStack(spacing: 12) {
            NeumorphicIconBadge(icon: searchTabIcon(viewModel.currentTab), tint: NeumorphicStyle.accent, size: 38)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 7) {
                    Text("SEARCH")
                        .font(NeumorphicStyle.labelFont(9, weight: .semibold))
                        .foregroundStyle(NeumorphicStyle.accent)
                        .tracking(1.1)

                    Capsule()
                        .fill(NeumorphicStyle.separator.opacity(0.76))
                        .frame(width: 18, height: 1)
                }

                Text(viewModel.displayKeyword.isEmpty ? String(localized: "action_search") : viewModel.displayKeyword)
                    .font(NeumorphicStyle.titleFont(19, weight: .semibold))
                    .foregroundStyle(NeumorphicStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                HStack(spacing: 6) {
                    neumorphicResultChip(text: platformTabName(viewModel.selectedPlatform), tint: viewModel.selectedPlatform.themedBadgeColor)
                    neumorphicResultChip(text: viewModel.currentTab.rawValue, tint: NeumorphicStyle.sage)
                }
            }

            Spacer(minLength: 8)

            Group {
                if isPlatformLoading {
                    ProgressView()
                        .tint(NeumorphicStyle.accent)
                        .scaleEffect(0.78)
                } else {
                    Text("\(selectedPlatformResultCount)")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(NeumorphicStyle.accent)
                        .monospacedDigit()
                }
            }
            .frame(minWidth: 42, minHeight: 38)
            .padding(.horizontal, 6)
            .background(NeumorphicSurfaceBackground(cornerRadius: 14, elevated: false, pressed: true, lightweight: true))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(NeumorphicSurfaceBackground(cornerRadius: 22, elevated: true))
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.bottom, 8)
    }

    func neumorphicResultChip(text: String, tint: Color) -> some View {
        Text(text)
            .font(NeumorphicStyle.labelFont(10, weight: .semibold))
            .foregroundStyle(tint)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(tint.opacity(0.13))
            )
    }

    /// aside 结果摘要：去掉卡片，改成杂志式标题行 —— 关键词大字 + 平台/类型/条数小注
    var defaultResultConsole: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.displayKeyword.isEmpty ? String(localized: "action_search") : viewModel.displayKeyword)
                .font(.rounded(size: 26, weight: .heavy))
                .foregroundStyle(Color.monoTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            HStack(spacing: 7) {
                Circle()
                    .fill(viewModel.selectedPlatform.themedBadgeColor)
                    .frame(width: 6, height: 6)

                Text(platformTabName(viewModel.selectedPlatform))
                    .font(.rounded(size: 12, weight: .semibold))
                    .foregroundStyle(Color.monoTextSecondary)

                Text(verbatim: "·")
                    .font(.rounded(size: 12, weight: .semibold))
                    .foregroundStyle(Color.monoTextSecondary.opacity(0.5))

                Text(viewModel.currentTab.rawValue)
                    .font(.rounded(size: 12, weight: .semibold))
                    .foregroundStyle(Color.monoTextSecondary)

                Spacer(minLength: 8)

                if isPlatformLoading {
                    ProgressView()
                        .scaleEffect(0.66)
                        .tint(.monoTextSecondary)
                } else {
                    Text(L10n.format("search_result_count_format", selectedPlatformResultCount))
                        .font(.rounded(size: 12, weight: .semibold))
                        .foregroundStyle(Color.monoTextSecondary.opacity(0.85))
                        .monospacedDigit()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.top, 8)
        .padding(.bottom, 2)
    }

    /// Muji：检索结果摘要 —— 圆点标记 + 关键词 + 水洗小签
    var mujiResultConsole: some View {
        return HStack(alignment: .top, spacing: 10) {
            MujiDotMark()
                .padding(.top, 9)

            VStack(alignment: .leading, spacing: 6) {
                Text(viewModel.displayKeyword.isEmpty ? String(localized: "action_search") : viewModel.displayKeyword)
                    .font(MujiStyle.titleFont(21, weight: .medium))
                    .foregroundStyle(MujiStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                HStack(spacing: 7) {
                    MujiPill(text: platformTabName(viewModel.selectedPlatform), tint: viewModel.selectedPlatform.themedBadgeColor)
                    MujiPill(text: viewModel.currentTab.rawValue, tint: MujiStyle.inkSoft)
                }
            }

            Spacer(minLength: 8)

            resultCountBadge(
                textColor: MujiStyle.clay,
                background: Color.clear,
                font: MujiStyle.titleFont(16, weight: .medium)
            )
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }

    var mangaResultConsole: some View {
        // 去卡片化：编辑部摘要式——关键词大标题 + 小字条目，底部一根规则线
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(viewModel.displayKeyword.isEmpty ? String(localized: "action_search") : viewModel.displayKeyword)
                    .font(MangaStyle.titleFont(21, weight: .black))
                    .foregroundStyle(MangaStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 8)

                resultCountBadge(
                    textColor: MangaStyle.accentPink,
                    background: Color.clear,
                    font: .system(size: 15, weight: .black, design: .monospaced)
                )
            }

            HStack(spacing: 7) {
                mangaResultChip(text: platformTabName(viewModel.selectedPlatform), tint: viewModel.selectedPlatform.themedBadgeColor)
                mangaResultChip(text: viewModel.currentTab.rawValue, tint: MangaStyle.labelYellow)
            }
            .padding(.top, 7)

            Rectangle()
                .fill(MangaStyle.strokeInk.opacity(0.24))
                .frame(height: 1)
                .padding(.top, 11)
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.bottom, 8)
    }

    func mangaResultChip(text: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(tint)
                .frame(width: 10, height: 3.5)

            Text(text)
                .font(MangaStyle.labelFont(10, weight: .black))
                .foregroundStyle(MangaStyle.inkSub)
                .lineLimit(1)
        }
    }

    var signalResultConsole: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 7) {
                    Text(platformTabName(viewModel.selectedPlatform).uppercased())
                        .font(SignalStyle.monoFont(9, weight: .semibold))
                        .foregroundStyle(SignalStyle.accent)

                    signalResultChip(text: viewModel.currentTab.rawValue, tint: SignalStyle.violet)
                }

                Text(viewModel.displayKeyword.isEmpty ? String(localized: "action_search") : viewModel.displayKeyword)
                    .font(SignalStyle.titleFont(19, weight: .bold))
                    .foregroundStyle(SignalStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

            }

            Spacer(minLength: 8)

            Group {
                if isPlatformLoading {
                    ProgressView()
                        .tint(SignalStyle.accent)
                        .scaleEffect(0.78)
                } else {
                    Text("\(selectedPlatformResultCount)")
                        .font(SignalStyle.monoFont(15, weight: .semibold))
                        .foregroundStyle(SignalStyle.accent)
                        .monospacedDigit()
                }
            }
            .frame(minWidth: 42, minHeight: 28, alignment: .trailing)
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(SignalStyle.separator.opacity(0.64))
                .frame(height: 0.65)
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        }
    }

    func signalResultChip(text: String, tint: Color) -> some View {
        Text(text)
            .font(SignalStyle.labelFont(10, weight: .bold))
            .foregroundStyle(tint)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(tint.opacity(0.13)))
    }

    struct SignalSearchGroove: View {
        let tint: Color

        var body: some View {
            HStack(spacing: 4) {
                ForEach(0..<12, id: \.self) { index in
                    Capsule()
                        .fill(index < 8 ? tint.opacity(0.74) : SignalStyle.inkMuted.opacity(0.2))
                        .frame(maxWidth: .infinity)
                        .frame(height: 3 + CGFloat(index % 4))
                }
            }
            .frame(maxWidth: 150)
        }
    }

    struct LiquidGlassMicroSpectrum: View {
        let tint: Color

        var body: some View {
            HStack(spacing: 4) {
                ForEach(0..<12, id: \.self) { index in
                    Capsule()
                        .fill(index < 7 ? tint.opacity(0.68) : LiquidGlassStyle.inkMuted.opacity(0.18))
                        .frame(width: index.isMultiple(of: 3) ? 13 : 8, height: 3 + CGFloat((index + 1) % 3))
                }
            }
            .frame(maxWidth: 142, alignment: .leading)
        }
    }

    struct LiquidGlassPulseGlyphSmall: View {
        let tint: Color

        var body: some View {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.12))
                    .frame(width: 42, height: 42)
                    .background(LiquidGlassSurfaceBackground(cornerRadius: 16, elevated: false, role: .list))

                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { index in
                        Capsule()
                            .fill(index == 1 ? tint : LiquidGlassStyle.inkMuted.opacity(0.38))
                            .frame(width: 4, height: CGFloat([13, 22, 16][index]))
                    }
                }
            }
            .accessibilityHidden(true)
        }
    }

    var sequoiaResultConsole: some View {
        HStack(spacing: 12) {
            SequoiaIconBadge(icon: searchTabIcon(viewModel.currentTab), tint: viewModel.selectedPlatform.themedBadgeColor, size: 40)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 7) {
                    Text(platformTabName(viewModel.selectedPlatform).uppercased())
                        .font(SequoiaStyle.labelFont(9.5, weight: .semibold))
                        .foregroundStyle(viewModel.selectedPlatform.themedBadgeColor)
                        .tracking(0.8)

                    SequoiaPill(text: viewModel.currentTab.rawValue, tint: SequoiaStyle.aqua, selected: false, compact: true)
                }

                Text(viewModel.displayKeyword.isEmpty ? String(localized: "action_search") : viewModel.displayKeyword)
                    .font(SequoiaStyle.titleFont(19, weight: .semibold))
                    .foregroundStyle(SequoiaStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                SequoiaMeter(tint: viewModel.selectedPlatform.themedBadgeColor, count: 14)
            }

            Spacer(minLength: 8)

            Group {
                if isPlatformLoading {
                    ProgressView()
                        .tint(SequoiaStyle.accent)
                        .scaleEffect(0.78)
                } else {
                    Text("\(selectedPlatformResultCount)")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(SequoiaStyle.accent)
                        .monospacedDigit()
                }
            }
            .frame(minWidth: 44, minHeight: 38)
            .padding(.horizontal, 6)
            .background(SequoiaSurfaceBackground(cornerRadius: 14, elevated: false, role: .list))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(SequoiaSurfaceBackground(cornerRadius: 22, elevated: true, role: .chrome))
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.bottom, 8)
    }

    var liquidGlassResultConsole: some View {
        HStack(spacing: 12) {
            LiquidGlassIconBadge(icon: searchTabIcon(viewModel.currentTab), tint: viewModel.selectedPlatform.themedBadgeColor, size: 42)

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 7) {
                    Text(platformTabName(viewModel.selectedPlatform))
                        .font(LiquidGlassStyle.labelFont(10, weight: .semibold))
                        .foregroundStyle(viewModel.selectedPlatform.themedBadgeColor)
                        .tracking(0.7)

                    LiquidGlassPill(text: viewModel.currentTab.rawValue, tint: LiquidGlassStyle.violet, compact: true)
                }

                Text(viewModel.displayKeyword.isEmpty ? String(localized: "action_search") : viewModel.displayKeyword)
                    .font(LiquidGlassStyle.titleFont(20, weight: .semibold))
                    .foregroundStyle(LiquidGlassStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                LiquidGlassMicroSpectrum(tint: viewModel.selectedPlatform.themedBadgeColor)
            }

            Spacer(minLength: 8)

            Group {
                if isPlatformLoading {
                    ProgressView()
                        .tint(LiquidGlassStyle.accent)
                        .scaleEffect(0.78)
                } else {
                    Text("\(selectedPlatformResultCount)")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(LiquidGlassStyle.accent)
                        .monospacedDigit()
                }
            }
            .frame(minWidth: 44, minHeight: 38)
            .padding(.horizontal, 6)
            .background(LiquidGlassSurfaceBackground(cornerRadius: 15, elevated: false, pressed: true, role: .list))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(LiquidGlassPrismBand(tint: viewModel.selectedPlatform.themedBadgeColor, cornerRadius: 24))
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.bottom, 8)
    }

    var capsuleSearchCommandBoard: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Capsule()
                    .fill(viewModel.selectedPlatform.themedBadgeColor)
                    .frame(width: 7, height: 54)
                    .overlay(
                        Capsule()
                            .fill(Color.white.opacity(0.42))
                            .frame(width: 2, height: 28)
                    )

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        capsuleResultChip(text: platformTabName(viewModel.selectedPlatform), tint: viewModel.selectedPlatform.themedBadgeColor)
                        capsuleResultChip(text: viewModel.currentTab.rawValue, tint: CapsuleStyle.cyan)
                    }

                    Text(viewModel.displayKeyword.isEmpty ? String(localized: "action_search") : viewModel.displayKeyword)
                        .font(CapsuleStyle.titleFont(22, weight: .bold))
                        .foregroundStyle(CapsuleStyle.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }

                Spacer(minLength: 8)

                VStack(spacing: 0) {
                    Text("\(selectedPlatformResultCount)")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(CapsuleStyle.ink)
                        .monospacedDigit()
                }
                .frame(width: 54, height: 54)
                .background(CapsuleStyle.surfaceRaised.opacity(0.82), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }

            capsulePlatformSwitch

            capsuleSearchTypeSwitch
        }
        .padding(13)
        .background(capsuleCommandPanelBackground)
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.bottom, 10)
    }

    var capsulePlatformSwitch: some View {
        let platforms = availableSearchPlatforms

        return HStack(spacing: 7) {
            ForEach(platforms, id: \.self) { platform in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.84)) {
                        viewModel.selectPlatform(platform)
                    }
                } label: {
                    let tint = platform.themedBadgeColor
                    let selected = viewModel.selectedPlatform == platform
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(tint.opacity(selected ? 0.95 : 0.34))
                            .frame(width: selected ? 20 : 8, height: 8)

                        Text(platformTabName(platform))
                            .font(CapsuleStyle.labelFont(11.5, weight: selected ? .bold : .semibold))
                            .foregroundStyle(selected ? CapsuleStyle.ink : CapsuleStyle.inkSoft)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(selected ? tint.opacity(0.13) : CapsuleStyle.surfaceTint.opacity(0.42))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    var capsuleSearchTypeSwitch: some View {
        HStack(spacing: 7) {
            ForEach(SearchTab.allCases, id: \.self) { tab in
                Button {
                    viewModel.switchTab(tab)
                } label: {
                    let selected = viewModel.currentTab == tab
                    VStack(spacing: 6) {
                        MonoIcon(
                            icon: searchTabIcon(tab),
                            size: 12,
                            color: selected ? CapsuleStyle.onAccent : CapsuleStyle.inkMuted,
                            lineWidth: 1.65
                        )
                        .frame(width: 24, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(selected ? CapsuleStyle.accent : CapsuleStyle.surfaceTint.opacity(0.54))
                        )

                        Text(tab.rawValue)
                            .font(CapsuleStyle.labelFont(10.5, weight: selected ? .bold : .semibold))
                            .foregroundStyle(selected ? CapsuleStyle.ink : CapsuleStyle.inkSoft)
                            .lineLimit(1)
                            .minimumScaleFactor(0.76)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(selected ? CapsuleStyle.surfaceRaised.opacity(0.8) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    var capsuleCommandPanelBackground: some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        CapsuleStyle.surfaceRaised.opacity(0.96),
                        CapsuleStyle.surface.opacity(0.86),
                        CapsuleStyle.surfaceTint.opacity(0.72),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(CapsuleStyle.hairline.opacity(0.82), lineWidth: 1)
            )
            .overlay(alignment: .topTrailing) {
                HStack(spacing: 5) {
                    ForEach(CapsuleStyle.accentGradient.indices, id: \.self) { index in
                        Circle()
                            .fill(CapsuleStyle.accentGradient[index].opacity(index == 0 ? 0.95 : 0.62))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(16)
            }
    }

    var capsuleResultConsole: some View {
        return HStack(spacing: 12) {
            CapsuleIconBadge(icon: searchTabIcon(viewModel.currentTab), tint: viewModel.selectedPlatform.themedBadgeColor, size: 42)

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 7) {
                    capsuleResultChip(text: platformTabName(viewModel.selectedPlatform), tint: viewModel.selectedPlatform.themedBadgeColor)
                    capsuleResultChip(text: viewModel.currentTab.rawValue, tint: CapsuleStyle.cyan)
                }

                Text(viewModel.displayKeyword.isEmpty ? String(localized: "action_search") : viewModel.displayKeyword)
                    .font(CapsuleStyle.titleFont(20, weight: .bold))
                    .foregroundStyle(CapsuleStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            Spacer(minLength: 8)

            resultCountBadge(
                textColor: CapsuleStyle.accent,
                background: CapsuleStyle.surfaceRaised,
                font: CapsuleStyle.labelFont(15, weight: .bold)
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(CapsuleSurfaceBackground(cornerRadius: 24, elevated: true, tint: CapsuleStyle.surface.opacity(0.92)))
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.bottom, 8)
    }

    func capsuleResultChip(text: String, tint: Color) -> some View {
        Text(text)
            .font(CapsuleStyle.labelFont(10.5, weight: .bold))
            .foregroundStyle(tint)
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(tint.opacity(0.12)))
            .overlay(Capsule().stroke(tint.opacity(0.24), lineWidth: 0.7))
    }

    func resultCountBadge(textColor: Color, background: Color, font: Font) -> some View {
        Group {
            if isPlatformLoading {
                ProgressView()
                    .tint(textColor)
                    .scaleEffect(0.78)
            } else {
                Text("\(selectedPlatformResultCount)")
                    .font(font)
                    .foregroundStyle(textColor)
                    .monospacedDigit()
                    .lineLimit(1)
            }
        }
        .frame(minWidth: 42, minHeight: 38)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(background)
        )
    }

}
