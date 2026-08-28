import Combine
import QQMusicKit
import SwiftUI

// MARK: - Cancellable Store

class ProfileCancellableStore: @unchecked Sendable {
    static let shared = ProfileCancellableStore()
    var cancellables = Set<AnyCancellable>()
}

// MARK: - Stat Cell

struct StatCell: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(valueFont)
                .foregroundColor(PetWhiteStyle.isActive ? PetWhiteStyle.ink : (SignalStyle.isActive ? SignalStyle.ink : (LiquidGlassStyle.isActive ? LiquidGlassStyle.ink : .monoTextPrimary)))

            Text(label)
                .font(labelFont)
                .foregroundColor(PetWhiteStyle.isActive ? PetWhiteStyle.inkSoft : (SignalStyle.isActive ? SignalStyle.inkSoft : (LiquidGlassStyle.isActive ? LiquidGlassStyle.inkSoft : .monoTextSecondary)))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var valueFont: Font {
        if MangaStyle.isActive { return MangaStyle.titleFont(18, weight: .black) }
        if PetWhiteStyle.isActive { return PetWhiteStyle.titleFont(18, weight: .black) }
        if PureWhiteStyle.isActive { return PureWhiteStyle.titleFont(18, weight: .black) }
        if MujiStyle.isActive { return MujiStyle.titleFont(18, weight: .medium) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.titleFont(18, weight: .semibold) }
        if SignalStyle.isActive { return SignalStyle.titleFont(17, weight: .bold) }
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.titleFont(18, weight: .semibold) }
        return .system(size: 18, weight: .bold, design: .rounded)
    }

    private var labelFont: Font {
        if MangaStyle.isActive { return MangaStyle.comicFont(10, weight: .bold) }
        if PetWhiteStyle.isActive { return PetWhiteStyle.labelFont(10, weight: .bold) }
        if PureWhiteStyle.isActive { return PureWhiteStyle.labelFont(10, weight: .bold) }
        if MujiStyle.isActive { return MujiStyle.labelFont(10, weight: .regular) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.labelFont(10, weight: .regular) }
        if SignalStyle.isActive { return SignalStyle.labelFont(10, weight: .medium) }
        if LiquidGlassStyle.isActive { return LiquidGlassStyle.labelFont(10, weight: .medium) }
        return .system(size: 10, weight: .medium, design: .rounded)
    }
}
