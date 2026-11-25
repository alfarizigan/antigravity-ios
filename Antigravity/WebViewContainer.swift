import SwiftUI
import WebKit
import UserNotifications
import Network
import UIKit

final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var delegate: WKScriptMessageHandler?

    init(_ delegate: WKScriptMessageHandler) {
        self.delegate = delegate
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        delegate?.userContentController(userContentController, didReceive: message)
    }
}

struct WebViewContainer: UIViewRepresentable {
    @Binding var progress: Double
    @Binding var isLoading: Bool
    @Binding var isInitialBootLoading: Bool
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var currentURL: URL?
    @Binding var networkErrorMessage: String?
    @Binding var reloadTrigger: Bool
    @Binding var goBackTrigger: Bool
    @Binding var goForwardTrigger: Bool
    @Binding var goHomeTrigger: Bool
    @Binding var externalURLToOpen: IdentifiableURL?
    @Binding var popupWebItem: PopupWebItem?
    @Binding var sharePayload: SharePayload?
    @Binding var toastMessage: String?

    static let safariUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.7 Mobile/15E148 Safari/604.1"
    static let surfaceUIColor = UIColor(red: 31/255, green: 31/255, blue: 31/255, alpha: 1.0)

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.websiteDataStore = .default()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true

        let pagePrefs = WKWebpagePreferences()
        pagePrefs.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = pagePrefs

        // CSP & Trusted-Types safe UserScript:
        // 1) Bridges window.Notification & ServiceWorkerRegistration.showNotification -> UNUserNotificationCenter
        // 2) Bridges client-side blob:/data: <a download> exports -> native Documents/Downloads + Share Sheet
        let contentController = WKUserContentController()
        let bridgeScript = """
        (function() {
            'use strict';
            function sendNativeNotification(title, options) {
                try {
                    var opts = options || {};
                    window.webkit.messageHandlers.notificationHandler.postMessage({
                        title: String(title || 'Antigravity'),
                        body: opts.body ? String(opts.body) : '',
                        tag: opts.tag ? String(opts.tag) : '',
                        url: (opts.data && opts.data.url) ? String(opts.data.url) : window.location.href
                    });
                } catch (_) {}
            }

            function NativeNotification(title, options) {
                if (!(this instanceof NativeNotification)) {
                    return new NativeNotification(title, options);
                }
                var opts = options || {};
                this.title = String(title || 'Antigravity');
                this.body = opts.body ? String(opts.body) : '';
                this.tag = opts.tag ? String(opts.tag) : '';
                this.data = opts.data || null;
                this.onclick = null;
                this.onshow = null;
                this.onclose = null;
                this.onerror = null;
                sendNativeNotification(this.title, opts);
            }
            NativeNotification.permission = 'granted';
            NativeNotification.maxActions = 2;
            NativeNotification.requestPermission = function(callback) {
                if (typeof callback === 'function') {
                    try { callback('granted'); } catch (_) {}
                }
                return Promise.resolve('granted');
            };
            NativeNotification.prototype.close = function() {
                if (typeof this.onclose === 'function') {
                    try { this.onclose(); } catch (_) {}
                }
            };
            NativeNotification.prototype.addEventListener = function() {};
            NativeNotification.prototype.removeEventListener = function() {};
            NativeNotification.prototype.dispatchEvent = function() { return true; };
            window.Notification = NativeNotification;

            if (window.ServiceWorkerRegistration && window.ServiceWorkerRegistration.prototype) {
                window.ServiceWorkerRegistration.prototype.showNotification = function(title, options) {
                    sendNativeNotification(title, options);
                    return Promise.resolve();
                };
            }

            document.addEventListener('click', function(ev) {
                var el = ev.target;
                while (el && el.tagName !== 'A') {
                    el = el.parentElement;
                }
                if (!el || !el.hasAttribute('download')) return;
                var href = el.getAttribute('href') || '';
                var filename = el.getAttribute('download') || 'export.txt';
                if (href.indexOf('blob:') === 0) {
                    ev.preventDefault();
                    fetch(href).then(function(r) { return r.blob(); }).then(function(blob) {
                        var reader = new FileReader();
                        reader.onloadend = function() {
                            try {
                                window.webkit.messageHandlers.blobDownloadHandler.postMessage({
                                    filename: filename,
                                    dataURL: String(reader.result || '')
                                });
                            } catch (_) {}
                        };
                        reader.readAsDataURL(blob);
                    }).catch(function() {});
                } else if (href.indexOf('data:') === 0) {
                    ev.preventDefault();
                    try {
                        window.webkit.messageHandlers.blobDownloadHandler.postMessage({
                            filename: filename,
                            dataURL: href
                        });
                    } catch (_) {}
                }
            }, true);
        })();
        """
        contentController.addUserScript(
            WKUserScript(source: bridgeScript, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        )
        let weakHandler = WeakScriptMessageHandler(context.coordinator)
        contentController.add(weakHandler, name: "notificationHandler")
        contentController.add(weakHandler, name: "blobDownloadHandler")
        configuration.userContentController = contentController

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = Self.surfaceUIColor
        webView.underPageBackgroundColor = Self.surfaceUIColor
        webView.scrollView.backgroundColor = Self.surfaceUIColor
        webView.scrollView.bounces = false
        webView.scrollView.alwaysBounceVertical = false
        webView.scrollView.alwaysBounceHorizontal = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.customUserAgent = Self.safariUserAgent

        #if DEBUG
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        #endif

        context.coordinator.attach(to: webView)
        CookieManager.shared.setupObserver(for: configuration.websiteDataStore.httpCookieStore)

        CookieManager.shared.restoreCookies(into: configuration.websiteDataStore.httpCookieStore) {
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
                self.networkErrorMessage = nil
            }
            if uiView.url != nil {
                uiView.reload()
            } else {
                let startURL = CookieManager.shared.getInitialURL()
                uiView.load(URLRequest(url: startURL, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 30))
            }
        }
        if goBackTrigger {
            DispatchQueue.main.async { self.goBackTrigger = false }
            if uiView.canGoBack {
                uiView.goBack()
            }
        }
        if goForwardTrigger {
            DispatchQueue.main.async { self.goForwardTrigger = false }
            if uiView.canGoForward {
                uiView.goForward()
            }
        }
        if goHomeTrigger {
            DispatchQueue.main.async {
                self.goHomeTrigger = false
                self.networkErrorMessage = nil
            }
            CookieManager.shared.clearSavedURL()
            if let rootURL = URL(string: CookieManager.defaultAppURLString) {
                uiView.load(URLRequest(url: rootURL))
            }
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate, WKScriptMessageHandler {
        var parent: WebViewContainer
        weak var webView: WKWebView?

        private var progressObservation: NSKeyValueObservation?
        private var urlObservation: NSKeyValueObservation?
        private var canGoBackObservation: NSKeyValueObservation?
        private var canGoForwardObservation: NSKeyValueObservation?
        private let pathMonitor = NWPathMonitor()
        private let monitorQueue = DispatchQueue(label: "com.google.antigravity.network")
        private var activeDownloads: [ObjectIdentifier: URL] = [:]

        init(_ parent: WebViewContainer) {
            self.parent = parent
            super.init()
            setupLifecycleAndDeepLinkObservers()
            startNetworkMonitor()
        }

        deinit {
            pathMonitor.cancel()
            NotificationCenter.default.removeObserver(self)
        }

        func attach(to webView: WKWebView) {
            self.webView = webView

            progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] view, _ in
                DispatchQueue.main.async {
                    self?.parent.progress = view.estimatedProgress
                }
            }

            urlObservation = webView.observe(\.url, options: [.new]) { [weak self] view, _ in
                guard let self = self else { return }
                if let newURL = view.url {
                    CookieManager.shared.saveLastVisitedURL(newURL)
                }
                DispatchQueue.main.async {
                    self.parent.currentURL = view.url
                    self.parent.canGoBack = view.canGoBack
                    self.parent.canGoForward = view.canGoForward
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

            // Safety cap so initial splash never hangs if a long-polling subresource keeps loading
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.5) { [weak self] in
                if self?.parent.isInitialBootLoading == true {
                    withAnimation(.easeOut(duration: 0.25)) {
                        self?.parent.isInitialBootLoading = false
                    }
                }
            }
        }

        private func setupLifecycleAndDeepLinkObservers() {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleWillEnterForeground),
                name: UIApplication.willEnterForegroundNotification,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleOpenURLNotification(_:)),
                name: .antigravityOpenURL,
                object: nil
            )
        }

        @objc private func handleWillEnterForeground() {
            guard let wv = webView else { return }
            // Recover automatically if WebContent was terminated while suspended in background
            if wv.url == nil {
                recoverWebViewSession(wv)
            }
        }

        @objc private func handleOpenURLNotification(_ notification: Notification) {
            guard let targetURL = notification.object as? URL, let wv = webView else { return }
            let host = targetURL.host?.lowercased() ?? ""
            if Self.isInternalHost(host) {
                wv.load(URLRequest(url: targetURL))
            } else if let scheme = targetURL.scheme?.lowercased(), scheme == "http" || scheme == "https" {
                DispatchQueue.main.async {
                    self.parent.externalURLToOpen = IdentifiableURL(url: targetURL)
                }
            }
        }

        private func startNetworkMonitor() {
            pathMonitor.pathUpdateHandler = { [weak self] path in
                guard path.status == .satisfied else { return }
                DispatchQueue.main.async {
                    guard let self = self, self.parent.networkErrorMessage != nil, let wv = self.webView else { return }
                    self.parent.networkErrorMessage = nil
                    if wv.url != nil {
                        wv.reload()
                    } else {
                        wv.load(URLRequest(url: CookieManager.shared.getInitialURL()))
                    }
                }
            }
            pathMonitor.start(queue: monitorQueue)
        }

        private func recoverWebViewSession(_ wv: WKWebView) {
            CookieManager.shared.restoreCookies(into: wv.configuration.websiteDataStore.httpCookieStore) {
                let resumeURL = wv.url ?? CookieManager.shared.getInitialURL()
                wv.load(URLRequest(url: resumeURL, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 30))
            }
        }

        // MARK: - Domain Classification Helpers

        private static func isInternalHost(_ host: String) -> Bool {
            if host.isEmpty { return true }
            let internalSuffixes = [
                "antigravity.google.com",
                "antigravity.google",
                "accounts.google.com",
                "myaccount.google.com",
                "accounts.youtube.com",
                "gstatic.com",
                "googleapis.com",
                "googleusercontent.com",
                "google.com"
            ]
            for suffix in internalSuffixes {
                if host == suffix || host.hasSuffix(".\(suffix)") {
                    return true
                }
            }
            return false
        }

        private static func isOAuthURL(_ url: URL) -> Bool {
            let host = url.host?.lowercased() ?? ""
            let path = url.path.lowercased()
            if host == "accounts.google.com" || host.hasSuffix(".accounts.google.com") {
                return true
            }
            if (host == "github.com" || host.hasSuffix(".github.com")) &&
               (path.hasPrefix("/login") || path.hasPrefix("/session") || path.hasPrefix("/sessions") || path.hasPrefix("/apps/") || path.contains("oauth") || path.contains("authorize")) {
                return true
            }
            if path.contains("/oauth") || path.contains("/authorize") {
                return true
            }
            return false
        }

        // MARK: - WKScriptMessageHandler

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "notificationHandler", let dict = message.body as? [String: Any] {
                let title = dict["title"] as? String ?? "Antigravity"
                let body = dict["body"] as? String ?? ""
                let tag = dict["tag"] as? String ?? ""
                let urlStr = dict["url"] as? String ?? CookieManager.defaultAppURLString

                let content = UNMutableNotificationContent()
                content.title = title
                content.body = body
                content.sound = .default
                content.userInfo = ["url": urlStr]
                if !tag.isEmpty {
                    content.threadIdentifier = tag
                }

                let reqID = tag.isEmpty ? UUID().uuidString : "ag-\(tag)"
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
                let request = UNNotificationRequest(identifier: reqID, content: content, trigger: trigger)
                UNUserNotificationCenter.current().add(request)
            } else if message.name == "blobDownloadHandler", let dict = message.body as? [String: Any] {
                guard let dataURL = dict["dataURL"] as? String,
                      let commaIdx = dataURL.firstIndex(of: ",") else { return }
                let rawFilename = dict["filename"] as? String ?? "antigravity-export.txt"
                let metaPart = String(dataURL[..<commaIdx])
                let payloadPart = String(dataURL[dataURL.index(after: commaIdx)...])

                let fileData: Data?
                if metaPart.contains(";base64") {
                    fileData = Data(base64Encoded: payloadPart, options: .ignoreUnknownCharacters)
                } else {
                    fileData = payloadPart.removingPercentEncoding?.data(using: .utf8)
                }

                guard let validData = fileData else { return }
                saveExportedDataAndShare(data: validData, suggestedFilename: rawFilename)
            }
        }

        // MARK: - WKNavigationDelegate

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            if navigationAction.shouldPerformDownload {
                decisionHandler(.download)
                return
            }

            let scheme = url.scheme?.lowercased() ?? ""
            if ["mailto", "tel", "sms", "facetime"].contains(scheme) {
                decisionHandler(.cancel)
                UIApplication.shared.open(url)
                return
            }

            if scheme == "itms-apps" || scheme == "itms-appss" || (url.host?.lowercased().contains("apps.apple.com") == true) {
                decisionHandler(.cancel)
                UIApplication.shared.open(url)
                return
            }

            // Inside popup OAuth webView, allow OAuth redirects (GitHub / Google) freely
            if webView !== self.webView {
                decisionHandler(.allow)
                return
            }

            let host = url.host?.lowercased() ?? ""
            let isInternal = Self.isInternalHost(host) || Self.isOAuthURL(url)

            if navigationAction.navigationType == .linkActivated && !isInternal && (scheme == "http" || scheme == "https") {
                decisionHandler(.cancel)
                DispatchQueue.main.async {
                    self.parent.externalURLToOpen = IdentifiableURL(url: url)
                }
                return
            }

            decisionHandler(.allow)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationResponse: WKNavigationResponse,
            decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
        ) {
            if let httpResp = navigationResponse.response as? HTTPURLResponse,
               let disposition = httpResp.value(forHTTPHeaderField: "Content-Disposition")?.lowercased(),
               disposition.contains("attachment") {
                decisionHandler(.download)
                return
            }
            if !navigationResponse.canShowMIMEType {
                decisionHandler(.download)
                return
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            guard webView === self.webView else { return }
            DispatchQueue.main.async {
                self.parent.isLoading = true
                self.parent.networkErrorMessage = nil
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard webView === self.webView else { return }
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.networkErrorMessage = nil
                self.parent.currentURL = webView.url
                self.parent.canGoBack = webView.canGoBack
                self.parent.canGoForward = webView.canGoForward
                if self.parent.isInitialBootLoading {
                    withAnimation(.easeOut(duration: 0.25)) {
                        self.parent.isInitialBootLoading = false
                    }
                }
                if let currentURL = webView.url {
                    CookieManager.shared.saveLastVisitedURL(currentURL)
                }
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            handleNavigationError(webView, error: error, isProvisional: false)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            handleNavigationError(webView, error: error, isProvisional: true)
        }

        private func handleNavigationError(_ webView: WKWebView, error: Error, isProvisional: Bool) {
            guard webView === self.webView else { return }
            let nsErr = error as NSError

            // Ignore benign navigation cancellations (-999) and policy/download handoffs (WebKitErrorDomain 102 / 204)
            if nsErr.code == NSURLErrorCancelled || (nsErr.domain == "WebKitErrorDomain" && (nsErr.code == 102 || nsErr.code == 204)) {
                DispatchQueue.main.async {
                    self.parent.isLoading = false
                }
                return
            }

            DispatchQueue.main.async {
                self.parent.isLoading = false
                if self.parent.isInitialBootLoading {
                    withAnimation(.easeOut(duration: 0.2)) {
                        self.parent.isInitialBootLoading = false
                    }
                }
                if isProvisional {
                    let offlineCodes = [
                        NSURLErrorNotConnectedToInternet,
                        NSURLErrorNetworkConnectionLost,
                        NSURLErrorTimedOut,
                        NSURLErrorCannotFindHost,
                        NSURLErrorCannotConnectToHost,
                        NSURLErrorDNSLookupFailed
                    ]
                    if offlineCodes.contains(nsErr.code) {
                        self.parent.networkErrorMessage = "Periksa koneksi Wi-Fi atau data seluler Anda. Aplikasi akan tersambung otomatis saat internet kembali aktif."
                    }
                }
            }
        }

        // Auto-recover if iOS terminates background WebContent process under heavy memory pressure
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            guard webView === self.webView else {
                DispatchQueue.main.async {
                    self.parent.popupWebItem = nil
                }
                return
            }
            recoverWebViewSession(webView)
        }

        // MARK: - WKUIDelegate (Popups, JS Alerts/Confirms/Prompts, Voice Mode Mic/Camera)

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            let url = navigationAction.request.url
            let scheme = url?.scheme?.lowercased() ?? ""
            let host = url?.host?.lowercased() ?? ""

            // System schemes
            if ["mailto", "tel", "sms", "facetime"].contains(scheme), let validURL = url {
                UIApplication.shared.open(validURL)
                return nil
            }

            // Standard external target="_blank" link click (non-OAuth, non-popup window) -> In-App Safari Sheet
            let isExplicitPopupWindow = (windowFeatures.width != nil || windowFeatures.height != nil)
            if let validURL = url,
               (scheme == "http" || scheme == "https"),
               !Self.isInternalHost(host),
               !Self.isOAuthURL(validURL),
               !isExplicitPopupWindow {
                DispatchQueue.main.async {
                    self.parent.externalURLToOpen = IdentifiableURL(url: validURL)
                }
                return nil
            }

            // OAuth popup or window.open() requiring window.opener & shared WKWebsiteDataStore
            let popupWV = WKWebView(frame: .zero, configuration: configuration)
            popupWV.navigationDelegate = self
            popupWV.uiDelegate = self
            popupWV.customUserAgent = WebViewContainer.safariUserAgent
            popupWV.isOpaque = false
            popupWV.backgroundColor = WebViewContainer.surfaceUIColor
            popupWV.scrollView.backgroundColor = WebViewContainer.surfaceUIColor

            let item = PopupWebItem(webView: popupWV, initialURL: url)
            DispatchQueue.main.async {
                self.parent.popupWebItem = item
            }
            return popupWV
        }

        func webViewDidClose(_ webView: WKWebView) {
            if webView !== self.webView {
                DispatchQueue.main.async {
                    if self.parent.popupWebItem?.webView === webView {
                        self.parent.popupWebItem = nil
                    }
                }
            }
        }

        // Seamless Voice Mode & Camera capture permission for trusted Google Antigravity origins
        func webView(
            _ webView: WKWebView,
            requestMediaCapturePermissionFor origin: WKSecurityOrigin,
            initiatedByFrame frame: WKFrameInfo,
            type: WKMediaCaptureType,
            decisionHandler: @escaping (WKPermissionDecision) -> Void
        ) {
            let host = origin.host.lowercased()
            if Self.isInternalHost(host) {
                decisionHandler(.grant)
            } else {
                decisionHandler(.prompt)
            }
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptAlertPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping () -> Void
        ) {
            guard let presenter = Self.topViewController() else {
                completionHandler()
                return
            }
            let alert = UIAlertController(title: "Antigravity", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Oke", style: .default) { _ in
                completionHandler()
            })
            presenter.present(alert, animated: true)
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptConfirmPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping (Bool) -> Void
        ) {
            guard let presenter = Self.topViewController() else {
                completionHandler(false)
                return
            }
            let alert = UIAlertController(title: "Konfirmasi", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Batal", style: .cancel) { _ in
                completionHandler(false)
            })
            alert.addAction(UIAlertAction(title: "Ya", style: .default) { _ in
                completionHandler(true)
            })
            presenter.present(alert, animated: true)
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptTextInputPanelWithPrompt prompt: String,
            defaultText: String?,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping (String?) -> Void
        ) {
            guard let presenter = Self.topViewController() else {
                completionHandler(nil)
                return
            }
            let alert = UIAlertController(title: "Antigravity", message: prompt, preferredStyle: .alert)
            alert.addTextField { tf in
                tf.text = defaultText
            }
            alert.addAction(UIAlertAction(title: "Batal", style: .cancel) { _ in
                completionHandler(nil)
            })
            alert.addAction(UIAlertAction(title: "Simpan", style: .default) { _ in
                completionHandler(alert.textFields?.first?.text)
            })
            presenter.present(alert, animated: true)
        }

        private static func topViewController() -> UIViewController? {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            let keyWindow = scenes
                .flatMap { $0.windows }
                .first { $0.isKeyWindow } ?? scenes.first?.windows.first
            var top = keyWindow?.rootViewController
            while let presented = top?.presentedViewController {
                top = presented
            }
            return top
        }

        // MARK: - WKDownloadDelegate & File Export

        func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
            download.delegate = self
        }

        func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
            download.delegate = self
        }

        func download(
            _ download: WKDownload,
            decideDestinationUsing response: URLResponse,
            suggestedFilename: String,
            completionHandler: @escaping (URL?) -> Void
        ) {
            let destURL = Self.uniqueDownloadDestination(for: suggestedFilename)
            activeDownloads[ObjectIdentifier(download)] = destURL
            completionHandler(destURL)
        }

        func downloadDidFinish(_ download: WKDownload) {
            let key = ObjectIdentifier(download)
            guard let fileURL = activeDownloads.removeValue(forKey: key) else { return }
            DispatchQueue.main.async {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                self.parent.toastMessage = "Berkas tersimpan: \(fileURL.lastPathComponent)"
                self.parent.sharePayload = SharePayload(items: [fileURL])
            }
        }

        func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
            activeDownloads.removeValue(forKey: ObjectIdentifier(download))
            DispatchQueue.main.async {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                self.parent.toastMessage = "Gagal mengunduh berkas"
            }
        }

        private func saveExportedDataAndShare(data: Data, suggestedFilename: String) {
            let destURL = Self.uniqueDownloadDestination(for: suggestedFilename)
            do {
                try data.write(to: destURL, options: .atomic)
                DispatchQueue.main.async {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    self.parent.toastMessage = "Berkas tersimpan: \(destURL.lastPathComponent)"
                    self.parent.sharePayload = SharePayload(items: [destURL])
                }
            } catch {
                DispatchQueue.main.async {
                    self.parent.toastMessage = "Gagal menyimpan berkas"
                }
            }
        }

        private static func uniqueDownloadDestination(for suggestedFilename: String) -> URL {
            let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            let downloadsDir = docsDir.appendingPathComponent("Downloads", isDirectory: true)
            try? FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)

            let cleanName = suggestedFilename
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: ":", with: "_")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let finalName = cleanName.isEmpty ? "antigravity-file" : cleanName

            var candidate = downloadsDir.appendingPathComponent(finalName)
            let ext = candidate.pathExtension
            let stem = candidate.deletingPathExtension().lastPathComponent
            var counter = 1
            while FileManager.default.fileExists(atPath: candidate.path) {
                let numbered = ext.isEmpty ? "\(stem) (\(counter))" : "\(stem) (\(counter)).\(ext)"
                candidate = downloadsDir.appendingPathComponent(numbered)
                counter += 1
            }
            return candidate
        }
    }
}
