import Combine
import QQMusicKit
import SwiftUI
import UniformTypeIdentifiers

struct PetWhiteLibraryStatusPill: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(PetWhiteStyle.titleFont(15, weight: .black))
                .foregroundStyle(PetWhiteStyle.ink)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title)
                .font(PetWhiteStyle.labelFont(9.5, weight: .bold))
                .foregroundStyle(PetWhiteStyle.inkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
        }
        .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            PetWhiteSurfaceBackground(
                cornerRadius: 17,
                elevated: false,
                tint: PetWhiteStyle.surfaceRaised,
                accent: tint
            )
        )
    }
}

struct PetWhiteLibraryPlaylistCard: View {
    let playlist: Playlist
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                CachedAsyncImage(url: playlist.coverUrl?.sized(600)) {
                    PetWhiteStyle.surfacePressed
                        .overlay(
                            PetWhitePetPetIcon(size: 54)
                                .opacity(0.88)
                        )
                }
                .aspectRatio(1, contentMode: .fill)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(PetWhiteStyle.stroke, lineWidth: 1)
                )

                PetWhitePackIcon(icon: .play, size: 15, visualScale: 1.08)
                    .frame(width: 34, height: 34)
                    .background(tint, in: Circle())
                    .overlay(Circle().stroke(PetWhiteStyle.stroke, lineWidth: 1))
                    .padding(8)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(PetWhiteStyle.bodyFont(13, weight: .black))
                    .foregroundStyle(PetWhiteStyle.ink)
                    .lineLimit(2)
                    .frame(minHeight: 36, alignment: .topLeading)

                HStack(spacing: 6) {
                    Capsule()
                        .fill(tint)
                        .frame(width: 22, height: 5)
                    Text(metaText)
                        .font(PetWhiteStyle.labelFont(10, weight: .bold))
                        .foregroundStyle(PetWhiteStyle.inkSoft)
                        .lineLimit(1)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            PetWhiteSurfaceBackground(
                cornerRadius: 24,
                elevated: true,
                tint: PetWhiteStyle.surfaceRaised,
                accent: tint
            )
        )
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var metaText: String {
        if let playCount = playlist.playCount, playCount > 0 {
            return cinematicFormatCount(playCount)
        }
        if let trackCount = playlist.trackCount, trackCount > 0 {
            return String(format: String(localized: "songs_count_format"), trackCount)
        }
        return playlist.sourceShortName
    }
}

struct LiquidGlassRefractionHeaderShape: InsettableShape {
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let rect = rect.insetBy(dx: insetAmount, dy: insetAmount)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.16, y: rect.minY + rect.height * 0.03))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.14, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.32),
            control: CGPoint(x: rect.maxX + rect.width * 0.02, y: rect.minY + rect.height * 0.08)
        )
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.05, y: rect.maxY - rect.height * 0.17))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - rect.width * 0.22, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY + rect.height * 0.02)
        )
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.maxY - rect.height * 0.02))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - rect.height * 0.28),
            control: CGPoint(x: rect.minX - rect.width * 0.02, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.02, y: rect.minY + rect.height * 0.24))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.16, y: rect.minY + rect.height * 0.03),
            control: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.08)
        )
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> LiquidGlassRefractionHeaderShape {
        var shape = self
        shape.insetAmount += amount
        return shape
    }
}
