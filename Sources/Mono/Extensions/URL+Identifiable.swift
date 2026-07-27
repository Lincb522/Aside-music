import Foundation

// MARK: - URL Extensions

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }

    /// FFmpeg 对本地资源更适合接收文件系统路径，而不是 file:// URL 字符串。
    var playerInputString: String {
        isFileURL ? path : absoluteString
    }
}
