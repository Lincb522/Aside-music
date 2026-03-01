// NewSongExpressView.swift
// 新歌速递页面 — 全新卡片式设计

import SwiftUI

struct NewSongExpressView: View {
    @State private var viewModel = NewSongExpressViewModel()
    @ObservedObject private var playerManager = PlayerManager.shared
    @State private var selectedArtistId: Int?
    @State private var showArtistDetail = false
    @State private var selectedSongForDetail: Song?
    @State private var showSongDetail = false
    @State private var selectedAlbumId: Int?
    @State private var showAlbumDetail = false
    
    var body: some View {
        ZStack {
            AsideBackground()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerSection
                typeSelector
                
                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                        .tint(.asideTextSecondary)
                    Spacer()
                } else if viewModel.songs.isEmpty {
                    Spacer()
                    emptyState
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // 完整列表
                            fullListSection
                        }
                        .padding(.bottom, 120)
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showArtistDetail) {
            if let id = selectedArtistId { ArtistDetailView(artistId: id) }
        }
        .navigationDestination(isPresented: $showSongDetail) {
            if let song = selectedSongForDetail { SongDetailView(song: song) }
        }
        .navigationDestination(isPresented: $showAlbumDetail) {
            if let id = selectedAlbumId { AlbumDetailView(albumId: id, albumName: nil, albumCoverUrl: nil) }
        }
        .onAppear {
            if viewModel.songs.isEmpty {
                viewModel.loadSongs(type: 0)
            }
        }
    }
    
    // MARK: - 顶部栏
    
    private var headerSection: some View {
        HStack {
            AsideBackButton()
            Spacer()
            Text(LocalizedStringKey("new_song_express"))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.asideTextPrimary)
            Spacer()
            // 随机播放
            Button {
                let shuffled = viewModel.songs.shuffled()
                if let first = shuffled.first {
                    playerManager.play(song: first, in: shuffled)
                }
            } label: {
                AsideIcon(icon: .shuffle, size: 18, color: .asideTextPrimary)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(AsideBouncingButtonStyle())
            .opacity(viewModel.songs.isEmpty ? 0.3 : 1)
            .disabled(viewModel.songs.isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.top, DeviceLayout.headerTopPadding)
    }
    
    // MARK: - 语种选择
    
    private var typeSelector: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(NewSongExpressViewModel.songTypes) { type in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.loadSongs(type: type.id)
                        }
                    } label: {
                        let isSelected = viewModel.selectedType == type.id
                        Text(LocalizedStringKey(type.nameKey))
                            .font(.system(size: 14, weight: isSelected ? .bold : .medium, design: .rounded))
                            .foregroundColor(isSelected ? .asideIconForeground : .asideTextSecondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(isSelected ? Color.asideAccent : Color.clear)
                            )
                            .clipShape(Capsule())
                            .glassEffect(.regular, in: .capsule)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
        .scrollIndicators(.hidden)
    }
    
    // MARK: - 空状态
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            AsideIcon(icon: .musicNote, size: 40, color: .asideTextSecondary.opacity(0.3))
            Text(LocalizedStringKey("empty_no_results"))
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.asideTextSecondary)
        }
    }
    
    // MARK: - 完整列表
    
    private var fullListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 播放全部按钮
            HStack {
                Button(action: {
                    if let first = viewModel.songs.first {
                        playerManager.play(song: first, in: viewModel.songs)
                    }
                }) {
                    HStack(spacing: 6) {
                        AsideIcon(icon: .play, size: 12, color: .white)
                        Text(LocalizedStringKey("artist_play_all"))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.accentColor)
                    .clipShape(Capsule())
                }
                .buttonStyle(AsideBouncingButtonStyle(scale: 0.95))
                
                Spacer()
                
                Text(String(format: NSLocalizedString("songs_count_format", comment: ""), viewModel.songs.count))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.asideTextSecondary)
            }
            .padding(.horizontal, 24)
            
            // 歌曲列表
            LazyVStack(spacing: 0) {
                ForEach(Array(viewModel.songs.enumerated()), id: \.element.id) { index, song in
                    SongListRow(
                        song: song,
                        index: index,
                        onArtistTap: { id in
                            selectedArtistId = id
                            showArtistDetail = true
                        },
                        onDetailTap: { s in
                            selectedSongForDetail = s
                            showSongDetail = true
                        },
                        onAlbumTap: { id in
                            selectedAlbumId = id
                            showAlbumDetail = true
                        }
                    )
                    .asButton {
                        playerManager.play(song: song, in: viewModel.songs)
                    }
                }
                
                NoMoreDataView()
            }
        }
    }
}
