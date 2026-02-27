import SwiftUI

/// 分类电台列表页面
struct CategoryRadioView: View {
    let category: RadioCategory
    @State private var viewModel: CategoryRadioViewModel
    @Environment(\.dismiss) private var dismiss

    init(category: RadioCategory) {
        self.category = category
        _viewModel = State(initialValue: CategoryRadioViewModel(category: category))
    }

    var body: some View {
        ZStack {
            AsideBackground()
                .ignoresSafeArea()

            if viewModel.isLoading && viewModel.radios.isEmpty {
                AsideLoadingView(text: "LOADING")
            } else if viewModel.radios.isEmpty {
                // 空状态
                VStack(spacing: 12) {
                    AsideIcon(icon: .micSlash, size: 40, color: .asideTextSecondary)
                    Text("radio_empty")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.asideTextSecondary)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.radios) { radio in
                            NavigationLink(value: PodcastView.PodcastDestination.radioDetail(radio.id)) {
                                radioRow(radio: radio)
                            }
                            .buttonStyle(.plain)

                            // 滚动到底部自动加载
                            if radio.id == viewModel.radios.last?.id {
                                Color.clear
                                    .frame(height: 1)
                                    .onAppear {
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
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                AsideBackButton()
            }
            ToolbarItem(placement: .principal) {
                Text(category.name)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.asideTextPrimary)
            }
        }
        .onAppear {
            if viewModel.radios.isEmpty {
                viewModel.fetchRadios()
            }
        }
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
                    if let count = radio.programCount {
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
    }
}
