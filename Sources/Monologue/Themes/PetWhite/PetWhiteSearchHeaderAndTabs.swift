import SwiftUI

struct PetWhiteSearchHeader: View {
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(String(localized: "搜索"))
                .font(PetWhiteStyle.titleFont(26, weight: .bold))
                .foregroundStyle(PetWhiteStyle.ink)
                .lineLimit(1)

            Spacer(minLength: 8)

            PetWhitePetPetIcon(size: 36)
        }
        .padding(.horizontal, DeviceLayout.homeHorizontalPadding)
        .padding(.top, DeviceLayout.headerTopPadding + 2)
        .padding(.bottom, 10)
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
                // 凹槽托盘：标签像嵌在黏土上压出的浅槽里
                RoundedRectangle(cornerRadius: hasSearched ? 18 : 21, style: .continuous)
                    .fill(PetWhiteStyle.surfacePressed)
                    .overlay(
                        PetWhiteClayInnerShadow(
                            shape: RoundedRectangle(cornerRadius: hasSearched ? 18 : 21, style: .continuous),
                            depth: 2.4
                        )
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
                        size: 16,
                        visualScale: 1.02,
                        fallbackColor: selected ? PetWhiteStyle.ink : PetWhiteStyle.inkMuted,
                        lineWidth: selected ? 1.8 : 1.5
                    )
                }

                Text(tab.rawValue)
                    .font(PetWhiteStyle.labelFont(hasSearched ? 11 : 12.5, weight: selected ? .bold : .semibold))
                    .foregroundStyle(selected ? PetWhiteStyle.ink : PetWhiteStyle.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .frame(width: itemWidth)
            .padding(.vertical, hasSearched ? 7 : 9)
            .background {
                if selected {
                    // 凹槽里凸起的选中块：从槽底鼓出来的一小块糖果黏土
                    PetWhiteClayPuck(
                        shape: RoundedRectangle(cornerRadius: hasSearched ? 12 : PetWhiteStyle.compactRadius, style: .continuous),
                        tint: PetWhiteStyle.sky
                    )
                }
            }
        }
        .buttonStyle(PetWhiteSquishyButtonStyle(scale: 0.94))
    }

    private func itemWidth(totalWidth: CGFloat, spacing: CGFloat) -> CGFloat {
        let count = CGFloat(SearchTab.allCases.count)
        let horizontalPadding = DeviceLayout.viewHorizontalPadding * 2
        let totalSpacing = spacing * max(count - 1, 0)
        let available = max(totalWidth - horizontalPadding - totalSpacing, 0)
        return max(floor(available / count), 44)
    }
}
