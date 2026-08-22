import Foundation
import MonoAudioCore
import MonoAudioFFmpeg
import MonoAudioStreaming

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

@main
enum MonoAudioCLI {
    static func main() async {
        do {
            try await run(Array(CommandLine.arguments.dropFirst()))
        } catch {
            FileHandle.standardError.write(Data("mono-audio: \(describe(error))\n".utf8))
            exit(2)
        }
    }

    private static func run(_ arguments: [String]) async throws {
        guard let command = arguments.first else {
            printUsage()
            return
        }
        switch command {
        case "validate":
            guard arguments.count == 2 else { throw CLIError.invalidArguments }
            let plan = try loadPlan(arguments[1])
            let report = MonoAudioPlanValidator().validate(plan)
            print(try prettyJSON(report))
            if !report.isValid { exit(1) }
        case "filtergraph":
            guard arguments.count == 2 else { throw CLIError.invalidArguments }
            print(try FFmpegFilterGraphCompiler().compile(loadPlan(arguments[1])).expression)
        case "probe":
            guard arguments.count == 2 else { throw CLIError.invalidArguments }
            print(try FFmpegCommandLine().probe(input: inputURL(arguments[1])).rawJSON)
        case "render":
            guard arguments.count == 4 || (arguments.count == 5 && arguments[4] == "--overwrite") else {
                throw CLIError.invalidArguments
            }
            let result = try FFmpegCommandLine().render(
                plan: loadPlan(arguments[1]),
                input: URL(fileURLWithPath: arguments[2]),
                output: URL(fileURLWithPath: arguments[3]),
                overwrite: arguments.count == 5
            )
            print(try prettyJSON(result))
        case "stream-capabilities":
            guard arguments.count == 1 || arguments.count == 2 else { throw CLIError.invalidArguments }
            let executable = arguments.count == 2 ? arguments[1] : "ffmpeg"
            print(try prettyJSON(
                FFmpegCommandLine(ffmpegExecutable: executable).inspectStreamingCapabilities()
            ))
        case "relay-argv":
            let parsed = try relayArguments(arguments)
            let commandLine = FFmpegCommandLine()
            let capabilities = parsed.checkCapabilities
                ? try commandLine.inspectStreamingCapabilities()
                : nil
            let command = try FFmpegStreamingCommandBuilder().buildRelay(
                parsed.configuration,
                capabilities: capabilities
            )
            print(try prettyJSON(command.argv))
        case "relay":
            let parsed = try relayArguments(arguments)
            let commandLine = FFmpegCommandLine()
            let capabilities = parsed.checkCapabilities
                ? try commandLine.inspectStreamingCapabilities()
                : nil
            print(try prettyJSON(
                try await commandLine.relay(parsed.configuration, capabilities: capabilities)
            ))
        case "help", "--help", "-h":
            printUsage()
        default:
            throw CLIError.unknownCommand(command)
        }
    }

    private static func loadPlan(_ path: String) throws -> MonoAudioPlan {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try JSONDecoder().decode(MonoAudioPlan.self, from: data)
    }

    private static func loadRelayConfiguration(_ path: String) throws -> FFmpegStreamingRelayConfiguration {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try JSONDecoder().decode(FFmpegStreamingRelayConfiguration.self, from: data)
    }

    private static func relayArguments(
        _ arguments: [String]
    ) throws -> (configuration: FFmpegStreamingRelayConfiguration, checkCapabilities: Bool) {
        guard arguments.count == 2 || (arguments.count == 3 && arguments[2] == "--check-capabilities") else {
            throw CLIError.invalidArguments
        }
        return (
            try loadRelayConfiguration(arguments[1]),
            arguments.count == 3
        )
    }

    private static func inputURL(_ value: String) -> URL {
        if value.contains("://"), let remoteURL = URL(string: value) {
            return remoteURL
        }
        return URL(fileURLWithPath: value)
    }

    private static func prettyJSON<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }

    private static func describe(_ error: Error) -> String {
        if let compilation = error as? FFmpegCompilationError,
           case let .invalidPlan(report) = compilation {
            return "invalid plan: \(report.issues.map { "\($0.path): \($0.message)" }.joined(separator: "; "))"
        }
        if let cli = error as? CLIError { return cli.description }
        return String(describing: error)
    }

    private static func printUsage() {
        print("""
        Usage:
          mono-audio validate <plan.json>
          mono-audio filtergraph <plan.json>
          mono-audio probe <input>
          mono-audio render <plan.json> <input> <output> [--overwrite]
          mono-audio stream-capabilities [ffmpeg-executable]
          mono-audio relay-argv <relay.json> [--check-capabilities]
          mono-audio relay <relay.json> [--check-capabilities]
        """)
    }

    private enum CLIError: Error, CustomStringConvertible {
        case invalidArguments
        case unknownCommand(String)

        var description: String {
            switch self {
            case .invalidArguments: "invalid arguments; run mono-audio help"
            case let .unknownCommand(command): "unknown command '\(command)'"
            }
        }
    }
}
