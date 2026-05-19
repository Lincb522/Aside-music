// MVVideoView.swift
// MV 和视频模块测试页面

import SwiftUI

struct MVVideoView: View {
    @ObservedObject var vm: DemoViewModel

    var body: some View {
        List {
            // MV 列表
            Section("全部 MV") {
                Button {
                    Task { await vm.fetchMvAll() }
                } label: {
                    Label("加载 MV 列表", systemImage: "play.rectangle")
                }
                .disabled(vm.isLoading)

                ForEach(Array(vm.mvList.enumerated()), id: \.offset) { _, mv in
                    let name = mv["name"] as? String ?? "未知"
                    let artist = (mv["artists"] as? [[String: Any]])?.first?["name"] as? String
                        ?? mv["artistName"] as? String ?? "未知"
                    let id = mv["id"] as? Int ?? 0
                    let playCount = mv["playCount"] as? Int ?? 0

                    Button {
                        Task { await vm.fetchMvDetail(id: id) }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(name).font(.subheadline)
                            HStack {
                                Text(artist)
                                Spacer()
                                Text("▶ \(playCount)")
                            }
                            .font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
            }

            // MV 详情
            if !vm.mvDetailName.isEmpty {
                Section("MV 详情") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(vm.mvDetailName).font(.headline)
                        Text(vm.mvDetailArtist).font(.subheadline).foregroundColor(.secondary)
                        if !vm.mvDetailUrl.isEmpty {
                            Text(vm.mvDetailUrl)
                                .font(.caption2)
                                .foregroundColor(.blue)
                                .lineLimit(2)
                        }
                        HStack {
                            Label("\(vm.mvDetailPlayCount)", systemImage: "play.fill")
                            Label("\(vm.mvDetailCommentCount)", systemImage: "bubble.right")
                            Label("\(vm.mvDetailLikeCount)", systemImage: "heart")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
            }

            // 最新 MV
            Section("最新 MV") {
                Button {
                    Task { await vm.fetchMvFirst() }
                } label: {
                    Label("加载最新 MV", systemImage: "sparkles.tv")
                }
                .disabled(vm.isLoading)

                ForEach(Array(vm.mvFirstList.enumerated()), id: \.offset) { _, mv in
                    let name = mv["name"] as? String ?? "未知"
                    let artist = (mv["artists"] as? [[String: Any]])?.first?["name"] as? String ?? "未知"
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name).font(.subheadline)
                        Text(artist).font(.caption).foregroundColor(.secondary)
                    }
                }
            }

            // 网易出品
            Section("网易出品 MV") {
                Button {
                    Task { await vm.fetchMvExclusive() }
                } label: {
                    Label("加载网易出品", systemImage: "star.circle")
                }
                .disabled(vm.isLoading)

                ForEach(Array(vm.mvExclusiveList.enumerated()), id: \.offset) { _, mv in
                    let name = mv["name"] as? String ?? "未知"
                    Text(name).font(.subheadline)
                }
            }
        }
        .navigationTitle("MV / 视频")
        .overlay { if vm.isLoading { ProgressView() } }
    }
}
