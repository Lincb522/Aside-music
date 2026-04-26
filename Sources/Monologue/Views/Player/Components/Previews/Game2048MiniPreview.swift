import SwiftUI

/// 2048 主题选择器预览 — 迷你棋盘动态展示
struct Game2048MiniPreview: View {
    @State private var layoutIdx = 0
    @State private var appeared = false

    // 迷你布局配置
    private struct MP { let c: Int, r: Int }
    private struct ML {
        let cover, lyrics, song, mode, like, prev, next, artist, quality: MP
    }

    private static let layouts: [ML] = [
        ML(cover: MP(c:0,r:0), lyrics: MP(c:2,r:2), song: MP(c:0,r:2),
           mode: MP(c:2,r:0), like: MP(c:3,r:0), prev: MP(c:2,r:1), next: MP(c:3,r:1),
           artist: MP(c:0,r:3), quality: MP(c:1,r:3)),
        ML(cover: MP(c:2,r:2), lyrics: MP(c:0,r:0), song: MP(c:2,r:0),
           mode: MP(c:0,r:2), like: MP(c:1,r:2), prev: MP(c:0,r:3), next: MP(c:1,r:3),
           artist: MP(c:2,r:1), quality: MP(c:3,r:1)),
        ML(cover: MP(c:2,r:0), lyrics: MP(c:0,r:2), song: MP(c:0,r:0),
           mode: MP(c:0,r:1), like: MP(c:1,r:1), prev: MP(c:2,r:2), next: MP(c:3,r:2),
           artist: MP(c:2,r:3), quality: MP(c:3,r:3)),
        ML(cover: MP(c:0,r:2), lyrics: MP(c:2,r:0), song: MP(c:0,r:0),
           mode: MP(c:0,r:1), like: MP(c:1,r:1), prev: MP(c:2,r:2), next: MP(c:3,r:2),
           artist: MP(c:2,r:3), quality: MP(c:3,r:3)),
    ]

    // 调色板
    private let boardBg = Color(hex: "BBADA0")
    private let empty   = Color(hex: "CDC1B4")
    private let t2048   = Color(hex: "EDC22E")
    private let t256    = Color(hex: "EDCC61")
    private let t1024   = Color(hex: "EDC53F")
    private let t2      = Color(hex: "EEE4DA")
    private let t4      = Color(hex: "EDE0C8")
    private let t8      = Color(hex: "F2B179")
    private let t16     = Color(hex: "F59563")
    private let t32     = Color(hex: "F67C5F")
    private let t64     = Color(hex: "F65E3B")
    private let darkFg  = Color(hex: "776E65")
    private let lightFg = Color(hex: "F9F6F2")

    private let cell: CGFloat = 13
    private let gap: CGFloat = 2.5
    private let cr: CGFloat = 2

    private var L: ML { Self.layouts[layoutIdx % Self.layouts.count] }

    private func off(_ p: MP) -> CGSize {
        CGSize(width: CGFloat(p.c) * (cell + gap), height: CGFloat(p.r) * (cell + gap))
    }
    private var dbl: CGFloat { cell * 2 + gap }
    private var grid: CGFloat { cell * 4 + gap * 3 }

    var body: some View {
        ZStack {
            boardBg

            VStack(spacing: gap) {
                ZStack(alignment: .topLeading) {
                    // 空格子
                    ForEach(0..<4, id: \.self) { r in
                        ForEach(0..<4, id: \.self) { c in
                            RoundedRectangle(cornerRadius: cr, style: .continuous)
                                .fill(empty)
                                .frame(width: cell, height: cell)
                                .offset(x: CGFloat(c) * (cell + gap), y: CGFloat(r) * (cell + gap))
                        }
                    }

                    // 封面 2048
                    miniBlock(t2048, w: dbl, h: dbl)
                        .overlay(Text("2048").font(.system(size: 6.5, weight: .black, design: .rounded))
                            .foregroundColor(lightFg))
                        .shadow(color: t2048.opacity(0.4), radius: 2)
                        .offset(off(L.cover))

                    // 歌词 256
                    miniBlock(t256, w: dbl, h: dbl)
                        .overlay(
                            VStack(spacing: 1) {
                                MonologueSymbolIcon(name: "text.quote", size: 7, color: lightFg)
                                Text("256").font(.system(size: 4.5, weight: .black, design: .rounded)).opacity(0.5)
                            }.foregroundColor(lightFg)
                        )
                        .offset(off(L.lyrics))

                    // 歌名 1024
                    miniBlock(t1024, w: dbl, h: cell)
                        .overlay(Text("1024").font(.system(size: 5, weight: .black, design: .rounded))
                            .foregroundColor(lightFg))
                        .offset(off(L.song))

                    // 小方块
                    miniBlock(t2, w: cell, h: cell)
                        .overlay(Text("2").font(.system(size: 5.5, weight: .black, design: .rounded))
                            .foregroundColor(darkFg))
                        .offset(off(L.mode))

                    miniBlock(t4, w: cell, h: cell)
                        .overlay(Text("4").font(.system(size: 5.5, weight: .black, design: .rounded))
                            .foregroundColor(darkFg))
                        .offset(off(L.like))

                    miniBlock(t8, w: cell, h: cell)
                        .overlay(MonologueIcon(icon: .previous, size: 6, color: lightFg, lineWidth: 1.3))
                        .offset(off(L.prev))

                    miniBlock(t16, w: cell, h: cell)
                        .overlay(MonologueIcon(icon: .next, size: 6, color: lightFg, lineWidth: 1.3))
                        .offset(off(L.next))

                    miniBlock(t32, w: cell, h: cell)
                        .overlay(Text("32").font(.system(size: 4.5, weight: .black, design: .rounded))
                            .foregroundColor(lightFg))
                        .offset(off(L.artist))

                    miniBlock(t64, w: cell, h: cell)
                        .overlay(Text("64").font(.system(size: 4.5, weight: .black, design: .rounded))
                            .foregroundColor(lightFg))
                        .offset(off(L.quality))
                }
                .frame(width: grid, height: grid, alignment: .topLeading)
                .clipped()
                .animation(.spring(response: 0.5, dampingFraction: 0.72), value: layoutIdx)

                // 进度条
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1.5).fill(empty)
                        .frame(width: grid, height: 3.5)
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(LinearGradient(colors: [t8, t2048], startPoint: .leading, endPoint: .trailing))
                        .frame(width: grid * 0.55, height: 3.5)
                }
            }
            .padding(3.5)
        }
        .onAppear {
            // 每 2 秒自动切换布局
            Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) {
                    layoutIdx = (layoutIdx + 1) % Self.layouts.count
                }
            }
        }
    }

    private func miniBlock(_ color: Color, w: CGFloat, h: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cr, style: .continuous)
            .fill(color)
            .frame(width: w, height: h)
    }
}
