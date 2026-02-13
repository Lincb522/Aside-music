import SwiftUI
import WebKit

/// App 内 WebView 页面，用于展示外链内容
struct AsideWebView: View {
    let url: URL
    let title: String?
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            AsideBackground()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 导航栏
                HStack {
                    Button(action: { dismiss() }) {
                        AsideIcon(icon: .chevronLeft, size: 18, color: .asideTextPrimary)
                            .padding(10)
                            .background(Color.asideSeparator)
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Text(title ?? "详情")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(.asideTextPrimary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // 占位，保持标题居中
                    Color.clear.frame(width: 38, height: 38)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                
                ZStack {
                    WebViewRepresentable(url: url, isLoading: $isLoading)
                    
                    if isLoading {
                        AsideLoadingView()
                    }
                }
            }
        }
        .navigationBarHidden(true)
    }
}

struct WebViewRepresentable: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    
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
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
        }
    }
}
