// UnblockSourceManageView.swift
// 第三方音源管理界面
// 支持导入 JS 脚本音源、添加自定义 HTTP 音源、排序、启用/禁用

import SwiftUI
import UniformTypeIdentifiers
import NeteaseCloudMusicAPI

struct UnblockSourceManageView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var sourceManager = UnblockSourceManager.shared
    @State private var showAddSheet = false
    @State private var showJSImporter = false
    @State private var showHTTPSheet = false
    @State private var isEditing = false
    @State private var showTestLogSheet = false
    @State private var testLogContent: [String] = []

    var body: some View {
        ZStack {
            AsideBackground()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    headerSection
                        .padding(.top, DeviceLayout.headerTopPadding)

                    tipCard

                    defaultSourceSection

                    if !sourceManager.sources.isEmpty {
                        sourceListSection
                    } else {
                        emptyStateSection
                    }

                    addButtonSection

                    testSection

                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddSourceSheet(
                onImportJS: {
                    showAddSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showJSImporter = true
                    }
                },
                onAddHTTP: {
                    showAddSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showHTTPSheet = true
                    }
                }
            )
            .presentationDetents([.height(260)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showHTTPSheet) {
            AddHTTPSourceSheet { config in
                sourceManager.addSource(config)
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .fileImporter(
            isPresented: $showJSImporter,
            allowedContentTypes: [UTType(filenameExtension: "js") ?? .plainText],
            allowsMultipleSelection: false
        ) { result in
            handleJSImport(result)
        }
        .sheet(isPresented: $showTestLogSheet) {
            TestLogSheet(logs: testLogContent)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - 顶部导航

    private var headerSection: some View {
        HStack {
            Button(action: { dismiss() }) {
                ZStack {
                    Circle()
                        .fill(Color.asideCardBackground)
                        .frame(width: 40, height: 40)
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    AsideIcon(icon: .back, size: 16, color: .asideTextPrimary)
                }
            }
            .buttonStyle(AsideBouncingButtonStyle())

            Spacer()

            Text("音源管理")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.asideTextPrimary)

            Spacer()

            if !sourceManager.sources.isEmpty {
                Button(action: { withAnimation(.spring(response: 0.35)) { isEditing.toggle() } }) {
                    ZStack {
                        Circle()
                            .fill(isEditing ? Color.asideIconBackground : Color.asideCardBackground)
                            .frame(width: 40, height: 40)
                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                        Text(isEditing ? "完成" : "编辑")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(isEditing ? .asideIconForeground : .asideTextPrimary)
                    }
                }
                .buttonStyle(AsideBouncingButtonStyle())
            } else {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 40, height: 40)
            }
        }
    }

    // MARK: - 提示卡片

    private var tipCard: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.asideAccentGreen.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.asideAccentGreen)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("已内置默认音源")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.asideTextPrimary)
                Text("无需添加即可使用，自定义源将优先匹配")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(.asideTextSecondary)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.asideCardBackground)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
    }

    // MARK: - 默认源

    private var defaultSourceSection: some View {
        SettingsSection(title: "默认源") {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(sourceManager.defaultSourcesEnabled ? Color.asideIconBackground : Color.asideSeparator)
                        .frame(width: 32, height: 32)
                    AsideIcon(icon: .cloud, size: 16, color: sourceManager.defaultSourcesEnabled ? .asideIconForeground : .asideTextSecondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("内置默认源")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(sourceManager.defaultSourcesEnabled ? .asideTextPrimary : .asideTextSecondary)
                    Text("后端匹配 · GD 音乐台")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.asideTextSecondary)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { sourceManager.defaultSourcesEnabled },
                    set: { _ in sourceManager.toggleDefaultSources() }
                ))
                .labelsHidden()
                .tint(Color(light: .black, dark: Color(hex: "555555")))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    // MARK: - 音源列表

    private var sourceListSection: some View {
        SettingsSection(title: "自定义音源（\(sourceManager.enabledCount)/\(sourceManager.sources.count)）") {
            VStack(spacing: 0) {
                ForEach(Array(sourceManager.sources.enumerated()), id: \.element.id) { index, source in
                    if index > 0 {
                        Divider().padding(.leading, 56)
                    }
                    sourceRow(source)
                }
            }
        }
    }

    private func sourceRow(_ source: UnblockSourceConfig) -> some View {
        HStack(spacing: 14) {
            // 类型图标
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(source.isEnabled ? Color.asideIconBackground : Color.asideSeparator)
                    .frame(width: 32, height: 32)

                AsideIcon(
                    icon: sourceIconType(source.type),
                    size: 14,
                    color: source.isEnabled ? .asideIconForeground : .asideTextSecondary
                )
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(source.name)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(source.isEnabled ? .asideTextPrimary : .asideTextSecondary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(sourceTypeLabel(source.type))
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.asideTextSecondary)

                    if let status = sourceManager.sourceTestResults[source.name] {
                        sourceStatusBadge(status)
                    }
                }
            }

            Spacer()

            if isEditing {
                Button {
                    withAnimation(.spring(response: 0.35)) {
                        sourceManager.removeSource(id: source.id)
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.12))
                            .frame(width: 30, height: 30)
                        AsideIcon(icon: .trash, size: 13, color: .red)
                    }
                }
                .buttonStyle(AsideBouncingButtonStyle())
            } else {
                // 单独测试按钮
                let isTesting = sourceManager.sourceTestResults[source.name] == .checking
                Button {
                    runSingleTestWithLog(source: source)
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.asideSeparator)
                            .frame(width: 30, height: 30)
                        if isTesting {
                            ProgressView()
                                .scaleEffect(0.5)
                        } else {
                            AsideIcon(icon: .play, size: 12, color: .asideTextSecondary)
                        }
                    }
                }
                .buttonStyle(AsideBouncingButtonStyle())
                .disabled(isTesting)

                Toggle("", isOn: Binding(
                    get: { source.isEnabled },
                    set: { _ in sourceManager.toggleSource(id: source.id) }
                ))
                .labelsHidden()
                .tint(Color(light: .black, dark: Color(hex: "555555")))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contextMenu {
            Button(role: .destructive) {
                withAnimation { sourceManager.removeSource(id: source.id) }
            } label: {
                Label("删除音源", systemImage: "trash")
            }
        }
    }

    /// 音源状态小标签
    @ViewBuilder
    private func sourceStatusBadge(_ status: UnblockSourceManager.SourceTestStatus) -> some View {
        switch status {
        case .available:
            HStack(spacing: 3) {
                Circle().fill(Color.asideAccentGreen).frame(width: 5, height: 5)
                Text("可用")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.asideAccentGreen)
            }
        case .unavailable:
            HStack(spacing: 3) {
                Circle().fill(Color.asideAccentRed).frame(width: 5, height: 5)
                Text("不可用")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.asideAccentRed)
            }
        case .checking:
            ProgressView()
                .scaleEffect(0.45)
                .frame(width: 12, height: 12)
        case .unknown:
            EmptyView()
        }
    }

    // MARK: - 空状态

    private var emptyStateSection: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.asideSeparator)
                    .frame(width: 56, height: 56)
                AsideIcon(icon: .cloud, size: 24, color: .asideTextSecondary.opacity(0.5))
            }

            Text("暂无自定义音源")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.asideTextSecondary)

            Text("添加自定义音源可提高匹配成功率")
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundColor(.asideTextSecondary.opacity(0.7))
        }
        .padding(.vertical, 36)
    }

    // MARK: - 添加按钮

    private var addButtonSection: some View {
        Button {
            showAddSheet = true
        } label: {
            HStack(spacing: 8) {
                AsideIcon(icon: .add, size: 16, color: .asideTextPrimary)
                Text("添加音源")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            }
            .foregroundColor(.asideTextPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.asideCardBackground)
                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
            )
        }
        .buttonStyle(AsideBouncingButtonStyle())
    }

    // MARK: - 测试区域

    private var testSection: some View {
        SettingsSection(title: "音源测试") {
            VStack(spacing: 0) {
                // 汇总状态
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(testSummaryColor.opacity(0.15))
                            .frame(width: 32, height: 32)
                        Image(systemName: testSummaryIcon)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(testSummaryColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("全部音源状态")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(.asideTextPrimary)
                        Text(testSummaryText)
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(.asideTextSecondary)
                    }

                    Spacer()

                    Button {
                        sourceManager.checkAllSources()
                    } label: {
                        if sourceManager.isTesting {
                            ProgressView()
                                .frame(width: 50, height: 30)
                        } else {
                            Text("测试")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.asideIconForeground)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule()
                                        .fill(Color.asideIconBackground)
                                )
                        }
                    }
                    .buttonStyle(AsideBouncingButtonStyle())
                    .disabled(sourceManager.isTesting)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                // 逐个音源状态
                if !sourceManager.sourceTestResults.isEmpty {
                    Divider().padding(.leading, 56)

                    ForEach(Array(sourceManager.sourceTestResults.keys.sorted()), id: \.self) { name in
                        if let status = sourceManager.sourceTestResults[name] {
                            sourceTestRow(name: name, status: status)
                        }
                    }
                }
            }
        }
    }

    private func sourceTestRow(name: String, status: UnblockSourceManager.SourceTestStatus) -> some View {
        Button {
            // 点击任意音源行，触发带详细日志的单源测试
            if let ncmSource = sourceManager.currentUnblockManager.sources.first(where: { $0.name == name }) {
                runDetailedTestWithLog(ncmSource: ncmSource)
            }
        } label: {
            HStack(spacing: 10) {
                Circle()
                    .fill(sourceStatusColor(status))
                    .frame(width: 7, height: 7)

                Text(name)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.asideTextPrimary)
                    .lineLimit(1)

                Spacer()

                Group {
                    switch status {
                    case .checking:
                        ProgressView().scaleEffect(0.6)
                    case .available(let info):
                        Text(info).foregroundColor(.asideAccentGreen)
                    case .unavailable(let msg):
                        Text(msg).foregroundColor(.asideAccentRed)
                    case .unknown:
                        Text("未测试").foregroundColor(.asideTextSecondary)
                    }
                }
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .lineLimit(1)

                AsideIcon(icon: .chevronRight, size: 10, color: .asideTextSecondary.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 辅助方法

    private func sourceIconType(_ type: UnblockSourceConfig.SourceType) -> AsideIcon.IconType {
        switch type {
        case .jsScript: return .musicNote
        case .httpUrl: return .cloud
        }
    }

    private func sourceTypeLabel(_ type: UnblockSourceConfig.SourceType) -> String {
        switch type {
        case .jsScript: return "JS 脚本"
        case .httpUrl(let baseURL, _):
            if let url = URL(string: baseURL), let host = url.host {
                return "HTTP · \(host)"
            }
            return "HTTP 音源"
        }
    }

    private func sourceStatusColor(_ status: UnblockSourceManager.SourceTestStatus) -> Color {
        switch status {
        case .available: return .asideAccentGreen
        case .unavailable: return .asideAccentRed
        case .checking: return .asideOrange
        case .unknown: return .asideTextSecondary
        }
    }

    private var testSummaryIcon: String {
        if sourceManager.isTesting { return "arrow.triangle.2.circlepath" }
        if sourceManager.sourceTestResults.isEmpty { return "questionmark.circle" }
        let available = sourceManager.availableSourceCount
        if available == 0 { return "exclamationmark.triangle.fill" }
        return "checkmark.circle.fill"
    }

    private var testSummaryColor: Color {
        if sourceManager.isTesting { return .asideOrange }
        if sourceManager.sourceTestResults.isEmpty { return .asideTextSecondary }
        let available = sourceManager.availableSourceCount
        if available == 0 { return .asideAccentRed }
        return .asideAccentGreen
    }

    private var testSummaryText: String {
        if sourceManager.isTesting { return "正在测试音源..." }
        if sourceManager.sourceTestResults.isEmpty { return "点击测试检查音源可用性" }
        let available = sourceManager.availableSourceCount
        let total = sourceManager.totalTestedSourceCount
        return "\(available)/\(total) 个音源可用"
    }

    // MARK: - 单源测试（带调试日志）

    private func runSingleTestWithLog(source: UnblockSourceConfig) {
        guard let ncmSource = sourceManager.currentUnblockManager.sources.first(where: { $0.name == source.name }) else { return }
        runDetailedTestWithLog(ncmSource: ncmSource)
    }

    /// 通用详细测试（默认源和自定义源都可用）
    private func runDetailedTestWithLog(ncmSource: NCMUnblockSource) {
        let name = ncmSource.name
        sourceManager.sourceTestResults[name] = .checking

        let testSongs: [(id: Int, title: String, artist: String)] = [
            (186016, "晴天", "周杰伦"),
            (347230, "海阔天空", "Beyond"),
            (25906124, "成都", "赵雷"),
        ]

        // 用于收集 JS 源内部日志
        var jsLogs: [String] = []
        let jsLogLock = NSLock()

        // 如果是 JS 源，设置日志回调捕获内部请求信息
        if let jsSource = ncmSource as? JSScriptSource {
            jsSource.logHandler = { message in
                jsLogLock.lock()
                jsLogs.append(message)
                jsLogLock.unlock()
            }
            jsSource.testMode = true
        }

        Task {
            var logs: [String] = ["🔍 开始测试音源: \(name)"]
            logs.append("📦 类型: \(ncmSource.sourceType.rawValue)")

            // 显示音源的实际请求地址信息
            if let serverSource = ncmSource as? ServerUnblockSource {
                logs.append("🌐 后端地址: \(serverSource.serverUrl)")
                logs.append("📋 模式: \(serverSource.mode.rawValue)")
            } else if let httpSource = ncmSource as? CustomURLSource {
                logs.append("🌐 API 地址: \(httpSource.baseURL)")
                if let tpl = httpSource.urlTemplate {
                    logs.append("📋 URL 模板: \(tpl)")
                }
            } else if let jsSource = ncmSource as? JSScriptSource {
                logs.append("📋 洛雪格式: \(jsSource.isLxFormat ? "是" : "否")")
                if jsSource.isLxFormat {
                    let keys = jsSource.lxSources.keys.sorted().joined(separator: ", ")
                    logs.append("🎵 支持平台: \(keys.isEmpty ? "未知" : keys)")
                }
            }
            logs.append("")

            var anySuccess = false
            var successInfo = ""

            for song in testSongs {
                if let serverSource = ncmSource as? ServerUnblockSource {
                    let base = serverSource.serverUrl.hasSuffix("/") ? String(serverSource.serverUrl.dropLast()) : serverSource.serverUrl
                    let previewUrl: String
                    switch serverSource.mode {
                    case .match: previewUrl = "\(base)/song/url/match?id=\(song.id)"
                    case .ncmget: previewUrl = "\(base)/song/url/ncmget?id=\(song.id)&br=320"
                    case .gdDirect: previewUrl = "\(ServerUnblockSource.gdDefaultURL)?types=url&id=\(song.id)&br=320"
                    }
                    logs.append("▶ 测试曲目: \(song.title) (ID: \(song.id))")
                    logs.append("  🔗 请求: \(previewUrl)")
                } else if let httpSource = ncmSource as? CustomURLSource {
                    let previewUrl: String
                    if let tpl = httpSource.urlTemplate {
                        previewUrl = tpl
                            .replacingOccurrences(of: "{id}", with: "\(song.id)")
                            .replacingOccurrences(of: "{quality}", with: "320")
                            .replacingOccurrences(of: "{br}", with: "320")
                            .replacingOccurrences(of: "{baseURL}", with: httpSource.baseURL)
                    } else {
                        previewUrl = "\(httpSource.baseURL)?types=url&id=\(song.id)&br=320"
                    }
                    logs.append("▶ 测试曲目: \(song.title) (ID: \(song.id))")
                    logs.append("  🔗 请求: \(previewUrl)")
                } else {
                    logs.append("▶ 测试曲目: \(song.title) - \(song.artist) (ID: \(song.id))")
                }

                let start = CFAbsoluteTimeGetCurrent()

                // 清空 JS 内部日志缓冲
                jsLogLock.lock()
                jsLogs.removeAll()
                jsLogLock.unlock()

                do {
                    let result = try await ncmSource.match(
                        id: song.id,
                        title: song.title,
                        artist: song.artist,
                        quality: "320"
                    )
                    let ms = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)

                    // 插入 JS 源捕获的内部日志（请求地址等）
                    jsLogLock.lock()
                    let capturedLogs = jsLogs
                    jsLogs.removeAll()
                    jsLogLock.unlock()
                    for jsLog in capturedLogs {
                        logs.append("  📜 \(jsLog)")
                    }

                    if !result.url.isEmpty {
                        let info = result.platform.isEmpty ? "未知来源" : result.platform
                        logs.append("  ✅ 匹配成功 [\(ms)ms]")
                        logs.append("  📡 来源: \(info)")
                        if !result.quality.isEmpty {
                            logs.append("  🎵 音质: \(result.quality)")
                        }
                        logs.append("  🔗 URL: \(result.url)")
                        if !result.extra.isEmpty {
                            if let proxyUrl = result.extra["proxyUrl"] as? String, !proxyUrl.isEmpty {
                                logs.append("  🔀 代理: \(proxyUrl)")
                            }
                            if let data = result.extra["data"] as? String, !data.isEmpty, data != result.url {
                                logs.append("  📎 原始: \(data)")
                            }
                        }
                        logs.append("")
                        anySuccess = true
                        successInfo = info
                    } else {
                        logs.append("  ❌ 返回空 URL [\(ms)ms]")
                        if !result.extra.isEmpty {
                            if let msg = result.extra["message"] as? String, !msg.isEmpty {
                                logs.append("  💬 消息: \(msg)")
                            }
                            if let code = result.extra["code"] as? Int {
                                logs.append("  📋 状态码: \(code)")
                            }
                        }
                        logs.append("")
                    }
                } catch {
                    let ms = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
                    // 插入 JS 源捕获的内部日志
                    jsLogLock.lock()
                    let capturedLogs = jsLogs
                    jsLogs.removeAll()
                    jsLogLock.unlock()
                    for jsLog in capturedLogs {
                        logs.append("  📜 \(jsLog)")
                    }
                    logs.append("  ❌ 错误 [\(ms)ms]: \(error.localizedDescription)")
                    logs.append("")
                }
            }

            logs.append("─────────────────────")
            if anySuccess {
                logs.append("✅ 结论: 音源可用 (\(successInfo))")
                sourceManager.sourceTestResults[name] = .available(successInfo)
            } else {
                logs.append("❌ 结论: 音源不可用（所有测试曲目均未匹配）")
                sourceManager.sourceTestResults[name] = .unavailable("所有测试曲目均未匹配")
            }

            // 清理 JS 源日志回调和测试模式
            if let jsSource = ncmSource as? JSScriptSource {
                jsSource.logHandler = nil
                jsSource.testMode = false
            }

            testLogContent = logs
            showTestLogSheet = true
        }
    }

    private func handleJSImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let config = try sourceManager.importJSScript(from: url)
                sourceManager.addSource(config)
            } catch {
                print("[UnblockSource] JS 导入失败: \(error)")
            }
        case .failure(let error):
            print("[UnblockSource] 文件选择失败: \(error)")
        }
    }
}

// MARK: - 添加音源类型选择 Sheet

private struct AddSourceSheet: View {
    let onImportJS: () -> Void
    let onAddHTTP: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AsideBackground()
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("选择音源类型")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.asideTextPrimary)
                    .padding(.top, 24)

                VStack(spacing: 10) {
                    sourceTypeButton(
                        icon: .musicNote,
                        title: "导入 JS 脚本",
                        subtitle: "支持洛雪格式和简单函数格式",
                        action: onImportJS
                    )

                    sourceTypeButton(
                        icon: .cloud,
                        title: "自定义 HTTP 音源",
                        subtitle: "填写 API 地址，支持自定义 URL 模板",
                        action: onAddHTTP
                    )
                }
                .padding(.horizontal, 20)

                Spacer()
            }
        }
    }

    private func sourceTypeButton(
        icon: AsideIcon.IconType,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.asideIconBackground)
                        .frame(width: 36, height: 36)
                    AsideIcon(icon: icon, size: 16, color: .asideIconForeground)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.asideTextPrimary)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.asideTextSecondary)
                }

                Spacer()

                AsideIcon(icon: .chevronRight, size: 12, color: .asideTextSecondary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.asideCardBackground)
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
            )
        }
        .buttonStyle(AsideBouncingButtonStyle())
    }
}

// MARK: - 添加 HTTP 音源 Sheet

private struct AddHTTPSourceSheet: View {
    let onAdd: (UnblockSourceConfig) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var baseURL = ""
    @State private var urlTemplate = ""
    @FocusState private var focusedField: Field?

    enum Field { case name, url, template }

    var body: some View {
        ZStack {
            AsideBackground()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // 标题栏
                    HStack {
                        Button("取消") { dismiss() }
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(.asideTextSecondary)

                        Spacer()

                        Text("添加 HTTP 音源")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(.asideTextPrimary)

                        Spacer()

                        Button("添加") {
                            let config = UnblockSourceConfig(
                                name: name.isEmpty ? "自定义音源" : name,
                                type: .httpUrl(
                                    baseURL: baseURL,
                                    urlTemplate: urlTemplate.isEmpty ? nil : urlTemplate
                                )
                            )
                            onAdd(config)
                            dismiss()
                        }
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(baseURL.isEmpty ? .asideTextSecondary : .asideTextPrimary)
                        .disabled(baseURL.isEmpty)
                    }
                    .padding(.top, 20)

                    // 输入区域
                    VStack(spacing: 14) {
                        inputField(
                            label: "音源名称",
                            placeholder: "给音源起个名字",
                            text: $name,
                            field: .name
                        )

                        inputField(
                            label: "API 地址",
                            placeholder: "https://example.com/api",
                            text: $baseURL,
                            field: .url,
                            keyboardType: .URL
                        )

                        inputField(
                            label: "URL 模板（可选）",
                            placeholder: "{baseURL}?id={id}&br={quality}",
                            text: $urlTemplate,
                            field: .template
                        )

                        // 模板说明
                        HStack(spacing: 6) {
                            AsideIcon(icon: .info, size: 12, color: .asideTextSecondary.opacity(0.6))
                            Text("留空使用默认格式，支持 {id} {quality} {br} {baseURL}")
                                .font(.system(size: 11, weight: .regular, design: .rounded))
                                .foregroundColor(.asideTextSecondary.opacity(0.6))
                        }
                        .padding(.horizontal, 4)
                    }

                    Spacer()
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func inputField(
        label: String,
        placeholder: String,
        text: Binding<String>,
        field: Field,
        keyboardType: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.asideTextSecondary)

            TextField(placeholder, text: text)
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundColor(.asideTextPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.asideCardBackground)
                        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 3)
                )
                .focused($focusedField, equals: field)
                .keyboardType(keyboardType)
                .autocapitalization(.none)
                .autocorrectionDisabled()
        }
    }
}

// MARK: - 调试日志 Sheet

private struct TestLogSheet: View {
    let logs: [String]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AsideBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 标题栏
                HStack {
                    Button {
                        UIPasteboard.general.string = logs.joined(separator: "\n")
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 13))
                            Text("复制")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                        }
                        .foregroundColor(.asideTextSecondary)
                    }

                    Spacer()

                    Text("测试日志")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.asideTextPrimary)

                    Spacer()

                    Button("关闭") { dismiss() }
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.asideTextSecondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 12)

                // 日志内容
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(Array(logs.enumerated()), id: \.offset) { _, line in
                            if line.isEmpty {
                                Divider()
                                    .padding(.vertical, 4)
                            } else {
                                Text(line)
                                    .font(.system(size: 12, weight: lineWeight(line), design: .monospaced))
                                    .foregroundColor(lineColor(line))
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func lineWeight(_ line: String) -> Font.Weight {
        if line.hasPrefix("🔍") || line.hasPrefix("✅ 结论") || line.hasPrefix("❌ 结论") {
            return .semibold
        }
        return .regular
    }

    private func lineColor(_ line: String) -> Color {
        if line.contains("✅") { return .asideAccentGreen }
        if line.contains("❌") { return .asideAccentRed }
        if line.hasPrefix("▶") { return .asideOrange }
        if line.contains("📜") { return .asideBlue }
        if line.hasPrefix("  📡") || line.hasPrefix("  🔗") { return .asideTextSecondary }
        return .asideTextPrimary
    }
}
