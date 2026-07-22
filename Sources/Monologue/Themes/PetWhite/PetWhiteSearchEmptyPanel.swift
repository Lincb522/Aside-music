import SwiftUI

struct PetWhiteSearchEmptyPanel: View {
    let defaultKeyword: SearchDefaultResult?
    let searchHistory: [SearchHistory]
    let hotSearchItems: [HotSearchItem]
    let onSearch: (String) -> Void
    let onDeleteHistory: (String) -> Void
    let onClearHistory: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            defaultKeywordCard
            historyShelf
            hotSearchShelf
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    @ViewBuilder
    private var defaultKeywordCard: some View {
        if let defaultKeyword {
            Button {
                onSearch(defaultKeyword.realkeyword)
            } label: {
                HStack(spacing: 12) {
                    PetWhiteClayPuck(shape: Circle(), tint: PetWhiteStyle.sky)
                        .frame(width: 38, height: 38)
                        .overlay(
                            PetWhitePackIcon(icon: .magnifyingGlass, size: 18, visualScale: 1.04, lineWidth: 1.7)
                        )

                    VStack(alignment: .leading, spacing: 3) {
                        Text("TRY")
                            .font(PetWhiteStyle.labelFont(10, weight: .semibold))
                            .tracking(1.2)
                            .foregroundStyle(PetWhiteStyle.dogEar)

                        Text(defaultKeyword.showKeyword)
                            .font(PetWhiteStyle.titleFont(17, weight: .semibold))
                            .foregroundStyle(PetWhiteStyle.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.76)
                    }

                    Spacer(minLength: 8)

                    PetWhitePackIcon(icon: .chevronRight, size: 14, visualScale: 1.02, fallbackColor: PetWhiteStyle.inkMuted)
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 13)
                .background(PetWhiteSurfaceBackground(cornerRadius: PetWhiteStyle.cardRadius, elevated: false, tint: PetWhiteStyle.surfaceRaised, accent: PetWhiteStyle.sky))
            }
            .buttonStyle(PetWhiteSquishyButtonStyle(scale: 0.92))
        }
    }

    @ViewBuilder
    private var historyShelf: some View {
        if !searchHistory.isEmpty {
            PetWhiteSearchShelf(
                title: String(localized: "search_history"),
                action: onClearHistory
            ) {
                VStack(spacing: 0) {
                    ForEach(Array(searchHistory.enumerated()), id: \.element.id) { index, item in
                        PetWhiteSearchHistoryRow(
                            item: item,
                            onSearch: onSearch,
                            onDelete: onDeleteHistory
                        )

                        if index < searchHistory.count - 1 {
                            Divider()
                                .overlay(PetWhiteStyle.separator)
                                .padding(.leading, 34)
                        }
                    }
                }
                .padding(.horizontal, 6)
                .background(PetWhiteSurfaceBackground(cornerRadius: PetWhiteStyle.cardRadius, elevated: false, tint: PetWhiteStyle.surfaceRaised, accent: PetWhiteStyle.mint))
            }
        }
    }

    @ViewBuilder
    private var hotSearchShelf: some View {
        if !hotSearchItems.isEmpty {
            PetWhiteSearchShelf(
                title: String(localized: "search_hot")
            ) {
                FlowLayout(spacing: 9) {
                    ForEach(Array(hotSearchItems.enumerated()), id: \.element.searchWord) { index, item in
                        PetWhiteHotSearchChip(
                            index: index,
                            item: item,
                            onSearch: onSearch
                        )
                    }
                }
            }
        }
    }
}

private struct PetWhiteSearchShelf<Content: View>: View {
    let title: String
    var action: (() -> Void)?
    let content: Content

    init(
        title: String,
        action: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.action = action
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 9) {
                Text(title)
                    .font(PetWhiteStyle.titleFont(18, weight: .bold))
                    .foregroundStyle(PetWhiteStyle.ink)

                Spacer(minLength: 8)

                if let action {
                    Button(action: action) {
                        Text(String(localized: "search_clear"))
                            .font(PetWhiteStyle.labelFont(12, weight: .semibold))
                            .foregroundStyle(PetWhiteStyle.dogEar)
                    }
                    .buttonStyle(.plain)
                }
            }

            content
        }
    }
}

private struct PetWhiteSearchHistoryRow: View {
    let item: SearchHistory
    let onSearch: (String) -> Void
    let onDelete: (String) -> Void

    var body: some View {
        Button {
            onSearch(item.keyword)
        } label: {
            HStack(spacing: 10) {
                PetWhitePackIcon(icon: .clock, size: 16, visualScale: 1.02, fallbackColor: PetWhiteStyle.inkMuted)

                Text(item.keyword)
                    .font(PetWhiteStyle.bodyFont(14, weight: .semibold))
                    .foregroundStyle(PetWhiteStyle.ink)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Button {
                    onDelete(item.keyword)
                } label: {
                    PetWhitePackIcon(icon: .xmark, size: 14, visualScale: 1.02, fallbackColor: PetWhiteStyle.inkMuted)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct PetWhiteHotSearchChip: View {
    let index: Int
    let item: HotSearchItem
    let onSearch: (String) -> Void

    var body: some View {
        Button {
            onSearch(item.searchWord)
        } label: {
            HStack(spacing: 7) {
                Text(String(format: "%02d", index + 1))
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(index < 3 ? PetWhiteStyle.dogOrange : PetWhiteStyle.inkMuted)

                Text(item.searchWord)
                    .font(PetWhiteStyle.labelFont(13, weight: .semibold))
                    .foregroundStyle(PetWhiteStyle.ink)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                PetWhiteClayPuck(
                    shape: Capsule(style: .continuous),
                    tint: index < 3 ? PetWhiteStyle.butter : PetWhiteStyle.surfaceRaised
                )
            )
        }
        .buttonStyle(PetWhiteSquishyButtonStyle(scale: 0.9))
    }
}
