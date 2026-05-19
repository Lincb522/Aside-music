import SwiftUI

struct PetWhiteSearchHeader: View {
    var body: some View {
        PetWhitePageHeader(
            eyebrow: "SNIFF",
            title: String(localized: "搜索"),
            subtitle: String(localized: "找到今天想听的声音"),
            icon: .magnifyingGlass
        ) {
            PetWhiteProfileHeadIcon(filled: false, size: 38)
                .frame(width: 48, height: 48)
                .background(PetWhiteStyle.surfaceRaised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(PetWhiteStyle.separator, lineWidth: 1)
                )
        }
    }
}

struct PetWhiteSearchTabBar: View {
    let currentTab: SearchTab
    let hasSearched: Bool
    let iconProvider: (SearchTab) -> MonologueIcon.IconType
    let onSelect: (SearchTab) -> Void

    var body: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = hasSearched ? 6 : 8
            let itemWidth = itemWidth(totalWidth: proxy.size.width, spacing: spacing)

            HStack(spacing: spacing) {
                ForEach(SearchTab.allCases, id: \.self) { tab in
                    tabButton(tab, itemWidth: itemWidth)
                }
            }
            .padding(5)
            .background(
                PetWhiteSurfaceBackground(
                    cornerRadius: hasSearched ? 18 : 21,
                    elevated: true,
                    tint: PetWhiteStyle.surfacePressed,
                    accent: PetWhiteStyle.mint
                )
            )
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.vertical, hasSearched ? 2 : 7)
        }
        .frame(height: hasSearched ? 48 : 58)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func tabButton(_ tab: SearchTab, itemWidth: CGFloat) -> some View {
        let selected = currentTab == tab

        return Button {
            onSelect(tab)
        } label: {
            HStack(spacing: hasSearched ? 0 : 6) {
                if !hasSearched {
                    PetWhitePackIcon(
                        icon: iconProvider(tab),
                        size: 17,
                        visualScale: 1.04,
                        fallbackColor: selected ? PetWhiteStyle.stroke : PetWhiteStyle.inkSoft,
                        lineWidth: selected ? 1.9 : 1.55
                    )
                }

                Text(tab.rawValue)
                    .font(PetWhiteStyle.labelFont(hasSearched ? 11 : 12.5, weight: selected ? .black : .bold))
                    .foregroundStyle(selected ? PetWhiteStyle.stroke : PetWhiteStyle.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .frame(width: itemWidth)
            .padding(.vertical, hasSearched ? 7 : 9)
            .background(
                PetWhiteSurfaceBackground(
                    cornerRadius: hasSearched ? 14 : 16,
                    elevated: selected,
                    tint: selected ? PetWhiteStyle.sky.opacity(0.82) : PetWhiteStyle.surfaceRaised,
                    accent: selected ? PetWhiteStyle.dogOrange : PetWhiteStyle.mint
                )
            )
        }
        .buttonStyle(.plain)
    }

    private func itemWidth(totalWidth: CGFloat, spacing: CGFloat) -> CGFloat {
        let count = CGFloat(SearchTab.allCases.count)
        let horizontalPadding = DeviceLayout.viewHorizontalPadding * 2
        let totalSpacing = spacing * max(count - 1, 0)
        let available = max(totalWidth - horizontalPadding - totalSpacing, 0)
        return max(floor(available / count), 44)
    }
}
