import SwiftUI

/// Capsule 主题的播客页完整体验：分类浏览、订阅、推荐电台等区块的单文件实现。
struct CapsulePodcastExperience: View {
    @ObservedObject private var viewModel = PodcastViewModel.shared
    @State private var showRadioPlayer = false
    @State private var radioIdToOpen = 0
    @State private var selectedBroadcastChannel: BroadcastChannel?
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        let _ = settings.globalThemeRevision

        NavigationStack {
            ZStack {
                ThemedPageBackground(useRenderLayer: true)
                    .ignoresSafeArea()

                if viewModel.isLoading && isEmptyInitialState {
                    capsuleLoadingView
                } else {
                    content
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: PodcastView.PodcastDestination.self) { destination in
                destinationView(for: destination)
            }
        }
        .fullScreenCover(isPresented: $showRadioPlayer) {
            PodcastPlayerView(radioId: radioIdToOpen)
        }
        .fullScreenCover(item: $selectedBroadcastChannel) { channel in
            BroadcastPlayerView(channel: channel)
        }
        .task {
            await viewModel.ensureDataLoadedAfterTabTransition(reason: "capsule podcast appear")
        }
    }

    private var isEmptyInitialState: Bool {
        viewModel.personalizedRadios.isEmpty
            && viewModel.categories.isEmpty
            && viewModel.rcmdPrograms.isEmpty
            && viewModel.broadcastChannels.isEmpty
    }

    private var content: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 18) {
                commandBar
                orbitDock

                if !viewModel.categories.isEmpty {
                    categoryRail
                }

                if !viewModel.rcmdPrograms.isEmpty {
                    programRail(
                        title: String(localized: "podcast_for_you"),
                        tint: CapsuleStyle.accent,
                        programs: Array(viewModel.rcmdPrograms.prefix(10)),
                        destination: .topList(String(localized: "podcast_for_you"), .hot)
                    )
                } else if !viewModel.personalizedRadios.isEmpty {
                    radioRail(
                        title: String(localized: "podcast_for_you"),
                        tint: CapsuleStyle.accent,
                        radios: Array(viewModel.personalizedRadios.prefix(8)),
                        destination: .topList(String(localized: "podcast_for_you"), .hot)
                    )
                }

                if !viewModel.todayPerfered.isEmpty {
                    focusRadioPanel
                }

                if !viewModel.hotPodcasts.isEmpty || !viewModel.recommendRadios.isEmpty {
                    hotPodcastPanel
                }

                if !viewModel.newestPrograms.isEmpty {
                    programRail(
                        title: String(localized: "上新佳作"),
                        tint: CapsuleStyle.mint,
                        programs: Array(viewModel.newestPrograms.prefix(10)),
                        destination: nil
                    )
                }

                if !viewModel.chartPrograms.isEmpty {
                    chartProgramPanel
                }

                if !viewModel.newcomerRadios.isEmpty {
                    radioRail(
                        title: String(localized: "podcast_newcomer"),
                        tint: CapsuleStyle.violet,
                        radios: Array(viewModel.newcomerRadios.prefix(8)),
                        destination: nil
                    )
                }

                if !viewModel.programToplist.isEmpty {
                    programToplistPanel
                }

                if !viewModel.broadcastChannels.isEmpty {
                    broadcastRail
                }

                FloatingBarBottomSpacer()
            }
            .iPadContentWidth(1180)
            .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
            .padding(.top, DeviceLayout.headerTopPadding + 8)
        }
        .refreshable {
            viewModel.refreshData()
        }
        .themeRenderScrollLayer()
    }

    private var commandBar: some View {
        HStack(spacing: 12) {
            CapsuleIconBadge(icon: .podcast, tint: CapsuleStyle.mint, size: 50)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Capsule()
                        .fill(CapsuleStyle.mint)
                        .frame(width: 22, height: 7)

                    Circle()
                        .fill(CapsuleStyle.cyan.opacity(0.75))
                        .frame(width: 7, height: 7)
                }

                Text("tabbar_podcast")
                    .font(CapsuleStyle.titleFont(25, weight: .bold))
                    .foregroundStyle(CapsuleStyle.ink)
                    .lineLimit(1)
            }

            Spacer(minLength: 10)

            NavigationLink(value: PodcastView.PodcastDestination.categoryBrowse) {
                CapsuleIconBadge(icon: .gridSquare, tint: CapsuleStyle.violet, size: 42)
            }
            .buttonStyle(CapsulePressStyle())

            NavigationLink(value: PodcastView.PodcastDestination.search) {
                CapsuleIconBadge(icon: .search, tint: CapsuleStyle.accent, size: 42)
            }
            .buttonStyle(CapsulePressStyle())
        }
    }

    private var orbitDock: some View {
        HStack(spacing: 10) {
            NavigationLink(value: PodcastView.PodcastDestination.topList(String(localized: "podcast_featured"), .hot)) {
                dockChip(
                    title: String(localized: "podcast_featured"),
                    value: "\(max(viewModel.recommendRadios.count, viewModel.hotPodcasts.count))",
                    icon: .sparkle,
                    tint: CapsuleStyle.accent
                )
            }
            .buttonStyle(.plain)

            NavigationLink(value: PodcastView.PodcastDestination.categoryBrowse) {
                dockChip(
                    title: String(localized: "分类"),
                    value: "\(viewModel.categories.count)",
                    icon: .layers,
                    tint: CapsuleStyle.violet
                )
            }
            .buttonStyle(.plain)

            NavigationLink(value: PodcastView.PodcastDestination.broadcastList) {
                dockChip(
                    title: String(localized: "podcast_broadcast"),
                    value: "\(viewModel.broadcastChannels.count)",
                    icon: .radio,
                    tint: CapsuleStyle.mint
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func dockChip(title: String, value: String, icon: MonoIcon.IconType, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                MonoIcon(icon: icon, size: 15, color: tint, lineWidth: 1.7)

                Spacer(minLength: 0)

                Text(value)
                    .font(CapsuleStyle.labelFont(13, weight: .bold))
                    .foregroundStyle(CapsuleStyle.ink)
            }

            Text(title)
                .font(CapsuleStyle.labelFont(11, weight: .bold))
                .foregroundStyle(CapsuleStyle.inkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 72)
        .background(CapsuleSurfaceBackground(cornerRadius: 24, elevated: true, tint: CapsuleStyle.surfaceRaised.opacity(0.9)))
        .overlay(alignment: .bottomLeading) {
            Capsule()
                .fill(tint.opacity(0.85))
                .frame(width: 34, height: 5)
                .padding(.leading, 13)
                .padding(.bottom, 9)
        }
    }

    private var categoryRail: some View {
        VStack(alignment: .leading, spacing: 13) {
            CapsuleSectionTitle(title: String(localized: "分类"), tint: CapsuleStyle.violet) {
                NavigationLink(value: PodcastView.PodcastDestination.categoryBrowse) {
                    CapsulePillLabel(title: String(localized: "view_all"), icon: .chevronRight, tint: CapsuleStyle.violet)
                }
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(viewModel.categories.prefix(12)) { category in
                        NavigationLink(value: PodcastView.PodcastDestination.category(category)) {
                            categoryChip(category)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(16)
        .background(CapsuleSurfaceBackground(cornerRadius: 30, elevated: true, tint: CapsuleStyle.surface.opacity(0.9)))
    }

    private func categoryChip(_ category: RadioCategory) -> some View {
        HStack(spacing: 8) {
            MonoIcon(icon: category.monoIconType, size: 15, color: CapsuleStyle.violet, lineWidth: 1.7)

            Text(category.name)
                .font(CapsuleStyle.labelFont(12, weight: .bold))
                .foregroundStyle(CapsuleStyle.ink)
                .lineLimit(1)
        }
        .padding(.horizontal, 13)
        .frame(height: 38)
        .background(
            Capsule()
                .fill(CapsuleStyle.surfaceRaised.opacity(0.86))
                .overlay(Capsule().stroke(CapsuleStyle.separator.opacity(0.45), lineWidth: 0.8))
        )
    }

    private func programRail(
        title: String,
        tint: Color,
        programs: [PodcastCreative],
        destination: PodcastView.PodcastDestination?
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            CapsuleSectionTitle(title: title, tint: tint) {
                if let destination {
                    NavigationLink(value: destination) {
                        CapsulePillLabel(title: String(localized: "view_all"), icon: .chevronRight, tint: tint)
                    }
                    .buttonStyle(.plain)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(programs.enumerated()), id: \.offset) { index, program in
                        programCard(program, index: index, tint: tint)
                    }
                }
                .padding(.vertical, 3)
            }
        }
    }

    private func programCard(_ program: PodcastCreative, index: Int, tint: Color) -> some View {
        Button {
            if let radioId = programRadioId(program) {
                radioIdToOpen = radioId
                showRadioPlayer = true
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                capsuleCover(url: programCoverURL(program), size: CGSize(width: 148, height: 116), cornerRadius: 28, tint: tint)
                    .overlay(alignment: .topLeading) {
                        Text(String(format: "%02d", index + 1))
                            .font(CapsuleStyle.labelFont(10, weight: .black))
                            .foregroundStyle(CapsuleStyle.readableLabel(on: tint))
                            .padding(.horizontal, 9)
                            .frame(height: 24)
                            .background(Capsule().fill(tint))
                            .padding(9)
                    }

                VStack(alignment: .leading, spacing: 5) {
                    Text(programTitle(program))
                        .font(CapsuleStyle.bodyFont(14, weight: .bold))
                        .foregroundStyle(CapsuleStyle.ink)
                        .lineLimit(2)
                        .frame(height: 38, alignment: .topLeading)

                    Text(programSubtitle(program))
                        .font(CapsuleStyle.labelFont(11, weight: .medium))
                        .foregroundStyle(CapsuleStyle.inkMuted)
                        .lineLimit(1)
                }
            }
            .padding(10)
            .frame(width: 168, alignment: .leading)
            .background(CapsuleSurfaceBackground(cornerRadius: 30, elevated: true, tint: CapsuleStyle.surfaceRaised.opacity(0.92)))
        }
        .buttonStyle(CapsulePressStyle())
    }

    private var focusRadioPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            CapsuleSectionTitle(title: String(localized: "podcast_today_pick"), tint: CapsuleStyle.coral)

            let featured = Array(viewModel.todayPerfered.prefix(4))
            VStack(spacing: 10) {
                ForEach(Array(featured.enumerated()), id: \.element.id) { index, radio in
                    radioStripe(radio: radio, index: index, tint: index == 0 ? CapsuleStyle.coral : CapsuleStyle.mint)
                }
            }
        }
        .padding(16)
        .background(CapsuleSurfaceBackground(cornerRadius: 32, elevated: true, tint: CapsuleStyle.surface.opacity(0.92)))
    }

    private var hotPodcastPanel: some View {
        let radios = !viewModel.hotPodcasts.isEmpty
            ? viewModel.hotPodcasts.compactMap { $0.creativeExtInfoVO?.radio }
            : viewModel.recommendRadios

        return VStack(alignment: .leading, spacing: 14) {
            CapsuleSectionTitle(title: String(localized: "podcast_featured"), tint: CapsuleStyle.amber) {
                NavigationLink(value: PodcastView.PodcastDestination.topList(String(localized: "podcast_featured"), .hot)) {
                    CapsulePillLabel(title: String(localized: "view_all"), icon: .chevronRight, tint: CapsuleStyle.amber)
                }
                .buttonStyle(.plain)
            }

            LazyVGrid(columns: hotPodcastColumns, spacing: 12) {
                ForEach(radios.prefix(4)) { radio in
                    compactRadioCard(radio: radio, tint: CapsuleStyle.amber)
                }
            }
        }
        .padding(16)
        .background(CapsuleSurfaceBackground(cornerRadius: 32, elevated: true, tint: CapsuleStyle.surface.opacity(0.9)))
    }

    private var hotPodcastColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: 12),
            count: DeviceLayout.usesExpandedLayout ? 4 : 2
        )
    }

    private func radioRail(
        title: String,
        tint: Color,
        radios: [RadioStation],
        destination: PodcastView.PodcastDestination?
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            CapsuleSectionTitle(title: title, tint: tint) {
                if let destination {
                    NavigationLink(value: destination) {
                        CapsulePillLabel(title: String(localized: "view_all"), icon: .chevronRight, tint: tint)
                    }
                    .buttonStyle(.plain)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(radios) { radio in
                        compactRadioCard(radio: radio, tint: tint)
                            .frame(width: 158)
                    }
                }
                .padding(.vertical, 3)
            }
        }
    }

    private func compactRadioCard(radio: RadioStation, tint: Color) -> some View {
        NavigationLink(value: PodcastView.PodcastDestination.radioDetail(radio.id)) {
            VStack(alignment: .leading, spacing: 10) {
                capsuleCover(url: radio.coverUrl, size: CGSize(width: 138, height: 112), cornerRadius: 28, tint: tint)
                    .overlay(alignment: .bottomTrailing) {
                        Button {
                            radioIdToOpen = radio.id
                            showRadioPlayer = true
                        } label: {
                            MonoIcon(icon: .play, size: 13, color: CapsuleStyle.readableLabel(on: tint), lineWidth: 1.8)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(tint))
                                .overlay(Circle().stroke(Color.white.opacity(0.36), lineWidth: 0.8))
                        }
                        .buttonStyle(CapsulePressStyle())
                        .padding(8)
                    }

                Text(radio.name)
                    .font(CapsuleStyle.bodyFont(13.5, weight: .bold))
                    .foregroundStyle(CapsuleStyle.ink)
                    .lineLimit(2)
                    .frame(minHeight: 36, alignment: .topLeading)

                Text(radioCountText(radio))
                    .font(CapsuleStyle.labelFont(11, weight: .medium))
                    .foregroundStyle(CapsuleStyle.inkMuted)
                    .lineLimit(1)
            }
            .padding(10)
            .background(CapsuleSurfaceBackground(cornerRadius: 30, elevated: true, tint: CapsuleStyle.surfaceRaised.opacity(0.92)))
        }
        .buttonStyle(.plain)
    }

    private func radioStripe(radio: RadioStation, index: Int, tint: Color) -> some View {
        NavigationLink(value: PodcastView.PodcastDestination.radioDetail(radio.id)) {
            HStack(spacing: 12) {
                Text(String(format: "%02d", index + 1))
                    .font(CapsuleStyle.titleFont(16, weight: .black))
                    .foregroundStyle(tint)
                    .frame(width: 34)

                capsuleCover(url: radio.coverUrl, size: CGSize(width: 58, height: 58), cornerRadius: 18, tint: tint)

                VStack(alignment: .leading, spacing: 5) {
                    Text(radio.name)
                        .font(CapsuleStyle.bodyFont(15, weight: .bold))
                        .foregroundStyle(CapsuleStyle.ink)
                        .lineLimit(1)

                    Text(radio.dj?.nickname ?? radioCountText(radio))
                        .font(CapsuleStyle.labelFont(11, weight: .medium))
                        .foregroundStyle(CapsuleStyle.inkMuted)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                MonoIcon(icon: .chevronRight, size: 13, color: CapsuleStyle.inkMuted, lineWidth: 1.7)
            }
            .padding(10)
            .background(CapsuleSurfaceBackground(cornerRadius: 24, elevated: false, tint: CapsuleStyle.surfaceRaised.opacity(0.82)))
        }
        .buttonStyle(.plain)
    }

    private var chartProgramPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            CapsuleSectionTitle(title: String(localized: "音乐播客榜"), tint: CapsuleStyle.cyan)

            VStack(spacing: 10) {
                ForEach(Array(viewModel.chartPrograms.prefix(5).enumerated()), id: \.offset) { index, program in
                    programRankStripe(program: program, index: index, tint: CapsuleStyle.cyan)
                }
            }
        }
        .padding(16)
        .background(CapsuleSurfaceBackground(cornerRadius: 32, elevated: true, tint: CapsuleStyle.surface.opacity(0.9)))
    }

    private func programRankStripe(program: PodcastCreative, index: Int, tint: Color) -> some View {
        Button {
            if let radioId = programRadioId(program) {
                radioIdToOpen = radioId
                showRadioPlayer = true
            }
        } label: {
            HStack(spacing: 12) {
                Text(String(format: "%02d", index + 1))
                    .font(CapsuleStyle.titleFont(16, weight: .black))
                    .foregroundStyle(tint)
                    .frame(width: 34)

                capsuleCover(url: programCoverURL(program), size: CGSize(width: 58, height: 58), cornerRadius: 18, tint: tint)

                VStack(alignment: .leading, spacing: 5) {
                    Text(programTitle(program))
                        .font(CapsuleStyle.bodyFont(15, weight: .bold))
                        .foregroundStyle(CapsuleStyle.ink)
                        .lineLimit(1)

                    Text(programSubtitle(program))
                        .font(CapsuleStyle.labelFont(11, weight: .medium))
                        .foregroundStyle(CapsuleStyle.inkMuted)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                MonoIcon(icon: .play, size: 13, color: CapsuleStyle.inkSoft, lineWidth: 1.7)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(CapsuleStyle.surfaceTint))
            }
            .padding(10)
            .background(CapsuleSurfaceBackground(cornerRadius: 24, elevated: false, tint: CapsuleStyle.surfaceRaised.opacity(0.84)))
        }
        .buttonStyle(CapsulePressStyle())
    }

    private var programToplistPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            CapsuleSectionTitle(title: String(localized: "podcast_program_toplist"), tint: CapsuleStyle.violet)

            VStack(spacing: 10) {
                ForEach(Array(viewModel.programToplist.prefix(5).enumerated()), id: \.element.id) { index, program in
                    programToplistStripe(program: program, index: index)
                }
            }
        }
        .padding(16)
        .background(CapsuleSurfaceBackground(cornerRadius: 32, elevated: true, tint: CapsuleStyle.surface.opacity(0.9)))
    }

    private func programToplistStripe(program: RadioProgram, index: Int) -> some View {
        Button {
            if let radioId = program.radio?.id {
                radioIdToOpen = radioId
                showRadioPlayer = true
            }
        } label: {
            HStack(spacing: 12) {
                Text(String(format: "%02d", index + 1))
                    .font(CapsuleStyle.titleFont(16, weight: .black))
                    .foregroundStyle(CapsuleStyle.violet)
                    .frame(width: 34)

                capsuleCover(url: program.programCoverUrl, size: CGSize(width: 58, height: 58), cornerRadius: 18, tint: CapsuleStyle.violet)

                VStack(alignment: .leading, spacing: 5) {
                    Text(program.name ?? String(localized: "播客节目"))
                        .font(CapsuleStyle.bodyFont(15, weight: .bold))
                        .foregroundStyle(CapsuleStyle.ink)
                        .lineLimit(1)

                    Text(program.radio?.name ?? program.durationText)
                        .font(CapsuleStyle.labelFont(11, weight: .medium))
                        .foregroundStyle(CapsuleStyle.inkMuted)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                MonoIcon(icon: .play, size: 13, color: CapsuleStyle.inkSoft, lineWidth: 1.7)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(CapsuleStyle.surfaceTint))
            }
            .padding(10)
            .background(CapsuleSurfaceBackground(cornerRadius: 24, elevated: false, tint: CapsuleStyle.surfaceRaised.opacity(0.84)))
        }
        .buttonStyle(CapsulePressStyle())
    }

    private var broadcastRail: some View {
        VStack(alignment: .leading, spacing: 14) {
            CapsuleSectionTitle(title: String(localized: "podcast_broadcast"), tint: CapsuleStyle.mint) {
                NavigationLink(value: PodcastView.PodcastDestination.broadcastList) {
                    CapsulePillLabel(title: String(localized: "view_all"), icon: .chevronRight, tint: CapsuleStyle.mint)
                }
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.broadcastChannels) { channel in
                        broadcastCard(channel)
                    }
                }
                .padding(.vertical, 3)
            }
        }
    }

    private func broadcastCard(_ channel: BroadcastChannel) -> some View {
        Button {
            selectedBroadcastChannel = channel
        } label: {
            HStack(spacing: 12) {
                capsuleCover(url: channel.coverImageUrl, size: CGSize(width: 64, height: 64), cornerRadius: 22, tint: CapsuleStyle.mint)

                VStack(alignment: .leading, spacing: 7) {
                    Text(channel.displayName)
                        .font(CapsuleStyle.bodyFont(15, weight: .bold))
                        .foregroundStyle(CapsuleStyle.ink)
                        .lineLimit(1)

                    Text(channel.displayProgram ?? "FM")
                        .font(CapsuleStyle.labelFont(11, weight: .medium))
                        .foregroundStyle(CapsuleStyle.inkMuted)
                        .lineLimit(1)

                    Capsule()
                        .fill(LinearGradient(colors: [CapsuleStyle.mint, CapsuleStyle.cyan], startPoint: .leading, endPoint: .trailing))
                        .frame(width: 54, height: 5)
                }

                Spacer(minLength: 4)
            }
            .padding(12)
            .frame(width: 224, height: 94)
            .background(CapsuleSurfaceBackground(cornerRadius: 30, elevated: true, tint: CapsuleStyle.surfaceRaised.opacity(0.92)))
        }
        .buttonStyle(CapsulePressStyle())
    }

    private func capsuleCover(url: URL?, size: CGSize, cornerRadius: CGFloat, tint: Color) -> some View {
        CachedAsyncImage(url: url, width: size.width, height: size.height) {
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(CapsuleStyle.surfaceTint)

                MonoIcon(icon: .podcast, size: min(size.width, size.height) * 0.34, color: tint.opacity(0.7), lineWidth: 1.8)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(CapsuleStyle.hairline.opacity(0.72), lineWidth: 0.8)
        )
    }

    private var capsuleLoadingView: some View {
        VStack(spacing: 16) {
            CapsuleIconBadge(icon: .podcast, tint: CapsuleStyle.mint, size: 62)

            HStack(spacing: 7) {
                Capsule()
                    .fill(CapsuleStyle.accent)
                    .frame(width: 44, height: 7)
                Capsule()
                    .fill(CapsuleStyle.cyan.opacity(0.8))
                    .frame(width: 24, height: 7)
                Capsule()
                    .fill(CapsuleStyle.violet.opacity(0.75))
                    .frame(width: 34, height: 7)
            }
        }
    }

    @ViewBuilder
    private func destinationView(for destination: PodcastView.PodcastDestination) -> some View {
        switch destination {
        case let .category(category):
            CategoryRadioView(category: category)
        case let .radioDetail(radioId):
            RadioDetailView(radioId: radioId)
        case .search:
            PodcastSearchView()
        case let .topList(title, listType):
            TopRadioListView(title: title, listType: listType)
        case .categoryBrowse:
            RadioCategoryBrowseView()
        case .broadcastList:
            BroadcastListView()
        }
    }

    private func programTitle(_ program: PodcastCreative) -> String {
        program.uiElement?.mainTitle?.title
            ?? program.creativeExtInfoVO?.djProgram?.name
            ?? program.creativeExtInfoVO?.radio?.name
            ?? String(localized: "播客节目")
    }

    private func programSubtitle(_ program: PodcastCreative) -> String {
        program.creativeExtInfoVO?.djProgram?.radio?.name
            ?? program.creativeExtInfoVO?.djProgram?.dj?.nickname
            ?? program.creativeExtInfoVO?.radio?.dj?.nickname
            ?? program.creativeExtInfoVO?.radio?.category
            ?? "PODCAST"
    }

    private func programCoverURL(_ program: PodcastCreative) -> URL? {
        if let imageUrl = program.uiElement?.image?.imageUrl {
            return URL(string: imageUrl)
        }
        if let url = program.creativeExtInfoVO?.djProgram?.programCoverUrl {
            return url
        }
        return program.creativeExtInfoVO?.radio?.coverUrl
    }

    private func programRadioId(_ program: PodcastCreative) -> Int? {
        program.creativeExtInfoVO?.djProgram?.radio?.id
            ?? program.creativeExtInfoVO?.radio?.id
    }

    private func radioCountText(_ radio: RadioStation) -> String {
        if let count = radio.programCount, count > 0 {
            return String.localizedStringWithFormat(String(localized: "podcast_episode_count"), count)
        }
        if let count = radio.subCount, count > 0 {
            return compactCount(count)
        }
        return radio.category ?? "PODCAST"
    }

    private func compactCount(_ value: Int) -> String {
        if value >= 10_000 {
            return String(format: "%.1f万", Double(value) / 10_000.0)
        }
        return "\(value)"
    }
}
