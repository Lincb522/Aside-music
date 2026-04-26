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
    }

    private func filterCapsule(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .medium, design: .rounded))
                            .foregroundColor(isSelected ? (MangaStyle.isActive ? MangaStyle.ink : .white) : .monologueTextPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
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

    private func chipBackground(isSelected: Bool) -> Color {
        if MangaStyle.isActive {
            return isSelected ? MangaStyle.labelYellow : MangaStyle.bubbleWhite
        } else if MujiStyle.isActive {
            return isSelected ? MujiStyle.clay : MujiStyle.surfaceRaised
        } else {
            return isSelected ? Color.monologueTextPrimary : Color.monologueGlassTint
        }
    }

    // MARK: - 频道行

    private func channelRow(channel: BroadcastChannel) -> some View {
        HStack(spacing: 14) {
            // 封面
            if let url = channel.coverImageUrl {
                CachedAsyncImage(url: url) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.monologueGlassTint)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.monologueGlassTint)
                    .frame(width: 56, height: 56)
                    .overlay(
                        MonologueIcon(icon: .radio, size: 22, color: .monologueTextSecondary, lineWidth: 1.4)
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(channel.displayName)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.monologueTextPrimary)
                    .lineLimit(1)

                if let program = channel.displayProgram, !program.isEmpty {
                    Text(program)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.monologueTextSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // FM 标识
            Text("FM")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.monologueTextSecondary)

            MonologueIcon(icon: .playCircle, size: 26, color: .monologueTextSecondary, lineWidth: 1.4)
        }
        .padding(.horizontal, ThemedPageStyle.isActive ? 16 : DeviceLayout.viewHorizontalPadding)
        .padding(.vertical, 10)
        .themedOnlyPageSurface(cornerRadius: ThemedPageStyle.compactSurfaceCornerRadius, elevated: false)
        .contentShape(Rectangle())
    }
}
