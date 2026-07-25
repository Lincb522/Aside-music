// AlbumView.swift
// 专辑模块测试页面

import SwiftUI

struct AlbumView: View {
    @ObservedObject var vm: DemoViewModel

    var body: some View {
        List {
            // 新碟上架
            Section("新碟上架") {
                Button {
                    Task { await vm.fetchNewAlbums() }
                } label: {
                    Label("加载新碟", systemImage: "opticaldisc")
                }
                .disabled(vm.isLoading)

                ForEach(Array(vm.newAlbums.enumerated()), id: \.offset) { _, album in
                    let name = album["name"] as? String ?? "未知"
                    let artist = (album["artist"] as? [String: Any])?["name"] as? String
                        ?? (album["artists"] as? [[String: Any]])?.first?["name"] as? String
                        ?? "未知"
                    let id = album["id"] as? Int ?? 0

                    Button {
                        Task { await vm.fetchAlbumDetail(id: id, name: name) }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(name).font(.subheadline)
                            Text(artist).font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
            }

            // 专辑详情
            if !vm.albumDetailName.isEmpty {
                Section("专辑: \(vm.albumDetailName)") {
                    ForEach(Array(vm.albumTracks.enumerated()), id: \.offset) { i, song in
                        let name = song["name"] as? String ?? "未知"
                        let artist = DemoViewModel.artistNames(from: song)
                        HStack {
                            Text("\(i + 1)").font(.caption).foregroundColor(.secondary)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(name).font(.subheadline)
                                Text(artist).font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }

            // 最新专辑
            Section("最新专辑") {
                Button {
                    Task { await vm.fetchNewestAlbums() }
                } label: {
                    Label("加载最新专辑", systemImage: "sparkles")
                }
                .disabled(vm.isLoading)

                ForEach(Array(vm.newestAlbums.enumerated()), id: \.offset) { _, album in
                    let name = album["name"] as? String ?? "未知"
                    let artist = (album["artist"] as? [String: Any])?["name"] as? String
                        ?? (album["artists"] as? [[String: Any]])?.first?["name"] as? String
                        ?? "未知"
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name).font(.subheadline)
                        Text(artist).font(.caption).foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("专辑")
        .overlay { if vm.isLoading { ProgressView() } }
    }
}
