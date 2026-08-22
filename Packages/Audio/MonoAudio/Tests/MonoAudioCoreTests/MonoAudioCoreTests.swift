import Foundation
import Testing
@testable import MonoAudioCore

@Test func neutralPlanIsValid() {
    let report = MonoAudioPlanValidator().validate(.init(name: "Neutral"))
    #expect(report.isValid)
    #expect(report.recommendedPreampDB == -0.5)
}

@Test func combinedDeviceAndTrackBoostControlsHeadroom() {
    var baseline = GraphicEQCurve.flat()
    baseline.gainsDB[4] = 2
    var track = GraphicEQCurve.flat()
    track.gainsDB[4] = 3
    let plan = MonoAudioPlan(
        name: "Combined",
        deviceBaseline: baseline,
        graphicEQ: track,
        outputSafety: .init(preampDB: -5.5)
    )
    let report = MonoAudioPlanValidator().validate(plan)
    #expect(report.isValid)
    #expect(report.recommendedPreampDB == -5.5)
}

@Test func insufficientHeadroomIsRejected() {
    var curve = GraphicEQCurve.flat()
    curve.gainsDB[5] = 3
    let plan = MonoAudioPlan(
        name: "Unsafe",
        graphicEQ: curve,
        outputSafety: .init(preampDB: -1)
    )
    let report = MonoAudioPlanValidator().validate(plan)
    #expect(!report.isValid)
    #expect(report.issues.contains { $0.code == "output.insufficient_headroom" })
}

@Test func sawToothCurveIsRejected() {
    let curve = GraphicEQCurve(mode: .tenBand, gainsDB: [0, 6, 0, 6, 0, 6, 0, 6, 0, 6])
    let report = MonoAudioPlanValidator().validate(
        .init(name: "Saw", graphicEQ: curve, outputSafety: .init(preampDB: -12))
    )
    #expect(report.issues.contains { $0.code == "curve.adjacent_jump" })
}
