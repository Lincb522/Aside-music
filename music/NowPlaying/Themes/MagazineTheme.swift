// MagazineTheme.swift
// Monologue Widget Extension

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Magazine Theme (杂志)

struct MagazineTheme: View {
    let entry: NowPlayingEntry
    let family: WidgetFamily

    private let paper = Color(hex: "F4F1EA")
    private let ink = Color(hex: "1A1A1A")
    private let inkLight = Color(hex: "6B6560")
    private let rule = Color(hex: "C8C0B4")
    private let accent = Color(hex: "C23616")

    init(entry: NowPlayingEntry, family: WidgetFamily) {
        self.entry = entry
        self.family = family
    }

    private var displaySong: String { entry.isEmpty ? "未在播放" : entry.songName }
    private var displayArtist: String { entry.isEmpty ? "暂无歌曲信息" : entry.artistName }
    private var displayLyric: String { entry.lyricText.isEmpty ? "" : entry.lyricText }

    private var issueNumber: String {
        guard entry.queueIndex > 0 else { return "No.—" }
        return "No.\(entry.queueIndex)"
    }

    var body: some View {
        switch family {
        case .systemMedium: mediumLayout
        case .systemLarge:  largeLayout
        default:            smallLayout
        }
    }

    // MARK: - Small

    private var smallLayout: some View {
        GeometryReader { geo in
            let pad: CGFloat = 12
            let coverH = geo.size.height * 0.60

            VStack(spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    CoverImage(data: entry.coverImageData, radius: 0)
                        .frame(height: coverH)
                        .clipped()

                    LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .center, endPoint: .bottom)
                        .frame(height: coverH * 0.5)

                    if !entry.isEmpty {
                        Text(issueNumber)
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(accent)
                            .padding(.leading, pad)
                            .padding(.bottom, 6)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(displaySong)
                        .font(.system(size: 14, weight: .black, design: .serif))
                        .foregroundStyle(ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                        .contentTransition(.interpolate)

                    Rectangle().fill(rule).frame(height: 0.8)

                    HStack(spacing: 0) {
                        if !entry.isEmpty {
                            HStack(spacing: 12) {
                                Button(intent: PreviousTrackIntent()) {
                                    Image(systemName: "backward.fill")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(ink.opacity(0.5))
                                }.buttonStyle(.plain)

                                Button(intent: TogglePlaybackIntent()) {
                                    Image(systemName: entry.controlSymbolName)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(accent)
                                        .contentTransition(.symbolEffect(.replace))
                                }.buttonStyle(.plain)

                                Button(intent: NextTrackIntent()) {
                                    Image(systemName: "forward.fill")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(ink.opacity(0.5))
                                }.buttonStyle(.plain)
                            }
                        }

                        Spacer()

                        Text(displayArtist)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(inkLight)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                }
                .padding(.horizontal, pad)
                .padding(.top, 7)
                .padding(.bottom, 8)
            }
        }
        .widgetURL(URL(string: "monologue://player"))
    }

    // MARK: - Medium

    private var mediumLayout: some View {
        GeometryReader { geo in
            let coverSize = geo.size.height
            let pad: CGFloat = 14

            HStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    CoverImage(data: entry.coverImageData, radius: 0)
                        .frame(width: coverSize, height: coverSize)
                        .clipped()

                    if !entry.isEmpty {
                        Text(issueNumber)
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(accent)
                            .padding(.leading, 8)
                            .padding(.top, 8)
                    }
                }

                VStack(alignment: .leading, spacing: 0) {
                    Text("MONO")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(accent)
                        .tracking(4)

                    Spacer(minLength: 4)

                    Text(displaySong)
                        .font(.system(size: 20, weight: .black, design: .serif))
                        .foregroundStyle(ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .contentTransition(.interpolate)

                    Text(displayArtist)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(inkLight)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.top, 2)

                    Spacer(minLength: 4)

                    if !displayLyric.isEmpty {
                        Text(displayLyric)
                            .font(.system(size: 11, weight: .medium, design: .serif))
                            .foregroundStyle(ink)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                    }

                    Spacer(minLength: 4)

                    Rectangle().fill(rule).frame(height: 0.8)

                    HStack(spacing: 0) {
                        if !entry.isEmpty {
                            HStack(spacing: 14) {
                                Button(intent: PreviousTrackIntent()) {
                                    Image(systemName: "backward.fill")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(ink.opacity(0.5))
                                }.buttonStyle(.plain)

                                Button(intent: TogglePlaybackIntent()) {
                                    Image(systemName: entry.controlSymbolName)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(accent)
                                        .contentTransition(.symbolEffect(.replace))
                                }.buttonStyle(.plain)

                                Button(intent: NextTrackIntent()) {
                                    Image(systemName: "forward.fill")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(ink.opacity(0.5))
                                }.buttonStyle(.plain)
                            }

                            Spacer(minLength: 8)
                        }

                        VStack(alignment: .trailing, spacing: 1) {
                            Text(entry.qualityText.isEmpty ? "--" : entry.qualityText)
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(accent)
                            if let bpm = entry.tempoBPM, bpm > 0 {
                                Text("\(bpm) BPM")
                                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                                    .foregroundStyle(inkLight)
                            }
                        }
                    }
                    .padding(.top, 6)
                }
                .padding(.horizontal, pad)
                .padding(.vertical, 10)
            }
        }
        .widgetURL(URL(string: "monologue://player"))
    }

    // MARK: - Large — 杂志内页风格

    private var largeLayout: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let pad: CGFloat = 20

            VStack(spacing: 0) {
                HStack {
                    Text("MONO")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(accent)
                        .tracking(5)
                    Spacer()
                    if !entry.isEmpty {
                        Text(issueNumber)
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(accent)
                    }
                }
                .padding(.horizontal, pad)
                .padding(.top, 14)

                Rectangle().fill(ink).frame(height: 2)
                    .padding(.horizontal, pad)
                    .padding(.top, 6)

                HStack(alignment: .top, spacing: 14) {
                    CoverImage(data: entry.coverImageData, radius: 4)
                        .frame(width: w * 0.38, height: w * 0.38)
                        .clipped()
                        .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)

                    VStack(alignment: .leading, spacing: 0) {
                        Text(displaySong)
                            .font(.system(size: 22, weight: .black, design: .serif))
                            .foregroundStyle(ink)
                            .lineLimit(3)
                            .minimumScaleFactor(0.65)
                            .contentTransition(.interpolate)

                        Text(displayArtist)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(inkLight)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .padding(.top, 4)

                        if !entry.albumName.isEmpty {
                            Text(entry.albumName)
                                .font(.system(size: 10, weight: .regular, design: .serif))
                                .foregroundStyle(inkLight.opacity(0.7))
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                                .padding(.top, 2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, pad)
                .padding(.top, 12)

                if !displayLyric.isEmpty {
                    Text("「\(displayLyric)」")
                        .font(.system(size: 13, weight: .medium, design: .serif))
                        .foregroundStyle(ink.opacity(0.7))
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, pad)
                        .padding(.top, 10)
                }

                Spacer(minLength: 6)

                Rectangle().fill(rule).frame(height: 0.8)
                    .padding(.horizontal, pad)

                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 2) {
                        if !entry.qualityText.isEmpty {
                            HStack(spacing: 4) {
                                Text("音质")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(accent)
                                Text(entry.qualityText)
                                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                                    .foregroundStyle(inkLight)
                            }
                        }
                        HStack(spacing: 8) {
                            Text(entry.playModeText)
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(inkLight)
                            if let bpm = entry.tempoBPM, bpm > 0 {
                                Text("\(bpm) BPM")
                                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                                    .foregroundStyle(inkLight)
                            }
                        }
                    }

                    Spacer()

                    if !entry.isEmpty {
                        HStack(spacing: 18) {
                            Button(intent: PreviousTrackIntent()) {
                                Image(systemName: "backward.fill")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(ink.opacity(0.4))
                            }.buttonStyle(.plain)

                            Button(intent: TogglePlaybackIntent()) {
                                ZStack {
                                    Circle().fill(accent)
                                        .frame(width: 42, height: 42)
                                    Image(systemName: entry.controlSymbolName)
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(.white)
                                        .contentTransition(.symbolEffect(.replace))
                                }
                            }.buttonStyle(.plain)

                            Button(intent: NextTrackIntent()) {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(ink.opacity(0.4))
                            }.buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, pad)
                .padding(.vertical, 10)

                Rectangle().fill(rule).frame(height: 0.8)
                    .padding(.horizontal, pad)

                HStack {
                    Text("MONO MUSIC EDITORIAL")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundStyle(inkLight.opacity(0.5))
                        .tracking(2)
                    Spacer()
                    Text(entry.sourceName.uppercased())
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundStyle(inkLight.opacity(0.5))
                }
                .padding(.horizontal, pad)
                .padding(.top, 4)
                .padding(.bottom, 10)
            }
        }
        .widgetURL(URL(string: "monologue://player"))
    }
}
