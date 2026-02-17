import SwiftUI

/// 电台详情页面，展示电台信息和节目列表
struct RadioDetailView: View {
    let radioId: Int
    @StateObject private var viewModel: RadioDetailViewModel
    @ObservedObject private var player = PlayerManager.shared
    @ObservedObject private var subManager = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showRadioPlayer = false

    init(radioId: Int) {
        self.radioId = radioId
        _viewModel = StateObject(wrappedValue: RadioDetailViewModel(radioId: radioId))
    }

    var body: some View {
        ZStack {
            AsideBackground()
                .ignoresSafeArea()

            if viewModel.isLoading && viewModel.radioDetail == nil {
                AsideLoadingView(text: "LOADING")
            } else if let error = viewModel.errorMessage, viewModel.radioDetail == nil {
                errorView(error)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        headerSection
                        programListSection
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
        }
        .onAppear {
            if viewModel.radioDetail == nil {
                viewModel.fetchDetail()
            }
        }
        .fullScreenCover(isPresented: $showRadioPlayer) {
            RadioPlayerView(radioId: radioId)
        }
    }

    // MARK: - 错误视图

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            AsideIcon(icon: .warning, size: 40, color: .asideTextSecondary)
            Text(error)
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(.asideTextSecondary)
                .multilineTextAlignment(.center)
            Button(String(localized: "radio_retry")) {
                viewModel.fetchDetail()
            }
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .foregroundColor(.asideIconForeground)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(Color.asideIconBackground)
            .clipShape(Capsule())
        }
        .padding(.horizontal, 40)
    }

    // MARK: - 电台头部信息

    private var headerSection: some View {
        VStack(spacing: 16) {
            if let radio = viewModel.radioDetail {
                CachedAsyncImage(url: radio.coverUrl) {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.asideCardBackground)
                }
                .frame(width: 160, height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)

                Text(radio.name)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.asideTextPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                HStack(spacing: 16) {
                    if let dj = radio.dj?.nickname {
                        HStack(spacing: 4) {
                            AsideIcon(icon: .profile, size: 13, color: .asideTextSecondary)
                            Text(dj)
                        }
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(.asideTextSecondary)
                    }
                    if let count = radio.programCount {
                        HStack(spacing: 4) {
                            AsideIcon(icon: .podcast, size: 13, color: .asideTextSecondary)
                            Text(String(format: String(localized: "radio_episode_count"), count))
                        }
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(.asideTextSecondary)
                    }
                }

                if let desc = radio.desc, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(.asideTextSecondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }

                // 操作按钮
                HStack(spacing: 12) {
                    // 订阅按钮
                    SubscribeButton(
                        isSubscribed: subManager.isRadioSubscribed(radio.id),
                        action: { subManager.toggleRadioSubscription(radio) }
                    )

                    // 收音机模式播放按钮
                    Button(action: { showRadioPlayer = true }) {
                        HStack(spacing: 8) {
                            AsideIcon(icon: .radio, size: 16, color: .asideIconForeground, lineWidth: 1.4)
                            Text("radio_mode")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(.asideIconForeground)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.asideIconBackground)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(AsideBouncingButtonStyle())
                }
                .padding(.top, 4)
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 24)
        .padding(.horizontal, 24)
    }

    // MARK: - 节目列表

    private var programListSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !viewModel.programs.isEmpty {
                Text("radio_program_list_title")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.asideTextPrimary)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }

            LazyVStack(spacing: 0) {
                ForEach(viewModel.programs) { program in
                    programRow(program: program)
                        .onTapGesture {
                            playProgram(program)
                        }

                    if program.id == viewModel.programs.last?.id {
                        Color.clear
                            .frame(height: 1)
                            .onAppear {
                                viewModel.loadMorePrograms()
                            }
                    }
                }

                if viewModel.isLoadingMore {
                    ProgressView()
                        .padding(.vertical, 16)
                }

                if !viewModel.hasMore && !viewModel.programs.isEmpty {
                    NoMoreDataView()
                }
            }
        }
    }

    // MARK: - 节目行

    /// 当前 player 是否正在播放本电台的内容
    private var isOwnContent: Bool {
        if case .podcast(let id) = player.playSource, id == radioId {
            return true
        }
        return false
    }

    private func programRow(program: RadioProgram) -> some View {
        let isCurrentPlaying = isOwnContent && player.currentSong?.id == program.mainSong?.id && player.isPlaying

        return HStack(spacing: 14) {
            CachedAsyncImage(url: program.programCoverUrl) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.asideCardBackground)
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                Group {
                    if isCurrentPlaying {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.3))
                        AsideIcon(icon: .waveform, size: 16, color: .white, lineWidth: 1.6)
                    }
                }
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(program.name ?? String(localized: "radio_unknown_program"))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(isCurrentPlaying ? .asideAccentBlue : .asideTextPrimary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if !program.durationText.isEmpty {
                        Text(program.durationText)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.asideTextSecondary)
                    }
                    if let listeners = program.listenerCount, listeners > 0 {
                        Text(String(format: String(localized: "radio_play_count"), formatCount(listeners)))
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.asideTextSecondary)
                    }
                }
            }

            Spacer()

            if program.mainSong != nil {
                AsideIcon(icon: .playCircle, size: 22, color: .asideTextSecondary, lineWidth: 1.4)
            } else {
                Text("radio_not_playable")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.asideTextSecondary.opacity(0.6))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private func playProgram(_ program: RadioProgram) {
        guard let song = program.mainSong else { return }
        let songs = viewModel.songsFromPrograms()
        player.playPodcast(song: song, in: songs, radioId: radioId)
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 100_000_000 {
            return String(format: "%.1f亿", Double(count) / 100_000_000)
        } else if count >= 10_000 {
            return String(format: "%.1f万", Double(count) / 10_000)
        }
        return "\(count)"
    }
}
