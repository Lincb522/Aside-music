// DJRadioView.swift
// 电台/播客页面 — 推荐电台、分类浏览、节目列表

import SwiftUI

struct DJRadioView: View {
    @ObservedObject var vm: DemoViewModel

    var body: some View {
        List {
            // MARK: - 推荐电台
            if !vm.djRecommendList.isEmpty {
                Section("推荐电台") {
                    ForEach(Array(vm.djRecommendList.enumerated()), id: \.offset) { _, radio in
                        DJRadioRow(radio: radio) {
                            if let id = radio["id"] as? Int {
                                let name = radio["name"] as? String ?? "电台"
                                Task { await vm.fetchDJPrograms(radioId: id, radioName: name) }
                            }
                        }
                    }
                }
            }

            // MARK: - 热门电台
            if !vm.djHotList.isEmpty {
                Section("热门电台") {
                    ForEach(Array(vm.djHotList.enumerated()), id: \.offset) { _, radio in
                        DJRadioRow(radio: radio) {
                            if let id = radio["id"] as? Int {
                                let name = radio["name"] as? String ?? "电台"
                                Task { await vm.fetchDJPrograms(radioId: id, radioName: name) }
                            }
                        }
                    }
                }
            }

            // MARK: - 电台分类
            if !vm.djCategories.isEmpty {
                Section("电台分类") {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 80), spacing: 8)
                    ], spacing: 8) {
                        ForEach(Array(vm.djCategories.enumerated()), id: \.offset) { _, cat in
                            let name = cat["name"] as? String ?? ""
                            Text(name)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(.tertiarySystemBackground))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            // MARK: - 节目排行
            if !vm.djProgramToplistData.isEmpty {
                Section("节目排行") {
                    ForEach(Array(vm.djProgramToplistData.prefix(20).enumerated()), id: \.offset) { idx, item in
                        let program = item["program"] as? [String: Any] ?? item
                        HStack(spacing: 10) {
                            Text("\(idx + 1)")
                                .font(.caption.bold())
                                .foregroundStyle(idx < 3 ? .red : .secondary)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(program["name"] as? String ?? "未知节目")
                                    .font(.subheadline)
                                    .lineLimit(1)
                                if let dj = program["dj"] as? [String: Any],
                                   let djName = dj["nickname"] as? String {
                                    Text(djName)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("电台")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("刷新", systemImage: "arrow.clockwise") {
                    Task { await vm.loadDJData() }
                }
                .disabled(vm.isLoading)
            }
        }
        .overlay {
            if vm.isLoading && vm.djRecommendList.isEmpty && vm.djHotList.isEmpty {
                ProgressView("加载中...")
            }
        }
        .sheet(isPresented: .init(
            get: { !vm.djProgramList.isEmpty },
            set: { if !$0 { vm.djProgramList = [] } }
        )) {
            NavigationStack {
                DJProgramListView(vm: vm)
            }
        }
        .task { await vm.loadDJData() }
    }
}

/// 电台行
struct DJRadioRow: View {
    let radio: [String: Any]
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                Text(radio["name"] as? String ?? "未知电台")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let desc = radio["rcmdtext"] as? String ?? radio["desc"] as? String, !desc.isEmpty {
                    Text(desc)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    if let subCount = radio["subCount"] as? Int {
                        Label("\(DJRadioView.formatCount(subCount))", systemImage: "person.2")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if let programCount = radio["programCount"] as? Int {
                        Label("\(programCount) 期", systemImage: "mic")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

/// 节目列表页（Sheet）
struct DJProgramListView: View {
    @ObservedObject var vm: DemoViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(Array(vm.djProgramList.enumerated()), id: \.offset) { idx, program in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(idx + 1)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                        Text(program["name"] as? String ?? "未知节目")
                            .font(.subheadline)
                            .lineLimit(1)
                    }

                    HStack(spacing: 8) {
                        if let duration = program["duration"] as? Int {
                            Text(DJRadioView.formatDuration(duration))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if let listenerCount = program["listenerCount"] as? Int {
                            Label("\(DJRadioView.formatCount(listenerCount))", systemImage: "headphones")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(vm.selectedRadioName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("关闭") { dismiss() }
            }
        }
    }
}

// MARK: - 辅助方法

extension DJRadioView {
    static func formatCount(_ count: Int) -> String {
        if count >= 100_000_000 { return "\(count / 100_000_000)亿" }
        if count >= 10_000 { return "\(count / 10_000)万" }
        return "\(count)"
    }

    static func formatDuration(_ ms: Int) -> String {
        let totalSeconds = ms / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
