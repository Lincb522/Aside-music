import SwiftUI

/// 电台分类浏览页面 — 顶部分类标签，选中后展示该分类下的电台列表，无限加载
struct RadioCategoryBrowseView: View {
    @State private var viewModel = RadioCategoryBrowseViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AsideBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 分类标签栏
                if !viewModel.categories.isEmpty {
                    categoryBar
                }

                // 内容区
                if viewModel.isLoading && viewModel.radios.isEmpty {
                    Spacer()
                    AsideLoadingView(text: "LOADING")
                    Spacer()
                } else if viewModel.radios.isEmpty && !viewModel.isLoading {
                    Spacer()
                    VStack(spacing: 12) {
                        AsideIcon(icon: .micSlash, size: 40, color: .asideTextSecondary)
                        Text("radio_empty")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.asideTextSecondary)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
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
                        .padding(.bottom, 120)
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                AsideBackButton()
            }
            ToolbarItem(placement: .principal) {
                Text("radio_category_browse")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.asideTextPrimary)
            }
        }
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
                            .foregroundColor(isSelected ? .asideIconForeground : .asideTextPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(isSelected ? Color.asideIconBackground : Color.asideGlassTint)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - 电台行

    private func radioRow(radio: RadioStation) -> some View {
        HStack(spacing: 14) {
            CachedAsyncImage(url: radio.coverUrl) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.asideGlassTint)
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(radio.name)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.asideTextPrimary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let dj = radio.dj?.nickname {
                        Text(dj)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.asideTextSecondary)
                            .lineLimit(1)
                    }
                    if let count = radio.programCount, count > 0 {
                        Text(String(format: String(localized: "podcast_episode_count"), count))
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.asideTextSecondary)
                    }
                }
            }

            Spacer()

            AsideIcon(icon: .chevronRight, size: 12, color: .asideTextSecondary, lineWidth: 1.2)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}
