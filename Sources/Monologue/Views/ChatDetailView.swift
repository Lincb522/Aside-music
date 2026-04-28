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
            ThemedPageBackground()
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
                        .font(NeumorphicStyle.isActive ? NeumorphicStyle.bodyFont(15, weight: .medium) : .system(size: 15, design: .rounded))
                        .monologueTextInputBehavior()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(ThemedPageStyle.isActive ? Color.clear : Color.monologueGlassTint)
                        .themedOnlyPageSurface(cornerRadius: 20, elevated: false)
                        .clipShape(Capsule())
                        .focused($isInputFocused)
                    
                    Button(action: sendMessage) {
                        MonologueIcon(icon: .send, size: 20, color: inputText.isEmpty ? (NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : .monologueTextSecondary.opacity(0.4)) : (NeumorphicStyle.isActive ? NeumorphicStyle.accent : .monologueTextPrimary))
                            .frame(width: 40, height: 40)
                            .background(NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.monologueGlassTint)
                            .clipShape(Circle())
                    }
                    .disabled(inputText.isEmpty)
                    .buttonStyle(MonologueBouncingButtonStyle())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .themedPageSurface(cornerRadius: MangaStyle.isActive ? 20 : 16, elevated: false)
            }
        }
        .themedNavigationChrome(title: nickname, eyebrow: "CHAT", icon: .comment)
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
                    .font(MangaStyle.isActive ? MangaStyle.comicFont(14, weight: .medium) : (MujiStyle.isActive ? MujiStyle.bodyFont(14, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.bodyFont(14, weight: .medium) : .system(size: 14, weight: .regular, design: .rounded))))
                    .foregroundColor(bubbleTextColor)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(bubbleBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        if MangaStyle.isActive {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.strokeWidth)
                        } else if MujiStyle.isActive {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(MujiStyle.hairline.opacity(0.35), lineWidth: 0.6)
                        } else if NeumorphicStyle.isActive {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(NeumorphicStyle.separator.opacity(0.42), lineWidth: 0.7)
                        }
                    }
                    .monologueGlass(cornerRadius: 16)
                
                Text(message.timeText)
                    .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(10, weight: .medium) : .system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : .monologueTextSecondary.opacity(0.5))
            }
            
            if !isMe { Spacer(minLength: 60) }
        }
    }

    private var bubbleBackground: Color {
        if MangaStyle.isActive {
            return isMe ? MangaStyle.labelYellow : MangaStyle.bubbleWhite
        } else if MujiStyle.isActive {
            return isMe ? MujiStyle.clay : MujiStyle.surfaceRaised
        } else if NeumorphicStyle.isActive {
            return isMe ? NeumorphicStyle.accent.opacity(0.18) : NeumorphicStyle.surfacePressed.opacity(0.74)
        } else {
            return isMe ? Color.monologueAccent.opacity(0.15) : Color.monologueGlassTint
        }
    }

    private var bubbleTextColor: Color {
        if MangaStyle.isActive {
            return MangaStyle.ink
        } else if MujiStyle.isActive {
            return isMe ? MujiStyle.paper : .monologueTextPrimary
        } else if NeumorphicStyle.isActive {
            return isMe ? NeumorphicStyle.accent : NeumorphicStyle.ink
        } else {
            return isMe ? .white : .monologueTextPrimary
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
