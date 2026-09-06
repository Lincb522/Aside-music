import SwiftUI

struct ArtistDetailTab: Identifiable {
    let id: Int
    let title: String
    var count: Int? = nil
}

/// Shared artist presentation across music sources. The name image keeps its original alpha and aspect ratio.
struct ArtistDetailPage<Content: View>: View {
    let identity: ArtistNameArtworkIdentity
    let coverURL: URL?
    let source: String
    var fansCount: Int? = nil
    var summary: String? = nil
    let tabs: [ArtistDetailTab]
    @Binding var selectedTab: Int
    let canPlay: Bool
    let play: () -> Void
    let secondaryAction: () -> Void
    var showBiography: (() -> Void)? = nil
    @ViewBuilder let content: () -> Content

    @State private var nameArtworkURL: URL?
    @State private var backgroundColor = Color(red: 0.20, green: 0.22, blue: 0.20)

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundColor.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 0) {
                        header(width: min(geometry.size.width, 900))
                        tabBar
                            .padding(.top, 24)
                        content()
                            .padding(.top, 10)
                        FloatingBarBottomSpacer()
                    }
                    .frame(maxWidth: 900)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
                .ignoresSafeArea(edges: .top)
            }
        }
        .foregroundStyle(.white)
        .tint(.white)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .monoNavigationBackButton(iconColor: .white)
        .task(id: identity) {
            nameArtworkURL = nil
            do {
                let url = try await APIService.shared.artistNameArtwork(
                    name: identity.name, aliases: identity.aliases, qqMid: identity.qqMid
                )
                guard !Task.isCancelled else { return }
                nameArtworkURL = url
            } catch {
                guard !Task.isCancelled else { return }
                AppLogger.error("[ArtistArtwork] Name artwork request failed: \(error.localizedDescription)")
            }
        }
        .task(id: coverURL) {
            guard let coverURL,
                  let colors = await MonoColorEngine.shared.colors(
                    for: coverURL.absoluteString, count: 2, mode: .adaptive, randomSeed: 0
                  ), !Task.isCancelled else { return }
            backgroundColor = Self.readableBackground(colors.dominant)
        }
    }

    private func header(width: CGFloat) -> some View {
        let photoHeight = min(max(width * 1.06, 340), 610)
        return VStack(spacing: 16) {
            Color.clear.frame(height: photoHeight * 0.72)
                .accessibilityHidden(true)

            nameArtwork(width: width)
                .padding(.horizontal, 32)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { metadata }
                VStack(spacing: 6) { metadata }
            }
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.90))
            .padding(.horizontal, 24)

            if let summary, !summary.isEmpty, let showBiography {
                Button(action: showBiography) {
                    HStack(spacing: 6) {
                        Text(summary).lineLimit(1)
                        Image(systemName: "chevron.right").font(.caption)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.90))
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
            }

            HStack(spacing: 12) {
                Button(action: play) {
                    Image(systemName: "play.fill")
                        .font(.title2)
                        .frame(width: 96, height: 48)
                        .foregroundStyle(backgroundColor)
                        .background(.white, in: Capsule())
                }
                .disabled(!canPlay)
                .opacity(canPlay ? 1 : 0.45)
                .accessibilityLabel(String(localized: "artist_play_all"))

                Button(action: secondaryAction) {
                    Image(systemName: "plus")
                        .font(.title2.weight(.medium))
                        .frame(width: 96, height: 48)
                        .background(.white.opacity(0.12), in: Capsule())
                }
                .disabled(!canPlay)
                .opacity(canPlay ? 1 : 0.45)
                .accessibilityLabel(String(localized: "song_add_to_playlist"))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(alignment: .top) {
            GeometryReader { proxy in
                CachedAsyncImage(url: coverURL) { backgroundColor }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: proxy.size.width, height: photoHeight + 64, alignment: .top)
                    .clipped()
                    .overlay {
                        LinearGradient(stops: [
                            .init(color: .black.opacity(0.18), location: 0),
                            .init(color: .clear, location: 0.35),
                            .init(color: backgroundColor.opacity(0.35), location: 0.60),
                            .init(color: backgroundColor, location: 0.94)
                        ], startPoint: .top, endPoint: .bottom)
                    }
            }
            .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var metadata: some View {
        Text(source)
        if let fansCount, fansCount > 0 {
            Text(String(format: String(localized: "artist_fans_count"), fansCount.formatted(.number.notation(.compactName))))
        }
    }

    private func nameArtwork(width: CGFloat) -> some View {
        // CachedAsyncImage's disk cache encodes JPEG. AsyncImage preserves the transparent PNG bytes.
        AsyncImage(url: nameArtworkURL) { phase in
            if let image = phase.image {
                image.renderingMode(.template).resizable()
                    .scaledToFit()
                    .frame(maxWidth: min(width * 0.72, 460), maxHeight: 100)
                    .foregroundStyle(.white)
                    .accessibilityLabel(identity.name)
                    .accessibilityAddTraits(.isHeader)
            } else {
                Text(identity.name)
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
        }
        .frame(minHeight: 56)
    }

    private var tabBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 26) {
                ForEach(tabs) { tab in
                    Button {
                        selectedTab = tab.id
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline, spacing: 5) {
                                Text(tab.title).font(.headline)
                                if let count = tab.count, count > 0 {
                                    Text(count.formatted()).font(.caption)
                                }
                            }
                            Capsule()
                                .fill(selectedTab == tab.id ? .white : .clear)
                                .frame(width: 24, height: 3)
                        }
                        .foregroundStyle(.white.opacity(selectedTab == tab.id ? 1 : 0.80))
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selectedTab == tab.id ? .isSelected : [])
                }
            }
            .padding(.horizontal, 24)
        }
        .scrollIndicators(.hidden)
    }

    private static func readableBackground(_ color: Color) -> Color {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        // Bound brightness so white text remains legible on pale artist photography.
        func luminance(_ value: CGFloat) -> CGFloat {
            value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        while 0.2126 * luminance(red) + 0.7152 * luminance(green) + 0.0722 * luminance(blue) > 0.13 {
            red *= 0.96; green *= 0.96; blue *= 0.96
        }
        return Color(red: red, green: green, blue: blue)
    }
}

struct ArtistAlbumRow: View {
    let album: AlbumInfo
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                CachedAsyncImage(url: album.coverUrl?.sized(200)) { Color.white.opacity(0.10) }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 68, height: 68)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 6) {
                    Text(album.name).font(.body.weight(.medium)).lineLimit(2)
                    Text(album.publishDateText).font(.caption).foregroundStyle(.white.opacity(0.85))
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption)
            }
            .foregroundStyle(.white)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct ArtistContentState: View {
    var isLoading = false
    let text: String

    var body: some View {
        VStack(spacing: 12) {
            if isLoading { ProgressView().tint(.white) }
            else { Text(text).font(.body).foregroundStyle(.white.opacity(0.85)) }
        }
        .frame(maxWidth: .infinity, minHeight: 140)
        .padding(.horizontal, 24)
    }
}

struct ArtistVideoCard: View {
    let name: String
    let coverURL: URL?
    let duration: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Color.white.opacity(0.10)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .overlay {
                        GeometryReader { proxy in
                            CachedAsyncImage(url: coverURL) { Color.clear }
                                .aspectRatio(contentMode: .fill)
                                .frame(width: proxy.size.width, height: proxy.size.height)
                                .clipped()
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if !duration.isEmpty {
                            Text(duration).font(.caption.monospacedDigit())
                                .padding(5)
                                .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 4))
                                .padding(6)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text(name).font(.subheadline).lineLimit(2)
            }
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}
