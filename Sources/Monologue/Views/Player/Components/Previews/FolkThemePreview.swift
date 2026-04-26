import SwiftUI

struct FolkThemePreview: View {
    @State private var photoRotation: Double = -3
    @State private var lyricOpacity: Double = 0.3

    var body: some View {
        let paperBg = Color(hex: "F4EBE0")
        let inkDark = Color(hex: "2A2520")
        let inkFaded = Color(hex: "8A8075")
        let redStamp = Color(hex: "BE4A41")
        let tapeColor = Color(hex: "E6D5B8")

        return ZStack {
            // 信纸背景
            paperBg

            VStack(spacing: 8) {
                // 顶部日期图章
                HStack {
                    Spacer()
                    VStack(spacing: 1) {
                        Capsule().fill(redStamp.opacity(0.8)).frame(width: 20, height: 1)
                        Capsule().fill(inkDark).frame(width: 32, height: 1)
                    }
                    .padding(3)
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(redStamp.opacity(0.5), lineWidth: 0.5))
                    .rotationEffect(.degrees(-2))
                }
                .padding(.horizontal, 10)
                .padding(.top, 6)

                // 封面与寄信人
                HStack(spacing: 6) {
                    ZStack {
                        Color.white
                        Rectangle().fill(inkFaded.opacity(0.2)).frame(width: 20, height: 20)
                    }
                    .frame(width: 24, height: 24)
                    .shadow(color: inkDark.opacity(0.1), radius: 2, x: 1, y: 1)
                    .rotationEffect(.degrees(photoRotation))
                    .overlay(
                        Rectangle().fill(tapeColor.opacity(0.8)).frame(width: 12, height: 4)
                            .rotationEffect(.degrees(-10)).offset(y: -10)
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 2) {
                            Capsule().fill(redStamp).frame(width: 10, height: 1)
                            Capsule().fill(inkDark).frame(width: 24, height: 2)
                        }
                        HStack(spacing: 2) {
                            Capsule().fill(inkFaded).frame(width: 10, height: 1)
                            Capsule().fill(inkFaded).frame(width: 18, height: 1.5)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 10)

                // 打字机歌词
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 2) {
                        Text("-").font(.system(size: 3)).foregroundColor(inkFaded)
                        Capsule().fill(inkDark).frame(width: 48, height: 2)
                    }
                    HStack(alignment: .top, spacing: 2) {
                        Text("-").font(.system(size: 3)).foregroundColor(redStamp)
                        Capsule().fill(inkDark).frame(width: 36, height: 2)
                    }
                    .opacity(lyricOpacity)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.top, 4)

                Spacer(minLength: 0)

                // 进度与控制
                VStack(spacing: 4) {
                    // 虚线与实线进度
                    ZStack(alignment: .leading) {
                        Capsule().fill(inkFaded.opacity(0.3)).frame(height: 0.5)
                        Capsule().fill(inkDark).frame(width: 28, height: 1)
                        Path { p in p.move(to: .zero); p.addLine(to: CGPoint(x: 2, y: 2)); p.addLine(to: CGPoint(x: -2, y: 2)); p.closeSubpath() }
                            .fill(inkDark).offset(x: 27, y: -1)
                    }
                    .padding(.horizontal, 10)

                    // 按钮
                    HStack(spacing: 8) {
                        MonologueIcon(icon: .previous, size: 5, color: inkDark, lineWidth: 1.3)
                            .background(Circle().stroke(inkFaded.opacity(0.3), lineWidth: 0.5).frame(width: 8, height: 8))
                        
                        ZStack {
                            Circle().fill(inkDark).frame(width: 14, height: 14)
                            MonologueIcon(icon: .play, size: 5, color: paperBg, lineWidth: 1.3)
                        }

                        MonologueIcon(icon: .next, size: 5, color: inkDark, lineWidth: 1.3)
                            .background(Circle().stroke(inkFaded.opacity(0.3), lineWidth: 0.5).frame(width: 8, height: 8))
                    }
                }
                .padding(.bottom, 6)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                photoRotation = -6
            }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                lyricOpacity = 1.0
            }
        }
    }
}
