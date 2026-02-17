//
//  DebugLogView.swift
//  AsideMusic
//
//  调试日志查看器 - 用于真机测试
//  使用统一的 AsideIcon 图标系统
//

import SwiftUI

struct DebugLogView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var logs: [LogEntry] = []
    @State private var filterLevel: LogEntry.LogLevel? = nil
    @State private var searchText = ""
    @State private var autoScroll = true
    @State private var showShareSheet = false
    
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
    var filteredLogs: [LogEntry] {
        var result = logs
        
        // 按级别过滤
        if let level = filterLevel {
            result = result.filter { $0.level == level }
        }
        
        // 按搜索文本过滤
        if !searchText.isEmpty {
            result = result.filter { log in
                log.message.localizedCaseInsensitiveContains(searchText) ||
                log.fileName.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return result
    }
    
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                AsideBackground()
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 顶部导航栏
                    navigationBar
                        .padding(.top, DeviceLayout.headerTopPadding)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                    
                    // 统计信息卡片
                    statsCard
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                    
                    // 搜索框
                    searchBar
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                    
                    // 过滤器标签
                    filterTags
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                    
                    // 日志列表
                    logsList
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                loadLogs()
            }
            .onReceive(timer) { _ in
                loadLogs()
            }
            .sheet(isPresented: $showShareSheet) {
                DebugLogShareSheet(items: [exportLogsAsText()])
            }
        }
    }
    
    // MARK: - 导航栏
    
    private var navigationBar: some View {
        HStack(spacing: 16) {
            // 返回按钮
            Button(action: { dismiss() }) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle()
                                .fill(Color.asideGlassOverlay)
                        )
                        .frame(width: 40, height: 40)
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                    
                    AsideIcon(icon: .back, size: 16, color: .asideTextPrimary)
                }
            }
            .buttonStyle(AsideBouncingButtonStyle())
            
            Spacer()
            
            // 标题
            VStack(spacing: 2) {
                Text("调试日志")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.asideTextPrimary)
                
                Text("\(filteredLogs.count) 条日志")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.asideTextSecondary)
            }
            
            Spacer()
            
            // 菜单按钮
            Menu {
                Button(action: { showShareSheet = true }) {
                    HStack {
                        AsideIcon(icon: .share, size: 14, color: .asideTextPrimary)
                        Text("导出日志")
                    }
                }
                
                Button(action: clearLogs) {
                    HStack {
                        AsideIcon(icon: .trash, size: 14, color: .asideTextPrimary)
                        Text("清空日志")
                    }
                }
                
                Toggle(isOn: $autoScroll) {
                    HStack {
                        AsideIcon(icon: .arrowDownToLine, size: 14, color: .asideTextPrimary)
                        Text("自动滚动")
                    }
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle()
                                .fill(Color.asideGlassOverlay)
                        )
                        .frame(width: 40, height: 40)
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                    
                    AsideIcon(icon: .more, size: 16, color: .asideTextPrimary)
                }
            }
        }
    }
    
    // MARK: - 统计卡片
    
    private var statsCard: some View {
        HStack(spacing: 16) {
            StatItem(
                title: "总计",
                value: "\(logs.count)",
                color: .asideAccent
            )
            
            StatItem(
                title: "错误",
                value: "\(logs.filter { $0.level == .error }.count)",
                color: .red
            )
            
            StatItem(
                title: "警告",
                value: "\(logs.filter { $0.level == .warning }.count)",
                color: .orange
            )
            
            StatItem(
                title: "成功",
                value: "\(logs.filter { $0.level == .success }.count)",
                color: .green
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.asideGlassOverlay)
                )
                .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 6)
        )
    }
    
    // MARK: - 搜索框
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            AsideIcon(icon: .magnifyingGlass, size: 16, color: .asideTextSecondary)
            
            TextField("搜索日志...", text: $searchText)
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(.asideTextPrimary)
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    AsideIcon(icon: .xmark, size: 14, color: .asideTextSecondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.asideGlassOverlay)
                )
        )
    }
    
    // MARK: - 过滤标签
    
    private var filterTags: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    title: "全部",
                    icon: nil,
                    isSelected: filterLevel == nil,
                    action: { filterLevel = nil }
                )
                
                ForEach([LogEntry.LogLevel.info, .debug, .warning, .error, .network, .success], id: \.self) { level in
                    FilterChip(
                        title: levelName(level),
                        icon: levelIcon(level),
                        isSelected: filterLevel == level,
                        color: levelColor(level),
                        action: { filterLevel = level }
                    )
                }
            }
        }
    }
    
    // MARK: - 日志列表
    
    private var logsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(filteredLogs) { log in
                        LogRowView(log: log)
                            .id(log.id)
                    }
                }
                .padding(20)
            }
            .onChange(of: logs.count) { _, _ in
                if autoScroll, let lastLog = filteredLogs.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(lastLog.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    // MARK: - 辅助方法
    
    private func loadLogs() {
        logs = AppLogger.getAllLogs()
    }
    
    private func clearLogs() {
        AppLogger.clearLogs()
        loadLogs()
    }
    
    private func levelName(_ level: LogEntry.LogLevel) -> String {
        switch level {
        case .info: return "信息"
        case .debug: return "调试"
        case .warning: return "警告"
        case .error: return "错误"
        case .network: return "网络"
        case .success: return "成功"
        }
    }
    
    private func levelColor(_ level: LogEntry.LogLevel) -> Color {
        switch level {
        case .info: return .blue
        case .debug: return .purple
        case .warning: return .orange
        case .error: return .red
        case .network: return .cyan
        case .success: return .green
        }
    }
    
    private func levelIcon(_ level: LogEntry.LogLevel) -> AsideIcon.IconType {
        switch level {
        case .info: return .logInfo
        case .debug: return .logDebug
        case .warning: return .warning
        case .error: return .logError
        case .network: return .logNetwork
        case .success: return .logSuccess
        }
    }
    
    private func exportLogsAsText() -> String {
        var text = "AsideMusic 调试日志\n"
        text += "导出时间: \(Date())\n"
        text += "日志数量: \(filteredLogs.count)\n"
        text += String(repeating: "=", count: 50) + "\n\n"
        
        for log in filteredLogs {
            text += "[\(log.formattedTime)] \(log.level.rawValue) "
            if !log.fileName.isEmpty {
                text += "[\(log.fileName):\(log.line)] "
            }
            text += "\(log.message)\n"
        }
        
        return text
    }
}

// MARK: - 统计项组件

struct StatItem: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(color)
            
            Text(title)
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(.asideTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 日志行视图

struct LogRowView: View {
    let log: LogEntry
    @State private var isExpanded = false
    
    private var levelColor: Color {
        switch log.level {
        case .info: return .blue
        case .debug: return .purple
        case .warning: return .orange
        case .error: return .red
        case .network: return .cyan
        case .success: return .green
        }
    }
    
    private var levelName: String {
        switch log.level {
        case .info: return "信息"
        case .debug: return "调试"
        case .warning: return "警告"
        case .error: return "错误"
        case .network: return "网络"
        case .success: return "成功"
        }
    }
    
    private var levelIcon: AsideIcon.IconType {
        switch log.level {
        case .info: return .logInfo
        case .debug: return .logDebug
        case .warning: return .warning
        case .error: return .logError
        case .network: return .logNetwork
        case .success: return .logSuccess
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                // 级别指示器
                Circle()
                    .fill(levelColor)
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)
                
                // 内容
                VStack(alignment: .leading, spacing: 6) {
                    // 时间和文件信息
                    HStack(spacing: 8) {
                        Text(log.formattedTime)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.asideTextSecondary)
                        
                        if !log.fileName.isEmpty {
                            Text("•")
                                .foregroundColor(.asideTextSecondary.opacity(0.5))
                            
                            Text("\(log.fileName):\(log.line)")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(.asideTextSecondary)
                        }
                        
                        Spacer()
                        
                        // 级别标签 - 使用图标 + 文本
                        HStack(spacing: 4) {
                            AsideIcon(icon: levelIcon, size: 10, color: levelColor)
                            Text(levelName)
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundColor(levelColor)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(levelColor.opacity(0.15))
                        )
                    }
                    
                    // 消息内容
                    Text(log.message)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.asideTextPrimary)
                        .lineLimit(isExpanded ? nil : 3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.asideGlassOverlay)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(levelColor.opacity(0.2), lineWidth: 1)
                    )
            )
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }
        }
    }
}

// MARK: - 过滤标签

struct FilterChip: View {
    let title: String
    let icon: AsideIcon.IconType?
    let isSelected: Bool
    var color: Color = .asideAccent
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    AsideIcon(icon: icon, size: 12, color: isSelected ? .white : color)
                }
                Text(title)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(isSelected ? .white : .asideTextSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? color : Color.asideCardBackground)
                    .shadow(color: isSelected ? color.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
            )
        }
        .buttonStyle(.plain)
    }
}

// 为了兼容性,添加一个不需要 icon 的初始化方法
extension FilterChip {
    init(title: String, isSelected: Bool, color: Color = .asideAccent, action: @escaping () -> Void) {
        self.title = title
        self.icon = nil
        self.isSelected = isSelected
        self.color = color
        self.action = action
    }
}

// MARK: - 分享组件

private struct DebugLogShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
