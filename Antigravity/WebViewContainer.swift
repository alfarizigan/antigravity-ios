import SwiftUI
import WebKit
import UserNotifications

struct WebViewContainer: UIViewRepresentable {
    @Binding var progress: Double
    @Binding var isLoading: Bool
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var reloadTrigger: Bool
    @Binding var goBackTrigger: Bool
    @Binding var goHomeTrigger: Bool
    @Binding var externalURLToOpen: IdentifiableURL?
    @Binding var downloadedFileURL: IdentifiableURL?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.websiteDataStore = WKWebsiteDataStore.default()

        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = preferences

        // Inject Native Notification Bridge so web app notifications trigger native iOS notification banners
        let contentController = WKUserContentController()
        let scriptSource = """
        (function() {
            function postNativeNotification(title, options) {
                try {
                    window.webkit.messageHandlers.notificationHandler.postMessage({
                        title: title || 'Antigravity',
                        body: (options && options.body) ? options.body : ''
                    });
                } catch(e) {}
            }
            window.Notification = function(title, options) {
                postNativeNotification(title, options);
                return {
                    close: function() {},
                    addEventListener: function() {},
                    removeEventListener: function() {}
                };
            };
            window.Notification.permission = 'granted';
            window.Notification.requestPermission = function() {
                return Promise.resolve('granted');
            };
        })();
        """
        let userScript = WKUserScript(source: scriptSource, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        contentController.addUserScript(userScript)
        contentController.add(context.coordinator, name: "notificationHandler")
        configuration.userContentController = contentController

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 0.07, green: 0.08, blue: 0.10, alpha: 1.0)
        webView.scrollView.backgroundColor = UIColor(red: 0.07, green: 0.08, blue: 0.10, alpha: 1.0)

        // Custom Safari User-Agent to prevent Google OAuth 403 disallowed_useragent
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"

        // Pull to refresh support
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(context.coordinator, action: #selector(Coordinator.handleRefresh(_:)), for: .valueChanged)
        refreshControl.tintColor = UIColor(red: 0.26, green: 0.52, blue: 0.96, alpha: 1.0)
        webView.scrollView.refreshControl = refreshControl

        // Setup KVO observers
        context.coordinator.setupObservers(for: webView)

        // Setup Cookie persistence
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

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate, WKScriptMessageHandler {
        var parent: WebViewContainer
        private var progressObservation: NSKeyValueObservation?
        private var urlObservation: NSKeyValueObservation?
        private var canGoBackObservation: NSKeyValueObservation?
        private var canGoForwardObservation: NSKeyValueObservation?

        init(_ parent: WebViewContainer) {
            self.parent = parent
        }

        func setupObservers(for webView: WKWebView) {
            progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] view, _ in
                DispatchQueue.main.async {
                    self?.parent.progress = view.estimatedProgress
                }
            }

            // KVO on URL: Tracks route changes even in Single Page Apps (SPA) without full reload
            urlObservation = webView.observe(\.url, options: [.new]) { [weak self] view, _ in
                if let newURL = view.url {
                    CookieManager.shared.saveLastVisitedURL(newURL)
                    DispatchQueue.main.async {
                        self?.parent.canGoBack = view.canGoBack
                        self?.parent.canGoForward = view.canGoForward
                    }
                }
            }

            canGoBackObservation = webView.observe(\.canGoBack, options: [.new]) { [weak self] view, _ in
                DispatchQueue.main.async {
                    self?.parent.canGoBack = view.canGoBack
                }
            }

            canGoForwardObservation = webView.observe(\.canGoForward, options: [.new]) { [weak self] view, _ in
                DispatchQueue.main.async {
                    self?.parent.canGoForward = view.canGoForward
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

        // Bridge JavaScript window.Notification to iOS native notification banners
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "notificationHandler", let dict = message.body as? [String: Any] {
                let title = dict["title"] as? String ?? "Antigravity"
                let body = dict["body"] as? String ?? ""

                let content = UNMutableNotificationContent()
                content.title = title
                content.body = body
                content.sound = .default

                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
                let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
                UNUserNotificationCenter.current().add(request)
            }
        }

        // Intercept external links and special schemes
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            let scheme = url.scheme?.lowercased() ?? ""
            if ["mailto", "tel", "sms"].contains(scheme) {
                decisionHandler(.cancel)
                UIApplication.shared.open(url)
                return
            }

            if scheme == "itms-apps" || (url.host?.lowercased().contains("apps.apple.com") ?? false) {
                decisionHandler(.cancel)
                UIApplication.shared.open(url)
                return
            }

            let host = url.host?.lowercased() ?? ""
            let isInternal = host.isEmpty ||
                             host.contains("antigravity.google") ||
                             host.contains("accounts.google.com") ||
                             host.contains("google.com") ||
                             host.contains("gstatic.com") ||
                             host.contains("googleapis.com")

            // If user clicked an external link (like GitHub, documentation, blog):
            if navigationAction.navigationType == .linkActivated && !isInternal {
                decisionHandler(.cancel)
                DispatchQueue.main.async {
                    self.parent.externalURLToOpen = IdentifiableURL(url: url)
                }
                return
            }

            decisionHandler(.allow)
        }

        // Handle target="_blank" and popup windows
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
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.canGoBack = webView.canGoBack
                self.parent.canGoForward = webView.canGoForward
                webView.scrollView.refreshControl?.endRefreshing()
                if let currentURL = webView.url {
                    CookieManager.shared.saveLastVisitedURL(currentURL)
                }
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                webView.scrollView.refreshControl?.endRefreshing()
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                webView.scrollView.refreshControl?.endRefreshing()
            }
        }

        // WKDownloadDelegate: Handle file downloads (e.g. exporting artifacts/code)
        func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
            download.delegate = self
        }

        func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
            download.delegate = self
        }

        func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
            let tempDir = FileManager.default.temporaryDirectory
            let targetURL = tempDir.appendingPathComponent(suggestedFilename)
            try? FileManager.default.removeItem(at: targetURL)
            completionHandler(targetURL)
        }

        func downloadDidFinish(_ download: WKDownload) {
            // Download completed gracefully
        }

        func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
            // Download failed gracefully
        }
    }
}
