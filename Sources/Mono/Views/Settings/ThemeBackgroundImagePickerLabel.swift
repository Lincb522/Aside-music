import PhotosUI
import SwiftUI

/// PhotosPicker 的标签闭包是 nonisolated 的，初始化只保存可发送的值。
struct ThemeBackgroundImagePickerLabel: View {
    let theme: GlobalThemeId
    let dark: Bool

    nonisolated init(theme: GlobalThemeId, dark: Bool = false) {
        self.theme = theme
        self.dark = dark
    }

    var body: some View {
        let image = ThemeColorCustomization.backgroundImage(for: theme, dark: dark)

        HStack(spacing: 10) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.monoGlassTint)
                        .overlay(
                            MonoIcon(icon: .album, size: 14, color: .monoTextSecondary, lineWidth: 1.5)
                        )
                }
            }
            .frame(width: 38, height: 38)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.monoSeparator.opacity(0.7), lineWidth: 0.7)
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(image == nil ? String(localized: "选择背景图") : String(localized: "更换背景图"))
                    .font(appearanceSettingsFont(12, weight: .semibold))
                    .foregroundStyle(Color.monoTextPrimary)
                    .lineLimit(1)

                Text(String(localized: "从相册选取"))
                    .font(appearanceSettingsFont(9.5, weight: .regular))
                    .foregroundStyle(Color.monoTextSecondary.opacity(0.8))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            MonoIcon(icon: .chevronRight, size: 9, color: Color.monoTextSecondary.opacity(0.72), lineWidth: 1.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.monoGlassTint)
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.monoSeparator.opacity(0.68), lineWidth: 0.65))
        )
    }
}
