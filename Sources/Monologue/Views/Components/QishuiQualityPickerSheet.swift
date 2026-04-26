import SwiftUI

struct QishuiQualityPickerSheet: View {
    let currentQuality: String
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.monologueSheetDismiss) private var monologueSheetDismiss

    private static let qualities: [(key: String, name: String, subtitle: String)] = [
        ("lossless", "无损", "FLAC · ~820kbps"),
        ("spatial", "空间音频", "AAC · ~324kbps"),
        ("hi_res", "高解析度", "AAC · ~320kbps"),
        ("highest", "超清", "AAC · ~260kbps"),
        ("higher", "较高", "AAC · ~132kbps"),
        ("medium", "标准", "AAC · ~64kbps"),
    ]

    static func displayName(for quality: String) -> String {
        qualities.first { $0.key == quality }?.name ?? quality
    }

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("QSM 音质")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.monologueTextPrimary)

                PlatformBadgeLabel(text: "QSM", source: .qishui)

                Spacer()

                Button(action: { dismissCurrentPresentation(systemDismiss: dismiss, monologueSheetDismiss: monologueSheetDismiss) }) {
                    MonologueIcon(icon: .close, size: 14, color: .monologueTextSecondary)
                        .padding(10)
                        .background(Color.monologueSeparator)
                        .clipShape(Circle())
                        .monologueGlassCircle()
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.top, 8)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(Self.qualities.enumerated()), id: \.element.key) { index, item in
                        Button(action: { onSelect(item.key) }) {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(currentQuality == item.key ? Color.monologueIconBackground : Color.monologueIconBackground.opacity(0.08))
                                        .frame(width: 32, height: 32)

                                    MonologueIcon(icon: .soundQuality, size: 16, color: currentQuality == item.key ? .monologueIconForeground : .monologueTextPrimary)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                        .foregroundColor(.monologueTextPrimary)

                                    Text(item.subtitle)
                                        .font(.system(size: 12, weight: .regular, design: .rounded))
                                        .foregroundColor(.monologueTextSecondary)
                                }

                                Spacer()

                                if currentQuality == item.key {
                                    MonologueIcon(icon: .checkmark, size: 14, color: .monologueTextPrimary)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.plain)

                        if index < Self.qualities.count - 1 {
                            Divider().padding(.leading, 56)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.monologueGlassTint)
                        .monologueGlass(cornerRadius: 20)
                        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.bottom, 20)
                .iPadContentWidth(500)
            }
            .scrollIndicators(.hidden)
        }
    }
}
