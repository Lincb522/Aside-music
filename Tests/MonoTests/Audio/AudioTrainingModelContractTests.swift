import Foundation
import XCTest
@testable import Mono

final class AudioTrainingModelContractTests: XCTestCase {
    func testSchemaWidthsKeepOldModelsLoadable() {
        XCTAssertEqual(AudioTrainingOnDeviceModelStore.outputWidth(forFeatureSchemaVersion: 5), 60)
        XCTAssertEqual(AudioTrainingOnDeviceModelStore.outputWidth(forFeatureSchemaVersion: 6), 92)
        XCTAssertEqual(AudioTrainingOnDeviceModelStore.outputWidth(forFeatureSchemaVersion: 7), 197)
        XCTAssertEqual(AudioTrainingOnDeviceModelStore.inputWidth(forFeatureSchemaVersion: 7), 636)
        XCTAssertNil(AudioTrainingOnDeviceModelStore.inputWidth(forFeatureSchemaVersion: 8))
    }

    func testCoverageUsesTheCurrentBranchAndIndependentAccounts() throws {
        var status = AudioTrainingInstalledModelStatus(
            id: "test", version: "test", sha256: "test", byteCount: 1,
            featureSchemaVersion: 7, targetSchemaVersion: 4,
            completeSampleCount: 118, legacySampleCount: 6033,
            completeAccountCount: 12,
            completeBranchSampleCounts: ["tenBand:standard": 108, "tenBand:monoSpatialEnhancement": 10],
            completeBranchAccountCounts: ["tenBand:standard": 12, "tenBand:monoSpatialEnhancement": 1],
            installedAt: Date()
        )
        XCTAssertEqual(status.trackCorrectionStrength(forBranch: "tenBand:standard"), 1)
        XCTAssertEqual(status.trackCorrectionStrength(forBranch: "thirtyTwoBand:standard"), 0)
        XCTAssertEqual(status.trackCorrectionStrength(forBranch: "tenBand:monoSpatialEnhancement"), 0.09375, accuracy: 0.00001)
        status.completeBranchAccountCounts = nil
        XCTAssertEqual(status.trackCorrectionStrength(forBranch: "tenBand:standard"), 1)
        let restored = try JSONDecoder().decode(
            AudioTrainingInstalledModelStatus.self, from: JSONEncoder().encode(status)
        )
        XCTAssertEqual(restored, status)
    }

    func testTraceDoesNotRelabelBlendedValuesAsRawPrediction() {
        let raw = Array(repeating: Float(2), count: 197)
        let blended = Array(repeating: Float(0.5), count: 197)
        let trace = AudioTrainingOnDeviceModelStore.inferenceTrace(
            version: "test", input: Array(repeating: 1, count: 636), output: raw,
            featureSchemaVersion: 7, latencyMilliseconds: 2,
            priorInput: Array(repeating: 0, count: 636),
            priorOutput: Array(repeating: 0, count: 197),
            blendedOutput: blended, trackCorrectionStrength: 0.25
        )
        XCTAssertEqual(trace.rawOutput.map(\.value), raw)
        XCTAssertEqual(trace.blendedOutput.map(\.value), blended)
        XCTAssertEqual(trace.priorInput.count, 636)
        XCTAssertEqual(trace.priorOutput.count, 197)
        XCTAssertEqual(Set(trace.rawOutput.map(\.name)).count, 197)
        XCTAssertEqual(trace.rawOutput[92].name, "professional.dynamicEQ.bands.0.active")
        XCTAssertEqual(trace.rawOutput.last?.name, "professional.multiband.maxReductionDB.2")
        XCTAssertEqual(trace.trackCorrectionStrength, 0.25)
    }
}
