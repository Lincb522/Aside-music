// SearchView.swift
// 搜索歌曲页面（iOS 风格）

import SwiftUI

struct SearchView: View {
    @ObservedObject var vm: DemoViewModel

    var body: some View {
        List {
            if vm.searchResults.isEmpty && !vm.isLoading {
                ContentUnavailableView("搜索歌曲", systemImage: "magnifyingglass", description: Text("输入关键词开始搜索"))
            }

            ForEach(Array(vm.searchResults.enumerated()), id: \.offset) { _, song in
                NavigationLink {
                    LyricView(vm: vm, songId: song["id"] as? Int ?? 0, songName: song["name"] as? String ?? "未知歌曲")
                } label: {
                    SongRow(song: song)
                }
            }

            if let error = vm.errorMessage {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        }
        .navigationTitle("搜索")
        .searchable(text: $vm.searchKeyword, prompt: "搜索歌曲、歌手...")
        .onSubmit(of: .search) {
            Task { await vm.searchSongs() }
        }
        .overlay {
            if vm.isLoading && vm.searchResults.isEmpty {
                ProgressView("搜索中...")
            }
        }
    }
}

/// 歌词详情页
struct LyricView: View {
    @ObservedObject var vm: DemoViewModel
    let songId: Int
    let songName: String

    var body: some View {
        ScrollView {
            if vm.selectedSongLyric.isEmpty {
                ProgressView("加载歌词...")
                    .padding(.top, 40)
            } else {
                Text(vm.selectedSongLyric)
                    .font(.body)
                    .textSelection(.enabled)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .navigationTitle(songName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await vm.fetchLyric(songId: songId, songName: songName)
        }
    }
}

/// 歌曲行视图
struct SongRow: View {
    let song: [String: Any]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(song["name"] as? String ?? "未知歌曲")
                .font(.body)
                .lineLimit(1)

            HStack {
                Text(DemoViewModel.artistNames(from: song))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                let album = DemoViewModel.albumName(from: song)
                if !album.isEmpty {
                    Text("·").foregroundStyle(.secondary)
                    Text(album)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
