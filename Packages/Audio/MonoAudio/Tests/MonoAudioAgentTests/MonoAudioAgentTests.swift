import Testing
import MonoAudioAgent
import MonoAudioCore

private struct StubProvider: MonoAudioAgentProvider {
    let plan: MonoAudioPlan

    func generatePlan(for request: MonoAudioTuningRequest) async throws -> MonoAudioPlan {
        plan
    }
}

@Test func routeBaselineRemainsAuthoritative() async throws {
    var baseline = GraphicEQCurve.flat()
    baseline.gainsDB[0] = -1
    let request = MonoAudioTuningRequest(
        assetID: "asset",
        outputIdentity: "headphones",
        requestedMode: .tenBand,
        features: .init(confidence: 0.8),
        deviceBaseline: baseline
    )
    let agent = MonoAudioAgent(provider: StubProvider(plan: .init(name: "Agent")))
    let result = try await agent.tune(request)
    #expect(result.plan.deviceBaseline == baseline)
}
