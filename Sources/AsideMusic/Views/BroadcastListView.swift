import SwiftUI

/// 广播电台列表页（支持地区/分类筛选）
struct BroadcastListView: View {
    @StateObject private var viewModel = BroadcastListViewModel()
    @State private var selectedChannel: BroadcastChannel?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AsideBackground()

            VStack(spacing: 0) {
                // 地区筛选标签
                if !viewModel.regions.isEmpty {
                    regionFilter
                }

                if viewModel.isLoading && viewModel.channels.isEmpty {
                    Spacer()
                    AsideLoadingView(text: "LOADING")
                    Spacer()
                } else if viewModel.channels.isEmpty {
                    Spacer()
                    Text("暂无广播电台")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.asideTextSecondary)
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.channels) { channel in
                                channelRow(channel: channel)
                                    .onTapGesture {
                                        selectedChannel = channel
                                    }
                            }
                        }
                        .padding(.bottom, 100)
                    }
                }
            }
        }
        .navigationTitle("广播电台")
        .navigationBarTitleDisplayMode(.inline)
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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // "全部"按钮
                filterCapsule(title: "全部", isSelected: viewModel.selectedRegionId == "0") {
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
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }

    private func filterCapsule(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .medium, design: .rounded))
                .foregroundColor(isSelected ? .white : .asideTextPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.asideAccentBlue : Color.asideCardBackground)
                .clipShape(Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - 频道行

    private func channelRow(channel: BroadcastChannel) -> some View {
        HStack(spacing: 14) {
            // 封面
            if let url = channel.coverImageUrl {
                CachedAsyncImage(url: url) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.asideCardBackground)
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.asideCardBackground)
                    .frame(width: 56, height: 56)
                    .overlay(
                        AsideIcon(icon: .radio, size: 22, color: .asideTextSecondary, lineWidth: 1.4)
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(channel.displayName)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.asideTextPrimary)
                    .lineLimit(1)

                if let program = channel.displayProgram, !program.isEmpty {
                    Text(program)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.asideTextSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // FM 标识
            Text("FM")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.asideAccentBlue)

            AsideIcon(icon: .playCircle, size: 26, color: .asideTextSecondary, lineWidth: 1.4)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}
