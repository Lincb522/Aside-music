// CloudView.swift
// 云盘模块测试页面

import SwiftUI

struct CloudView: View {
    @ObservedObject var vm: DemoViewModel

    var body: some View {
        List {
            // 云盘歌曲列表
            Section("云盘歌曲（需登录）") {
                Button {
                    Task { await vm.fetchUserCloud() }
                } label: {
                    Label("加载云盘歌曲", systemImage: "cloud")
                }
                .disabled(vm.isLoading)

                if vm.cloudSongCount > 0 {
                    Text("共 \(vm.cloudSongCount) 首")
                        .font(.caption).foregroundColor(.secondary)
                }

                ForEach(Array(vm.cloudSongs.enumerated()), id: \.offset) { _, item in
                    let simpleSong = item["simpleSong"] as? [String: Any] ?? [:]
                    let name = simpleSong["name"] as? String
                        ?? item["songName"] as? String ?? "未知"
                    let artist = item["artist"] as? String
                        ?? DemoViewModel.artistNames(from: simpleSong)
                    let fileSize = item["fileSize"] as? Int ?? 0
                    let sizeMB = String(format: "%.1f MB", Double(fileSize) / 1024.0 / 1024.0)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(name).font(.subheadline)
                        HStack {
                            Text(artist)
                            Spacer()
                            Text(sizeMB)
                        }
                        .font(.caption).foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("云盘")
        .overlay { if vm.isLoading { ProgressView() } }
    }
}
