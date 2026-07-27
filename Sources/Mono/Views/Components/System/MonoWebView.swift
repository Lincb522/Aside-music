import SwiftUI
import WebKit

/// App 内 WebView 页面，用于展示外链内容
struct MonoWebView: View {
    let url: URL
    let title: String?
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var pageTitle: String?
    
    var body: some View {
        ZStack {
            ThemedPageBackground()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                webHeader
                
                ZStack {
                    WebViewRepresentable(url: url, isLoading: $isLoading, pageTitle: $pageTitle)
                    
                    if isLoading {
                        MonoLoadingView()
                    }
                }
            }
        }
    }
    
    private var webHeader: some View {
        HStack {
            Button { dismiss() } label: {
                MonoIcon(icon: .xmark, size: 14, color: webSecondaryText)
                    .frame(width: 32, height: 32)
                    .background(SequoiaStyle.isActive ? SequoiaStyle.materialPressed : Color.monoGlassTint)
                    .clipShape(Circle())
            }
            
            Spacer()
            
            Text(title ?? pageTitle ?? String(localized: "详情"))
                .font(webTitleFont)
                .foregroundColor(webText)
                .lineLimit(1)
            
            Spacer()
            
            Color.clear.frame(width: 32, height: 32)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .themedOnlyPageSurface(cornerRadius: MangaStyle.isActive ? 18 : 14, elevated: false)
        .padding(.horizontal, ThemedPageStyle.horizontalInset)
        .padding(.top, ThemedPageStyle.isActive ? 8 : 0)
    }

    private var webText: Color {
        if SequoiaStyle.isActive { return SequoiaStyle.ink }
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        return .monoTextPrimary
    }

    private var webSecondaryText: Color {
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        return .monoTextSecondary
    }

    private var webTitleFont: Font {
        if MangaStyle.isActive { return MangaStyle.titleFont(16, weight: .black) }
        if MujiStyle.isActive { return MujiStyle.titleFont(16, weight: .medium) }
        if SequoiaStyle.isActive { return SequoiaStyle.titleFont(16, weight: .semibold) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.titleFont(16, weight: .semibold) }
        return .system(size: 16, weight: .semibold, design: .rounded)
    }
}

struct WebViewRepresentable: UIViewRepresentable {
    private static let loggerHandlerName = "monoLogger"

    private static let loggerScript = #"""
    (() => {
        if (window.__monoNativeLoggerInstalled) return;
        window.__monoNativeLoggerInstalled = true;

        const bridge = window.webkit && window.webkit.messageHandlers
            ? window.webkit.messageHandlers.monoLogger
            : null;
        if (!bridge) return;

        const serialize = (value) => {
            if (value instanceof Error) {
                return `${value.name}: ${value.message}`;
            }
            if (typeof value === "string") return value;
            try {
                const json = JSON.stringify(value);
                return typeof json === "string" ? json : String(value);
            } catch (_) {
                return String(value);
            }
        };

        const send = (level, args, extra = {}) => {
            try {
                bridge.postMessage({
                    level: String(level || "debug"),
                    eventType: String(extra.eventType || `console.${level}`),
                    message: Array.from(args || []).map(serialize).join(" "),
                    sourceURL: String(extra.sourceURL || location.href || ""),
                    lineNumber: Number(extra.lineNumber || 0),
                    columnNumber: Number(extra.columnNumber || 0),
                    errorName: String(extra.errorName || ""),
                    stack: String(extra.stack || "")
                });
            } catch (_) {}
        };

        ["debug", "log", "info", "warn", "error"].forEach((level) => {
            const original = console[level];
            if (typeof original !== "function") return;
            console[level] = function(...args) {
                const stack = new Error().stack || "";
                send(level, args, { stack, eventType: `console.${level}` });
                return original.apply(console, args);
            };
        });

        window.addEventListener("error", (event) => {
            send("error", [event.message || "JavaScript Error"], {
                sourceURL: event.filename || location.href || "",
                lineNumber: event.lineno || 0,
                columnNumber: event.colno || 0,
                errorName: event.error && event.error.name ? event.error.name : "Error",
                stack: event.error && event.error.stack ? event.error.stack : "",
                eventType: "window.error"
            });
        });

        window.addEventListener("unhandledrejection", (event) => {
            const reason = event.reason;
            send("error", [reason || "Unhandled Promise Rejection"], {
                sourceURL: location.href || "",
                errorName: reason && reason.name ? reason.name : "UnhandledRejection",
                stack: reason && reason.stack ? reason.stack : "",
                eventType: "unhandledrejection"
            });
        });
    })();
    """#

    let url: URL
    @Binding var isLoading: Bool
    @Binding var pageTitle: String?
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: Self.loggerHandlerName)
        contentController.addUserScript(
            WKUserScript(
                source: Self.loggerScript,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            )
        )

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = contentController
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.load(URLRequest(url: url))
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.navigationDelegate = nil
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: loggerHandlerName)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let parent: WebViewRepresentable
        
        init(_ parent: WebViewRepresentable) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
            AppLogger.network(
                "url=\(webView.url?.absoluteString ?? parent.url.absoluteString)",
                step: "WebView navigation started"
            )
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            parent.pageTitle = webView.title
            AppLogger.success(
                "url=\(webView.url?.absoluteString ?? parent.url.absoluteString) title=\(webView.title ?? "")",
                step: "WebView navigation finished"
            )
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            logNavigationFailure(error, url: webView.url)
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            parent.isLoading = false
            logNavigationFailure(error, url: webView.url)
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == WebViewRepresentable.loggerHandlerName,
                  let payload = message.body as? [String: Any]
            else { return }

            let level = (payload["level"] as? String ?? "debug").lowercased()
            let eventType = payload["eventType"] as? String ?? "console.\(level)"
            let body = Self.javaScriptLogBody(from: payload)
            let step = "JavaScript \(eventType)"

            switch level {
            case "error":
                AppLogger.error(body, step: step)
            case "warn", "warning":
                AppLogger.warning(body, step: step)
            case "info":
                AppLogger.info(body, step: step)
            default:
                AppLogger.debug(body, step: step)
            }
        }

        private func logNavigationFailure(_ error: Error, url: URL?) {
            let nsError = error as NSError
            AppLogger.error(
                "url=\(url?.absoluteString ?? parent.url.absoluteString) domain=\(nsError.domain) code=\(nsError.code) message=\(nsError.localizedDescription)",
                step: "WebView navigation failed"
            )
        }

        private static func javaScriptLogBody(from payload: [String: Any]) -> String {
            let level = payload["level"] as? String ?? "debug"
            let eventType = payload["eventType"] as? String ?? "console.\(level)"
            let text = payload["message"] as? String ?? ""
            let sourceURL = payload["sourceURL"] as? String ?? ""
            let lineNumber = Self.integerValue(payload["lineNumber"])
            let columnNumber = Self.integerValue(payload["columnNumber"])
            let errorName = payload["errorName"] as? String ?? ""
            let stack = payload["stack"] as? String ?? ""

            return [
                "[JavaScript]",
                "level=\(level)",
                "eventType=\(eventType)",
                "message=\(text)",
                "sourceURL=\(sourceURL)",
                "lineNumber=\(lineNumber)",
                "columnNumber=\(columnNumber)",
                "errorName=\(errorName)",
                "stack=\(stack)"
            ].joined(separator: "\n")
        }

        private static func integerValue(_ value: Any?) -> Int {
            if let number = value as? NSNumber { return number.intValue }
            if let value = value as? Int { return value }
            return 0
        }
    }
}
