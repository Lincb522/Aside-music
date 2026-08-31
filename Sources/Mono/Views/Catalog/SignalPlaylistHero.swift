import SwiftUI

struct SignalPlaylistHero<Accessory: View>: View {
    let coverURL: URL?
    let title: String
    let sourceLabel: String
    let subtitle: String?
    let descriptionText: String?
    let trackCount: Int?
    let playDisabled: Bool
    let onPlay: () -> Void
    private let accessory: Accessory

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    init(
        coverURL: URL?,
        title: String,
        sourceLabel: String,
        subtitle: String? = nil,
        descriptionText: String? = nil,
        trackCount: Int? = nil,
        playDisabled: Bool = false,
        onPlay: @escaping () -> Void,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.coverURL = coverURL
        self.title = title
        self.sourceLabel = sourceLabel
        self.subtitle = subtitle
        self.descriptionText = descriptionText
        self.trackCount = trackCount
        self.playDisabled = playDisabled
        self.onPlay = onPlay
        self.accessory = accessory()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            artworkPlane

            actionLayout
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.vertical, 14)

            Rectangle()
                .fill(SignalStyle.separator.opacity(0.66))
                .frame(height: 0.65)
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        }
        .padding(.bottom, 6)
        .frame(maxWidth: 860)
        .frame(maxWidth: .infinity)
    }

    private var artworkPlane: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                coverImage
                    .frame(width: proxy.size.width, height: proxy.size.height)

                LinearGradient(
                    colors: [
                        Color.black.opacity(0.02),
                        Color.black.opacity(0.16),
                        Color.black.opacity(0.92),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(sourceLabel.uppercased())
                            .font(SignalStyle.monoFont(9.5, weight: .semibold))
                            .foregroundStyle(SignalStyle.accent)
                            .lineLimit(1)

                        Spacer(minLength: 10)

                        if let trackCount {
                            Text("\(trackCount) \(String(localized: "songs_unit"))")
                                .font(SignalStyle.monoFont(9.5, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.62))
                                .monospacedDigit()
                        }
                    }

                    Text(title)
                        .font(SignalStyle.titleFont(horizontalSizeClass == .regular ? 36 : 28, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .lineLimit(horizontalSizeClass == .regular ? 2 : 3)
                        .fixedSize(horizontal: false, vertical: true)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(SignalStyle.bodyFont(12, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.72))
                            .lineLimit(1)
                    }

                    if let description = descriptionText?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !description.isEmpty {
                        Text(description)
                            .font(SignalStyle.bodyFont(11, weight: .regular))
                            .foregroundStyle(Color.white.opacity(0.62))
                            .lineLimit(horizontalSizeClass == .regular ? 2 : 1)
                            .lineSpacing(2)
                    }
                }
                .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                .padding(.vertical, horizontalSizeClass == .regular ? 24 : 18)
            }
        }
        .aspectRatio(horizontalSizeClass == .regular ? 16 / 9 : 4 / 3, contentMode: .fit)
        .clipped()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }

    @ViewBuilder
    private var coverImage: some View {
        if let coverURL {
            CachedAsyncImage(url: coverURL.sized(1200)) {
                placeholder
            }
            .aspectRatio(contentMode: .fill)
            .clipped()
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        ZStack {
            SignalStyle.controlPressed
            MonoIcon(icon: .musicNoteList, size: 46, color: SignalStyle.inkMuted, lineWidth: 1.45)
        }
    }

    @ViewBuilder
    private var actionLayout: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                playButton
                accessory
            }

            VStack(alignment: .leading, spacing: 10) {
                playButton
                accessory
            }
        }
    }

    private var playButton: some View {
        Button(action: onPlay) {
            HStack(spacing: 9) {
                MonoIcon(icon: .play, size: 14, color: SignalStyle.onAccent, lineWidth: 1.9)
                Text(String(localized: "play_now"))
                    .font(SignalStyle.labelFont(13, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(SignalStyle.onAccent)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(
                SignalStyle.accent,
                in: RoundedRectangle(cornerRadius: SignalStyle.buttonRadius, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: SignalStyle.buttonRadius, style: .continuous))
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.97))
        .disabled(playDisabled)
        .opacity(playDisabled ? 0.42 : 1)
    }
}

struct SignalPlaylistUtilityButton: View {
    let icon: MonoIcon.IconType
    var tint: Color = SignalStyle.inkSoft
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            MonoIcon(icon: icon, size: 15, color: tint, lineWidth: 1.6)
                .frame(width: 44, height: 44)
                .background(
                    SignalStyle.controlPressed,
                    in: RoundedRectangle(cornerRadius: SignalStyle.compactRadius, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: SignalStyle.compactRadius, style: .continuous)
                        .stroke(SignalStyle.separator.opacity(0.68), lineWidth: 0.7)
                }
                .contentShape(RoundedRectangle(cornerRadius: SignalStyle.compactRadius, style: .continuous))
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.94))
        .accessibilityLabel(label)
    }
}
