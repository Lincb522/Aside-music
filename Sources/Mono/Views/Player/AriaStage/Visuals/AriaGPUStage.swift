//  沉浸舞台的镜头完成层。GPU 只处理背景，不处理歌词：
//  连绵节拍折射负责空间流动，镜头色散与呼吸暗角负责画面质感。

import SwiftUI

extension View {
    @ViewBuilder
    func ariaGPUStage(
        pulse: AriaAudioPulse,
        isActive: Bool,
        enabled: Bool,
        stackedWithSonicStage: Bool = false
    ) -> some View {
        if enabled, #available(iOS 17.0, *) {
            modifier(AriaGPUStageModifier(
                pulse: pulse,
                isActive: isActive,
                stackedWithSonicStage: stackedWithSonicStage
            ))
        } else {
            self
        }
    }
}

@available(iOS 17.0, *)
private struct AriaGPUStageModifier: ViewModifier {
    let pulse: AriaAudioPulse
    let isActive: Bool
    let stackedWithSonicStage: Bool

    @ObservedObject private var performance = AriaPerformanceGovernor.shared

    private var frameRate: Int {
        60
    }

    func body(content: Content) -> some View {
        let shadersEnabled = isActive

        GeometryReader { proxy in
            TimelineView(
                AppFrameRate.throttledTimeline(
                    maximumFramesPerSecond: frameRate,
                    paused: !shadersEnabled
                )
            ) { _ in
                let snapshot = pulse.snapshot()
                let size = CGSize(
                    width: max(proxy.size.width, 1),
                    height: max(proxy.size.height, 1)
                )

                content
                    .distortionEffect(
                        ShaderLibrary.ariaOpticalFlow(
                            .float2(size),
                            .float(Float(shadersEnabled ? snapshot.bass : 0)),
                            .float(Float(shadersEnabled ? snapshot.rawEnergy : 0)),
                            .float(Float(shadersEnabled ? snapshot.punch : 0)),
                            .float(Float(shadersEnabled ? snapshot.tension : 0))
                        ),
                        maxSampleOffset: CGSize(width: 12, height: 12),
                        isEnabled: shadersEnabled
                    )
                    .layerEffect(
                        ShaderLibrary.ariaLensFinish(
                            .float2(size),
                            .float(Float(shadersEnabled ? snapshot.punch : 0)),
                            .float(Float(shadersEnabled ? snapshot.rawEnergy : 0)),
                            .float(Float(shadersEnabled ? snapshot.treble : 0))
                        ),
                        maxSampleOffset: CGSize(width: 4, height: 4),
                        isEnabled: shadersEnabled
                    )
            }
        }
        .ignoresSafeArea()
    }
}
