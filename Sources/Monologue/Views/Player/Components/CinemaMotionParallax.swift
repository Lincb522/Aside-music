import CoreMotion

/// 沉浸舞台的水平仪视差 — 陀螺仪姿态驱动镜头微倾。
/// 相对进入时的姿态做增量，基准缓慢跟随当前姿态（用户换个姿势坐不会残留偏置）。
/// 输出不走 @Published：舞台每帧从 TimelineView 里直接读取，避免高频刷新风暴。
final class CinemaMotionParallax {
    private let motion = CMMotionManager()

    /// 平滑后的左右倾斜 -1...1（横屏下驱动 yaw）
    private(set) var tiltX: Double = 0
    /// 平滑后的前后俯仰 -1...1（横屏下驱动 pitch）
    private(set) var tiltY: Double = 0

    private var baseA: Double?
    private var baseB: Double?

    func start() {
        guard motion.isDeviceMotionAvailable, !motion.isDeviceMotionActive else { return }
        motion.deviceMotionUpdateInterval = 1.0 / 60.0
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self, let attitude = data?.attitude else { return }
            // 横屏持机：pitch 轴对应屏幕左右倾、roll 轴对应前后俯仰
            let a = attitude.pitch
            let b = attitude.roll
            if baseA == nil {
                baseA = a
                baseB = b
            }
            // 基准缓慢跟随（时间常数约 8 秒），倾斜是相对动作而非绝对姿态
            baseA = (baseA ?? a) * 0.998 + a * 0.002
            baseB = (baseB ?? b) * 0.998 + b * 0.002

            let da = max(-0.55, min(0.55, a - (baseA ?? a))) / 0.55
            let db = max(-0.55, min(0.55, b - (baseB ?? b))) / 0.55
            tiltX = tiltX * 0.88 + da * 0.12
            tiltY = tiltY * 0.88 + db * 0.12
        }
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
        baseA = nil
        baseB = nil
        tiltX = 0
        tiltY = 0
    }
}
