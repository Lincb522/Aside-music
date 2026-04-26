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
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(categoryTextColor(isSelected: isSelected))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
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
    }

    private func categoryTextColor(isSelected: Bool) -> Color {
        if MangaStyle.isActive {
            return isSelected ? MangaStyle.ink : .monologueTextPrimary
        } else if MujiStyle.isActive {
            return isSelected ? MujiStyle.paper : .monologueTextPrimary
        } else {
            return isSelected ? .monologueIconForeground : .monologueTextPrimary
        }
    }

    private func categoryChipBackground(isSelected: Bool) -> Color {
        if MangaStyle.isActive {
            return isSelected ? MangaStyle.labelYellow : MangaStyle.bubbleWhite
        } else if MujiStyle.isActive {
            return isSelected ? MujiStyle.clay : MujiStyle.surfaceRaised
        } else {
            return isSelected ? Color.monologueIconBackground : Color.monologueGlassTint
        }
    }

    // MARK: - 电台行

    private func radioRow(radio: RadioStation) -> some View {
        HStack(spacing: 14) {
            CachedAsyncImage(url: radio.coverUrl) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.monologueGlassTint)
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(radio.name)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.monologueTextPrimary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let dj = radio.dj?.nickname {
                        Text(dj)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.monologueTextSecondary)
                            .lineLimit(1)
                    }
                    if let count = radio.programCount, count > 0 {
                        Text(String(format: String(localized: "podcast_episode_count"), count))
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.monologueTextSecondary)
                    }
                }
            }

            Spacer()

            MonologueIcon(icon: .chevronRight, size: 12, color: .monologueTextSecondary, lineWidth: 1.2)
        }
        .padding(.horizontal, ThemedPageStyle.isActive ? 16 : DeviceLayout.viewHorizontalPadding)
        .padding(.vertical, 12)
        .themedOnlyPageSurface(cornerRadius: ThemedPageStyle.compactSurfaceCornerRadius, elevated: false)
        .contentShape(Rectangle())
    }
}
