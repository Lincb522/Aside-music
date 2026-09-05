import CoreML
import Foundation

// Standalone macOS runtime check; does not build or launch the iOS application.
struct PredictionCase: Decodable {
    let input: [Double]
    let expected: [Double]
}

enum VerificationError: Error {
    case arguments
    case outputShape
    case mismatch(test: Int, index: Int, expected: Double, actual: Double)
}

guard CommandLine.arguments.count == 3 else { throw VerificationError.arguments }
let modelURL = URL(fileURLWithPath: CommandLine.arguments[1])
let casesURL = URL(fileURLWithPath: CommandLine.arguments[2])
let cases = try JSONDecoder().decode([PredictionCase].self, from: Data(contentsOf: casesURL))
let compiled = try MLModel.compileModel(at: modelURL)
defer { try? FileManager.default.removeItem(at: compiled) }
let configuration = MLModelConfiguration()
configuration.computeUnits = .cpuOnly
let model = try MLModel(contentsOf: compiled, configuration: configuration)
var maximumError = 0.0
for (testIndex, test) in cases.enumerated() {
    let input = try MLMultiArray(shape: [NSNumber(value: test.input.count)], dataType: .float32)
    for (index, value) in test.input.enumerated() { input[index] = NSNumber(value: value) }
    let provider = try MLDictionaryFeatureProvider(dictionary: ["features": MLFeatureValue(multiArray: input)])
    let result = try model.prediction(from: provider)
    guard let output = result.featureValue(for: "tuning")?.multiArrayValue,
          output.count == test.expected.count else { throw VerificationError.outputShape }
    for (index, expected) in test.expected.enumerated() {
        let actual = output[index].doubleValue
        let error = abs(actual - expected)
        guard actual.isFinite, error <= 0.0001 + abs(expected) * 0.0001 else {
            throw VerificationError.mismatch(test: testIndex, index: index, expected: expected, actual: actual)
        }
        maximumError = max(maximumError, error)
    }
}
print("Core ML runtime: \(cases.count) cases; maximum absolute error \(maximumError)")
