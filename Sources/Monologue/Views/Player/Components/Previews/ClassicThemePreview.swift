import SwiftUI

struct ClassicThemePreview: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPlaying = false
    @State private var progress: CGFloat = 0

    var body: some View {
        Group {
            if MangaStyle.isActive {
                mangaPreview
            } else if MujiStyle.isActive {
                mujiPreview
            } else {
                defaultPreview
            }
        }
        .onAppear {
            isPlaying = true
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                progress = 1.0
            }
        }
    }

    private var defaultPreview: some View {
        ZStack {
            if colorScheme == .dark {
                Color(hex: "1A1A1E")
            } else {
                Color(hex: "F0F0F2")
            }

            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: colorScheme == .dark
                                ? [Color(hex: "3A3A3E"), Color(hex: "2A2A2E")]
                                : [Color(hex: "D8D8DC"), Color(hex: "C8C8CC")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                    .overlay(
                        MonologueIcon(icon: .musicNote, size: 18, color: colorScheme == .dark ? .white.opacity(0.3) : .black.opacity(0.15))
                    )
                    .scaleEffect(isPlaying ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPlaying)

                VStack(spacing: 4) {
                    progressLine(width: 70, height: 2, fill: colorScheme == .dark ? .white : .black, track: Color.monologueTextSecondary.opacity(0.2))

                    HStack(spacing: 8) {
                        Circle().fill(Color.monologueTextSecondary.opacity(0.3)).frame(width: 6, height: 6)
                        Circle().fill(Color.monologueTextSecondary.opacity(0.3)).frame(width: 8, height: 8)
                        Circle()
                            .fill(colorScheme == .dark ? Color.white : Color.black)
                            .frame(width: 16, height: 16)
                            .scaleEffect(isPlaying ? 1.1 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.5).repeatForever(autoreverses: true), value: isPlaying)
                        Circle().fill(Color.monologueTextSecondary.opacity(0.3)).frame(width: 8, height: 8)
                        Circle().fill(Color.monologueTextSecondary.opacity(0.3)).frame(width: 6, height: 6)
                    }
                }
            }
        }
    }

    private var mangaPreview: some View {
        ZStack {
            LinearGradient(
                colors: [MangaStyle.paper, MangaStyle.paperWarm.opacity(0.86), MangaStyle.bubblePink.opacity(0.48)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            MangaDotsTexture(opacity: colorScheme == .dark ? 0.035 : 0.055, gap: 11)

            VStack(spacing: 7) {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [MangaStyle.bubbleBlue, MangaStyle.bubblePink, MangaStyle.labelYellow.opacity(0.86)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 58)
                        .overlay(MonologueIcon(icon: .musicNote, size: 17, color: MangaStyle.ink))
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(MangaStyle.ink, lineWidth: 2))
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(MangaStyle.ink)
                                .offset(x: 3, y: 3)
                        )
                        .rotationEffect(.degrees(-4))
                        .scaleEffect(isPlaying ? 1.04 : 1)
                        .animation(.spring(response: 0.42, dampingFraction: 0.68).repeatForever(autoreverses: true), value: isPlaying)

                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(MangaStyle.labelYellow)
                            .frame(width: 50, height: 12)
                            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).stroke(MangaStyle.ink, lineWidth: 1))

                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(MangaStyle.bubbleWhite)
                            .frame(width: 66, height: 20)
                            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).stroke(MangaStyle.ink, lineWidth: 1.2))

                        HStack(spacing: 5) {
                            mangaDot(size: 8, fill: MangaStyle.bubbleBlue)
                            mangaDot(size: 8, fill: MangaStyle.bubblePink)
                            mangaDot(size: 8, fill: MangaStyle.labelYellow)
                        }
                    }
                }

                HStack(spacing: 8) {
                    progressLine(width: 78, height: 4, fill: MangaStyle.accentPink, track: MangaStyle.ink.opacity(0.18))
                        .overlay(Capsule().stroke(MangaStyle.ink, lineWidth: 1))

                    mangaDot(size: 18, fill: MangaStyle.labelYellow)
                        .scaleEffect(isPlaying ? 1.12 : 1)
                        .animation(.spring(response: 0.32, dampingFraction: 0.58).repeatForever(autoreverses: true), value: isPlaying)
                }
            }
            .padding(10)
            .background(MangaStyle.bubbleWhite.opacity(0.72), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(MangaStyle.ink, lineWidth: 1.7))
            .padding(10)
        }
    }

    private var mujiPreview: some View {
        ZStack {
            MujiStyle.paper
            LinearGradient(
                colors: [MujiStyle.paperWarm.opacity(0.72), MujiStyle.surface.opacity(0.76), MujiStyle.tea.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            MujiPaperTexture(opacity: colorScheme == .dark ? 0.1 : 0.18)

            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(MujiStyle.surfaceRaised)
                    .frame(width: 58, height: 58)
                    .overlay(MujiPaperTexture(opacity: 0.08).clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous)))
                    .overlay(MonologueIcon(icon: .musicNote, size: 17, color: MujiStyle.clay))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(MujiStyle.hairline.opacity(0.58), lineWidth: 0.7))
                    .padding(6)
                    .background(MujiStyle.surface.opacity(0.82), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(MujiStyle.hairline.opacity(0.4), lineWidth: 0.6))
                    .shadow(color: Color.black.opacity(0.055), radius: 8, x: 0, y: 4)
                    .scaleEffect(isPlaying ? 1.025 : 1)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isPlaying)

                VStack(spacing: 5) {
                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 1, style: .continuous)
                            .fill(MujiStyle.inkSoft.opacity(0.5))
                            .frame(width: 38, height: 2)
                        RoundedRectangle(cornerRadius: 1, style: .continuous)
                            .fill(MujiStyle.hairline.opacity(0.6))
                            .frame(width: 22, height: 2)
                    }

                    progressLine(width: 76, height: 2, fill: MujiStyle.clay, track: MujiStyle.hairline.opacity(0.34))

                    Circle()
                        .fill(MujiStyle.surfaceRaised)
                        .frame(width: 18, height: 18)
                        .overlay(Circle().stroke(MujiStyle.clay.opacity(0.72), lineWidth: 1))
                        .scaleEffect(isPlaying ? 1.08 : 1)
                        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: isPlaying)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(MujiStyle.surface.opacity(0.74), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(MujiStyle.hairline.opacity(0.42), lineWidth: 0.6))
            }
            .padding(10)
        }
    }

    private func progressLine(width: CGFloat, height: CGFloat, fill: Color, track: Color) -> some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(track)
                .frame(width: width, height: height)

            Capsule()
                .fill(fill)
                .frame(width: width * progress, height: height)
        }
    }

    private func mangaDot(size: CGFloat, fill: Color) -> some View {
        Circle()
            .fill(fill)
            .frame(width: size, height: size)
            .overlay(Circle().stroke(MangaStyle.ink, lineWidth: 1.2))
    }
}
