// MiscView.swift
// 杂项功能测试页面
// 曲风、动态、首页、签到、相似推荐等

import SwiftUI

struct MiscView: View {
    @ObservedObject var vm: DemoViewModel

    var body: some View {
        List {
            // 曲风
            Section("曲风") {
                Button {
                    Task { await vm.fetchStyleList() }
                } label: {
                    Label("获取曲风列表", systemImage: "waveform")
                }
                .disabled(vm.isLoading)

                ForEach(Array(vm.styleListData.prefix(20).enumerated()), id: \.offset) { _, style in
                    let name = style["tagName"] as? String ?? style["name"] as? String ?? "未知"
                    Text(name).font(.subheadline)
                }
            }

            // 首页
            Section("首页") {
                Button {
                    Task { await vm.fetchHomepage() }
                } label: {
                    Label("首页 Block Page", systemImage: "house")
                }
                .disabled(vm.isLoading)

                Button {
                    Task { await vm.fetchDragonBall() }
                } label: {
                    Label("首页入口图标", systemImage: "circle.grid.3x3")
                }
                .disabled(vm.isLoading)

                if !vm.homepageInfo.isEmpty {
                    Text(vm.homepageInfo)
                        .font(.caption).foregroundColor(.secondary)
                }
            }

            // 签到
            Section("签到（需登录）") {
                Button {
                    Task { await vm.fetchSigninProgress() }
                } label: {
                    Label("获取签到进度", systemImage: "checkmark.seal")
                }
                .disabled(vm.isLoading)

                if !vm.signinInfo.isEmpty {
                    Text(vm.signinInfo)
                        .font(.caption).foregroundColor(.secondary)
                }
            }

            // 国家编码
            Section("其他") {
                Button {
                    Task { await vm.fetchCountriesCode() }
                } label: {
                    Label("国家编码列表", systemImage: "globe")
                }
                .disabled(vm.isLoading)

                if vm.countriesCodeCount > 0 {
                    Text("共 \(vm.countriesCodeCount) 个国家/地区")
                        .font(.caption).foregroundColor(.secondary)
                }

                Button {
                    Task { await vm.fetchRecentListenList() }
                } label: {
                    Label("最近听歌列表", systemImage: "clock.arrow.circlepath")
                }
                .disabled(vm.isLoading)

                if !vm.recentListenInfo.isEmpty {
                    Text(vm.recentListenInfo)
                        .font(.caption).foregroundColor(.secondary)
                }
            }

            // 相似推荐
            Section("相似推荐") {
                HStack {
                    TextField("歌曲 ID", text: $vm.simiSongIdInput)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                }

                Button {
                    Task { await vm.fetchSimiSong() }
                } label: {
                    Label("相似歌曲", systemImage: "music.note.list")
                }
                .disabled(vm.isLoading || vm.simiSongIdInput.isEmpty)

                Button {
                    Task { await vm.fetchSimiPlaylist() }
                } label: {
                    Label("相似歌单", systemImage: "rectangle.stack")
                }
                .disabled(vm.isLoading || vm.simiSongIdInput.isEmpty)

                ForEach(Array(vm.simiResults.prefix(10).enumerated()), id: \.offset) { _, item in
                    let name = item["name"] as? String ?? "未知"
                    Text(name).font(.subheadline)
                }
            }
        }
        .navigationTitle("更多功能")
        .overlay { if vm.isLoading { ProgressView() } }
    }
}
