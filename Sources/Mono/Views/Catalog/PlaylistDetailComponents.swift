import SwiftUI

// MARK: - 歌单简介 Sheet（aside）

/// 歌单 / 本地歌单详情页共用的介绍弹层，与歌手简介同一交互：
/// 头部封面 + 名称 + 创建者，下方滚动阅读完整介绍
struct PlaylistDescSheet: View {
    let coverUrl: URL?
    let title: String
    var subtitle: String? = nil
    let descriptionText: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.monoSheetDismiss) private var monoSheetDismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                CachedAsyncImage(url: coverUrl) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.monoGlassTint)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.rounded(size: 20, weight: .bold))
                        .foregroundColor(.monoTextPrimary)
                        .lineLimit(1)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.rounded(size: 12))
                            .foregroundColor(.monoTextSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Button(action: { dismissCurrentPresentation(systemDismiss: dismiss, monoSheetDismiss: monoSheetDismiss) }) {
                    MonoIcon(icon: .close, size: 20, color: .monoTextSecondary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.monoSeparator))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
            .padding(.top, 16)
            .padding(.bottom, 16)

            Rectangle()
                .fill(Color.monoSeparator)
                .frame(height: 0.5)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let desc = descriptionText?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !desc.isEmpty {
                        Text(desc)
                            .font(.rounded(size: 15, weight: .regular))
                            .foregroundColor(.monoTextPrimary)
                            .lineSpacing(6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color.monoGlassTint)
                                    .monoGlass(cornerRadius: 20)
                            }
                    } else {
                        VStack(spacing: 14) {
                            MonoIcon(icon: .info, size: 34, color: .monoTextSecondary.opacity(0.5))
                            Text(String(localized: "暂无介绍"))
                                .font(.rounded(size: 14))
                                .foregroundColor(.monoTextSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    }
                }
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.vertical, 20)
            }
        }
    }
}

// MARK: - Utilities

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
