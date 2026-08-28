import SwiftUI

extension SearchView {
    // MARK: - 搜索建议浮层

    @ViewBuilder
    var suggestionsOverlay: some View {
        if viewModel.showSuggestions && !viewModel.suggestions.isEmpty {
            if MangaStyle.isActive {
                themedSuggestionsOverlay
            } else if MujiStyle.isActive {
                themedSuggestionsOverlay
            } else if NeumorphicStyle.isActive {
                neumorphicSuggestionsOverlay
            } else if SequoiaStyle.isActive {
                sequoiaSuggestionsOverlay
            } else if CapsuleStyle.isActive {
                themedSuggestionsOverlay
            } else {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(viewModel.suggestions, id: \.self) { suggestion in
                                HStack(spacing: 12) {
                                    MonoIcon(icon: .magnifyingGlass, size: 14, color: .monoTextSecondary)

                                    Text(suggestion)
                                        .font(.rounded(size: 15, weight: .regular))
                                        .foregroundColor(.monoTextPrimary)
                                        .lineLimit(1)

                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    isFocused = false
                                    viewModel.performSearch(keyword: suggestion)
                                }

                                if suggestion != viewModel.suggestions.last {
                                    Divider()
                                        .opacity(0.4)
                                        .padding(.horizontal, 16)
                                }
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .scrollDismissesKeyboard(.never)
                    .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
                    .frame(maxHeight: 320)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .monoGlass(cornerRadius: 16)
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, suggestionsTopPadding)
                .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
                .animation(.spring(response: 0.3, dampingFraction: 0.85), value: viewModel.showSuggestions)
            }
        }
    }

    var themedSuggestionsOverlay: some View {
        ScrollView {
            VStack(spacing: suggestionsRowSpacing) {
                ForEach(viewModel.suggestions, id: \.self) { suggestion in
                    Button {
                        isFocused = false
                        viewModel.performSearch(keyword: suggestion)
                    } label: {
                        HStack(spacing: 11) {
                            suggestionsIcon

                            Text(suggestion)
                                .font(suggestionsFont)
                                .foregroundStyle(suggestionsPrimaryColor)
                                .lineLimit(1)

                            Spacer(minLength: 8)

                            MonoIcon(icon: .chevronRight, size: 10, color: suggestionsSecondaryColor, lineWidth: 1.5)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background { suggestionsRowBackground }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(MangaStyle.isActive ? 11 : 10)
        }
        .scrollDismissesKeyboard(.never)
        .scrollIndicators(.hidden)
        .themeRenderScrollLayer()
        .frame(maxHeight: 328)
        .background { suggestionsPanelBackground }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, suggestionsTopPadding)
        .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: viewModel.showSuggestions)
    }

    var suggestionsRowSpacing: CGFloat {
        return MangaStyle.isActive ? 8 : 7
    }

    var suggestionsFont: Font {
        if MangaStyle.isActive { return MangaStyle.comicFont(14, weight: .bold) }
        if MujiStyle.isActive { return MujiStyle.bodyFont(15, weight: .regular) }
        if CapsuleStyle.isActive { return CapsuleStyle.bodyFont(15, weight: .semibold) }
        return .rounded(size: 15, weight: .regular)
    }

    var suggestionsPrimaryColor: Color {
        if MangaStyle.isActive { return MangaStyle.ink }
        if MujiStyle.isActive { return MujiStyle.ink }
        if CapsuleStyle.isActive { return CapsuleStyle.ink }
        return .monoTextPrimary
    }

    var suggestionsSecondaryColor: Color {
        if MangaStyle.isActive { return MangaStyle.inkMuted }
        if MujiStyle.isActive { return MujiStyle.inkMuted }
        if CapsuleStyle.isActive { return CapsuleStyle.inkMuted }
        return .monoTextSecondary.opacity(0.5)
    }

    @ViewBuilder
    var suggestionsIcon: some View {
        if MangaStyle.isActive {
            MangaSectionMark(kind: .star, tint: MangaStyle.labelYellow)
                .frame(width: 30, height: 30)
        } else if MujiStyle.isActive {
            MonoIcon(icon: .magnifyingGlass, size: 13, color: MujiStyle.clay, lineWidth: 1.5)
                .frame(width: 30, height: 30)
        } else if CapsuleStyle.isActive {
            MonoIcon(icon: .magnifyingGlass, size: 13, color: CapsuleStyle.accent, lineWidth: 1.6)
                .frame(width: 30, height: 30)
                .background(CapsuleStyle.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            MonoIcon(icon: .magnifyingGlass, size: 13, color: .monoTextSecondary, lineWidth: 1.5)
        }
    }

    @ViewBuilder
    var suggestionsRowBackground: some View {
        if MangaStyle.isActive {
            // 去卡片化：候选词行只留底部细墨线
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                Rectangle()
                    .fill(MangaStyle.strokeInk.opacity(0.14))
                    .frame(height: 1)
                    .padding(.horizontal, 4)
            }
        } else if MujiStyle.isActive {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                MujiListDivider()
                    .padding(.horizontal, 4)
            }
        } else if CapsuleStyle.isActive {
            CapsuleSurfaceBackground(cornerRadius: 16, elevated: false, tint: CapsuleStyle.surfaceRaised.opacity(0.86))
        } else {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.monoTextPrimary.opacity(0.06))
        }
    }

    @ViewBuilder
    var suggestionsPanelBackground: some View {
        if MangaStyle.isActive {
            MangaCardBackground(cornerRadius: MangaStyle.cardRadius + 4, elevated: true)
        } else if MujiStyle.isActive {
            MujiPaperCardBackground(cornerRadius: 13, elevated: true)
        } else if CapsuleStyle.isActive {
            CapsuleSurfaceBackground(cornerRadius: 24, elevated: true, tint: CapsuleStyle.surface.opacity(0.94))
        } else {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.monoGlassTint)
                .monoGlass(cornerRadius: 18)
        }
    }

    var neumorphicSuggestionsOverlay: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(viewModel.suggestions, id: \.self) { suggestion in
                    Button {
                        isFocused = false
                        viewModel.performSearch(keyword: suggestion)
                    } label: {
                        HStack(spacing: 11) {
                            MonoIcon(icon: .magnifyingGlass, size: 13, color: NeumorphicStyle.accent, lineWidth: 1.55)
                                .frame(width: 30, height: 30)
                                .background(NeumorphicSurfaceBackground(cornerRadius: 11, elevated: false, pressed: true, lightweight: true))

                            Text(suggestion)
                                .font(NeumorphicStyle.bodyFont(15, weight: .medium))
                                .foregroundStyle(NeumorphicStyle.ink)
                                .lineLimit(1)

                            Spacer(minLength: 8)

                            MonoIcon(icon: .chevronRight, size: 10, color: NeumorphicStyle.inkMuted, lineWidth: 1.5)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(NeumorphicSurfaceBackground(cornerRadius: 17, elevated: false, pressed: true, lightweight: true))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
        }
        .scrollDismissesKeyboard(.never)
        .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        .frame(maxHeight: 328)
        .background(NeumorphicSurfaceBackground(cornerRadius: 24, elevated: true))
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, suggestionsTopPadding)
        .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: viewModel.showSuggestions)
    }

    var sequoiaSuggestionsOverlay: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(viewModel.suggestions.enumerated()), id: \.element) { index, suggestion in
                    Button {
                        isFocused = false
                        viewModel.performSearch(keyword: suggestion)
                    } label: {
                        HStack(spacing: 11) {
                            MonoIcon(icon: .magnifyingGlass, size: 13, color: SequoiaStyle.accent, lineWidth: 1.48)
                                .frame(width: 30, height: 30)
                                .background(SequoiaSurfaceBackground(cornerRadius: 11, elevated: false, role: .list))

                            Text(suggestion)
                                .font(SequoiaStyle.bodyFont(15, weight: .medium))
                                .foregroundStyle(SequoiaStyle.ink)
                                .lineLimit(1)

                            Spacer(minLength: 8)

                            MonoIcon(icon: .chevronRight, size: 10, color: SequoiaStyle.inkMuted, lineWidth: 1.45)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < viewModel.suggestions.count - 1 {
                        Divider()
                            .overlay(SequoiaStyle.separator)
                            .padding(.leading, 54)
                    }
                }
            }
            .padding(.vertical, 7)
        }
        .scrollDismissesKeyboard(.never)
        .scrollIndicators(.hidden)
        .themeRenderScrollLayer()
        .frame(maxHeight: 328)
        .background(SequoiaSurfaceBackground(cornerRadius: 22, elevated: true, role: .chrome))
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, suggestionsTopPadding)
        .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: viewModel.showSuggestions)
    }
}
