import WidgetKit
import SwiftUI

// MARK: - 共享组件

/// 从时间线内嵌图片数据渲染封面，缺失时显示音乐占位图。
struct CoverImage: View {
    let data: Data?
    let radius: CGFloat

    var body: some View {
        if let data, let img = UIImage(data: data) {
            Image(uiImage: img)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Color(white: 0.95))
                .overlay(Image(systemName: "music.note").font(.title).foregroundStyle(.gray))
        }
    }
}

/// Widget 主题共用的四段波浪装饰形状。
struct GreenSquiggle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width; let h = rect.height
        path.move(to: CGPoint(x: 0, y: h/2))
        path.addQuadCurve(to: CGPoint(x: w/4, y: h/2), control: CGPoint(x: w/8, y: -h/2))
        path.addQuadCurve(to: CGPoint(x: 2*w/4, y: h/2), control: CGPoint(x: 3*w/8, y: 1.5*h))
        path.addQuadCurve(to: CGPoint(x: 3*w/4, y: h/2), control: CGPoint(x: 5*w/8, y: -h/2))
        path.addQuadCurve(to: CGPoint(x: w, y: h/2), control: CGPoint(x: 7*w/8, y: 1.5*h))
        return path
    }
}
