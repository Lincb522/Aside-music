import SwiftUI

extension SearchView {
    var mangaEmptySearchView: some View {
        // 去卡片化：默认词、历史与热搜全部直接排在纸面上，用规则线分栏
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if let defaultKeyword = viewModel.defaultKeyword {
                    Button {
                        viewModel.performSearch(keyword: defaultKeyword.realkeyword)
                        isFocused = false
                    } label: {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 12) {
                                MangaLabel(text: "PICK", tint: MangaStyle.accentPink, small: true)

                                Text(defaultKeyword.showKeyword)
                                    .font(MangaStyle.titleFont(18, weight: .black))
                                    .foregroundStyle(MangaStyle.ink)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.78)

                                Spacer(minLength: 8)

                                MonoIcon(icon: .chevronRight, size: 12, color: MangaStyle.inkMuted, lineWidth: 1.8)
                            }
                            .padding(.vertical, 12)

                            Rectangle()
                                .fill(MangaStyle.strokeInk.opacity(0.22))
                                .frame(height: 1)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(MonoBouncingButtonStyle(scale: 0.98))
                }

                if !viewModel.searchHistory.isEmpty {
                    mangaSearchShelf(
                        title: String(localized: "search_history"),
                        tint: MangaStyle.decoBlue,
                        actionIcon: .trash,
                        action: { viewModel.clearAllHistory() }
                    ) {
                        VStack(spacing: 0) {
                            ForEach(Array(viewModel.searchHistory.prefix(6).enumerated()), id: \.element.id) { index, item in
                                Button {
                                    viewModel.performSearch(keyword: item.keyword)
                                    isFocused = false
                                } label: {
                                    HStack(spacing: 10) {
                                        Text(String(format: "%02d", index + 1))
                                            .font(.system(size: 11, weight: .black, design: .monospaced))
                                            .foregroundStyle(MangaStyle.inkMuted)
                                            .frame(width: 24, alignment: .leading)

                                        Text(item.keyword)
                                            .font(MangaStyle.comicFont(14, weight: .bold))
                                            .foregroundStyle(MangaStyle.ink)
                                            .lineLimit(1)

                                        Spacer(minLength: 8)

                                        Button {
                                            viewModel.deleteHistoryItem(keyword: item.keyword)
                                        } label: {
                                            MonoIcon(icon: .xmark, size: 10, color: MangaStyle.inkMuted, lineWidth: 1.6)
                                                .frame(width: 28, height: 28)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.vertical, 7)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                if index < min(viewModel.searchHistory.count, 6) - 1 {
                                    Rectangle()
                                        .fill(MangaStyle.strokeInk.opacity(0.12))
                                        .frame(height: 1)
                                }
                            }
                        }
                    }
                }

                if !viewModel.hotSearchItems.isEmpty {
                    mangaSearchShelf(title: String(localized: "search_hot"), tint: MangaStyle.labelYellow) {
                        FlowLayout(spacing: 12) {
                            ForEach(Array(viewModel.hotSearchItems.prefix(20).enumerated()), id: \.element.searchWord) { index, item in
                                Button {
                                    viewModel.performSearch(keyword: item.searchWord)
                                    isFocused = false
                                } label: {
                                    HStack(spacing: 6) {
                                        Text(String(format: "%02d", index + 1))
                                            .font(.system(size: 10, weight: .black, design: .monospaced))
                                            .foregroundStyle(index < 3 ? MangaStyle.accentPink : MangaStyle.inkMuted)

                                        Text(item.searchWord)
                                            .font(MangaStyle.labelFont(12, weight: .bold))
                                            .foregroundStyle(MangaStyle.ink)
                                            .lineLimit(1)
                                    }
                                    .padding(.vertical, 6)
                                    .contentShape(Rectangle())
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

    func mangaSearchShelf<Content: View>(
        title: String,
        tint: Color,
        actionIcon: MonoIcon.IconType? = nil,
        action: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        // 栏目：色块短划 + 黑体题 + 规则线，内容直接排在下方
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(tint)
                    .frame(width: 14, height: 4)

                Text(title)
                    .font(MangaStyle.titleFont(17, weight: .black))
                    .foregroundStyle(MangaStyle.ink)

                VStack(spacing: 2.5) {
                    Rectangle()
                        .fill(MangaStyle.ink.opacity(0.72))
                        .frame(height: 1.6)
                    Rectangle()
                        .fill(MangaStyle.ink.opacity(0.28))
                        .frame(height: 0.8)
                }

                if let actionIcon, let action {
                    Button(action: action) {
                        MonoIcon(icon: actionIcon, size: 13, color: MangaStyle.inkSub, lineWidth: 1.7)
                            .frame(width: 30, height: 30)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            content()
        }
    }

    var capsuleEmptySearchView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let defaultKeyword = viewModel.defaultKeyword {
                    Button {
                        viewModel.performSearch(keyword: defaultKeyword.realkeyword)
                        isFocused = false
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(CapsuleStyle.accent)
                                    .frame(width: 58, height: 58)

                                MonoIcon(icon: .magnifyingGlass, size: 22, color: CapsuleStyle.onAccent, lineWidth: 2)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 5) {
                                    Capsule()
                                        .fill(CapsuleStyle.cyan)
                                        .frame(width: 24, height: 7)
                                    Capsule()
                                        .fill(CapsuleStyle.amber)
                                        .frame(width: 10, height: 7)
                                }

                                Text(defaultKeyword.showKeyword)
                                    .font(CapsuleStyle.titleFont(22, weight: .bold))
                                    .foregroundStyle(CapsuleStyle.ink)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.78)
                            }

                            Spacer(minLength: 8)

                            MonoIcon(icon: .chevronRight, size: 13, color: CapsuleStyle.ink, lineWidth: 1.7)
                                .frame(width: 38, height: 38)
                                .background(CapsuleStyle.surfaceRaised.opacity(0.86), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            CapsuleStyle.surfaceRaised.opacity(0.96),
                                            CapsuleStyle.surfaceTint.opacity(0.72),
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                                        .stroke(CapsuleStyle.hairline.opacity(0.78), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(CapsulePressStyle())
                }

                if !viewModel.searchHistory.isEmpty {
                    VStack(alignment: .leading, spacing: 11) {
                        CapsuleSectionTitle(title: String(localized: "search_history"), tint: CapsuleStyle.mint) {
                            Button(action: { viewModel.clearAllHistory() }) {
                                MonoIcon(icon: .trash, size: 13, color: CapsuleStyle.inkMuted, lineWidth: 1.55)
                                    .frame(width: 34, height: 34)
                                    .background(CapsuleStyle.surfaceRaised.opacity(0.82), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }

                        ScrollView(.horizontal) {
                            HStack(spacing: 10) {
                                ForEach(viewModel.searchHistory.prefix(8), id: \.id) { item in
                                    HStack(spacing: 8) {
                                        Button {
                                            viewModel.performSearch(keyword: item.keyword)
                                            isFocused = false
                                        } label: {
                                            HStack(spacing: 8) {
                                                MonoIcon(icon: .clock, size: 12, color: CapsuleStyle.mint, lineWidth: 1.5)
                                                Text(item.keyword)
                                                    .font(CapsuleStyle.bodyFont(14, weight: .semibold))
                                                    .foregroundStyle(CapsuleStyle.ink)
                                                    .lineLimit(1)
                                            }
                                        }
                                        .buttonStyle(.plain)

                                        Button {
                                            viewModel.deleteHistoryItem(keyword: item.keyword)
                                        } label: {
                                            MonoIcon(icon: .xmark, size: 9, color: CapsuleStyle.inkMuted, lineWidth: 1.45)
                                                .frame(width: 24, height: 24)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.leading, 12)
                                    .padding(.trailing, 7)
                                    .padding(.vertical, 10)
                                    .background(CapsuleStyle.surfaceRaised.opacity(0.84), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .stroke(CapsuleStyle.separator.opacity(0.42), lineWidth: 0.7)
                                    )
                                }
                            }
                            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                        }
                        .scrollIndicators(.hidden)
                        .padding(.horizontal, -DeviceLayout.viewHorizontalPadding)
                    }
                }

                if !viewModel.hotSearchItems.isEmpty {
                    VStack(alignment: .leading, spacing: 11) {
                        CapsuleSectionTitle(title: String(localized: "search_hot"), tint: CapsuleStyle.coral)

                        VStack(spacing: 8) {
                            ForEach(Array(viewModel.hotSearchItems.prefix(12).enumerated()), id: \.element.searchWord) { index, item in
                                Button {
                                    viewModel.performSearch(keyword: item.searchWord)
                                    isFocused = false
                                } label: {
                                    HStack(spacing: 11) {
                                        Text(String(format: "%02d", index + 1))
                                            .font(.system(size: 11, weight: .black, design: .rounded))
                                            .foregroundStyle(index < 3 ? CapsuleStyle.onAccent : CapsuleStyle.inkMuted)
                                            .monospacedDigit()
                                            .frame(width: 34, height: 30)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .fill(index < 3 ? CapsuleStyle.coral : CapsuleStyle.surfaceTint.opacity(0.58))
                                            )

                                        Text(item.searchWord)
                                            .font(CapsuleStyle.bodyFont(15, weight: .bold))
                                            .foregroundStyle(CapsuleStyle.ink)
                                            .lineLimit(1)

                                        Spacer(minLength: 8)

                                        HStack(spacing: 4) {
                                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                                .fill(index < 3 ? CapsuleStyle.coral : CapsuleStyle.accent.opacity(0.56))
                                                .frame(width: 18, height: 5)
                                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                                .fill(CapsuleStyle.cyan.opacity(index < 3 ? 0.9 : 0.48))
                                                .frame(width: 8, height: 5)
                                        }
                                    }
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                                            .fill(index < 3 ? CapsuleStyle.surfaceRaised.opacity(0.94) : CapsuleStyle.surface.opacity(0.66))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                                    .stroke(index < 3 ? CapsuleStyle.coral.opacity(0.3) : CapsuleStyle.separator.opacity(0.35), lineWidth: 0.7)
                                            )
                                    )
                                }
                                .buttonStyle(CapsulePressStyle())
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

    func capsuleSearchShelf<Content: View>(
        title: String,
        icon: MonoIcon.IconType,
        tint: Color,
        actionIcon: MonoIcon.IconType? = nil,
        action: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            CapsuleSectionTitle(title: title, tint: tint) {
                if let actionIcon, let action {
                    Button(action: action) {
                        MonoIcon(icon: actionIcon, size: 13, color: CapsuleStyle.inkMuted, lineWidth: 1.55)
                            .frame(width: 34, height: 34)
                            .background(CapsuleSurfaceBackground(cornerRadius: 14, elevated: false, tint: CapsuleStyle.surfaceRaised.opacity(0.86)))
                    }
                    .buttonStyle(.plain)
                }
            }

            content()
        }
        .padding(14)
        .background(CapsuleSurfaceBackground(cornerRadius: 24, elevated: true, tint: CapsuleStyle.surface.opacity(0.92)))
    }

}
