// VIPView.swift
// VIP 和云贝模块测试页面

import SwiftUI

struct VIPView: View {
    @ObservedObject var vm: DemoViewModel

    var body: some View {
        List {
            // VIP 信息
            Section("VIP 信息（需登录）") {
                Button {
                    Task { await vm.fetchVipInfo() }
                } label: {
                    Label("获取 VIP 信息", systemImage: "crown")
                }
                .disabled(vm.isLoading)

                if !vm.vipInfoText.isEmpty {
                    ForEach(vm.vipInfoText.components(separatedBy: "\n"), id: \.self) { line in
                        Text(line)
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
            }

            // VIP 成长值
            Section("VIP 成长值") {
                Button {
                    Task { await vm.fetchVipGrowthpoint() }
                } label: {
                    Label("获取成长值", systemImage: "chart.line.uptrend.xyaxis")
                }
                .disabled(vm.isLoading)

                if !vm.vipGrowthText.isEmpty {
                    Text(vm.vipGrowthText)
                        .font(.caption).foregroundColor(.secondary)
                }
            }

            // VIP 任务
            Section("VIP 任务") {
                Button {
                    Task { await vm.fetchVipTasks() }
                } label: {
                    Label("获取任务列表", systemImage: "checklist")
                }
                .disabled(vm.isLoading)

                ForEach(Array(vm.vipTaskList.enumerated()), id: \.offset) { _, task in
                    let name = task["taskName"] as? String
                        ?? task["name"] as? String
                        ?? task["action"] as? String
                        ?? "未知"
                    let desc = task["taskDesc"] as? String
                        ?? task["description"] as? String
                        ?? ""
                    let status = task["status"] as? Int
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(name).font(.subheadline)
                            Spacer()
                            if let s = status {
                                Text(s == 0 ? "未完成" : "已完成")
                                    .font(.caption2)
                                    .foregroundColor(s == 0 ? .orange : .green)
                            }
                        }
                        if !desc.isEmpty {
                            Text(desc).font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
            }

            // 云贝
            Section("云贝") {
                Button {
                    Task { await vm.fetchYunbeiInfo() }
                } label: {
                    Label("获取云贝信息", systemImage: "bitcoinsign.circle")
                }
                .disabled(vm.isLoading)

                if !vm.yunbeiInfoText.isEmpty {
                    Text(vm.yunbeiInfoText)
                        .font(.caption).foregroundColor(.secondary)
                }

                Button {
                    Task { await vm.fetchYunbeiTasks() }
                } label: {
                    Label("获取云贝任务", systemImage: "list.bullet")
                }
                .disabled(vm.isLoading)

                ForEach(Array(vm.yunbeiTaskList.enumerated()), id: \.offset) { _, task in
                    let name = task["taskName"] as? String ?? task["name"] as? String ?? "未知"
                    let desc = task["taskDesc"] as? String ?? ""
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name).font(.subheadline)
                        if !desc.isEmpty {
                            Text(desc).font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("VIP / 云贝")
        .overlay { if vm.isLoading { ProgressView() } }
    }
}
