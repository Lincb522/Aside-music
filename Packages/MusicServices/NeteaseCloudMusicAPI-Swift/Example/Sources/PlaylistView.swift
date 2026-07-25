// PlaylistView.swift
// 热门歌单页面（iOS 风格，NavigationLink 进入详情）

import SwiftUI

struct PlaylistView: View {
    @ObservedObject var vm: DemoViewModel

    var body: some View {
        List {
            ForEach(Array(vm.hotPlaylists.enumerated()), id: \.offset) { _, playlist in
                NavigationLink {
                    PlaylistDetailView(vm: vm, playlistId: playlist["id"] as? Int ?? 0, playlistName: playlist["name"] as? String ?? "")
                } label: {
                    PlaylistRow(playlist: playlist)
                }
            }
        }
        .navigationTitle("歌单")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("刷新", systemImage: "arrow.clockwise") {
                    Task { await vm.fetchHotPlaylists() }
                }
                .disabled(vm.isLoading)
            }
        }
        .overlay {
            if vm.isLoading && vm.hotPlaylists.isEmpty {
                ProgressView("加载中...")
            }
        }
        .task { await vm.fetchHotPlaylists() }
    }
}

/// 歌单详情页 - 显示歌曲列表
struct PlaylistDetailView: View {
    @ObservedObject var vm: DemoViewModel
    let playlistId: Int
    let playlistName: String

    var body: some View {
        List(Array(vm.playlistTracks.enumerated()), id: \.offset) { index, track in
            HStack(spacing: 12) {
                Text("\(index + 1)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 28, alignment: .trailing)

                VStack(alignment: .leading, spacing: 2) {
                    Text(track["name"] as? String ?? "未知歌曲")
                        .lineLimit(1)
                    Text(DemoViewModel.artistNames(from: track))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(playlistName)
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if vm.isLoading && vm.playlistTracks.isEmpty {
                ProgressView("加载中...")
            }
        }
        .task {
            await vm.fetchPlaylistDetail(id: playlistId, name: playlistName)
        }
    }
}

/// 歌单行视图
struct PlaylistRow: View {
    let playlist: [String: Any]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(playlist["name"] as? String ?? "未知歌单")
                .font(.body)
                .lineLimit(1)

            HStack {
                if let playCount = playlist["playCount"] as? Int {
                    Text("播放 \(formatCount(playCount))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let trackCount = playlist["trackCount"] as? Int {
                    Text("· \(trackCount) 首")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 100_000_000 { return "\(count / 100_000_000)亿" }
        if count >= 10_000 { return "\(count / 10_000)万" }
        return "\(count)"
    }
}
