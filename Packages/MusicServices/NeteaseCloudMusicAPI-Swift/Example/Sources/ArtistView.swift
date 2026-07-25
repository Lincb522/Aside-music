// ArtistView.swift
// 歌手模块测试页面

import SwiftUI

struct ArtistView: View {
    @ObservedObject var vm: DemoViewModel

    var body: some View {
        List {
            // 歌手搜索/查看
            Section("歌手查询") {
                HStack {
                    TextField("歌手 ID", text: $vm.artistIdInput)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                    Button {
                        Task { await vm.fetchArtistInfo() }
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .disabled(vm.isLoading)
                }

                if !vm.artistName.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(vm.artistName).font(.headline)
                        if !vm.artistAlias.isEmpty {
                            Text(vm.artistAlias).font(.caption).foregroundColor(.secondary)
                        }
                        if vm.artistFansCount > 0 {
                            Text("粉丝: \(vm.artistFansCount)").font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
            }

            // 热门歌曲
            if !vm.artistTopSongs.isEmpty {
                Section("热门歌曲 (Top \(vm.artistTopSongs.count))") {
                    ForEach(Array(vm.artistTopSongs.prefix(20).enumerated()), id: \.offset) { i, song in
                        let name = song["name"] as? String ?? "未知"
                        let album = DemoViewModel.albumName(from: song)
                        HStack {
                            Text("\(i + 1)").font(.caption).foregroundColor(.secondary)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(name).font(.subheadline)
                                if !album.isEmpty {
                                    Text(album).font(.caption).foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }

            // 歌手专辑
            if !vm.artistAlbums.isEmpty {
                Section("专辑 (\(vm.artistAlbums.count))") {
                    ForEach(Array(vm.artistAlbums.prefix(10).enumerated()), id: \.offset) { _, album in
                        let name = album["name"] as? String ?? "未知"
                        let size = album["size"] as? Int ?? 0
                        HStack {
                            Image(systemName: "opticaldisc")
                                .foregroundColor(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(name).font(.subheadline)
                                Text("\(size) 首").font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }

            // 相似歌手
            if !vm.simiArtists.isEmpty {
                Section("相似歌手") {
                    ForEach(Array(vm.simiArtists.prefix(10).enumerated()), id: \.offset) { _, a in
                        let name = a["name"] as? String ?? "未知"
                        Text(name).font(.subheadline)
                    }
                }
            }

            // 歌手列表
            Section("歌手列表（华语男歌手）") {
                Button {
                    Task { await vm.fetchArtistList() }
                } label: {
                    Label("加载歌手列表", systemImage: "person.3")
                }
                .disabled(vm.isLoading)

                ForEach(Array(vm.artistListData.enumerated()), id: \.offset) { _, a in
                    let name = a["name"] as? String ?? "未知"
                    let fansSize = a["fansSize"] as? Int
                    HStack {
                        Text(name).font(.subheadline)
                        Spacer()
                        if let fans = fansSize {
                            Text("\(fans) 粉丝").font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("歌手")
        .overlay { if vm.isLoading { ProgressView() } }
    }
}
