import SwiftUI

struct AnnouncementPopupOverlay: View {
    @ObservedObject private var center = AnnouncementCenter.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if let announcement = center.pendingAnnouncement {
                Color.black.opacity(0.44)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        guard !announcement.requiresAcknowledgement else { return }
                        center.dismissPendingAnnouncement()
                    }

                AnnouncementPopupCard(
                    announcement: announcement,
                    onDismiss: center.dismissPendingAnnouncement
                )
                .transition(reduceMotion ? .opacity : .scale(scale: 0.96).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? .linear(duration: 0.12) : .easeOut(duration: 0.22), value: center.pendingAnnouncement?.id)
    }
}

private struct AnnouncementPopupCard: View {
    let announcement: AppAnnouncement
    let onDismiss: () -> Void

    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            banner

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    if let summary = announcement.summary, !summary.isEmpty {
                        Text(summary)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.monoTextPrimary.opacity(0.82))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    bodyText
                        .font(.body)
                        .foregroundStyle(Color.monoTextPrimary.opacity(0.82))
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, bannerHasImage ? 16 : 20)
                .padding(.bottom, 18)
            }
            .frame(maxHeight: min(430, DeviceLayout.viewportHeight * 0.48))

            actions
        }
        .frame(maxWidth: 420)
        .background {
            ZStack {
                Rectangle().fill(.regularMaterial)
                Rectangle().fill(Color.monoGlassTint.opacity(colorScheme == .dark ? 0.72 : 0.48))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.monoTextPrimary.opacity(0.1), lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(0.3), radius: 28, x: 0, y: 14)
        .padding(.horizontal, 22)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var banner: some View {
        if let url = imageURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    Color.monoAccent.opacity(0.1)
                case .empty:
                    ZStack {
                        Color.monoAccent.opacity(0.08)
                        ProgressView().tint(.monoAccent)
                    }
                @unknown default:
                    Color.monoAccent.opacity(0.08)
                }
            }
            .frame(height: 156)
            .frame(maxWidth: .infinity)
            .clipped()
            .overlay(alignment: .topTrailing) { closeButton.padding(12) }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Label {
                    Text(announcement.category.title)
                } icon: {
                    if let semantic = announcement.category.monoGlyphSemantic {
                        MonoSemanticIcon(semantic: semantic, fallback: announcement.category.fallbackIcon)
                    } else {
                        Image(systemName: announcement.category.symbol)
                    }
                }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.monoAccent)

                if announcement.priority != .normal {
                    Text(announcement.priority == .critical ? "紧急" : "重要")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.monoAccent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.monoAccent.opacity(0.12), in: Capsule())
                }

                Spacer(minLength: 8)
                if !bannerHasImage { closeButton }
            }

            Text(announcement.title)
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.monoTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
    }

    private var closeButton: some View {
        Button(action: onDismiss) {
            Image(systemName: "xmark")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.monoTextSecondary)
                .frame(width: 34, height: 34)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .opacity(announcement.requiresAcknowledgement ? 0 : 1)
        .disabled(announcement.requiresAcknowledgement)
        .accessibilityLabel("关闭公告")
    }

    @ViewBuilder
    private var bodyText: some View {
        if let attributed = try? AttributedString(
            markdown: announcement.body,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            Text(attributed)
        } else {
            Text(announcement.body)
        }
    }

    private var actions: some View {
        HStack(spacing: 10) {
            if let actionTitle = announcement.actionTitle,
               !actionTitle.isEmpty,
               let actionURL = URL(string: announcement.actionURL ?? "") {
                Button {
                    openURL(actionURL)
                    onDismiss()
                } label: {
                    Text(actionTitle)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.monoTextPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 48)
                        .background(Color.monoTextPrimary.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            Button(action: onDismiss) {
                Text(announcement.requiresAcknowledgement ? "确认" : "知道了")
                    .font(.body.weight(.bold))
                    .foregroundStyle(Color(light: .white, dark: .black))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 48)
                    .background(Color.monoAccent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .overlay(alignment: .top) { Divider().opacity(0.45) }
    }

    private var imageURL: URL? {
        guard let value = announcement.imageURL else { return nil }
        return URL(string: value)
    }

    private var bannerHasImage: Bool { imageURL != nil }
}

private extension AppAnnouncementCategory {
    var monoGlyphSemantic: MonoGlyphSemantic? {
        switch self {
        case .maintenance: return .maintenance
        case .policy: return .policyDocument
        case .general, .activity, .important, .update: return nil
        }
    }

    var fallbackIcon: MonoIcon.IconType {
        switch self {
        case .maintenance: return .settings
        case .policy: return .info
        case .general: return .bell
        case .activity: return .sparkle
        case .important: return .warning
        case .update: return .download
        }
    }
}
