import SwiftUI

extension SearchView {
    var minimalWhiteEmptySearchView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if viewModel.searchHistory.isEmpty && viewModel.hotSearchItems.isEmpty {
                    themeSearchStatePanel(
                        icon: .magnifyingGlass,
                        title: String(localized: "action_search"),
                        tint: MinimalWhiteStyle.inkMuted
                    )
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    .padding(.top, 36)
                }

                if !viewModel.searchHistory.isEmpty {
                    MinimalWhiteSectionTitle(title: String(localized: "search_history")) {
                        Button(action: viewModel.clearAllHistory) {
                            MonoIcon(icon: .trash, size: 15, color: MinimalWhiteStyle.inkMuted, lineWidth: 1.55)
                                .frame(width: 32, height: 32)
                                .background(MinimalWhiteCircleBackground())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)

                    VStack(spacing: 0) {
                        ForEach(viewModel.searchHistory, id: \.id) { item in
                            Button {
                                viewModel.performSearch(keyword: item.keyword)
                                isFocused = false
                            } label: {
                                HStack(spacing: 12) {
                                    MonoIcon(icon: .clock, size: 15, color: MinimalWhiteStyle.inkMuted, lineWidth: 1.45)

                                    Text(item.keyword)
                                        .font(MinimalWhiteStyle.bodyFont(15, weight: .regular))
                                        .foregroundStyle(MinimalWhiteStyle.ink)
                                        .lineLimit(1)

                                    Spacer(minLength: 8)

                                    Button {
                                        viewModel.deleteHistoryItem(keyword: item.keyword)
                                    } label: {
                                        MonoIcon(icon: .xmark, size: 11, color: MinimalWhiteStyle.inkMuted.opacity(0.7), lineWidth: 1.5)
                                            .frame(width: 28, height: 28)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                                .padding(.vertical, 12)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .minimalWhiteHairline(.bottom)
                        }
                    }
                }

                if !viewModel.hotSearchItems.isEmpty {
                    MinimalWhiteSectionTitle(title: String(localized: "search_hot"))
                        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)

                    FlowLayout(spacing: 10) {
                        ForEach(viewModel.hotSearchItems.prefix(20), id: \.searchWord) { item in
                            Button {
                                viewModel.performSearch(keyword: item.searchWord)
                                isFocused = false
                            } label: {
                                Text(item.searchWord)
                                    .font(MinimalWhiteStyle.bodyFont(14, weight: .regular))
                                    .foregroundStyle(MinimalWhiteStyle.ink)
                                    .lineLimit(1)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(MinimalWhiteCapsuleBackground())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                }
            }
            .padding(.top, 18)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .themeRenderScrollLayer()
    }

    var petWhiteEmptySearchView: some View {
        PetWhiteSearchEmptyPanel(
            defaultKeyword: viewModel.defaultKeyword,
            searchHistory: Array(viewModel.searchHistory.prefix(6)),
            hotSearchItems: Array(viewModel.hotSearchItems.prefix(20)),
            onSearch: { keyword in
                viewModel.performSearch(keyword: keyword)
                isFocused = false
            },
            onDeleteHistory: { keyword in
                viewModel.deleteHistoryItem(keyword: keyword)
            },
            onClearHistory: {
                viewModel.clearAllHistory()
            }
        )
    }

    var sequoiaEmptySearchView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let defaultKeyword = viewModel.defaultKeyword {
                    Button {
                        viewModel.performSearch(keyword: defaultKeyword.realkeyword)
                        isFocused = false
                    } label: {
                        HStack(spacing: 13) {
                            SequoiaIconBadge(icon: .magnifyingGlass, tint: SequoiaStyle.accent, size: 42)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(String(localized: "action_search"))
                                    .font(SequoiaStyle.labelFont(10, weight: .semibold))
                                    .foregroundStyle(SequoiaStyle.inkMuted)
                                    .tracking(0.8)

                                Text(defaultKeyword.showKeyword)
                                    .font(SequoiaStyle.titleFont(19, weight: .semibold))
                                    .foregroundStyle(SequoiaStyle.ink)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.78)
                            }

                            Spacer(minLength: 8)
                            SequoiaMeter(tint: SequoiaStyle.accent, count: 9)
                        }
                        .padding(13)
                        .background(SequoiaSurfaceBackground(cornerRadius: 22, elevated: true, role: .chrome))
                    }
                    .buttonStyle(MonoBouncingButtonStyle(scale: 0.97))
                }

                if !viewModel.searchHistory.isEmpty {
                    sequoiaSearchShelf(
                        title: String(localized: "search_history"),
                        icon: .clock,
                        tint: SequoiaStyle.green,
                        actionIcon: .trash,
                        action: { viewModel.clearAllHistory() }
                    ) {
                        SequoiaListGroup {
                            ForEach(Array(viewModel.searchHistory.prefix(6).enumerated()), id: \.element.id) { index, item in
                                Button {
                                    viewModel.performSearch(keyword: item.keyword)
                                    isFocused = false
                                } label: {
                                    HStack(spacing: 11) {
                                        MonoIcon(icon: .clock, size: 14, color: SequoiaStyle.green, lineWidth: 1.5)
                                        Text(item.keyword)
                                            .font(SequoiaStyle.labelFont(14, weight: .medium))
                                            .foregroundStyle(SequoiaStyle.ink)
                                            .lineLimit(1)
                                        Spacer(minLength: 8)
                                        Button {
                                            viewModel.deleteHistoryItem(keyword: item.keyword)
                                        } label: {
                                            MonoIcon(icon: .xmark, size: 11, color: SequoiaStyle.inkMuted, lineWidth: 1.45)
                                                .frame(width: 28, height: 28)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 10)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                if index < min(viewModel.searchHistory.count, 6) - 1 {
                                    Divider()
                                        .overlay(SequoiaStyle.separator)
                                        .padding(.leading, 42)
                                }
                            }
                        }
                    }
                }

                if !viewModel.hotSearchItems.isEmpty {
                    sequoiaSearchShelf(
                        title: String(localized: "search_hot"),
                        icon: .sparkle,
                        tint: SequoiaStyle.aqua
                    ) {
                        FlowLayout(spacing: 9) {
                            ForEach(viewModel.hotSearchItems.prefix(20), id: \.searchWord) { item in
                                Button {
                                    viewModel.performSearch(keyword: item.searchWord)
                                    isFocused = false
                                } label: {
                                    SequoiaPill(text: item.searchWord, tint: SequoiaStyle.aqua, selected: false)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.top, 4)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .themeRenderScrollLayer()
    }

    func sequoiaSearchShelf<Content: View>(
        title: String,
        icon: MonoIcon.IconType,
        tint: Color,
        actionIcon: MonoIcon.IconType? = nil,
        action: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                MonoIcon(icon: icon, size: 15, color: tint, lineWidth: 1.55)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(tint.opacity(0.11))
                    )
                Text(title)
                    .font(SequoiaStyle.titleFont(17, weight: .semibold))
                    .foregroundStyle(SequoiaStyle.ink)
                Spacer(minLength: 8)
                if let actionIcon, let action {
                    Button(action: action) {
                        SequoiaControlButton(icon: actionIcon, tint: SequoiaStyle.inkMuted, size: 34)
                    }
                    .buttonStyle(.plain)
                }
            }
            SequoiaHairline(tint: tint.opacity(0.26))
            content()
        }
    }

    var neumorphicEmptySearchView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let defaultKeyword = viewModel.defaultKeyword {
                    Button {
                        viewModel.performSearch(keyword: defaultKeyword.realkeyword)
                        isFocused = false
                    } label: {
                        HStack(spacing: 14) {
                            NeumorphicIconBadge(icon: .magnifyingGlass, tint: NeumorphicStyle.accent, size: 46)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("DEFAULT")
                                    .font(NeumorphicStyle.labelFont(10, weight: .semibold))
                                    .foregroundStyle(NeumorphicStyle.inkMuted)
                                    .tracking(1.0)

                                Text(defaultKeyword.showKeyword)
                                    .font(NeumorphicStyle.titleFont(20, weight: .semibold))
                                    .foregroundStyle(NeumorphicStyle.ink)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.78)
                            }

                            Spacer(minLength: 8)

                            MonoIcon(icon: .chevronRight, size: 13, color: NeumorphicStyle.accent, lineWidth: 1.6)
                                .frame(width: 34, height: 34)
                                .background(NeumorphicSurfaceBackground(cornerRadius: 12, elevated: false, pressed: true, lightweight: true))
                        }
                        .padding(15)
                        .background(NeumorphicSurfaceBackground(cornerRadius: 24, elevated: true))
                    }
                    .buttonStyle(MonoBouncingButtonStyle(scale: 0.97))
                }

                if !viewModel.searchHistory.isEmpty {
                    neumorphicSearchShelf(
                        title: String(localized: "search_history"),
                        icon: .clock,
                        tint: NeumorphicStyle.sage,
                        actionIcon: .trash,
                        action: { viewModel.clearAllHistory() }
                    ) {
                        VStack(spacing: 8) {
                            ForEach(viewModel.searchHistory.prefix(6), id: \.id) { item in
                                Button {
                                    viewModel.performSearch(keyword: item.keyword)
                                    isFocused = false
                                } label: {
                                    HStack(spacing: 10) {
                                        MonoIcon(icon: .clock, size: 13, color: NeumorphicStyle.sage, lineWidth: 1.5)

                                        Text(item.keyword)
                                            .font(NeumorphicStyle.bodyFont(14, weight: .medium))
                                            .foregroundStyle(NeumorphicStyle.ink)
                                            .lineLimit(1)

                                        Spacer(minLength: 8)

                                        Button {
                                            viewModel.deleteHistoryItem(keyword: item.keyword)
                                        } label: {
                                            MonoIcon(icon: .xmark, size: 10, color: NeumorphicStyle.inkMuted, lineWidth: 1.5)
                                                .frame(width: 28, height: 28)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(NeumorphicSurfaceBackground(cornerRadius: 16, elevated: false, pressed: true, lightweight: true))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                if !viewModel.hotSearchItems.isEmpty {
                    neumorphicSearchShelf(
                        title: String(localized: "search_hot"),
                        icon: .chart,
                        tint: NeumorphicStyle.warm
                    ) {
                        FlowLayout(spacing: 10) {
                            ForEach(Array(viewModel.hotSearchItems.prefix(20).enumerated()), id: \.element.searchWord) { index, item in
                                Button {
                                    viewModel.performSearch(keyword: item.searchWord)
                                    isFocused = false
                                } label: {
                                    HStack(spacing: 7) {
                                        Text(String(format: "%02d", index + 1))
                                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(index < 3 ? NeumorphicStyle.warm : NeumorphicStyle.inkMuted)

                                        Text(item.searchWord)
                                            .font(NeumorphicStyle.labelFont(13, weight: .medium))
                                            .foregroundStyle(NeumorphicStyle.ink)
                                            .lineLimit(1)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 9)
                                    .background(NeumorphicSurfaceBackground(cornerRadius: 16, elevated: false, pressed: true, lightweight: true))
                                }
                                .buttonStyle(MonoBouncingButtonStyle(scale: 0.96))
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.top, 4)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
    }

    func neumorphicSearchShelf<Content: View>(
        title: String,
        icon: MonoIcon.IconType,
        tint: Color,
        actionIcon: MonoIcon.IconType? = nil,
        action: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 10) {
                NeumorphicIconBadge(icon: icon, tint: tint, size: 34)

                Text(title)
                    .font(NeumorphicStyle.titleFont(17, weight: .semibold))
                    .foregroundStyle(NeumorphicStyle.ink)

                Spacer(minLength: 8)

                if let actionIcon, let action {
                    Button(action: action) {
                        MonoIcon(icon: actionIcon, size: 14, color: NeumorphicStyle.inkMuted, lineWidth: 1.5)
                            .frame(width: 34, height: 34)
                            .background(NeumorphicSurfaceBackground(cornerRadius: 12, elevated: false, pressed: true, lightweight: true))
                    }
                    .buttonStyle(.plain)
                }
            }

            content()
        }
        .padding(14)
        .background(NeumorphicSurfaceBackground(cornerRadius: 24, elevated: true))
    }

    /// Muji：空态检索页 —— 历史与热搜为清新目次列表，针脚分隔
    var mujiEmptySearchView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                if !viewModel.searchHistory.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        MujiSectionTitle(
                            title: String(localized: "search_history"),
                            actionTitle: String(localized: "search_clear"),
                            action: { viewModel.clearAllHistory() }
                        )

                        VStack(spacing: 0) {
                            ForEach(Array(viewModel.searchHistory.enumerated()), id: \.element.id) { index, item in
                                Button {
                                    viewModel.performSearch(keyword: item.keyword)
                                    isFocused = false
                                } label: {
                                    HStack(spacing: 13) {
                                        Text(String(format: "%02d", index + 1))
                                            .font(MujiStyle.titleFont(12.5, weight: .medium))
                                            .foregroundStyle(MujiStyle.inkMuted)
                                            .monospacedDigit()
                                            .frame(width: 24, alignment: .leading)

                                        Text(item.keyword)
                                            .font(MujiStyle.bodyFont(15, weight: .regular))
                                            .foregroundStyle(MujiStyle.ink)
                                            .lineLimit(1)

                                        Spacer()

                                        Button {
                                            viewModel.deleteHistoryItem(keyword: item.keyword)
                                        } label: {
                                            MonoIcon(icon: .xmark, size: 11, color: MujiStyle.inkMuted.opacity(0.72))
                                                .frame(width: 26, height: 26)
                                                .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.vertical, 11)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                if index < viewModel.searchHistory.count - 1 {
                                    MujiListDivider()
                                        .padding(.leading, 37)
                                }
                            }
                        }
                    }
                }

                if !viewModel.hotSearchItems.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        MujiSectionTitle(title: String(localized: "search_hot"))

                        // 热搜排行：两栏目次，前三位用陶土衬线序号
                        let items = Array(viewModel.hotSearchItems.prefix(20))
                        let columns = [
                            GridItem(.flexible(), spacing: 26),
                            GridItem(.flexible(), spacing: 26),
                        ]

                        LazyVGrid(columns: columns, alignment: .leading, spacing: 0) {
                            ForEach(Array(items.enumerated()), id: \.element.searchWord) { index, item in
                                Button {
                                    viewModel.performSearch(keyword: item.searchWord)
                                    isFocused = false
                                } label: {
                                    VStack(spacing: 0) {
                                        HStack(spacing: 10) {
                                            Text(String(format: "%02d", index + 1))
                                                .font(MujiStyle.titleFont(12.5, weight: .medium))
                                                .foregroundStyle(index < 3 ? MujiStyle.clay : MujiStyle.inkMuted)
                                                .monospacedDigit()
                                                .frame(width: 22, alignment: .leading)

                                            Text(item.searchWord)
                                                .font(MujiStyle.bodyFont(13.5, weight: index < 3 ? .medium : .regular))
                                                .foregroundStyle(MujiStyle.ink)
                                                .lineLimit(1)

                                            Spacer(minLength: 0)
                                        }
                                        .padding(.vertical, 10)

                                        MujiListDivider()
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding + 6)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
    }

}
