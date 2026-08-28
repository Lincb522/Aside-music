import SwiftUI

extension SearchView {
    // MARK: - 搜索历史 & 热搜

    @ViewBuilder
    var emptySearchView: some View {
        if MinimalWhiteStyle.isActive {
            minimalWhiteEmptySearchView
        } else if MangaStyle.isActive {
            mangaEmptySearchView
        } else if PetWhiteStyle.isActive {
            petWhiteEmptySearchView
        } else if NeumorphicStyle.isActive {
            neumorphicEmptySearchView
        } else if MujiStyle.isActive {
            mujiEmptySearchView
        } else if SequoiaStyle.isActive {
            sequoiaEmptySearchView
        } else if CapsuleStyle.isActive {
            capsuleEmptySearchView
        } else {
            defaultEmptySearchView
        }
    }

    // MARK: - aside 待搜索页：历史胶囊 + 热搜榜单

    var defaultEmptySearchView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                // 搜索历史：可换行的胶囊，长按可单个删除
                if !viewModel.searchHistory.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        defaultSearchSectionHeader(
                            title: String(localized: "search_history")
                        ) {
                            Button {
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                                    viewModel.clearAllHistory()
                                }
                            } label: {
                                MonoIcon(icon: .trash, size: 14, color: .monoTextSecondary.opacity(0.75))
                                    .frame(width: 30, height: 30)
                                    .background(
                                        Circle().fill(Color.monoTextPrimary.opacity(0.05))
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }

                        FlowLayout(spacing: 9) {
                            ForEach(viewModel.searchHistory, id: \.id) { item in
                                Button {
                                    viewModel.performSearch(keyword: item.keyword)
                                    isFocused = false
                                } label: {
                                    Text(item.keyword)
                                        .font(.rounded(size: 13.5, weight: .medium))
                                        .foregroundColor(.monoTextPrimary.opacity(0.88))
                                        .lineLimit(1)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8.5)
                                        .background(
                                            Capsule().fill(Color.monoTextPrimary.opacity(0.055))
                                        )
                                        .overlay(
                                            Capsule().stroke(Color.monoTextPrimary.opacity(0.06), lineWidth: 1)
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                                .contextMenu {
                                    Button(role: .destructive) {
                                        viewModel.deleteHistoryItem(keyword: item.keyword)
                                    } label: {
                                        Label(String(localized: "删除"), systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }

                // 热门搜索：双列榜单，前三名号码用强调色
                if !viewModel.hotSearchItems.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        defaultSearchSectionHeader(
                            title: String(localized: "search_hot")
                        ) { EmptyView() }
                            .padding(.bottom, 6)

                        let items = Array(viewModel.hotSearchItems.prefix(20))
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 22),
                                GridItem(.flexible(), spacing: 0),
                            ],
                            alignment: .leading,
                            spacing: 2
                        ) {
                            ForEach(Array(items.enumerated()), id: \.element.searchWord) { index, item in
                                Button {
                                    viewModel.performSearch(keyword: item.searchWord)
                                    isFocused = false
                                } label: {
                                    HStack(spacing: 11) {
                                        Text("\(index + 1)")
                                            .font(.system(size: 14.5, weight: .heavy, design: .rounded))
                                            .foregroundColor(
                                                index < 3
                                                    ? .monoAccent
                                                    : .monoTextSecondary.opacity(0.45)
                                            )
                                            .monospacedDigit()
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.7)
                                            .frame(width: 24, alignment: .center)

                                        Text(item.searchWord)
                                            .font(.rounded(size: 14.5, weight: index < 3 ? .semibold : .regular))
                                            .foregroundColor(.monoTextPrimary)
                                            .lineLimit(1)

                                        Spacer(minLength: 0)
                                    }
                                    .padding(.vertical, 9)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.top, 18)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .themeRenderScrollLayer()
    }

    /// aside 搜索区块头：强调色小竖标 + 标题
    func defaultSearchSectionHeader<Trailing: View>(
        title: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 8) {
            Capsule()
                .fill(Color.monoAccent)
                .frame(width: 3, height: 13)

            Text(title)
                .font(.rounded(size: 15, weight: .bold))
                .foregroundColor(.monoTextPrimary)

            Spacer()

            trailing()
        }
    }

}
