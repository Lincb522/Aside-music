import Foundation
import MonoAudioCore

public enum FFmpegCompilationError: Error, Equatable, Sendable {
    case invalidPlan(ValidationReport)
}

public struct FFmpegFilterGraph: Codable, Equatable, Sendable {
    public var filters: [String]

    public var expression: String {
        filters.isEmpty ? "anull" : filters.joined(separator: ",")
    }

    public init(filters: [String]) {
        self.filters = filters
    }
}

/// Converts the portable plan to stock FFmpeg filters. The chain order is:
/// device baseline -> graphic EQ -> selective PEQ -> compressor -> spatial ->
/// preamp -> final limiter.
public struct FFmpegFilterGraphCompiler: Sendable {
    private let validator: MonoAudioPlanValidator

    public init(validator: MonoAudioPlanValidator = .init()) {
        self.validator = validator
    }

    public func compile(_ plan: MonoAudioPlan) throws -> FFmpegFilterGraph {
        let report = validator.validate(plan)
        guard report.isValid else { throw FFmpegCompilationError.invalidPlan(report) }

        var filters: [String] = []
        if let baseline = plan.deviceBaseline {
            filters.append(contentsOf: compileGraphicCurve(baseline))
        }
        filters.append(contentsOf: compileGraphicCurve(plan.graphicEQ))

        for band in plan.parametricEQ where band.isEnabled && abs(band.gainDB) >= 0.001 {
            switch band.kind {
            case .peak:
                filters.append("equalizer=f=\(number(band.frequencyHz)):t=q:w=\(number(band.q)):g=\(number(band.gainDB)):r=f32")
            case .lowShelf:
                filters.append("bass=f=\(number(band.frequencyHz)):t=q:w=\(number(band.q)):g=\(number(band.gainDB)):r=f32")
            case .highShelf:
                filters.append("treble=f=\(number(band.frequencyHz)):t=q:w=\(number(band.q)):g=\(number(band.gainDB)):r=f32")
            }
        }

        if plan.compressor.isEnabled {
            filters.append([
                "acompressor=threshold=\(number(dbToLinear(plan.compressor.thresholdDB)))",
                "ratio=\(number(plan.compressor.ratio))",
                "attack=\(number(plan.compressor.attackMS))",
                "release=\(number(plan.compressor.releaseMS))",
                "makeup=\(number(dbToLinear(plan.compressor.makeupDB)))",
                "knee=2.82843:link=maximum:detection=rms",
            ].joined(separator: ":"))
        }

        if abs(plan.spatial.stereoWidth - 1) >= 0.001 {
            filters.append("extrastereo=m=\(number(plan.spatial.stereoWidth)):c=false")
        }
        if abs(plan.outputSafety.preampDB) >= 0.001 {
            filters.append("volume=volume=\(number(plan.outputSafety.preampDB))dB:precision=float")
        }
        if plan.outputSafety.limiterEnabled {
            filters.append("alimiter=limit=\(number(dbToLinear(plan.outputSafety.limiterCeilingDBFS))):attack=5:release=50:level=false:latency=true")
        }
        return FFmpegFilterGraph(filters: filters)
    }

    private func compileGraphicCurve(_ curve: GraphicEQCurve) -> [String] {
        zip(zip(curve.mode.centerFrequenciesHz, curve.mode.qValues), curve.gainsDB).compactMap { pair, gain in
            guard abs(gain) >= 0.001 else { return nil }
            return "equalizer=f=\(number(pair.0)):t=q:w=\(number(pair.1)):g=\(number(gain)):r=f32"
        }
    }

    private func dbToLinear(_ value: Double) -> Double {
        pow(10, value / 20)
    }

    private func number(_ value: Double) -> String {
        var output = String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), value)
        while output.contains(".") && output.last == "0" { output.removeLast() }
        if output.last == "." { output.removeLast() }
        return output == "-0" ? "0" : output
    }
}
