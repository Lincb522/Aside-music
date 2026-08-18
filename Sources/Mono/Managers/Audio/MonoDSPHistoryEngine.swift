import Combine
import Foundation
import FFmpegSwiftSDK

private struct MonoDSPHistorySnapshot: Equatable {
    let isEnabled: Bool
    let graphicMode: GraphicEQMode
    let currentPreset: EQPreset?
    let customGains: [Float]
    let processingIntensity: Float
    let outputCalibration: Bool
    let smartCompensation: Bool
    let dynamicEQ: Bool
    let multiband: Bool
    let parametricEQ: Bool
    let parametricBands: [ParametricEQBand]
    let dynamicBands: [DynamicEQBand]
    let multibandConfiguration: MultibandDynamicsConfiguration
    let selectedHeadphoneProfileID: String
    let hearingEnabled: Bool
    let hearingLeft: [Float]
    let hearingRight: [Float]
    let environmentEnabled: Bool
    let environmentGains: [Float]
}

@MainActor
final class MonoDSPHistoryEngine: ObservableObject {
    static let shared = MonoDSPHistoryEngine()

    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false
    @Published private(set) var checkpointCount = 0

    private var undoStack: [MonoDSPHistorySnapshot] = []
    private var redoStack: [MonoDSPHistorySnapshot] = []
    private let maximumSnapshots = 20

    private init() {}

    func checkpoint() {
        let snapshot = capture()
        guard undoStack.last != snapshot else { return }
        undoStack.append(snapshot)
        if undoStack.count > maximumSnapshots {
            undoStack.removeFirst(undoStack.count - maximumSnapshots)
        }
        redoStack.removeAll()
        updateState()
    }

    func undo() {
        guard let target = undoStack.popLast() else { return }
        redoStack.append(capture())
        restore(target)
        updateState()
    }

    func redo() {
        guard let target = redoStack.popLast() else { return }
        undoStack.append(capture())
        restore(target)
        updateState()
    }

    private func capture() -> MonoDSPHistorySnapshot {
        let manager = EQManager.shared
        return MonoDSPHistorySnapshot(
            isEnabled: manager.isEnabled,
            graphicMode: manager.graphicEQMode,
            currentPreset: manager.currentPreset,
            customGains: manager.customGains,
            processingIntensity: manager.professionalProcessingIntensity,
            outputCalibration: manager.isOutputCalibrationEnabled,
            smartCompensation: manager.isSmartSongCompensationEnabled,
            dynamicEQ: manager.isDynamicEQEnabled,
            multiband: manager.isMultibandDynamicsEnabled,
            parametricEQ: manager.isParametricEQEnabled,
            parametricBands: manager.parametricBands,
            dynamicBands: manager.dynamicEQBands,
            multibandConfiguration: manager.multibandConfiguration,
            selectedHeadphoneProfileID: manager.selectedHeadphoneProfileID,
            hearingEnabled: manager.isHearingCorrectionEnabled,
            hearingLeft: manager.hearingLeftGains,
            hearingRight: manager.hearingRightGains,
            environmentEnabled: manager.isEnvironmentCompensationEnabled,
            environmentGains: manager.environmentCompensationGains
        )
    }

    private func restore(_ snapshot: MonoDSPHistorySnapshot) {
        let manager = EQManager.shared
        if manager.graphicEQMode != snapshot.graphicMode {
            manager.setGraphicEQMode(snapshot.graphicMode)
        }
        manager.professionalProcessingIntensity = snapshot.processingIntensity
        manager.isOutputCalibrationEnabled = snapshot.outputCalibration
        manager.isSmartSongCompensationEnabled = snapshot.smartCompensation
        manager.isDynamicEQEnabled = snapshot.dynamicEQ
        manager.isMultibandDynamicsEnabled = snapshot.multiband
        manager.isParametricEQEnabled = snapshot.parametricEQ
        manager.parametricBands = snapshot.parametricBands
        manager.dynamicEQBands = snapshot.dynamicBands
        manager.multibandConfiguration = snapshot.multibandConfiguration
        manager.selectedHeadphoneProfileID = snapshot.selectedHeadphoneProfileID
        manager.installHearingCorrection(
            left: snapshot.hearingLeft,
            right: snapshot.hearingRight,
            enabled: snapshot.hearingEnabled
        )
        manager.installEnvironmentCompensation(
            snapshot.environmentGains,
            enabled: snapshot.environmentEnabled
        )
        if let preset = snapshot.currentPreset, preset.id != "custom" {
            manager.applyPreset(preset)
        } else {
            manager.currentPreset = nil
            for (index, gain) in snapshot.customGains.enumerated() {
                manager.setCustomGain(gain, at: index)
            }
        }
        manager.isEnabled = snapshot.isEnabled
    }

    private func updateState() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
        checkpointCount = undoStack.count
    }
}
