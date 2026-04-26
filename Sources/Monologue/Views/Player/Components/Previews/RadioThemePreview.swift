import SwiftUI

struct RadioThemePreview: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var ledPhase = 0
    @State private var progressOffset: CGFloat = 0

    var body: some View {
        let isDark = colorScheme == .dark
        let bgTop = isDark ? Color(hex: "1E1040") : Color(hex: "B8A0E0")
        let bgBot = isDark ? Color(hex: "100828") : Color(hex: "9070C0")
        let card = isDark ? Color(hex: "2E2058") : Color(hex: "8B6FC0")
        let ledBg = isDark ? Color(hex: "08060E") : Color(hex: "18102C")
        let ledOn = isDark ? Color(hex: "D0C0F0") : Color(hex: "F0E8FF")
        let ledOff = isDark ? Color(hex: "1E1830") : Color(hex: "2A2040")
        let spkr = isDark ? Color(hex: "18142A") : Color(hex: "2C2444")
        let info = isDark ? Color(hex: "3A2868") : Color(hex: "A088D8")
        let tw = isDark ? Color(hex: "F0E8FF") : Color(hex: "1E1040")
        let td = isDark ? Color(hex: "9080B0") : Color(hex: "5A4880")
        let pBg = isDark ? Color(hex: "14102A") : Color(hex: "3A2858")
        let pDot = isDark ? Color(hex: "80E8A0") : Color(hex: "50D080")

        return ZStack {
            LinearGradient(colors: [bgTop, bgBot], startPoint: .topLeading, endPoint: .bottomTrailing)

            VStack(spacing: 0) {
                // LED
                ZStack {
                    RoundedRectangle(cornerRadius: 5).fill(ledBg)
                    Canvas { ctx, size in
                        let d: CGFloat = 1.6; let g: CGFloat = 4.5
                        for r in stride(from: g, to: size.height, by: g) {
                            for c in stride(from: g, to: size.width, by: g) {
                                ctx.fill(Path(ellipseIn: CGRect(x: c - d/2, y: r - d/2, width: d, height: d)),
                                         with: .color(ledOff))
                            }
                        }
                    }
                    HStack(spacing: 1.5) {
                        ForEach(0..<10, id: \.self) { i in
                            Circle().fill(ledOn.opacity(i < (ledPhase + 3) % 10 ? 0.6 : 0.1)).frame(width: 2.5, height: 2.5)
                        }
                        Capsule().fill(ledOn.opacity(0.8)).frame(width: 18, height: 2.5)
                        ForEach(0..<6, id: \.self) { i in
                            Circle().fill(ledOn.opacity(i < (ledPhase % 6) ? 0.35 : 0.1)).frame(width: 2.5, height: 2.5)
                        }
                    }
                    .animation(.linear(duration: 0.2), value: ledPhase)
                }
                .frame(height: 18)
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
                                .scaleEffect(1.0 + (ledPhase % 2 == 0 ? 0.05 : 0))
                                .animation(.spring(response: 0.3), value: ledPhase)
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
                            Capsule().fill(pBg).frame(width: 40, height: 8)
                            Circle().fill(pDot).frame(width: 5, height: 5).offset(x: progressOffset)
                        }
                        HStack(spacing: 2) {
                            Text("3:42").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(tw)
                            Text("5:10").font(.system(size: 8, weight: .medium, design: .rounded)).foregroundStyle(td)
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
            let timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
                ledPhase += 1
            }
            timer.fire()
            withAnimation(.linear(duration: 5).repeatForever(autoreverses: false)) {
                progressOffset = 30
            }
        }
    }
}
