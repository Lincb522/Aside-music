import Foundation

public enum ValidationSeverity: String, Codable, Sendable {
    case warning
    case error
}

public struct ValidationIssue: Codable, Equatable, Sendable {
    public var severity: ValidationSeverity
    public var code: String
    public var path: String
    public var message: String

    public init(severity: ValidationSeverity, code: String, path: String, message: String) {
        self.severity = severity
        self.code = code
        self.path = path
        self.message = message
    }
}

public struct ValidationReport: Codable, Equatable, Sendable {
    public var issues: [ValidationIssue]
    public var recommendedPreampDB: Double

    public var isValid: Bool {
        !issues.contains { $0.severity == .error }
    }

    public init(issues: [ValidationIssue], recommendedPreampDB: Double) {
        self.issues = issues
        self.recommendedPreampDB = recommendedPreampDB
    }
}

public struct MonoAudioPlanValidator: Sendable {
    public init() {}

    public func validate(_ plan: MonoAudioPlan) -> ValidationReport {
        var issues: [ValidationIssue] = []

        if plan.schemaVersion != MonoAudioSchema.currentVersion {
            issues.append(.init(
                severity: .error,
                code: "schema.unsupported",
                path: "schemaVersion",
                message: "Expected schema version \(MonoAudioSchema.currentVersion)."
            ))
        }

        if plan.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(severity: .error, code: "name.empty", path: "name", message: "Plan name must not be empty."))
        }

        validateCurve(plan.graphicEQ, path: "graphicEQ", issues: &issues)
        if let baseline = plan.deviceBaseline {
            validateCurve(baseline, path: "deviceBaseline", issues: &issues)
            if baseline.mode != plan.graphicEQ.mode {
                issues.append(.init(
                    severity: .error,
                    code: "baseline.mode_mismatch",
                    path: "deviceBaseline.mode",
                    message: "Device baseline and track curve must use the same band mode."
                ))
            }
        }

        if plan.parametricEQ.count > 12 {
            issues.append(.init(severity: .error, code: "peq.too_many_bands", path: "parametricEQ", message: "At most 12 parametric bands are supported."))
        }
        for (index, band) in plan.parametricEQ.enumerated() where band.isEnabled {
            requireFinite(band.frequencyHz, range: 20 ... 20_000, code: "peq.frequency", path: "parametricEQ[\(index)].frequencyHz", issues: &issues)
            requireFinite(band.gainDB, range: -12 ... 12, code: "peq.gain", path: "parametricEQ[\(index)].gainDB", issues: &issues)
            requireFinite(band.q, range: 0.1 ... 12, code: "peq.q", path: "parametricEQ[\(index)].q", issues: &issues)
        }

        if plan.compressor.isEnabled {
            requireFinite(plan.compressor.thresholdDB, range: -60 ... 0, code: "compressor.threshold", path: "compressor.thresholdDB", issues: &issues)
            requireFinite(plan.compressor.ratio, range: 1 ... 6, code: "compressor.ratio", path: "compressor.ratio", issues: &issues)
            requireFinite(plan.compressor.attackMS, range: 0.1 ... 500, code: "compressor.attack", path: "compressor.attackMS", issues: &issues)
            requireFinite(plan.compressor.releaseMS, range: 10 ... 2_000, code: "compressor.release", path: "compressor.releaseMS", issues: &issues)
            requireFinite(plan.compressor.makeupDB, range: 0 ... 6, code: "compressor.makeup", path: "compressor.makeupDB", issues: &issues)
        }

        requireFinite(plan.spatial.stereoWidth, range: 0.75 ... 1.5, code: "spatial.width", path: "spatial.stereoWidth", issues: &issues)
        requireFinite(plan.outputSafety.preampDB, range: -24 ... 0, code: "output.preamp", path: "outputSafety.preampDB", issues: &issues)
        requireFinite(plan.outputSafety.limiterCeilingDBFS, range: -6 ... -0.05, code: "output.ceiling", path: "outputSafety.limiterCeilingDBFS", issues: &issues)
        requireFinite(plan.outputSafety.uncertaintyMarginDB, range: 0 ... 3, code: "output.margin", path: "outputSafety.uncertaintyMarginDB", issues: &issues)

        let recommendedPreamp = recommendedPreampDB(for: plan)
        if plan.outputSafety.preampDB > recommendedPreamp + 0.05 {
            issues.append(.init(
                severity: .error,
                code: "output.insufficient_headroom",
                path: "outputSafety.preampDB",
                message: "Preamp must be at most \(format(recommendedPreamp)) dB for the enabled stages."
            ))
        }
        if !plan.outputSafety.limiterEnabled {
            issues.append(.init(
                severity: .warning,
                code: "output.limiter_disabled",
                path: "outputSafety.limiterEnabled",
                message: "The final limiter is disabled."
            ))
        }

        return ValidationReport(issues: issues, recommendedPreampDB: recommendedPreamp)
    }

    public func recommendedPreampDB(for plan: MonoAudioPlan) -> Double {
        let baselineGains = plan.deviceBaseline?.gainsDB ?? []
        var graphicBoost = 0.0
        for index in plan.graphicEQ.gainsDB.indices {
            let baselineGain = index < baselineGains.count ? baselineGains[index] : 0
            graphicBoost = max(graphicBoost, baselineGain + plan.graphicEQ.gainsDB[index])
        }
        let peqBoost = plan.parametricEQ.filter(\.isEnabled).map(\.gainDB).filter { $0 > 0 }.reduce(0, +)
        let compressorMakeup = plan.compressor.isEnabled ? max(0, plan.compressor.makeupDB) : 0
        let spatialAllowance = max(0, plan.spatial.stereoWidth - 1) * 2
        let worstCaseBoost = max(0, graphicBoost) + peqBoost + compressorMakeup + spatialAllowance + plan.outputSafety.uncertaintyMarginDB
        return min(0, -worstCaseBoost)
    }

    private func validateCurve(_ curve: GraphicEQCurve, path: String, issues: inout [ValidationIssue]) {
        let expectedCount = curve.mode.centerFrequenciesHz.count
        if curve.gainsDB.count != expectedCount {
            issues.append(.init(
                severity: .error,
                code: "curve.band_count",
                path: "\(path).gainsDB",
                message: "Expected \(expectedCount) gains for \(curve.mode.rawValue)."
            ))
            return
        }
        for (index, gain) in curve.gainsDB.enumerated() {
            requireFinite(gain, range: -12 ... 12, code: "curve.gain", path: "\(path).gainsDB[\(index)]", issues: &issues)
        }
        for index in 1 ..< curve.gainsDB.count {
            let jump = abs(curve.gainsDB[index] - curve.gainsDB[index - 1])
            if jump > curve.mode.maximumAdjacentJumpDB {
                issues.append(.init(
                    severity: .error,
                    code: "curve.adjacent_jump",
                    path: "\(path).gainsDB[\(index)]",
                    message: "Adjacent jump \(format(jump)) dB exceeds \(format(curve.mode.maximumAdjacentJumpDB)) dB."
                ))
            }
        }
    }

    private func requireFinite(
        _ value: Double,
        range: ClosedRange<Double>,
        code: String,
        path: String,
        issues: inout [ValidationIssue]
    ) {
        guard value.isFinite, range.contains(value) else {
            issues.append(.init(
                severity: .error,
                code: code,
                path: path,
                message: "Value must be finite and within \(format(range.lowerBound))...\(format(range.upperBound))."
            ))
            return
        }
    }

    private func format(_ value: Double) -> String {
        String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}
