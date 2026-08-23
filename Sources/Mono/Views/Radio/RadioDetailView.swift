import SwiftUI

/// 电台详情页面，展示电台信息和节目列表
struct RadioDetailView: View {
    let radioId: Int
    @StateObject private var viewModel: RadioDetailViewModel
    @ObservedObject private var player = PlayerManager.shared
    @ObservedObject private var subManager = SubscriptionManager.shared
    @ObservedObject private var settings = SettingsManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showRadioPlayer = false
    @State private var isSearchExpanded = false
    @State private var searchText = ""
    @State private var scrollOffset: CGFloat = 0
    @State private var showDescSheet = false
    @FocusState private var isSearchFieldFocused: Bool
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    init(radioId: Int) {
        self.radioId = radioId
        _viewModel = StateObject(wrappedValue: RadioDetailViewModel(radioId: radioId))
    }

    /// aside 主题走歌手页式 Hero 头部
    private var usesAsideHero: Bool {
        !ThemedPageStyle.isActive
    }

    var body: some View {
        let _ = settings.globalThemeRevision

        ZStack {
            if MangaStyle.isActive {
                MangaRootBackdrop()
            } else if MujiStyle.isActive {
                MujiRootBackdrop()
            } else {
                ThemedPageBackground()
                    .ignoresSafeArea()
            }

            if viewModel.isLoading && viewModel.radioDetail == nil {
                MonoLoadingView(text: "LOADING")
            } else if let error = viewModel.errorMessage, viewModel.radioDetail == nil {
                errorView(error)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        if usesAsideHero {
                            asideHeaderSection
                        } else {
                            headerSection
                                .monoPageHeaderCollapse()
                        }
                        programListSection
                    }
                    .padding(.bottom, 120)
                }
                .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
            .monoScrollOffset($scrollOffset)
            .ignoresSafeArea(edges: usesAsideHero ? .top : [])
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .monoNavigationBackButton()
        .monoSheet(isPresented: $showDescSheet, preset: .standard) {
            PlaylistDescSheet(
                coverUrl: viewModel.radioDetail?.coverUrl,
                title: viewModel.radioDetail?.name ?? "",
                subtitle: viewModel.radioDetail?.dj?.nickname,
                descriptionText: viewModel.radioDetail?.desc
            )
        }
        .onAppear {
            if viewModel.radioDetail == nil {
                viewModel.fetchDetail()
            }
        }
        .onChange(of: isSearchExpanded) { _, isExpanded in
            if isExpanded {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    isSearchFieldFocused = true
                }
            } else {
                searchText = ""
                isSearchFieldFocused = false
            }
        }
        .onChange(of: searchText) { _, _ in
            loadAllProgramsForSearchIfNeeded()
        }
        .onChange(of: viewModel.programs.count) { _, _ in
            loadAllProgramsForSearchIfNeeded()
        }
        .fullScreenCover(isPresented: $showRadioPlayer) {
            PodcastPlayerView(radioId: radioId)
        }
    }

    // MARK: - 错误视图

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            MonoIcon(icon: .warning, size: 40, color: SequoiaStyle.isActive ? SequoiaStyle.inkSoft : .monoTextSecondary)
            Text(error)
                .font(MangaStyle.isActive ? MangaStyle.bodyFont(14, weight: .bold) : (MujiStyle.isActive ? MujiStyle.labelFont(14, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(14, weight: .medium) : (SequoiaStyle.isActive ? SequoiaStyle.labelFont(14, weight: .regular) : .system(size: 14, design: .rounded)))))
                .foregroundColor(MangaStyle.isActive ? MangaStyle.inkSub : (MujiStyle.isActive ? MujiStyle.inkSoft : (NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : (SequoiaStyle.isActive ? SequoiaStyle.inkSoft : .monoTextSecondary))))
                .multilineTextAlignment(.center)
            Button(String(localized: "radio_retry")) {
                viewModel.fetchDetail()
            }
            .font(MangaStyle.isActive ? MangaStyle.labelFont(15, weight: .black) : (MujiStyle.isActive ? MujiStyle.labelFont(15, weight: .semibold) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(15, weight: .semibold) : (SequoiaStyle.isActive ? SequoiaStyle.labelFont(15, weight: .semibold) : .system(size: 15, weight: .medium, design: .rounded)))))
            .foregroundColor(MangaStyle.isActive ? ThemeColorCustomization.readableForegroundColor(on: MangaStyle.labelYellow, light: MangaStyle.strokeInk, dark: MangaStyle.onStrokeInk) : (MujiStyle.isActive ? MujiStyle.onTint : (NeumorphicStyle.isActive ? Color(light: .white, dark: .black) : (SequoiaStyle.isActive ? SequoiaStyle.onAccent : .monoIconForeground))))
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(
                MangaStyle.isActive ? MangaStyle.labelYellow : (MujiStyle.isActive ? MujiStyle.clay : (NeumorphicStyle.isActive ? NeumorphicStyle.accent : (SequoiaStyle.isActive ? SequoiaStyle.accent : Color.monoIconBackground))),
                in: MangaStyle.isActive ? AnyShape(RoundedRectangle(cornerRadius: MangaStyle.buttonRadius, style: .continuous)) : AnyShape(Capsule())
            )
        }
        .padding(.horizontal, 40)
    }

    // MARK: - aside Hero 头部

    private var asideHeaderSection: some View {
        Group {
            if let radio = viewModel.radioDetail {
                AsideDetailHeroHeader(
                    coverUrl: radio.coverUrl?.sized(800),
                    title: radio.name,
                    subtitle: radio.dj?.nickname,
                    metaItems: asideHeroMetaItems(for: radio),
                    descriptionText: radio.desc,
                    onDescriptionTap: { showDescSheet = true },
                    scrollOffset: scrollOffset,
                    playAllTitle: String(localized: "radio_mode"),
                    playAllDisabled: false,
                    onPlayAll: { showRadioPlayer = true }
                ) {
                    SubscribeButton(
                        isSubscribed: subManager.isRadioSubscribed(radio.id),
                        action: { subManager.toggleRadioSubscription(radio) }
                    )
                }
                .padding(.bottom, 20)
            }
        }
    }

    private func asideHeroMetaItems(for radio: RadioStation) -> [String] {
        var items: [String] = []
        if let count = radio.programCount {
            items.append(String(format: String(localized: "radio_episode_count"), count))
        }
        if let subCount = radio.subCount, subCount > 0 {
            items.append(String(format: String(localized: "radio_sub_count"), formatCount(subCount)))
        }
        if let category = radio.category, !category.isEmpty {
            items.append(category)
        }
        return items
    }

    // MARK: - 电台头部信息

    private var headerSection: some View {
        VStack(spacing: 16) {
            if let radio = viewModel.radioDetail {
                CachedAsyncImage(url: radio.coverUrl) {
                    RoundedRectangle(cornerRadius: radioCoverRadius)
                        .fill(radioCoverPlaceholderFill)
                }
                .frame(width: radioCoverSize, height: radioCoverSize)
                .clipShape(RoundedRectangle(cornerRadius: radioCoverRadius, style: .continuous))
                .overlay {
                    if MangaStyle.isActive {
                        RoundedRectangle(cornerRadius: radioCoverRadius, style: .continuous)
                            .stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.strokeWidth)
                    } else if MujiStyle.isActive {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(MujiStyle.hairline.opacity(0.62), lineWidth: 0.65)
                    } else if NeumorphicStyle.isActive {
                        RoundedRectangle(cornerRadius: radioCoverRadius, style: .continuous)
                            .stroke(NeumorphicStyle.separator.opacity(0.55), lineWidth: 0.75)
                    } else if SequoiaStyle.isActive {
                        RoundedRectangle(cornerRadius: radioCoverRadius, style: .continuous)
                            .stroke(SequoiaStyle.separator.opacity(0.78), lineWidth: 0.65)
                    } else if BentoStyle.isActive {
                        RoundedRectangle(cornerRadius: radioCoverRadius, style: .continuous)
                            .stroke(BentoStyle.hairline.opacity(0.58), lineWidth: 0.7)
                    }
                }
                .background {
                    if MangaStyle.isActive {
                        RoundedRectangle(cornerRadius: radioCoverRadius, style: .continuous)
                            .fill(MangaStyle.strokeInk)
                            .offset(x: MangaStyle.shadowOffset, y: MangaStyle.shadowOffset)
                    } else if NeumorphicStyle.isActive {
                        NeumorphicSurfaceBackground(cornerRadius: radioCoverRadius, elevated: true)
                    } else if SequoiaStyle.isActive {
                        SequoiaSurfaceBackground(cornerRadius: radioCoverRadius + 6, elevated: true, role: .chrome)
                    } else if BentoStyle.isActive {
                        RoundedRectangle(cornerRadius: radioCoverRadius + 4, style: .continuous)
                            .fill(BentoStyle.surface)
                            .shadow(color: BentoStyle.ink.opacity(0.07), radius: 12, x: 0, y: 6)
                    }
                }
                .shadow(color: .black.opacity(ThemedPageStyle.isActive ? 0.055 : 0.15), radius: ThemedPageStyle.isActive ? 10 : 12, x: 0, y: ThemedPageStyle.isActive ? 5 : 6)

                Text(radio.name)
                    .font(radioTitleFont)
                    .foregroundColor(radioTitleColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                HStack(spacing: 16) {
                    if let dj = radio.dj?.nickname {
                        HStack(spacing: 4) {
                            MonoIcon(icon: .profile, size: 13, color: radioMetaColor)
                            Text(dj)
                        }
                            .font(radioMetaFont)
                            .foregroundColor(radioMetaColor)
                    }
                    if let count = radio.programCount {
                        HStack(spacing: 4) {
                            MonoIcon(icon: .podcast, size: 13, color: radioMetaColor)
                            Text(String(format: String(localized: "radio_episode_count"), count))
                        }
                            .font(radioMetaFont)
                            .foregroundColor(radioMetaColor)
                    }
                }

                if let desc = radio.desc, !desc.isEmpty {
                    Text(desc)
                        .font(radioDescriptionFont)
                        .foregroundColor(radioMetaColor)
                        .lineLimit(3)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }

                // 操作按钮
                HStack(spacing: 12) {
                    // 订阅按钮
                    SubscribeButton(
                        isSubscribed: subManager.isRadioSubscribed(radio.id),
                        action: { subManager.toggleRadioSubscription(radio) }
                    )

                    // 收音机模式播放按钮
                    Button(action: { showRadioPlayer = true }) {
                        if MangaStyle.isActive {
                            MangaLabel(text: String(localized: "radio_mode"), tint: MangaStyle.labelYellow, small: false)
                        } else if MujiStyle.isActive {
                            MujiActionPill(title: String(localized: "radio_mode"), icon: .radio, selected: true, tint: MujiStyle.indigo)
                        } else if NeumorphicStyle.isActive {
                            NeumorphicPlayPill(title: String(localized: "radio_mode"), icon: .radio, tint: NeumorphicStyle.sage)
                        } else if SequoiaStyle.isActive {
                            SequoiaPill(text: String(localized: "radio_mode"), icon: .radio, tint: SequoiaStyle.aqua, selected: true)
                        } else if BentoStyle.isActive {
                            HStack(spacing: 8) {
                                MonoIcon(icon: .radio, size: 15, color: BentoStyle.onAccent, lineWidth: 1.8)
                                Text("radio_mode")
                                    .font(BentoStyle.labelFont(13, weight: .black))
                            }
                            .foregroundStyle(BentoStyle.onAccent)
                            .padding(.horizontal, 18)
                            .frame(height: 40)
                            .background(BentoStyle.nori, in: Capsule())
                        } else {
                            HStack(spacing: 8) {
                                MonoIcon(icon: .radio, size: 16, color: .monoIconForeground, lineWidth: 1.4)
                                Text("radio_mode")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                            }
                            .foregroundColor(.monoIconForeground)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.monoIconBackground)
                            .clipShape(Capsule())
                        }
                    }
                    .buttonStyle(MonoBouncingButtonStyle())
                }
                .padding(.top, 4)

                if MangaStyle.isActive {
                    MangaListDivider()
                        .padding(.top, 6)
                } else if MujiStyle.isActive {
                    MujiListDivider()
                        .padding(.top, 6)
                } else if NeumorphicStyle.isActive {
                    Divider()
                        .overlay(NeumorphicStyle.separator.opacity(0.6))
                        .padding(.top, 10)
                        .padding(.horizontal, 18)
                } else if SequoiaStyle.isActive {
                    SequoiaHairline(tint: SequoiaStyle.separator)
                        .padding(.top, 10)
                        .padding(.horizontal, 18)
                } else if BentoStyle.isActive {
                    BentoDivider()
                        .padding(.top, 10)
                        .padding(.horizontal, 18)
                }
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 24)
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .background {
            if MangaStyle.isActive && viewModel.radioDetail != nil {
                // 电台详情页唯一焦点分格：保留厚墨框错版投影
                MangaCardBackground(cornerRadius: MangaStyle.cardRadius + 4, elevated: true, tint: MangaStyle.bubbleWhite, poster: true)
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
            } else if NeumorphicStyle.isActive && viewModel.radioDetail != nil {
                NeumorphicSurfaceBackground(cornerRadius: 28, elevated: true)
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
            } else if SequoiaStyle.isActive && viewModel.radioDetail != nil {
                SequoiaGlassBand(tint: SequoiaStyle.aqua, cornerRadius: 28)
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
            } else if BentoStyle.isActive && viewModel.radioDetail != nil {
                RoundedRectangle(cornerRadius: BentoStyle.blockRadiusLarge, style: .continuous)
                    .fill(BentoStyle.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: BentoStyle.blockRadiusLarge, style: .continuous)
                            .stroke(BentoStyle.hairline.opacity(0.58), lineWidth: 0.7)
                    )
                    .padding(.horizontal, BentoStyle.blockSpacing)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
            }
        }
    }

    private var radioCoverRadius: CGFloat {
        if MangaStyle.isActive { return MangaStyle.cardRadius }
        if MujiStyle.isActive { return 10 }
        if NeumorphicStyle.isActive { return 26 }
        if SequoiaStyle.isActive { return 24 }
        if BentoStyle.isActive { return 24 }
        return 20
    }

    private var radioCoverSize: CGFloat {
        if NeumorphicStyle.isActive { return 148 }
        if SequoiaStyle.isActive { return 148 }
        if MangaStyle.isActive { return 150 }
        if BentoStyle.isActive { return 142 }
        return 160
    }

    private var radioCoverPlaceholderFill: Color {
        if MangaStyle.isActive { return MangaStyle.paperCool }
        if MujiStyle.isActive { return MujiStyle.surfaceRaised }
        if NeumorphicStyle.isActive { return NeumorphicStyle.surfacePressed }
        if SequoiaStyle.isActive { return SequoiaStyle.materialList }
        if BentoStyle.isActive { return BentoStyle.buckwheat.opacity(0.45) }
        return Color.monoGlassTint
    }

    private var radioTitleFont: Font {
        if MangaStyle.isActive { return MangaStyle.titleFont(24, weight: .black) }
        if MujiStyle.isActive { return MujiStyle.titleFont(24, weight: .regular) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.titleFont(24, weight: .semibold) }
        if SequoiaStyle.isActive { return SequoiaStyle.titleFont(24, weight: .semibold) }
        if BentoStyle.isActive { return BentoStyle.displayFont(24, weight: .black) }
        return .system(size: 20, weight: .bold, design: .rounded)
    }

    private var radioTitleColor: Color {
        if MangaStyle.isActive { return MangaStyle.ink }
        if MujiStyle.isActive { return MujiStyle.ink }
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        if SequoiaStyle.isActive { return SequoiaStyle.ink }
        if BentoStyle.isActive { return BentoStyle.ink }
        return .monoTextPrimary
    }

    private var radioMetaFont: Font {
        if MangaStyle.isActive { return MangaStyle.bodyFont(13, weight: .bold) }
        if MujiStyle.isActive { return MujiStyle.labelFont(13, weight: .regular) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(13, weight: .medium) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(13, weight: .regular) }
        if BentoStyle.isActive { return BentoStyle.labelFont(12, weight: .semibold) }
        return .system(size: 13, design: .rounded)
    }

    private var radioMetaColor: Color {
        if MangaStyle.isActive { return MangaStyle.inkSub }
        if MujiStyle.isActive { return MujiStyle.inkSoft }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        if BentoStyle.isActive { return BentoStyle.inkSoft }
        return .monoTextSecondary
    }

    private var radioDescriptionFont: Font {
        if MangaStyle.isActive { return MangaStyle.bodyFont(13, weight: .bold) }
        if MujiStyle.isActive { return MujiStyle.bodyFont(13, weight: .regular) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.bodyFont(13, weight: .regular) }
        if SequoiaStyle.isActive { return SequoiaStyle.bodyFont(13, weight: .regular) }
        if BentoStyle.isActive { return BentoStyle.bodyFont(13, weight: .medium) }
        return .system(size: 13, design: .rounded)
    }

    // MARK: - 节目列表

    private var programListSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !viewModel.programs.isEmpty {
                VStack(spacing: 0) {
                    HStack {
                        if usesAsideHero {
                            HStack(spacing: 10) {
                                Capsule()
                                    .fill(Color.monoAccent)
                                    .frame(width: 4, height: 15)
                                Text("radio_program_list_title")
                                    .font(.rounded(size: 19, weight: .bold))
                                    .foregroundColor(.monoTextPrimary)
                            }
                        } else {
                            Text("radio_program_list_title")
                                .font(programListTitleFont)
                                .foregroundColor(programListTitleColor)
                        }

                        Spacer()

                        Button(action: { viewModel.toggleEpisodeOrder() }) {
                            HStack(spacing: 5) {
                                MonoIcon(icon: .filter, size: 11, color: listControlColor, lineWidth: 1.4)
                                Text(
                                    viewModel.isAscendingOrder
                                        ? String(localized: "podcast_sort_oldest")
                                        : String(localized: "podcast_sort_latest")
                                )
                                .font(listControlFont)
                                .foregroundColor(listControlColor)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(listControlBackground, in: Capsule())
                            .overlay(Capsule().stroke(listControlStroke, lineWidth: NeumorphicStyle.isActive ? 0.7 : 0.6))
                        }
                        .buttonStyle(MonoBouncingButtonStyle(scale: 0.95))

                        Button(action: toggleSearch) {
                            MonoIcon(
                                icon: isSearchExpanded ? .close : .search,
                                size: 13,
                                color: listControlColor
                            )
                            .frame(width: 32, height: 32)
                            .background(listControlBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(listControlStroke, lineWidth: NeumorphicStyle.isActive ? 0.7 : 0.6)
                            )
                        }
                        .buttonStyle(MonoBouncingButtonStyle(scale: 0.92))
                        .accessibilityLabel(
                            isSearchExpanded
                                ? String(localized: "podcast_search_cancel")
                                : String(localized: "tab_search")
                        )
                    }
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)

                    if isSearchExpanded {
                        HStack(spacing: 10) {
                            MonoIcon(icon: .search, size: 14, color: listControlColor)

                            TextField(
                                String(localized: "podcast_episode_search_placeholder"),
                                text: $searchText
                            )
                            .monoTextInputBehavior()
                            .focused($isSearchFieldFocused)

                            Button {
                                if searchText.isEmpty {
                                    toggleSearch()
                                } else {
                                    searchText = ""
                                }
                            } label: {
                                MonoIcon(icon: .close, size: 12, color: listControlColor)
                                    .frame(width: 22, height: 22)
                                    .background(searchCloseBackground)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(searchFieldBackground)
                        .clipShape(RoundedRectangle(cornerRadius: searchFieldRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: searchFieldRadius, style: .continuous)
                                .stroke(listControlStroke, lineWidth: NeumorphicStyle.isActive ? 0.7 : 0.6)
                        )
                        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                        .padding(.top, 10)
                    }
                }
                .padding(.bottom, 12)
            }

            LazyVStack(spacing: 0) {
                if filteredOrderedPrograms.isEmpty && !searchKeyword.isEmpty {
                    VStack(spacing: 12) {
                        MonoIcon(icon: .search, size: 36, color: programMetaColor.opacity(0.42))
                        Text("podcast_episode_search_empty")
                            .font(SequoiaStyle.isActive ? SequoiaStyle.labelFont(14, weight: .medium) : .system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(programMetaColor)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 32)
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                }

                ForEach(Array(filteredOrderedPrograms.enumerated()), id: \.element.id) { index, program in
                    programRow(program: program, index: index)
                        .onTapWithHaptic {
                            playProgram(program)
                        }

                    if program.id == filteredOrderedPrograms.last?.id {
                        Color.clear
                            .frame(height: 1)
                            .onAppear {
                                if searchKeyword.isEmpty {
                                    viewModel.loadMorePrograms()
                                } else {
                                    loadAllProgramsForSearchIfNeeded()
                                }
                            }
                    }
                }

                if viewModel.isLoadingMore {
                    ProgressView()
                        .padding(.vertical, 16)
                }

                if !viewModel.hasMore && !viewModel.programs.isEmpty {
                    NoMoreDataView()
                }
            }
        }
    }

    private var listControlColor: Color {
        if MujiStyle.isActive { return MujiStyle.inkSoft }
        if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
        if SequoiaStyle.isActive { return SequoiaStyle.accent }
        if BentoStyle.isActive { return BentoStyle.tomato }
        if usesAsideHero { return .monoTextPrimary.opacity(0.78) }
        return .monoTextSecondary
    }

    private var listControlBackground: Color {
        if MujiStyle.isActive { return MujiStyle.surface.opacity(0.84) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.surfacePressed.opacity(0.72) }
        if SequoiaStyle.isActive { return SequoiaStyle.materialList.opacity(0.84) }
        if BentoStyle.isActive { return BentoStyle.surface }
        if usesAsideHero { return .clear }
        return Color.monoSeparator.opacity(0.9)
    }

    private var listControlStroke: Color {
        if MujiStyle.isActive { return MujiStyle.hairline.opacity(0.45) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.separator.opacity(0.55) }
        if SequoiaStyle.isActive { return SequoiaStyle.separator.opacity(0.62) }
        if BentoStyle.isActive { return BentoStyle.hairline.opacity(0.58) }
        if usesAsideHero { return Color.monoSeparator.opacity(0.95) }
        return .clear
    }

    private var listControlFont: Font {
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(11, weight: .semibold) }
        if MujiStyle.isActive { return MujiStyle.labelFont(11, weight: .regular) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(11, weight: .semibold) }
        if BentoStyle.isActive { return BentoStyle.labelFont(11, weight: .heavy) }
        return .system(size: 11, weight: .medium, design: .rounded)
    }

    private var programListTitleFont: Font {
        if MujiStyle.isActive { return MujiStyle.titleFont(18, weight: .regular) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.titleFont(18, weight: .semibold) }
        if SequoiaStyle.isActive { return SequoiaStyle.titleFont(18, weight: .semibold) }
        if BentoStyle.isActive { return BentoStyle.titleFont(20, weight: .black) }
        return .system(size: 17, weight: .bold, design: .rounded)
    }

    private var programListTitleColor: Color {
        if MujiStyle.isActive { return MujiStyle.ink }
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        if SequoiaStyle.isActive { return SequoiaStyle.ink }
        if BentoStyle.isActive { return BentoStyle.ink }
        return .monoTextPrimary
    }

    private var searchFieldRadius: CGFloat {
        if BentoStyle.isActive { return 20 }
        return (NeumorphicStyle.isActive || SequoiaStyle.isActive) ? 18 : 14
    }

    private var searchFieldBackground: Color {
        if NeumorphicStyle.isActive { return NeumorphicStyle.surfacePressed.opacity(0.72) }
        if MujiStyle.isActive { return MujiStyle.surface.opacity(0.84) }
        if SequoiaStyle.isActive { return SequoiaStyle.materialList.opacity(0.84) }
        if BentoStyle.isActive { return BentoStyle.surfaceRaised }
        if usesAsideHero { return Color.monoGlassTint.opacity(0.4) }
        return Color.monoSeparator.opacity(0.85)
    }

    private var searchCloseBackground: Color {
        if NeumorphicStyle.isActive { return NeumorphicStyle.surfacePressed }
        if MujiStyle.isActive { return MujiStyle.surfaceRaised }
        if SequoiaStyle.isActive { return SequoiaStyle.materialPressed }
        if BentoStyle.isActive { return BentoStyle.paper }
        return Color.monoSeparator
    }

    // MARK: - 节目行

    /// 当前 player 是否正在播放本电台的内容
    private var isOwnContent: Bool {
        if case .podcast(let id) = player.playSource, id == radioId {
            return true
        }
        return false
    }

    @ViewBuilder
    private func programRow(program: RadioProgram, index: Int) -> some View {
        if usesAsideHero {
            asideProgramRow(program: program, index: index)
        } else {
            legacyProgramRow(program: program, index: index)
        }
    }

    // MARK: - aside 节目行（编辑部风）

    private func asideProgramRow(program: RadioProgram, index: Int) -> some View {
        let isCurrentPlaying = isOwnContent && player.currentSong?.id == program.mainSong?.id && player.isPlaying
        let episodeNumber = displayEpisodeNumber(for: index)

        return VStack(spacing: 0) {
            HStack(spacing: 14) {
                Text(String(format: "%02d", episodeNumber))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(isCurrentPlaying ? .monoAccent : .monoTextSecondary.opacity(0.6))
                    .frame(width: 26, alignment: .leading)

                CachedAsyncImage(url: program.programCoverUrl) {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.monoGlassTint)
                }
                .frame(width: 46, height: 46)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(Color.monoSeparator.opacity(0.9), lineWidth: 0.8)
                )
                .overlay {
                    if isCurrentPlaying {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color.black.opacity(0.32))
                        PlayingVisualizerView(isAnimating: player.isPlaying, color: .white)
                            .frame(width: 14, height: 12)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(program.name ?? String(localized: "radio_unknown_program"))
                        .font(.rounded(size: 14, weight: .semibold))
                        .foregroundColor(isCurrentPlaying ? .monoAccent : .monoTextPrimary)
                        .lineLimit(1)

                    HStack(spacing: 10) {
                        if !program.durationText.isEmpty {
                            Text(program.durationText)
                                .monospacedDigit()
                        }
                        if let listeners = program.listenerCount, listeners > 0 {
                            Text(String(format: String(localized: "radio_play_count"), formatCount(listeners)))
                        }
                    }
                    .font(.rounded(size: 11.5))
                    .foregroundColor(.monoTextSecondary.opacity(0.85))
                }

                Spacer(minLength: 8)

                if program.mainSong != nil {
                    MonoIcon(icon: .playCircle, size: 21, color: .monoTextSecondary.opacity(0.7), lineWidth: 1.3)
                } else {
                    Text("radio_not_playable")
                        .font(.rounded(size: 11))
                        .foregroundColor(.monoTextSecondary.opacity(0.55))
                }
            }
            .padding(.vertical, 11)

            Rectangle()
                .fill(Color.monoSeparator.opacity(0.7))
                .frame(height: 0.6)
                .padding(.leading, 40)
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .contentShape(Rectangle())
    }

    private func legacyProgramRow(program: RadioProgram, index: Int) -> some View {
        let isCurrentPlaying = isOwnContent && player.currentSong?.id == program.mainSong?.id && player.isPlaying
        let episodeNumber = displayEpisodeNumber(for: index)
        let themedRow = MujiStyle.isActive || NeumorphicStyle.isActive || SequoiaStyle.isActive || BentoStyle.isActive

        return HStack(spacing: 14) {
            CachedAsyncImage(url: program.programCoverUrl) {
                RoundedRectangle(cornerRadius: programCoverRadius, style: .continuous)
                    .fill(programCoverPlaceholderFill)
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: programCoverRadius, style: .continuous))
            .overlay {
                if MujiStyle.isActive {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(MujiStyle.hairline.opacity(0.55), lineWidth: 0.6)
                } else if NeumorphicStyle.isActive {
                    RoundedRectangle(cornerRadius: programCoverRadius, style: .continuous)
                        .stroke(NeumorphicStyle.separator.opacity(0.5), lineWidth: 0.7)
                } else if SequoiaStyle.isActive {
                    RoundedRectangle(cornerRadius: programCoverRadius, style: .continuous)
                        .stroke(SequoiaStyle.separator.opacity(0.72), lineWidth: 0.6)
                } else if BentoStyle.isActive {
                    RoundedRectangle(cornerRadius: programCoverRadius, style: .continuous)
                        .stroke(BentoStyle.hairline.opacity(0.55), lineWidth: 0.7)
                }
            }
            .overlay(
                Group {
                    if isCurrentPlaying {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.3))
                        MonoIcon(icon: .waveform, size: 16, color: .white, lineWidth: 1.6)
                    }
                }
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(program.name ?? String(localized: "radio_unknown_program"))
                    .font(programTitleFont)
                    .foregroundColor(programTitleColor(isCurrentPlaying: isCurrentPlaying))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(String(format: String(localized: "radio_episode_label"), episodeNumber))
                        .font(programMetaFont)
                        .foregroundColor(programMetaColor)

                    if !program.durationText.isEmpty {
                        Text(program.durationText)
                            .font(programMetaFont)
                            .foregroundColor(programMetaColor)
                    }
                    if let listeners = program.listenerCount, listeners > 0 {
                        Text(String(format: String(localized: "radio_play_count"), formatCount(listeners)))
                            .font(programMetaFont)
                            .foregroundColor(programMetaColor)
                    }
                }
            }

            Spacer()

            if program.mainSong != nil {
                MonoIcon(icon: .playCircle, size: 22, color: BentoStyle.isActive ? BentoStyle.tomato : (SequoiaStyle.isActive ? SequoiaStyle.accent : (NeumorphicStyle.isActive ? NeumorphicStyle.accent : (MujiStyle.isActive ? MujiStyle.inkSoft : .monoTextSecondary))), lineWidth: 1.4)
            } else {
                Text("radio_not_playable")
                    .font(BentoStyle.isActive ? BentoStyle.labelFont(11, weight: .semibold) : (SequoiaStyle.isActive ? SequoiaStyle.labelFont(11, weight: .regular) : (MujiStyle.isActive ? MujiStyle.labelFont(11, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(11, weight: .medium) : .system(size: 11, design: .rounded)))))
                    .foregroundColor(BentoStyle.isActive ? BentoStyle.inkMuted : (MujiStyle.isActive ? MujiStyle.inkMuted : (NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : (SequoiaStyle.isActive ? SequoiaStyle.inkMuted : .monoTextSecondary.opacity(0.6)))))
            }
        }
        .padding(.horizontal, themedRow ? 12 : DeviceLayout.viewHorizontalPadding)
        .padding(.vertical, themedRow ? 11 : 10)
        .background {
            if MujiStyle.isActive {
                // Muji：电台节目行以针脚收尾；当前播放行加水洗底
                ZStack(alignment: .leading) {
                    if isCurrentPlaying {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(MujiStyle.wash(MujiStyle.clay, strength: 1.1))
                    } else {
                        VStack {
                            Spacer()
                            MujiListDivider()
                        }
                    }
                }
            } else if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(cornerRadius: 18, elevated: isCurrentPlaying)
            } else if SequoiaStyle.isActive {
                SequoiaSurfaceBackground(cornerRadius: 18, elevated: isCurrentPlaying, role: isCurrentPlaying ? .selected : .list)
            } else if BentoStyle.isActive {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isCurrentPlaying ? BentoStyle.tomato.opacity(0.14) : BentoStyle.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(isCurrentPlaying ? BentoStyle.tomato.opacity(0.36) : BentoStyle.hairline.opacity(0.55), lineWidth: 0.7)
                    )
            }
        }
        .padding(.horizontal, themedRow ? DeviceLayout.viewHorizontalPadding : 0)
        .padding(.vertical, themedRow ? 5 : 0)
        .contentShape(Rectangle())
    }

    private var programCoverRadius: CGFloat {
        if BentoStyle.isActive { return 14 }
        return (NeumorphicStyle.isActive || SequoiaStyle.isActive) ? 14 : 8
    }

    private var programMetaColor: Color {
        if MujiStyle.isActive { return MujiStyle.inkSoft }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        if BentoStyle.isActive { return BentoStyle.inkMuted }
        return .monoTextSecondary
    }

    private var programCoverPlaceholderFill: Color {
        if MujiStyle.isActive { return MujiStyle.surfaceRaised }
        if NeumorphicStyle.isActive { return NeumorphicStyle.surfacePressed }
        if SequoiaStyle.isActive { return SequoiaStyle.materialList }
        if BentoStyle.isActive { return BentoStyle.buckwheat.opacity(0.45) }
        return Color.monoGlassTint
    }

    private var programTitleFont: Font {
        if MujiStyle.isActive { return MujiStyle.bodyFont(14, weight: .regular) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.bodyFont(14, weight: .semibold) }
        if SequoiaStyle.isActive { return SequoiaStyle.bodyFont(14, weight: .semibold) }
        if BentoStyle.isActive { return BentoStyle.bodyFont(14, weight: .heavy) }
        return .system(size: 14, weight: .medium, design: .rounded)
    }

    private var programMetaFont: Font {
        if MujiStyle.isActive { return MujiStyle.labelFont(12, weight: .regular) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(12, weight: .medium) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(12, weight: .regular) }
        if BentoStyle.isActive { return BentoStyle.labelFont(11, weight: .semibold) }
        return .system(size: 12, weight: .medium, design: .rounded)
    }

    private func programTitleColor(isCurrentPlaying: Bool) -> Color {
        if isCurrentPlaying {
            if MujiStyle.isActive { return MujiStyle.clay }
            if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
            if SequoiaStyle.isActive { return SequoiaStyle.accent }
            if BentoStyle.isActive { return BentoStyle.tomato }
            return .monoAccentBlue
        }

        if MujiStyle.isActive { return MujiStyle.ink }
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        if SequoiaStyle.isActive { return SequoiaStyle.ink }
        if BentoStyle.isActive { return BentoStyle.ink }
        return .monoTextPrimary
    }

    private func playProgram(_ program: RadioProgram) {
        let songs = viewModel.songsFromPrograms()
        guard let song = songs.first(where: { $0.id == program.mainSong?.id }) else { return }
        player.playPodcast(song: song, in: songs, radioId: radioId)
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 100_000_000 {
            return String(format: String(localized: "count_hundred_million"), Double(count) / 100_000_000)
        } else if count >= 10_000 {
            return String(format: String(localized: "count_ten_thousand"), Double(count) / 10_000)
        }
        return "\(count)"
    }

    private var searchKeyword: String {
        searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private var filteredOrderedPrograms: [RadioProgram] {
        let programs = viewModel.orderedPrograms
        guard !searchKeyword.isEmpty else { return programs }

        return programs.enumerated().compactMap { index, program in
            matchesSearch(for: program, index: index) ? program : nil
        }
    }

    private func matchesSearch(for program: RadioProgram, index: Int) -> Bool {
        let episodeNumber = displayEpisodeNumber(for: index)
        let normalizedTitle = (program.name ?? "").lowercased()
        var candidates: [String] = [
            normalizedTitle,
            "\(episodeNumber)",
            "ep\(episodeNumber)",
            "episode \(episodeNumber)",
            L10n.format("radio_episode_number_format", episodeNumber),
            L10n.format("radio_episode_part_format", episodeNumber)
        ]

        if let serialNumber = program.serialNum {
            candidates.append("\(serialNumber)")
            candidates.append("ep\(serialNumber)")
            candidates.append("episode \(serialNumber)")
            candidates.append(L10n.format("radio_episode_number_format", serialNumber))
            candidates.append(L10n.format("radio_episode_part_format", serialNumber))
        }

        return candidates.contains { !$0.isEmpty && $0.contains(searchKeyword) }
    }

    private func displayEpisodeNumber(for index: Int) -> Int {
        viewModel.displayEpisodeNumber(at: index)
    }

    private func loadAllProgramsForSearchIfNeeded() {
        guard !searchKeyword.isEmpty, viewModel.hasMore, !viewModel.isLoadingMore else { return }
        viewModel.loadMorePrograms()
    }

    private func toggleSearch() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            isSearchExpanded.toggle()
        }
    }
}
