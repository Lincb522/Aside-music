import Foundation
import MonoAudioCore

public struct FFmpegExecutionResult: Codable, Equatable, Sendable {
    public var argv: [String]
    public var returnCode: Int32
    public var standardOutput: String
    public var standardError: String

    public init(argv: [String], returnCode: Int32, standardOutput: String, standardError: String) {
        self.argv = argv
        self.returnCode = returnCode
        self.standardOutput = standardOutput
        self.standardError = standardError
    }
}

public struct FFmpegProbeResult: Codable, Equatable, Sendable {
    public var rawJSON: String

    public init(rawJSON: String) {
        self.rawJSON = rawJSON
    }
}

public enum FFmpegCommandLineError: Error, Equatable, Sendable {
    case unsupportedPlatform
    case processFailed(FFmpegExecutionResult)
}

public struct FFmpegCommandLine: Sendable {
    public var ffmpegExecutable: String
    public var ffprobeExecutable: String

    public init(ffmpegExecutable: String = "ffmpeg", ffprobeExecutable: String = "ffprobe") {
        self.ffmpegExecutable = ffmpegExecutable
        self.ffprobeExecutable = ffprobeExecutable
    }

    public func probe(input: URL) throws -> FFmpegProbeResult {
        let result = try run(
            executable: ffprobeExecutable,
            arguments: [
                "-v", "error", "-show_streams", "-show_format", "-of", "json",
                Self.inputArgument(for: input),
            ]
        )
        guard result.returnCode == 0 else { throw FFmpegCommandLineError.processFailed(result) }
        return .init(rawJSON: result.standardOutput)
    }

    static func inputArgument(for input: URL) -> String {
        input.isFileURL ? input.path : input.absoluteString
    }

    public func render(
        plan: MonoAudioPlan,
        input: URL,
        output: URL,
        overwrite: Bool = false
    ) throws -> FFmpegExecutionResult {
        let graph = try FFmpegFilterGraphCompiler().compile(plan)
        var arguments = ["-nostdin", "-hide_banner", overwrite ? "-y" : "-n", "-i", input.path]
        arguments += ["-map", "0:a:0", "-vn", "-af", graph.expression, output.path]
        let result = try run(executable: ffmpegExecutable, arguments: arguments)
        guard result.returnCode == 0 else { throw FFmpegCommandLineError.processFailed(result) }
        return result
    }

    /// Reads the capabilities of this exact FFmpeg executable. The returned
    /// evidence must be checked separately from the portable protocol model.
    public func inspectStreamingCapabilities() throws -> FFmpegStreamingCapabilities {
        let protocols = try checkedRun(arguments: ["-hide_banner", "-protocols"])
        let demuxers = try checkedRun(arguments: ["-hide_banner", "-demuxers"])
        let muxers = try checkedRun(arguments: ["-hide_banner", "-muxers"])
        let encoders = try checkedRun(arguments: ["-hide_banner", "-encoders"])
        return .parse(
            protocolsOutput: protocols.standardOutput + "\n" + protocols.standardError,
            demuxersOutput: demuxers.standardOutput + "\n" + demuxers.standardError,
            muxersOutput: muxers.standardOutput + "\n" + muxers.standardError,
            encodersOutput: encoders.standardOutput + "\n" + encoders.standardError
        )
    }

    /// Executes a relay on a detached utility task so process creation,
    /// decoding, and network I/O never run on the caller's realtime thread.
    /// Long-running relays complete when FFmpeg exits; configure a finite
    /// duration when the caller needs a bounded operation. Cancelling the Swift
    /// task does not currently terminate the child process.
    public func relay(
        _ configuration: FFmpegStreamingRelayConfiguration,
        capabilities: FFmpegStreamingCapabilities? = nil
    ) async throws -> FFmpegExecutionResult {
        let command = try FFmpegStreamingCommandBuilder(ffmpegExecutable: ffmpegExecutable)
            .buildRelay(configuration, capabilities: capabilities)
        let result = try await Task.detached(priority: .utility) {
            try run(executable: command.executable, arguments: command.arguments)
        }.value
        guard result.returnCode == 0 else { throw FFmpegCommandLineError.processFailed(result) }
        return result
    }

    private func checkedRun(arguments: [String]) throws -> FFmpegExecutionResult {
        let result = try run(executable: ffmpegExecutable, arguments: arguments)
        guard result.returnCode == 0 else { throw FFmpegCommandLineError.processFailed(result) }
        return result
    }

    public func run(executable: String, arguments: [String]) throws -> FFmpegExecutionResult {
#if os(macOS) || os(Linux)
        let process = Process()
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("mono-audio-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
        let stdoutURL = temporaryDirectory.appendingPathComponent("stdout")
        let stderrURL = temporaryDirectory.appendingPathComponent("stderr")
        _ = FileManager.default.createFile(atPath: stdoutURL.path, contents: nil)
        _ = FileManager.default.createFile(atPath: stderrURL.path, contents: nil)
        let stdout = try FileHandle(forWritingTo: stdoutURL)
        let stderr = try FileHandle(forWritingTo: stderrURL)
        defer {
            try? stdout.close()
            try? stderr.close()
        }
        let argv: [String]
        if executable.contains("/") {
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            argv = [executable] + arguments
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [executable] + arguments
            argv = [executable] + arguments
        }
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()
        try stdout.synchronize()
        try stderr.synchronize()
        let outputData = try Data(contentsOf: stdoutURL)
        let errorData = try Data(contentsOf: stderrURL)
        return .init(
            argv: argv,
            returnCode: process.terminationStatus,
            standardOutput: String(decoding: outputData.prefix(1_000_000), as: UTF8.self),
            standardError: String(decoding: errorData.prefix(1_000_000), as: UTF8.self)
        )
#else
        throw FFmpegCommandLineError.unsupportedPlatform
#endif
    }
}
