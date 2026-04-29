import SwiftUI
import Combine

// MARK: - 私信列表

struct MessageListView: View {
    @StateObject private var viewModel = MessageListViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            ThemedPageBackground()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                if viewModel.isLoading && viewModel.messages.isEmpty {
                    Spacer()
                    MonologueLoadingView(text: "LOADING MESSAGES")
                    Spacer()
                } else if viewModel.messages.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        MonologueIcon(icon: .send, size: 40, color: .monologueTextSecondary.opacity(0.3))
                        Text(LocalizedStringKey("message_empty"))
                            .font(NeumorphicStyle.isActive ? NeumorphicStyle.bodyFont(15, weight: .medium) : .system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : .monologueTextSecondary)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: ThemedPageStyle.listSpacing) {
                            ForEach(viewModel.messages) { msg in
                                NavigationLink(destination: ChatDetailView(userId: msg.userId, nickname: msg.nickname, avatarUrl: msg.avatarUrl)) {
                                    MessageRow(message: msg)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, ThemedPageStyle.horizontalInset)
                        .padding(.top, 8)
                        
                        FloatingBarBottomSpacer()
                    }
                    .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
                }
            }
        }
        .themedNavigationChrome(title: String(localized: "message_title"), eyebrow: "MESSAGE", icon: .bell)
        .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
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
                        Circle().fill(NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.monologueSeparator)
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.monologueSeparator)
                        .frame(width: 50, height: 50)
                        .overlay(MonologueIcon(icon: .profile, size: 22, color: NeumorphicStyle.isActive ? NeumorphicStyle.accent : .monologueTextSecondary.opacity(0.5)))
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
                        .font(NeumorphicStyle.isActive ? NeumorphicStyle.bodyFont(15, weight: .semibold) : .system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.ink : .monologueTextPrimary)
                        .lineLimit(1)
                    Spacer()
                    Text(message.timeText)
                        .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(12, weight: .medium) : .system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : .monologueTextSecondary.opacity(0.6))
                }
                
                Text(message.lastMsg)
                    .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(13, weight: .medium) : .system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : .monologueTextSecondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, ThemedPageStyle.isActive ? 16 : 20)
        .padding(.vertical, 12)
        .themedOnlyPageSurface(cornerRadius: ThemedPageStyle.compactSurfaceCornerRadius, elevated: false)
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
