import SwiftUI

struct LocalImportProgressPanel: View {
    let progress: LocalMusicLibraryManager.ImportProgress

    private var accent: Color {
        if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
        if SequoiaStyle.isActive { return SequoiaStyle.accent }
        return .monologueAccent
    }

    private var primaryText: Color {
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        if SequoiaStyle.isActive { return SequoiaStyle.ink }
        return .monologueTextPrimary
    }

    private var secondaryText: Color {
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        return .monologueTextSecondary
    }

    var body: some View {
        HStack(spacing: 10) {
            statusIcon

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(progress.title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(primaryText)
                        .lineLimit(1)

                    Text(progress.phaseText)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(accent)
                        .lineLimit(1)
                        .layoutPriority(1)

                    Spacer(minLength: 6)

                    if !progress.countText.isEmpty {
                        Text(progress.countText)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(secondaryText)
                            .monospacedDigit()
                            .lineLimit(1)
                    }
                }

                progressBar

                if let detail = progress.detailText, !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(secondaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else if progress.isCompleted {
                    completedSummary
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: ThemedPageStyle.isActive ? 8 : 12, style: .continuous)
                .fill(Color.monologueGlassTint.opacity(0.66))
                .monologueGlass(cornerRadius: ThemedPageStyle.isActive ? 8 : 12)
        )
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var statusIcon: some View {
        ZStack {
            Circle()
                .fill(accent.opacity(progress.isCompleted ? 0.18 : 0.12))
                .frame(width: 28, height: 28)

            if progress.isCompleted {
                MonologueIcon(icon: .checkmark, size: 13, color: accent, lineWidth: 1.8)
            } else {
                ProgressView()
                    .tint(accent)
                    .scaleEffect(0.58)
            }
        }
        .frame(width: 28, height: 28)
    }

    private var progressBar: some View {
        GeometryReader { geometry in
            let fraction = CGFloat(min(max(progress.fraction, 0), 1))
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color.monologueTextPrimary.opacity(0.08))

                Capsule(style: .continuous)
                    .fill(accent.opacity(0.82))
                    .frame(width: max(4, geometry.size.width * fraction))
            }
        }
        .frame(height: 4)
    }

    private var completedSummary: some View {
        HStack(spacing: 6) {
            metricPill(title: String(localized: "导入"), value: progress.importedCount)
            if progress.skippedCount > 0 {
                metricPill(title: String(localized: "跳过"), value: progress.skippedCount)
            }
            if progress.failedCount > 0 {
                metricPill(title: String(localized: "失败"), value: progress.failedCount)
            }
        }
    }

    private func metricPill(title: String, value: Int) -> some View {
        HStack(spacing: 4) {
            Text(title)
            Text("\(value)")
                .monospacedDigit()
        }
        .font(.system(size: 10, weight: .semibold, design: .rounded))
        .foregroundColor(secondaryText)
        .lineLimit(1)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule(style: .continuous)
                .fill(Color.monologueTextPrimary.opacity(0.055))
        )
    }
}
