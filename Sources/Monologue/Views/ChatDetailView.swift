import SwiftUI
import Combine

// MARK: - 聊天详情

struct ChatDetailView: View {
    let userId: Int
    let nickname: String
    let avatarUrl: String?
    
    @StateObject private var viewModel = ChatDetailViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        ZStack {
            MonologueBackground()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 消息列表
                if viewModel.isLoading && viewModel.messages.isEmpty {
                    Spacer()
                    MonologueLoadingView(text: "LOADING CHAT")
                    Spacer()
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.messages) { msg in
                                    ChatBubble(
                                        message: msg,
                                        isMe: msg.fromUserId == APIService.shared.currentUserId
                                    )
                                    .id(msg.id)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .scrollIndicators(.hidden)
                        .onChange(of: viewModel.messages.count) {
                            if let last = viewModel.messages.last {
                                withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                            }
                        }
                    }
                }
                
                // 输入栏
                HStack(spacing: 12) {
                    TextField(String(localized: "message_input_placeholder"), text: $inputText)
                        .font(.system(size: 15, design: .rounded))
                        .monologueTextInputBehavior()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.monologueGlassTint)
                        .clipShape(Capsule())
                        .focused($isInputFocused)
                    
                    Button(action: sendMessage) {
                        MonologueIcon(icon: .send, size: 20, color: inputText.isEmpty ? .monologueTextSecondary.opacity(0.4) : .monologueTextPrimary)
                            .frame(width: 40, height: 40)
                            .background(Color.monologueGlassTint)
                            .clipShape(Circle())
                    }
                    .disabled(inputText.isEmpty)
                    .buttonStyle(MonologueBouncingButtonStyle())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.clear).monologueGlass(cornerRadius: 16)
            }
        }
        .navigationTitle(nickname)
        .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear { viewModel.fetchHistory(uid: userId) }
    }
    
    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        viewModel.sendText(userIds: [userId], msg: text)
    }
}

// MARK: - 聊天气泡

private struct ChatBubble: View {
    let message: ChatMessage
    let isMe: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if isMe { Spacer(minLength: 60) }
            
            if !isMe {
                if let url = message.fromAvatarURL {
                    CachedAsyncImage(url: url) {
                        Circle().fill(Color.monologueSeparator)
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.monologueSeparator)
                        .frame(width: 36, height: 36)
                }
            }
            
            VStack(alignment: isMe ? .trailing : .leading, spacing: 4) {
                Text(message.msg)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(isMe ? .white : .monologueTextPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(isMe ? Color.monologueAccent.opacity(0.15) : Color.monologueGlassTint)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .monologueGlass(cornerRadius: 16)
                
                Text(message.timeText)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.monologueTextSecondary.opacity(0.5))
            }
            
            if !isMe { Spacer(minLength: 60) }
        }
    }
}

// MARK: - ViewModel

@MainActor
class ChatDetailViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    
    private var cancellables = Set<AnyCancellable>()
    
    func fetchHistory(uid: Int) {
        isLoading = true
        APIService.shared.fetchPrivateHistory(uid: uid)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] _ in
                self?.isLoading = false
            }, receiveValue: { [weak self] msgs in
                self?.messages = msgs.reversed()
            })
            .store(in: &cancellables)
    }
    
    func sendText(userIds: [Int], msg: String) {
        APIService.shared.sendTextMessage(userIds: userIds, msg: msg)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in },
                  receiveValue: { [weak self] _ in
                // 发送成功后刷新
                if let uid = userIds.first {
                    self?.fetchHistory(uid: uid)
                }
            })
            .store(in: &cancellables)
    }
}
