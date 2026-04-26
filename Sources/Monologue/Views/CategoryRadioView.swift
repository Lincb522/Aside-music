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
            ThemedPageBackground()
                .ignoresSafeArea()

            if viewModel.isLoading && viewModel.radios.isEmpty {
                MonologueLoadingView(text: "LOADING")
            } else if viewModel.radios.isEmpty {
                // 空状态
                VStack(spacing: 12) {
                    MonologueIcon(icon: .micSlash, size: 40, color: .monologueTextSecondary)
                    Text("radio_empty")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.monologueTextSecondary)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: ThemedPageStyle.listSpacing) {
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
                    .padding(.horizontal, ThemedPageStyle.horizontalInset)
                    .padding(.top, ThemedPageStyle.isActive ? 8 : 0)
                    .padding(.bottom, 120)
                }
                .scrollIndicators(.hidden)
            }
        }
        .themedNavigationChrome(title: category.name, eyebrow: "RADIO", icon: .radio)
        .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
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
                    if let count = radio.programCount {
                        Text(String(format: String(localized: "podcast_episode_count"), count))
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.monologueTextSecondary)
                    }
                }
            }

            Spacer()

            MonologueIcon(icon: .chevronRight, size: 12, color: .monologueTextSecondary, lineWidth: 1.2)
        }
        .padding(.horizontal, ThemedPageStyle.isActive ? 16 : 20)
        .padding(.vertical, 12)
        .themedOnlyPageSurface(cornerRadius: ThemedPageStyle.compactSurfaceCornerRadius, elevated: false)
    }
}
