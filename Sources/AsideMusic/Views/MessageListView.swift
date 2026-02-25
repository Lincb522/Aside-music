import SwiftUI
import Combine

// MARK: - 私信列表

struct MessageListView: View {
    @StateObject private var viewModel = MessageListViewModel()
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
                    Text(LocalizedStringKey("message_title"))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.asideTextPrimary)
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 16)
                .padding(.top, DeviceLayout.headerTopPadding)
                
                if viewModel.isLoading && viewModel.messages.isEmpty {
                    Spacer()
                    AsideLoadingView(text: "LOADING MESSAGES")
                    Spacer()
                } else if viewModel.messages.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        AsideIcon(icon: .send, size: 40, color: .asideTextSecondary.opacity(0.3))
                        Text(LocalizedStringKey("message_empty"))
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(.asideTextSecondary)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.messages) { msg in
                                NavigationLink(destination: ChatDetailView(userId: msg.userId, nickname: msg.nickname, avatarUrl: msg.avatarUrl)) {
                                    MessageRow(message: msg)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, 8)
                        
                        Color.clear.frame(height: 100)
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.fetchMessages() }
    }
}

// MARK: - 私信行

private struct MessageRow: View {
    let message: PrivateMessage
    
    var body: some View {
        HStack(spacing: 14) {
            // 头像
            ZStack(alignment: .topTrailing) {
                if let url = message.avatarURL {
                    CachedAsyncImage(url: url) {
                        Circle().fill(Color.asideSeparator)
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.asideSeparator)
                        .frame(width: 50, height: 50)
                        .overlay(AsideIcon(icon: .profile, size: 22, color: .asideTextSecondary.opacity(0.5)))
                }
                
                // 未读标记
                if message.newMsgCount > 0 {
                    Text("\(min(message.newMsgCount, 99))")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .clipShape(Capsule())
                        .offset(x: 4, y: -4)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(message.nickname)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.asideTextPrimary)
                        .lineLimit(1)
                    Spacer()
                    Text(message.timeText)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.asideTextSecondary.opacity(0.6))
                }
                
                Text(message.lastMsg)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(.asideTextSecondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - ViewModel

@MainActor
class MessageListViewModel: ObservableObject {
    @Published var messages: [PrivateMessage] = []
    @Published var isLoading = false
    
    private var cancellables = Set<AnyCancellable>()
    
    func fetchMessages() {
        isLoading = true
        APIService.shared.fetchPrivateMessages()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] _ in
                self?.isLoading = false
            }, receiveValue: { [weak self] msgs in
                self?.messages = msgs
            })
            .store(in: &cancellables)
    }
}
