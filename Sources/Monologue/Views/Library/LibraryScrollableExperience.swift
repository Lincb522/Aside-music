import Combine
import QQMusicKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Shared Scrollable Library

struct ScrollableLibraryExperience: View {
    private enum MyLibraryColumn: CaseIterable, Hashable {
        case localPlaylists, ncmPlaylists, qcmPlaylists, localPodcasts, ncmPodcasts

        var title: String {
            switch self {
            case .localPlaylists: return String(localized: "lib_local_playlists")
            case .ncmPlaylists: return String(localized: "lib_netease_playlists")
            case .qcmPlaylists: return String(localized: "QCM歌单")
            case .localPodcasts: return String(localized: "本地播客")
            case .ncmPodcasts: return String(localized: "NCM 播客")
            }
        }

        var icon: MonologueIcon.IconType {
            switch self {
            case .localPlaylists: return .musicNoteList
            case .ncmPlaylists, .qcmPlaylists: return .list
            case .localPodcasts, .ncmPodcasts: return .radio
            }
        }
    }

    @ObservedObject var viewModel: LibraryViewModel
    @Binding var tabIndex: Int
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var localManager = LocalPlaylistManager.shared
    @ObservedObject private var subManager = SubscriptionManager.shared
    @ObservedObject private var qqSession = QQUserSession.shared
    @State private var selectedMyLibraryColumn: MyLibraryColumn = .localPlaylists
    @State private var isLibraryActionsExpanded = false
    @State private var showFileImporter = false
    @State private var showQQImport = false
    @State private var isImporting = false
    @State private var qqUserPlaylists: [Playlist] = []
    @State private var isLoadingQQUserPlaylists = false
    @State private var hasLoadedQQUserPlaylists = false
    @Namespace private var sequoiaLibraryNamespace

    private let tabs = LibraryViewModel.LibraryTab.allCases
    private let twoColumns = [GridItem(.flexible(), spacing: 13), GridItem(.flexible(), spacing: 13)]
    private let actionColumns = [GridItem(.flexible(), spacing: 9), GridItem(.flexible(), spacing: 9)]
    private let artistColumns = Array(repeating: GridItem(.flexible(), spacing: 14), count: DeviceLayout.artistGridColumns)

    private var selectedTab: LibraryViewModel.LibraryTab {
        tabs[min(max(tabIndex, 0), tabs.count - 1)]
    }

    private var activeTabTint: Color {
        tint(for: selectedTab)
    }

    private var activeTabEyebrow: String {
        switch selectedTab {
        case .my: return "COLLECTION"
        case .square: return "DISCOVER"
        case .artists: return "ARTISTS"
        case .charts: return "CHARTS"
        }
    }

    private var activeTabShortLabel: String {
        switch selectedTab {
        case .my: return String(localized: "我的")
        case .square: return String(localized: "广场")
        case .artists: return String(localized: "歌手")
        case .charts: return String(localized: "榜单")
        }
    }

    private var contentHorizontalPadding: CGFloat {
        PetWhiteStyle.isActive ? (DeviceLayout.isPad ? 16 : 10) : DeviceLayout.libraryHorizontalPadding
    }

    var body: some View {
        let _ = settings.globalThemeRevision
        ZStack {
            ThemedPageBackground(useRenderLayer: true)
                .ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    header
                    tabContent
                }
                .padding(.bottom, 128)
            }
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
        .onAppear {
            syncTabFromViewModel()
            loadCurrentTab()
            if subManager.subscribedRadios.isEmpty {
                subManager.fetchSubscribedRadios()
            }
        }
        .onChange(of: viewModel.currentTab) { _, _ in
            syncTabFromViewModel()
            loadCurrentTab()
        }
        .onChange(of: tabIndex) { _, _ in
            loadCurrentTab()
        }
        .onChange(of: qqSession.isLoggedIn) { _, isLoggedIn in
            if isLoggedIn {
                hasLoadedQQUserPlaylists = false
                loadQQUserPlaylistsIfNeeded(force: true)
            } else {
                qqUserPlaylists = []
                hasLoadedQQUserPlaylists = false
            }
        }
        .monologueSheet(isPresented: $showQQImport, preset: .large) {
            QQPlaylistImportView()
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
            switch result {
            case let .success(urls):
                guard let url = urls.first else { return }
                importPlaylistFromFile(url: url)
            case let .failure(error):
                AlertManager.shared.show(
                    title: String(localized: "lib_import_failed"),
                    message: error.localizedDescription,
                    primaryButtonTitle: String(localized: "lib_confirm"),
                    primaryAction: {}
                )
            }
        }
    }

    @ViewBuilder
    private var header: some View {
        if LiquidGlassStyle.isActive {
            liquidGlassHeaderDeck
        } else if PetWhiteStyle.isActive {
            petWhiteHeaderDeck
        } else if NeumorphicStyle.isActive {
            neumorphicHeaderDeck
        } else if SignalStyle.isActive {
            signalHeaderDeck
        } else if SequoiaStyle.isActive {
            sequoiaHeaderDeck
        } else if CapsuleStyle.isActive {
            capsuleHeaderDeck
        } else {
            VStack(alignment: .leading, spacing: 14) {
                if MujiStyle.isActive {
                    MujiPageHeader(eyebrow: "collection shelves", title: String(localized: "tabbar_library"), subtitle: "") {
                        MujiIconBadge(icon: .library, tint: MujiStyle.tea, size: 48)
                    }
                } else {
                    HStack(spacing: 12) {
                        MonologueIcon(icon: .libraryFilled, size: 24, color: .monologueIconForeground, lineWidth: 2)
                            .frame(width: 50, height: 50)
                            .background(Color.monologueIconBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: Color.monologueIconBackground.opacity(0.18), radius: 10, y: 5)

                        Text(LocalizedStringKey("tabbar_library"))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.monologueTextPrimary)

                        Spacer(minLength: 0)
                    }
                }

                tabStrip
            }
            .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
            .padding(.top, DeviceLayout.headerTopPadding + 8)
        }
    }

    private var neumorphicHeaderDeck: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 15) {
                HStack(alignment: .top, spacing: 14) {
                    NeumorphicIconBadge(icon: icon(for: selectedTab), tint: activeTabTint, size: 52)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(activeTabEyebrow)
                            .font(NeumorphicStyle.labelFont(10, weight: .semibold))
                            .foregroundStyle(activeTabTint)
                            .tracking(1.1)

                        Text(String(localized: "tabbar_library"))
                            .font(NeumorphicStyle.titleFont(30, weight: .semibold))
                            .foregroundStyle(NeumorphicStyle.ink)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    Text(activeTabShortLabel)
                        .font(NeumorphicStyle.labelFont(10, weight: .semibold))
                        .foregroundStyle(activeTabTint)
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(activeTabTint.opacity(0.13))
                        )
                }

            }
            .padding(16)
            .background(
                NeumorphicSurfaceBackground(
                    cornerRadius: 28,
                    elevated: true,
                    tint: activeTabTint.opacity(0.06)
                )
            )

            tabStrip
        }
        .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
        .padding(.top, DeviceLayout.headerTopPadding + 10)
    }

    private var petWhiteHeaderDeck: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                PetWhiteIconBadge(icon: icon(for: selectedTab), tint: activeTabTint, size: 42)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 7) {
                        PetWhitePill(text: activeTabEyebrow, tint: activeTabTint)
                        PetWhitePill(text: activeTabShortLabel, tint: PetWhiteStyle.butter)
                    }

                    Text(String(localized: "tabbar_library"))
                        .font(PetWhiteStyle.titleFont(26, weight: .black))
                        .foregroundStyle(PetWhiteStyle.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
                .layoutPriority(1)

                Spacer(minLength: 8)

                PetWhitePetPetIcon(size: 42)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 12)
            .background(
                PetWhiteSurfaceBackground(
                    cornerRadius: 24,
                    elevated: true,
                    tint: PetWhiteStyle.surfaceRaised,
                    accent: activeTabTint
                )
            )

            tabStrip
        }
        .padding(.horizontal, contentHorizontalPadding)
        .padding(.top, DeviceLayout.headerTopPadding + 4)
    }

    private var signalHeaderDeck: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        SignalPulseDot(tint: activeTabTint, size: 18)

                        Text(activeTabEyebrow)
                            .font(SignalStyle.monoFont(10, weight: .semibold))
                            .foregroundStyle(activeTabTint)
                    }

                    Text(String(localized: "tabbar_library"))
                        .font(SignalStyle.titleFont(27, weight: .bold))
                        .foregroundStyle(SignalStyle.ink)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                HStack(spacing: 8) {
                    SignalLibraryMiniBars(tint: activeTabTint)
                    SignalPill(text: activeTabShortLabel, tint: activeTabTint, selected: true, compact: true)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(SignalSurfaceBackground(cornerRadius: 18, elevated: false, pressed: true, fill: SignalStyle.control))
            }

            tabStrip
        }
        .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
        .padding(.top, DeviceLayout.headerTopPadding + 10)
    }

    private var sequoiaHeaderDeck: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 13) {
                VStack(spacing: 4) {
                    Capsule()
                        .fill(activeTabTint)
                        .frame(width: 4, height: 26)
                    Capsule()
                        .fill(SequoiaStyle.separator)
                        .frame(width: 4, height: 10)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(activeTabEyebrow)
                        .font(SequoiaStyle.labelFont(10, weight: .semibold))
                        .foregroundStyle(activeTabTint)
                        .tracking(0.9)

                    Text(String(localized: "tabbar_library"))
                        .font(SequoiaStyle.titleFont(25, weight: .semibold))
                        .foregroundStyle(SequoiaStyle.ink)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                HStack(spacing: 9) {
                    SequoiaMeter(tint: activeTabTint, count: 9)
                    SequoiaPill(text: activeTabShortLabel, tint: activeTabTint, selected: true, compact: true)
                }
            }
            .padding(14)
            .background(SequoiaChromeBar(cornerRadius: 23))

            tabStrip
        }
        .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
        .padding(.top, DeviceLayout.headerTopPadding + 8)
    }

    @ViewBuilder
    private var tabStrip: some View {
        if LiquidGlassStyle.isActive {
            liquidGlassTabDeck
        } else if PetWhiteStyle.isActive {
            petWhiteTabDeck
        } else if NeumorphicStyle.isActive {
            neumorphicTabDeck
        } else if SignalStyle.isActive {
            signalTabDeck
        } else if SequoiaStyle.isActive {
            sequoiaTabDeck
        } else if CapsuleStyle.isActive {
            capsuleTabDeck
        } else {
            HStack(spacing: 6) {
                ForEach(Array(tabs.enumerated()), id: \.element) { index, tab in
                    let selected = tabIndex == index
                    Button {
                        selectTab(tab, index: index)
                    } label: {
                        HStack(spacing: 6) {
                            MonologueIcon(icon: icon(for: tab), size: 13, color: tabForeground(selected: selected), lineWidth: 1.8)
                            Text(tab.localizedKey)
                                .font(tabFont(selected: selected))
                                .foregroundColor(tabForeground(selected: selected))
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: NeumorphicStyle.isActive ? 40 : 38)
                        .background(tabBackground(selected: selected, tint: tint(for: tab)))
                        .contentShape(RoundedRectangle(cornerRadius: tabCornerRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(NeumorphicStyle.isActive ? 5 : 4)
            .background(panelBackground(cornerRadius: NeumorphicStyle.isActive ? 20 : 14))
            .animation(.spring(response: 0.34, dampingFraction: 0.86), value: tabIndex)
        }
    }

    private var capsuleHeaderDeck: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                CapsuleIconBadge(icon: icon(for: selectedTab), tint: activeTabTint, size: 46)

                VStack(alignment: .leading, spacing: 4) {
                    Text(activeTabEyebrow)
                        .font(CapsuleStyle.labelFont(10, weight: .bold))
                        .foregroundStyle(activeTabTint)
                        .tracking(1.1)

                    Text(String(localized: "tabbar_library"))
                        .font(CapsuleStyle.titleFont(25, weight: .bold))
                        .foregroundStyle(CapsuleStyle.ink)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                HStack(spacing: 6) {
                    Capsule()
                        .fill(activeTabTint)
                        .frame(width: 24, height: 8)
                    Capsule()
                        .fill(CapsuleStyle.cyan.opacity(0.65))
                        .frame(width: 10, height: 8)
                    Text(activeTabShortLabel)
                        .font(CapsuleStyle.labelFont(11, weight: .bold))
                        .foregroundStyle(CapsuleStyle.ink)
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .frame(height: 36)
                .background(
                    CapsuleSurfaceBackground(
                        cornerRadius: 18,
                        elevated: true,
                        tint: CapsuleStyle.surfaceRaised.opacity(0.82)
                    )
                )
            }

            tabStrip
        }
        .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
        .padding(.top, DeviceLayout.headerTopPadding + 8)
    }

    private var capsuleTabDeck: some View {
        HStack(spacing: 7) {
            ForEach(Array(tabs.enumerated()), id: \.element) { index, tab in
                capsuleTabButton(tab: tab, index: index)
            }
        }
        .padding(5)
        .background(
            CapsuleSurfaceBackground(
                cornerRadius: 22,
                elevated: true,
                tint: CapsuleStyle.surface.opacity(0.88)
            )
        )
        .animation(.spring(response: 0.34, dampingFraction: 0.88), value: tabIndex)
    }

    private func capsuleTabButton(tab: LibraryViewModel.LibraryTab, index: Int) -> some View {
        let selected = tabIndex == index
        let tint = tint(for: tab)

        return Button {
            selectTab(tab, index: index)
        } label: {
            VStack(spacing: 5) {
                MonologueIcon(
                    icon: icon(for: tab),
                    size: 14,
                    color: selected ? CapsuleStyle.readableLabel(on: tint) : CapsuleStyle.inkSoft,
                    lineWidth: selected ? 1.9 : 1.55
                )

                Text(tab.localizedKey)
                    .font(CapsuleStyle.labelFont(10.5, weight: selected ? .bold : .semibold))
                    .foregroundStyle(selected ? CapsuleStyle.readableLabel(on: tint) : CapsuleStyle.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(tint)
                        .overlay(
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .stroke(Color.white.opacity(0.35), lineWidth: 0.8)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(CapsuleStyle.surfaceRaised.opacity(0.62))
                        .overlay(
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .stroke(CapsuleStyle.separator.opacity(0.35), lineWidth: 0.7)
                        )
                }
            }
        }
        .buttonStyle(CapsulePressStyle())
    }

    private var liquidGlassHeaderDeck: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                LiquidGlassRefractionHeaderShape()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        LiquidGlassRefractionHeaderShape()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        activeTabTint.opacity(0.2),
                                        LiquidGlassStyle.glassRaised.opacity(0.74),
                                        LiquidGlassStyle.cyan.opacity(0.1),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        LiquidGlassRefractionHeaderShape()
                            .strokeBorder(Color.white.opacity(0.48), lineWidth: 0.75)
                    )

                LiquidGlassCausticField(opacity: 0.1)
                    .clipShape(LiquidGlassRefractionHeaderShape())

                HStack(alignment: .bottom, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            LiquidGlassDropletMark(tint: activeTabTint)

                            Text(activeTabShortLabel)
                                .font(LiquidGlassStyle.labelFont(11, weight: .bold))
                                .foregroundStyle(activeTabTint)
                                .lineLimit(1)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(activeTabTint.opacity(0.13)))
                        }

                        Text(String(localized: "tabbar_library"))
                            .font(LiquidGlassStyle.titleFont(31, weight: .semibold))
                            .foregroundStyle(LiquidGlassStyle.ink)
                            .lineLimit(1)
                    }
                    .layoutPriority(1)

                    Spacer(minLength: 8)

                    LiquidGlassIconBadge(icon: icon(for: selectedTab), tint: activeTabTint, size: 54)
                }
                .padding(16)
            }
            .frame(height: 126)

            tabStrip
        }
        .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
        .padding(.top, DeviceLayout.headerTopPadding + 8)
    }

    private var liquidGlassTabDeck: some View {
        HStack(spacing: 7) {
            ForEach(Array(tabs.enumerated()), id: \.element) { index, tab in
                liquidGlassTabButton(tab: tab, index: index)
            }
        }
        .padding(5)
        .background(LiquidGlassSurfaceBackground(cornerRadius: 24, elevated: true, role: .chrome))
        .animation(.spring(response: 0.32, dampingFraction: 0.88), value: tabIndex)
    }

    private var petWhiteTabDeck: some View {
        HStack(spacing: 7) {
            ForEach(Array(tabs.enumerated()), id: \.element) { index, tab in
                petWhiteTabButton(tab: tab, index: index)
            }
        }
        .padding(5)
        .background(PetWhiteSurfaceBackground(cornerRadius: 22, elevated: true, tint: PetWhiteStyle.surfacePressed, accent: activeTabTint))
        .animation(.spring(response: 0.32, dampingFraction: 0.88), value: tabIndex)
    }

    private func petWhiteTabButton(tab: LibraryViewModel.LibraryTab, index: Int) -> some View {
        let selected = tabIndex == index
        let tint = tint(for: tab)

        return Button {
            selectTab(tab, index: index)
        } label: {
            VStack(spacing: 5) {
                PetWhitePackIcon(
                    icon: icon(for: tab),
                    size: 19,
                    visualScale: selected ? 1.08 : 0.98,
                    fallbackColor: selected ? PetWhiteStyle.stroke : PetWhiteStyle.inkSoft,
                    lineWidth: selected ? 1.9 : 1.55
                )

                Text(tab.localizedKey)
                    .font(PetWhiteStyle.labelFont(10.5, weight: selected ? .black : .bold))
                    .foregroundStyle(selected ? PetWhiteStyle.stroke : PetWhiteStyle.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(PetWhiteDockSelectionBackground(tint: tint, isSelected: selected, cornerRadius: 16))
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
    }

    private func liquidGlassTabButton(tab: LibraryViewModel.LibraryTab, index: Int) -> some View {
        let selected = tabIndex == index
        let tint = tint(for: tab)

        return Button {
            selectTab(tab, index: index)
        } label: {
            HStack(spacing: 6) {
                MonologueIcon(
                    icon: icon(for: tab),
                    size: 13,
                    color: selected ? tint : LiquidGlassStyle.inkSoft,
                    lineWidth: selected ? 1.8 : 1.45
                )

                Text(tab.localizedKey)
                    .font(LiquidGlassStyle.labelFont(11.5, weight: selected ? .semibold : .medium))
                    .foregroundStyle(selected ? LiquidGlassStyle.ink : LiquidGlassStyle.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(
                LiquidGlassSurfaceBackground(
                    cornerRadius: 17,
                    elevated: selected,
                    pressed: !selected,
                    fill: selected ? tint.opacity(0.16) : nil,
                    role: selected ? .selected : .list
                )
            )
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
    }

    private var neumorphicTabDeck: some View {
        HStack(spacing: 8) {
            ForEach(Array(tabs.enumerated()), id: \.element) { index, tab in
                neumorphicTabButton(tab: tab, index: index)
            }
        }
        .padding(6)
        .background(NeumorphicSurfaceBackground(cornerRadius: 24, elevated: true, lightweight: true))
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: tabIndex)
    }

    private func neumorphicTabButton(tab: LibraryViewModel.LibraryTab, index: Int) -> some View {
        let selected = tabIndex == index
        let tint = tint(for: tab)

        return Button {
            selectTab(tab, index: index)
        } label: {
            VStack(spacing: 5) {
                MonologueIcon(
                    icon: icon(for: tab),
                    size: 15,
                    color: selected ? tint : NeumorphicStyle.inkSoft,
                    lineWidth: selected ? 1.9 : 1.55
                )

                Text(tab.localizedKey)
                    .font(NeumorphicStyle.labelFont(10, weight: selected ? .semibold : .medium))
                    .foregroundStyle(selected ? NeumorphicStyle.ink : NeumorphicStyle.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                NeumorphicSurfaceBackground(
                    cornerRadius: 17,
                    elevated: selected,
                    pressed: !selected,
                    tint: selected ? tint.opacity(0.17) : NeumorphicStyle.surface,
                    lightweight: true
                )
            )
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
    }

    private var signalTabDeck: some View {
        HStack(spacing: 7) {
            ForEach(Array(tabs.enumerated()), id: \.element) { index, tab in
                signalTabButton(tab: tab, index: index)
            }
        }
        .padding(5)
        .background(SignalSurfaceBackground(cornerRadius: 22, elevated: true, fill: SignalStyle.device))
        .animation(.spring(response: 0.32, dampingFraction: 0.88), value: tabIndex)
    }

    private func signalTabButton(tab: LibraryViewModel.LibraryTab, index: Int) -> some View {
        let selected = tabIndex == index
        let tint = tint(for: tab)

        return Button {
            selectTab(tab, index: index)
        } label: {
            HStack(spacing: 6) {
                MonologueIcon(
                    icon: icon(for: tab),
                    size: 14,
                    color: selected ? tint : SignalStyle.inkSoft,
                    lineWidth: selected ? 1.9 : 1.55
                )

                Text(tab.localizedKey)
                    .font(SignalStyle.labelFont(11.5, weight: selected ? .bold : .semibold))
                    .foregroundStyle(selected ? SignalStyle.ink : SignalStyle.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(
                SignalSurfaceBackground(
                    cornerRadius: 16,
                    elevated: selected,
                    pressed: !selected,
                    fill: selected ? tint.opacity(0.16) : SignalStyle.control
                )
            )
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
    }

    private var sequoiaTabDeck: some View {
        HStack(spacing: 6) {
            ForEach(Array(tabs.enumerated()), id: \.element) { index, tab in
                sequoiaTabButton(tab: tab, index: index)
            }
        }
        .padding(5)
        .background(SequoiaSurfaceBackground(cornerRadius: 18, elevated: true, role: .chrome))
        .animation(.spring(response: 0.32, dampingFraction: 0.88), value: tabIndex)
    }

    private func sequoiaTabButton(tab: LibraryViewModel.LibraryTab, index: Int) -> some View {
        let selected = tabIndex == index
        let tint = tint(for: tab)

        return Button {
            selectTab(tab, index: index)
        } label: {
            HStack(spacing: 6) {
                MonologueIcon(
                    icon: icon(for: tab),
                    size: 13,
                    color: selected ? tint : SequoiaStyle.inkSoft,
                    lineWidth: selected ? 1.75 : 1.45
                )

                Text(tab.localizedKey)
                    .font(SequoiaStyle.labelFont(11.5, weight: selected ? .semibold : .medium))
                    .foregroundStyle(selected ? SequoiaStyle.ink : SequoiaStyle.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(SequoiaStyle.selectedWash)
                        .matchedGeometryEffect(id: "library-tab", in: sequoiaLibraryNamespace)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(tint.opacity(0.24), lineWidth: 0.55)
                        )
                }
            }
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .my:
            myLibraryPage
        case .square:
            playlistSquarePage
        case .artists:
            artistsPage
        case .charts:
            chartsPage
        }
    }

    private var myLibraryPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            myLibraryControlPanel
            myLibraryColumnContent
        }
    }

    @ViewBuilder
    private var myLibraryControlPanel: some View {
        if PetWhiteStyle.isActive {
            petWhiteLibraryControlPanel
        } else if CapsuleStyle.isActive {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "浏览分区"))
                            .font(CapsuleStyle.titleFont(16, weight: .bold))
                            .foregroundStyle(CapsuleStyle.ink)

                        Text(selectedMyLibraryColumn.title)
                            .font(CapsuleStyle.labelFont(11, weight: .semibold))
                            .foregroundStyle(tint(for: selectedMyLibraryColumn))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    Button {
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                            isLibraryActionsExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 7) {
                            MonologueIcon(
                                icon: isLibraryActionsExpanded ? .close : .more,
                                size: 13,
                                color: isLibraryActionsExpanded ? CapsuleStyle.readableLabel(on: defaultAccent) : CapsuleStyle.inkSoft,
                                lineWidth: 1.8
                            )
                            Text(String(localized: "工具"))
                                .font(CapsuleStyle.labelFont(11, weight: .bold))
                                .foregroundStyle(isLibraryActionsExpanded ? CapsuleStyle.readableLabel(on: defaultAccent) : CapsuleStyle.inkSoft)
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 36)
                        .background(
                            Capsule()
                                .fill(isLibraryActionsExpanded ? defaultAccent : CapsuleStyle.surfaceRaised.opacity(0.8))
                                .overlay(
                                    Capsule()
                                        .stroke(isLibraryActionsExpanded ? Color.white.opacity(0.35) : CapsuleStyle.separator.opacity(0.45), lineWidth: 0.8)
                                )
                        )
                    }
                    .buttonStyle(CapsulePressStyle())
                }

                columnStrip

                LibraryDisclosureReveal(isExpanded: isLibraryActionsExpanded) {
                    actionStrip
                        .padding(10)
                        .background(
                            CapsuleSurfaceBackground(
                                cornerRadius: 20,
                                elevated: false,
                                tint: CapsuleStyle.surfaceTint.opacity(0.82)
                            )
                        )
                }
            }
            .padding(13)
            .background(
                CapsuleSurfaceBackground(
                    cornerRadius: 26,
                    elevated: true,
                    tint: CapsuleStyle.surface.opacity(0.9)
                )
            )
            .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
        } else if NeumorphicStyle.isActive {
            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(String(localized: "浏览分区"))
                            .font(NeumorphicStyle.titleFont(16, weight: .semibold))
                            .foregroundStyle(NeumorphicStyle.ink)

                        Text(selectedMyLibraryColumn.title)
                            .font(NeumorphicStyle.labelFont(11, weight: .medium))
                            .foregroundStyle(tint(for: selectedMyLibraryColumn))
                    }

                    Spacer(minLength: 8)

                    Button {
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                            isLibraryActionsExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            MonologueIcon(icon: isLibraryActionsExpanded ? .close : .more, size: 14, color: isLibraryActionsExpanded ? defaultAccent : NeumorphicStyle.inkSoft, lineWidth: 1.7)
                            Text(String(localized: "工具"))
                                .font(NeumorphicStyle.labelFont(11, weight: .semibold))
                                .foregroundStyle(isLibraryActionsExpanded ? NeumorphicStyle.ink : NeumorphicStyle.inkSoft)
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 38)
                        .background(
                            NeumorphicSurfaceBackground(
                                cornerRadius: 15,
                                elevated: isLibraryActionsExpanded,
                                pressed: !isLibraryActionsExpanded,
                                tint: isLibraryActionsExpanded ? defaultAccent.opacity(0.15) : NeumorphicStyle.surface,
                                lightweight: true
                            )
                        )
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))
                }

                columnStrip

                LibraryDisclosureReveal(isExpanded: isLibraryActionsExpanded) {
                    actionStrip
                        .padding(10)
                        .background(
                            NeumorphicSurfaceBackground(
                                cornerRadius: 20,
                                elevated: false,
                                pressed: true,
                                lightweight: true
                            )
                        )
                }
            }
            .padding(13)
            .background(NeumorphicSurfaceBackground(cornerRadius: 24, elevated: true, lightweight: true))
            .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 10) {
                    columnStrip.layoutPriority(1)

                    Button {
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                            isLibraryActionsExpanded.toggle()
                        }
                    } label: {
                        MonologueIcon(icon: isLibraryActionsExpanded ? .close : .more, size: 16, color: isLibraryActionsExpanded ? selectedChipText : secondaryText, lineWidth: 1.8)
                            .frame(width: 42, height: 42)
                            .background(panelBackground(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(isLibraryActionsExpanded ? defaultAccent.opacity(0.14) : .clear)
                            )
                            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))
                }

                LibraryDisclosureReveal(isExpanded: isLibraryActionsExpanded) {
                    actionStrip
                        .padding(10)
                        .background(panelBackground(cornerRadius: 18))
                }
            }
            .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
        }
    }

    private var petWhiteLibraryControlPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                PetWhiteSectionTitle(
                    title: String(localized: "音乐库分区"),
                    detail: selectedMyLibraryColumn.title,
                    icon: selectedMyLibraryColumn.icon,
                    tint: tint(for: selectedMyLibraryColumn)
                )

                Spacer(minLength: 0)

                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                        isLibraryActionsExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        PetWhitePackIcon(
                            icon: isLibraryActionsExpanded ? .close : .more,
                            size: 14,
                            visualScale: 1.05,
                            fallbackColor: PetWhiteStyle.stroke,
                            lineWidth: 1.75
                        )
                        Text(String(localized: "工具"))
                            .font(PetWhiteStyle.labelFont(11, weight: .black))
                            .foregroundStyle(PetWhiteStyle.stroke)
                    }
                    .padding(.horizontal, 11)
                    .frame(height: 34)
                    .background(
                        PetWhiteSurfaceBackground(
                            cornerRadius: 14,
                            elevated: isLibraryActionsExpanded,
                            tint: isLibraryActionsExpanded ? tint(for: selectedMyLibraryColumn).opacity(0.22) : PetWhiteStyle.surfacePressed,
                            accent: tint(for: selectedMyLibraryColumn)
                        )
                    )
                }
                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.94))
            }

            columnStrip

            LibraryDisclosureReveal(isExpanded: isLibraryActionsExpanded) {
                actionStrip
                    .padding(10)
                    .background(
                        PetWhiteSurfaceBackground(
                            cornerRadius: 22,
                            elevated: false,
                            tint: PetWhiteStyle.surfacePressed,
                            accent: tint(for: selectedMyLibraryColumn)
                        )
                    )
            }
        }
        .padding(12)
        .background(
            PetWhiteSurfaceBackground(
                cornerRadius: 24,
                elevated: true,
                tint: PetWhiteStyle.surfaceRaised,
                accent: tint(for: selectedMyLibraryColumn)
            )
        )
        .padding(.horizontal, contentHorizontalPadding)
    }

    private var columnStrip: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(MyLibraryColumn.allCases, id: \.self) { column in
                    let selected = selectedMyLibraryColumn == column
                    Button {
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                            selectedMyLibraryColumn = column
                        }
                        if column == .qcmPlaylists {
                            loadQQUserPlaylistsIfNeeded()
                        }
                    } label: {
                        HStack(spacing: 7) {
                            if PetWhiteStyle.isActive {
                                PetWhitePackIcon(
                                    icon: column.icon,
                                    size: 15,
                                    visualScale: selected ? 1.08 : 1,
                                    fallbackColor: selected ? PetWhiteStyle.stroke : PetWhiteStyle.inkSoft,
                                    lineWidth: selected ? 1.9 : 1.55
                                )
                            } else {
                                MonologueIcon(icon: column.icon, size: 14, color: selected ? selectedChipText : secondaryText, lineWidth: selected ? 2 : 1.6)
                            }
                            Text(column.title)
                                .font(chipFont(selected: selected))
                                .foregroundColor(selected ? selectedChipText : secondaryText)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 12)
                        .frame(minHeight: 42)
                        .background(chipBackground(selected: selected, tint: tint(for: column), capsule: true))
                        .contentShape(Capsule())
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))
                }
            }
            .padding(.vertical, 1)
        }
        .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
    }

    @ViewBuilder
    private var myLibraryColumnContent: some View {
        switch selectedMyLibraryColumn {
        case .localPlaylists: localPlaylistsSection
        case .ncmPlaylists: ncmPlaylistsSection
        case .qcmPlaylists: qcmPlaylistsSection
        case .localPodcasts: localPodcastsSection
        case .ncmPodcasts: ncmPodcastsSection
        }
    }

    private var actionStrip: some View {
        LazyVGrid(columns: actionColumns, spacing: 9) {
            actionChip(title: String(localized: "lib_create"), icon: .add, tint: defaultAccent) {
                createLocalPlaylist()
            }

            actionChip(title: String(localized: "lib_import_playlist"), icon: .download, tint: secondaryAccent, isLoading: isImporting) {
                showFileImporter = true
            }
            .disabled(isImporting)

            actionChip(title: String(localized: "从链接导入"), icon: .share, tint: tertiaryAccent, isLoading: isImporting) {
                showImportLinkPrompt()
            }
            .disabled(isImporting)

            actionChip(title: String(localized: "QCM歌单"), icon: .musicNoteList, tint: MusicSource.qqmusic.themedBadgeColor) {
                showQQImport = true
            }
        }
    }

    private var localPlaylistsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ThemedLibrarySectionHeader(title: MyLibraryColumn.localPlaylists.title)

            if localManager.playlists.isEmpty {
                ThemedLibraryEmptyState(icon: .musicNoteList, title: String(localized: "lib_no_local_playlists"), tint: defaultAccent)
                    .padding(.horizontal, contentHorizontalPadding)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(localManager.playlists, id: \.id) { playlist in
                        NavigationLink(value: LibraryViewModel.NavigationDestination.localPlaylist(playlist.id)) {
                            LocalPlaylistRow(playlist: playlist)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, contentHorizontalPadding)
            }
        }
    }

    private var ncmPlaylistsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ThemedLibrarySectionHeader(title: MyLibraryColumn.ncmPlaylists.title)

            if viewModel.userPlaylists.isEmpty {
                ThemedLibraryEmptyState(icon: .list, title: String(localized: "empty_no_playlists"), tint: MusicSource.netease.themedBadgeColor)
                    .padding(.horizontal, contentHorizontalPadding)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.userPlaylists) { playlist in
                        NavigationLink(value: LibraryViewModel.NavigationDestination.playlist(playlist)) {
                            LibraryPlaylistRow(playlist: playlist)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, contentHorizontalPadding)
            }
        }
    }

    private var qcmPlaylistsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ThemedLibrarySectionHeader(title: MyLibraryColumn.qcmPlaylists.title)

            if isLoadingQQUserPlaylists && qqUserPlaylists.isEmpty {
                LibraryLoadingStateView()
            } else if !qqSession.isLoggedIn {
                ThemedLibraryEmptyState(icon: .musicNoteList, title: String(localized: "请先登录 QCM"), tint: MusicSource.qqmusic.themedBadgeColor)
                    .padding(.horizontal, contentHorizontalPadding)
            } else if qqUserPlaylists.isEmpty {
                ThemedLibraryEmptyState(icon: .list, title: String(localized: "暂无 QCM 歌单"), tint: MusicSource.qqmusic.themedBadgeColor)
                    .padding(.horizontal, contentHorizontalPadding)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(qqUserPlaylists) { playlist in
                        NavigationLink(value: LibraryViewModel.NavigationDestination.playlist(playlist)) {
                            LibraryPlaylistRow(playlist: playlist)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, contentHorizontalPadding)
            }
        }
    }

    private var localPodcastsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ThemedLibrarySectionHeader(title: MyLibraryColumn.localPodcasts.title)

            if subManager.localSubscribedRadios.isEmpty {
                ThemedLibraryEmptyState(icon: .radio, title: String(localized: "暂无本地收藏"), tint: tertiaryAccent)
                    .padding(.horizontal, contentHorizontalPadding)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(subManager.localSubscribedRadios) { radio in
                        NavigationLink(value: LibraryViewModel.NavigationDestination.radioDetail(radio.id)) {
                            ThemedLibraryPodcastRow(radio: radio, tint: tertiaryAccent)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, contentHorizontalPadding)
            }
        }
    }

    private var ncmPodcastsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ThemedLibrarySectionHeader(title: MyLibraryColumn.ncmPodcasts.title)

            if subManager.isLoadingRadios && subManager.subscribedRadios.isEmpty {
                LibraryLoadingStateView()
            } else if subManager.subscribedRadios.isEmpty {
                ThemedLibraryEmptyState(icon: .radio, title: String(localized: "lib_no_podcasts"), tint: secondaryAccent)
                    .padding(.horizontal, contentHorizontalPadding)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(subManager.subscribedRadios) { radio in
                        NavigationLink(value: LibraryViewModel.NavigationDestination.radioDetail(radio.id)) {
                            ThemedLibraryPodcastRow(radio: radio, tint: secondaryAccent)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, contentHorizontalPadding)
            }
        }
    }

    private var playlistSquarePage: some View {
        VStack(alignment: .leading, spacing: 14) {
            sourceStrip(selected: viewModel.squareSource) { source in
                viewModel.squareSource = source
                source == .qq ? viewModel.fetchQQSquareData() : viewModel.fetchSquareData()
            }
            .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)

            if viewModel.squareSource == .qq {
                qqCategoryBar
                playlistGrid(playlists: viewModel.qqSquarePlaylists, isLoading: viewModel.isLoadingQQSquare, emptyTitle: String(localized: "暂无QCM推荐歌单"))

                if viewModel.hasMoreQQSquare && !viewModel.qqSquarePlaylists.isEmpty {
                    loadMoreButton { viewModel.loadMoreQQSquarePlaylists() }
                }
            } else {
                ncmCategoryBar
                playlistGrid(playlists: viewModel.squarePlaylists, isLoading: viewModel.isLoadingSquare, emptyTitle: String(localized: "empty_no_playlists"))

                if viewModel.hasMoreSquarePlaylists && !viewModel.squarePlaylists.isEmpty {
                    loadMoreButton { viewModel.loadMoreSquarePlaylists() }
                }
            }
        }
    }

    private var artistsPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            sourceStrip(selected: viewModel.artistSource) { source in
                viewModel.artistSource = source
                source == .qq ? viewModel.fetchQQArtistData(reset: true) : viewModel.fetchArtistData(reset: true)
            }
            .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)

            if viewModel.artistSource == .qq {
                qqArtistFilterBars
                artistGrid(artists: viewModel.qqArtists, isLoading: viewModel.isLoadingQQArtists, tint: MusicSource.qqmusic.themedBadgeColor)
                if viewModel.hasMoreQQArtists && !viewModel.qqArtists.isEmpty {
                    loadMoreButton { viewModel.loadMoreQQArtists() }
                }
            } else {
                ncmArtistFilterBars
                artistGrid(artists: viewModel.topArtists, isLoading: viewModel.isLoadingArtists, tint: tertiaryAccent)
                if viewModel.hasMoreArtists && !viewModel.topArtists.isEmpty {
                    loadMoreButton { viewModel.loadMoreArtists() }
                }
            }
        }
    }

    private var chartsPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            if NeumorphicStyle.isActive {
                sourceStrip(selected: viewModel.chartsSource) { source in
                    viewModel.chartsSource = source
                    source == .qq ? viewModel.fetchQQTopLists() : viewModel.fetchTopLists()
                }
                .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
            }

            if NeumorphicStyle.isActive, viewModel.chartsSource == .qq {
                qqChartsContent
            } else {
                if viewModel.isLoadingCharts && viewModel.topLists.isEmpty {
                    LibraryLoadingStateView()
                } else if viewModel.topLists.isEmpty {
                    ThemedLibraryEmptyState(icon: .chart, title: String(localized: "empty_no_charts"), tint: secondaryAccent)
                        .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
                } else {
                    let officialIds: Set<Int> = [19_723_756, 3_779_629, 2_884_035, 3_778_678]
                    let official = viewModel.topLists.filter { officialIds.contains($0.id) }
                    let others = viewModel.topLists.filter { !officialIds.contains($0.id) }

                    if !official.isEmpty {
                        ThemedLibrarySectionHeader(title: String(localized: "charts_official"))
                        ScrollView(.horizontal) {
                            HStack(spacing: 14) {
                                ForEach(official) { list in
                                    NavigationLink(value: chartDestination(list)) {
                                        OfficialChartCard(list: list)
                                    }
                                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))
                                }
                            }
                            .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
                        }
                        .scrollIndicators(.hidden)
                        .themeRenderScrollLayer()
                    }

                    if !others.isEmpty {
                        ThemedLibrarySectionHeader(title: String(localized: "charts_more"))
                        LazyVGrid(columns: artistColumns, spacing: 16) {
                            ForEach(others) { list in
                                NavigationLink(value: chartDestination(list)) {
                                    CompactChartCard(list: list)
                                }
                                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
                            }
                        }
                        .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
                    }
                }
            }
        }
    }

    private var qqChartsContent: some View {
        Group {
            if viewModel.isLoadingQQCharts && viewModel.qqTopLists.isEmpty {
                LibraryLoadingStateView()
            } else if viewModel.qqTopLists.isEmpty {
                ThemedLibraryEmptyState(icon: .chart, title: String(localized: "暂无QCM排行榜"), tint: MusicSource.qqmusic.themedBadgeColor)
                    .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
            } else {
                ForEach(viewModel.qqTopLists) { group in
                    ThemedLibrarySectionHeader(title: group.groupName)

                    if group.groupId == 0 || group.items.count <= 4 {
                        ScrollView(.horizontal) {
                            HStack(spacing: 14) {
                                ForEach(group.items) { item in
                                    NavigationLink(value: qqChartDestination(item)) {
                                        QQOfficialChartCard(item: item)
                                    }
                                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))
                                }
                            }
                            .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
                        }
                        .scrollIndicators(.hidden)
                        .themeRenderScrollLayer()
                    } else {
                        LazyVGrid(columns: artistColumns, spacing: 16) {
                            ForEach(group.items) { item in
                                NavigationLink(value: qqChartDestination(item)) {
                                    QQChartCard(item: item)
                                }
                                .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
                            }
                        }
                        .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
                    }
                }
            }
        }
    }

    private var ncmCategoryBar: some View {
        horizontalFilterBar {
            ForEach(viewModel.playlistCategories, id: \.idString) { category in
                filterChip(title: category.name, selected: viewModel.selectedCategory == category.name, tint: MusicSource.netease.themedBadgeColor) {
                    viewModel.selectedCategory = category.name
                    viewModel.loadSquarePlaylists(cat: category.name, reset: true)
                }
            }
        }
    }

    private var qqCategoryBar: some View {
        horizontalFilterBar {
            ForEach(filteredQQCategories, id: \.id) { category in
                filterChip(title: category.name, selected: viewModel.selectedQQCategoryId == category.id, tint: MusicSource.qqmusic.themedBadgeColor) {
                    viewModel.selectQQCategory(id: category.id, name: category.name)
                }
            }
        }
    }

    private var filteredQQCategories: [(id: Int, name: String)] {
        let hidden: Set<String> = [String(localized: "全部"), String(localized: "ai歌单"), String(localized: "私藏"), String(localized: "音乐人在听"), "chill vibes", String(localized: "ai 歌单")]
        return viewModel.qqPlaylistCategories.filter { !hidden.contains($0.name.lowercased()) }
    }

    private var ncmArtistFilterBars: some View {
        VStack(alignment: .leading, spacing: 10) {
            horizontalFilterBar {
                ForEach(viewModel.artistAreas, id: \.value) { area in
                    filterChip(title: NSLocalizedString(area.name, comment: ""), selected: viewModel.artistArea == area.value, tint: tertiaryAccent) {
                        viewModel.artistArea = area.value
                        viewModel.fetchArtistData(reset: true)
                    }
                }
            }
            horizontalFilterBar {
                ForEach(viewModel.artistTypes, id: \.value) { type in
                    filterChip(title: NSLocalizedString(type.name, comment: ""), selected: viewModel.artistType == type.value, tint: secondaryAccent) {
                        viewModel.artistType = type.value
                        viewModel.fetchArtistData(reset: true)
                    }
                }
            }
            horizontalFilterBar {
                ForEach(viewModel.artistInitials, id: \.self) { initial in
                    filterChip(title: initial == "-1" ? NSLocalizedString("search_hot", comment: "") : initial, selected: viewModel.artistInitial == initial, tint: defaultAccent) {
                        viewModel.artistInitial = initial
                        viewModel.fetchArtistData(reset: true)
                    }
                }
            }
        }
    }

    private var qqArtistFilterBars: some View {
        VStack(alignment: .leading, spacing: 10) {
            horizontalFilterBar {
                ForEach(viewModel.qqArtistAreas, id: \.value) { area in
                    filterChip(title: NSLocalizedString(area.name, comment: ""), selected: viewModel.qqArtistArea == area.value, tint: MusicSource.qqmusic.themedBadgeColor) {
                        viewModel.qqArtistArea = area.value
                        viewModel.fetchQQArtistData(reset: true)
                    }
                }
            }
            horizontalFilterBar {
                ForEach(viewModel.qqArtistSexes, id: \.value) { sex in
                    filterChip(title: NSLocalizedString(sex.name, comment: ""), selected: viewModel.qqArtistSex == sex.value, tint: defaultAccent) {
                        viewModel.qqArtistSex = sex.value
                        viewModel.fetchQQArtistData(reset: true)
                    }
                }
            }
            horizontalFilterBar {
                ForEach(viewModel.qqArtistGenres, id: \.value) { genre in
                    filterChip(title: NSLocalizedString(genre.name, comment: ""), selected: viewModel.qqArtistGenre == genre.value, tint: tertiaryAccent) {
                        viewModel.qqArtistGenre = genre.value
                        viewModel.fetchQQArtistData(reset: true)
                    }
                }
            }
        }
    }

    private func playlistGrid(playlists: [Playlist], isLoading: Bool, emptyTitle: String) -> some View {
        Group {
            if isLoading && playlists.isEmpty {
                LibraryLoadingStateView()
            } else if playlists.isEmpty {
                ThemedLibraryEmptyState(icon: .list, title: emptyTitle, tint: defaultAccent)
                    .padding(.horizontal, contentHorizontalPadding)
            } else {
                LazyVGrid(columns: twoColumns, spacing: 14) {
                    ForEach(playlists) { playlist in
                        NavigationLink(value: LibraryViewModel.NavigationDestination.playlist(playlist)) {
                            if NeumorphicStyle.isActive {
                                NeumorphicPlaylistPoster(
                                    playlist: playlist,
                                    tint: playlist.source == .qqmusic ? MusicSource.qqmusic.themedBadgeColor : MusicSource.netease.themedBadgeColor
                                )
                            } else if SequoiaStyle.isActive {
                                SequoiaLibraryPlaylistTile(
                                    playlist: playlist,
                                    tint: playlist.source == .qqmusic ? MusicSource.qqmusic.themedBadgeColor : MusicSource.netease.themedBadgeColor
                                )
                            } else if PetWhiteStyle.isActive {
                                PetWhiteLibraryPlaylistCard(
                                    playlist: playlist,
                                    tint: playlist.source == .qqmusic ? MusicSource.qqmusic.themedBadgeColor : PetWhiteStyle.mint
                                )
                            } else {
                                CinematicCard(playlist: playlist, height: 168)
                            }
                        }
                        .buttonStyle(CinematicPressStyle())
                    }
                }
                .padding(.horizontal, contentHorizontalPadding)
            }
        }
    }

    private func artistGrid(artists: [ArtistInfo], isLoading: Bool, tint: Color) -> some View {
        Group {
            if isLoading && artists.isEmpty {
                LibraryLoadingStateView()
            } else if artists.isEmpty {
                ThemedLibraryEmptyState(icon: .personEmpty, title: String(localized: "empty_no_artists"), tint: tint)
                    .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
            } else {
                LazyVGrid(columns: artistColumns, spacing: 18) {
                    ForEach(artists) { artist in
                        NavigationLink(value: LibraryViewModel.NavigationDestination.artistInfo(artist)) {
                            ThemedLibraryArtistCard(artist: artist, tint: tint)
                        }
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))
                    }
                }
                .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
            }
        }
    }

    private func sourceStrip(selected: LibraryViewModel.MusicSource, onSelect: @escaping (LibraryViewModel.MusicSource) -> Void) -> some View {
        HStack(spacing: 6) {
            ForEach(LibraryViewModel.MusicSource.allCases, id: \.self) { source in
                let isSelected = selected == source
                let tint = source == .ncm ? MusicSource.netease.themedBadgeColor : MusicSource.qqmusic.themedBadgeColor
                Button {
                    guard !isSelected else { return }
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                        onSelect(source)
                    }
                } label: {
                    if NeumorphicStyle.isActive {
                        HStack(spacing: 7) {
                            MonologueIcon(icon: source == .ncm ? .musicNoteList : .library, size: 13, color: isSelected ? tint : secondaryText, lineWidth: 1.65)
                            Text(source == .ncm ? "NCM" : "QCM")
                                .font(chipFont(selected: isSelected))
                                .foregroundColor(isSelected ? primaryText : secondaryText)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(chipBackground(selected: isSelected, tint: tint, capsule: false))
                    } else {
                        Text(source == .ncm ? "NCM" : "QCM")
                            .font(chipFont(selected: isSelected))
                            .foregroundColor(isSelected ? selectedChipText : secondaryText)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 9)
                            .background(chipBackground(selected: isSelected, tint: tint, capsule: false))
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .background(panelBackground(cornerRadius: 18))
    }

    private func horizontalFilterBar<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 9) {
                content()
            }
            .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
        }
        .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
    }

    private func filterChip(title: String, selected: Bool, tint: Color, action: @escaping () -> Void) -> some View {
        Button {
            guard !selected else { return }
            withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                action()
            }
        } label: {
            HStack(spacing: 7) {
                if NeumorphicStyle.isActive {
                    Circle()
                        .fill(selected ? tint : tint.opacity(0.42))
                        .frame(width: 6, height: 6)
                }

                Text(title)
                    .font(chipFont(selected: selected))
                    .foregroundColor(selected ? selectedChipText : secondaryText)
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(chipBackground(selected: selected, tint: tint, capsule: false))
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))
    }

    private func actionChip(title: String, icon: MonologueIcon.IconType, tint: Color, isLoading: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if isLoading {
                    ProgressView()
                        .tint(tint)
                        .scaleEffect(0.68)
                        .frame(width: 14, height: 14)
                } else if PetWhiteStyle.isActive {
                    PetWhitePackIcon(
                        icon: icon,
                        size: 15,
                        visualScale: 1.06,
                        fallbackColor: tint,
                        lineWidth: 1.7
                    )
                } else {
                    MonologueIcon(icon: icon, size: 14, color: tint, lineWidth: 1.7)
                }

                Text(title)
                    .font(chipFont(selected: true))
                    .foregroundColor(primaryText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 42)
            .background(chipBackground(selected: false, tint: tint, capsule: false))
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
    }

    private func loadMoreButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(LocalizedStringKey("查看更多"))
                .font(chipFont(selected: true))
                .foregroundColor(selectedChipText)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(chipBackground(selected: true, tint: defaultAccent, capsule: false))
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))
        .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
        .padding(.top, 4)
    }

    private func selectTab(_ tab: LibraryViewModel.LibraryTab, index: Int) {
        tabIndex = index
        viewModel.currentTab = tab
        load(tab)
    }

    private func syncTabFromViewModel() {
        if let index = tabs.firstIndex(of: viewModel.currentTab), index != tabIndex {
            tabIndex = index
        }
    }

    private func loadCurrentTab() {
        load(selectedTab)
    }

    private func load(_ tab: LibraryViewModel.LibraryTab) {
        switch tab {
        case .my:
            viewModel.fetchPlaylists()
            if selectedMyLibraryColumn == .qcmPlaylists {
                loadQQUserPlaylistsIfNeeded()
            }
            if subManager.subscribedRadios.isEmpty {
                subManager.fetchSubscribedRadios()
            }
        case .square:
            viewModel.squareSource == .qq ? viewModel.fetchQQSquareData() : viewModel.fetchSquareData()
        case .artists:
            viewModel.artistSource == .qq ? viewModel.fetchQQArtistData() : viewModel.fetchArtistData()
        case .charts:
            if NeumorphicStyle.isActive && viewModel.chartsSource == .qq {
                viewModel.fetchQQTopLists()
            } else {
                viewModel.fetchTopLists()
            }
        }
    }

    private func loadQQUserPlaylistsIfNeeded(force: Bool = false) {
        guard force || !hasLoadedQQUserPlaylists else { return }
        guard !isLoadingQQUserPlaylists else { return }
        guard qqSession.isLoggedIn, let mid = qqSession.musicId else {
            qqUserPlaylists = []
            hasLoadedQQUserPlaylists = true
            return
        }

        isLoadingQQUserPlaylists = true
        Task { @MainActor in
            defer {
                isLoadingQQUserPlaylists = false
                hasLoadedQQUserPlaylists = true
            }

            do {
                let result: JSON = try await QQUserSession.shared.withUserSession { client in
                    try await client.createdSonglist(uin: String(mid))
                }
                qqUserPlaylists = Self.parseQQUserPlaylists(result)
            } catch {
                AppLogger.error("[Library] 加载 QCM 歌单失败: \(error)")
            }
        }
    }

    private static func parseQQUserPlaylists(_ result: JSON) -> [Playlist] {
        let list = result["v_playlist"]?.arrayValue ?? result.arrayValue ?? []
        return list.compactMap { json in
            guard let obj = json.objectValue else { return nil }
            let tid = obj["tid"]?.intValue ?? 0
            let name = obj["dirName"]?.stringValue ?? obj["diss_name"]?.stringValue ?? ""
            let cover = obj["picUrl"]?.stringValue ?? obj["logo"]?.stringValue ?? ""
            let songCount = obj["songNum"]?.intValue ?? obj["song_cnt"]?.intValue ?? 0
            guard !name.isEmpty else { return nil }
            return Playlist(
                id: tid,
                name: name,
                coverImgUrl: cover,
                picUrl: nil,
                trackCount: songCount,
                playCount: nil,
                subscribedCount: nil,
                shareCount: nil,
                commentCount: nil,
                creator: nil,
                description: nil,
                tags: nil,
                source: .qqmusic
            )
        }
    }

    private func createLocalPlaylist() {
        AlertManager.shared.showInput(
            title: String(localized: "lib_create_playlist"),
            message: "",
            placeholder: String(localized: "lib_playlist_name"),
            primaryButtonTitle: String(localized: "lib_create"),
            secondaryButtonTitle: String(localized: "alert_cancel"),
            onConfirm: { name in
                guard !name.isEmpty else { return }
                _ = localManager.createPlaylist(name: name)
            }
        )
    }

    private func showImportLinkPrompt() {
        AlertManager.shared.showInput(
            title: String(localized: "从链接导入歌单"),
            message: "",
            placeholder: String(localized: "粘贴歌单链接"),
            primaryButtonTitle: String(localized: "导入"),
            secondaryButtonTitle: String(localized: "取消"),
            onConfirm: { url in
                importPlaylistFromURL(url)
            }
        )
    }

    private func importPlaylistFromFile(url: URL) {
        isImporting = true
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        do {
            let parsed = try LocalPlaylistManager.parseExportFile(url: url)
            let ids = parsed.songIds
            let name = parsed.name
            guard !ids.isEmpty else {
                AlertManager.shared.show(
                    title: String(localized: "lib_import_failed"),
                    message: String(localized: "lib_import_no_songs"),
                    primaryButtonTitle: String(localized: "lib_confirm"),
                    primaryAction: {}
                )
                isImporting = false
                return
            }

            Task {
                var allSongs: [Song] = []
                for i in stride(from: 0, to: ids.count, by: 50) {
                    let batch = Array(ids[i ..< min(i + 50, ids.count)])
                    do {
                        let songs: [Song] = try await withCheckedThrowingContinuation { continuation in
                            var cancellable: AnyCancellable?
                            cancellable = APIService.shared.fetchSongDetails(ids: batch)
                                .sink(receiveCompletion: { completion in
                                    if case let .failure(error) = completion {
                                        continuation.resume(throwing: error)
                                    }
                                    cancellable?.cancel()
                                }, receiveValue: { songs in
                                    continuation.resume(returning: songs)
                                    cancellable?.cancel()
                                })
                        }
                        allSongs.append(contentsOf: songs)
                    } catch {
                        AppLogger.error("导入歌单批次获取失败: \(error)")
                    }
                }

                await MainActor.run {
                    if allSongs.isEmpty {
                        AlertManager.shared.show(
                            title: String(localized: "lib_import_failed"),
                            message: String(localized: "lib_import_fetch_failed"),
                            primaryButtonTitle: String(localized: "lib_confirm"),
                            primaryAction: {}
                        )
                    } else {
                        localManager.importPlaylist(name: name, songs: allSongs)
                    }
                    isImporting = false
                }
            }
        } catch {
            AlertManager.shared.show(
                title: String(localized: "lib_import_failed"),
                message: error.localizedDescription,
                primaryButtonTitle: String(localized: "lib_confirm"),
                primaryAction: {}
            )
            isImporting = false
        }
    }

    private func importPlaylistFromURL(_ urlString: String) {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isImporting = true

        if let qqId = extractQQPlaylistId(from: trimmed) {
            importQQPlaylist(id: qqId)
        } else if let ncmId = extractNCMPlaylistId(from: trimmed) {
            importNCMPlaylist(id: ncmId)
        } else {
            AlertManager.shared.show(
                title: String(localized: "lib_import_failed"),
                message: String(localized: "无法识别的歌单链接"),
                primaryButtonTitle: String(localized: "lib_confirm"),
                primaryAction: {}
            )
            isImporting = false
        }
    }

    private func extractQQPlaylistId(from url: String) -> Int? {
        if let range = url.range(of: #"playlist/(\d+)"#, options: .regularExpression) {
            return Int(url[range].replacingOccurrences(of: "playlist/", with: ""))
        }
        if let range = url.range(of: #"id=(\d+)"#, options: .regularExpression), url.contains("y.qq.com") {
            return Int(String(url[range]).replacingOccurrences(of: "id=", with: ""))
        }
        return nil
    }

    private func extractNCMPlaylistId(from url: String) -> Int? {
        if let range = url.range(of: #"playlist\?id=(\d+)"#, options: .regularExpression) {
            return Int(String(url[range]).replacingOccurrences(of: "playlist?id=", with: ""))
        }
        if let range = url.range(of: #"id=(\d+)"#, options: .regularExpression), url.contains("music.163.com") {
            return Int(String(url[range]).replacingOccurrences(of: "id=", with: ""))
        }
        return nil
    }

    private func importQQPlaylist(id: Int) {
        Task {
            do {
                let detail = try await APIService.shared.qqClient.songlistDetail(songlistId: id, num: 1, page: 1)
                let name = detail["dirinfo"]?["title"]?.stringValue ?? String(localized: "QCM歌单")
                var allSongs: [Song] = []
                var page = 1
                var hasMore = true

                while hasMore {
                    let songs: [Song] = try await withCheckedThrowingContinuation { continuation in
                        var resumed = false
                        var cancellable: AnyCancellable?
                        cancellable = APIService.shared.fetchQQPlaylistSongs(playlistId: id, page: page, num: 50)
                            .sink(receiveCompletion: { completion in
                                if case let .failure(error) = completion, !resumed {
                                    resumed = true
                                    continuation.resume(throwing: error)
                                }
                                cancellable?.cancel()
                            }, receiveValue: { songs in
                                guard !resumed else { return }
                                resumed = true
                                continuation.resume(returning: songs)
                                cancellable?.cancel()
                            })
                    }
                    allSongs.append(contentsOf: songs)
                    hasMore = songs.count >= 50
                    page += 1
                }

                await MainActor.run {
                    if allSongs.isEmpty {
                        AlertManager.shared.show(
                            title: String(localized: "lib_import_failed"),
                            message: String(localized: "歌单为空或获取失败"),
                            primaryButtonTitle: String(localized: "lib_confirm"),
                            primaryAction: {}
                        )
                    } else {
                        localManager.importPlaylist(name: name, songs: allSongs)
                    }
                    isImporting = false
                }
            } catch {
                await MainActor.run {
                    AlertManager.shared.show(
                        title: String(localized: "lib_import_failed"),
                        message: String(localized: "QCM歌单导入失败: \(error.localizedDescription)"),
                        primaryButtonTitle: String(localized: "lib_confirm"),
                        primaryAction: {}
                    )
                    isImporting = false
                }
            }
        }
    }

    private func importNCMPlaylist(id: Int) {
        Task {
            var allSongs: [Song] = []
            var offset = 0
            let limit = 50
            var hasMore = true

            while hasMore {
                do {
                    let songs: [Song] = try await withCheckedThrowingContinuation { continuation in
                        var resumed = false
                        var cancellable: AnyCancellable?
                        cancellable = APIService.shared.fetchPlaylistTracks(id: id, limit: limit, offset: offset)
                            .sink(receiveCompletion: { completion in
                                if case let .failure(error) = completion, !resumed {
                                    resumed = true
                                    continuation.resume(throwing: error)
                                }
                                cancellable?.cancel()
                            }, receiveValue: { songs in
                                guard !resumed else { return }
                                resumed = true
                                continuation.resume(returning: songs)
                                cancellable?.cancel()
                            })
                    }
                    allSongs.append(contentsOf: songs)
                    hasMore = songs.count >= limit
                    offset += limit
                } catch {
                    hasMore = false
                }
            }

            await MainActor.run {
                if allSongs.isEmpty {
                    AlertManager.shared.show(
                        title: String(localized: "lib_import_failed"),
                        message: String(localized: "歌单为空或获取失败"),
                        primaryButtonTitle: String(localized: "lib_confirm"),
                        primaryAction: {}
                    )
                } else {
                    localManager.importPlaylist(name: String(localized: "NCM歌单"), songs: allSongs)
                }
                isImporting = false
            }
        }
    }

    private func chartDestination(_ list: TopList) -> LibraryViewModel.NavigationDestination {
        .playlist(Playlist(
            id: list.id,
            name: list.name,
            coverImgUrl: list.coverImgUrl,
            picUrl: nil,
            trackCount: nil,
            playCount: nil,
            subscribedCount: nil,
            shareCount: nil,
            commentCount: nil,
            creator: nil,
            description: nil,
            tags: nil,
            isTopList: true
        ))
    }

    private func qqChartDestination(_ item: QQTopListItem) -> LibraryViewModel.NavigationDestination {
        .playlist(Playlist(
            id: item.topId,
            name: item.title,
            coverImgUrl: item.coverUrl,
            picUrl: nil,
            trackCount: nil,
            playCount: nil,
            subscribedCount: nil,
            shareCount: nil,
            commentCount: nil,
            creator: nil,
            description: item.intro.isEmpty ? nil : item.intro,
            tags: nil,
            source: .qqmusic,
            isTopList: true
        ))
    }

    private func icon(for tab: LibraryViewModel.LibraryTab) -> MonologueIcon.IconType {
        switch tab {
        case .my: return PetWhiteStyle.isActive ? .library : .libraryFilled
        case .square: return .gridSquare
        case .artists: return .personCircle
        case .charts: return .chart
        }
    }

    private func tint(for tab: LibraryViewModel.LibraryTab) -> Color {
        switch tab {
        case .my: return defaultAccent
        case .square: return secondaryAccent
        case .artists: return tertiaryAccent
        case .charts: return quaternaryAccent
        }
    }

    private func tint(for column: MyLibraryColumn) -> Color {
        switch column {
        case .localPlaylists: return defaultAccent
        case .ncmPlaylists: return MusicSource.netease.themedBadgeColor
        case .qcmPlaylists: return MusicSource.qqmusic.themedBadgeColor
        case .localPodcasts: return tertiaryAccent
        case .ncmPodcasts: return secondaryAccent
        }
    }

    private var primaryText: Color {
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.ink }
        if PetWhiteStyle.isActive { return PetWhiteStyle.ink }
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        if SignalStyle.isActive { return SignalStyle.ink }
        if MujiStyle.isActive { return MujiStyle.ink }
        if SequoiaStyle.isActive { return SequoiaStyle.ink }
        if CapsuleStyle.isActive { return CapsuleStyle.ink }
        return .monologueTextPrimary
    }

    private var secondaryText: Color {
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.inkSoft }
        if PetWhiteStyle.isActive { return PetWhiteStyle.inkSoft }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkMuted }
        if SignalStyle.isActive { return SignalStyle.inkSoft }
        if MujiStyle.isActive { return MujiStyle.inkSoft }
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        if CapsuleStyle.isActive { return CapsuleStyle.inkSoft }
        return .monologueTextSecondary
    }

    private var defaultAccent: Color {
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.accent }
        if PetWhiteStyle.isActive { return PetWhiteStyle.dogOrange }
        if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
        if SignalStyle.isActive { return SignalStyle.accent }
        if MujiStyle.isActive { return MujiStyle.tea }
        if SequoiaStyle.isActive { return SequoiaStyle.accent }
        if CapsuleStyle.isActive { return CapsuleStyle.accent }
        return .monologueAccent
    }

    private var secondaryAccent: Color {
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.cyan }
        if PetWhiteStyle.isActive { return PetWhiteStyle.mint }
        if NeumorphicStyle.isActive { return NeumorphicStyle.sage }
        if SignalStyle.isActive { return SignalStyle.olive }
        if MujiStyle.isActive { return MujiStyle.clay }
        if SequoiaStyle.isActive { return SequoiaStyle.aqua }
        if CapsuleStyle.isActive { return CapsuleStyle.cyan }
        return .monologueAccentBlue
    }

    private var tertiaryAccent: Color {
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.mint }
        if PetWhiteStyle.isActive { return PetWhiteStyle.sky }
        if NeumorphicStyle.isActive { return NeumorphicStyle.warm }
        if SignalStyle.isActive { return SignalStyle.rust }
        if MujiStyle.isActive { return MujiStyle.indigo }
        if SequoiaStyle.isActive { return SequoiaStyle.green }
        if CapsuleStyle.isActive { return CapsuleStyle.mint }
        return .monologueAccentGreen
    }

    private var quaternaryAccent: Color {
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.violet }
        if PetWhiteStyle.isActive { return PetWhiteStyle.butter }
        if NeumorphicStyle.isActive { return NeumorphicStyle.red }
        if SignalStyle.isActive { return SignalStyle.red }
        if MujiStyle.isActive { return MujiStyle.red }
        if SequoiaStyle.isActive { return SequoiaStyle.violet }
        if CapsuleStyle.isActive { return CapsuleStyle.violet }
        return .monologueAccentRed
    }

    private var selectedChipText: Color {
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.ink }
        if PetWhiteStyle.isActive { return PetWhiteStyle.stroke }
        if CapsuleStyle.isActive { return CapsuleStyle.onAccent }
        return MujiStyle.isActive ? MujiStyle.onTint : (NeumorphicStyle.isActive ? NeumorphicStyle.ink : (SignalStyle.isActive ? SignalStyle.ink : (SequoiaStyle.isActive ? SequoiaStyle.ink : .monologueIconForeground)))
    }

    private var tabCornerRadius: CGFloat {
        if LiquidGlassStyle.isActive { return 17 }
        if PetWhiteStyle.isActive { return 16 }
        return NeumorphicStyle.isActive ? 15 : (SignalStyle.isActive ? 16 : (MujiStyle.isActive ? 8 : (SequoiaStyle.isActive ? 14 : 14)))
    }

    private func tabFont(selected: Bool) -> Font {
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.labelFont(12, weight: selected ? .semibold : .medium) }
        if PetWhiteStyle.isActive { return PetWhiteStyle.labelFont(12, weight: selected ? .black : .bold) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(12, weight: selected ? .semibold : .medium) }
        if SignalStyle.isActive { return SignalStyle.labelFont(12, weight: selected ? .bold : .semibold) }
        if MujiStyle.isActive { return MujiStyle.labelFont(12, weight: selected ? .semibold : .regular) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(12, weight: selected ? .semibold : .medium) }
        if CapsuleStyle.isActive { return CapsuleStyle.labelFont(12, weight: selected ? .bold : .semibold) }
        return .system(size: 13, weight: selected ? .bold : .medium, design: .rounded)
    }

    private func chipFont(selected: Bool) -> Font {
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.labelFont(12, weight: selected ? .semibold : .medium) }
        if PetWhiteStyle.isActive { return PetWhiteStyle.labelFont(12, weight: selected ? .black : .bold) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(12, weight: selected ? .semibold : .medium) }
        if SignalStyle.isActive { return SignalStyle.labelFont(12, weight: selected ? .bold : .semibold) }
        if MujiStyle.isActive { return MujiStyle.labelFont(12, weight: selected ? .semibold : .regular) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(12, weight: selected ? .semibold : .medium) }
        if CapsuleStyle.isActive { return CapsuleStyle.labelFont(12, weight: selected ? .bold : .semibold) }
        return .system(size: 13, weight: selected ? .semibold : .medium, design: .rounded)
    }

    private func tabForeground(selected: Bool) -> Color {
        selected ? selectedChipText : secondaryText
    }

    private func tabBackground(selected: Bool, tint: Color) -> some View {
        Group {
            if LiquidGlassStyle.isActive {
                LiquidGlassSurfaceBackground(cornerRadius: tabCornerRadius, elevated: selected, pressed: !selected, fill: selected ? tint.opacity(0.16) : nil, role: selected ? .selected : .list)
            } else if PetWhiteStyle.isActive {
                PetWhiteDockSelectionBackground(tint: tint, isSelected: selected, cornerRadius: tabCornerRadius)
            } else if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(cornerRadius: tabCornerRadius, elevated: selected, pressed: !selected, tint: selected ? tint.opacity(0.15) : NeumorphicStyle.surface, lightweight: true)
            } else if SignalStyle.isActive {
                SignalSurfaceBackground(cornerRadius: tabCornerRadius, elevated: selected, pressed: !selected, fill: selected ? tint.opacity(0.16) : SignalStyle.control)
            } else if SequoiaStyle.isActive {
                SequoiaSurfaceBackground(cornerRadius: tabCornerRadius, elevated: selected, pressed: !selected, fill: selected ? SequoiaStyle.selectedWash : SequoiaStyle.materialList, role: selected ? .selected : .list)
            } else if MujiStyle.isActive {
                RoundedRectangle(cornerRadius: tabCornerRadius, style: .continuous)
                    .fill(selected ? MujiStyle.ink : MujiStyle.surface.opacity(0.78))
                    .overlay(RoundedRectangle(cornerRadius: tabCornerRadius, style: .continuous).stroke(selected ? Color.clear : MujiStyle.hairline.opacity(0.45), lineWidth: 0.6))
            } else {
                RoundedRectangle(cornerRadius: tabCornerRadius, style: .continuous)
                    .fill(selected ? Color.monologueIconBackground : Color.monologueGlassTint)
            }
        }
    }

    private func chipBackground(selected: Bool, tint: Color, capsule: Bool) -> some View {
        Group {
            if LiquidGlassStyle.isActive {
                LiquidGlassSurfaceBackground(cornerRadius: capsule ? 18 : 15, elevated: selected, pressed: !selected, fill: selected ? tint.opacity(0.15) : nil, role: selected ? .selected : .list)
            } else if PetWhiteStyle.isActive {
                PetWhiteSurfaceBackground(cornerRadius: capsule ? 18 : 15, elevated: selected, tint: selected ? tint.opacity(0.86) : PetWhiteStyle.surfaceRaised, accent: tint)
            } else if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(cornerRadius: capsule ? 18 : 15, elevated: selected, pressed: !selected, tint: selected ? tint.opacity(0.16) : NeumorphicStyle.surface, lightweight: true)
            } else if SignalStyle.isActive {
                SignalSurfaceBackground(cornerRadius: capsule ? 12 : 10, elevated: selected, pressed: !selected, fill: selected ? tint.opacity(0.18) : SignalStyle.control)
            } else if SequoiaStyle.isActive {
                SequoiaSurfaceBackground(cornerRadius: capsule ? 18 : 13, elevated: selected, pressed: !selected, fill: selected ? tint.opacity(0.13) : SequoiaStyle.materialList, role: selected ? .selected : .list)
            } else if CapsuleStyle.isActive {
                let radius: CGFloat = capsule ? 18 : 15
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(selected ? tint : CapsuleStyle.surfaceRaised.opacity(0.72))
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .stroke(selected ? Color.white.opacity(0.32) : CapsuleStyle.separator.opacity(0.46), lineWidth: 0.7)
                    )
            } else if MujiStyle.isActive {
                let shape = RoundedRectangle(cornerRadius: capsule ? 18 : 8, style: .continuous)
                shape
                    .fill(selected ? MujiStyle.ink : MujiStyle.surface.opacity(0.78))
                    .overlay(shape.stroke(selected ? Color.clear : MujiStyle.hairline.opacity(0.5), lineWidth: 0.6))
            } else if capsule {
                Capsule().fill(selected ? Color.monologueIconBackground : Color.monologueGlassTint)
            } else {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(selected ? Color.monologueIconBackground : Color.monologueGlassTint)
            }
        }
    }

    private func panelBackground(cornerRadius: CGFloat) -> some View {
        Group {
            if LiquidGlassStyle.isActive {
                LiquidGlassSurfaceBackground(cornerRadius: min(cornerRadius, 24), elevated: true, role: .chrome)
            } else if PetWhiteStyle.isActive {
                PetWhiteSurfaceBackground(cornerRadius: min(max(cornerRadius, 16), 24), elevated: true, tint: PetWhiteStyle.surfaceRaised, accent: activeTabTint)
            } else if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(cornerRadius: cornerRadius, elevated: true, lightweight: true)
            } else if SignalStyle.isActive {
                SignalSurfaceBackground(cornerRadius: min(cornerRadius, 18), elevated: true, fill: SignalStyle.device)
            } else if SequoiaStyle.isActive {
                SequoiaSurfaceBackground(cornerRadius: min(cornerRadius, 20), elevated: true, role: .chrome)
            } else if CapsuleStyle.isActive {
                CapsuleSurfaceBackground(
                    cornerRadius: min(max(cornerRadius, 16), 26),
                    elevated: true,
                    tint: CapsuleStyle.surface.opacity(0.9)
                )
            } else if MujiStyle.isActive {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(MujiStyle.surface.opacity(0.82))
                    .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).stroke(MujiStyle.hairline.opacity(0.44), lineWidth: 0.6))
            } else {
                Color.clear.monologueGlass(cornerRadius: cornerRadius)
            }
        }
    }
}

private struct PetWhiteLibraryStatusPill: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(PetWhiteStyle.titleFont(15, weight: .black))
                .foregroundStyle(PetWhiteStyle.ink)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title)
                .font(PetWhiteStyle.labelFont(9.5, weight: .bold))
                .foregroundStyle(PetWhiteStyle.inkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
        }
        .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            PetWhiteSurfaceBackground(
                cornerRadius: 17,
                elevated: false,
                tint: PetWhiteStyle.surfaceRaised,
                accent: tint
            )
        )
    }
}

private struct PetWhiteLibraryPlaylistCard: View {
    let playlist: Playlist
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                CachedAsyncImage(url: playlist.coverUrl?.sized(600)) {
                    PetWhiteStyle.surfacePressed
                        .overlay(
                            PetWhitePetPetIcon(size: 54)
                                .opacity(0.88)
                        )
                }
                .aspectRatio(1, contentMode: .fill)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(PetWhiteStyle.stroke, lineWidth: 1.4)
                )

                PetWhitePackIcon(icon: .play, size: 15, visualScale: 1.08)
                    .frame(width: 34, height: 34)
                    .background(tint, in: Circle())
                    .overlay(Circle().stroke(PetWhiteStyle.stroke, lineWidth: 1.2))
                    .padding(8)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(PetWhiteStyle.bodyFont(13, weight: .black))
                    .foregroundStyle(PetWhiteStyle.ink)
                    .lineLimit(2)
                    .frame(minHeight: 36, alignment: .topLeading)

                HStack(spacing: 6) {
                    Capsule()
                        .fill(tint)
                        .frame(width: 22, height: 5)
                    Text(metaText)
                        .font(PetWhiteStyle.labelFont(10, weight: .bold))
                        .foregroundStyle(PetWhiteStyle.inkSoft)
                        .lineLimit(1)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            PetWhiteSurfaceBackground(
                cornerRadius: 24,
                elevated: true,
                tint: PetWhiteStyle.surfaceRaised,
                accent: tint
            )
        )
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var metaText: String {
        if let playCount = playlist.playCount, playCount > 0 {
            return cinematicFormatCount(playCount)
        }
        if let trackCount = playlist.trackCount, trackCount > 0 {
            return String(format: String(localized: "songs_count_format"), trackCount)
        }
        return playlist.source == .qqmusic ? "QCM" : "NCM"
    }
}

private struct LiquidGlassRefractionHeaderShape: InsettableShape {
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let rect = rect.insetBy(dx: insetAmount, dy: insetAmount)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.16, y: rect.minY + rect.height * 0.03))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.14, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.32),
            control: CGPoint(x: rect.maxX + rect.width * 0.02, y: rect.minY + rect.height * 0.08)
        )
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.05, y: rect.maxY - rect.height * 0.17))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - rect.width * 0.22, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY + rect.height * 0.02)
        )
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.maxY - rect.height * 0.02))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - rect.height * 0.28),
            control: CGPoint(x: rect.minX - rect.width * 0.02, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.02, y: rect.minY + rect.height * 0.24))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.16, y: rect.minY + rect.height * 0.03),
            control: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.08)
        )
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> LiquidGlassRefractionHeaderShape {
        var shape = self
        shape.insetAmount += amount
        return shape
    }
}
