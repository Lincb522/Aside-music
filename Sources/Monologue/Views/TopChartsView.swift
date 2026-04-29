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
            if MangaStyle.isActive {
                MangaRootBackdrop()
            } else if MujiStyle.isActive {
                MujiRootBackdrop()
            } else {
                ThemedPageBackground()
            }

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
                        if MangaStyle.isActive {
                            MangaPageHeader(
                                eyebrow: "RANKING",
                                title: String(localized: "top_charts"),
                                subtitle: ""
                            ) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(MangaStyle.bubblePink)
                                    MonologueIcon(icon: .chart, size: 23, color: MangaStyle.ink, lineWidth: 2)
                                }
                                .frame(width: 48, height: 48)
                                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.strokeWidth))
                                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(MangaStyle.strokeInk).offset(x: 2.5, y: 2.5))
                            }
                        } else if MujiStyle.isActive {
                            MujiPageHeader(
                                eyebrow: String(localized: "lib_tab_charts"),
                                title: String(localized: "top_charts"),
                                subtitle: ""
                            ) {
                                MujiIconBadge(icon: .chart, tint: MujiStyle.indigo, size: 48)
                            }
                        } else if NeumorphicStyle.isActive {
                            NeumorphicPageHeader(
                                eyebrow: "RANKING",
                                title: String(localized: "top_charts"),
                                subtitle: ""
                            ) {
                                NeumorphicIconBadge(icon: .chart, tint: NeumorphicStyle.warm, size: 48)
                            }
                        }

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
            .themeRenderScrollLayer()
                }
            }
        }
        .navigationTitle(ThemedPageStyle.isActive ? "" : "top_charts")
        .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear {
            loadData()
        }
    }

    private func chartCard(_ list: TopList) -> some View {
        let isSubscribed = subManager.isPlaylistSubscribed(list.id)
        return NavigationLink(
            destination: PlaylistDetailView(playlist: Playlist(id: list.id, name: list.name, coverImgUrl: list.coverImgUrl, picUrl: nil, trackCount: nil, playCount: nil, subscribedCount: nil, shareCount: nil, commentCount: nil, creator: nil, description: nil, tags: nil))

        ) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    CachedAsyncImage(url: list.coverUrl) {
                        MangaStyle.isActive ? MangaStyle.paperCool : (MujiStyle.isActive ? MujiStyle.surfaceRaised : (NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.gray.opacity(0.1)))
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 110)
                    .clipShape(RoundedRectangle(cornerRadius: MangaStyle.isActive ? 8 : (MujiStyle.isActive ? 8 : (NeumorphicStyle.isActive ? 16 : 12)), style: .continuous))
                    .overlay {
                        if MangaStyle.isActive {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.fineStrokeWidth)
                        } else if MujiStyle.isActive {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(MujiStyle.hairline.opacity(0.55), lineWidth: 0.6)
                        } else if NeumorphicStyle.isActive {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(NeumorphicStyle.separator.opacity(0.34), lineWidth: 0.7)
                        }
                    }
                    .shadow(color: Color.black.opacity(ThemedPageStyle.isActive ? 0.055 : 0.1), radius: ThemedPageStyle.isActive ? 8 : 5, x: 0, y: ThemedPageStyle.isActive ? 4 : 2)

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            subManager.togglePlaylistSubscription(id: list.id)
                        }
                    } label: {
                        MonologueIcon(
                            icon: isSubscribed ? .liked : .like,
                            size: 14,
                            color: MangaStyle.isActive ? (isSubscribed ? MangaStyle.red : MangaStyle.strokeInk) : (MujiStyle.isActive ? (isSubscribed ? MujiStyle.red : MujiStyle.inkSoft) : (NeumorphicStyle.isActive ? (isSubscribed ? NeumorphicStyle.red : NeumorphicStyle.inkSoft) : (isSubscribed ? .red : .primary))),
                            lineWidth: 1.4
                        )
                        .padding(6)
                        .background {
                            if MangaStyle.isActive {
                                Circle().fill(MangaStyle.labelYellow)
                            } else if MujiStyle.isActive {
                                Circle().fill(MujiStyle.surface.opacity(0.92))
                            } else if NeumorphicStyle.isActive {
                                Circle().fill(NeumorphicStyle.surfaceRaised.opacity(0.94))
                            } else {
                                Circle().fill(.ultraThinMaterial)
                            }
                        }
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 1)
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.85))
                    .padding(6)
                }

                Text(list.name)
                    .font(MangaStyle.isActive ? MangaStyle.bodyFont(12, weight: .black) : (MujiStyle.isActive ? MujiStyle.bodyFont(12, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(12, weight: .semibold) : .system(size: 12, weight: .medium))))
                    .foregroundColor(MangaStyle.isActive ? MangaStyle.ink : (MujiStyle.isActive ? MujiStyle.ink : (NeumorphicStyle.isActive ? NeumorphicStyle.ink : Theme.text)))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(list.updateFrequency)
                    .font(MangaStyle.isActive ? MangaStyle.bodyFont(10, weight: .bold) : (MujiStyle.isActive ? MujiStyle.labelFont(10, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(10, weight: .medium) : .system(size: 10))))
                    .foregroundColor(MangaStyle.isActive ? MangaStyle.inkSub : (MujiStyle.isActive ? MujiStyle.inkSoft : (NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : Theme.secondaryText)))
            }
            .padding(ThemedPageStyle.isActive ? 8 : 0)
            .background {
                if MangaStyle.isActive {
                    MangaCardBackground(cornerRadius: 10, elevated: true, tint: MangaStyle.bubbleWhite)
                } else if MujiStyle.isActive {
                    MujiPaperCardBackground(cornerRadius: 10)
                } else if NeumorphicStyle.isActive {
                    NeumorphicSurfaceBackground(cornerRadius: 18, elevated: false)
                }
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
