// MoreView.swift
// 更多模块入口页面
// 汇集所有 API 模块的测试入口

import SwiftUI

struct MoreView: View {
    @ObservedObject var vm: DemoViewModel

    var body: some View {
        List {
            Section("音乐") {
                NavigationLink {
                    PlaylistView(vm: vm)
                } label: {
                    Label("歌单", systemImage: "music.note.list")
                }
                NavigationLink {
                    AlbumView(vm: vm)
                } label: {
                    Label("专辑", systemImage: "opticaldisc")
                }
                NavigationLink {
                    ArtistView(vm: vm)
                } label: {
                    Label("歌手", systemImage: "person.fill")
                }
                NavigationLink {
                    MVVideoView(vm: vm)
                } label: {
                    Label("MV / 视频", systemImage: "play.rectangle")
                }
                NavigationLink {
                    DJRadioView(vm: vm)
                } label: {
                    Label("电台", systemImage: "radio")
                }
            }

            Section("社交") {
                NavigationLink {
                    CommentView(vm: vm)
                } label: {
                    Label("评论", systemImage: "bubble.left.and.bubble.right")
                }
                NavigationLink {
                    UserView(vm: vm)
                } label: {
                    Label("用户", systemImage: "person.crop.circle")
                }
            }

            Section("个人") {
                NavigationLink {
                    CloudView(vm: vm)
                } label: {
                    Label("云盘", systemImage: "cloud")
                }
                NavigationLink {
                    VIPView(vm: vm)
                } label: {
                    Label("VIP / 云贝", systemImage: "crown")
                }
            }

            Section("工具") {
                NavigationLink {
                    UnblockView(vm: vm)
                } label: {
                    Label("解灰测试", systemImage: "wand.and.stars")
                }
                NavigationLink {
                    MiscView(vm: vm)
                } label: {
                    Label("更多功能", systemImage: "ellipsis.circle")
                }
            }
        }
        .navigationTitle("全部模块")
    }
}
