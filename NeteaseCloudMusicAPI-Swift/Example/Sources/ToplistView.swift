// ToplistView.swift
// 排行榜页面（iOS 风格）

import SwiftUI

struct ToplistView: View {
    @ObservedObject var vm: DemoViewModel

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 12)
            ], spacing: 12) {
                ForEach(Array(vm.toplists.enumerated()), id: \.offset) { _, item in
                    ToplistCard(item: item)
                }
            }
            .padding()
        }
        .navigationTitle("排行榜")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("刷新", systemImage: "arrow.clockwise") {
                    Task { await vm.fetchToplists() }
                }
                .disabled(vm.isLoading)
            }
        }
        .overlay {
            if vm.isLoading && vm.toplists.isEmpty {
                ProgressView("加载中...")
            }
        }
        .task { await vm.fetchToplists() }
    }
}

/// 排行榜卡片
struct ToplistCard: View {
    let item: [String: Any]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item["name"] as? String ?? "未知榜单")
                .font(.subheadline.bold())
                .lineLimit(1)

            Text(item["description"] as? String ?? "")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack {
                if let playCount = item["playCount"] as? Int {
                    Text(formatCount(playCount))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if let trackCount = item["trackCount"] as? Int {
                    Text("· \(trackCount) 首")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Text(item["updateFrequency"] as? String ?? "")
                .font(.caption2)
                .foregroundStyle(.blue)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 100_000_000 { return "\(count / 100_000_000)亿" }
        if count >= 10_000 { return "\(count / 10_000)万" }
        return "\(count)"
    }
}
