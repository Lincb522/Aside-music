import SwiftUI

/// 歌单内搜索栏：默认只显示搜索图标 + 批量选择图标，点击后展开
struct PlaylistSearchBar: View {
    @ObservedObject private var settings = SettingsManager.shared

    @Binding var searchText: String
    @Binding var isSearching: Bool
    var onSearchActivated: (() -> Void)? = nil
    
    var isSelectMode: Binding<Bool>? = nil
    var selectedIds: Binding<Set<String>>? = nil
    var songs: [Song]? = nil
    var onBatchQueue: (() -> Void)? = nil
    var onBatchDownload: (() -> Void)? = nil
    var onBatchCollect: (() -> Void)? = nil
    var onBatchRemove: (() -> Void)? = nil
    
    @FocusState private var isFocused: Bool
    
    private var selectMode: Bool { isSelectMode?.wrappedValue ?? false }
    
    var body: some View {
        let _ = settings.globalThemeRevision

        Group {
            if SignalStyle.isActive {
                signalBar
            } else {
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
        }
    }

    @ViewBuilder
    private var signalBar: some View {
        Group {
            if selectMode {
                signalBatchSelectionBar
            } else if isSearching {
                signalSearchBar
            } else {
                signalNormalBar
            }
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(SignalStyle.separator.opacity(0.5))
                .frame(height: 0.65)
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        }
    }

    private var signalSearchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 9) {
                MonoIcon(icon: .search, size: 14, color: SignalStyle.accent, lineWidth: 1.6)

                TextField(String(localized: "mono_session_search"), text: $searchText)
                    .font(SignalStyle.bodyFont(14, weight: .medium))
                    .monoTextInputBehavior()
                    .foregroundStyle(SignalStyle.ink)
                    .focused($isFocused)
                    .submitLabel(.search)
                    .monoOnSubmit(text: $searchText) { _ in isFocused = false }

                Button {
                    if searchText.isEmpty {
                        closeSearch()
                    } else {
                        searchText = ""
                    }
                } label: {
                    MonoIcon(
                        icon: searchText.isEmpty ? .close : .xmarkCircle,
                        size: 14,
                        color: SignalStyle.inkMuted,
                        lineWidth: 1.5
                    )
                    .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, 12)
            .padding(.trailing, 6)
            .frame(height: 42)
            .background(
                SignalStyle.controlPressed,
                in: RoundedRectangle(cornerRadius: SignalStyle.buttonRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: SignalStyle.buttonRadius, style: .continuous)
                    .stroke(SignalStyle.separator.opacity(0.72), lineWidth: 0.7)
            }

            Button(action: closeSearch) {
                Text(String(localized: "cancel"))
                    .font(SignalStyle.labelFont(12, weight: .semibold))
                    .foregroundStyle(SignalStyle.inkSoft)
                    .frame(height: 42)
            }
            .buttonStyle(.plain)
        }
        .transition(.opacity.combined(with: .move(edge: .trailing)))
    }

    private var signalNormalBar: some View {
        HStack(spacing: 4) {
            Text(String(localized: "songs_unit").uppercased())
                .font(SignalStyle.monoFont(9, weight: .semibold))
                .foregroundStyle(SignalStyle.inkMuted)

            Spacer(minLength: 12)

            if isSelectMode != nil && onBatchCollect != nil {
                signalIconButton(icon: .like, tint: SignalStyle.inkSoft, label: String(localized: "收藏")) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isSelectMode?.wrappedValue = true
                        selectedIds?.wrappedValue.removeAll()
                    }
                }
            }

            signalIconButton(icon: .search, tint: SignalStyle.accent, label: String(localized: "mono_session_search")) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isSearching = true
                }
                onSearchActivated?()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    isFocused = true
                }
            }

            if isSelectMode != nil {
                signalIconButton(icon: .checkmark, tint: SignalStyle.inkSoft, label: String(localized: "多选")) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isSelectMode?.wrappedValue = true
                        selectedIds?.wrappedValue.removeAll()
                    }
                }
            }
        }
        .frame(height: 38)
    }

    private var signalBatchSelectionBar: some View {
        HStack(spacing: 7) {
            Button {
                guard let ids = selectedIds, let allSongs = songs else { return }
                if ids.wrappedValue.count == allSongs.count {
                    ids.wrappedValue.removeAll()
                } else {
                    ids.wrappedValue = Set(allSongs.map(\.identityKey))
                }
            } label: {
                Text(selectedIds?.wrappedValue.count == songs?.count ? String(localized: "取消全选") : String(localized: "全选"))
                    .font(SignalStyle.labelFont(12, weight: .semibold))
                    .foregroundStyle(SignalStyle.ink)
            }
            .buttonStyle(.plain)

            Text(String(format: "%02d", selectedIds?.wrappedValue.count ?? 0))
                .font(SignalStyle.monoFont(10, weight: .semibold))
                .foregroundStyle(SignalStyle.accent)
                .monospacedDigit()

            Spacer(minLength: 6)

            if !(selectedIds?.wrappedValue.isEmpty ?? true) {
                if onBatchQueue != nil {
                    signalIconButton(icon: .add, tint: SignalStyle.inkSoft, label: String(localized: "player_queue")) {
                        onBatchQueue?()
                    }
                }
                if onBatchCollect != nil {
                    signalIconButton(icon: .like, tint: SignalStyle.inkSoft, label: String(localized: "收藏")) {
                        onBatchCollect?()
                    }
                }
                if AppConfig.Features.downloadEnabled {
                    signalIconButton(icon: .download, tint: SignalStyle.inkSoft, label: String(localized: "download")) {
                        onBatchDownload?()
                    }
                }
                if onBatchRemove != nil {
                    signalIconButton(icon: .trash, tint: SignalStyle.rust, label: String(localized: "lib_delete")) {
                        onBatchRemove?()
                    }
                }
            }

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isSelectMode?.wrappedValue = false
                    selectedIds?.wrappedValue.removeAll()
                }
            } label: {
                Text(String(localized: "cancel"))
                    .font(SignalStyle.labelFont(12, weight: .semibold))
                    .foregroundStyle(SignalStyle.inkMuted)
            }
            .buttonStyle(.plain)
        }
        .frame(height: 38)
        .transition(.opacity.combined(with: .move(edge: .trailing)))
    }

    private func signalIconButton(
        icon: MonoIcon.IconType,
        tint: Color,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            MonoIcon(icon: icon, size: 14, color: tint, lineWidth: 1.6)
                .frame(width: 38, height: 38)
                .contentShape(Rectangle())
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.92))
        .accessibilityLabel(label)
    }
    
    private var searchBar: some View {
        Group {
            HStack(spacing: 8) {
                MonoIcon(icon: .search, size: 14, color: MangaStyle.isActive ? MangaStyle.inkSub : (NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : (CapsuleStyle.isActive ? CapsuleStyle.inkSoft : (SequoiaStyle.isActive ? SequoiaStyle.inkSoft : .monoTextSecondary))))
                
                TextField(String(localized: "mono_session_search"), text: $searchText)
                    .font(MangaStyle.isActive ? MangaStyle.bodyFont(14, weight: .bold) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(14, weight: .medium) : (CapsuleStyle.isActive ? CapsuleStyle.labelFont(14, weight: .medium) : (SequoiaStyle.isActive ? SequoiaStyle.labelFont(14, weight: .regular) : .system(size: 14, design: .rounded)))))
                    .monoTextInputBehavior()
                    .foregroundColor(MangaStyle.isActive ? MangaStyle.ink : (NeumorphicStyle.isActive ? NeumorphicStyle.ink : (CapsuleStyle.isActive ? CapsuleStyle.ink : (SequoiaStyle.isActive ? SequoiaStyle.ink : .monoTextPrimary))))
                    .focused($isFocused)
                    .submitLabel(.search)
                    .monoOnSubmit(text: $searchText) { _ in
                        isFocused = false
                    }
                
                Button {
                    if searchText.isEmpty {
                        closeSearch()
                    } else {
                        searchText = ""
                    }
                } label: {
                    MonoIcon(icon: searchText.isEmpty ? .close : .xmarkCircle, size: 14, color: MangaStyle.isActive ? MangaStyle.inkMuted : (NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : (CapsuleStyle.isActive ? CapsuleStyle.inkMuted : (SequoiaStyle.isActive ? SequoiaStyle.inkMuted : .monoTextSecondary.opacity(0.6)))))
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
                        .fill(Color.monoTextPrimary.opacity(0.06))
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
                    .foregroundColor(MangaStyle.isActive ? MangaStyle.inkSub : (NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : (CapsuleStyle.isActive ? CapsuleStyle.accent : (SequoiaStyle.isActive ? SequoiaStyle.inkSoft : .monoTextSecondary))))
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
                        MonoIcon(icon: .like, size: 14, color: MangaStyle.isActive ? MangaStyle.strokeInk : (NeumorphicStyle.isActive ? NeumorphicStyle.red : .monoTextSecondary))
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
                    MonoIcon(icon: .search, size: 14, color: MangaStyle.isActive ? MangaStyle.strokeInk : (NeumorphicStyle.isActive ? NeumorphicStyle.accent : .monoTextSecondary))
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
                        MonoIcon(icon: .checkmark, size: 14, color: MangaStyle.isActive ? ThemeColorCustomization.readableForegroundColor(on: MangaStyle.labelYellow, light: MangaStyle.strokeInk, dark: MangaStyle.onStrokeInk) : (NeumorphicStyle.isActive ? NeumorphicStyle.sage : .monoTextSecondary))
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
                    ids.wrappedValue = Set(allSongs.map { $0.identityKey })
                }
            } label: {
                Text(selectedIds?.wrappedValue.count == songs?.count ? String(localized: "取消全选") : String(localized: "全选"))
                    .font(MangaStyle.isActive ? MangaStyle.labelFont(12, weight: .black) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(13, weight: .semibold) : (CapsuleStyle.isActive ? CapsuleStyle.labelFont(13, weight: .bold) : (SequoiaStyle.isActive ? SequoiaStyle.labelFont(13, weight: .semibold) : .system(size: 13, weight: .medium, design: .rounded)))))
                    .foregroundColor(MangaStyle.isActive ? MangaStyle.ink : (NeumorphicStyle.isActive ? NeumorphicStyle.ink : (CapsuleStyle.isActive ? CapsuleStyle.ink : (SequoiaStyle.isActive ? SequoiaStyle.ink : .monoTextPrimary))))
            }
            .buttonStyle(.plain)
            
            Text("已选 \(selectedIds?.wrappedValue.count ?? 0) 首")
                .font(MangaStyle.isActive ? MangaStyle.bodyFont(12, weight: .bold) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(12, weight: .medium) : (CapsuleStyle.isActive ? CapsuleStyle.labelFont(12, weight: .medium) : (SequoiaStyle.isActive ? SequoiaStyle.labelFont(12, weight: .regular) : .system(size: 12, design: .rounded)))))
                .foregroundColor(MangaStyle.isActive ? MangaStyle.inkSub : (NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : (CapsuleStyle.isActive ? CapsuleStyle.inkSoft : (SequoiaStyle.isActive ? SequoiaStyle.inkSoft : .monoTextSecondary))))
            
            Spacer()
            
            if let ids = selectedIds, !ids.wrappedValue.isEmpty {
                if onBatchQueue != nil {
                    Button { onBatchQueue?() } label: {
                        MonoIcon(icon: .add, size: 18, color: MangaStyle.isActive ? MangaStyle.strokeInk : (NeumorphicStyle.isActive ? NeumorphicStyle.accent : (CapsuleStyle.isActive ? CapsuleStyle.accent : (SequoiaStyle.isActive ? SequoiaStyle.accent : .monoTextPrimary))))
                            .frame(width: 32, height: 32)
                            .background(MangaStyle.isActive ? MangaStyle.bubbleBlue : (NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : (CapsuleStyle.isActive ? CapsuleStyle.surfaceTint : (SequoiaStyle.isActive ? SequoiaStyle.materialList : Color.monoTextPrimary.opacity(0.06)))))
                            .clipShape(RoundedRectangle(cornerRadius: MangaStyle.isActive ? 10 : (NeumorphicStyle.isActive ? 11 : (CapsuleStyle.isActive ? 13 : (SequoiaStyle.isActive ? 11 : 16))), style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                if onBatchCollect != nil {
                    Button { onBatchCollect?() } label: {
                        MonoIcon(icon: .like, size: 18, color: MangaStyle.isActive ? MangaStyle.strokeInk : (NeumorphicStyle.isActive ? NeumorphicStyle.red : (CapsuleStyle.isActive ? CapsuleStyle.coral : (SequoiaStyle.isActive ? SequoiaStyle.red : .monoTextPrimary))))
                            .frame(width: 32, height: 32)
                            .background(MangaStyle.isActive ? MangaStyle.bubblePink : (NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : (CapsuleStyle.isActive ? CapsuleStyle.surfaceTint : (SequoiaStyle.isActive ? SequoiaStyle.materialList : Color.monoTextPrimary.opacity(0.06)))))
                            .clipShape(RoundedRectangle(cornerRadius: MangaStyle.isActive ? 10 : (NeumorphicStyle.isActive ? 11 : (CapsuleStyle.isActive ? 13 : (SequoiaStyle.isActive ? 11 : 16))), style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                
                // 保留批量下载入口，由功能开关统一控制。
                if AppConfig.Features.downloadEnabled {
                    Button { onBatchDownload?() } label: {
                        MonoIcon(icon: .download, size: 18, color: MangaStyle.isActive ? ThemeColorCustomization.readableForegroundColor(on: MangaStyle.labelYellow, light: MangaStyle.strokeInk, dark: MangaStyle.onStrokeInk) : (NeumorphicStyle.isActive ? NeumorphicStyle.warm : (CapsuleStyle.isActive ? CapsuleStyle.cyan : (SequoiaStyle.isActive ? SequoiaStyle.aqua : .monoTextPrimary))))
                            .frame(width: 32, height: 32)
                            .background(MangaStyle.isActive ? MangaStyle.labelYellow : (NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : (CapsuleStyle.isActive ? CapsuleStyle.surfaceTint : (SequoiaStyle.isActive ? SequoiaStyle.materialList : Color.monoTextPrimary.opacity(0.06)))))
                            .clipShape(RoundedRectangle(cornerRadius: MangaStyle.isActive ? MangaStyle.buttonRadius : (NeumorphicStyle.isActive ? 11 : (CapsuleStyle.isActive ? 13 : (SequoiaStyle.isActive ? 11 : 16))), style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                if onBatchRemove != nil {
                    Button { onBatchRemove?() } label: {
                        MonoIcon(icon: .trash, size: 18, color: MangaStyle.isActive ? ThemeColorCustomization.readableForegroundColor(on: MangaStyle.labelYellow, light: MangaStyle.strokeInk, dark: MangaStyle.onStrokeInk) : (NeumorphicStyle.isActive ? NeumorphicStyle.red : (CapsuleStyle.isActive ? CapsuleStyle.coral : (SequoiaStyle.isActive ? SequoiaStyle.red : .monoTextPrimary))))
                            .frame(width: 32, height: 32)
                            .background(MangaStyle.isActive ? MangaStyle.labelYellow : (NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : (CapsuleStyle.isActive ? CapsuleStyle.surfaceTint : (SequoiaStyle.isActive ? SequoiaStyle.materialList : Color.monoTextPrimary.opacity(0.06)))))
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
                    .foregroundColor(MangaStyle.isActive ? MangaStyle.inkSub : (NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : (CapsuleStyle.isActive ? CapsuleStyle.inkSoft : (SequoiaStyle.isActive ? SequoiaStyle.inkSoft : .monoTextSecondary))))
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
