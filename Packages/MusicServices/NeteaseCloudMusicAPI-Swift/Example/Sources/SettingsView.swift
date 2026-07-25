// SettingsView.swift
// 连接设置页面 — 服务配置、二维码登录、播放测试

import SwiftUI
import AVFoundation

struct SettingsView: View {
    @ObservedObject var vm: DemoViewModel

    var body: some View {
        Form {
            // MARK: - 服务配置
            Section("服务配置") {
                TextField("后端地址（留空则直连）", text: $vm.serverUrl)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                Text(vm.serverUrl.isEmpty ? "当前: 直连ncm（客户端加密）" : "当前: 后端代理")
                    .font(.caption)
                    .foregroundStyle(vm.serverUrl.isEmpty ? .orange : .green)

                Button {
                    Task { await vm.testConnection() }
                } label: {
                    HStack {
                        Text("测试连接")
                        if vm.isLoading {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(vm.isLoading)

                Text(vm.connectionStatus)
                    .font(.callout)
            }

            // MARK: - 二维码登录
            Section("二维码登录") {
                if vm.isLoggedIn {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("已登录: \(vm.loginNickname)")
                    }
                    Button("退出登录", role: .destructive) {
                        Task { await vm.doLogout() }
                    }
                } else {
                    Button {
                        Task { await vm.startQrLogin() }
                    } label: {
                        HStack {
                            Text("生成登录二维码")
                            if vm.qrPolling {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(vm.qrPolling)

                    if let qrImage = vm.qrImage {
                        HStack {
                            Spacer()
                            Image(uiImage: qrImage)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 200, height: 200)
                            Spacer()
                        }
                        Text(vm.qrStatusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // MARK: - Cookie
            Section("Cookie") {
                if vm.currentCookies.isEmpty {
                    Text("暂无 Cookie（登录后自动获取）")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(vm.currentCookies)
                        .font(.system(.caption2, design: .monospaced))
                        .lineLimit(5)
                        .textSelection(.enabled)
                }

                TextField("手动输入 Cookie", text: $vm.cookie)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                Button("应用 Cookie") {
                    vm.applyCookie()
                }
            }

            // MARK: - 播放测试
            Section("播放测试") {
                TextField("歌曲 ID", text: $vm.testSongId)
                    .keyboardType(.numberPad)

                Button {
                    Task { await vm.testPlaySong() }
                } label: {
                    HStack {
                        Text("获取并播放")
                        if vm.isPlayLoading {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(vm.testSongId.isEmpty || vm.isPlayLoading)

                if !vm.playSongName.isEmpty {
                    Text("🎵 \(vm.playSongName)")
                        .font(.callout)
                }

                if !vm.playUrl.isEmpty {
                    Text(vm.playUrl)
                        .font(.system(.caption2, design: .monospaced))
                        .lineLimit(2)
                        .textSelection(.enabled)
                }

                if vm.isPlaying {
                    Button("停止播放") {
                        vm.stopPlaying()
                    }
                    .foregroundStyle(.red)
                }

                if !vm.playStatus.isEmpty {
                    Text(vm.playStatus)
                        .font(.caption)
                        .foregroundStyle(vm.playStatus.contains("失败") ? .red : .green)
                }
            }

            // MARK: - 错误信息
            if let error = vm.errorMessage {
                Section("错误") {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("设置")
    }
}
