import SwiftUI
import WebKit

/// App 内 WebView 页面，用于展示外链内容
struct MonologueWebView: View {
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
                        MonologueLoadingView()
                    }
                }
            }
        }
    }
    
    private var webHeader: some View {
        HStack {
            Button { dismiss() } label: {
                MonologueIcon(icon: .xmark, size: 14)
                    .frame(width: 32, height: 32)
                    .background(Color.monologueGlassTint)
                    .clipShape(Circle())
            }
            
            Spacer()
            
            Text(title ?? pageTitle ?? String(localized: "详情"))
                .font(MangaStyle.isActive ? MangaStyle.comicFont(16, weight: .bold) : (MujiStyle.isActive ? MujiStyle.titleFont(16, weight: .medium) : .system(size: 16, weight: .semibold, design: .rounded)))
                .foregroundColor(.monologueTextPrimary)
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
}

struct WebViewRepresentable: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var pageTitle: String?
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.load(URLRequest(url: url))
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: WebViewRepresentable
        
        init(_ parent: WebViewRepresentable) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            parent.pageTitle = webView.title
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
        }
    }
}
