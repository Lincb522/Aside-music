import SwiftUI

/// 电台分类浏览页面 — 顶部分类标签，选中后展示该分类下的电台列表，无限加载
struct RadioCategoryBrowseView: View {
    @State private var viewModel = RadioCategoryBrowseViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            ThemedPageBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 分类标签栏
                if !viewModel.categories.isEmpty {
                    categoryBar
                }

                // 内容区
                if viewModel.isLoading && viewModel.radios.isEmpty {
                    Spacer()
                    MonologueLoadingView(text: "LOADING")
                    Spacer()
                } else if viewModel.radios.isEmpty && !viewModel.isLoading {
                    Spacer()
                    VStack(spacing: 12) {
                        MonologueIcon(icon: .micSlash, size: 40, color: .monologueTextSecondary)
                        Text("radio_empty")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.monologueTextSecondary)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: ThemedPageStyle.listSpacing) {
                            ForEach(Array(viewModel.radios.enumerated()), id: \.element.id) { index, radio in
                                NavigationLink(value: PodcastView.PodcastDestination.radioDetail(radio.id)) {
                                    radioRow(radio: radio)
                                }
                                .buttonStyle(.plain)
                                .onAppear {
                                    if index >= viewModel.radios.count - 5 {
                                        viewModel.loadMore()
                                    }
                                }
                            }

                            if viewModel.isLoadingMore {
                                ProgressView()
                                    .padding(.vertical, 16)
                            }

                            if !viewModel.hasMore && !viewModel.radios.isEmpty {
                                NoMoreDataView()
                            }
                        }
                        .padding(.horizontal, ThemedPageStyle.horizontalInset)
                        .padding(.top, ThemedPageStyle.isActive ? 4 : 0)
                        .padding(.bottom, 120)
                    }
                    .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
                }
            }
        }
        .themedNavigationChrome(title: String(localized: "radio_category_browse"), eyebrow: "RADIO", icon: .gridSquare)
        .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear {
            viewModel.initialLoad()
        }
    }

    // MARK: - 分类标签栏

    private var categoryBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(viewModel.categories) { cat in
                    let isSelected = viewModel.selectedCategory?.id == cat.id
                    Button(action: {
                        viewModel.selectCategory(cat)
                    }) {
                        Text(cat.name)
                            .font(categoryChipFont(isSelected: isSelected))
                            .foregroundColor(categoryTextColor(isSelected: isSelected))
                            .padding(.horizontal, NeumorphicStyle.isActive ? 16 : 14)
                            .padding(.vertical, NeumorphicStyle.isActive ? 9 : 8)
                            .background(categoryChipBackground(isSelected: isSelected))
                            .clipShape(Capsule())
                            .overlay {
                                if MangaStyle.isActive {
                                    Capsule()
                                        .stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.strokeWidth)
                                } else if MujiStyle.isActive {
                                    Capsule()
                                        .stroke(MujiStyle.hairline.opacity(0.45), lineWidth: 0.6)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.vertical, 12)
        }
        .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
    }

    private func categoryChipFont(isSelected: Bool) -> Font {
        if MangaStyle.isActive { return MangaStyle.labelFont(13, weight: isSelected ? .black : .bold) }
        if MujiStyle.isActive { return MujiStyle.labelFont(13, weight: isSelected ? .semibold : .regular) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(13, weight: isSelected ? .semibold : .medium) }
        return .system(size: 13, weight: .medium, design: .rounded)
    }

    private func categoryTextColor(isSelected: Bool) -> Color {
        if MangaStyle.isActive {
            return isSelected ? MangaStyle.ink : .monologueTextPrimary
        } else if MujiStyle.isActive {
            return isSelected ? MujiStyle.paper : .monologueTextPrimary
        } else if NeumorphicStyle.isActive {
            return isSelected ? NeumorphicStyle.accent : NeumorphicStyle.inkSoft
        } else {
            return isSelected ? .monologueIconForeground : .monologueTextPrimary
        }
    }

    @ViewBuilder
    private func categoryChipBackground(isSelected: Bool) -> some View {
        if MangaStyle.isActive {
            Capsule().fill(isSelected ? MangaStyle.labelYellow : MangaStyle.bubbleWhite)
        } else if MujiStyle.isActive {
            Capsule().fill(isSelected ? MujiStyle.clay : MujiStyle.surfaceRaised)
        } else if NeumorphicStyle.isActive {
            NeumorphicSurfaceBackground(
                cornerRadius: 16,
                elevated: isSelected,
                pressed: !isSelected,
                tint: isSelected ? NeumorphicStyle.accent.opacity(0.16) : NeumorphicStyle.surface
            )
        } else {
            Capsule().fill(isSelected ? Color.monologueIconBackground : Color.monologueGlassTint)
        }
    }

    // MARK: - 电台行

    private func radioRow(radio: RadioStation) -> some View {
        HStack(spacing: 14) {
            CachedAsyncImage(url: radio.coverUrl) {
                RoundedRectangle(cornerRadius: coverRadius, style: .continuous)
                    .fill(NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.monologueGlassTint)
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: coverRadius, style: .continuous))
            .overlay(coverStroke)

            VStack(alignment: .leading, spacing: 4) {
                Text(radio.name)
                    .font(NeumorphicStyle.isActive ? NeumorphicStyle.bodyFont(15, weight: .semibold) : .system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.ink : .monologueTextPrimary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let dj = radio.dj?.nickname {
                        Text(dj)
                            .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(12, weight: .medium) : .system(size: 12, design: .rounded))
                            .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : .monologueTextSecondary)
                            .lineLimit(1)
                    }
                    if let count = radio.programCount, count > 0 {
                        Text(String(format: String(localized: "podcast_episode_count"), count))
                            .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(12, weight: .medium) : .system(size: 12, design: .rounded))
                            .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : .monologueTextSecondary)
                    }
                }
            }

            Spacer()

            MonologueIcon(icon: .chevronRight, size: 12, color: NeumorphicStyle.isActive ? NeumorphicStyle.accent : .monologueTextSecondary, lineWidth: 1.2)
        }
        .padding(.horizontal, ThemedPageStyle.isActive ? 16 : DeviceLayout.viewHorizontalPadding)
        .padding(.vertical, 12)
        .themedOnlyPageSurface(cornerRadius: ThemedPageStyle.compactSurfaceCornerRadius, elevated: false)
        .contentShape(Rectangle())
    }

    private var coverRadius: CGFloat {
        NeumorphicStyle.isActive ? 14 : 10
    }

    @ViewBuilder
    private var coverStroke: some View {
        if NeumorphicStyle.isActive {
            RoundedRectangle(cornerRadius: coverRadius, style: .continuous)
                .stroke(NeumorphicStyle.separator.opacity(0.5), lineWidth: 0.7)
        }
    }
}
