import SwiftUI

struct TopChartsView: View {
    @State private var topLists: [TopList] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @ObservedObject private var subManager = SubscriptionManager.shared
    
    typealias Theme = PlaylistDetailView.Theme
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        ZStack {
            MonologueBackground()
            
            if isLoading {
                MonologueLoadingView(text: "LOADING CHARTS")
            } else if let error = errorMessage {
                VStack {
                    MonologueIcon(icon: .warning, size: 48, color: .monologueTextSecondary)
                    Text(error)
                        .foregroundColor(.monologueTextSecondary)
                        .padding()
                    Button("Retry") {
                        loadData()
                    }
                }
            } else {
                VStack(spacing: 0) {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(topLists) { list in
                                chartCard(list)
                            }
                        }
                        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                        .padding(.top, 16)
                        .padding(.bottom, 120)
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
        .navigationTitle("top_charts")
        .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear {
            loadData()
        }
    }
    
    private func chartCard(_ list: TopList) -> some View {
        let isSubscribed = subManager.isPlaylistSubscribed(list.id)
        return NavigationLink(destination: PlaylistDetailView(playlist: Playlist(id: list.id, name: list.name, coverImgUrl: list.coverImgUrl, picUrl: nil, trackCount: nil, playCount: nil, subscribedCount: nil, shareCount: nil, commentCount: nil, creator: nil, description: nil, tags: nil))) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    CachedAsyncImage(url: list.coverUrl) {
                        Color.gray.opacity(0.1)
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 110)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                    
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            subManager.togglePlaylistSubscription(id: list.id)
                        }
                    } label: {
                        MonologueIcon(
                            icon: isSubscribed ? .liked : .like,
                            size: 14,
                            color: isSubscribed ? .red : .primary,
                            lineWidth: 1.4
                        )
                        .padding(6)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 1)
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.85))
                    .padding(6)
                }
                
                Text(list.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Text(list.updateFrequency)
                    .font(.system(size: 10))
                    .foregroundColor(Theme.secondaryText)
            }
        }
    }
    
    private func loadData() {
        Task {
            do {
                let lists = try await APIService.shared.fetchTopLists().async()
                topLists = lists
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
