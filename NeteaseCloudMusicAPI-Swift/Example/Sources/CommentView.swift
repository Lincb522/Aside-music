// CommentView.swift
// 评论模块测试页面

import SwiftUI

struct CommentView: View {
    @ObservedObject var vm: DemoViewModel

    var body: some View {
        List {
            // 输入
            Section("查询评论") {
                HStack {
                    TextField("资源 ID", text: $vm.commentResourceId)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                }
                Picker("资源类型", selection: $vm.commentTypeIndex) {
                    Text("歌曲").tag(0)
                    Text("MV").tag(1)
                    Text("歌单").tag(2)
                    Text("专辑").tag(3)
                }
                .pickerStyle(.segmented)

                HStack {
                    Button {
                        Task { await vm.fetchComments() }
                    } label: {
                        Label("最新评论", systemImage: "bubble.left.and.bubble.right")
                    }
                    Spacer()
                    Button {
                        Task { await vm.fetchHotComments() }
                    } label: {
                        Label("热门评论", systemImage: "flame")
                    }
                }
                .disabled(vm.isLoading)
            }

            // 评论总数
            if vm.commentTotal > 0 {
                Section {
                    Text("共 \(vm.commentTotal) 条评论")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // 评论列表
            if !vm.commentList.isEmpty {
                Section(vm.isHotComments ? "热门评论" : "最新评论") {
                    ForEach(Array(vm.commentList.enumerated()), id: \.offset) { _, c in
                        let user = (c["user"] as? [String: Any])?["nickname"] as? String ?? "匿名"
                        let content = c["content"] as? String ?? ""
                        let likeCount = c["likedCount"] as? Int ?? 0
                        let time = c["time"] as? Int ?? 0
                        let timeStr = DemoViewModel.formatTimestamp(time)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(user).font(.subheadline).fontWeight(.medium)
                                Spacer()
                                Label("\(likeCount)", systemImage: "heart")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Text(content).font(.subheadline)
                            Text(timeStr).font(.caption2).foregroundColor(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle("评论")
        .overlay { if vm.isLoading { ProgressView() } }
    }
}
