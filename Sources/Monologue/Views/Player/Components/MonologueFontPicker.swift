import SwiftUI
import UIKit

enum MonologueFontPickerLayout {
    case horizontal
    case grid(columns: Int)
}

struct MonologueFontPicker: View {
    @Binding var selectionRaw: String
    @Binding var customFontID: String

    let accent: Color
    var layout: MonologueFontPickerLayout = .horizontal
    var includesFollowTheme = false
    var followLabel = String(localized: "跟随主题")

    @ObservedObject private var fontManager = CustomFontManager.shared
    @State private var showImporter = false
    @State private var importError: String?

    private var builtInChoices: [AriaLyricFontChoice] {
        AriaLyricFontChoice.allCases.filter { $0 != .custom }
    }

    var body: some View {
        Group {
            switch layout {
            case .horizontal:
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        pickerContent
                    }
                }
            case .grid(let count):
                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(.flexible(), spacing: 7),
                        count: max(2, count)
                    ),
                    spacing: 7
                ) {
                    pickerContent
                }
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: CustomFontManager.supportedContentTypes,
            allowsMultipleSelection: true
        ) { result in
            handleImport(result)
        }
        .alert(
            String(localized: "字体导入失败"),
            isPresented: Binding(
                get: { importError != nil },
                set: { if !$0 { importError = nil } }
            )
        ) {
            Button(String(localized: "确定"), role: .cancel) {}
        } message: {
            Text(importError ?? "")
        }
    }

    @ViewBuilder
    private var pickerContent: some View {
        if includesFollowTheme {
            selectionButton(
                id: MonologuePlayerFont.followThemeRawValue,
                name: followLabel,
                previewFont: .system(size: 18, weight: .bold, design: .rounded),
                selected: selectionRaw == MonologuePlayerFont.followThemeRawValue
            ) {
                selectionRaw = MonologuePlayerFont.followThemeRawValue
            }
        }

        ForEach(builtInChoices, id: \.rawValue) { choice in
            selectionButton(
                id: choice.rawValue,
                name: choice.label,
                previewFont: choice.font(size: 18, weight: .bold),
                selected: selectionRaw == choice.rawValue
            ) {
                selectionRaw = choice.rawValue
            }
        }

        ForEach(fontManager.fonts) { record in
            selectionButton(
                id: record.id,
                name: record.displayName,
                previewFont: .custom(record.postScriptName, size: 18),
                selected: selectionRaw == AriaLyricFontChoice.custom.rawValue
                    && customFontID == record.id
            ) {
                customFontID = record.id
                selectionRaw = AriaLyricFontChoice.custom.rawValue
            }
            .contextMenu {
                Button(role: .destructive) {
                    fontManager.delete(record)
                } label: {
                    Label(String(localized: "删除字体"), systemImage: "trash")
                }
            }
        }

        importButton
    }

    private func selectionButton(
        id: String,
        name: String,
        previewFont: Font,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            VStack(spacing: 3) {
                Text("永Aa")
                    .font(previewFont)
                    .foregroundStyle(.white.opacity(selected ? 1 : 0.7))
                    .lineLimit(1)

                Text(name)
                    .font(.system(size: 9.5, weight: selected ? .semibold : .medium))
                    .foregroundStyle(.white.opacity(selected ? 0.84 : 0.42))
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            }
            .frame(maxWidth: layoutUsesGrid ? .infinity : nil)
            .frame(width: layoutUsesGrid ? nil : 82, height: 54)
            .padding(.horizontal, layoutUsesGrid ? 5 : 0)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(selected ? 0.1 : 0.035))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        selected ? accent.opacity(0.62) : Color.white.opacity(0.06),
                        lineWidth: 1
                    )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .id(id)
    }

    private var importButton: some View {
        Button {
            showImporter = true
        } label: {
            VStack(spacing: 4) {
                MonologueIcon(icon: .add, size: 16, color: accent)
                Text(String(localized: "导入字体"))
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: layoutUsesGrid ? .infinity : nil)
            .frame(width: layoutUsesGrid ? nil : 82, height: 54)
            .padding(.horizontal, layoutUsesGrid ? 5 : 0)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.035))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        accent.opacity(0.24),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                    )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "导入字体"))
    }

    private var layoutUsesGrid: Bool {
        if case .grid = layout {
            return true
        }
        return false
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            do {
                let imported = try fontManager.importFonts(from: urls)
                if let first = imported.first {
                    customFontID = first.id
                    selectionRaw = AriaLyricFontChoice.custom.rawValue
                }
            } catch {
                importError = error.localizedDescription
            }
        case .failure(let error):
            importError = error.localizedDescription
        }
    }
}

struct PlayerTypographySettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("playerDisplayFont") private var selectionRaw = MonologuePlayerFont.followThemeRawValue
    @AppStorage("playerCustomFontID") private var customFontID = ""
    @AppStorage("playerFontScale") private var fontScale = 1.0
    @AppStorage("lyricsForceUppercaseEnglish") private var forceUppercaseEnglish = false

    @ObservedObject private var player = PlayerManager.shared
    @StateObject private var coverColors = CoverColorExtractor()

    private var accent: Color {
        coverColors.dominantColor
    }

    private var previewFont: Font {
        MonologuePlayerFont.font(
            selectionRaw: selectionRaw,
            customFontID: customFontID,
            size: 29 * CGFloat(fontScale),
            weight: .bold,
            fallback: .system(size: 29 * CGFloat(fontScale), weight: .bold, design: .rounded)
        )
    }

    private var selectedFontName: String {
        if selectionRaw == MonologuePlayerFont.followThemeRawValue {
            return String(localized: "跟随播放器主题")
        }
        if selectionRaw == AriaLyricFontChoice.custom.rawValue {
            return CustomFontManager.shared.record(withID: customFontID)?.displayName
                ?? String(localized: "自定义字体")
        }
        return (AriaLyricFontChoice(rawValue: selectionRaw) ?? .system).label
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    preview
                    fontSection
                    behaviorSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 44)
            }
        }
        .compatFontDesign(nil)
        .background(backdrop.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .onAppear {
            coverColors.extract(from: player.currentSong?.coverUrl?.sized(200).absoluteString)
        }
        .onChange(of: player.currentSong?.id) { _, _ in
            coverColors.extract(from: player.currentSong?.coverUrl?.sized(200).absoluteString)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                MonologueIcon(icon: .back, size: 18, color: .white.opacity(0.9))
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(MonologueBouncingButtonStyle())

            Text(String(localized: "播放器字体"))
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    private var preview: some View {
        VStack(spacing: 8) {
            Text(forceUppercaseEnglish ? "MIDNIGHT RADIO · 春风" : "Midnight Radio · 春风")
                .font(previewFont)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.55)

            Text(selectedFontName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.48))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 104)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(accent.opacity(0.24), lineWidth: 1)
        }
        .id("\(selectionRaw)|\(customFontID)|\(fontScale)|\(forceUppercaseEnglish)")
    }

    private var fontSection: some View {
        section(title: String(localized: "字体")) {
            VStack(spacing: 14) {
                MonologueFontPicker(
                    selectionRaw: $selectionRaw,
                    customFontID: $customFontID,
                    accent: accent,
                    layout: .grid(columns: 3),
                    includesFollowTheme: true
                )

                VStack(spacing: 6) {
                    HStack {
                        controlLabel(String(localized: "字号"))
                        Spacer()
                        Text(String(format: "%.2f×", fontScale))
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    Slider(value: $fontScale, in: 0.75...1.5)
                        .tint(accent)
                }
            }
            .padding(14)
            .background(cardBackground)
        }
    }

    private var behaviorSection: some View {
        section(title: String(localized: "歌词显示")) {
            Toggle(isOn: $forceUppercaseEnglish) {
                Text(String(localized: "英文歌词强制大写"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .tint(accent)
            .padding(14)
            .background(cardBackground)
        }
    }

    private func section<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.45))
            content()
        }
    }

    private func controlLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white.opacity(0.62))
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.white.opacity(0.05))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            }
    }

    private var backdrop: some View {
        ZStack {
            Color(red: 0.055, green: 0.055, blue: 0.072)
            RadialGradient(
                colors: [accent.opacity(0.16), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 440
            )
        }
    }
}
