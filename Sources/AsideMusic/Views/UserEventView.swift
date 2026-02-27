import SwiftUI
import Combine

// MARK: - 用户动态

struct UserEventView: View {
    @StateObject private var viewModel = UserEventViewModel()
    @ObservedObject private var playerManager = PlayerManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            AsideBackground()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 顶部栏
                HStack {
                    AsideBackButton()
                    Spacer()
                    Text(LocalizedStringKey("event_title"))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.asideTextPrimary)
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 16)
                .padding(.top, DeviceLayout.headerTopPadding)
                
                if viewModel.isLoading && viewModel.events.isEmpty {
                    Spacer()
                    AsideLoadingView(text: "LOADING EVENTS")
                    Spacer()
                } else if viewModel.events.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        AsideIcon(icon: .send, size: 40, color: .asideTextSecondary.opacity(0.3))
                        Text(LocalizedStringKey("event_empty"))
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(.asideTextSecondary)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.events) { event in
                                EventCard(event: event) {
                                    if let song = event.song {
                                        playerManager.playSingle(song: song)
                                    }
                                }
                            }
                            
                            // 加载更多
                            if viewModel.hasMore {
                                Button(action: { viewModel.loadMore() }) {
                                    Text(LocalizedStringKey("event_load_more"))
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .foregroundColor(.asideTextSecondary)
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
        .toolbar(.hidden, for: .navigationBar)
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
                        Circle().fill(Color.asideSeparator)
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 38, height: 38)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.asideSeparator)
                        .frame(width: 38, height: 38)
                        .overlay(AsideIcon(icon: .profile, size: 16, color: .asideTextSecondary.opacity(0.5)))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.userName)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.asideTextPrimary)
                    
                    HStack(spacing: 6) {
                        if !event.actName.isEmpty {
                            Text(event.actName)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(.asideIconForeground)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.asideIconBackground.opacity(0.5))
                                .clipShape(Capsule())
                        }
                        Text(event.timeText)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.asideTextSecondary.opacity(0.6))
                    }
                }
                
                Spacer()
            }
            
            // 动态内容
            if !event.content.isEmpty {
                Text(event.content)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(.asideTextPrimary)
                    .lineLimit(5)
            }
            
            // 关联歌曲
            if let song = event.song {
                Button(action: onPlaySong) {
                    HStack(spacing: 10) {
                        CachedAsyncImage(url: song.coverUrl) {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.asideSeparator)
                        }
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(song.name)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.asideTextPrimary)
                                .lineLimit(1)
                            Text(song.artistName)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(.asideTextSecondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        AsideIcon(icon: .play, size: 14, color: .asideTextSecondary)
                            .frame(width: 28, height: 28)
                            .background(Color.asideSeparator)
                            .clipShape(Circle())
                    }
                    .padding(10)
                    .background(Color.asideSeparator.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(AsideBouncingButtonStyle(scale: 0.98))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.asideGlassTint)
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
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
