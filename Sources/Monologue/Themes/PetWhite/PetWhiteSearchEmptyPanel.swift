import SwiftUI

struct PetWhiteSearchEmptyPanel: View {
    let defaultKeyword: SearchDefaultResult?
    let searchHistory: [SearchHistory]
    let hotSearchItems: [HotSearchItem]
    let onSearch: (String) -> Void
    let onDeleteHistory: (String) -> Void
    let onClearHistory: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            defaultKeywordCard
            historyShelf
            hotSearchShelf
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.top, 4)
        .padding(.bottom, 16)
    }

    @ViewBuilder
    private var defaultKeywordCard: some View {
        if let defaultKeyword {
            Button {
                onSearch(defaultKeyword.realkeyword)
            } label: {
                HStack(spacing: 12) {
                    PetWhiteIconBadge(icon: .magnifyingGlass, tint: PetWhiteStyle.sky, size: 44)

                    VStack(alignment: .leading, spacing: 4) {
                        PetWhitePill(text: "TRY", tint: PetWhiteStyle.butter)

                        Text(defaultKeyword.showKeyword)
                            .font(PetWhiteStyle.titleFont(19, weight: .black))
                            .foregroundStyle(PetWhiteStyle.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.76)
                    }

                    Spacer(minLength: 8)

                    PetWhiteProfileHeadIcon(filled: true, size: 30)
                }
                .padding(14)
                .background(PetWhiteSurfaceBackground(cornerRadius: 22, elevated: true, tint: PetWhiteStyle.surfaceRaised, accent: PetWhiteStyle.sky))
            }
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))
        }
    }

    @ViewBuilder
    private var historyShelf: some View {
        if !searchHistory.isEmpty {
            PetWhiteSearchShelf(
                title: String(localized: "search_history"),
                icon: .clock,
                tint: PetWhiteStyle.mint,
                action: onClearHistory
            ) {
                VStack(spacing: 8) {
                    ForEach(searchHistory, id: \.id) { item in
                        PetWhiteSearchHistoryRow(
                            item: item,
                            onSearch: onSearch,
                            onDelete: onDeleteHistory
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var hotSearchShelf: some View {
        if !hotSearchItems.isEmpty {
            PetWhiteSearchShelf(
                title: String(localized: "search_hot"),
                icon: .sparkle,
                tint: PetWhiteStyle.dogOrange
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
    let icon: MonologueIcon.IconType
    let tint: Color
    var action: (() -> Void)?
    let content: Content

    init(
        title: String,
        icon: MonologueIcon.IconType,
        tint: Color,
        action: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.tint = tint
        self.action = action
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 9) {
                PetWhiteIconBadge(icon: icon, tint: tint, size: 34)

                Text(title)
                    .font(PetWhiteStyle.titleFont(17, weight: .black))
                    .foregroundStyle(PetWhiteStyle.ink)

                Spacer(minLength: 8)

                if let action {
                    Button(action: action) {
                        PetWhitePackIcon(icon: .trash, size: 20, visualScale: 1.08)
                            .frame(width: 34, height: 34)
                            .background(PetWhiteStyle.butter, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(PetWhiteStyle.stroke, lineWidth: 1.4)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            content
        }
        .padding(13)
        .background(PetWhiteSurfaceBackground(cornerRadius: 22, elevated: true, tint: PetWhiteStyle.surfaceRaised, accent: tint))
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
                PetWhitePackIcon(icon: .clock, size: 18, visualScale: 1.06)

                Text(item.keyword)
                    .font(PetWhiteStyle.bodyFont(14, weight: .bold))
                    .foregroundStyle(PetWhiteStyle.ink)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Button {
                    onDelete(item.keyword)
                } label: {
                    PetWhitePackIcon(icon: .xmark, size: 16, visualScale: 1.04, fallbackColor: PetWhiteStyle.inkSoft)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(PetWhiteSurfaceBackground(cornerRadius: 16, elevated: false, tint: PetWhiteStyle.surfacePressed, accent: PetWhiteStyle.mint))
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
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(index < 3 ? PetWhiteStyle.dogOrange : PetWhiteStyle.inkSoft)

                Text(item.searchWord)
                    .font(PetWhiteStyle.labelFont(13, weight: .bold))
                    .foregroundStyle(PetWhiteStyle.ink)
                    .lineLimit(1)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .background(PetWhiteSurfaceBackground(cornerRadius: 16, elevated: false, tint: PetWhiteStyle.surfaceRaised, accent: index < 3 ? PetWhiteStyle.dogOrange : PetWhiteStyle.sky))
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.96))
    }
}
