import Foundation
import MonoAudioCore

public protocol MonoAudioAgentProvider: Sendable {
    func generatePlan(for request: MonoAudioTuningRequest) async throws -> MonoAudioPlan
}

public struct MonoAudioAgentResult: Sendable {
    public var plan: MonoAudioPlan
    public var validation: ValidationReport

    public init(plan: MonoAudioPlan, validation: ValidationReport) {
        self.plan = plan
        self.validation = validation
    }
}

public enum MonoAudioAgentError: Error, Equatable, Sendable {
    case invalidPlan(ValidationReport)
    case wrongGraphicEQMode(expected: GraphicEQMode, actual: GraphicEQMode)
    case staleRequest
}

/// Platform-neutral Agent coordinator. The provider may use a local model or a
/// remote LLM, but every response is checked by the same local safety contract.
public actor MonoAudioAgent {
    private let provider: any MonoAudioAgentProvider
    private let validator: MonoAudioPlanValidator
    private var generation = 0

    public init(provider: any MonoAudioAgentProvider, validator: MonoAudioPlanValidator = .init()) {
        self.provider = provider
        self.validator = validator
    }

    public func tune(_ request: MonoAudioTuningRequest) async throws -> MonoAudioAgentResult {
        generation += 1
        let requestGeneration = generation
        var plan = try await provider.generatePlan(for: request)
        guard requestGeneration == generation else { throw MonoAudioAgentError.staleRequest }

        // The local route authority owns device correction. Provider output is
        // never allowed to silently replace or omit the supplied baseline.
        plan.deviceBaseline = request.deviceBaseline
        guard plan.graphicEQ.mode == request.requestedMode else {
            throw MonoAudioAgentError.wrongGraphicEQMode(
                expected: request.requestedMode,
                actual: plan.graphicEQ.mode
            )
        }

        let report = validator.validate(plan)
        guard report.isValid else { throw MonoAudioAgentError.invalidPlan(report) }
        return .init(plan: plan, validation: report)
    }

    public func cancelCurrentGeneration() {
        generation += 1
    }
}
