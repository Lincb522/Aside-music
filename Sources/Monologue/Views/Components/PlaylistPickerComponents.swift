import SwiftUI

struct PlaylistPickerContainerCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if NeumorphicStyle.isActive {
                    NeumorphicSurfaceBackground(cornerRadius: 22, elevated: false)
                } else {
                    Color.monologueTextPrimary.opacity(0.04)
                }
            }
            .clipShape(.rect(cornerRadius: NeumorphicStyle.isActive ? 22 : 18, style: .continuous))
            .overlay {
                if !NeumorphicStyle.isActive {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.monologueTextPrimary.opacity(0.06), lineWidth: 1)
                }
            }
    }
}

struct PlaylistPickerSection<Content: View>: View {
    let title: LocalizedStringKey
    let subtitle: String?

    private let content: Content

    init(
        title: LocalizedStringKey,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(13, weight: .semibold) : .system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : Color.monologueTextSecondary)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(12, weight: .regular) : .system(size: 12, design: .rounded))
                        .foregroundStyle(NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : Color.monologueTextSecondary.opacity(0.75))
                }
            }
            .padding(.horizontal, 4)

            VStack(spacing: 10) {
                content
            }
        }
    }
}

struct PlaylistPickerStatusBadge: View {
    let text: String
    var tint: Color = .monologueTextSecondary

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                if NeumorphicStyle.isActive {
                    NeumorphicSurfaceBackground(cornerRadius: 13, elevated: false, pressed: true, tint: tint.opacity(0.15), lightweight: true)
                } else {
                    tint.opacity(0.12)
                }
            }
            .clipShape(.capsule)
    }
}

struct PlaylistPickerActionCard: View {
    let icon: MonologueIcon.IconType
    let title: String
    let subtitle: String?
    let tint: Color
    var statusText: String? = nil
    var statusTint: Color = .monologueTextSecondary
    var isLoading = false
    var isDisabled = false
    var showsChevron = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            PlaylistPickerContainerCard {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.clear)
                            .frame(width: 46, height: 46)
                            .background {
                                if NeumorphicStyle.isActive {
                                    NeumorphicSurfaceBackground(cornerRadius: 15, elevated: false, pressed: true, tint: tint.opacity(0.16), lightweight: true)
                                } else {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(tint.opacity(0.12))
                                }
                            }

                        MonologueIcon(icon: icon, size: 18, color: tint)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(15, weight: .semibold) : .system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(NeumorphicStyle.isActive ? NeumorphicStyle.ink : Color.monologueTextPrimary)
                            .lineLimit(1)

                        if let subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : Color.monologueTextSecondary)
                                .lineLimit(2)
                        }
                    }

                    Spacer(minLength: 12)

                    trailingView
                }
            }
            .opacity(isDisabled ? 0.58 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
    }

    @ViewBuilder
    private var trailingView: some View {
        if isLoading {
            ProgressView()
                .controlSize(.small)
                .tint(Color.monologueTextSecondary)
        } else if let statusText, !statusText.isEmpty {
            PlaylistPickerStatusBadge(text: statusText, tint: statusTint)
        } else if showsChevron {
            MonologueIcon(icon: .chevronRight, size: 12, color: .monologueTextSecondary.opacity(0.45))
        }
    }
}

struct PlaylistPickerPlaylistRow: View {
    let title: String
    let subtitle: String
    let coverURL: URL?
    let placeholderIcon: MonologueIcon.IconType
    var statusText: String? = nil
    var statusTint: Color = .monologueTextSecondary
    var isLoading = false
    var isDisabled = false
    var showsChevron = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            PlaylistPickerContainerCard {
                HStack(spacing: 14) {
                    PlaylistPickerArtwork(coverURL: coverURL, placeholderIcon: placeholderIcon)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(15, weight: .medium) : .system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(NeumorphicStyle.isActive ? NeumorphicStyle.ink : Color.monologueTextPrimary)
                            .lineLimit(1)

                        Text(subtitle)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : Color.monologueTextSecondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 12)

                    trailingView
                }
            }
            .opacity(isDisabled ? 0.58 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
    }

    @ViewBuilder
    private var trailingView: some View {
        if isLoading {
            ProgressView()
                .controlSize(.small)
                .tint(Color.monologueTextSecondary)
        } else if let statusText, !statusText.isEmpty {
            PlaylistPickerStatusBadge(text: statusText, tint: statusTint)
        } else if showsChevron {
            MonologueIcon(icon: .chevronRight, size: 12, color: .monologueTextSecondary.opacity(0.45))
        }
    }
}

struct PlaylistPickerEmptyStateCard: View {
    let icon: MonologueIcon.IconType
    let message: String

    var body: some View {
        PlaylistPickerContainerCard {
            HStack(spacing: 12) {
                MonologueIcon(icon: icon, size: 18, color: .monologueTextSecondary.opacity(0.7))

                Text(message)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Color.monologueTextSecondary)
            }
        }
    }
}

private struct PlaylistPickerArtwork: View {
    let coverURL: URL?
    let placeholderIcon: MonologueIcon.IconType

    var body: some View {
        Group {
            if let coverURL {
                CachedAsyncImage(url: coverURL.sized(200)) {
                    placeholder
                }
                .aspectRatio(contentMode: .fill)
            } else {
                placeholder
            }
        }
        .frame(width: 50, height: 50)
        .clipShape(.rect(cornerRadius: 12, style: .continuous))
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(NeumorphicStyle.isActive ? Color.clear : Color.monologueGlassTint)
                .background {
                    if NeumorphicStyle.isActive {
                        NeumorphicSurfaceBackground(cornerRadius: 12, elevated: false, pressed: true, lightweight: true)
                    }
                }

            MonologueIcon(icon: placeholderIcon, size: 18, color: (NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : .monologueTextSecondary).opacity(0.45))
        }
    }
}
