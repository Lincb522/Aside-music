import SwiftUI
import UIKit

// ============================================================
//  封面粒子 — Mineradio 封面粒子系统（SILK 预设）移植
//  原版：index.html buildCoverParticleGeometry + SILK 顶点着色器
//  把专辑封面拆成 N×N 粒子网格，每颗粒子取封面对应像素颜色，
//  z 位移 = 低音涟漪 + 中频噪声 + 高频抖动 + 低音呼吸，
//  亮度/大小随涟漪与节拍增大。
// ============================================================

// MARK: - 粒子场（封面像素采样）

struct CoverParticleField {
    let grid: Int
    /// 每粒子基色（已按 Mineradio uColorBoost=1.1 做 gamma 提亮）
    let red: [Double]
    let green: [Double]
    let blue: [Double]
    /// 每粒子随机种子（对应 aRand）
    let rand: [Double]
    /// 静态位置抖动（平面单位）：打破整齐网格感，让点云读作"粒子"
    let jitterX: [Double]
    let jitterY: [Double]
    /// 点径随机系数 0.68~1.30
    let sizeVar: [Double]
    /// 近黑像素标记：暗色舞台上不可见，渲染循环直接跳过（省 fill 调用）
    let dark: [Bool]
    /// Sobel 边缘强度 0~1（Mineradio buildEdgeAndDepth）：轮廓粒子增亮变大偏暖
    let edge: [Double]

    static func build(from image: UIImage, grid: Int) -> CoverParticleField? {
        guard let cg = image.cgImage else { return nil }
        let count = grid * grid
        var pixels = [UInt8](repeating: 0, count: count * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        let ok: Bool = pixels.withUnsafeMutableBytes { buf in
            guard let ctx = CGContext(
                data: buf.baseAddress, width: grid, height: grid,
                bitsPerComponent: 8, bytesPerRow: grid * 4,
                space: colorSpace, bitmapInfo: bitmapInfo
            ) else { return false }
            ctx.interpolationQuality = .medium
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: grid, height: grid))
            return true
        }
        guard ok else { return nil }

        var red = [Double](repeating: 0, count: count)
        var green = [Double](repeating: 0, count: count)
        var blue = [Double](repeating: 0, count: count)
        var rand = [Double](repeating: 0, count: count)
        var jitterX = [Double](repeating: 0, count: count)
        var jitterY = [Double](repeating: 0, count: count)
        var sizeVar = [Double](repeating: 0, count: count)
        var dark = [Bool](repeating: false, count: count)
        // Mineradio: vColor = pow(color, 1.0 / uColorBoost)，uColorBoost 默认 1.1
        let gamma: Double = 1.0 / 1.1
        let texel: Double = 4.8 / Double(grid)
        for i in 0..<count {
            let o = i * 4
            red[i] = pow(Double(pixels[o]) / 255.0, gamma)
            green[i] = pow(Double(pixels[o + 1]) / 255.0, gamma)
            blue[i] = pow(Double(pixels[o + 2]) / 255.0, gamma)
            rand[i] = Double.random(in: 0..<1)
            jitterX[i] = Double.random(in: -0.42...0.42) * texel
            jitterY[i] = Double.random(in: -0.42...0.42) * texel
            sizeVar[i] = Double.random(in: 0.68...1.30)
            // 亮度 < 4%（黑边/纯黑背景）的粒子在暗舞台上肉眼不可见
            dark[i] = red[i] + green[i] + blue[i] < 0.12
        }

        // Sobel 边缘检测（原版 buildEdgeAndDepth 步骤 3，直接在网格分辨率上做）：
        // 轮廓处的粒子由 edgeBoost 增亮放大，画面的"图形骨架"在粒子云里保持清晰
        var lum = [Double](repeating: 0, count: count)
        for i in 0..<count {
            lum[i] = red[i] * 0.299 + green[i] * 0.587 + blue[i] * 0.114
        }
        var edge = [Double](repeating: 0, count: count)
        if grid >= 3 {
            for y in 1..<(grid - 1) {
                for x in 1..<(grid - 1) {
                    let i = y * grid + x
                    let gx = -lum[i - grid - 1] - 2 * lum[i - 1] - lum[i + grid - 1]
                           + lum[i - grid + 1] + 2 * lum[i + 1] + lum[i + grid + 1]
                    let gy = -lum[i - grid - 1] - 2 * lum[i - grid] - lum[i - grid + 1]
                           + lum[i + grid - 1] + 2 * lum[i + grid] + lum[i + grid + 1]
                    edge[i] = min(1.0, (gx * gx + gy * gy).squareRoot() * 0.9)
                }
            }
        }

        return CoverParticleField(
            grid: grid, red: red, green: green, blue: blue, rand: rand,
            jitterX: jitterX, jitterY: jitterY, sizeVar: sizeVar, dark: dark, edge: edge
        )
    }
}

// MARK: - 涟漪引擎（Mineradio triggerRipple / updateRipples 移植）

final class CoverRippleEngine {
    struct Ripple {
        var x: Double = 0
        var y: Double = 0
        var age: Double = -10
        var str: Double = 0
    }

    /// 与 Mineradio 一致的常量
    private static let planeSize: Double = 4.8
    private static let rippleMax = 12
    private static let bassThreshold: Double = 0.30
    private static let rippleCooldown: Double = 0.32

    /// 3×3 九宫格触发区域（±0.72 * PLANE_SIZE/2）
    private static let regions: [(Double, Double)] = {
        var out: [(Double, Double)] = []
        for ry in 0..<3 {
            for rx in 0..<3 {
                let x = (Double(rx) / 2 - 0.5) * planeSize * 0.72
                let y = (Double(ry) / 2 - 0.5) * planeSize * 0.72
                out.append((x, y))
            }
        }
        return out
    }()

    private(set) var time: Double = 0
    private(set) var ripples = [Ripple](repeating: Ripple(), count: rippleMax)
    private var rippleIdx = 0
    private var lastRippleAt: Double = -10
    private var lastBassRising = false
    private var lastNow: Double?

    func step(now: Double, bass: Double) {
        let dt: Double
        if let last = lastNow {
            dt = min(0.1, max(0, now - last))
        } else {
            dt = 0
        }
        lastNow = now
        time += dt

        // bass 上升沿触发（原版 updateRipples）
        let isBassHit = bass > Self.bassThreshold && !lastBassRising
        lastBassRising = bass > Self.bassThreshold * 0.75
        if isBassHit && (time - lastRippleAt) > Self.rippleCooldown {
            lastRippleAt = time
            let count = 2 + (Bool.random() ? 0 : 1)
            var used = Set<Int>()
            for _ in 0..<count {
                var idx = Int.random(in: 0..<9)
                var tries = 0
                while used.contains(idx) && tries < 12 {
                    idx = Int.random(in: 0..<9)
                    tries += 1
                }
                used.insert(idx)
                let reg = Self.regions[idx]
                let jx = reg.0 + Double.random(in: -0.35...0.35)
                let jy = reg.1 + Double.random(in: -0.35...0.35)
                let str = 0.65 + bass * 1.4 + Double.random(in: 0...0.25)
                trigger(x: jx, y: jy, str: str)
            }
        }

        for i in 0..<ripples.count where ripples[i].str > 0.005 {
            ripples[i].age += dt
            if ripples[i].age > 2.0 {
                ripples[i].str = 0
                ripples[i].age = -10
            }
        }
    }

    func trigger(x: Double, y: Double, str: Double) {
        ripples[rippleIdx] = Ripple(x: x, y: y, age: 0, str: str)
        rippleIdx = (rippleIdx + 1) % Self.rippleMax
    }

    private var lastTouchRippleAt: Double = -10

    /// 手指划过封面触发的涟漪（节流，避免一次拖动占满全部涟漪槽）
    func touchRipple(x: Double, y: Double) {
        guard time - lastTouchRippleAt > 0.14 else { return }
        lastTouchRippleAt = time
        trigger(x: x, y: y, str: 0.85 + Double.random(in: 0...0.2))
    }

    func activeRipples() -> [Ripple] {
        ripples.filter { $0.str > 0.005 && $0.age >= 0 && $0.age <= 2.0 }
    }
}

// MARK: - 封面粒子视图

struct CinemaCoverParticles: View {
    let pulse: CinemaAudioPulse
    let coverUrl: URL?
    let side: CGFloat
    let isPlaying: Bool

    @State private var field: CoverParticleField?
    @State private var engine = CoverRippleEngine()
    /// 当前触点（平面坐标，±2.4）：手指按住处粒子被顶起（Mineradio 鼠标推开效果）
    @State private var touchPlane: CGPoint? = nil
    /// 粒子场诞生时刻：切歌时粒子从星雾聚合成封面（Mineradio uLoading 雾化形态）
    @State private var fieldBornAt: Double = 0

    /// 性能调节器：发热/省电时自动降粒子密度与帧率
    @ObservedObject private var perf = CinemaPerformanceGovernor.shared

    /// 画布外扩比例：粒子受涟漪推出封面边界，需要额外画布空间
    private static let canvasExpand: CGFloat = 1.45

    var body: some View {
        ZStack {
            // 不播放（或粒子场未就绪）时显示正常封面；播放中封面粒子化
            if isPlaying, let field {
                // 泛光底层（Mineradio bloomParticles 近似）：
                // 原版把粒子几何体用 2.65x 点径 + 加色混合再画一遍，形成整体光晕；
                // 这里用高斯模糊的封面底图等效——封面色彩向外溢出，只花一次纹理绘制
                bloomUnderlay
                particleCanvas(field: field)
                    .transition(.opacity)
            } else {
                flatFallback
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: isPlaying)
        .animation(.easeInOut(duration: 0.5), value: field == nil)
        // 布局只占 side×side，外扩的画布仅做视觉溢出，不挤压控制栏
        .frame(width: side, height: side)
        .contentShape(Rectangle())
        .gesture(coverInteraction)
        .task(id: "\(coverUrl?.absoluteString ?? "")|\(perf.coverGrid)") {
            guard let url = coverUrl else {
                field = nil
                return
            }
            let grid = perf.coverGrid
            guard let image = await ImageLoadCoordinator.shared.loadImage(url: url, maxSize: 160),
                  !Task.isCancelled else { return }
            // 像素采样在后台线程做，避免阻塞主线程一帧
            let built = await Task.detached(priority: .userInitiated) {
                CoverParticleField.build(from: image, grid: grid)
            }.value
            if !Task.isCancelled {
                fieldBornAt = Date.timeIntervalSinceReferenceDate
                withAnimation(.easeIn(duration: 0.45)) { field = built }
            }
        }
    }

    /// 手指划过封面：触点处粒子隆起 + 沿途播撒涟漪（Mineradio 鼠标交互移植）
    /// minimumDistance > 0，轻点仍透传给舞台的显隐控制
    private var coverInteraction: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { v in
                let unit = Double(side) / 4.8
                let x = (Double(v.location.x) - Double(side) / 2) / unit
                let y = (Double(v.location.y) - Double(side) / 2) / unit
                guard abs(x) <= 2.6, abs(y) <= 2.6 else {
                    touchPlane = nil
                    return
                }
                touchPlane = CGPoint(x: x, y: y)
                engine.touchRipple(x: x, y: y)
            }
            .onEnded { _ in touchPlane = nil }
    }

    /// 泛光底层：模糊放大的封面（uBloomStrength=0.62、uBloomSize=2.65 的静态近似），
    /// 随 bass 轻微呼吸，让粒子看起来在一团封面色的辉光里浮动
    @ViewBuilder
    private var bloomUnderlay: some View {
        if let coverUrl {
            TimelineView(AppFrameRate.animationTimeline(maximumFramesPerSecond: 10, paused: !isPlaying)) { _ in
                let snap = pulse.snapshot()
                CachedAsyncImage(url: coverUrl) { Color.clear }
                    .aspectRatio(1, contentMode: .fill)
                    .frame(width: side, height: side)
                    .blur(radius: 34)
                    .opacity(0.30 + snap.bass * 0.18 + snap.beatPulse * 0.10)
                    .scaleEffect(1.18 + snap.bass * 0.05)
                    .blendMode(.screen)
                    .allowsHitTesting(false)
            }
        }
    }

    /// 加载期间回退平面封面，避免黑屏
    @ViewBuilder
    private var flatFallback: some View {
        if let coverUrl {
            CachedAsyncImage(url: coverUrl) {
                RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.12))
            }
            .aspectRatio(1, contentMode: .fill)
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.45), radius: 24, x: 0, y: 14)
        } else {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.1))
                .frame(width: side, height: side)
                .overlay(MonologueIcon(icon: .musicNote, size: 60, color: .white.opacity(0.7)))
        }
    }

    private func particleCanvas(field: CoverParticleField) -> some View {
        TimelineView(AppFrameRate.animationTimeline(maximumFramesPerSecond: perf.coverFPS, paused: !isPlaying)) { timeline in
            Canvas(rendersAsynchronously: true) { context, canvasSize in
                render(field: field, context: context, size: canvasSize,
                       now: timeline.date.timeIntervalSinceReferenceDate)
            }
        }
        .frame(width: side * Self.canvasExpand, height: side * Self.canvasExpand)
    }

    // MARK: - 每帧渲染（SILK 顶点着色器移植）

    private func render(field: CoverParticleField, context: GraphicsContext, size: CGSize, now: Double) {
        let snap = pulse.snapshot()
        engine.step(now: now, bass: snap.bass)
        let t: Double = engine.time

        // 聚合动画（Mineradio uLoading）：切歌后 1.1s 内粒子从环形星雾聚拢成封面
        let bornAge = now - fieldBornAt
        let loadingRaw = 1.0 - min(1, max(0, bornAge / 1.1))
        let loading = loadingRaw * loadingRaw * (3 - 2 * loadingRaw)   // smoothstep ease

        let grid = field.grid
        let plane: Double = 4.8
        let unit: Double = Double(side) / plane
        let cx: Double = Double(size.width) * 0.5
        let cy: Double = Double(size.height) * 0.5

        // Mineradio: K = uIntensity(0.85) * 1.6
        let K: Double = 0.85 * 1.6
        let bass: Double = snap.bass
        let mid: Double = snap.mid
        let treble: Double = snap.treble
        let energy: Double = snap.energy
        let beat: Double = snap.beatPulse

        let gridMax: Double = Double(grid - 1)

        // 平面坐标 + 行列波形预计算（把 snoise 分解为可分离正弦积，逐粒子只做乘加）
        var axisP = [Double](repeating: 0, count: grid)
        var colM1 = [Double](repeating: 0, count: grid)
        var colM2 = [Double](repeating: 0, count: grid)
        var colB = [Double](repeating: 0, count: grid)
        var rowM1 = [Double](repeating: 0, count: grid)
        var rowM2 = [Double](repeating: 0, count: grid)
        var rowB = [Double](repeating: 0, count: grid)
        for gi in 0..<grid {
            let p: Double = (Double(gi) / gridMax - 0.5) * plane
            axisP[gi] = p
            colM1[gi] = sin(p * 1.4 + t * 0.55)
            colM2[gi] = sin(p * 2.8 + 5.0 - t * 0.85)
            colB[gi] = sin(p * 0.35 + t * 0.40)
            rowM1[gi] = sin(p * 1.4 - t * 0.37 + 2.1)
            rowM2[gi] = sin(p * 2.8 - 3.0 + t * 0.62)
            rowB[gi] = sin(p * 0.35 - t * 0.28 + 1.3)
        }

        // 高频抖动查找表（对应 trebleJ 的 aRand 相位）
        var trebLUT = [Double](repeating: 0, count: 64)
        let trebAmp: Double = treble * 0.18 * K
        for k in 0..<64 {
            trebLUT[k] = sin(t * 3.5 + Double(k) * 0.0982) * trebAmp
        }

        // 海浪主体：中频驱动的大面积起伏（加一点常驻底浪保证画面不死板）
        let midAmp: Double = (0.05 + mid * 0.43) * K
        let bassAmp: Double = bass * 0.50 * K
        let active = engine.activeRipples()

        // 手指触点：按住处粒子隆起（半径 1.1 平面单位的平滑鼓包）
        let touch = touchPlane
        let touchRadius: Double = 1.1
        // 无涟漪且无触点时走快速路径：跳过逐粒子的距离/指数计算
        let calm = active.isEmpty && touch == nil

        // 预展开活跃涟漪参数，内层循环免重复计算
        struct RippleParams {
            let x: Double; let y: Double
            let str: Double
            let env: Double
            let bulgeGain: Double
            let invBulge: Double
            let waveR: Double
            let invRingW: Double
        }
        var rippleParams: [RippleParams] = []
        rippleParams.reserveCapacity(active.count)
        for r in active {
            let lifeN: Double = r.age / 2.0
            let fadeIn: Double = smoothstep(0, 0.06, r.age)
            let fadeOut: Double = 1.0 - smoothstep(0.7, 1.0, lifeN)
            let env: Double = fadeIn * fadeOut
            guard env > 0.001 else { continue }
            let bulgeW: Double = 0.55 + r.age * 0.80
            let bulgeGain: Double = 1.0 - smoothstep(0, 0.55, lifeN)
            let ringW: Double = 0.40 + r.age * 0.22
            rippleParams.append(RippleParams(
                x: r.x, y: r.y, str: r.str, env: env,
                bulgeGain: bulgeGain,
                invBulge: 1.0 / (2.0 * bulgeW * bulgeW),
                waveR: r.age * 2.10,
                invRingW: 1.0 / ringW
            ))
        }

        let cell: Double = Double(side) / Double(grid)
        // 静止时点径 ≈ 格距（轻微交叠），粒子拼合出完整封面；音频来了才散开成浪
        let baseR: Double = cell * 0.56
        let sizeBeatBoost: Double = 1.0 + beat * 0.24
        let brightBase: Double = 0.90 + bass * 0.10 + energy * 0.05

        for gy in 0..<grid {
            let py: Double = axisP[gy]
            let rM1: Double = rowM1[gy]
            let rM2: Double = rowM2[gy]
            let rB: Double = rowB[gy]
            let rowOffset = gy * grid

            for gx in 0..<grid {
                let i = rowOffset + gx
                // 近黑粒子在暗色舞台上不可见，直接跳过（省一半以上 fill）
                if field.dark[i] { continue }
                // 静态抖动打破网格排列，读作自然粒子云
                let px: Double = axisP[gx] + field.jitterX[i]
                let pyJ: Double = py + field.jitterY[i]

                // ---- 涟漪 z（原版 rippleSumAt：中心凸起 + 扩散圆环）----
                var rippleZ: Double = 0
                var rippleAmp: Double = 0
                if !calm {
                    for rp in rippleParams {
                        let dx: Double = px - rp.x
                        let dy: Double = pyJ - rp.y
                        let d2: Double = dx * dx + dy * dy
                        let dist: Double = sqrt(d2)
                        let bulge: Double = exp(-d2 * rp.invBulge) * rp.bulgeGain
                        let ringT: Double = (dist - rp.waveR) * rp.invRingW
                        let ring: Double = exp(-(ringT * ringT))
                        let local: Double = (bulge * 2.4 + ring * 1.30) * rp.env * rp.str
                        rippleZ += local
                        let absLocal: Double = abs(local)
                        if absLocal > rippleAmp { rippleAmp = absLocal }
                    }
                }

                // ---- 中频起伏 + 高频抖动 + 低音呼吸（原版 midDisp/trebleJ/bassBreath）----
                let midN: Double = colM1[gx] * rM1 * 0.6 + colM2[gx] * rM2 * 0.4
                let midDisp: Double = midN * midAmp
                let trebleJ: Double = trebLUT[Int(field.rand[i] * 63.999)]
                let bassBreath: Double = colB[gx] * rB * bassAmp
                var z: Double = rippleZ * 1.30 + midDisp + trebleJ + bassBreath

                // ---- 手指推浪（原版鼠标 push）----
                if let touch {
                    let tdx: Double = px - Double(touch.x)
                    let tdy: Double = pyJ - Double(touch.y)
                    let td2: Double = tdx * tdx + tdy * tdy
                    if td2 < touchRadius * touchRadius {
                        let fall: Double = 1.0 - sqrt(td2) / touchRadius
                        z += fall * fall * 0.95
                    }
                }

                // ---- 边缘增亮（原版 edgeBoost）：轮廓粒子更亮、微暖、点径稍大 ----
                let edgeBoost: Double = field.edge[i]

                // ---- z → 空间投影：靠近观者放大 + 上抬（复刻 Mineradio 俯视角下的浪涌）----
                let posScale: Double = 1.0 + z * 0.05
                var bx: Double = cx + px * unit * posScale
                var by: Double = cy + pyJ * unit * posScale - z * unit * 0.30
                // 原版 audioBoost = 1 + ripple*0.7 + edgeBoost*0.55 + beat*0.30
                let audioBoost: Double = (1.0 + rippleAmp * 0.55 + edgeBoost * 0.30) * sizeBeatBoost
                var dotR: Double = baseR * field.sizeVar[i] * audioBoost * (1.0 + max(0, z) * 0.28)
                if dotR > cell * 1.5 { dotR = cell * 1.5 }
                if dotR < 0.6 { dotR = 0.6 }

                // ---- 亮度（原版 vBright = 0.82 + ripple*0.55 + bass*0.10 + edge*0.30）----
                let bright: Double = brightBase + rippleAmp * 0.55 + max(0, z) * 0.16 + edgeBoost * 0.30
                var rr: Double = min(1.0, field.red[i] * bright + edgeBoost * 0.077)
                var gg: Double = min(1.0, field.green[i] * bright + edgeBoost * 0.063)
                var bb: Double = min(1.0, field.blue[i] * bright + edgeBoost * 0.035)
                var dotAlpha: Double = 1.0

                // ---- 聚合星雾（原版 uLoading 雾化形态的平面近似）----
                // 粒子从环形雾带位置 lerp 回封面网格位；雾态偏蓝白、半透明、点径稍大
                if loading > 0.001 {
                    let seed: Double = field.rand[i]
                    let mistAngle: Double = seed * 6.2831 + t * (0.16 + seed * 0.18)
                    let mistR: Double = (1.35 + 1.8 * seed.squareRoot()) * unit
                    let mx: Double = cx + cos(mistAngle) * mistR * 1.1
                    let my: Double = cy + sin(mistAngle * 0.82) * mistR * 0.62
                    bx += (mx - bx) * loading
                    by += (my - by) * loading
                    let mistBlend: Double = loading * 0.78
                    rr += (0.55 - rr) * mistBlend
                    gg += (0.70 - gg) * mistBlend
                    bb += (0.80 - bb) * mistBlend
                    dotAlpha = 1.0 - loading * (0.72 - seed * 0.30)
                    dotR *= 1.0 + loading * 0.35
                }

                let rect = CGRect(x: bx - dotR, y: by - dotR, width: dotR * 2, height: dotR * 2)
                let fillColor = Color(red: rr, green: gg, blue: bb)
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(dotAlpha < 0.999 ? fillColor.opacity(dotAlpha) : fillColor)
                )

                // ---- 简化 bloom：强涟漪粒子叠一层放大的柔光（原版 bloomParticles 加色层）----
                if rippleAmp > 0.30 {
                    let glowR: Double = dotR * 2.2
                    let glowRect = CGRect(x: bx - glowR, y: by - glowR, width: glowR * 2, height: glowR * 2)
                    let glowAlpha: Double = min(0.35, rippleAmp * 0.30)
                    context.fill(
                        Path(ellipseIn: glowRect),
                        with: .color(Color(red: rr, green: gg, blue: bb).opacity(glowAlpha))
                    )
                }
            }
        }
    }

    private func smoothstep(_ e0: Double, _ e1: Double, _ x: Double) -> Double {
        let n = min(1, max(0, (x - e0) / (e1 - e0)))
        return n * n * (3 - 2 * n)
    }
}
