import SwiftUI

/// 广播电台列表页（支持地区/分类筛选）
struct BroadcastListView: View {
    @State private var viewModel = BroadcastListViewModel()
    @ObservedObject private var settings = SettingsManager.shared
    @State private var selectedChannel: BroadcastChannel?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let _ = settings.globalThemeRevision

        ZStack {
            ThemedPageBackground()

            VStack(spacing: 0) {
                // 地区筛选标签
                if !viewModel.regions.isEmpty {
                    regionFilter
                }

                if viewModel.isLoading && viewModel.channels.isEmpty {
                    Spacer()
                    MonologueLoadingView(text: "LOADING")
                    Spacer()
                } else if viewModel.channels.isEmpty {
                    Spacer()
                    Text(LocalizedStringKey("broadcast_no_stations"))
                        .font(SequoiaStyle.isActive ? SequoiaStyle.labelFont(14, weight: .regular) : .system(size: 14, design: .rounded))
                        .foregroundColor(SequoiaStyle.isActive ? SequoiaStyle.inkSoft : .monologueTextSecondary)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: ThemedPageStyle.listSpacing) {
                            ForEach(viewModel.channels) { channel in
                                channelRow(channel: channel)
                                    .onTapWithHaptic {
                                        selectedChannel = channel
                                    }
                            }
                        }
                        .padding(.horizontal, ThemedPageStyle.horizontalInset)
                        .padding(.top, ThemedPageStyle.isActive ? 4 : 0)
                        .padding(.bottom, 100)
                    }
                    .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
                }
            }
        }
        .themedNavigationChrome(title: NSLocalizedString("broadcast_title", comment: ""), eyebrow: "RADIO", icon: .radio)
        .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear {
            if viewModel.channels.isEmpty {
                viewModel.fetchData()
            }
        }
        .fullScreenCover(item: $selectedChannel) { channel in
            BroadcastPlayerView(channel: channel)
        }
    }

    // MARK: - 地区筛选

    private var regionFilter: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                // "全部"按钮
                filterCapsule(title: NSLocalizedString("broadcast_all", comment: ""), isSelected: viewModel.selectedRegionId == "0") {
                    viewModel.selectRegion("0")
                }

                ForEach(viewModel.regions) { region in
                    filterCapsule(
                        title: region.name ?? "",
                        isSelected: viewModel.selectedRegionId == String(region.id)
                    ) {
                        viewModel.selectRegion(String(region.id))
                    }
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.vertical, 12)
        }
        .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
    }

    private func filterCapsule(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(chipFont(isSelected: isSelected))
                .foregroundColor(chipTextColor(isSelected: isSelected))
                .padding(.horizontal, (NeumorphicStyle.isActive || SequoiaStyle.isActive) ? 16 : 14)
                .padding(.vertical, (NeumorphicStyle.isActive || SequoiaStyle.isActive) ? 9 : 8)
                .background(chipBackground(isSelected: isSelected))
                .clipShape(Capsule())
                .overlay {
                    if MangaStyle.isActive {
                        Capsule()
                            .stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.strokeWidth)
                    } else if MujiStyle.isActive {
                        Capsule()
                            .stroke(MujiStyle.hairline.opacity(0.45), lineWidth: 0.6)
                    } else if SequoiaStyle.isActive {
                        Capsule()
                            .stroke((isSelected ? SequoiaStyle.accent : SequoiaStyle.separator).opacity(0.45), lineWidth: 0.55)
                    }
                }
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func chipFont(isSelected: Bool) -> Font {
        if MangaStyle.isActive { return MangaStyle.labelFont(13, weight: isSelected ? .black : .bold) }
        if MujiStyle.isActive { return MujiStyle.labelFont(13, weight: isSelected ? .semibold : .regular) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(13, weight: isSelected ? .semibold : .medium) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(13, weight: isSelected ? .semibold : .medium) }
        return .system(size: 13, weight: isSelected ? .semibold : .medium, design: .rounded)
    }

    private func chipTextColor(isSelected: Bool) -> Color {
        if MangaStyle.isActive { return isSelected ? MangaStyle.ink : MangaStyle.inkSub }
        if MujiStyle.isActive { return isSelected ? MujiStyle.paper : MujiStyle.ink }
        if NeumorphicStyle.isActive { return isSelected ? NeumorphicStyle.accent : NeumorphicStyle.inkSoft }
        if SequoiaStyle.isActive { return isSelected ? SequoiaStyle.onAccent : SequoiaStyle.inkSoft }
        return isSelected ? .white : .monologueTextPrimary
    }

    @ViewBuilder
    private func chipBackground(isSelected: Bool) -> some View {
        if MangaStyle.isActive {
            Capsule().fill(isSelected ? MangaStyle.labelYellow : MangaStyle.bubbleWhite)
        } else if MujiStyle.isActive {
            Capsule().fill(isSelected ? MujiStyle.clay : MujiStyle.surfaceRaised)
        } else if NeumorphicStyle.isActive {
            NeumorphicSurfaceBackground(
                cornerRadius: 16,
                elevated: isSelected,
                pressed: !isSelected,
                tint: isSelected ? NeumorphicStyle.accent.opacity(0.16) : NeumorphicStyle.surface
            )
        } else if SequoiaStyle.isActive {
            Capsule()
                .fill(isSelected ? SequoiaStyle.accent : SequoiaStyle.materialList.opacity(0.76))
        } else {
            Capsule().fill(isSelected ? Color.monologueTextPrimary : Color.monologueGlassTint)
        }
    }

    // MARK: - 频道行

    private func channelRow(channel: BroadcastChannel) -> some View {
        HStack(spacing: 14) {
            // 封面
            if let url = channel.coverImageUrl {
                CachedAsyncImage(url: url) {
                    RoundedRectangle(cornerRadius: coverRadius)
                        .fill(coverPlaceholderFill)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: coverRadius, style: .continuous))
                .overlay(coverStroke)
            } else {
                RoundedRectangle(cornerRadius: coverRadius, style: .continuous)
                    .fill(coverPlaceholderFill)
                    .frame(width: 56, height: 56)
                    .overlay(
                        MonologueIcon(icon: .radio, size: 22, color: SequoiaStyle.isActive ? SequoiaStyle.aqua : (NeumorphicStyle.isActive ? NeumorphicStyle.sage : .monologueTextSecondary), lineWidth: 1.4)
                    )
                    .overlay(coverStroke)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(channel.displayName)
                    .font(rowTitleFont)
                    .foregroundColor(primaryTextColor)
                    .lineLimit(1)

                if let program = channel.displayProgram, !program.isEmpty {
                    Text(program)
                        .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(12, weight: .medium) : .system(size: 12, design: .rounded))
                        .foregroundColor(secondaryTextColor)
                        .lineLimit(1)
                }
            }

            Spacer()

            // FM 标识
            if NeumorphicStyle.isActive {
                NeumorphicPill(text: "FM", tint: NeumorphicStyle.sage, compact: true)
            } else if SequoiaStyle.isActive {
                SequoiaPill(text: "FM", icon: .radio, tint: SequoiaStyle.aqua, compact: true)
            } else {
                Text("FM")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.monologueTextSecondary)
            }

            MonologueIcon(icon: .playCircle, size: 26, color: SequoiaStyle.isActive ? SequoiaStyle.accent : (NeumorphicStyle.isActive ? NeumorphicStyle.accent : .monologueTextSecondary), lineWidth: 1.4)
        }
        .padding(.horizontal, ThemedPageStyle.isActive ? 16 : DeviceLayout.viewHorizontalPadding)
        .padding(.vertical, 10)
        .themedOnlyPageSurface(cornerRadius: ThemedPageStyle.compactSurfaceCornerRadius, elevated: false)
        .contentShape(Rectangle())
    }

    private var coverRadius: CGFloat {
        (NeumorphicStyle.isActive || SequoiaStyle.isActive) ? 14 : 12
    }

    @ViewBuilder
    private var coverStroke: some View {
        if NeumorphicStyle.isActive {
            RoundedRectangle(cornerRadius: coverRadius, style: .continuous)
                .stroke(NeumorphicStyle.separator.opacity(0.5), lineWidth: 0.7)
        } else if SequoiaStyle.isActive {
            RoundedRectangle(cornerRadius: coverRadius, style: .continuous)
                .stroke(SequoiaStyle.separator.opacity(0.78), lineWidth: 0.6)
        }
    }

    private var rowTitleFont: Font {
        if NeumorphicStyle.isActive { return NeumorphicStyle.bodyFont(15, weight: .semibold) }
        if SequoiaStyle.isActive { return SequoiaStyle.bodyFont(15, weight: .semibold) }
        return .system(size: 15, weight: .medium, design: .rounded)
    }

    private var primaryTextColor: Color {
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        if SequoiaStyle.isActive { return SequoiaStyle.ink }
        return .monologueTextPrimary
    }

    private var secondaryTextColor: Color {
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        return .monologueTextSecondary
    }

    private var coverPlaceholderFill: Color {
        if NeumorphicStyle.isActive { return NeumorphicStyle.surfacePressed }
        if SequoiaStyle.isActive { return SequoiaStyle.materialList }
        return Color.monologueGlassTint
    }
}
