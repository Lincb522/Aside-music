import SwiftUI

extension SearchView {
    // MARK: - 平台标签页

    @ViewBuilder
    var platformTabBar: some View {
        if MangaStyle.isActive {
            mangaPlatformTabBar
        } else if NeumorphicStyle.isActive {
            neumorphicPlatformTabBar
        } else if SignalStyle.isActive {
            signalPlatformTabBar
        } else if MujiStyle.isActive {
            mujiPlatformTabBar
        } else if SequoiaStyle.isActive {
            sequoiaPlatformTabBar
        } else if LiquidGlassStyle.isActive {
            liquidGlassPlatformTabBar
        } else if CapsuleStyle.isActive {
            capsulePlatformTabBar
        } else {
            // aside：胶囊分段的平台切换，平台色作为圆点标识
            let platforms = availableSearchPlatforms

            HStack(spacing: 3) {
                ForEach(platforms, id: \.self) { platform in
                    let selected = viewModel.selectedPlatform == platform
                    let tint = platform.themedBadgeColor

                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            viewModel.selectPlatform(platform)
                        }
                    }) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(tint)
                                .frame(width: 5.5, height: 5.5)
                                .opacity(selected ? 1 : 0.5)

                            Text(platformTabName(platform))
                                .font(.rounded(size: 12.5, weight: selected ? .bold : .medium))
                                .foregroundColor(
                                    selected
                                        ? .monoTextPrimary
                                        : .monoTextSecondary.opacity(0.8)
                                )
                        }
                        .padding(.horizontal, 13)
                        .padding(.vertical, 7)
                        .background {
                            if selected {
                                Capsule()
                                    .fill(Color.monoGlassTint.opacity(0.9))
                                    .shadow(color: .black.opacity(0.07), radius: 4, y: 1)
                            }
                        }
                        .contentShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(3)
            .background(
                Capsule().fill(Color.monoTextPrimary.opacity(0.045))
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.top, 2)
            .padding(.bottom, 8)
        }
    }

    /// Muji：平台切换 —— 水洗胶囊签，选中着色
    var mujiPlatformTabBar: some View {
        let platforms = availableSearchPlatforms

        return HStack(spacing: 9) {
            ForEach(platforms, id: \.self) { platform in
                let selected = viewModel.selectedPlatform == platform
                let tint = platform.themedBadgeColor

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewModel.selectPlatform(platform)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(selected ? tint : MujiStyle.inkMuted.opacity(0.4))
                            .frame(width: 4.5, height: 4.5)

                        Text(platformTabName(platform))
                            .font(MujiStyle.labelFont(11, weight: selected ? .semibold : .regular))
                            .foregroundStyle(selected ? MujiStyle.ink : MujiStyle.inkMuted)
                            .tracking(0.6)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(selected ? MujiStyle.wash(tint, strength: 1.3) : Color.clear)
                    )
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.bottom, viewModel.hasSearched ? 4 : 8)
    }

    var neumorphicPlatformTabBar: some View {
        let platforms = availableSearchPlatforms

        return HStack(spacing: 7) {
            ForEach(platforms, id: \.self) { platform in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewModel.selectPlatform(platform)
                    }
                } label: {
                    let tint = platform.themedBadgeColor
                    let selected = viewModel.selectedPlatform == platform
                    Text(platformTabName(platform))
                        .font(NeumorphicStyle.labelFont(viewModel.hasSearched ? 10.5 : 11, weight: .semibold))
                        .foregroundStyle(selected ? tint : tint.opacity(0.68))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, viewModel.hasSearched ? 6 : 8)
                        .background(
                            RoundedRectangle(cornerRadius: viewModel.hasSearched ? 8 : 10, style: .continuous)
                                .fill(selected ? tint.opacity(0.13) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(viewModel.hasSearched ? 4 : 5)
        .background(NeumorphicSurfaceBackground(cornerRadius: viewModel.hasSearched ? 13 : 15, elevated: false, pressed: true, lightweight: true))
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.bottom, viewModel.hasSearched ? 2 : 8)
    }

    var signalPlatformTabBar: some View {
        let platforms = availableSearchPlatforms

        return HStack(spacing: 7) {
            ForEach(platforms, id: \.self) { platform in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewModel.selectPlatform(platform)
                    }
                } label: {
                    let tint = platform.themedBadgeColor
                    let selected = viewModel.selectedPlatform == platform
                    Text(platformTabName(platform))
                        .font(SignalStyle.labelFont(viewModel.hasSearched ? 10.5 : 11, weight: .bold))
                        .foregroundStyle(selected ? tint : tint.opacity(0.72))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, viewModel.hasSearched ? 6 : 8)
                        .background(
                            RoundedRectangle(cornerRadius: viewModel.hasSearched ? 9 : 11, style: .continuous)
                                .fill(selected ? tint.opacity(0.14) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(viewModel.hasSearched ? 4 : 5)
        .background(SignalSurfaceBackground(cornerRadius: viewModel.hasSearched ? 14 : 16, elevated: false, pressed: true, fill: SignalStyle.controlPressed))
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.bottom, viewModel.hasSearched ? 2 : 8)
    }

    var sequoiaPlatformTabBar: some View {
        let platforms = availableSearchPlatforms

        return HStack(spacing: 6) {
            ForEach(platforms, id: \.self) { platform in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.84)) {
                        viewModel.selectPlatform(platform)
                    }
                } label: {
                    let tint = platform.themedBadgeColor
                    let selected = viewModel.selectedPlatform == platform
                    HStack(spacing: 6) {
                        Circle()
                            .fill(tint)
                            .frame(width: 6, height: 6)
                        Text(platformTabName(platform))
                            .font(SequoiaStyle.labelFont(viewModel.hasSearched ? 10.5 : 11, weight: selected ? .semibold : .medium))
                            .foregroundStyle(selected ? SequoiaStyle.ink : SequoiaStyle.inkSoft)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, viewModel.hasSearched ? 7 : 8)
                    .background {
                        if selected {
                            Capsule()
                                .fill(tint.opacity(0.13))
                                .matchedGeometryEffect(id: "platform-tab", in: sequoiaSearchNamespace)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(SequoiaSurfaceBackground(cornerRadius: viewModel.hasSearched ? 14 : 16, elevated: false, role: .list))
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.bottom, viewModel.hasSearched ? 3 : 8)
    }

    var mangaPlatformTabBar: some View {
        // 去卡片化：平台色短划 + 文字，选中压底部色线
        let platforms = availableSearchPlatforms

        return HStack(spacing: 0) {
            ForEach(platforms, id: \.self) { platform in
                let tint = platform.themedBadgeColor
                let selected = viewModel.selectedPlatform == platform
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewModel.selectPlatform(platform)
                    }
                } label: {
                    VStack(spacing: 5) {
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 1, style: .continuous)
                                .fill(tint)
                                .frame(width: 10, height: 3.5)
                                .opacity(selected ? 1 : 0.45)

                            Text(platformTabName(platform))
                                .font(MangaStyle.labelFont(11, weight: selected ? .black : .bold))
                                .foregroundStyle(selected ? MangaStyle.ink : MangaStyle.inkMuted)
                        }

                        Rectangle()
                            .fill(selected ? tint : Color.clear)
                            .frame(height: 2)
                            .padding(.horizontal, 14)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 7)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.bottom, 8)
    }

    var liquidGlassPlatformTabBar: some View {
        let platforms = availableSearchPlatforms

        return HStack(spacing: 7) {
            ForEach(platforms, id: \.self) { platform in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.84)) {
                        viewModel.selectPlatform(platform)
                    }
                } label: {
                    let tint = platform.themedBadgeColor
                    let selected = viewModel.selectedPlatform == platform
                    HStack(spacing: 6) {
                        Circle()
                            .fill(tint.opacity(selected ? 0.9 : 0.42))
                            .frame(width: 6, height: 6)
                        Text(platformTabName(platform))
                            .font(LiquidGlassStyle.labelFont(viewModel.hasSearched ? 10.5 : 11.5, weight: .semibold))
                            .foregroundStyle(selected ? LiquidGlassStyle.ink : LiquidGlassStyle.inkSoft)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, viewModel.hasSearched ? 7 : 8)
                    .background(
                        Capsule()
                            .fill(selected ? tint.opacity(0.13) : Color.clear)
                            .overlay(Capsule().stroke(selected ? tint.opacity(0.26) : Color.clear, lineWidth: 0.55))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(LiquidGlassSurfaceBackground(cornerRadius: viewModel.hasSearched ? 15 : 17, elevated: false, pressed: true, role: .list))
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.bottom, viewModel.hasSearched ? 3 : 8)
    }

    var capsulePlatformTabBar: some View {
        let platforms = availableSearchPlatforms

        return HStack(spacing: 7) {
            ForEach(platforms, id: \.self) { platform in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.84)) {
                        viewModel.selectPlatform(platform)
                    }
                } label: {
                    let tint = platform.themedBadgeColor
                    let selected = viewModel.selectedPlatform == platform
                    HStack(spacing: 6) {
                        Capsule()
                            .fill(tint.opacity(selected ? 0.95 : 0.42))
                            .frame(width: selected ? 18 : 7, height: 6)
                            .animation(.spring(response: 0.28, dampingFraction: 0.82), value: selected)

                        Text(platformTabName(platform))
                            .font(CapsuleStyle.labelFont(viewModel.hasSearched ? 10.5 : 11.5, weight: selected ? .bold : .semibold))
                            .foregroundStyle(selected ? CapsuleStyle.ink : CapsuleStyle.inkSoft)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, viewModel.hasSearched ? 7 : 8)
                    .background(
                        Capsule()
                            .fill(selected ? tint.opacity(0.13) : Color.clear)
                            .overlay(Capsule().stroke(selected ? tint.opacity(0.24) : Color.clear, lineWidth: 0.7))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(CapsuleSurfaceBackground(cornerRadius: viewModel.hasSearched ? 15 : 18, elevated: true, tint: CapsuleStyle.surface.opacity(0.78)))
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.bottom, viewModel.hasSearched ? 3 : 8)
    }

    func platformTabName(_ source: MusicSource) -> String {
        switch source {
        case .netease: return "NCM"
        case .qqmusic: return "QCM"
        case .qishui: return "QSM"
        case .kugou: return "KCM"
        case .appleMusic: return "AM"
        case .local: return "Local"
        }
    }

    var availableSearchPlatforms: [MusicSource] {
        switch viewModel.currentTab {
        case .songs:
            return [.netease, .qqmusic, .qishui, .kugou, .appleMusic]
        case .artists, .playlists, .albums:
            return [.netease, .qqmusic, .kugou, .appleMusic]
        case .mvs:
            return [.netease, .qqmusic, .kugou]
        }
    }

    var isPlatformLoading: Bool {
        switch viewModel.selectedPlatform {
        case .netease: return viewModel.isNeteaseLoading
        case .qqmusic: return viewModel.isQQLoading
        case .qishui: return viewModel.isQishuiLoading
        case .kugou: return viewModel.isKugouLoading
        case .appleMusic: return viewModel.isAppleMusicLoading
        case .local: return false
        }
    }

    var isPlatformEmpty: Bool {
        switch viewModel.selectedPlatform {
        case .netease:
            switch viewModel.currentTab {
            case .songs: return viewModel.neteaseResults.isEmpty
            case .artists: return viewModel.neteaseArtistResults.isEmpty
            case .playlists: return viewModel.neteasePlaylistResults.isEmpty
            case .albums: return viewModel.neteaseAlbumResults.isEmpty
            case .mvs: return viewModel.neteaseMVResults.isEmpty
            }
        case .qqmusic:
            switch viewModel.currentTab {
            case .songs: return viewModel.qqResults.isEmpty
            case .artists: return viewModel.qqArtistResults.isEmpty
            case .playlists: return viewModel.qqPlaylistResults.isEmpty
            case .albums: return viewModel.qqAlbumResults.isEmpty
            case .mvs: return viewModel.qqMVResults.isEmpty
            }
        case .qishui: return viewModel.qishuiResults.isEmpty
        case .kugou:
            switch viewModel.currentTab {
            case .songs: return viewModel.kugouResults.isEmpty
            case .artists: return viewModel.kugouArtistResults.isEmpty
            case .playlists: return viewModel.kugouPlaylistResults.isEmpty
            case .albums: return viewModel.kugouAlbumResults.isEmpty
            case .mvs: return viewModel.kugouMVResults.isEmpty
            }
        case .appleMusic:
            switch viewModel.currentTab {
            case .songs: return viewModel.appleMusicResults.isEmpty
            case .artists: return viewModel.appleMusicArtistResults.isEmpty
            case .playlists: return viewModel.appleMusicPlaylistResults.isEmpty
            case .albums: return viewModel.appleMusicAlbumResults.isEmpty
            case .mvs: return true
            }
        case .local: return true
        }
    }

}
