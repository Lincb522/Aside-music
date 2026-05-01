import SwiftUI

struct QCMNewSongsView: View {
    @ObservedObject private var viewModel = HomeViewModel.shared
    @ObservedObject private var playerManager = PlayerManager.shared
    @ObservedObject private var settings = SettingsManager.shared
    @State private var isSelectMode = false
    @State private var selectedSongIds: Set<Int> = []
    @State private var showBatchAddToPlaylist = false

    private var songs: [Song] {
        viewModel.qqNewSongs
    }

    private var qcmAccent: Color {
        return NeumorphicStyle.isActive ? NeumorphicStyle.accent : MusicSource.qqmusic.themedBadgeColor
    }

    private var qcmAccentForeground: Color {
        if NeumorphicStyle.isActive {
            return ThemeColorCustomization.readableForegroundColor(
                on: NeumorphicStyle.accent,
                light: Color(hex: "172026"),
                dark: .white
            )
        }
        return Color(light: .white, dark: .black)
    }

    private var qcmPrimaryText: Color {
        return NeumorphicStyle.isActive ? NeumorphicStyle.ink : .monologueTextPrimary
    }

    private var qcmSecondaryText: Color {
        return NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : .monologueTextSecondary
    }

    var body: some View {
        let _ = settings.globalThemeRevision

        ZStack {
            ThemedPageBackground()
                .ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: ThemedPageStyle.isActive ? 10 : 0) {
                    header

                    if viewModel.isLoading && songs.isEmpty {
                        loadingState
                    } else if songs.isEmpty {
                        emptyState
                    } else {
                        toolbar

                        ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                            SongListRow(
                                song: song,
                                index: index,
                                isSelecting: isSelectMode,
                                isSelected: selectedSongIds.contains(song.id),
                                onTap: {
                                    if isSelectMode {
                                        toggleSelection(song.id)
                                    } else {
                                        playerManager.play(song: song, in: songs)
                                    }
                                }
                            )
                        }
                    }

                    FloatingBarBottomSpacer()
                }
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
        .navigationTitle(ThemedPageStyle.isActive ? "" : "QCM 新歌")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    playAll()
                } label: {
                    MonologueIcon(icon: .play, size: 16)
                }
                .disabled(songs.isEmpty)
                .opacity(songs.isEmpty ? 0.35 : 1)
            }
        }
        .onAppear {
            if songs.isEmpty {
                viewModel.fetchData()
            }
        }
        .monologueSheet(isPresented: $showBatchAddToPlaylist, preset: .standard) {
            BatchAddToPlaylistSheet(songs: songs.filter { selectedSongIds.contains($0.id) })
        }
    }

    @ViewBuilder
    private var header: some View {
        if SignalStyle.isActive {
            SignalPageHeader(
                eyebrow: "QCM NEW",
                title: "QCM 新歌",
                subtitle: "\(songs.count) \(String(localized: "首"))"
            ) {
                SignalIconBadge(icon: .musicNote, tint: MusicSource.qqmusic.themedBadgeColor, size: 48)
            }
            .padding(.bottom, 2)
        } else if ThemedPageStyle.isActive {
            ThemedPageHeader(
                eyebrow: "QCM NEW",
                title: "QCM 新歌",
                subtitle: "\(songs.count) \(String(localized: "首"))",
                icon: .musicNote
            )
            .padding(.bottom, 2)
        } else {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("QCM NEW")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.monologueTextSecondary)
                        .tracking(1.3)

                    Text("QCM 新歌")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.monologueTextPrimary)

                    Text("\(songs.count) \(String(localized: "首"))")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.monologueTextSecondary)
                }

                Spacer(minLength: 10)

                MonologueIcon(icon: .musicNote, size: 22, color: .monologueTextPrimary, lineWidth: 1.8)
                    .frame(width: 46, height: 46)
                    .background(Color.monologueTextPrimary.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.top, DeviceLayout.headerTopPadding + 8)
            .padding(.bottom, 12)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Button {
                playAll()
            } label: {
                toolbarPill(title: String(localized: "artist_play_all"), icon: .play, tint: qcmAccent)
            }
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))

            Spacer(minLength: 8)

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                    isSelectMode.toggle()
                    if !isSelectMode {
                        selectedSongIds.removeAll()
                    }
                }
            } label: {
                toolbarIcon(icon: isSelectMode ? .close : .checkmark, tint: isSelectMode ? qcmSecondaryText : qcmAccent)
            }
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))

            if isSelectMode {
                Button {
                    showBatchAddToPlaylist = true
                } label: {
                    toolbarIcon(icon: .add, tint: qcmAccent)
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))
                .disabled(selectedSongIds.isEmpty)
                .opacity(selectedSongIds.isEmpty ? 0.4 : 1)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.vertical, ThemedPageStyle.isActive ? 4 : 8)
    }

    private func toolbarPill(title: String, icon: MonologueIcon.IconType, tint: Color) -> some View {
        Group {
            if SignalStyle.isActive {
                SignalPlayPill(title: title, icon: icon, tint: tint)
            } else {
                HStack(spacing: 7) {
                    MonologueIcon(icon: icon, size: 12, color: qcmAccentForeground, lineWidth: 1.7)
                        .frame(width: 24, height: 24)
                        .background(tint, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                    Text(title)
                        .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(12, weight: .semibold) : .rounded(size: 13, weight: .semibold))
                        .foregroundStyle(qcmPrimaryText)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .themedPageSurface(cornerRadius: 15, elevated: false)
            }
        }
    }

    private func toolbarIcon(icon: MonologueIcon.IconType, tint: Color) -> some View {
        MonologueIcon(icon: icon, size: 13, color: tint, lineWidth: 1.7)
            .frame(width: 32, height: 32)
            .themedPageSurface(cornerRadius: 13, elevated: true)
    }

    private var loadingState: some View {
        MonologueLoadingView(text: "LOADING QCM")
            .frame(maxWidth: .infinity)
            .padding(.top, 120)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            if SignalStyle.isActive {
                SignalIconBadge(icon: .musicNote, tint: MusicSource.qqmusic.themedBadgeColor, size: 54)
            } else if NeumorphicStyle.isActive {
                NeumorphicIconBadge(icon: .musicNote, tint: qcmAccent, size: 54)
            } else {
                MonologueIcon(icon: .musicNote, size: 38, color: MusicSource.qqmusic.themedBadgeColor.opacity(0.65), lineWidth: 1.7)
            }
            Text("暂无 QCM 新歌")
                .font(SignalStyle.isActive ? SignalStyle.bodyFont(15, weight: .semibold) : (NeumorphicStyle.isActive ? NeumorphicStyle.bodyFont(15, weight: .semibold) : .rounded(size: 15, weight: .semibold)))
                .foregroundStyle(SignalStyle.isActive ? SignalStyle.inkSoft : qcmSecondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 120)
    }

    private func toggleSelection(_ id: Int) {
        if selectedSongIds.contains(id) {
            selectedSongIds.remove(id)
        } else {
            selectedSongIds.insert(id)
        }
    }

    private func playAll() {
        guard let first = songs.first else { return }
        playerManager.play(song: first, in: songs)
    }
}
