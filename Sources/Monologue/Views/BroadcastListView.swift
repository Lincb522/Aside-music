import SwiftUI

/// 广播电台列表页（支持地区/分类筛选）
struct BroadcastListView: View {
    @State private var viewModel = BroadcastListViewModel()
    @State private var selectedChannel: BroadcastChannel?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
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
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.monologueTextSecondary)
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
                .padding(.horizontal, NeumorphicStyle.isActive ? 16 : 14)
                .padding(.vertical, NeumorphicStyle.isActive ? 9 : 8)
                .background(chipBackground(isSelected: isSelected))
                .clipShape(Capsule())
                .overlay {
                    if MangaStyle.isActive {
                        Capsule()
                            .stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.strokeWidth)
                    } else if MujiStyle.isActive {
                        Capsule()
                            .stroke(MujiStyle.hairline.opacity(0.45), lineWidth: 0.6)
                    }
                }
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func chipFont(isSelected: Bool) -> Font {
        if MangaStyle.isActive { return MangaStyle.labelFont(13, weight: isSelected ? .black : .bold) }
        if MujiStyle.isActive { return MujiStyle.labelFont(13, weight: isSelected ? .semibold : .regular) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(13, weight: isSelected ? .semibold : .medium) }
        return .system(size: 13, weight: isSelected ? .semibold : .medium, design: .rounded)
    }

    private func chipTextColor(isSelected: Bool) -> Color {
        if MangaStyle.isActive { return isSelected ? MangaStyle.ink : MangaStyle.inkSub }
        if MujiStyle.isActive { return isSelected ? MujiStyle.paper : MujiStyle.ink }
        if NeumorphicStyle.isActive { return isSelected ? NeumorphicStyle.accent : NeumorphicStyle.inkSoft }
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
                        .fill(NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.monologueGlassTint)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: coverRadius, style: .continuous))
                .overlay(coverStroke)
            } else {
                RoundedRectangle(cornerRadius: coverRadius, style: .continuous)
                    .fill(NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.monologueGlassTint)
                    .frame(width: 56, height: 56)
                    .overlay(
                        MonologueIcon(icon: .radio, size: 22, color: NeumorphicStyle.isActive ? NeumorphicStyle.sage : .monologueTextSecondary, lineWidth: 1.4)
                    )
                    .overlay(coverStroke)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(channel.displayName)
                    .font(NeumorphicStyle.isActive ? NeumorphicStyle.bodyFont(15, weight: .semibold) : .system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.ink : .monologueTextPrimary)
                    .lineLimit(1)

                if let program = channel.displayProgram, !program.isEmpty {
                    Text(program)
                        .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(12, weight: .medium) : .system(size: 12, design: .rounded))
                        .foregroundColor(NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : .monologueTextSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // FM 标识
            if NeumorphicStyle.isActive {
                NeumorphicPill(text: "FM", tint: NeumorphicStyle.sage, compact: true)
            } else {
                Text("FM")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.monologueTextSecondary)
            }

            MonologueIcon(icon: .playCircle, size: 26, color: NeumorphicStyle.isActive ? NeumorphicStyle.accent : .monologueTextSecondary, lineWidth: 1.4)
        }
        .padding(.horizontal, ThemedPageStyle.isActive ? 16 : DeviceLayout.viewHorizontalPadding)
        .padding(.vertical, 10)
        .themedOnlyPageSurface(cornerRadius: ThemedPageStyle.compactSurfaceCornerRadius, elevated: false)
        .contentShape(Rectangle())
    }

    private var coverRadius: CGFloat {
        NeumorphicStyle.isActive ? 14 : 12
    }

    @ViewBuilder
    private var coverStroke: some View {
        if NeumorphicStyle.isActive {
            RoundedRectangle(cornerRadius: coverRadius, style: .continuous)
                .stroke(NeumorphicStyle.separator.opacity(0.5), lineWidth: 0.7)
        }
    }
}
