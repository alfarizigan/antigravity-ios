import SwiftUI
import WebKit

struct WebViewContainer: UIViewRepresentable {
    @Binding var progress: Double
    @Binding var isLoading: Bool
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var reloadTrigger: Bool
    @Binding var goBackTrigger: Bool
    @Binding var goHomeTrigger: Bool
    @Binding var externalURLToOpen: IdentifiableURL?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.websiteDataStore = WKWebsiteDataStore.default()

        // Responsive viewport and script execution
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = preferences

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 0.07, green: 0.08, blue: 0.10, alpha: 1.0)
        webView.scrollView.backgroundColor = UIColor(red: 0.07, green: 0.08, blue: 0.10, alpha: 1.0)

        // Custom Safari User-Agent to avoid Google OAuth 403 disallowed_useragent
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"

        // Pull to refresh support
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(context.coordinator, action: #selector(Coordinator.handleRefresh(_:)), for: .valueChanged)
        refreshControl.tintColor = UIColor(red: 0.26, green: 0.52, blue: 0.96, alpha: 1.0)
        webView.scrollView.refreshControl = refreshControl

        // Observe progress
        context.coordinator.setupProgressObserver(for: webView)

        // Observe cookies for persistence
        CookieManager.shared.setupObserver(for: webView.configuration.websiteDataStore.httpCookieStore)

        // Restore cookies before loading initial URL
        CookieManager.shared.restoreCookies(into: webView.configuration.websiteDataStore.httpCookieStore) {
            let startURL = CookieManager.shared.getInitialURL()
            let request = URLRequest(url: startURL, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 30)
            webView.load(request)
        }

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if reloadTrigger {
            DispatchQueue.main.async {
                self.reloadTrigger = false
            }
            uiView.reload()
        }
        if goBackTrigger {
            DispatchQueue.main.async {
                self.goBackTrigger = false
            }
            if uiView.canGoBack {
                uiView.goBack()
            }
        }
        if goHomeTrigger {
            DispatchQueue.main.async {
                self.goHomeTrigger = false
            }
            CookieManager.shared.clearSavedURL()
            let rootReq = URLRequest(url: URL(string: "https://antigravity.google")!)
            uiView.load(rootReq)
        }
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: WebViewContainer
        private var progressObservation: NSKeyValueObservation?

        init(_ parent: WebViewContainer) {
            self.parent = parent
        }

        func setupProgressObserver(for webView: WKWebView) {
            progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] view, change in
                DispatchQueue.main.async {
                    self?.parent.progress = view.estimatedProgress
                }
            }
        }

        @objc func handleRefresh(_ sender: UIRefreshControl) {
            if let webView = sender.superview as? WKWebView ?? (sender.superview?.superview as? WKWebView) {
                webView.reload()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                sender.endRefreshing()
            }
        }

        // Intercept navigation: Open external links in SFSafariViewController
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url {
                let host = url.host?.lowercased() ?? ""
                let isInternal = host.isEmpty ||
                                 host.contains("antigravity.google") ||
                                 host.contains("accounts.google.com") ||
                                 host.contains("google.com") ||
                                 host.contains("gstatic.com") ||
                                 host.contains("googleapis.com")

                if navigationAction.navigationType == .linkActivated && !isInternal {
                    decisionHandler(.cancel)
                    DispatchQueue.main.async {
                        self.parent.externalURLToOpen = IdentifiableURL(url: url)
                    }
                    return
                }
            }
            decisionHandler(.allow)
        }

        // Support target="_blank" and popups
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = navigationAction.request.url {
                let host = url.host?.lowercased() ?? ""
                let isInternal = host.contains("antigravity.google") ||
                                 host.contains("accounts.google.com") ||
                                 host.contains("google.com")
                if !isInternal {
                    DispatchQueue.main.async {
                        self.parent.externalURLToOpen = IdentifiableURL(url: url)
                    }
                    return nil
                }
            }
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = true
                self.parent.canGoBack = webView.canGoBack
                self.parent.canGoForward = webView.canGoForward
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.canGoBack = webView.canGoBack
                self.parent.canGoForward = webView.canGoForward
                if let currentURL = webView.url {
                    CookieManager.shared.saveLastVisitedURL(currentURL)
                }
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }
    }
}
