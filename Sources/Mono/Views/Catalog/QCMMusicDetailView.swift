// qcm歌手/专辑/歌单详情页
// 歌手：Hero 大图 + Tab（音乐/专辑/MV）
// 专辑：封面 + 歌手 + 发行信息 + 歌曲列表
// 歌单：封面 + 创建者 + 歌曲列表

import SwiftUI
import Combine
import QQMusicKit

// MARK: - qcm详情类型

enum QQDetailType {
    case artist(mid: String, name: String, coverUrl: String?)
    case album(mid: String, name: String, coverUrl: String?, artistName: String?)
    case playlist(id: Int, name: String, coverUrl: String?, creatorName: String?)
}

enum QQDetailPalette {
    static var accent: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.ink }
        return NeumorphicStyle.isActive ? NeumorphicStyle.accent : .monoIconBackground
    }

    static var accentForeground: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.onAccent }
        if NeumorphicStyle.isActive {
            return ThemeColorCustomization.readableForegroundColor(
                on: NeumorphicStyle.accent,
                light: Color(hex: "172026"),
                dark: .white
            )
        }
        return .monoIconForeground
    }

    static var primaryText: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.ink }
        return NeumorphicStyle.isActive ? NeumorphicStyle.ink : .monoTextPrimary
    }

    static var secondaryText: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.inkSoft }
        return NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : .monoTextSecondary
    }

    static var mutedText: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.inkMuted }
        return NeumorphicStyle.isActive ? NeumorphicStyle.inkMuted : .monoTextSecondary
    }

    static var placeholderFill: Color {
        if MinimalWhiteStyle.isActive { return MinimalWhiteStyle.controlGlassFill }
        return NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : .monoGlassTint
    }

    static func pageBase(for colorScheme: ColorScheme) -> Color {
        if MinimalWhiteStyle.isActive {
            return MinimalWhiteStyle.paper
        }
        if NeumorphicStyle.isActive {
            return NeumorphicStyle.base
        }
        return colorScheme == .dark ? Color(hex: "0A0A0A") : Color(hex: "F5F5F7")
    }
}

// MARK: - 路由入口

struct QQMusicDetailView: View {
    let detailType: QQDetailType
    
    var body: some View {
        switch detailType {
        case .artist(let mid, let name, let coverUrl):
            QQArtistDetailView(mid: mid, name: name, coverUrl: coverUrl)
        case .album(let mid, let name, let coverUrl, let artistName):
            QQAlbumDetailView(mid: mid, name: name, coverUrl: coverUrl, artistName: artistName)
        case .playlist(let id, let name, let coverUrl, let creatorName):
            QQPlaylistDetailView(playlistId: id, name: name, coverUrl: coverUrl, creatorName: creatorName)
        }
    }
}
