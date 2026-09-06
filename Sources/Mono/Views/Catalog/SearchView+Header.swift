import SwiftUI

extension SearchView {
    // MARK: - 搜索栏

    /// aside：大标题页头，只在未搜索时出现（搜索后让位给结果摘要）
    var defaultSearchHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(String(localized: "action_search"))
                .font(.rounded(size: 32, weight: .heavy))
                .foregroundStyle(Color.monoTextPrimary)

            Spacer(minLength: 12)
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.top, DeviceLayout.headerTopPadding + 6)
        .padding(.bottom, 4)
    }

    var mangaSearchHeader: some View {
        // 周刊印刷刊头:话数眉题 + 错版标题
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                MangaLabel(text: "SEARCH", tint: MangaStyle.labelYellow, small: true)

                MangaMisprintTitle(text: String(localized: "action_search"), size: 26)
            }

            Spacer(minLength: 12)
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.top, DeviceLayout.headerTopPadding + 8)
        .padding(.bottom, 10)
        .monoPageHeaderCollapse()
    }

    /// Muji：检索刊头 —— 圆点眉题 + 衬线大标题
    var mujiSearchHeader: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .center, spacing: 8) {
                MujiDotMark()

                Text("SEARCH DESK")
                    .font(MujiStyle.labelFont(10, weight: .semibold))
                    .foregroundStyle(MujiStyle.clay)
                    .tracking(2.2)
                    .fixedSize()
            }

            Text(String(localized: "action_search"))
                .font(MujiStyle.titleFont(30, weight: .medium))
                .foregroundStyle(MujiStyle.ink)
                .tracking(0.3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.top, DeviceLayout.headerTopPadding + 6)
        .padding(.bottom, 10)
        .monoPageHeaderCollapse()
    }

    var neumorphicSearchHeader: some View {
        Text(String(localized: "action_search"))
            .font(NeumorphicStyle.titleFont(29, weight: .semibold))
            .foregroundStyle(NeumorphicStyle.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
            .padding(.top, DeviceLayout.headerTopPadding + 8)
            .padding(.bottom, 10)
            .monoPageHeaderCollapse()
    }

    var signalSearchHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                SignalBreathingIndicator(size: 6)
                Text("SEARCH")
                    .font(SignalStyle.monoFont(9, weight: .semibold))
                    .foregroundStyle(SignalStyle.inkMuted)
                    .tracking(1.5)
                Rectangle()
                    .fill(SignalStyle.separator.opacity(0.72))
                    .frame(height: 0.65)
            }

            Text(String(localized: "action_search"))
                .font(SignalStyle.titleFont(30, weight: .semibold))
                .foregroundStyle(SignalStyle.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.top, DeviceLayout.headerTopPadding + 6)
        .padding(.bottom, 10)
        .monoPageHeaderCollapse()
    }

    var sequoiaSearchHeader: some View {
        SequoiaPageHeader(
            eyebrow: "Search",
            title: String(localized: "action_search"),
            subtitle: ""
        ) {
            SequoiaIconBadge(icon: .magnifyingGlass, tint: SequoiaStyle.accent, size: 42)
        }
        .padding(.bottom, 2)
    }

    var liquidGlassSearchHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(LiquidGlassStyle.accent.opacity(0.16))
                    .frame(width: 52, height: 52)
                    .blur(radius: 8)

                LiquidGlassIconBadge(icon: .magnifyingGlass, tint: LiquidGlassStyle.accent, size: 46)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 7) {
                    Capsule()
                        .fill(LiquidGlassStyle.accentGradient)
                        .frame(width: 28, height: 5)
                    Capsule()
                        .fill(LiquidGlassStyle.violet.opacity(0.42))
                        .frame(width: 10, height: 5)
                }

                Text(String(localized: "action_search"))
                    .font(LiquidGlassStyle.titleFont(28, weight: .semibold))
                    .foregroundStyle(LiquidGlassStyle.ink)
            }

            Spacer(minLength: 0)

            LiquidGlassPulseGlyphSmall(tint: LiquidGlassStyle.cyan)
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.top, DeviceLayout.headerTopPadding + 8)
        .padding(.bottom, 12)
        .monoPageHeaderCollapse()
    }

    var capsuleSearchHeader: some View {
        Text(String(localized: "action_search"))
            .font(CapsuleStyle.titleFont(26, weight: .bold))
            .foregroundStyle(CapsuleStyle.ink)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.top, DeviceLayout.headerTopPadding + 8)
            .padding(.bottom, 12)
            .monoPageHeaderCollapse()
    }

    var petWhiteSearchHeader: some View {
        PetWhiteSearchHeader()
    }

    var searchBarSection: some View {
        let showFullSearch = isSearchBarExpanded
        let searchRadius = searchBarCornerRadius(showFullSearch: showFullSearch)

        return HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                searchBackButtonLabel
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel(String(localized: "action_back"))

            if !showFullSearch {
                Spacer(minLength: 0)
            }

            HStack(spacing: showFullSearch ? 8 : 0) {
                MonoIcon(icon: .magnifyingGlass, size: 18, color: searchIconColor)

                HStack(spacing: 0) {
                    ZStack(alignment: .leading) {
                        if !isFocused, viewModel.query.isEmpty {
                            if viewModel.hasSearched {
                                if !viewModel.displayKeyword.isEmpty {
                                    Text(viewModel.displayKeyword)
                                        .font(searchFieldFont(weight: .medium))
                                        .foregroundColor(searchPlaceholderColor)
                                        .lineLimit(1)
                                }
                            } else {
                                Text(String(localized: "action_search"))
                                    .font(searchFieldFont(weight: .medium))
                                    .foregroundColor(searchPlaceholderColor)
                                    .lineLimit(1)
                            }
                        }

                        TextField("", text: $viewModel.query)
                            .foregroundColor(searchTextColor)
                            .font(searchFieldFont(weight: .medium))
                            .monoTextInputBehavior()
                            .focused($isFocused)
                            .submitLabel(.search)
                            .monoOnSubmit(text: $viewModel.query) { keyword in
                                submitSearchInput(committedText: keyword)
                            }
                    }

                    if showFullSearch {
                        Button(action: {
                            if viewModel.query.isEmpty {
                                isFocused = false
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    isSearchBarExpanded = false
                                }
                            } else {
                                viewModel.query = ""
                            }
                        }) {
                            MonoIcon(icon: .xmark, size: 18, color: searchIconColor)
                        }
                        .padding(.leading, 8)
                    }
                }
                .frame(maxWidth: showFullSearch ? .infinity : 0)
                .opacity(showFullSearch ? 1 : 0)
                .clipped()
            }
            .padding(.horizontal, showFullSearch ? 16 : 12)
            .padding(.vertical, viewModel.hasSearched ? (NeumorphicStyle.isActive ? 7 : 8) : (showFullSearch ? (SequoiaStyle.isActive ? 9 : 10) : 12))
            .background(
                Group {
                    if MinimalWhiteStyle.isActive {
                        MinimalWhiteSurfaceBackground(
                            cornerRadius: searchRadius,
                            elevated: true,
                            tint: MinimalWhiteStyle.glassStrongFill
                        )
                    } else if MangaStyle.isActive {
                        MangaCardBackground(cornerRadius: searchRadius, elevated: true)
                    } else if MujiStyle.isActive {
                        // Muji：水洗胶囊输入面
                        Capsule()
                            .fill(MujiStyle.wash(MujiStyle.clay, strength: isFocused ? 1.35 : 0.9))
                    } else if NeumorphicStyle.isActive {
                        NeumorphicSurfaceBackground(cornerRadius: searchRadius, elevated: true)
                    } else if SignalStyle.isActive {
                        SignalSurfaceBackground(cornerRadius: searchRadius, elevated: false, fill: SignalStyle.screen)
                    } else if SequoiaStyle.isActive {
                        SequoiaSurfaceBackground(cornerRadius: searchRadius, elevated: true, fill: SequoiaStyle.materialChrome)
                    } else if PetWhiteStyle.isActive {
                        PetWhiteSurfaceBackground(cornerRadius: searchRadius, elevated: true, tint: PetWhiteStyle.surfaceRaised, accent: PetWhiteStyle.sky)
                    } else if CapsuleStyle.isActive {
                        CapsuleSurfaceBackground(cornerRadius: searchRadius, elevated: true, tint: CapsuleStyle.surfaceRaised)
                    }
                }
            )
            .liquidGlassStyle(cornerRadius: searchRadius)
            .onTapGesture {
                if !showFullSearch {
                    viewModel.beginSearchEditing()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isSearchBarExpanded = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        isFocused = true
                    }
                }
            }
        }
        .frame(maxWidth: 720)
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.top, viewModel.hasSearched ? 0 : (ThemedPageStyle.isActive ? 0 : 4))
        .padding(.bottom, viewModel.hasSearched ? (NeumorphicStyle.isActive ? 3 : 6) : (ThemedPageStyle.isActive ? 12 : 6))
        .onChange(of: viewModel.hasSearched) { _, searched in
            if !searched {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isSearchBarExpanded = true
                }
            }
        }
    }

    func submitSearchInput(committedText: String) {
        let committedKeyword = committedText
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let boundKeyword = viewModel.query
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // Return 只能提交用户真正输入的内容。输入法提交瞬间如果 committedText
        // 暂时为空，就使用界面当前 Binding；两者都为空时保持搜索页，不再偷偷
        // 回退到默认热词（例如“畏难而退”）。默认词仅由用户主动点击触发。
        let keyword = committedKeyword.isEmpty ? boundKeyword : committedKeyword

        guard !keyword.isEmpty else {
            isFocused = true
            return
        }

        isFocused = false
        viewModel.performSearch(keyword: keyword)

        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            isSearchBarExpanded = false
        }
    }

    func searchBarCornerRadius(showFullSearch: Bool) -> CGFloat {
        if MinimalWhiteStyle.isActive { return showFullSearch ? 16 : 20 }
        if MangaStyle.isActive { return MangaStyle.cardRadius }
        if PetWhiteStyle.isActive { return showFullSearch ? 20 : 22 }
        if MujiStyle.isActive { return showFullSearch ? 20 : 22 }
        if NeumorphicStyle.isActive { return showFullSearch ? 18 : 20 }
        if SignalStyle.isActive { return 6 }
        if SequoiaStyle.isActive { return showFullSearch ? 16 : 18 }
        if LiquidGlassStyle.isActive { return showFullSearch ? 20 : 24 }
        if CapsuleStyle.isActive { return showFullSearch ? 22 : 24 }
        return showFullSearch ? 16 : 21
    }

    var searchBackButtonLabel: some View {
        let radius = searchBackButtonRadius

        return MonoIcon(icon: PetWhiteStyle.isActive ? .chevronLeft : .back, size: 18, color: searchBackButtonIconColor, lineWidth: 1.8)
            .frame(width: 44, height: 44)
            .background(
                Group {
                    if GlobalThemeId.persistedOrDefault == .default {
                        Color.clear
                    } else if LiquidGlassStyle.isActive {
                        LiquidGlassSurfaceBackground(cornerRadius: radius, elevated: true, role: .list)
                    } else if CapsuleStyle.isActive {
                        CapsuleSurfaceBackground(cornerRadius: radius, elevated: true, tint: CapsuleStyle.surfaceRaised)
                    } else {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(searchBackButtonFill)
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(searchBackButtonStroke, lineWidth: GlobalThemeId.persistedOrDefault == .default ? 0 : searchBackButtonStrokeWidth)
            )
            .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    var searchBackButtonRadius: CGFloat {
        if MinimalWhiteStyle.isActive { return 14 }
        if MangaStyle.isActive { return MangaStyle.buttonRadius }
        if NeumorphicStyle.isActive { return 16 }
        if SignalStyle.isActive { return 4 }
        if SequoiaStyle.isActive { return 15 }
        if LiquidGlassStyle.isActive { return 17 }
        if CapsuleStyle.isActive { return 18 }
        return 21
    }

    var searchBackButtonFill: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.glassStrongFill }
        if MangaStyle.isActive { return MangaStyle.surface }
        if PetWhiteStyle.isActive { return PetWhiteStyle.surfaceRaised }
        if MujiStyle.isActive { return Color.clear }
        if NeumorphicStyle.isActive { return NeumorphicStyle.surfaceRaised }
        if SignalStyle.isActive { return Color.clear }
        if SequoiaStyle.isActive { return SequoiaStyle.materialRaised }
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.glassList }
        if CapsuleStyle.isActive { return CapsuleStyle.surfaceRaised }
        return Color.monoTextPrimary.opacity(0.04)
    }

    var searchBackButtonStroke: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.hairline }
        if MangaStyle.isActive { return MangaStyle.ink }
        if PetWhiteStyle.isActive { return PetWhiteStyle.stroke }
        if MujiStyle.isActive { return MujiStyle.hairline.opacity(0.75) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.separator.opacity(0.4) }
        if SignalStyle.isActive { return Color.clear }
        if SequoiaStyle.isActive { return SequoiaStyle.separator }
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.luminousEdge.opacity(0.48) }
        if CapsuleStyle.isActive { return CapsuleStyle.separator.opacity(0.58) }
        return Color.monoTextPrimary.opacity(0.05)
    }

    var searchBackButtonStrokeWidth: CGFloat {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.strokeWidth }
        if MangaStyle.isActive { return MangaStyle.strokeWidth }
        if PetWhiteStyle.isActive { return 1 }
        if MujiStyle.isActive { return 0.8 }
        if CapsuleStyle.isActive { return 0.8 }
        return 0.5
    }

    var searchBackButtonIconColor: Color {
        if MujiStyle.isActive { return MujiStyle.ink }
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.ink }
        if PetWhiteStyle.isActive { return PetWhiteStyle.ink }
        if SignalStyle.isActive { return SignalStyle.ink }
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        if SequoiaStyle.isActive { return SequoiaStyle.ink }
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.ink }
        if CapsuleStyle.isActive { return CapsuleStyle.ink }
        return .monoTextPrimary
    }

    var searchIconColor: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.inkMuted }
        if MangaStyle.isActive { return MangaStyle.inkMuted }
        if PetWhiteStyle.isActive { return PetWhiteStyle.inkSoft }
        if MujiStyle.isActive { return MujiStyle.inkMuted }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        if SignalStyle.isActive { return SignalStyle.inkSoft }
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.inkSoft }
        if CapsuleStyle.isActive { return CapsuleStyle.inkSoft }
        return .gray
    }

    var searchPlaceholderColor: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.inkMuted }
        if MangaStyle.isActive { return MangaStyle.inkMuted }
        if PetWhiteStyle.isActive { return PetWhiteStyle.inkMuted }
        if MujiStyle.isActive { return MujiStyle.inkMuted }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkMuted }
        if SignalStyle.isActive { return SignalStyle.inkMuted }
        if SequoiaStyle.isActive { return SequoiaStyle.inkMuted }
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.inkMuted }
        if CapsuleStyle.isActive { return CapsuleStyle.inkMuted }
        return .monoTextSecondary.opacity(0.6)
    }

    var searchTextColor: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.ink }
        if MangaStyle.isActive { return MangaStyle.ink }
        if PetWhiteStyle.isActive { return PetWhiteStyle.ink }
        if MujiStyle.isActive { return MujiStyle.ink }
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        if SignalStyle.isActive { return SignalStyle.ink }
        if SequoiaStyle.isActive { return SequoiaStyle.ink }
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.ink }
        if CapsuleStyle.isActive { return CapsuleStyle.ink }
        return .monoTextPrimary
    }

    func searchFieldFont(weight: Font.Weight) -> Font {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.bodyFont(15, weight: weight) }
        if MangaStyle.isActive { return MangaStyle.comicFont(15, weight: weight == .bold ? .bold : .medium) }
        if PetWhiteStyle.isActive { return PetWhiteStyle.bodyFont(15, weight: .semibold) }
        if MujiStyle.isActive { return MujiStyle.bodyFont(15.5, weight: .regular) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(15, weight: .medium) }
        if SignalStyle.isActive { return SignalStyle.labelFont(15, weight: .semibold) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(15, weight: .regular) }
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.labelFont(15, weight: .medium) }
        if CapsuleStyle.isActive { return CapsuleStyle.labelFont(15, weight: .semibold) }
        return .rounded(size: 16, weight: .medium)
    }

    // MARK: - 搜索类型 Tab 栏

    @ViewBuilder
    var searchTabBar: some View {
        if MangaStyle.isActive {
            mangaSearchTabBar
        } else if PetWhiteStyle.isActive {
            petWhiteSearchTabBar
        } else if NeumorphicStyle.isActive {
            neumorphicSearchTabBar
        } else if SignalStyle.isActive {
            signalSearchTabBar
        } else if MujiStyle.isActive {
            mujiSearchTabBar
        } else if SequoiaStyle.isActive {
            sequoiaSearchTabBar
        } else if LiquidGlassStyle.isActive {
            liquidGlassSearchTabBar
        } else if CapsuleStyle.isActive {
            capsuleSearchTabBar
        } else {
            // aside：左对齐杂志式类型页签，短下划线锚在文字下方
            HStack(spacing: 24) {
                ForEach(SearchTab.allCases, id: \.self) { tab in
                    let selected = viewModel.currentTab == tab

                    Button(action: {
                        viewModel.switchTab(tab)
                    }) {
                        VStack(spacing: 5) {
                            Text(tab.rawValue)
                                .font(.rounded(size: 15, weight: selected ? .heavy : .medium))
                                .foregroundColor(
                                    selected
                                        ? .monoTextPrimary
                                        : .monoTextSecondary.opacity(0.85)
                                )
                                .animation(.none, value: viewModel.currentTab)

                            Capsule()
                                .fill(Color.monoAccent)
                                .frame(width: 16, height: 3)
                                .opacity(selected ? 1 : 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.top, 10)
            .padding(.bottom, 6)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.currentTab)
        }
    }

    /// Muji：清新页签 —— 衬线文字 + 选中圆点标记
    var mujiSearchTabBar: some View {
        HStack(spacing: 24) {
            ForEach(SearchTab.allCases, id: \.self) { tab in
                let selected = viewModel.currentTab == tab

                Button {
                    viewModel.switchTab(tab)
                } label: {
                    VStack(spacing: 5) {
                        Text(tab.rawValue)
                            .font(MujiStyle.bodyFont(14.5, weight: selected ? .medium : .regular))
                            .foregroundStyle(selected ? MujiStyle.ink : MujiStyle.inkMuted)
                            .animation(.none, value: viewModel.currentTab)

                        Circle()
                            .fill(MujiStyle.clay)
                            .frame(width: 4.5, height: 4.5)
                            .opacity(selected ? 1 : 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.top, viewModel.hasSearched ? 6 : 10)
        .padding(.bottom, 6)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.currentTab)
    }

    var neumorphicSearchTabBar: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = viewModel.hasSearched ? 7 : 8
            let itemWidth = searchTabItemWidth(totalWidth: proxy.size.width, spacing: spacing)

            HStack(spacing: spacing) {
                ForEach(SearchTab.allCases, id: \.self) { tab in
                    Button {
                        viewModel.switchTab(tab)
                    } label: {
                        let selected = viewModel.currentTab == tab
                        HStack(spacing: viewModel.hasSearched ? 0 : 6) {
                            if !viewModel.hasSearched {
                                MonoIcon(
                                    icon: searchTabIcon(tab),
                                    size: 12,
                                    color: selected ? NeumorphicStyle.accent : NeumorphicStyle.inkSoft,
                                    lineWidth: 1.55
                                )
                            }

                            Text(tab.rawValue)
                                .font(NeumorphicStyle.labelFont(viewModel.hasSearched ? 11.5 : 12.5, weight: selected ? .semibold : .medium))
                                .foregroundStyle(selected ? NeumorphicStyle.ink : NeumorphicStyle.inkSoft)
                        }
                        .frame(width: itemWidth)
                        .padding(.vertical, viewModel.hasSearched ? 6 : 9)
                        .background(
                            NeumorphicSurfaceBackground(
                                cornerRadius: viewModel.hasSearched ? 12 : 15,
                                elevated: selected,
                                pressed: !selected,
                                tint: selected ? NeumorphicStyle.accent.opacity(0.16) : NeumorphicStyle.surface
                            )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.vertical, viewModel.hasSearched ? 2 : 8)
        }
        .frame(height: viewModel.hasSearched ? 40 : 52)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var signalSearchTabBar: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = 0
            let itemWidth = searchTabItemWidth(totalWidth: proxy.size.width, spacing: spacing)

            HStack(spacing: spacing) {
                ForEach(SearchTab.allCases, id: \.self) { tab in
                    Button {
                        viewModel.switchTab(tab)
                    } label: {
                        let selected = viewModel.currentTab == tab
                        VStack(spacing: 6) {
                            MonoIcon(
                                icon: searchTabIcon(tab),
                                size: 12,
                                color: selected ? SignalStyle.accent : SignalStyle.inkMuted,
                                lineWidth: 1.6
                            )

                            Text(tab.rawValue)
                                .font(SignalStyle.labelFont(viewModel.hasSearched ? 10.5 : 11.5, weight: selected ? .semibold : .medium))
                                .foregroundStyle(selected ? SignalStyle.ink : SignalStyle.inkMuted)

                            Rectangle()
                                .fill(selected ? SignalStyle.accent : Color.clear)
                                .frame(width: 18, height: 1.5)
                        }
                        .frame(width: itemWidth)
                        .padding(.vertical, viewModel.hasSearched ? 5 : 7)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.vertical, viewModel.hasSearched ? 2 : 8)
        }
        .frame(height: viewModel.hasSearched ? 48 : 58)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var sequoiaSearchTabBar: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = viewModel.hasSearched ? 5 : 6
            let itemWidth = searchTabItemWidth(totalWidth: proxy.size.width, spacing: spacing)

            HStack(spacing: spacing) {
                ForEach(SearchTab.allCases, id: \.self) { tab in
                    Button {
                        viewModel.switchTab(tab)
                    } label: {
                        let selected = viewModel.currentTab == tab
                        HStack(spacing: viewModel.hasSearched ? 0 : 6) {
                            if !viewModel.hasSearched {
                                MonoIcon(
                                    icon: searchTabIcon(tab),
                                    size: 12,
                                    color: selected ? SequoiaStyle.accent : SequoiaStyle.inkSoft,
                                    lineWidth: 1.5
                                )
                            }

                            Text(tab.rawValue)
                                .font(SequoiaStyle.labelFont(viewModel.hasSearched ? 11.5 : 12.5, weight: selected ? .semibold : .medium))
                                .foregroundStyle(selected ? SequoiaStyle.ink : SequoiaStyle.inkSoft)
                        }
                        .frame(width: itemWidth)
                        .padding(.vertical, viewModel.hasSearched ? 6 : 9)
                        .background {
                            if selected {
                                RoundedRectangle(cornerRadius: viewModel.hasSearched ? 11 : 14, style: .continuous)
                                    .fill(SequoiaStyle.selectedWash)
                                    .matchedGeometryEffect(id: "search-tab", in: sequoiaSearchNamespace)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: viewModel.hasSearched ? 11 : 14, style: .continuous)
                                            .stroke(SequoiaStyle.accent.opacity(0.24), lineWidth: 0.56)
                                    )
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(5)
            .background(SequoiaSurfaceBackground(cornerRadius: viewModel.hasSearched ? 15 : 18, elevated: true, role: .chrome))
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.vertical, viewModel.hasSearched ? 2 : 7)
        }
        .frame(height: viewModel.hasSearched ? 48 : 58)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var mangaSearchTabBar: some View {
        // 报刊栏目条：文字页签 + 选中朱红下划线，夹在上下规则线之间
        GeometryReader { proxy in
            let spacing: CGFloat = 0
            let itemWidth = searchTabItemWidth(totalWidth: proxy.size.width, spacing: spacing)

            VStack(spacing: 0) {
                Rectangle()
                    .fill(MangaStyle.ink.opacity(0.7))
                    .frame(height: 1.4)

                HStack(spacing: spacing) {
                    ForEach(SearchTab.allCases, id: \.self) { tab in
                        let selected = viewModel.currentTab == tab
                        Button {
                            viewModel.switchTab(tab)
                        } label: {
                            VStack(spacing: 5) {
                                Text(tab.rawValue)
                                    .font(MangaStyle.labelFont(13, weight: selected ? .black : .bold))
                                    .foregroundStyle(selected ? MangaStyle.ink : MangaStyle.inkMuted)

                                Rectangle()
                                    .fill(selected ? MangaStyle.accentPink : Color.clear)
                                    .frame(height: 2.5)
                                    .padding(.horizontal, 10)
                            }
                            .frame(width: itemWidth)
                            .padding(.top, 9)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                Rectangle()
                    .fill(MangaStyle.ink.opacity(0.28))
                    .frame(height: 0.8)
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.vertical, 8)
        }
        .frame(height: 56)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var petWhiteSearchTabBar: some View {
        PetWhiteSearchTabBar(
            currentTab: viewModel.currentTab,
            hasSearched: viewModel.hasSearched,
            iconProvider: searchTabIcon,
            onSelect: viewModel.switchTab
        )
    }

    var liquidGlassSearchTabBar: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = viewModel.hasSearched ? 6 : 7
            let itemWidth = searchTabItemWidth(totalWidth: proxy.size.width, spacing: spacing)

            HStack(spacing: spacing) {
                ForEach(SearchTab.allCases, id: \.self) { tab in
                    Button {
                        viewModel.switchTab(tab)
                    } label: {
                        let selected = viewModel.currentTab == tab
                        HStack(spacing: viewModel.hasSearched ? 0 : 6) {
                            if !viewModel.hasSearched {
                                MonoIcon(
                                    icon: searchTabIcon(tab),
                                    size: 12,
                                    color: selected ? LiquidGlassStyle.onAccent : LiquidGlassStyle.inkSoft,
                                    lineWidth: 1.5
                                )
                            }

                            Text(tab.rawValue)
                                .font(LiquidGlassStyle.labelFont(viewModel.hasSearched ? 11 : 12.5, weight: selected ? .semibold : .medium))
                                .foregroundStyle(selected ? LiquidGlassStyle.onAccent : LiquidGlassStyle.inkSoft)
                                .lineLimit(1)
                        }
                        .frame(width: itemWidth)
                        .padding(.vertical, viewModel.hasSearched ? 6 : 9)
                        .background(
                            Capsule()
                                .fill(selected ? LiquidGlassStyle.accent.opacity(0.88) : LiquidGlassStyle.glassList.opacity(0.58))
                                .overlay(
                                    Capsule()
                                        .stroke(selected ? Color.white.opacity(0.42) : LiquidGlassStyle.separator.opacity(0.7), lineWidth: 0.55)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(5)
            .background(LiquidGlassChromeBar(cornerRadius: viewModel.hasSearched ? 17 : 20))
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.vertical, viewModel.hasSearched ? 2 : 7)
        }
        .frame(height: viewModel.hasSearched ? 48 : 58)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var capsuleSearchTabBar: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = viewModel.hasSearched ? 6 : 8
            let itemWidth = searchTabItemWidth(totalWidth: proxy.size.width, spacing: spacing)

            HStack(spacing: spacing) {
                ForEach(SearchTab.allCases, id: \.self) { tab in
                    Button {
                        viewModel.switchTab(tab)
                    } label: {
                        let selected = viewModel.currentTab == tab
                        HStack(spacing: viewModel.hasSearched ? 0 : 6) {
                            if !viewModel.hasSearched {
                                MonoIcon(
                                    icon: searchTabIcon(tab),
                                    size: 12,
                                    color: selected ? CapsuleStyle.onAccent : CapsuleStyle.inkSoft,
                                    lineWidth: 1.65
                                )
                            }

                            Text(tab.rawValue)
                                .font(CapsuleStyle.labelFont(viewModel.hasSearched ? 11 : 12.5, weight: selected ? .bold : .semibold))
                                .foregroundStyle(selected ? CapsuleStyle.onAccent : CapsuleStyle.inkSoft)
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)
                        }
                        .frame(width: itemWidth)
                        .padding(.vertical, viewModel.hasSearched ? 7 : 9)
                        .background(
                            Capsule()
                                .fill(selected ? CapsuleStyle.accent : CapsuleStyle.surfaceRaised.opacity(0.72))
                                .overlay(
                                    Capsule()
                                        .stroke(selected ? Color.white.opacity(0.34) : CapsuleStyle.separator.opacity(0.42), lineWidth: 0.8)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(5)
            .background(CapsuleSurfaceBackground(cornerRadius: viewModel.hasSearched ? 18 : 21, elevated: true, tint: CapsuleStyle.surface.opacity(0.88)))
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.vertical, viewModel.hasSearched ? 2 : 7)
        }
        .frame(height: viewModel.hasSearched ? 48 : 58)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func searchTabItemWidth(totalWidth: CGFloat, spacing: CGFloat) -> CGFloat {
        let count = CGFloat(SearchTab.allCases.count)
        let horizontalPadding = DeviceLayout.viewHorizontalPadding * 2
        let totalSpacing = spacing * max(count - 1, 0)
        let available = max(totalWidth - horizontalPadding - totalSpacing, 0)
        return max(floor(available / count), 44)
    }

}
