import Foundation

enum DownloadResponseValidator {
    enum Failure: LocalizedError {
        case http(Int)
        case invalidMedia

        var errorDescription: String? {
            switch self {
            case .http(let status):
                return String(format: String(localized: "download_http_failed_format"), status)
            case .invalidMedia:
                return String(localized: "download_invalid_media")
            }
        }
    }

    static func validate(response: URLResponse?) throws {
        guard let response = response as? HTTPURLResponse else { throw Failure.invalidMedia }
        guard response.statusCode == 200 || response.statusCode == 206 else {
            throw Failure.http(response.statusCode)
        }
        let mime = (response.mimeType ?? "").lowercased()
        if mime.hasPrefix("text/") || mime.contains("json") || mime.contains("xml") {
            throw Failure.invalidMedia
        }
    }

    static func validateMediaPrefix(_ data: Data) throws {
        let bytes = [UInt8](data.prefix(16))
        guard bytes.count >= 12 else { throw Failure.invalidMedia }
        let signature = String(decoding: bytes.prefix(4), as: UTF8.self)
        let isWave = signature == "RIFF" && String(decoding: bytes[8..<12], as: UTF8.self) == "WAVE"
        let isMP4 = String(decoding: bytes[4..<8], as: UTF8.self) == "ftyp"
        let isMPEG = bytes[0] == 0xff && bytes[1] & 0xe0 == 0xe0
        guard ["fLaC", "OggS"].contains(signature) || isWave || isMP4 || isMPEG
            || bytes.prefix(3).elementsEqual([0x49, 0x44, 0x33]) else {
            throw Failure.invalidMedia
        }
    }
}
