import SwiftUI

/// 歌单内搜索栏：默认只显示搜索图标 + 批量选择图标，点击后展开
struct PlaylistSearchBar: View {
    @ObservedObject private var settings = SettingsManager.shared

    @Binding var searchText: String
    @Binding var isSearching: Bool
    var onSearchActivated: (() -> Void)? = nil
    
    var isSelectMode: Binding<Bool>? = nil
    var selectedIds: Binding<Set<Int>>? = nil
    var songs: [Song]? = nil
    var onBatchQueue: (() -> Void)? = nil
    var onBatchDownload: (() -> Void)? = nil
    var onBatchCollect: (() -> Void)? = nil
    var onBatchRemove: (() -> Void)? = nil
    
    @FocusState private var isFocused: Bool
    
    private var selectMode: Bool { isSelectMode?.wrappedValue ?? false }
    
    var body: some View {
        let _ = settings.globalThemeRevision

        HStack(spacing: 8) {
            if selectMode {
                batchSelectionBar
            } else if isSearching {
                searchBar
            } else {
                normalBar
            }
        }
        .padding(.horizontal, CapsuleStyle.isActive ? DeviceLayout.viewHorizontalPadding - 4 : DeviceLayout.viewHorizontalPadding)
        .padding(.vertical, MangaStyle.isActive ? (selectMode || isSearching ? 8 : 6) : (NeumorphicStyle.isActive ? (selectMode || isSearching ? 8 : 4) : (CapsuleStyle.isActive ? (selectMode || isSearching ? 8 : 4) : (SequoiaStyle.isActive ? (selectMode || isSearching ? 8 : 4) : (selectMode || isSearching ? 6 : 2)))))
    }
    
    private var searchBar: some View {
        Group {
            HStack(spacing: 8) {
                MonologueIcon(icon: .search, size: 14, color: MangaStyle.isActive ? MangaStyle.inkSub : (NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : (CapsuleStyle.isActive ? CapsuleStyle.inkSoft : (SequoiaStyle.isActive ? SequoiaStyle.inkSoft : .monologueTextSecondary))))
                
                TextField(String(localized: "mono_session_search"), text: $searchText)
                    .font(MangaStyle.isActive ? MangaStyle.bodyFont(14, weight: .bold) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(14, weight: .medium) : (CapsuleStyle.isActive ? CapsuleStyle.labelFont(14, weight: .medium) : (SequoiaStyle.isActive ? SequoiaStyle.labelFont(14, weight: .regular) : .system(size: 14, design: .rounded)))))
                    .monologueTextInputBehavior()
                    .foregroundColor(MangaStyle.isActive ? MangaStyle.ink : (NeumorphicStyle.isActive ? NeumorphicStyle.ink : (CapsuleStyle.isActive ? CapsuleStyle.ink : (SequoiaStyle.isActive ? SequoiaStyle.ink : .monologueTextPrimary))))
                    .focused($isFocused)
                    .submitLabel(.search)
                
                Button {
                    if searchText.isEmpty {
                        closeSearch()
                    } else {
                        searchText = ""
                    }
                } label: {
                    MonologueIcon(icon: searchText.isEmpty ? .close : .xmarkCircle, size: 14, color: MangaStyle.isActive ? MangaStyle.inkMuted : (NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : (CapsuleStyle.isActive ? CapsuleStyle.inkMuted : (SequoiaStyle.isActive ? SequoiaStyle.inkMuted : .monologueTextSecondary.opacity(0.6)))))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, MangaStyle.isActive || NeumorphicStyle.isActive || CapsuleStyle.isActive || SequoiaStyle.isActive ? 10 : 8)
            .background {
                if MangaStyle.isActive {
                    MangaCardBackground(cornerRadius: MangaStyle.cardRadius, elevated: false, tint: MangaStyle.bubbleWhite)
                } else if NeumorphicStyle.isActive {
                    NeumorphicSurfaceBackground(cornerRadius: 16, elevated: false, pressed: true, lightweight: true)
                } else if CapsuleStyle.isActive {
                    CapsuleSurfaceBackground(cornerRadius: 18, elevated: false, tint: CapsuleStyle.surfaceRaised.opacity(0.92))
                } else if SequoiaStyle.isActive {
                    SequoiaSurfaceBackground(cornerRadius: 16, elevated: false, pressed: true, role: .list)
                } else {
                    Capsule()
                        .fill(Color.monologueTextPrimary.opacity(0.06))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: MangaStyle.isActive ? 12 : (NeumorphicStyle.isActive ? 16 : (CapsuleStyle.isActive ? 18 : (SequoiaStyle.isActive ? 16 : 20))), style: .continuous))
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            ))
            
            Button {
                closeSearch()
            } label: {
                Text("取消")
                    .font(MangaStyle.isActive ? MangaStyle.labelFont(12, weight: .black) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(13, weight: .medium) : (CapsuleStyle.isActive ? CapsuleStyle.labelFont(13, weight: .bold) : (SequoiaStyle.isActive ? SequoiaStyle.labelFont(13, weight: .medium) : .system(size: 13, weight: .medium, design: .rounded)))))
                    .foregroundColor(MangaStyle.isActive ? MangaStyle.inkSub : (NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : (CapsuleStyle.isActive ? CapsuleStyle.accent : (SequoiaStyle.isActive ? SequoiaStyle.inkSoft : .monologueTextSecondary))))
            }
            .transition(.opacity)
        }
    }

    private func closeSearch() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            searchText = ""
            isSearching = false
            isFocused = false
        }
    }
    
    private var normalBar: some View {
        HStack(spacing: 6) {
            Spacer()
            
            // 批量喜欢快捷入口:点击直接进入多选模式
            if isSelectMode != nil && onBatchCollect != nil {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isSelectMode?.wrappedValue = true
                        selectedIds?.wrappedValue.removeAll()
                    }
                } label: {
                    if SequoiaStyle.isActive {
                        SequoiaControlButton(icon: .like, tint: SequoiaStyle.red, size: 34)
                    } else if CapsuleStyle.isActive {
                        CapsuleDetailIconButton(icon: .like, tint: CapsuleStyle.coral)
                            .frame(width: 34, height: 34)
                    } else {
                        MonologueIcon(icon: .like, size: 14, color: MangaStyle.isActive ? MangaStyle.strokeInk : (NeumorphicStyle.isActive ? NeumorphicStyle.red : .monologueTextSecondary))
                            .frame(width: MangaStyle.isActive || NeumorphicStyle.isActive ? 34 : 28, height: MangaStyle.isActive || NeumorphicStyle.isActive ? 34 : 28)
                            .background {
                                if MangaStyle.isActive {
                                    MangaCardBackground(cornerRadius: MangaStyle.cardRadius, tint: MangaStyle.bubblePink)
                                } else if NeumorphicStyle.isActive {
                                    NeumorphicSurfaceBackground(cornerRadius: 12, elevated: false, pressed: true, lightweight: true)
                                }
                            }
                    }
                }
                .transition(.opacity)
            }

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isSearching = true
                }
                onSearchActivated?()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    isFocused = true
                }
            } label: {
                if SequoiaStyle.isActive {
                    SequoiaControlButton(icon: .search, tint: SequoiaStyle.accent, size: 34)
                } else if CapsuleStyle.isActive {
                    CapsuleDetailIconButton(icon: .search, tint: CapsuleStyle.accent)
                        .frame(width: 34, height: 34)
                } else {
                    MonologueIcon(icon: .search, size: 14, color: MangaStyle.isActive ? MangaStyle.strokeInk : (NeumorphicStyle.isActive ? NeumorphicStyle.accent : .monologueTextSecondary))
                        .frame(width: MangaStyle.isActive || NeumorphicStyle.isActive ? 34 : 28, height: MangaStyle.isActive || NeumorphicStyle.isActive ? 34 : 28)
                        .background {
                            if MangaStyle.isActive {
                                MangaCardBackground(cornerRadius: MangaStyle.cardRadius, tint: MangaStyle.paperCool)
                            } else if NeumorphicStyle.isActive {
                                NeumorphicSurfaceBackground(cornerRadius: 12, elevated: false, pressed: true, lightweight: true)
                            }
                        }
                    }
            }
            .transition(.opacity)
            
            if isSelectMode != nil {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isSelectMode?.wrappedValue = true
                        selectedIds?.wrappedValue.removeAll()
                    }
                } label: {
                    if SequoiaStyle.isActive {
                        SequoiaControlButton(icon: .checkmark, tint: SequoiaStyle.green, size: 34)
                    } else if CapsuleStyle.isActive {
                        CapsuleDetailIconButton(icon: .checkmark, tint: CapsuleStyle.mint)
                            .frame(width: 34, height: 34)
                    } else {
                        MonologueIcon(icon: .checkmark, size: 14, color: MangaStyle.isActive ? ThemeColorCustomization.readableForegroundColor(on: MangaStyle.labelYellow, light: MangaStyle.strokeInk, dark: MangaStyle.onStrokeInk) : (NeumorphicStyle.isActive ? NeumorphicStyle.sage : .monologueTextSecondary))
                            .frame(width: MangaStyle.isActive || NeumorphicStyle.isActive ? 34 : 28, height: MangaStyle.isActive || NeumorphicStyle.isActive ? 34 : 28)
                            .background {
                                if MangaStyle.isActive {
                                    MangaCardBackground(cornerRadius: MangaStyle.cardRadius, tint: MangaStyle.labelYellow)
                                } else if NeumorphicStyle.isActive {
                                    NeumorphicSurfaceBackground(cornerRadius: 12, elevated: false, pressed: true, lightweight: true)
                                }
                            }
                        }
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
                    .font(MangaStyle.isActive ? MangaStyle.labelFont(12, weight: .black) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(13, weight: .semibold) : (CapsuleStyle.isActive ? CapsuleStyle.labelFont(13, weight: .bold) : (SequoiaStyle.isActive ? SequoiaStyle.labelFont(13, weight: .semibold) : .system(size: 13, weight: .medium, design: .rounded)))))
                    .foregroundColor(MangaStyle.isActive ? MangaStyle.ink : (NeumorphicStyle.isActive ? NeumorphicStyle.ink : (CapsuleStyle.isActive ? CapsuleStyle.ink : (SequoiaStyle.isActive ? SequoiaStyle.ink : .monologueTextPrimary))))
            }
            .buttonStyle(.plain)
            
            Text("已选 \(selectedIds?.wrappedValue.count ?? 0) 首")
                .font(MangaStyle.isActive ? MangaStyle.bodyFont(12, weight: .bold) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(12, weight: .medium) : (CapsuleStyle.isActive ? CapsuleStyle.labelFont(12, weight: .medium) : (SequoiaStyle.isActive ? SequoiaStyle.labelFont(12, weight: .regular) : .system(size: 12, design: .rounded)))))
                .foregroundColor(MangaStyle.isActive ? MangaStyle.inkSub : (NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : (CapsuleStyle.isActive ? CapsuleStyle.inkSoft : (SequoiaStyle.isActive ? SequoiaStyle.inkSoft : .monologueTextSecondary))))
            
            Spacer()
            
            if let ids = selectedIds, !ids.wrappedValue.isEmpty {
                if onBatchQueue != nil {
                    Button { onBatchQueue?() } label: {
                        MonologueIcon(icon: .add, size: 18, color: MangaStyle.isActive ? MangaStyle.strokeInk : (NeumorphicStyle.isActive ? NeumorphicStyle.accent : (CapsuleStyle.isActive ? CapsuleStyle.accent : (SequoiaStyle.isActive ? SequoiaStyle.accent : .monologueTextPrimary))))
                            .frame(width: 32, height: 32)
                            .background(MangaStyle.isActive ? MangaStyle.bubbleBlue : (NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : (CapsuleStyle.isActive ? CapsuleStyle.surfaceTint : (SequoiaStyle.isActive ? SequoiaStyle.materialList : Color.monologueTextPrimary.opacity(0.06)))))
                            .clipShape(RoundedRectangle(cornerRadius: MangaStyle.isActive ? 10 : (NeumorphicStyle.isActive ? 11 : (CapsuleStyle.isActive ? 13 : (SequoiaStyle.isActive ? 11 : 16))), style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                if onBatchCollect != nil {
                    Button { onBatchCollect?() } label: {
                        MonologueIcon(icon: .like, size: 18, color: MangaStyle.isActive ? MangaStyle.strokeInk : (NeumorphicStyle.isActive ? NeumorphicStyle.red : (CapsuleStyle.isActive ? CapsuleStyle.coral : (SequoiaStyle.isActive ? SequoiaStyle.red : .monologueTextPrimary))))
                            .frame(width: 32, height: 32)
                            .background(MangaStyle.isActive ? MangaStyle.bubblePink : (NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : (CapsuleStyle.isActive ? CapsuleStyle.surfaceTint : (SequoiaStyle.isActive ? SequoiaStyle.materialList : Color.monologueTextPrimary.opacity(0.06)))))
                            .clipShape(RoundedRectangle(cornerRadius: MangaStyle.isActive ? 10 : (NeumorphicStyle.isActive ? 11 : (CapsuleStyle.isActive ? 13 : (SequoiaStyle.isActive ? 11 : 16))), style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                
                // 保留批量下载入口，由功能开关统一控制。
                if AppConfig.Features.downloadEnabled {
                    Button { onBatchDownload?() } label: {
                        MonologueIcon(icon: .download, size: 18, color: MangaStyle.isActive ? ThemeColorCustomization.readableForegroundColor(on: MangaStyle.labelYellow, light: MangaStyle.strokeInk, dark: MangaStyle.onStrokeInk) : (NeumorphicStyle.isActive ? NeumorphicStyle.warm : (CapsuleStyle.isActive ? CapsuleStyle.cyan : (SequoiaStyle.isActive ? SequoiaStyle.aqua : .monologueTextPrimary))))
                            .frame(width: 32, height: 32)
                            .background(MangaStyle.isActive ? MangaStyle.labelYellow : (NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : (CapsuleStyle.isActive ? CapsuleStyle.surfaceTint : (SequoiaStyle.isActive ? SequoiaStyle.materialList : Color.monologueTextPrimary.opacity(0.06)))))
                            .clipShape(RoundedRectangle(cornerRadius: MangaStyle.isActive ? MangaStyle.buttonRadius : (NeumorphicStyle.isActive ? 11 : (CapsuleStyle.isActive ? 13 : (SequoiaStyle.isActive ? 11 : 16))), style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                if onBatchRemove != nil {
                    Button { onBatchRemove?() } label: {
                        MonologueIcon(icon: .trash, size: 18, color: MangaStyle.isActive ? ThemeColorCustomization.readableForegroundColor(on: MangaStyle.labelYellow, light: MangaStyle.strokeInk, dark: MangaStyle.onStrokeInk) : (NeumorphicStyle.isActive ? NeumorphicStyle.red : (CapsuleStyle.isActive ? CapsuleStyle.coral : (SequoiaStyle.isActive ? SequoiaStyle.red : .monologueTextPrimary))))
                            .frame(width: 32, height: 32)
                            .background(MangaStyle.isActive ? MangaStyle.labelYellow : (NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : (CapsuleStyle.isActive ? CapsuleStyle.surfaceTint : (SequoiaStyle.isActive ? SequoiaStyle.materialList : Color.monologueTextPrimary.opacity(0.06)))))
                            .clipShape(RoundedRectangle(cornerRadius: MangaStyle.isActive ? MangaStyle.buttonRadius : (NeumorphicStyle.isActive ? 11 : (CapsuleStyle.isActive ? 13 : (SequoiaStyle.isActive ? 11 : 16))), style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isSelectMode?.wrappedValue = false
                    selectedIds?.wrappedValue.removeAll()
                }
            } label: {
                Text("取消")
                    .font(MangaStyle.isActive ? MangaStyle.labelFont(12, weight: .black) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(13, weight: .medium) : (CapsuleStyle.isActive ? CapsuleStyle.labelFont(13, weight: .bold) : (SequoiaStyle.isActive ? SequoiaStyle.labelFont(13, weight: .medium) : .system(size: 13, weight: .medium, design: .rounded)))))
                    .foregroundColor(MangaStyle.isActive ? MangaStyle.inkSub : (NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : (CapsuleStyle.isActive ? CapsuleStyle.inkSoft : (SequoiaStyle.isActive ? SequoiaStyle.inkSoft : .monologueTextSecondary))))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, MangaStyle.isActive || NeumorphicStyle.isActive || CapsuleStyle.isActive || SequoiaStyle.isActive ? 12 : 0)
        .padding(.vertical, MangaStyle.isActive || NeumorphicStyle.isActive || CapsuleStyle.isActive || SequoiaStyle.isActive ? 9 : 0)
        .background {
            if MangaStyle.isActive {
                MangaCardBackground(cornerRadius: MangaStyle.cardRadius + 2, elevated: false, tint: MangaStyle.bubbleWhite)
            } else if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(cornerRadius: 16, elevated: false, pressed: true, lightweight: true)
            } else if CapsuleStyle.isActive {
                CapsuleSurfaceBackground(cornerRadius: 18, elevated: false, tint: CapsuleStyle.surfaceRaised.opacity(0.92))
            } else if SequoiaStyle.isActive {
                SequoiaSurfaceBackground(cornerRadius: 16, elevated: false, pressed: true, role: .list)
            }
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
