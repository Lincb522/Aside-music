import SwiftUI
import Combine

// MARK: - 用户动态

struct UserEventView: View {
    @StateObject private var viewModel = UserEventViewModel()
    @ObservedObject private var playerManager = PlayerManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            MonologueBackground()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                if viewModel.isLoading && viewModel.events.isEmpty {
                    Spacer()
                    MonologueLoadingView(text: "LOADING EVENTS")
                    Spacer()
                } else if viewModel.events.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        MonologueIcon(icon: .send, size: 40, color: .monologueTextSecondary.opacity(0.3))
                        Text(LocalizedStringKey("event_empty"))
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(.monologueTextSecondary)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.events) { event in
                                EventCard(event: event) {
                                    if let song = event.song {
                                        playerManager.play(song: song, in: [song])
                                    }
                                }
                            }
                            
                            // 加载更多
                            if viewModel.hasMore {
                                Button(action: { viewModel.loadMore() }) {
                                    Text(LocalizedStringKey("event_load_more"))
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .foregroundColor(.monologueTextSecondary)
                                        .padding(.vertical, 12)
                                }
                            } else if !viewModel.events.isEmpty {
                                NoMoreDataView()
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        
                        Color.clear.frame(height: 100)
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
        .navigationTitle(LocalizedStringKey("event_title"))
        .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear { viewModel.fetchEvents() }
    }
}

// MARK: - 动态卡片

private struct EventCard: View {
    let event: UserEvent
    let onPlaySong: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 用户信息 + 时间
            HStack(spacing: 10) {
                if let url = event.userAvatarURL {
                    CachedAsyncImage(url: url) {
                        Circle().fill(Color.monologueSeparator)
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 38, height: 38)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.monologueSeparator)
                        .frame(width: 38, height: 38)
                        .overlay(MonologueIcon(icon: .profile, size: 16, color: .monologueTextSecondary.opacity(0.5)))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.userName)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.monologueTextPrimary)
                    
                    HStack(spacing: 6) {
                        if !event.actName.isEmpty {
                            Text(event.actName)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(.monologueIconForeground)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.monologueIconBackground.opacity(0.5))
                                .clipShape(Capsule())
                        }
                        Text(event.timeText)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.monologueTextSecondary.opacity(0.6))
                    }
                }
                
                Spacer()
            }
            
            // 动态内容
            if !event.content.isEmpty {
                Text(event.content)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(.monologueTextPrimary)
                    .lineLimit(5)
            }
            
            // 关联歌曲
            if let song = event.song {
                Button(action: onPlaySong) {
                    HStack(spacing: 10) {
                        CachedAsyncImage(url: song.coverUrl) {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.monologueSeparator)
                        }
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(song.name)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.monologueTextPrimary)
                                .lineLimit(1)
                            Text(song.artistName)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(.monologueTextSecondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        MonologueIcon(icon: .play, size: 14, color: .monologueTextSecondary)
                            .frame(width: 28, height: 28)
                            .background(Color.monologueSeparator)
                            .clipShape(Circle())
                    }
                    .padding(10)
                    .background(Color.monologueSeparator.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.monologueGlassTint)
                .monologueGlass(cornerRadius: 20)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - ViewModel

@MainActor
class UserEventViewModel: ObservableObject {
    @Published var events: [UserEvent] = []
    @Published var isLoading = false
    @Published var hasMore = false
    
    private var lasttime: Int = -1
    private var cancellables = Set<AnyCancellable>()
    
    func fetchEvents() {
        guard let uid = APIService.shared.currentUserId else { return }
        isLoading = true
        lasttime = -1
        
        APIService.shared.fetchUserEvents(uid: uid, lasttime: -1)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] _ in
                self?.isLoading = false
            }, receiveValue: { [weak self] result in
                self?.events = result.events
                self?.lasttime = result.lasttime
                self?.hasMore = result.more
            })
            .store(in: &cancellables)
    }
    
    func loadMore() {
        guard let uid = APIService.shared.currentUserId, hasMore else { return }
        
        APIService.shared.fetchUserEvents(uid: uid, lasttime: lasttime)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in },
                  receiveValue: { [weak self] result in
                self?.events.append(contentsOf: result.events)
                self?.lasttime = result.lasttime
                self?.hasMore = result.more
            })
            .store(in: &cancellables)
    }
}
