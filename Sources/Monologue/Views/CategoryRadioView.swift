import SwiftUI

/// 分类电台列表页面
struct CategoryRadioView: View {
    let category: RadioCategory
    @StateObject private var viewModel: CategoryRadioViewModel
    @ObservedObject private var settings = SettingsManager.shared
    @Environment(\.dismiss) private var dismiss

    init(category: RadioCategory) {
        self.category = category
        _viewModel = StateObject(wrappedValue: CategoryRadioViewModel(category: category))
    }

    var body: some View {
        let _ = settings.globalThemeRevision

        ZStack {
            ThemedPageBackground()
                .ignoresSafeArea()

            if viewModel.isLoading && viewModel.radios.isEmpty {
                MonologueLoadingView(text: MinimalWhiteStyle.isActive ? nil : "LOADING")
            } else if viewModel.radios.isEmpty {
                // 空状态
                VStack(spacing: 12) {
                    if MinimalWhiteStyle.isActive {
                        MinimalWhiteIconBadge(icon: .micSlash, size: 54)
                    } else {
                        MonologueIcon(icon: .micSlash, size: 40, color: emptyStateColor)
                    }
                    Text("radio_empty")
                        .font(emptyStateFont)
                        .foregroundColor(emptyStateColor)
                }
                .padding(.vertical, 44)
                .frame(maxWidth: .infinity)
                .background {
                    if MinimalWhiteStyle.isActive {
                        MinimalWhiteSurfaceBackground(
                            cornerRadius: MinimalWhiteStyle.cardRadius,
                            elevated: false,
                            tint: MinimalWhiteStyle.glassFill
                        )
                    }
                }
                .padding(.horizontal, MinimalWhiteStyle.isActive ? DeviceLayout.viewHorizontalPadding : 0)
            } else {
                ScrollView {
                    LazyVStack(spacing: ThemedPageStyle.listSpacing) {
                        ForEach(viewModel.radios) { radio in
                            NavigationLink(value: PodcastView.PodcastDestination.radioDetail(radio.id)) {
                                radioRow(radio: radio)
                            }
                            .buttonStyle(.plain)

                            // 滚动到底部自动加载
                            if radio.id == viewModel.radios.last?.id {
                                Color.clear
                                    .frame(height: 1)
                                    .onAppear {
                                        viewModel.loadMore()
                                    }
                            }
                        }

                        if viewModel.isLoadingMore {
                            ProgressView()
                                .padding(.vertical, 16)
                        }

                        if !viewModel.hasMore && !viewModel.radios.isEmpty {
                            NoMoreDataView()
                        }
                    }
                    .padding(.horizontal, ThemedPageStyle.horizontalInset)
                    .padding(.top, ThemedPageStyle.isActive ? 8 : 0)
                    .padding(.bottom, 120)
                }
                .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
            }
        }
        .themedNavigationChrome(title: category.name, eyebrow: "RADIO", icon: .radio)
        .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear {
            if viewModel.radios.isEmpty {
                viewModel.fetchRadios()
            }
        }
    }

    // MARK: - 电台行

    @ViewBuilder
    private func radioRow(radio: RadioStation) -> some View {
        if !ThemedPageStyle.isActive {
            AsideRadioListRow(radio: radio)
        } else {
            legacyRadioRow(radio: radio)
        }
    }

    private func legacyRadioRow(radio: RadioStation) -> some View {
        HStack(spacing: 14) {
            CachedAsyncImage(url: radio.coverUrl) {
                RoundedRectangle(cornerRadius: coverRadius, style: .continuous)
                    .fill(coverPlaceholderFill)
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: coverRadius, style: .continuous))
            .overlay(coverStroke)

            VStack(alignment: .leading, spacing: 4) {
                Text(radio.name)
                    .font(rowTitleFont)
                    .foregroundColor(primaryTextColor)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let dj = radio.dj?.nickname {
                        Text(dj)
                            .font(rowMetaFont)
                            .foregroundColor(secondaryTextColor)
                            .lineLimit(1)
                    }
                    if let count = radio.programCount {
                        Text(String(format: String(localized: "podcast_episode_count"), count))
                            .font(rowMetaFont)
                            .foregroundColor(tertiaryTextColor)
                    }
                }
            }

            Spacer()

            MonologueIcon(icon: .chevronRight, size: 12, color: accentColor, lineWidth: 1.2)
        }
        .padding(.horizontal, ThemedPageStyle.isActive ? 16 : 20)
        .padding(.vertical, 12)
        .themedOnlyPageSurface(cornerRadius: ThemedPageStyle.compactSurfaceCornerRadius, elevated: false)
    }

    private var coverRadius: CGFloat {
        if MinimalWhiteStyle.isActive { return 12 }
        return (NeumorphicStyle.isActive || SequoiaStyle.isActive) ? 14 : 10
    }

    @ViewBuilder
    private var coverStroke: some View {
        if NeumorphicStyle.isActive {
            RoundedRectangle(cornerRadius: coverRadius, style: .continuous)
                .stroke(NeumorphicStyle.separator.opacity(0.5), lineWidth: 0.7)
        } else if SequoiaStyle.isActive {
            RoundedRectangle(cornerRadius: coverRadius, style: .continuous)
                .stroke(SequoiaStyle.separator.opacity(0.78), lineWidth: 0.6)
        } else if MinimalWhiteStyle.isActive {
            RoundedRectangle(cornerRadius: coverRadius, style: .continuous)
                .stroke(MinimalWhiteStyle.hairline, lineWidth: MinimalWhiteStyle.strokeWidth)
        }
    }

    private var rowTitleFont: Font {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.bodyFont(15, weight: .medium) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.bodyFont(15, weight: .semibold) }
        if SequoiaStyle.isActive { return SequoiaStyle.bodyFont(15, weight: .semibold) }
        return .system(size: 15, weight: .medium, design: .rounded)
    }

    private var rowMetaFont: Font {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.labelFont(12, weight: .regular) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(12, weight: .medium) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(12, weight: .regular) }
        return .system(size: 12, design: .rounded)
    }

    private var emptyStateFont: Font {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.labelFont(14, weight: .medium) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(16, weight: .medium) }
        return .system(size: 16, weight: .medium, design: .rounded)
    }

    private var primaryTextColor: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.ink }
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        if SequoiaStyle.isActive { return SequoiaStyle.ink }
        return .monologueTextPrimary
    }

    private var secondaryTextColor: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.inkMuted }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        return .monologueTextSecondary
    }

    private var tertiaryTextColor: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.inkMuted }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkMuted }
        if SequoiaStyle.isActive { return SequoiaStyle.inkMuted }
        return .monologueTextSecondary
    }

    private var emptyStateColor: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.inkMuted }
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        return .monologueTextSecondary
    }

    private var accentColor: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.inkMuted }
        if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
        if SequoiaStyle.isActive { return SequoiaStyle.accent }
        return .monologueTextSecondary
    }

    private var coverPlaceholderFill: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.controlGlassFill }
        if NeumorphicStyle.isActive { return NeumorphicStyle.surfacePressed }
        if SequoiaStyle.isActive { return SequoiaStyle.materialList }
        return Color.monologueGlassTint
    }
}
