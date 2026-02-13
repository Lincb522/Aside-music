import SwiftUI
import Combine

/// 热门电台完整列表（查看更多），无限加载
struct TopRadioListView: View {
    let title: String
    let listType: ListType

    @StateObject private var viewModel: TopRadioListViewModel
    @Environment(\.dismiss) private var dismiss

    enum ListType {
        case hot
        case toplist
    }

    init(title: String, listType: ListType) {
        self.title = title
        self.listType = listType
        _viewModel = StateObject(wrappedValue: TopRadioListViewModel(listType: listType))
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
                    Text("暂无电台")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.asideTextSecondary)
                }
            } else {
                ScrollView(showsIndicators: false) {
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
                    .fill(Color.asideCardBackground)
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
                        Text("\(count)期")
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


// MARK: - ViewModel

@MainActor
class TopRadioListViewModel: ObservableObject {
    @Published var radios: [RadioStation] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var hasMore = true

    private let listType: TopRadioListView.ListType
    private var offset = 0
    private let limit = 30
    private var cancellables = Set<AnyCancellable>()

    init(listType: TopRadioListView.ListType) {
        self.listType = listType
    }

    func fetchRadios() {
        guard !isLoading else { return }
        isLoading = true
        offset = 0
        radios = []

        fetchPage(offset: 0)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
            }, receiveValue: { [weak self] stations in
                guard let self = self else { return }
                self.radios = stations
                self.offset = stations.count
                self.hasMore = stations.count >= self.limit
            })
            .store(in: &cancellables)
    }

    func loadMore() {
        guard !isLoadingMore, !isLoading, hasMore else { return }
        isLoadingMore = true

        fetchPage(offset: offset)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoadingMore = false
            }, receiveValue: { [weak self] stations in
                guard let self = self else { return }
                let existingIds = Set(self.radios.map { $0.id })
                let newStations = stations.filter { !existingIds.contains($0.id) }
                self.radios.append(contentsOf: newStations)
                self.offset += stations.count
                self.hasMore = stations.count >= self.limit
            })
            .store(in: &cancellables)
    }

    private func fetchPage(offset: Int) -> AnyPublisher<[RadioStation], Error> {
        switch listType {
        case .hot:
            return APIService.shared.fetchDJHot(limit: limit, offset: offset)
        case .toplist:
            return APIService.shared.fetchDJToplist(type: "hot", limit: limit, offset: offset)
        }
    }
}
