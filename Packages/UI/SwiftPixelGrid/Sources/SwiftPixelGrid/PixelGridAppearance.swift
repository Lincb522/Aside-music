/// 九个像素最终使用的完整色板分配。
///
/// 逐格颜色优先于统一颜色；两者都不存在时使用默认青色色板。
struct PixelGridAppearance: Hashable, Sendable {
    private let palettes: [PixelGridPalette]

    init(
        color: PixelGridColor?,
        colors: [PixelGridColor]?
    ) {
        if let colors, colors.count == PixelGridFrame.cellCount {
            palettes = colors.map(\.palette)
        } else if let color {
            palettes = Array(
                repeating: color.palette,
                count: PixelGridFrame.cellCount
            )
        } else {
            palettes = Array(
                repeating: .defaultCyan,
                count: PixelGridFrame.cellCount
            )
        }
    }

    func palette(at cell: PixelGridFrame.Cell) -> PixelGridPalette {
        palettes[cell.index]
    }
}
