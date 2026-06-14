import SwiftUI
import WebKit

struct EclassLoginWebView: UIViewRepresentable {
    @ObservedObject var syncManager: EclassSyncManager

    func makeCoordinator() -> Coordinator {
        Coordinator(syncManager: syncManager)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: URL(string: "https://learn.hansung.ac.kr/login/index.php")!))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        let syncManager: EclassSyncManager

        init(syncManager: EclassSyncManager) {
            self.syncManager = syncManager
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                self.syncManager.startIfPossible(webView: webView)
            }
        }
    }
}
