// UserView.swift
// 用户模块测试页面

import SwiftUI

struct UserView: View {
    @ObservedObject var vm: DemoViewModel

    var body: some View {
        List {
            // 用户查询
            Section("用户查询") {
                HStack {
                    TextField("用户 ID", text: $vm.userIdInput)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                    Button {
                        Task { await vm.fetchUserInfo() }
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .disabled(vm.isLoading)
                }

                if !vm.userInfoName.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(vm.userInfoName).font(.headline)
                        if !vm.userInfoSignature.isEmpty {
                            Text(vm.userInfoSignature)
                                .font(.caption).foregroundColor(.secondary)
                        }
                        HStack(spacing: 16) {
                            Label("\(vm.userInfoFollows)", systemImage: "person.badge.plus")
                            Label("\(vm.userInfoFolloweds)", systemImage: "person.2")
                            Label("Lv.\(vm.userInfoLevel)", systemImage: "star")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
            }

            // 用户歌单
            if !vm.userPlaylists.isEmpty {
                Section("歌单 (\(vm.userPlaylists.count))") {
                    ForEach(Array(vm.userPlaylists.prefix(15).enumerated()), id: \.offset) { _, pl in
                        let name = pl["name"] as? String ?? "未知"
                        let count = pl["trackCount"] as? Int ?? 0
                        let playCount = pl["playCount"] as? Int ?? 0
                        VStack(alignment: .leading, spacing: 2) {
                            Text(name).font(.subheadline)
                            HStack {
                                Text("\(count) 首")
                                Spacer()
                                Text("▶ \(playCount)")
                            }
                            .font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
            }

            // 当前账号信息
            Section("当前账号") {
                Button {
                    Task { await vm.fetchCurrentAccount() }
                } label: {
                    Label("获取账号信息", systemImage: "person.crop.circle")
                }
                .disabled(vm.isLoading)

                Button {
                    Task { await vm.fetchUserLevel() }
                } label: {
                    Label("获取等级信息", systemImage: "chart.bar.fill")
                }
                .disabled(vm.isLoading)

                Button {
                    Task { await vm.fetchUserSubcount() }
                } label: {
                    Label("获取订阅数量", systemImage: "number")
                }
                .disabled(vm.isLoading)

                if !vm.accountInfoText.isEmpty {
                    Text(vm.accountInfoText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // 听歌记录
            Section("听歌记录") {
                Button {
                    Task { await vm.fetchUserRecord() }
                } label: {
                    Label("获取听歌排行", systemImage: "music.note.list")
                }
                .disabled(vm.isLoading || vm.userIdInput.isEmpty)

                ForEach(Array(vm.userRecordSongs.prefix(20).enumerated()), id: \.offset) { i, item in
                    let song = item["song"] as? [String: Any] ?? [:]
                    let name = song["name"] as? String ?? "未知"
                    let artist = DemoViewModel.artistNames(from: song)
                    let playCount = item["playCount"] as? Int ?? 0
                    HStack {
                        Text("\(i + 1)").font(.caption).foregroundColor(.secondary)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(name).font(.subheadline)
                            Text(artist).font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("×\(playCount)").font(.caption).foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("用户")
        .overlay { if vm.isLoading { ProgressView() } }
    }
}
