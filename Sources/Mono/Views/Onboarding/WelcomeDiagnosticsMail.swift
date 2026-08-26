import MessageUI
import SwiftUI
import UIKit

struct WelcomeDiagnosticsContext: Sendable {
    let capturedAt: Date
    let elapsedSeconds: TimeInterval
    let themeID: String
    let isLoggedIn: Bool
    let hasStoredToken: Bool
    let preloadCompleted: Bool
    let isWaitingForInitialHomeContent: Bool
    let initialContentRetryCount: Int
    let homeIsLoading: Bool
    let homeHasDisplayableContent: Bool
    let reduceMotionEnabled: Bool

    var logContext: [String: String] {
        [
            "elapsedSeconds": String(format: "%.2f", elapsedSeconds),
            "themeID": themeID,
            "isLoggedIn": String(isLoggedIn),
            "hasStoredToken": String(hasStoredToken),
            "preloadCompleted": String(preloadCompleted),
            "waitingForHomeContent": String(isWaitingForInitialHomeContent),
            "initialContentRetryCount": String(initialContentRetryCount),
            "homeIsLoading": String(homeIsLoading),
            "homeHasDisplayableContent": String(homeHasDisplayableContent),
            "reduceMotionEnabled": String(reduceMotionEnabled),
        ]
    }
}

struct WelcomeDiagnosticsMailDraft: Identifiable {
    static let recipient = "523266933@qq.com"

    let id = UUID()
    let subject: String
    let body: String
    let report: String
    let attachmentURL: URL?

    @MainActor
    static func make(context: WelcomeDiagnosticsContext) -> WelcomeDiagnosticsMailDraft {
        let subject = String(localized: "welcome_diagnostics_subject")
        let body = String(localized: "welcome_diagnostics_body")
        let report = reportText(context: context)
        let attachmentURL = writeReport(report, capturedAt: context.capturedAt)
        return WelcomeDiagnosticsMailDraft(
            subject: subject,
            body: body,
            report: report,
            attachmentURL: attachmentURL
        )
    }

    var mailtoURL: URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = Self.recipient
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: "\(body)\n\n\(String(report.prefix(12_000)))"),
        ]
        return components.url
    }

    @MainActor
    private static func reportText(context: WelcomeDiagnosticsContext) -> String {
        let snapshot = AppLogger.snapshot()
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        let entries = boundedLogEntries(snapshot.entries)
        let logs = entries.isEmpty
            ? "No runtime log entries were collected."
            : AppLogger.textExport(entries: entries)

        return """
        Mono Welcome Diagnostics
        capturedAt=\(context.capturedAt.formatted(.iso8601))
        appVersion=\(version) (\(build))
        osVersion=\(ProcessInfo.processInfo.operatingSystemVersionString)
        deviceModel=\(UIDevice.current.model)
        locale=\(Locale.current.identifier)
        elapsedSeconds=\(String(format: "%.2f", context.elapsedSeconds))
        themeID=\(context.themeID)
        isLoggedIn=\(context.isLoggedIn)
        hasStoredToken=\(context.hasStoredToken)
        preloadCompleted=\(context.preloadCompleted)
        waitingForHomeContent=\(context.isWaitingForInitialHomeContent)
        initialContentRetryCount=\(context.initialContentRetryCount)
        homeIsLoading=\(context.homeIsLoading)
        homeHasDisplayableContent=\(context.homeHasDisplayableContent)
        reduceMotionEnabled=\(context.reduceMotionEnabled)
        droppedLogCount=\(snapshot.droppedCount)
        coalescedLogCount=\(snapshot.coalescedCount)

        --- Runtime Logs ---
        \(logs)
        """
    }

    private static func boundedLogEntries(_ entries: [LogEntry]) -> [LogEntry] {
        let maximumCharacters = 800_000
        var selected: [LogEntry] = []
        var characterCount = 0

        for entry in entries.reversed() {
            let entryCount = entry.exportText.count + 1
            guard characterCount + entryCount <= maximumCharacters else { break }
            selected.append(entry)
            characterCount += entryCount
        }
        return Array(selected.reversed())
    }

    private static func writeReport(_ report: String, capturedAt: Date) -> URL? {
        let timestamp = Int(capturedAt.timeIntervalSince1970)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("mono-welcome-diagnostics-\(timestamp)")
            .appendingPathExtension("log")
        do {
            try report.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            AppLogger.error(
                "[Welcome] Failed to write diagnostics attachment: \(error)",
                category: .interface,
                event: "welcome_diagnostics_write_failed"
            )
            return nil
        }
    }
}

@MainActor
struct WelcomeDiagnosticsMailView: UIViewControllerRepresentable {
    let draft: WelcomeDiagnosticsMailDraft
    @Environment(\.dismiss) private var dismiss

    static var canSendMail: Bool {
        MFMailComposeViewController.canSendMail()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: dismiss)
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        controller.setToRecipients([WelcomeDiagnosticsMailDraft.recipient])
        controller.setSubject(draft.subject)
        controller.setMessageBody(draft.body, isHTML: false)
        if let attachmentURL = draft.attachmentURL,
           let data = try? Data(contentsOf: attachmentURL) {
            controller.addAttachmentData(
                data,
                mimeType: "text/plain",
                fileName: attachmentURL.lastPathComponent
            )
        }
        return controller
    }

    func updateUIViewController(
        _ uiViewController: MFMailComposeViewController,
        context: Context
    ) {}

    @MainActor
    final class Coordinator: NSObject, @preconcurrency MFMailComposeViewControllerDelegate {
        private let dismiss: DismissAction

        init(dismiss: DismissAction) {
            self.dismiss = dismiss
        }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            if let error {
                AppLogger.error(
                    "[Welcome] Diagnostics mail failed: \(error)",
                    category: .interface,
                    event: "welcome_diagnostics_mail_failed"
                )
            }
            dismiss()
        }
    }
}
