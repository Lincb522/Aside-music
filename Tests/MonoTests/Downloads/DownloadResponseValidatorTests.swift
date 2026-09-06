import XCTest
@testable import Mono

final class DownloadResponseValidatorTests: XCTestCase {
    func testRejectsHTTPErrorEvenWhenDownloadTransferSucceeded() throws {
        let url = try XCTUnwrap(URL(string: "https://example.invalid/fixture.mp3"))
        let response = HTTPURLResponse(url: url, statusCode: 403, httpVersion: nil, headerFields: nil)
        XCTAssertThrowsError(try DownloadResponseValidator.validate(response: response))
    }

    func testRejectsErrorDocumentWithSuccessfulStatus() throws {
        let url = try XCTUnwrap(URL(string: "https://example.invalid/fixture.mp3"))
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil,
                                       headerFields: ["Content-Type": "application/json"])
        XCTAssertThrowsError(try DownloadResponseValidator.validate(response: response))
        XCTAssertThrowsError(try DownloadResponseValidator.validateMediaPrefix(Data("<html>expired link</html>".utf8)))
    }

    func testAcceptsSupportedAudioHeadersAndRejectsEmptyFiles() throws {
        for prefix in ["fLaC", "OggS", "ID3\u{0}", "RIFF\u{0}\u{0}\u{0}\u{0}WAVE", "\u{0}\u{0}\u{0}\u{0}ftyp"] {
            try DownloadResponseValidator.validateMediaPrefix(Data((prefix + String(repeating: "\u{0}", count: 16)).utf8))
        }
        XCTAssertThrowsError(try DownloadResponseValidator.validateMediaPrefix(Data()))
    }
}
