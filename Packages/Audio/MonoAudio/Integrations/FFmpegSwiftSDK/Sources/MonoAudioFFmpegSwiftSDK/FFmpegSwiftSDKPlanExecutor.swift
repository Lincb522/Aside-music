import FFmpegSwiftSDK
import MonoAudioCore

/// Applies a validated portable plan to an FFmpegSwiftSDK realtime player.
/// All SDK mutations stay on the main actor; the SDK itself performs smoothed
/// realtime updates and owns its render-thread synchronization.
@MainActor
public final class FFmpegSwiftSDKPlanExecutor: MonoAudioPlanExecutor {
    private let player: StreamPlayer
    private let validator: MonoAudioPlanValidator

    public init(player: StreamPlayer, validator: MonoAudioPlanValidator = .init()) {
        self.player = player
        self.validator = validator
    }

    public func apply(_ plan: MonoAudioPlan) async throws {
        let report = validator.validate(plan)
        guard report.isValid else { throw FFmpegSwiftSDKPlanExecutorError.invalidPlan(report) }

        let sdkMode: FFmpegSwiftSDK.GraphicEQMode = switch plan.graphicEQ.mode {
        case .tenBand: .tenBand
        case .thirtyTwoBand: .thirtyTwoBand
        }
        player.equalizer.setCalibrationGains((plan.deviceBaseline?.gainsDB ?? []).map(Float.init))
        player.equalizer.setGraphicMode(sdkMode, gainsDB: plan.graphicEQ.gainsDB.map(Float.init))
        player.equalizer.setParametricBands(plan.parametricEQ.map(makeParametricBand))
        player.equalizer.setPreampDB(Float(plan.outputSafety.preampDB))

        player.audioEffects.setNightModeEnabled(plan.compressor.isEnabled)
        if plan.compressor.isEnabled {
            player.audioEffects.setCompressorParams(
                threshold: Float(plan.compressor.thresholdDB),
                ratio: Float(plan.compressor.ratio),
                attack: Float(plan.compressor.attackMS),
                release: Float(plan.compressor.releaseMS),
                makeup: Float(plan.compressor.makeupDB)
            )
        }
        player.audioEffects.setStereoWidth(Float(plan.spatial.stereoWidth))
        player.audioRepair.configureOutputSafety(
            limiterEnabled: plan.outputSafety.limiterEnabled,
            ceilingDB: Float(plan.outputSafety.limiterCeilingDBFS),
            transitionProtectionEnabled: true
        )
    }

    public func reset() async throws {
        player.equalizer.reset()
        player.equalizer.setCalibrationGains([])
        player.equalizer.setParametricBands([])
        player.equalizer.setPreampDB(0)
        player.audioEffects.setNightModeEnabled(false)
        player.audioEffects.setStereoWidth(1)
        player.audioRepair.configureOutputSafety(limiterEnabled: true, ceilingDB: -1)
    }

    private func makeParametricBand(_ band: MonoAudioCore.ParametricEQBand) -> FFmpegSwiftSDK.ParametricEQBand {
        let type: ParametricEQFilterType = switch band.kind {
        case .peak: .peak
        case .lowShelf: .lowShelf
        case .highShelf: .highShelf
        }
        return .init(
            id: band.id,
            isEnabled: band.isEnabled,
            type: type,
            frequency: Float(band.frequencyHz),
            gainDB: Float(band.gainDB),
            q: Float(band.q)
        )
    }
}

public enum FFmpegSwiftSDKPlanExecutorError: Error, Sendable {
    case invalidPlan(ValidationReport)
}
