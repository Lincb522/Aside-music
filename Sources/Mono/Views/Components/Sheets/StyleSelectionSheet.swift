import SwiftUI

// MARK: - Daily Recommend Type Panel

struct StyleSelectionMorphView: View {
    enum Placement {
        case standalone
        case attachedToHeader
    }

    @ObservedObject var styleManager: StyleManager
    @ObservedObject private var settings = SettingsManager.shared
    @Binding var isPresented: Bool
    var placement: Placement = .standalone

    @State private var tempSelectedStyle: APIService.StyleTag?
    @State private var selectedCategory: DailyRecommendStyleCategory = .genre
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var tabNamespace

    private let columns = [GridItem(.adaptive(minimum: 66, maximum: 96), spacing: 10)]

    var body: some View {
        let _ = settings.globalThemeRevision
        panelContent
            .background {
                if drawsOwnChrome {
                    panelBackground
                }
            }
            .clipShape(panelShape)
            .overlay {
                if drawsOwnChrome {
                    panelStroke
                }
            }
            .shadow(color: panelShadowColor, radius: panelShadowRadius, x: 0, y: panelShadowY)
            .padding(.horizontal, panelHorizontalPadding)
            .padding(.top, panelTopPadding)
            .onAppear {
                syncTemporarySelection()
            }
            .onChange(of: isPresented) { _, newValue in
                if newValue {
                    syncTemporarySelection()
                }
            }
    }

    private var panelContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !isAttachedToHeader {
                panelHeader
            }
            categoryTabs

            Group {
                if styleManager.isLoadingStyles {
                    loadingView
                } else {
                    styleGrid
                }
            }

            actionBar
        }
    }

    private var panelHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                dismiss()
            } label: {
                HStack(spacing: 7) {
                    Text(tempSelectedStyle?.localizedDisplayName ?? String(localized: "style_default"))
                        .font(headerFont)
                        .foregroundStyle(primaryTextColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    MonoIcon(icon: .chevronRight, size: 11, color: secondaryTextColor)
                        .rotationEffect(.degrees(-90))
                }
                .padding(.horizontal, currentPillHorizontalPadding)
                .padding(.vertical, currentPillVerticalPadding)
                .background(currentPillFill, in: currentPillShape)
                .overlay(currentPillStroke)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 8)
        }
        .padding(.horizontal, innerHorizontalPadding)
        .padding(.top, headerTopPadding)
        .padding(.bottom, 10)
    }

    private var categoryTabs: some View {
        ScrollView(.horizontal) {
            HStack(spacing: MangaStyle.isActive ? 12 : 18) {
                ForEach(DailyRecommendStyleCategory.allCases) { category in
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.86)) {
                            selectedCategory = category
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Text(category.title)
                                .font(tabFont(isSelected: selectedCategory == category))
                                .foregroundStyle(selectedCategory == category ? tabSelectedColor : tabNormalColor)
                                .lineLimit(1)

                            ZStack {
                                Capsule()
                                    .fill(Color.clear)
                                    .frame(width: 22, height: indicatorHeight)

                                if selectedCategory == category {
                                    Capsule()
                                        .fill(tabIndicatorColor)
                                        .frame(width: MangaStyle.isActive ? 24 : 20, height: indicatorHeight)
                                        .matchedGeometryEffect(id: "daily_style_tab_indicator", in: tabNamespace)
                                }
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, innerHorizontalPadding)
        }
        .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        .padding(.top, isAttachedToHeader ? 12 : 0)
        .padding(.bottom, 12)
    }

    private var loadingView: some View {
        VStack {
            ProgressView()
                .tint(selectionTint)
                .frame(width: 44, height: 44)
        }
        .frame(maxWidth: .infinity)
        .frame(height: gridHeight)
    }

    private var styleGrid: some View {
        ScrollView(.vertical) {
            LazyVGrid(columns: columns, spacing: 10) {
                if selectedCategory == .genre {
                    tagButton(
                        name: String(localized: "style_default"),
                        isSelected: tempSelectedStyle == nil,
                        tint: selectionTint
                    ) {
                        tempSelectedStyle = nil
                    }
                }

                ForEach(Array(visibleStyles.enumerated()), id: \.element.id) { index, style in
                    tagButton(
                        name: style.localizedDisplayName,
                        isSelected: tempSelectedStyle?.id == style.id,
                        tint: tagTint(for: index)
                    ) {
                        tempSelectedStyle = style
                    }
                }

                if visibleStyles.isEmpty && selectedCategory != .genre {
                    emptyCategoryView
                        .gridCellColumns(3)
                }
            }
            .padding(.horizontal, innerHorizontalPadding)
            .padding(.top, 2)
            .padding(.bottom, 8)
            .animation(.spring(response: 0.28, dampingFraction: 0.9), value: selectedCategory)
        }
        .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        .frame(height: gridHeight)
        .transition(.opacity.combined(with: .move(edge: .trailing)))
    }

    private var emptyCategoryView: some View {
        Text(LocalizedStringKey("style_category_empty"))
            .font(emptyFont)
            .foregroundStyle(secondaryTextColor)
            .frame(maxWidth: .infinity, minHeight: 96)
    }

    private func tagButton(
        name: String,
        isSelected: Bool,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.88)) {
                action()
            }
        } label: {
            Text(name)
                .font(tagFont(isSelected: isSelected))
                .foregroundStyle(isSelected ? selectedTagForeground : primaryTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
                .frame(maxWidth: .infinity)
                .frame(height: tagHeight)
                .padding(.horizontal, 7)
                .background(tagBackground(isSelected: isSelected, tint: tint))
                .overlay(tagStroke(isSelected: isSelected, tint: tint))
                .contentShape(RoundedRectangle(cornerRadius: tagRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Text(LocalizedStringKey("cancel"))
                    .font(actionFont(isPrimary: false))
                    .foregroundStyle(secondaryTextColor)
                    .frame(maxWidth: .infinity)
                    .frame(height: actionHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                styleManager.selectStyle(tempSelectedStyle)
                dismiss()
            } label: {
                Text(LocalizedStringKey("style_confirm"))
                    .font(actionFont(isPrimary: true))
                    .foregroundStyle(confirmForeground)
                    .frame(maxWidth: .infinity)
                    .frame(height: actionHeight)
                    .background(confirmFill, in: confirmShape)
                    .overlay(confirmStroke)
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.985, opacity: 0.94))
        }
        .padding(.horizontal, innerHorizontalPadding)
        .padding(.top, 12)
        .padding(.bottom, actionBottomPadding)
    }

    private var visibleStyles: [APIService.StyleTag] {
        let styles = styleManager.availableStyles.filter { style in
            selectedCategory.matches(style)
        }

        if selectedCategory == .genre {
            let nonGenreUnmatched = styleManager.availableStyles.filter { style in
                DailyRecommendStyleCategory.category(for: style) == .genre
            }
            return styles.isEmpty ? nonGenreUnmatched : styles
        }

        return styles
    }

    private func category(for style: APIService.StyleTag?) -> DailyRecommendStyleCategory {
        guard let style else { return .genre }
        return DailyRecommendStyleCategory.category(for: style)
    }

    private func syncTemporarySelection() {
        tempSelectedStyle = styleManager.currentStyle
        selectedCategory = category(for: styleManager.currentStyle)
    }

    private func dismiss() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
            isPresented = false
        }
    }

    @ViewBuilder
    private var panelBackground: some View {
        if MangaStyle.isActive {
            panelShape
                .fill(MangaStyle.bubbleWhite)
                .overlay(
                    MangaDotsTexture(opacity: 0.024, gap: 12)
                        .clipShape(panelShape)
                )
        } else if MujiStyle.isActive {
            panelShape
                .fill(MujiStyle.surfaceRaised)
                .overlay(
                    MujiPaperTexture(opacity: colorScheme == .dark ? 0.07 : 0.12)
                        .clipShape(panelShape)
                )
        } else if NeumorphicStyle.isActive {
            panelShape
                .fill(NeumorphicStyle.surface)
                .overlay(NeumorphicReliefTexture(opacity: colorScheme == .dark ? 0.035 : 0.055).clipShape(panelShape))
        } else if SequoiaStyle.isActive {
            panelShape
                .fill(.ultraThinMaterial)
                .overlay(panelShape.fill(SequoiaStyle.materialFloating.opacity(colorScheme == .dark ? 0.86 : 0.74)))
                .overlay(
                    LinearGradient(
                        colors: [
                            SequoiaStyle.highlight(colorScheme).opacity(0.34),
                            .clear,
                            SequoiaStyle.accent.opacity(0.035)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(panelShape)
                )
        } else {
            panelShape
                .fill(Color(light: .white.opacity(0.92), dark: Color(hex: "1E2028").opacity(0.92)))
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.04 : 0.3),
                            Color.monoGlassTint.opacity(colorScheme == .dark ? 0.16 : 0.42)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(panelShape)
                )
        }
    }

    private var panelShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: isAttachedToHeader ? 0 : panelRadius,
            bottomLeadingRadius: panelRadius,
            bottomTrailingRadius: panelRadius,
            topTrailingRadius: isAttachedToHeader ? 0 : panelRadius,
            style: .continuous
        )
    }

    @ViewBuilder
    private var panelStroke: some View {
        if MangaStyle.isActive {
            if isAttachedToHeader {
                MangaConnectedPanelOutline(radius: panelRadius)
                    .stroke(MangaStyle.strokeInk, lineWidth: MangaStyle.strokeWidth)
            } else {
                panelShape.stroke(MangaStyle.strokeInk, lineWidth: 1.8)
            }
        } else if MujiStyle.isActive {
            if isAttachedToHeader {
                MangaConnectedPanelOutline(radius: panelRadius)
                    .stroke(MujiStyle.hairline.opacity(colorScheme == .dark ? 0.48 : 0.64), lineWidth: 0.7)
            } else {
                panelShape.stroke(MujiStyle.hairline.opacity(colorScheme == .dark ? 0.48 : 0.64), lineWidth: 0.7)
            }
        } else if NeumorphicStyle.isActive {
            if isAttachedToHeader {
                MangaConnectedPanelOutline(radius: panelRadius)
                    .stroke(NeumorphicStyle.separator.opacity(0.42), lineWidth: 0.8)
            } else {
                panelShape.stroke(NeumorphicStyle.lightShadow(colorScheme, intensity: 0.64), lineWidth: 0.8)
            }
        } else if SequoiaStyle.isActive {
            if isAttachedToHeader {
                MangaConnectedPanelOutline(radius: panelRadius)
                    .stroke(SequoiaStyle.separator.opacity(0.62), lineWidth: 0.7)
            } else {
                panelShape.stroke(SequoiaStyle.separator.opacity(0.76), lineWidth: 0.7)
            }
        } else {
            if isAttachedToHeader {
                MangaConnectedPanelOutline(radius: panelRadius)
                    .stroke(Color.monoSeparator.opacity(0.54), lineWidth: 0.8)
            } else {
                panelShape.stroke(Color.monoSeparator.opacity(0.76), lineWidth: 0.8)
            }
        }
    }

    private var currentPillShape: some Shape {
        RoundedRectangle(cornerRadius: MangaStyle.isActive ? 12 : (MujiStyle.isActive ? 8 : ((NeumorphicStyle.isActive || SequoiaStyle.isActive) ? 14 : 15)), style: .continuous)
    }

    @ViewBuilder
    private var currentPillStroke: some View {
        if MangaStyle.isActive {
            currentPillShape.stroke(MangaStyle.strokeInk, lineWidth: 1.1)
        } else if MujiStyle.isActive {
            currentPillShape.stroke(MujiStyle.hairline.opacity(0.44), lineWidth: 0.6)
        } else if NeumorphicStyle.isActive {
            currentPillShape.stroke(NeumorphicStyle.separator.opacity(0.38), lineWidth: 0.7)
        } else if SequoiaStyle.isActive {
            currentPillShape.stroke(SequoiaStyle.separator.opacity(0.54), lineWidth: 0.6)
        }
    }

    private func tagBackground(isSelected: Bool, tint: Color) -> some View {
        Group {
            if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(
                    cornerRadius: tagRadius,
                    elevated: isSelected,
                    pressed: !isSelected,
                    tint: isSelected ? tint.opacity(0.2) : NeumorphicStyle.surface
                )
            } else if SequoiaStyle.isActive {
                SequoiaSurfaceBackground(
                    cornerRadius: tagRadius,
                    elevated: isSelected,
                    pressed: !isSelected,
                    fill: isSelected ? tint.opacity(0.13) : SequoiaStyle.materialList,
                    role: isSelected ? .selected : .list
                )
            } else {
                RoundedRectangle(cornerRadius: tagRadius, style: .continuous)
                    .fill(isSelected ? tint : tagFill)
            }
        }
    }

    private func tagStroke(isSelected: Bool, tint: Color) -> some View {
        RoundedRectangle(cornerRadius: tagRadius, style: .continuous)
            .stroke(isSelected ? selectedTagStroke(tint) : tagBorder, lineWidth: tagStrokeWidth(isSelected: isSelected))
    }

    private var confirmShape: some Shape {
        RoundedRectangle(cornerRadius: confirmRadius, style: .continuous)
    }

    @ViewBuilder
    private var confirmStroke: some View {
        if MangaStyle.isActive {
            confirmShape.stroke(MangaStyle.strokeInk, lineWidth: 1.55)
        } else if MujiStyle.isActive {
            confirmShape.stroke(MujiStyle.hairline.opacity(0.28), lineWidth: 0.6)
        } else if SequoiaStyle.isActive {
            confirmShape.stroke(SequoiaStyle.luminousSeparator.opacity(0.26), lineWidth: 0.55)
        }
    }

    private func tagTint(for index: Int) -> Color {
        if MangaStyle.isActive {
            return [MangaStyle.labelYellow, MangaStyle.bubblePink, MangaStyle.bubbleBlue, MangaStyle.mint][index % 4]
        }

        if MujiStyle.isActive {
            return [MujiStyle.clay, MujiStyle.tea, MujiStyle.indigo, MujiStyle.straw][index % 4]
        }

        if NeumorphicStyle.isActive {
            return [NeumorphicStyle.accent, NeumorphicStyle.sage, NeumorphicStyle.warm, NeumorphicStyle.red][index % 4]
        }

        if SequoiaStyle.isActive {
            return [SequoiaStyle.accent, SequoiaStyle.aqua, SequoiaStyle.green, SequoiaStyle.violet][index % 4]
        }

        return [Color(hex: "D7264D"), Color(hex: "E85C72"), Color(hex: "C6315B"), Color(hex: "EC7890")][index % 4]
    }

    private func selectedTagStroke(_ tint: Color) -> Color {
        if MangaStyle.isActive { return MangaStyle.strokeInk }
        if MujiStyle.isActive { return tint.opacity(0.18) }
        if NeumorphicStyle.isActive { return tint.opacity(0.28) }
        if SequoiaStyle.isActive { return tint.opacity(0.26) }
        return tint.opacity(0.18)
    }

    private func tagStrokeWidth(isSelected: Bool) -> CGFloat {
        if MangaStyle.isActive { return isSelected ? 1.35 : 1.0 }
        if NeumorphicStyle.isActive { return isSelected ? 0.55 : 0.4 }
        return isSelected ? 0.4 : 0.65
    }

    private func tagFont(isSelected: Bool) -> Font {
        if MangaStyle.isActive { return MangaStyle.labelFont(12, weight: .black) }
        if MujiStyle.isActive { return MujiStyle.labelFont(12, weight: isSelected ? .semibold : .regular) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(12, weight: isSelected ? .semibold : .medium) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(12, weight: isSelected ? .semibold : .medium) }
        return .system(size: 12, weight: isSelected ? .semibold : .medium, design: .rounded)
    }

    private func tabFont(isSelected: Bool) -> Font {
        if MangaStyle.isActive { return MangaStyle.labelFont(13, weight: .black) }
        if MujiStyle.isActive { return MujiStyle.labelFont(13, weight: isSelected ? .semibold : .regular) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(13, weight: isSelected ? .semibold : .medium) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(13, weight: isSelected ? .semibold : .medium) }
        return .system(size: 13, weight: isSelected ? .semibold : .medium, design: .rounded)
    }

    private func actionFont(isPrimary: Bool) -> Font {
        if MangaStyle.isActive { return MangaStyle.labelFont(14, weight: .black) }
        if MujiStyle.isActive { return MujiStyle.labelFont(14, weight: isPrimary ? .semibold : .regular) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(14, weight: isPrimary ? .semibold : .medium) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(14, weight: isPrimary ? .semibold : .medium) }
        return .system(size: 14, weight: isPrimary ? .bold : .medium, design: .rounded)
    }

    private var headerFont: Font {
        if MangaStyle.isActive { return MangaStyle.labelFont(15, weight: .black) }
        if MujiStyle.isActive { return MujiStyle.labelFont(15, weight: .semibold) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(15, weight: .semibold) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(15, weight: .semibold) }
        return .system(size: 15, weight: .semibold, design: .rounded)
    }

    private var currentFont: Font {
        if MangaStyle.isActive { return MangaStyle.labelFont(11, weight: .black) }
        if MujiStyle.isActive { return MujiStyle.labelFont(11, weight: .regular) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(11, weight: .medium) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(11, weight: .medium) }
        return .system(size: 11, weight: .medium, design: .rounded)
    }

    private var emptyFont: Font {
        if MangaStyle.isActive { return MangaStyle.bodyFont(13, weight: .bold) }
        if MujiStyle.isActive { return MujiStyle.labelFont(13, weight: .regular) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(13, weight: .medium) }
        if SequoiaStyle.isActive { return SequoiaStyle.labelFont(13, weight: .regular) }
        return .system(size: 13, weight: .medium, design: .rounded)
    }

    private var primaryTextColor: Color {
        if MangaStyle.isActive { return MangaStyle.ink }
        if MujiStyle.isActive { return MujiStyle.ink }
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        if SequoiaStyle.isActive { return SequoiaStyle.ink }
        return .monoTextPrimary
    }

    private var secondaryTextColor: Color {
        if MangaStyle.isActive { return MangaStyle.inkSub }
        if MujiStyle.isActive { return MujiStyle.inkSoft }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        return .monoTextSecondary
    }

    private var tabSelectedColor: Color {
        if MangaStyle.isActive { return MangaStyle.strokeInk }
        if MujiStyle.isActive { return MujiStyle.ink }
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        if SequoiaStyle.isActive { return SequoiaStyle.ink }
        return .monoTextPrimary
    }

    private var tabNormalColor: Color {
        if MangaStyle.isActive { return MangaStyle.inkSub }
        if MujiStyle.isActive { return MujiStyle.inkSoft }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        return .monoTextSecondary
    }

    private var tabIndicatorColor: Color {
        if MangaStyle.isActive { return MangaStyle.bubblePink }
        if MujiStyle.isActive { return MujiStyle.clay }
        if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
        if SequoiaStyle.isActive { return SequoiaStyle.accent }
        return Color(hex: "D7264D")
    }

    private var selectionTint: Color {
        if MangaStyle.isActive { return MangaStyle.bubblePink }
        if MujiStyle.isActive { return MujiStyle.clay }
        if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
        if SequoiaStyle.isActive { return SequoiaStyle.accent }
        return Color(hex: "D7264D")
    }

    private var selectedTagForeground: Color {
        if MangaStyle.isActive { return MangaStyle.strokeInk }
        if MujiStyle.isActive { return MujiStyle.onTint }
        if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
        if SequoiaStyle.isActive { return SequoiaStyle.onAccent }
        return .white
    }

    private var tagFill: Color {
        if MangaStyle.isActive { return MangaStyle.bubbleWhite.opacity(0.9) }
        if MujiStyle.isActive { return MujiStyle.surface.opacity(0.84) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.surfacePressed.opacity(0.72) }
        if SequoiaStyle.isActive { return SequoiaStyle.materialList.opacity(0.72) }
        return Color.monoGlassTint.opacity(0.64)
    }

    private var tagBorder: Color {
        if MangaStyle.isActive { return MangaStyle.strokeInk.opacity(0.68) }
        if MujiStyle.isActive { return MujiStyle.hairline.opacity(0.42) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.separator.opacity(0.4) }
        if SequoiaStyle.isActive { return SequoiaStyle.separator.opacity(0.52) }
        return Color.monoSeparator.opacity(0.42)
    }

    private var currentPillFill: Color {
        if MangaStyle.isActive { return MangaStyle.bubbleBlue.opacity(0.72) }
        if MujiStyle.isActive { return MujiStyle.surface.opacity(0.76) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.surfacePressed.opacity(0.8) }
        if SequoiaStyle.isActive { return SequoiaStyle.materialList.opacity(0.82) }
        return Color.monoSeparator.opacity(0.42)
    }

    private var confirmFill: Color {
        if MangaStyle.isActive { return MangaStyle.labelYellow }
        if MujiStyle.isActive { return MujiStyle.clay }
        if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
        if SequoiaStyle.isActive { return SequoiaStyle.accent }
        return Color(hex: "D7264D")
    }

    private var confirmForeground: Color {
        if MangaStyle.isActive { return MangaStyle.strokeInk }
        if MujiStyle.isActive { return MujiStyle.onTint }
        if NeumorphicStyle.isActive { return Color(light: .white, dark: .black) }
        if SequoiaStyle.isActive { return SequoiaStyle.onAccent }
        return .white
    }

    private var panelRadius: CGFloat {
        if MangaStyle.isActive { return 22 }
        if MujiStyle.isActive { return 14 }
        if NeumorphicStyle.isActive { return 22 }
        if SequoiaStyle.isActive { return 22 }
        return 20
    }

    private var tagRadius: CGFloat {
        if MangaStyle.isActive { return 12 }
        if MujiStyle.isActive { return 8 }
        if NeumorphicStyle.isActive { return 14 }
        if SequoiaStyle.isActive { return 14 }
        return 12
    }

    private var confirmRadius: CGFloat {
        if MangaStyle.isActive { return 15 }
        if MujiStyle.isActive { return 20 }
        if NeumorphicStyle.isActive { return 18 }
        if SequoiaStyle.isActive { return 18 }
        return 20
    }

    private var panelHorizontalPadding: CGFloat {
        isAttachedToHeader ? 0 : (MangaStyle.isActive ? DeviceLayout.viewHorizontalPadding : 0)
    }

    private var innerHorizontalPadding: CGFloat {
        MangaStyle.isActive ? 14 : DeviceLayout.viewHorizontalPadding
    }

    private var headerTopPadding: CGFloat {
        if isAttachedToHeader { return MangaStyle.isActive ? 14 : 12 }
        return MangaStyle.isActive ? 16 : 18
    }

    private var actionBottomPadding: CGFloat {
        if isAttachedToHeader { return MangaStyle.isActive ? 18 : 20 }
        return MangaStyle.isActive ? 18 : 16
    }

    private var currentPillHorizontalPadding: CGFloat {
        MangaStyle.isActive ? 10 : 11
    }

    private var currentPillVerticalPadding: CGFloat {
        MangaStyle.isActive ? 7 : 6
    }

    private var tagHeight: CGFloat {
        MangaStyle.isActive ? 34 : 32
    }

    private var actionHeight: CGFloat {
        MangaStyle.isActive ? 42 : 40
    }

    private var gridHeight: CGFloat {
        DeviceLayout.isPad ? 310 : 246
    }

    private var indicatorHeight: CGFloat {
        MangaStyle.isActive ? 4 : 3
    }

    private var panelShadowRadius: CGFloat {
        if NeumorphicStyle.isActive { return isAttachedToHeader ? 0 : 18 }
        if isAttachedToHeader { return MujiStyle.isActive ? 10 : 0 }
        return MangaStyle.isActive ? 0 : 14
    }

    private var panelShadowY: CGFloat {
        if NeumorphicStyle.isActive { return isAttachedToHeader ? 0 : 10 }
        if isAttachedToHeader { return MujiStyle.isActive ? 5 : 0 }
        return MangaStyle.isActive ? 0 : 8
    }

    private var panelShadowColor: Color {
        if !drawsOwnChrome { return .clear }
        if isAttachedToHeader { return MujiStyle.isActive ? Color.black.opacity(colorScheme == .dark ? 0.025 : 0.045) : .clear }
        if MangaStyle.isActive { return .clear }
        if MujiStyle.isActive { return Color.black.opacity(colorScheme == .dark ? 0.05 : 0.08) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.darkShadow(colorScheme, intensity: 0.5) }
        return Color.black.opacity(0.12)
    }

    private var isAttachedToHeader: Bool {
        placement == .attachedToHeader
    }

    private var drawsOwnChrome: Bool {
        !isAttachedToHeader || MangaStyle.isActive
    }

    private var panelTopPadding: CGFloat {
        isAttachedToHeader ? 0 : (MangaStyle.isActive ? 4 : 0)
    }
}

struct MangaConnectedHeaderOutline: Shape {
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + radius),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + radius, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        return path
    }
}

struct MangaConnectedPanelOutline: Shape {
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + radius, y: rect.maxY),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY - radius),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

private enum DailyRecommendStyleCategory: String, CaseIterable, Identifiable {
    case genre
    case mood
    case scene
    case language
    case theme

    var id: String { rawValue }

    var title: String {
        switch self {
        case .genre: return String(localized: "style_tab_genre")
        case .mood: return String(localized: "style_tab_mood")
        case .scene: return String(localized: "style_tab_scene")
        case .language: return String(localized: "style_tab_language")
        case .theme: return String(localized: "style_tab_theme")
        }
    }

    func matches(_ style: APIService.StyleTag) -> Bool {
        Self.category(for: style) == self
    }

    static func category(for style: APIService.StyleTag) -> DailyRecommendStyleCategory {
        DailyRecommendStyleCategory(rawValue: style.categoryRawValue) ?? .genre
    }
}
