import SwiftUI

/// aside 主题共享的电台列表行：细线描边封面 + 排印文本 + 发丝分隔线
struct AsideRadioListRow: View {
    let radio: RadioStation
    var rank: Int? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                if let rank {
                    Text(String(format: "%02d", rank))
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(rank <= 3 ? .monologueAccent : .monologueTextSecondary.opacity(0.6))
                        .frame(width: 28, alignment: .leading)
                }

                CachedAsyncImage(url: radio.coverUrl) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.monologueGlassTint)
                }
                .frame(width: 54, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.monologueSeparator.opacity(0.9), lineWidth: 0.8)
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(radio.name)
                        .font(.rounded(size: 15, weight: .semibold))
                        .foregroundColor(.monologueTextPrimary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        if let dj = radio.dj?.nickname, !dj.isEmpty {
                            Text(dj)
                                .lineLimit(1)
                        }
                        if let count = radio.programCount, count > 0 {
                            Text(String(format: String(localized: "podcast_episode_count"), count))
                                .fixedSize()
                        }
                    }
                    .font(.rounded(size: 12))
                    .foregroundColor(.monologueTextSecondary.opacity(0.85))
                }

                Spacer(minLength: 8)

                MonologueIcon(icon: .chevronRight, size: 11, color: .monologueTextSecondary.opacity(0.55), lineWidth: 1.3)
            }
            .padding(.vertical, 11)

            Rectangle()
                .fill(Color.monologueSeparator.opacity(0.7))
                .frame(height: 0.6)
                .padding(.leading, rank == nil ? 68 : 110)
        }
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .contentShape(Rectangle())
    }
}
