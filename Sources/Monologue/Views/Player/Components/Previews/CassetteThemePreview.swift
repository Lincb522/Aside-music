import SwiftUI

struct CassetteThemePreview: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var reelRotation: Double = 0

    var body: some View {
        let isDark = colorScheme == .dark
        let card = isDark ? Color(hex: "222222") : Color.white
        let inner = isDark ? Color(hex: "111111") : Color(hex: "EEEEEE")
        let spkr = isDark ? Color(hex: "1A1A1A") : Color(hex: "F8F8F8")
        let tw = isDark ? Color.white : Color.black
        let td = isDark ? Color.white.opacity(0.5) : Color.black.opacity(0.4)
        let info = isDark ? Color(hex: "2A2A2A") : Color(hex: "F0F0F0")
        let pBg = isDark ? Color(hex: "333333") : Color(hex: "DDDDDD")
        let pDot = Color(hex: "FF3B30")
        
        return ZStack {
            if isDark {
                Color(hex: "18181A")
            } else {
                Color(hex: "EFEFEF")
            }

            VStack(spacing: 0) {
                // Cassette top
                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: 12).fill(card).frame(height: 50)
                    // Inner tape window
                    RoundedRectangle(cornerRadius: 4).fill(inner).frame(width: 60, height: 22).offset(y: 16)
                        .overlay(
                            HStack(spacing: 20) {
                                // Left reel
                                ZStack {
                                    Circle().fill(Color.white.opacity(0.1)).frame(width: 14, height: 14)
                                    Circle().stroke(Color.white.opacity(0.2), lineWidth: 1).frame(width: 8, height: 8)
                                    // Spikes
                                    ForEach(0..<3, id: \.self) { i in
                                        Rectangle().fill(Color.white.opacity(0.3)).frame(width: 1, height: 8)
                                            .rotationEffect(.degrees(Double(i) * 60))
                                    }
                                }
                                .rotationEffect(.degrees(reelRotation))
                                
                                // Right reel
                                ZStack {
                                    Circle().fill(Color.white.opacity(0.1)).frame(width: 14, height: 14)
                                    Circle().stroke(Color.white.opacity(0.2), lineWidth: 1).frame(width: 8, height: 8)
                                    // Spikes
                                    ForEach(0..<3, id: \.self) { i in
                                        Rectangle().fill(Color.white.opacity(0.3)).frame(width: 1, height: 8)
                                            .rotationEffect(.degrees(Double(i) * 60))
                                    }
                                }
                                .rotationEffect(.degrees(reelRotation))
                            }
                            .offset(y: 16)
                        )
                    // Labels
                    VStack(spacing: 2) {
                        Capsule().fill(Color.orange.opacity(0.8)).frame(width: 40, height: 4)
                        HStack(spacing: 2) {
                            Capsule().fill(Color.blue.opacity(0.6)).frame(width: 15, height: 2)
                            Capsule().fill(Color.green.opacity(0.6)).frame(width: 25, height: 2)
                        }
                    }
                    .padding(.top, 6)
                }
                .padding(.horizontal, 6)
                .padding(.top, 6)
                .padding(.bottom, 4)

                HStack(spacing: 5) {
                    // Speaker
                    ZStack {
                        RoundedRectangle(cornerRadius: 8).fill(spkr).frame(width: 52, height: 52)
                        ForEach(0..<3, id: \.self) { i in
                            Circle().stroke(Color.white.opacity(0.06), lineWidth: 1)
                                .frame(width: CGFloat(18 + i * 8), height: CGFloat(18 + i * 8))
                        }
                        Circle().fill(Color.white.opacity(0.06)).frame(width: 8, height: 8)
                        // Mini chrome spheres
                        ZStack {
                            Circle().fill(RadialGradient(colors: [.white.opacity(0.8), .gray], center: .init(x: 0.3, y: 0.3), startRadius: 0, endRadius: 4))
                                .frame(width: 7, height: 7)
                            Circle().fill(RadialGradient(colors: [.white.opacity(0.75), .gray], center: .init(x: 0.35, y: 0.25), startRadius: 0, endRadius: 3))
                                .frame(width: 5, height: 5).offset(x: -5, y: -3)
                            Circle().fill(RadialGradient(colors: [.white.opacity(0.7), .gray], center: .init(x: 0.3, y: 0.3), startRadius: 0, endRadius: 2))
                                .frame(width: 4, height: 4).offset(x: 3, y: -5)
                        }
                        .offset(x: 8, y: 10)
                    }

                    // Info card
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 3) {
                            RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.15))
                                .frame(width: 14, height: 14)
                            VStack(alignment: .leading, spacing: 1) {
                                Capsule().fill(tw.opacity(0.8)).frame(width: 28, height: 3)
                                Capsule().fill(td.opacity(0.5)).frame(width: 20, height: 2)
                            }
                        }
                        // Thick progress
                        ZStack(alignment: .leading) {
                            Capsule().fill(pBg).frame(height: 8)
                            Circle().fill(pDot).frame(width: 5, height: 5).offset(x: 14)
                        }
                    }
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(info))
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 6)
            }
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(card).padding(4))
        }
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                reelRotation = 360
            }
        }
    }
}
