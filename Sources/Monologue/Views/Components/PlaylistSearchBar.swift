import SwiftUI

/// 歌单内搜索栏：默认只显示搜索图标 + 批量选择图标，点击后展开
struct PlaylistSearchBar: View {
    @Binding var searchText: String
    @Binding var isSearching: Bool
    var onSearchActivated: (() -> Void)? = nil
    
    var isSelectMode: Binding<Bool>? = nil
    var selectedIds: Binding<Set<Int>>? = nil
    var songs: [Song]? = nil
    var onBatchQueue: (() -> Void)? = nil
    var onBatchDownload: (() -> Void)? = nil
    var onBatchCollect: (() -> Void)? = nil
    
    @FocusState private var isFocused: Bool
    
    private var selectMode: Bool { isSelectMode?.wrappedValue ?? false }
    
    var body: some View {
        HStack(spacing: 8) {
            if selectMode {
                batchSelectionBar
            } else if isSearching {
                searchBar
            } else {
                normalBar
            }
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.vertical, selectMode || isSearching ? 6 : 2)
    }
    
    private var searchBar: some View {
        Group {
            HStack(spacing: 8) {
                MonologueIcon(icon: .search, size: 14, color: .monologueTextSecondary)
                
                TextField(String(localized: "搜索歌曲"), text: $searchText)
                    .font(.system(size: 14, design: .rounded))
                    .monologueTextInputBehavior()
                    .foregroundColor(.monologueTextPrimary)
                    .focused($isFocused)
                    .submitLabel(.search)
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        MonologueIcon(icon: .xmarkCircle, size: 14, color: .monologueTextSecondary.opacity(0.6))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.monologueTextPrimary.opacity(0.06))
            .clipShape(Capsule())
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            ))
            
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    searchText = ""
                    isSearching = false
                    isFocused = false
                }
            } label: {
                Text("取消")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.monologueTextSecondary)
            }
            .transition(.opacity)
        }
    }
    
    private var normalBar: some View {
        HStack(spacing: 6) {
            Spacer()
            
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isSearching = true
                }
                onSearchActivated?()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    isFocused = true
                }
            } label: {
                MonologueIcon(icon: .search, size: 14, color: .monologueTextSecondary)
                    .frame(width: 28, height: 28)
            }
            .transition(.opacity)
            
            if isSelectMode != nil {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isSelectMode?.wrappedValue = true
                        selectedIds?.wrappedValue.removeAll()
                    }
                } label: {
                    MonologueIcon(icon: .checkmark, size: 14, color: .monologueTextSecondary)
                        .frame(width: 28, height: 28)
                }
                .transition(.opacity)
            }
        }
    }
    
    private var batchSelectionBar: some View {
        HStack(spacing: 10) {
            Button {
                guard let ids = selectedIds, let allSongs = songs else { return }
                if ids.wrappedValue.count == allSongs.count {
                    ids.wrappedValue.removeAll()
                } else {
                    ids.wrappedValue = Set(allSongs.map { $0.id })
                }
            } label: {
                Text(selectedIds?.wrappedValue.count == songs?.count ? String(localized: "取消全选") : String(localized: "全选"))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.monologueTextPrimary)
            }
            .buttonStyle(.plain)
            
            Text("已选 \(selectedIds?.wrappedValue.count ?? 0) 首")
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.monologueTextSecondary)
            
            Spacer()
            
            if let ids = selectedIds, !ids.wrappedValue.isEmpty {
                if onBatchQueue != nil {
                    Button { onBatchQueue?() } label: {
                        MonologueIcon(icon: .add, size: 18, color: .monologueTextPrimary)
                            .frame(width: 32, height: 32)
                            .background(Color.monologueTextPrimary.opacity(0.06))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                Button { onBatchCollect?() } label: {
                    MonologueIcon(icon: .like, size: 18, color: .monologueTextPrimary)
                        .frame(width: 32, height: 32)
                        .background(Color.monologueTextPrimary.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                
                Button { onBatchDownload?() } label: {
                    MonologueIcon(icon: .download, size: 18, color: .monologueTextPrimary)
                        .frame(width: 32, height: 32)
                        .background(Color.monologueTextPrimary.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isSelectMode?.wrappedValue = false
                    selectedIds?.wrappedValue.removeAll()
                }
            } label: {
                Text("取消")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.monologueTextSecondary)
            }
            .buttonStyle(.plain)
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .trailing).combined(with: .opacity)
        ))
    }
}

@MainActor
enum SongBatchActionHelper {
    static func addToQueue(_ songs: [Song], reset: (() -> Void)? = nil) {
        guard !songs.isEmpty else { return }

        PlayerManager.shared.addToQueue(songs: songs)
        AlertManager.shared.show(
            title: String(localized: "queue_added_title"),
            message: String(format: String(localized: "queue_added_message"), songs.count),
            primaryButtonTitle: String(localized: "confirm"),
            primaryAction: {}
        )

        if let reset {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                reset()
            }
        }
    }
}

// MARK: - 搜索过滤工具

extension Array where Element == Song {
    func filtered(by query: String) -> [Song] {
        guard !query.isEmpty else { return self }
        let q = query.lowercased()
        return filter {
            $0.name.lowercased().contains(q)
            || $0.artistName.lowercased().contains(q)
            || ($0.album?.name.lowercased().contains(q) ?? false)
        }
    }
}
