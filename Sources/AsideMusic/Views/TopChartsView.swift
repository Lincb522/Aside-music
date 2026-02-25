import SwiftUI

struct TopChartsView: View {
    @State private var topLists: [TopList] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    typealias Theme = PlaylistDetailView.Theme
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        ZStack {
            AsideBackground()
            
            if isLoading {
                AsideLoadingView(text: "LOADING CHARTS")
            } else if let error = errorMessage {
                VStack {
                    AsideIcon(icon: .warning, size: 48, color: .asideTextSecondary)
                    Text(error)
                        .foregroundColor(.asideTextSecondary)
                        .padding()
                    Button("Retry") {
                        loadData()
                    }
                }
            } else {
                VStack(spacing: 0) {
                    HStack {
                        AsideBackButton()
                        Spacer()
                        Text(LocalizedStringKey("top_charts"))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.text)
                        Spacer()
                        Color.clear.frame(width: 44, height: 44)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, DeviceLayout.headerTopPadding)
                    .padding(.bottom, 16)
                    
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(topLists) { list in
                                NavigationLink(destination: PlaylistDetailView(playlist: Playlist(id: list.id, name: list.name, coverImgUrl: list.coverImgUrl, picUrl: nil, trackCount: nil, playCount: nil, subscribedCount: nil, shareCount: nil, commentCount: nil, creator: nil, description: nil, tags: nil))) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        CachedAsyncImage(url: list.coverUrl) {
                                            Color.gray.opacity(0.1)
                                        }
                                        .aspectRatio(contentMode: .fill)
                                        .frame(height: 110)
                                        .cornerRadius(12)
                                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                                        
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
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 120)
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            loadData()
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
