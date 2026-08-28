import SwiftUI

struct SequoiaSearchStatePanel: View {
    let icon: MonoIcon.IconType
    let title: String
    var subtitle: String = ""
    var tint: Color = SequoiaStyle.accent
    var loading = false

    var body: some View {
        VStack(spacing: 13) {
            SequoiaIconBadge(icon: icon, tint: tint, size: 52)

            VStack(spacing: 5) {
                Text(title)
                    .font(SequoiaStyle.titleFont(18, weight: .semibold))
                    .foregroundStyle(SequoiaStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(SequoiaStyle.labelFont(12, weight: .regular))
                        .foregroundStyle(SequoiaStyle.inkMuted)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
            }

            if loading {
                ProgressView()
                    .tint(tint)
                    .scaleEffect(0.82)
            } else {
                SequoiaMeter(tint: tint, count: 10)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 38)
        .padding(.horizontal, 18)
        .background(SequoiaSurfaceBackground(cornerRadius: 24, elevated: true, role: .chrome))
    }
}
