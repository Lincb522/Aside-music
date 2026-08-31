import Foundation

/// A bounded snapshot of the renderer and queue state used by app-side fault diagnostics.
public struct AudioOutputDiagnostics: Sendable {
    public let isEngineRunning: Bool
    public let renderCallbackSerial: UInt64
    public let lastRenderCallbackAge: TimeInterval?
    public let recentRealPCMFrameCount: Int
    public let recentOutputPeak: Float
    public let underrunSerial: UInt64
    public let queuedBufferCount: Int
    public let queuedDuration: TimeInterval
    public let totalRealPCMOutputDuration: TimeInterval

    public init(
        isEngineRunning: Bool,
        renderCallbackSerial: UInt64,
        lastRenderCallbackAge: TimeInterval?,
        recentRealPCMFrameCount: Int,
        recentOutputPeak: Float,
        underrunSerial: UInt64,
        queuedBufferCount: Int,
        queuedDuration: TimeInterval,
        totalRealPCMOutputDuration: TimeInterval
    ) {
        self.isEngineRunning = isEngineRunning
        self.renderCallbackSerial = renderCallbackSerial
        self.lastRenderCallbackAge = lastRenderCallbackAge
        self.recentRealPCMFrameCount = recentRealPCMFrameCount
        self.recentOutputPeak = recentOutputPeak
        self.underrunSerial = underrunSerial
        self.queuedBufferCount = queuedBufferCount
        self.queuedDuration = queuedDuration
        self.totalRealPCMOutputDuration = totalRealPCMOutputDuration
    }
}
