import SwiftUI

// MARK: - View

struct DailyRecommendView: View {
    @StateObject private var viewModel = DailyRecommendViewModel()
    @ObservedObject private var styleManager = StyleManager.shared
    @ObservedObject private var settings = SettingsManager.shared
    @State private var selectedArtistId: Int?
    @State private var showArtistDetail = false
    @State private var selectedSongForDetail: Song?
    @State private var showSongDetail = false
    @State private var selectedAlbumId: Int?
    @State private var showAlbumDetail = false
    @State private var isSelectMode = false
    @State private var selectedSongIds: Set<Int> = []
    @State private var showBatchAddToPlaylist = false
    @State private var searchText = ""
    @State private var isSearching = false

    typealias Theme = PlaylistDetailView.Theme

    var body: some View {
        let _ = settings.globalThemeRevision

        ZStack(alignment: .top) {
            if MangaStyle.isActive {
                MangaRootBackdrop()
            } else if PetWhiteStyle.isActive {
                PetWhiteRootBackdrop()
            } else if MujiStyle.isActive {
                MujiRootBackdrop()
            } else if NeumorphicStyle.isActive {
                ThemeRenderBackdrop(theme: .neumorphic)
            } else if SignalStyle.isActive {
                ThemeRenderBackdrop(theme: .signal)
            } else if BentoStyle.isActive {
                BentoRootBackdrop()
            } else {
                ThemedPageBackground()
            }

            mainContent
        }
        .monologueSheet(isPresented: $viewModel.showHistorySheet, preset: .standard) {
            DailyHistoryView(dates: viewModel.historyDates)
        }
        .onChange(of: viewModel.noHistoryMessage) { _, newValue in
            if let message = newValue {
                AlertManager.shared.show(
                    title: NSLocalizedString("daily_history_title", comment: ""),
                    message: message,
                    primaryButtonTitle: NSLocalizedString("daily_no_history", comment: ""),
                    primaryAction: {
                        viewModel.noHistoryMessage = nil
                    }
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showArtistDetail) {
            if let artistId = selectedArtistId {
                ArtistDetailView(artistId: artistId)

            }
        }
        .navigationDestination(isPresented: $showSongDetail) {
            if let song = selectedSongForDetail {
                SongDetailView(song: song)

            }
        }
        .navigationDestination(isPresented: $showAlbumDetail) {
            if let albumId = selectedAlbumId {
                AlbumDetailView(albumId: albumId, albumName: nil, albumCoverUrl: nil)

            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        if viewModel.isLoading && viewModel.songs.isEmpty {
            scrollableDailyShell {
                headerSection
                MonologueLoadingView(text: "LOADING...")
                    .frame(maxWidth: .infinity)
                    .padding(.top, 72)
            }
        } else if let error = viewModel.errorMessage {
            scrollableDailyShell {
                headerSection
                errorView(msg: error)
            }
        } else {
            songList
        }
    }

    private func scrollableDailyShell<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                content()
            }
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
    }

    // MARK: - Subviews

    @ViewBuilder
    private var headerSection: some View {
        if MangaStyle.isActive {
            mangaHeaderSection
        } else if PetWhiteStyle.isActive {
            petWhiteHeaderSection
        } else if NeumorphicStyle.isActive {
            neumorphicHeaderSection
        } else if SignalStyle.isActive {
            signalHeaderSection
        } else if MujiStyle.isActive {
            mujiHeaderSection
        } else if SequoiaStyle.isActive {
            sequoiaHeaderSection
        } else if CapsuleStyle.isActive {
            capsuleHeaderSection
        } else if BentoStyle.isActive {
            bentoHeaderSection
        } else {
            defaultHeaderSection
        }
    }

    private var petWhiteHeaderSection: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        PetWhiteSurfaceBackground(cornerRadius: 24, elevated: true, tint: PetWhiteStyle.surfaceRaised, accent: PetWhiteStyle.butter)
                        VStack(spacing: 0) {
                            Text(dayString)
                                .font(PetWhiteStyle.titleFont(36, weight: .black))
                                .foregroundStyle(PetWhiteStyle.ink)
                            Text("/ \(monthString)")
                                .font(PetWhiteStyle.labelFont(12, weight: .black))
                                .foregroundStyle(PetWhiteStyle.inkSoft)
                        }
                    }
                    .frame(width: 84, height: 84)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 7) {
                            PetWhitePill(text: String(localized: "daily_recommend"), tint: PetWhiteStyle.mint)
                            if !viewModel.songs.isEmpty {
                                PetWhitePill(text: "\(viewModel.songs.count) \(String(localized: "songs_unit"))", tint: PetWhiteStyle.butter)
                            }
                        }

                        Text(dailyHeaderTitle)
                            .font(PetWhiteStyle.titleFont(24, weight: .black))
                            .foregroundStyle(PetWhiteStyle.ink)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 8) {
                            Button(action: toggleStyleMenu) {
                                petWhiteDailyChip(text: dailyStyleChipTitle, icon: .sparkle, tint: PetWhiteStyle.sky)
                            }
                            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))

                            Button(action: { viewModel.loadHistoryDates() }) {
                                petWhiteDailyChip(text: NSLocalizedString("daily_history", comment: ""), icon: .history, tint: PetWhiteStyle.mint)
                            }
                            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))
                        }
                    }

                    Spacer(minLength: 8)
                }

                if !viewModel.songs.isEmpty {
                    Button(action: {
                        if let first = viewModel.songs.first {
                            PlayerManager.shared.playReplacingContext(song: first, in: viewModel.songs)
                        }
                    }) {
                        petWhiteDailyChip(text: String(localized: "artist_play_all"), icon: .play, tint: PetWhiteStyle.dogOrange, filled: true)
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
                }
            }
            .padding(16)
            .background(PetWhiteSurfaceBackground(cornerRadius: 28, elevated: true, tint: PetWhiteStyle.surfaceRaised, accent: PetWhiteStyle.mint))
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.top, 16)
            .padding(.bottom, viewModel.showStyleMenu ? 8 : 10)

            attachedStylePanel
        }
    }

    private func petWhiteDailyChip(text: String, icon: MonologueIcon.IconType, tint: Color, filled: Bool = false) -> some View {
        HStack(spacing: 6) {
            PetWhitePackIcon(icon: icon, size: 13, visualScale: 1.06, fallbackColor: filled ? PetWhiteStyle.onAccent : PetWhiteStyle.stroke)
            Text(text)
                .font(PetWhiteStyle.labelFont(12, weight: .black))
                .lineLimit(1)
        }
        .foregroundStyle(filled ? PetWhiteStyle.onAccent : PetWhiteStyle.stroke)
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(filled ? tint : PetWhiteStyle.surfaceRaised, in: Capsule())
        .overlay(Capsule().stroke(PetWhiteStyle.stroke, lineWidth: PetWhiteStyle.fineStrokeWidth))
    }

    private var bentoHeaderSection: some View {
        VStack(spacing: 0) {
            BentoBlock(fill: BentoStyle.surfaceRaised, radius: BentoStyle.blockRadiusLarge, padding: 16, stroked: true) {
                HStack(alignment: .center, spacing: 14) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text(dayString)
                                .font(BentoStyle.displayFont(46, weight: .black))
                                .foregroundStyle(BentoStyle.ink)
                            Text("/ \(monthString)")
                                .font(BentoStyle.titleFont(16, weight: .heavy))
                                .foregroundStyle(BentoStyle.inkSoft)
                                .padding(.bottom, 8)
                        }
                        BentoTag(text: String(localized: "daily_recommend"), color: BentoStyle.tomato)
                    }
                    .frame(width: 104, alignment: .leading)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(dailyHeaderTitle)
                            .font(BentoStyle.titleFont(24, weight: .black))
                            .foregroundStyle(BentoStyle.ink)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 8) {
                            Button(action: toggleStyleMenu) {
                                bentoDailyChip(
                                    text: dailyStyleChipTitle,
                                    icon: .sparkle,
                                    tint: viewModel.showStyleMenu ? BentoStyle.tomato : BentoStyle.nori
                                )
                            }
                            .buttonStyle(BentoPressStyle())

                            Button(action: { viewModel.loadHistoryDates() }) {
                                bentoDailyChip(text: NSLocalizedString("daily_history", comment: ""), icon: .history, tint: BentoStyle.matcha)
                            }
                            .buttonStyle(BentoPressStyle())
                        }
                    }

                    Spacer(minLength: 8)

                    if !viewModel.songs.isEmpty {
                        Button(action: {
                            if let first = viewModel.songs.first {
                                PlayerManager.shared.playReplacingContext(song: first, in: viewModel.songs)
                            }
                        }) {
                            MonologueIcon(icon: .play, size: 17, color: BentoStyle.onAccent, lineWidth: 2)
                                .frame(width: 48, height: 48)
                                .background(BentoStyle.tomato, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(BentoPressStyle())
                    }
                }
            }
            .padding(.horizontal, BentoStyle.blockSpacing)
            .padding(.top, 16)
            .padding(.bottom, viewModel.showStyleMenu ? 8 : 10)

            attachedStylePanel
        }
    }

    private func bentoDailyChip(text: String, icon: MonologueIcon.IconType, tint: Color) -> some View {
        HStack(spacing: 6) {
            MonologueIcon(icon: icon, size: 13, color: tint, lineWidth: 1.8)
            Text(text)
                .font(BentoStyle.labelFont(12, weight: .heavy))
                .foregroundStyle(BentoStyle.ink)
                .lineLimit(1)
            if icon == .sparkle {
                MonologueIcon(icon: .chevronRight, size: 10, color: BentoStyle.inkMuted, lineWidth: 1.8)
                    .rotationEffect(.degrees(viewModel.showStyleMenu ? -90 : 90))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(tint.opacity(0.13), in: Capsule())
        .overlay(Capsule().stroke(tint.opacity(0.22), lineWidth: 0.7))
    }

    private var defaultHeaderSection: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text(dayString)
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.text)

                            Text("/ \(monthString)")
                                .font(.system(size: 18, weight: .medium, design: .rounded))
                                .foregroundColor(Theme.secondaryText)
                                .padding(.bottom, 4)
                        }

                        HStack(spacing: 10) {
                            Button(action: toggleStyleMenu) {
                                HStack(spacing: 6) {
                                    Text(dailyStyleChipTitle)
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundColor(Theme.secondaryText)

                                    MonologueIcon(icon: .chevronRight, size: 12, color: Theme.secondaryText)
                                        .rotationEffect(.degrees(viewModel.showStyleMenu ? -90 : 90))
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color.monologueSeparator)
                                )
                            }

                            Button(action: {
                                viewModel.loadHistoryDates()
                            }) {
                                HStack(spacing: 6) {
                                    MonologueIcon(icon: .history, size: 14, color: Theme.secondaryText)
                                    Text(LocalizedStringKey("daily_history"))
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                }
                                .foregroundColor(Theme.secondaryText)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color.monologueSeparator)
                                )
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }

                    Spacer()

                    if !viewModel.songs.isEmpty {
                        Button(action: {
                            if let first = viewModel.songs.first {
                                PlayerManager.shared.playReplacingContext(song: first, in: viewModel.songs)
                            }
                        }) {
                            HStack(spacing: 8) {
                                MonologueIcon(icon: .play, size: 14, color: .monologueIconForeground)
                                Text(LocalizedStringKey("artist_play_all"))
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(.monologueIconForeground)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Theme.accent)
                            .clipShape(Capsule())
                            .shadow(color: Theme.accent.opacity(0.2), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.top, 16)
            .padding(.bottom, viewModel.showStyleMenu ? 8 : 10)

            attachedStylePanel
        }
    }

    private var mujiHeaderSection: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dayString)
                            .font(MujiStyle.titleFont(52, weight: .light))
                            .foregroundStyle(MujiStyle.ink)
                            .lineLimit(1)

                        Text("/ \(monthString)")
                            .font(MujiStyle.labelFont(12, weight: .regular))
                            .foregroundStyle(MujiStyle.inkMuted)
                    }
                    .frame(width: 72, alignment: .leading)

                    Rectangle()
                        .fill(MujiStyle.separator)
                        .frame(width: 0.65, height: 68)
                        .padding(.top, 4)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 7) {
                            MujiPill(text: String(localized: "daily_recommend"), tint: MujiStyle.clay)
                            if !viewModel.songs.isEmpty {
                                MujiPill(text: "\(viewModel.songs.count) \(String(localized: "songs_unit"))", tint: MujiStyle.tea)
                            }
                        }

                        Text(dailyHeaderTitle)
                            .font(MujiStyle.titleFont(24, weight: .regular))
                            .foregroundStyle(MujiStyle.ink)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    if !viewModel.songs.isEmpty {
                        Button(action: {
                            if let first = viewModel.songs.first {
                                PlayerManager.shared.playReplacingContext(song: first, in: viewModel.songs)
                            }
                        }) {
                            MonologueIcon(icon: .play, size: 15, color: MujiStyle.onTint, lineWidth: 1.5)
                                .frame(width: 42, height: 42)
                                .background(MujiStyle.clay, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                        }
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
                    }
                }

                HStack(spacing: 9) {
                    Button(action: toggleStyleMenu) {
                        mujiHeaderChip(
                            text: dailyStyleChipTitle,
                            icon: .sparkle,
                            tint: viewModel.showStyleMenu ? MujiStyle.clay : MujiStyle.indigo
                        )
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        viewModel.loadHistoryDates()
                    }) {
                        mujiHeaderChip(
                            text: NSLocalizedString("daily_history", comment: ""),
                            icon: .history,
                            tint: MujiStyle.tea
                        )
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))
                }

                if !viewModel.showStyleMenu {
                    MujiListDivider()
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.top, 16)
            .padding(.bottom, viewModel.showStyleMenu ? 8 : 10)

            attachedStylePanel
        }
        .background(mujiHeaderBackground)
    }

    private var neumorphicHeaderSection: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 14) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(dayString)
                            .font(NeumorphicStyle.titleFont(48, weight: .semibold))
                            .foregroundStyle(NeumorphicStyle.ink)
                            .lineLimit(1)

                        Text("/ \(monthString)")
                            .font(NeumorphicStyle.labelFont(13, weight: .medium))
                            .foregroundStyle(NeumorphicStyle.inkMuted)
                            .padding(.leading, 3)
                    }
                    .frame(width: 74, alignment: .leading)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 7) {
                            NeumorphicPill(text: String(localized: "daily_recommend"), tint: NeumorphicStyle.accent, selected: true, compact: true)
                            if !viewModel.songs.isEmpty {
                                NeumorphicPill(text: "\(viewModel.songs.count) \(String(localized: "songs_unit"))", tint: NeumorphicStyle.sage, compact: true)
                            }
                        }

                        Text(dailyHeaderTitle)
                            .font(NeumorphicStyle.titleFont(24, weight: .semibold))
                            .foregroundStyle(NeumorphicStyle.ink)
                            .lineLimit(2)
                            .minimumScaleFactor(0.78)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if !viewModel.songs.isEmpty {
                        Button(action: {
                            if let first = viewModel.songs.first {
                                PlayerManager.shared.playReplacingContext(song: first, in: viewModel.songs)
                            }
                        }) {
                            MonologueIcon(icon: .play, size: 16, color: Color(light: .white, dark: .black), lineWidth: 1.8)
                                .frame(width: 44, height: 44)
                                .background(NeumorphicStyle.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .shadow(color: NeumorphicStyle.accent.opacity(0.24), radius: 10, x: 0, y: 5)
                        }
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
                    }
                }

                HStack(spacing: 9) {
                    Button(action: toggleStyleMenu) {
                        NeumorphicPill(
                            text: dailyStyleChipTitle,
                            tint: NeumorphicStyle.accent,
                            icon: .sparkle,
                            selected: viewModel.showStyleMenu
                        )
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        viewModel.loadHistoryDates()
                    }) {
                        NeumorphicPill(
                            text: NSLocalizedString("daily_history", comment: ""),
                            tint: NeumorphicStyle.warm,
                            icon: .history
                        )
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))
                }
            }
            .padding(17)

            attachedStylePanel
        }
        .background(neumorphicHeaderBackground)
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    private var signalHeaderSection: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 14) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(dayString)
                            .font(SignalStyle.titleFont(48, weight: .bold))
                            .foregroundStyle(SignalStyle.ink)
                            .lineLimit(1)

                        Text("/ \(monthString)")
                            .font(SignalStyle.monoFont(12, weight: .semibold))
                            .foregroundStyle(SignalStyle.inkMuted)
                            .padding(.leading, 3)
                    }
                    .frame(width: 74, alignment: .leading)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 7) {
                            SignalPill(text: String(localized: "daily_recommend"), tint: SignalStyle.accent, selected: true, compact: true)
                            if !viewModel.songs.isEmpty {
                                SignalPill(text: "\(viewModel.songs.count) \(String(localized: "songs_unit"))", tint: SignalStyle.olive, compact: true)
                            }
                        }

                        Text(dailyHeaderTitle)
                            .font(SignalStyle.titleFont(24, weight: .bold))
                            .foregroundStyle(SignalStyle.ink)
                            .lineLimit(2)
                            .minimumScaleFactor(0.78)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if !viewModel.songs.isEmpty {
                        Button(action: {
                            if let first = viewModel.songs.first {
                                PlayerManager.shared.playReplacingContext(song: first, in: viewModel.songs)
                            }
                        }) {
                            MonologueIcon(icon: .play, size: 16, color: SignalStyle.onAccent, lineWidth: 1.8)
                                .frame(width: 46, height: 46)
                                .background(
                                    LinearGradient(
                                        colors: [SignalStyle.accent, SignalStyle.violet],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    in: RoundedRectangle(cornerRadius: 17, style: .continuous)
                                )
                                .shadow(color: SignalStyle.accent.opacity(0.24), radius: 14, x: 0, y: 8)
                        }
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
                    }
                }

                HStack(spacing: 9) {
                    Button(action: toggleStyleMenu) {
                        SignalPill(
                            text: dailyStyleChipTitle,
                            tint: SignalStyle.accent,
                            icon: .sparkle,
                            selected: viewModel.showStyleMenu
                        )
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        viewModel.loadHistoryDates()
                    }) {
                        SignalPill(
                            text: NSLocalizedString("daily_history", comment: ""),
                            tint: SignalStyle.amber,
                            icon: .history
                        )
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))
                }
            }
            .padding(16)

            attachedStylePanel
        }
        .background(signalHeaderBackground)
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    private var sequoiaHeaderSection: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 15) {
                HStack(alignment: .center, spacing: 13) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(dayString)
                            .font(SequoiaStyle.titleFont(46, weight: .semibold))
                            .foregroundStyle(SequoiaStyle.ink)
                            .lineLimit(1)

                        Text("/ \(monthString)")
                            .font(SequoiaStyle.labelFont(12, weight: .medium))
                            .foregroundStyle(SequoiaStyle.inkMuted)
                            .padding(.leading, 3)
                    }
                    .frame(width: 70, alignment: .leading)

                    Rectangle()
                        .fill(SequoiaStyle.separator)
                        .frame(width: 0.6, height: 56)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 7) {
                            SequoiaPill(
                                text: String(localized: "daily_recommend"),
                                icon: .sparkle,
                                tint: SequoiaStyle.accent,
                                selected: true,
                                compact: true
                            )

                            if !viewModel.songs.isEmpty {
                                SequoiaPill(
                                    text: "\(viewModel.songs.count) \(String(localized: "songs_unit"))",
                                    tint: SequoiaStyle.aqua,
                                    compact: true
                                )
                            }
                        }

                        Text(dailyHeaderTitle)
                            .font(SequoiaStyle.titleFont(23, weight: .semibold))
                            .foregroundStyle(SequoiaStyle.ink)
                            .lineLimit(2)
                            .minimumScaleFactor(0.78)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if !viewModel.songs.isEmpty {
                        Button(action: {
                            if let first = viewModel.songs.first {
                                PlayerManager.shared.playReplacingContext(song: first, in: viewModel.songs)
                            }
                        }) {
                            SequoiaControlButton(icon: .play, tint: SequoiaStyle.accent, size: 44, selected: true)
                        }
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
                    }
                }

                HStack(spacing: 9) {
                    Button(action: toggleStyleMenu) {
                        sequoiaHeaderChip(
                            text: dailyStyleChipTitle,
                            icon: .sparkle,
                            tint: SequoiaStyle.accent,
                            selected: viewModel.showStyleMenu
                        )
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        viewModel.loadHistoryDates()
                    }) {
                        sequoiaHeaderChip(
                            text: NSLocalizedString("daily_history", comment: ""),
                            icon: .history,
                            tint: SequoiaStyle.green,
                            selected: false
                        )
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))
                }
            }
            .padding(15)

            attachedStylePanel
        }
        .background(SequoiaGlassBand(tint: SequoiaStyle.accent, cornerRadius: 24))
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    private func sequoiaHeaderChip(text: String, icon: MonologueIcon.IconType, tint: Color, selected: Bool) -> some View {
        HStack(spacing: 7) {
            MonologueIcon(icon: icon, size: 13, color: selected ? tint : SequoiaStyle.inkSoft, lineWidth: 1.5)
            Text(text)
                .font(SequoiaStyle.labelFont(12, weight: selected ? .semibold : .medium))
                .foregroundStyle(selected ? SequoiaStyle.ink : SequoiaStyle.inkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(
            SequoiaSurfaceBackground(
                cornerRadius: 14,
                elevated: selected,
                pressed: !selected,
                fill: selected ? tint.opacity(0.13) : SequoiaStyle.materialList,
                role: selected ? .selected : .list
            )
        )
    }

    private var capsuleHeaderSection: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 13) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(dayString)
                            .font(CapsuleStyle.titleFont(48, weight: .black))
                            .foregroundStyle(CapsuleStyle.ink)
                            .lineLimit(1)

                        Text("/ \(monthString)")
                            .font(CapsuleStyle.labelFont(12, weight: .bold))
                            .foregroundStyle(CapsuleStyle.inkMuted)
                            .padding(.leading, 4)
                    }
                    .frame(width: 74, alignment: .leading)

                    Rectangle()
                        .fill(CapsuleStyle.separator.opacity(0.64))
                        .frame(width: 0.8, height: 58)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 7) {
                            CapsuleDetailChip(
                                text: String(localized: "daily_recommend"),
                                icon: .sparkle,
                                tint: CapsuleStyle.accent,
                                selected: true
                            )

                            if !viewModel.songs.isEmpty {
                                CapsuleDetailChip(
                                    text: "\(viewModel.songs.count) \(String(localized: "songs_unit"))",
                                    tint: CapsuleStyle.cyan
                                )
                            }
                        }

                        Text(dailyHeaderTitle)
                            .font(CapsuleStyle.titleFont(23, weight: .bold))
                            .foregroundStyle(CapsuleStyle.ink)
                            .lineLimit(2)
                            .minimumScaleFactor(0.78)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if !viewModel.songs.isEmpty {
                        Button(action: {
                            if let first = viewModel.songs.first {
                                PlayerManager.shared.playReplacingContext(song: first, in: viewModel.songs)
                            }
                        }) {
                            CapsuleDetailIconButton(icon: .play, tint: CapsuleStyle.accent)
                        }
                        .buttonStyle(CapsulePressStyle())
                    }
                }

                HStack(spacing: 9) {
                    Button(action: toggleStyleMenu) {
                        CapsuleDetailChip(
                            text: dailyStyleChipTitle,
                            icon: .sparkle,
                            tint: CapsuleStyle.accent,
                            selected: viewModel.showStyleMenu
                        )
                    }
                    .buttonStyle(.plain)

                    Button(action: { viewModel.loadHistoryDates() }) {
                        CapsuleDetailChip(
                            text: NSLocalizedString("daily_history", comment: ""),
                            icon: .history,
                            tint: CapsuleStyle.mint
                        )
                    }
                    .buttonStyle(CapsulePressStyle())
                }
            }
            .padding(15)

            attachedStylePanel
        }
        .background(CapsuleSurfaceBackground(cornerRadius: 30, elevated: true, tint: CapsuleStyle.surface.opacity(0.92)))
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    private func mujiHeaderChip(text: String, icon: MonologueIcon.IconType, tint: Color) -> some View {
        HStack(spacing: 7) {
            MonologueIcon(icon: icon, size: 13, color: tint, lineWidth: 1.5)
            Text(text)
                .font(MujiStyle.labelFont(12, weight: .regular))
                .foregroundStyle(MujiStyle.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(MujiStyle.surface.opacity(0.84), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(MujiStyle.hairline.opacity(0.48), lineWidth: 0.6)
        )
    }

    private var mangaHeaderSection: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 13) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(dayString)
                            .font(MangaStyle.titleFont(42, weight: .black))
                            .foregroundColor(MangaStyle.ink)
                            .lineLimit(1)

                        Text("/ \(monthString)")
                            .font(MangaStyle.labelFont(13, weight: .black))
                            .foregroundColor(MangaStyle.inkSub)
                    }
                    .frame(width: 64, alignment: .leading)

                    VStack(alignment: .leading, spacing: 9) {
                        HStack(spacing: 7) {
                            MangaSectionMark(kind: .heart, tint: MangaStyle.bubblePink, size: 22, foreground: MangaStyle.ink)
                            MangaLabel(text: String(localized: "daily_recommend"), tint: MangaStyle.labelYellow, small: true)
                        }

                        Text(dailyHeaderTitle)
                            .font(MangaStyle.titleFont(24, weight: .black))
                            .foregroundColor(MangaStyle.ink)
                            .lineLimit(2)
                            .minimumScaleFactor(0.78)

                        if !viewModel.songs.isEmpty {
                            MangaLabel(text: "\(viewModel.songs.count) \(String(localized: "songs_unit"))", tint: MangaStyle.paperCool, small: true, foreground: MangaStyle.ink)
                        }
                    }

                    Spacer(minLength: 8)

                    if !viewModel.songs.isEmpty {
                        Button(action: {
                            if let first = viewModel.songs.first {
                                PlayerManager.shared.playReplacingContext(song: first, in: viewModel.songs)
                            }
                        }) {
                            MonologueIcon(icon: .play, size: 16, color: MangaStyle.strokeInk, lineWidth: 2)
                                .frame(width: 44, height: 44)
                                .background(MangaStyle.labelYellow, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(MangaStyle.strokeInk, lineWidth: 1.6))
                                .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(MangaStyle.strokeInk).offset(x: 2, y: 2))
                        }
                        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
                    }
                }

                HStack(spacing: 9) {
                    Button(action: toggleStyleMenu) {
                        mangaHeaderChip(
                            text: dailyStyleChipTitle,
                            icon: .sparkle,
                            tint: viewModel.showStyleMenu ? MangaStyle.labelYellow : MangaStyle.bubbleBlue
                        )
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        viewModel.loadHistoryDates()
                    }) {
                        mangaHeaderChip(
                            text: NSLocalizedString("daily_history", comment: ""),
                            icon: .history,
                            tint: MangaStyle.mint,
                            foreground: MangaStyle.strokeInk
                        )
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))
                }
            }
            .padding(16)

            attachedStylePanel
        }
        .background(mangaHeaderBackground)
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var attachedStylePanel: some View {
        DailyStylePanelReveal(isExpanded: viewModel.showStyleMenu) {
            StyleSelectionMorphView(
                styleManager: styleManager,
                isPresented: $viewModel.showStyleMenu,
                placement: .attachedToHeader
            )
        }
    }

    @ViewBuilder
    private var mujiHeaderBackground: some View {
        EmptyView()
    }

    @ViewBuilder
    private var mangaHeaderBackground: some View {
        MangaCardBackground(cornerRadius: 22, elevated: true, tint: MangaStyle.bubbleWhite)
    }

    @ViewBuilder
    private var neumorphicHeaderBackground: some View {
        NeumorphicSurfaceBackground(cornerRadius: 26, elevated: true)
    }

    @ViewBuilder
    private var signalHeaderBackground: some View {
        SignalSurfaceBackground(cornerRadius: 30, elevated: true, fill: SignalStyle.paper)
    }

    private func mangaHeaderChip(text: String, icon: MonologueIcon.IconType, tint: Color, foreground: Color = MangaStyle.ink) -> some View {
        HStack(spacing: 7) {
            MonologueIcon(icon: icon, size: 13, color: foreground, lineWidth: 1.7)
            Text(text)
                .font(MangaStyle.labelFont(12, weight: .black))
                .foregroundColor(foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.74)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Capsule().fill(tint))
        .overlay(Capsule().stroke(MangaStyle.strokeInk, lineWidth: 1.3))
    }

    private var dailyFilteredSongs: [Song] { viewModel.songs.filtered(by: searchText) }

    private var songList: some View {
        Group {
            if CapsuleStyle.isActive {
                capsuleSongList
            } else if PetWhiteStyle.isActive {
                petWhiteSongList
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        headerSection

                        if !viewModel.showStyleMenu {
                            dailySearchBar
                        }

                        dailyRows
                    }
                    .padding(.bottom, 120)
                    .animation(.spring(response: 0.34, dampingFraction: 0.9), value: viewModel.showStyleMenu)
                }
                .scrollIndicators(.hidden)
                .themeRenderScrollLayer()
            }
        }
        .monologueSheet(isPresented: $showBatchAddToPlaylist, preset: .standard) {
            BatchAddToPlaylistSheet(songs: dailyFilteredSongs.filter { selectedSongIds.contains($0.id) })
        }
    }

    private var petWhiteSongList: some View {
        ScrollView {
            VStack(spacing: 14) {
                headerSection

                VStack(alignment: .leading, spacing: 12) {
                    PetWhiteSectionTitle(
                        title: "TODAY",
                        detail: String(format: NSLocalizedString("songs_count_format", comment: ""), dailyFilteredSongs.count),
                        icon: .sparkle,
                        tint: PetWhiteStyle.butter
                    )

                    if !viewModel.showStyleMenu {
                        dailySearchBar
                            .padding(.horizontal, -DeviceLayout.viewHorizontalPadding)
                    }

                    dailyRows
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(PetWhiteSurfaceBackground(cornerRadius: 26, elevated: true, tint: PetWhiteStyle.surfaceRaised, accent: PetWhiteStyle.butter))
                .padding(.horizontal, DeviceLayout.isPad ? 8 : 4)
            }
            .padding(.bottom, 120)
            .animation(.spring(response: 0.34, dampingFraction: 0.9), value: viewModel.showStyleMenu)
        }
        .scrollIndicators(.hidden)
        .themeRenderScrollLayer()
    }

    private var capsuleSongList: some View {
        ScrollView {
            VStack(spacing: 14) {
                headerSection

                CapsuleDetailSection(
                    title: "TODAY",
                    subtitle: String(format: NSLocalizedString("songs_count_format", comment: ""), dailyFilteredSongs.count),
                    icon: .sparkle,
                    tint: CapsuleStyle.accent
                ) {
                    if !viewModel.showStyleMenu {
                        dailySearchBar
                            .padding(.horizontal, -DeviceLayout.viewHorizontalPadding)
                    }

                    dailyRows
                }
            }
            .padding(.bottom, 120)
            .animation(.spring(response: 0.34, dampingFraction: 0.9), value: viewModel.showStyleMenu)
        }
        .scrollIndicators(.hidden)
        .themeRenderScrollLayer()
    }

    private var dailySearchBar: some View {
        PlaylistSearchBar(
            searchText: $searchText,
            isSearching: $isSearching,
            isSelectMode: $isSelectMode,
            selectedIds: $selectedSongIds,
            songs: dailyFilteredSongs,
            onBatchQueue: {
                let selected = dailyFilteredSongs.filter { selectedSongIds.contains($0.id) }
                SongBatchActionHelper.addToQueue(selected) {
                    isSelectMode = false
                    selectedSongIds.removeAll()
                }
            },
            onBatchDownload: { batchDownloadSelected() },
            onBatchCollect: { showBatchAddToPlaylist = true }
        )
    }

    private var dailyRows: some View {
        LazyVStack(spacing: CapsuleStyle.isActive ? 4 : 0) {
            ForEach(Array(dailyFilteredSongs.enumerated()), id: \.element.id) { index, song in
                SongListRow(song: song, index: index, isSelecting: isSelectMode, isSelected: selectedSongIds.contains(song.id), onArtistTap: { artistId in
                    selectedArtistId = artistId
                    showArtistDetail = true
                }, onDetailTap: { detailSong in
                    selectedSongForDetail = detailSong
                    showSongDetail = true
                }, onAlbumTap: { albumId in
                    selectedAlbumId = albumId
                    showAlbumDetail = true
                }, onTap: {
                    if isSelectMode {
                        if selectedSongIds.contains(song.id) {
                            selectedSongIds.remove(song.id)
                        } else {
                            selectedSongIds.insert(song.id)
                        }
                    } else {
                        PlayerManager.shared.play(song: song, in: dailyFilteredSongs)
                    }
                }, horizontalPadding: PetWhiteStyle.isActive ? CGFloat(0) : nil)
            }
        }
    }

    private func batchDownloadSelected() {
        let selected = dailyFilteredSongs.filter { selectedSongIds.contains($0.id) }
        for song in selected {
            if song.isQQMusic {
                DownloadManager.shared.downloadQQ(song: song, quality: DownloadManager.defaultQQDownloadQuality)
            } else {
                DownloadManager.shared.download(song: song, quality: DownloadManager.defaultNeteaseDownloadQuality)
            }
        }
        AlertManager.shared.show(title: String(localized: "已加入下载"), message: String(localized: "已将 \(selected.count) 首歌曲加入下载队列"), primaryButtonTitle: String(localized: "确定"), primaryAction: {})
        withAnimation { isSelectMode = false; selectedSongIds.removeAll() }
    }

    private func errorView(msg: String) -> some View {
        VStack(spacing: 14) {
            if NeumorphicStyle.isActive {
                NeumorphicIconBadge(icon: .warning, tint: NeumorphicStyle.red, size: 56)
            } else if SignalStyle.isActive {
                SignalIconBadge(icon: .warning, tint: SignalStyle.rust, size: 56)
            } else if SequoiaStyle.isActive {
                SequoiaIconBadge(icon: .warning, tint: SequoiaStyle.red, size: 56)
            } else {
                MonologueIcon(icon: .warning, size: 48, color: .monologueTextSecondary)
            }
            Text(msg)
                .font(SignalStyle.isActive ? SignalStyle.labelFont(14, weight: .medium) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(14, weight: .medium) : (SequoiaStyle.isActive ? SequoiaStyle.labelFont(14, weight: .medium) : .body)))
                .foregroundColor(SignalStyle.isActive ? SignalStyle.inkSoft : (NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : (SequoiaStyle.isActive ? SequoiaStyle.inkSoft : .monologueTextSecondary)))
                .multilineTextAlignment(.center)
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            Button("Retry") {
                viewModel.loadStandardRecommend()
            }
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SequoiaStyle.isActive ? 26 : 0)
        .background {
            if SequoiaStyle.isActive {
                SequoiaSurfaceBackground(cornerRadius: 22, elevated: true, role: .chrome)
            }
        }
        .padding(.horizontal, SequoiaStyle.isActive ? DeviceLayout.viewHorizontalPadding : 0)
        .padding(.top, 72)
    }

    private var dailyHeaderTitle: String {
        styleManager.currentStyle == nil ? String(localized: "made_for_you") : styleManager.currentStyleName
    }

    private var dailyStyleChipTitle: String {
        styleManager.currentStyle == nil ? String(localized: "style_default") : styleManager.currentStyleName
    }

    private func toggleStyleMenu() {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) {
            isSelectMode = false
            selectedSongIds.removeAll()
            viewModel.showStyleMenu.toggle()
        }
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd"
        return f
    }()

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM"
        return f
    }()

    private var dayString: String {
        Self.dayFormatter.string(from: Date())
    }

    private var monthString: String {
        Self.monthFormatter.string(from: Date())
    }
}

private struct DailyStylePanelReveal<Content: View>: View {
    let isExpanded: Bool
    let content: Content
    @State private var measuredHeight: CGFloat = 0

    init(isExpanded: Bool, @ViewBuilder content: () -> Content) {
        self.isExpanded = isExpanded
        self.content = content()
    }

    var body: some View {
        content
            .fixedSize(horizontal: false, vertical: true)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: DailyStylePanelHeightPreferenceKey.self,
                        value: proxy.size.height
                    )
                }
            )
            .onPreferenceChange(DailyStylePanelHeightPreferenceKey.self) { height in
                if height > 0 {
                    measuredHeight = height
                }
            }
            .frame(height: isExpanded ? measuredHeight : 0, alignment: .top)
            .opacity(isExpanded ? 1 : 0.001)
            .clipped()
            .compositingGroup()
            .allowsHitTesting(isExpanded)
            .animation(.spring(response: 0.34, dampingFraction: 0.9), value: isExpanded)
    }
}

private struct DailyStylePanelHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - History View

struct DailyHistoryView: View {
    let dates: [String]
    @Environment(\.dismiss) var dismiss
    @Environment(\.monologueSheetDismiss) private var monologueSheetDismiss
    @State private var selectedDate: String?
    @State private var songs: [Song] = []
    @State private var isLoading = false
    @State private var loadTask: Task<Void, Never>?

    typealias Theme = PlaylistDetailView.Theme

    var body: some View {
        ZStack {
            MonologueSheetAwareBackground {
                if NeumorphicStyle.isActive {
                    ThemeRenderBackdrop(theme: .neumorphic)
                } else if SignalStyle.isActive {
                    ThemeRenderBackdrop(theme: .signal)
                } else {
                    ThemedPageBackground()
                }
            }

            VStack(spacing: 0) {
                headerSection

                dateSelector
                    .padding(.top, 8)

                if isLoading {
                    Spacer()
                    MonologueLoadingView(text: "LOADING")
                    Spacer()
                } else if songs.isEmpty {
                    emptyState
                } else {
                    songList
                }
            }
        }
        .onAppear {
            AppLogger.debug("DailyHistoryView appeared with \(dates.count) dates: \(dates)")
            if let first = dates.first {
                loadSongs(for: first)
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Button(action: { dismissCurrentPresentation(systemDismiss: dismiss, monologueSheetDismiss: monologueSheetDismiss) }) {
                MonologueIcon(icon: .close, size: 20, color: MujiStyle.isActive ? MujiStyle.inkSoft : (SignalStyle.isActive ? SignalStyle.inkSoft : (NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : Theme.text)))
                    .padding(10)
                    .background {
                        if NeumorphicStyle.isActive {
                            NeumorphicSurfaceBackground(cornerRadius: 20, elevated: false, pressed: true, lightweight: true)
                        } else if SignalStyle.isActive {
                            SignalSurfaceBackground(cornerRadius: 20, elevated: false, pressed: true, fill: SignalStyle.controlPressed)
                        } else {
                            Circle().fill(MujiStyle.isActive ? MujiStyle.surfaceRaised : Color.monologueGlassTint.opacity(0.6))
                        }
                    }
                    .clipShape(Circle())
            }

            Spacer()

            VStack(spacing: 2) {
                Text(LocalizedStringKey("daily_history_title"))
                    .font(MujiStyle.isActive ? MujiStyle.titleFont(19, weight: .regular) : (SignalStyle.isActive ? SignalStyle.titleFont(19, weight: .bold) : (NeumorphicStyle.isActive ? NeumorphicStyle.titleFont(19, weight: .semibold) : .system(size: 18, weight: .bold, design: .rounded))))
                    .foregroundColor(MujiStyle.isActive ? MujiStyle.ink : (SignalStyle.isActive ? SignalStyle.ink : (NeumorphicStyle.isActive ? NeumorphicStyle.ink : Theme.text)))

                Text(LocalizedStringKey("daily_history_subtitle"))
                    .font(MujiStyle.isActive ? MujiStyle.labelFont(12, weight: .regular) : (SignalStyle.isActive ? SignalStyle.labelFont(12, weight: .medium) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(12, weight: .medium) : .system(size: 12, weight: .medium, design: .rounded))))
                    .foregroundColor(MujiStyle.isActive ? MujiStyle.inkSoft : (SignalStyle.isActive ? SignalStyle.inkSoft : (NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : Theme.secondaryText)))
            }

            Spacer()

            if !songs.isEmpty {
                Button(action: {
                    if let first = songs.first {
                        PlayerManager.shared.playReplacingContext(song: first, in: songs)
                    }
                }) {
                    if MujiStyle.isActive {
                        MujiActionPill(title: String(localized: "artist_play_all"), icon: .play, selected: true, tint: MujiStyle.clay)
                    } else if NeumorphicStyle.isActive {
                        NeumorphicPlayPill(title: String(localized: "artist_play_all"), tint: NeumorphicStyle.accent)
                    } else if SignalStyle.isActive {
                        SignalPlayPill(title: String(localized: "artist_play_all"))
                    } else {
                        HStack(spacing: 8) {
                            MonologueIcon(icon: .play, size: 14, color: .monologueIconForeground)
                            Text(LocalizedStringKey("artist_play_all"))
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.monologueIconForeground)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Theme.accent)
                        .clipShape(Capsule())
                    }
                }
                .buttonStyle(ScaleButtonStyle())
            } else {
                Color.clear
                    .frame(width: 92, height: 40)
            }
        }
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Date Selector

    private var dateSelector: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(dates, id: \.self) { date in
                    dateButton(for: date)
                }
            }
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
    }

    private func dateButton(for date: String) -> some View {
        let isSelected = selectedDate == date
        let displayDate = formatDateShort(date)

        return Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                loadSongs(for: date)
            }
        }) {
            Text(displayDate)
                .font(MujiStyle.isActive ? MujiStyle.labelFont(14, weight: isSelected ? .semibold : .regular) : (SignalStyle.isActive ? SignalStyle.labelFont(14, weight: isSelected ? .bold : .medium) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(14, weight: isSelected ? .semibold : .medium) : .system(size: 14, weight: isSelected ? .bold : .medium, design: .rounded))))
                .foregroundColor(MujiStyle.isActive ? (isSelected ? MujiStyle.onTint : MujiStyle.ink) : (SignalStyle.isActive ? (isSelected ? SignalStyle.onAccent : SignalStyle.inkSoft) : (NeumorphicStyle.isActive ? (isSelected ? NeumorphicStyle.accent : NeumorphicStyle.inkSoft) : (isSelected ? .monologueIconForeground : .monologueTextPrimary))))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(dateButtonBackground(isSelected: isSelected))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    @ViewBuilder
    private func dateButtonBackground(isSelected: Bool) -> some View {
        if NeumorphicStyle.isActive {
            NeumorphicSurfaceBackground(
                cornerRadius: 17,
                elevated: isSelected,
                pressed: !isSelected,
                tint: isSelected ? NeumorphicStyle.accent.opacity(0.18) : NeumorphicStyle.surface
            )
        } else if SignalStyle.isActive {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(isSelected ? SignalStyle.accent : SignalStyle.control)
                .overlay(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .stroke(isSelected ? Color.white.opacity(0.2) : SignalStyle.separator.opacity(0.75), lineWidth: 0.8)
                )
                .shadow(color: isSelected ? SignalStyle.accent.opacity(0.18) : .clear, radius: 12, x: 0, y: 7)
        } else {
            Capsule()
                .fill(MujiStyle.isActive ? (isSelected ? MujiStyle.clay : MujiStyle.surfaceRaised) : (isSelected ? Color.monologueIconBackground.opacity(0.85) : Color.monologueGlassTint))
                .overlay(
                    Capsule()
                        .stroke(MujiStyle.isActive ? MujiStyle.hairline.opacity(isSelected ? 0 : 0.5) : Color.monologueSeparator, lineWidth: isSelected ? 0 : 1)
                )
        }
    }

    // MARK: - Content

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            if NeumorphicStyle.isActive {
                NeumorphicIconBadge(icon: .clock, tint: NeumorphicStyle.warm, size: 56)
            } else if SignalStyle.isActive {
                SignalIconBadge(icon: .clock, tint: SignalStyle.amber, size: 56)
            } else {
                MonologueIcon(icon: .clock, size: 48, color: .monologueTextSecondary.opacity(0.5))
            }

            Text(LocalizedStringKey("daily_select_date"))
                .font(SignalStyle.isActive ? SignalStyle.labelFont(15, weight: .medium) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(15, weight: .medium) : .system(size: 16, weight: .medium, design: .rounded)))
                .foregroundColor(SignalStyle.isActive ? SignalStyle.inkSoft : (NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : .monologueTextSecondary))

            Spacer()
        }
    }

    private var songList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if let date = selectedDate {
                    HStack {
                        Text(formatFullDate(date))
                            .font(SignalStyle.isActive ? SignalStyle.labelFont(13, weight: .bold) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(13, weight: .semibold) : .system(size: 14, weight: .medium, design: .rounded)))
                            .foregroundColor(SignalStyle.isActive ? SignalStyle.ink : (NeumorphicStyle.isActive ? NeumorphicStyle.ink : Theme.secondaryText))

                        Spacer()

                        Text(String(format: NSLocalizedString("daily_song_count", comment: ""), songs.count))
                            .font(SignalStyle.isActive ? SignalStyle.labelFont(12, weight: .medium) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(12, weight: .medium) : .system(size: 13, weight: .medium, design: .rounded)))
                            .foregroundColor(SignalStyle.isActive ? SignalStyle.inkSoft : (NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : Theme.secondaryText.opacity(0.7)))
                    }
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    .padding(.vertical, 12)
                    .background {
                        if NeumorphicStyle.isActive {
                            NeumorphicSurfaceBackground(cornerRadius: 18, elevated: false, pressed: true, lightweight: true)
                                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                        } else if SignalStyle.isActive {
                            SignalSurfaceBackground(cornerRadius: 20, elevated: false, pressed: true, fill: SignalStyle.controlPressed)
                                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                        }
                    }
                }

                ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                    SongListRow(song: song, index: index, onTap: {
                        PlayerManager.shared.play(song: song, in: songs)
                    })
                }
            }
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
    }

    // MARK: - Helpers

    private func loadSongs(for date: String) {
        selectedDate = date
        isLoading = true
        songs = []
        loadTask?.cancel()

        AppLogger.debug("Loading history songs for date: \(date)")
        loadTask = Task {
            do {
                let loadedSongs = try await APIService.shared.fetchHistoryRecommendSongs(date: date).async()
                guard !Task.isCancelled else { return }
                AppLogger.debug("Received \(loadedSongs.count) history songs")
                songs = loadedSongs
            } catch {
                guard !Task.isCancelled else { return }
                AppLogger.error("History songs load error: \(error)")
            }
            isLoading = false
        }
    }

    private func formatDateShort(_ dateString: String) -> String {
        let components = dateString.split(separator: "-")
        if components.count >= 3 {
            return "\(components[1])/\(components[2])"
        }
        return dateString
    }

    private func formatDate(_ dateString: String) -> (day: String, month: String) {
        let components = dateString.split(separator: "-")
        if components.count >= 3 {
            let day = String(components[2])
            let monthNum = Int(components[1]) ?? 1
            let months = ["", String(localized: "一月"), String(localized: "二月"), String(localized: "三月"), String(localized: "四月"), String(localized: "五月"), String(localized: "六月"),
                         String(localized: "七月"), String(localized: "八月"), String(localized: "九月"), String(localized: "十月"), String(localized: "十一月"), String(localized: "十二月")]
            let month = months[min(monthNum, 12)]
            return (day, month)
        }
        return (dateString, "")
    }

    private func formatFullDate(_ dateString: String) -> String {
        let components = dateString.split(separator: "-")
        if components.count >= 3 {
            return String(localized: "\(components[0])年\(components[1])月\(components[2])日 推荐")
        }
        return dateString
    }
}
