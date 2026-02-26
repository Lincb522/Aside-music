import SwiftUI

/// 热门电台完整列表（查看更多），无限加载
struct TopRadioListView: View {
    let title: String
    let listType: ListType

    @State private var viewModel: TopRadioListViewModel
    @Environment(\.dismiss) private var dismiss

    enum ListType {
        case hot
        case toplist
    }

    init(title: String, listType: ListType) {
        self.title = title
        self.listType = listType
        _viewModel = State(initialValue: TopRadioListViewModel(listType: listType))
    }

    var body: some View {
        ZStack {
            AsideBackground()
                .ignoresSafeArea()

            if viewModel.isLoading && viewModel.radios.isEmpty {
                AsideLoadingView(text: "LOADING")
            } else if viewModel.radios.isEmpty && !viewModel.isLoading {
                VStack(spacing: 12) {
                    AsideIcon(icon: .micSlash, size: 40, color: .asideTextSecondary)
                    Text("radio_empty")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.asideTextSecondary)
                }
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
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                AsideBackButton()
            }
            ToolbarItem(placement: .principal) {
                Text(title)
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
