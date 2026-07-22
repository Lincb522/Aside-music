//
//  AriaGPUStage.swift
//  Monologue
//
//  沉浸舞台的镜头完成层。GPU 只处理背景，不处理歌词：
//  连绵节拍折射负责空间流动，镜头色散与呼吸暗角负责画面质感。
//

import SwiftUI

extension View {
    @ViewBuilder
    func ariaGPUStage(
        pulse: AriaAudioPulse,
        isActive: Bool,
        enabled: Bool
    ) -> some View {
        if enabled, #available(iOS 17.0, *) {
            modifier(AriaGPUStageModifier(pulse: pulse, isActive: isActive))
        } else {
            self
        }
    }
}

@available(iOS 17.0, *)
private struct AriaGPUStageModifier: ViewModifier {
    let pulse: AriaAudioPulse
    let isActive: Bool

    @ObservedObject private var performance = AriaPerformanceGovernor.shared

    private var frameRate: Int {
        switch performance.tier {
        case .high: return 30
        case .medium: return 24
        case .low: return 20
        }
    }

    func body(content: Content) -> some View {
        let shadersEnabled = isActive && performance.tier != .low

        GeometryReader { proxy in
            TimelineView(
                AppFrameRate.throttledTimeline(
                    maximumFramesPerSecond: frameRate,
                    paused: !shadersEnabled
                )
            ) { timeline in
                let snapshot = pulse.snapshot()
                let time = timeline.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 7200)
                let size = CGSize(
                    width: max(proxy.size.width, 1),
                    height: max(proxy.size.height, 1)
                )

                content
                    .distortionEffect(
                        ShaderLibrary.ariaOpticalFlow(
                            .float2(size),
                            .float(Float(time)),
                            .float(Float(shadersEnabled ? snapshot.bass : 0)),
                            .float(Float(shadersEnabled ? snapshot.energy : 0)),
                            .float(Float(shadersEnabled ? snapshot.punch : 0)),
                            .float(Float(shadersEnabled ? snapshot.tension : 0))
                        ),
                        maxSampleOffset: CGSize(width: 12, height: 12),
                        isEnabled: shadersEnabled
                    )
                    .layerEffect(
                        ShaderLibrary.ariaLensFinish(
                            .float2(size),
                            .float(Float(time)),
                            .float(Float(shadersEnabled ? snapshot.punch : 0)),
                            .float(Float(shadersEnabled ? snapshot.energy : 0)),
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
