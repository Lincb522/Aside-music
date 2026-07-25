// RecommendView.swift
// 推荐模块测试页面

import SwiftUI

struct RecommendView: View {
    @ObservedObject var vm: DemoViewModel

    var body: some View {
        List {
            // 个性化推荐歌单
            Section("推荐歌单") {
                Button {
                    Task { await vm.fetchPersonalized() }
                } label: {
                    Label("加载推荐歌单", systemImage: "star.fill")
                }
                .disabled(vm.isLoading)

                ForEach(Array(vm.personalizedPlaylists.enumerated()), id: \.offset) { _, pl in
                    let name = pl["name"] as? String ?? "未知"
                    let playCount = pl["playCount"] as? Int ?? pl["playcount"] as? Int ?? 0
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name).font(.subheadline)
                        Text("▶ \(playCount)").font(.caption).foregroundColor(.secondary)
                    }
                }
            }

            // 推荐新歌
            Section("推荐新歌") {
                Button {
                    Task { await vm.fetchPersonalizedNewsong() }
                } label: {
                    Label("加载推荐新歌", systemImage: "music.note")
                }
                .disabled(vm.isLoading)

                ForEach(Array(vm.personalizedSongs.enumerated()), id: \.offset) { _, item in
                    let song = item["song"] as? [String: Any] ?? item
                    let name = song["name"] as? String ?? "未知"
                    let artist = DemoViewModel.artistNames(from: song)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name).font(.subheadline)
                        Text(artist).font(.caption).foregroundColor(.secondary)
                    }
                }
            }

            // 每日推荐（需登录）
            Section("每日推荐（需登录）") {
                Button {
                    Task { await vm.fetchDailyRecommendSongs() }
                } label: {
                    Label("每日推荐歌曲", systemImage: "calendar")
                }
                .disabled(vm.isLoading)

                Button {
                    Task { await vm.fetchDailyRecommendResource() }
                } label: {
                    Label("每日推荐歌单", systemImage: "rectangle.stack")
                }
                .disabled(vm.isLoading)

                ForEach(Array(vm.dailyRecommendSongs.prefix(20).enumerated()), id: \.offset) { i, song in
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

            // 私人 FM
            Section("私人 FM（需登录）") {
                Button {
                    Task { await vm.fetchPersonalFm() }
                } label: {
                    Label("获取私人 FM", systemImage: "radio")
                }
                .disabled(vm.isLoading)

                ForEach(Array(vm.personalFmSongs.enumerated()), id: \.offset) { _, song in
                    let name = song["name"] as? String ?? "未知"
                    let artist = DemoViewModel.artistNames(from: song)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name).font(.subheadline)
                        Text(artist).font(.caption).foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("推荐")
        .overlay { if vm.isLoading { ProgressView() } }
    }
}
