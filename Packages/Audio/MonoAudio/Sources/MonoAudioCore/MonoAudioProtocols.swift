import Foundation

public struct MonoAudioTuningRequest: Codable, Equatable, Sendable {
    public var assetID: String
    public var outputIdentity: String
    public var requestedMode: GraphicEQMode
    public var features: AudioFeatureSnapshot
    public var deviceBaseline: GraphicEQCurve?

    public init(
        assetID: String,
        outputIdentity: String,
        requestedMode: GraphicEQMode,
        features: AudioFeatureSnapshot,
        deviceBaseline: GraphicEQCurve? = nil
    ) {
        self.assetID = assetID
        self.outputIdentity = outputIdentity
        self.requestedMode = requestedMode
        self.features = features
        self.deviceBaseline = deviceBaseline
    }
}

public protocol MonoAudioFeatureSource: Sendable {
    func captureFeatures(for assetID: String) async throws -> AudioFeatureSnapshot
}

public protocol MonoAudioPlanExecutor: Sendable {
    func apply(_ plan: MonoAudioPlan) async throws
    func reset() async throws
}

public protocol MonoAudioOutputRouteProvider: Sendable {
    func currentOutputIdentity() async -> String
    func currentDeviceBaseline(mode: GraphicEQMode) async -> GraphicEQCurve?
}

public enum MonoAudioRuntimeError: Error, Equatable, Sendable {
    case unsupportedPlatform(String)
    case executionFailed(String)
    case staleResult
}
