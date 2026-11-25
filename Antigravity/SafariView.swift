import SwiftUI
import SafariServices
import WebKit
import UIKit

struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

struct SharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
}

final class PopupWebItem: ObservableObject, Identifiable {
    let id = UUID()
    let webView: WKWebView
    @Published var title: String
    @Published var host: String
    @Published var progress: Double = 0.1

    private var titleObs: NSKeyValueObservation?
    private var urlObs: NSKeyValueObservation?
    private var progObs: NSKeyValueObservation?

    init(webView: WKWebView, initialURL: URL?) {
        self.webView = webView
        self.title = "Otentikasi"
        self.host = initialURL?.host ?? "antigravity.google.com"

        titleObs = webView.observe(\.title, options: [.new]) { [weak self] wv, _ in
            DispatchQueue.main.async {
                if let t = wv.title, !t.isEmpty {
                    self?.title = t
                }
            }
        }
        urlObs = webView.observe(\.url, options: [.new]) { [weak self] wv, _ in
            DispatchQueue.main.async {
                if let h = wv.url?.host, !h.isEmpty {
                    self?.host = h
                }
            }
        }
        progObs = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] wv, _ in
            DispatchQueue.main.async {
                self?.progress = wv.estimatedProgress
            }
        }
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let safeURL: URL = {
            let scheme = url.scheme?.lowercased() ?? ""
            if scheme == "http" || scheme == "https" {
                return url
            }
            return URL(string: CookieManager.defaultAppURLString)!
        }()
        let configuration = SFSafariViewController.Configuration()
        configuration.entersReaderIfAvailable = false
        configuration.barCollapsingEnabled = true
        let safariVC = SFSafariViewController(url: safeURL, configuration: configuration)
        safariVC.preferredBarTintColor = UIColor(red: 31/255, green: 31/255, blue: 31/255, alpha: 1.0)
        safariVC.preferredControlTintColor = UIColor(red: 0.35, green: 0.62, blue: 1.0, alpha: 1.0)
        safariVC.dismissButtonStyle = .done
        return safariVC
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct HostedWebViewRepresentable: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView {
        webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

struct PopupWebViewModal: View {
    @ObservedObject var item: PopupWebItem
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: onClose) {
                    Text("Selesai")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(red: 0.35, green: 0.62, blue: 1.0))
                }

                Spacer()

                HStack(spacing: 5) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.green.opacity(0.85))
                    Text(item.host)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(1)
                }

                Spacer()

                Button(action: {
                    item.webView.reload()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 46)
            .background(Color(red: 31/255, green: 31/255, blue: 31/255))

            if item.progress < 1.0 {
                ProgressView(value: item.progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: Color(red: 0.35, green: 0.62, blue: 1.0)))
                    .frame(height: 2)
            }

            HostedWebViewRepresentable(webView: item.webView)
                .ignoresSafeArea(.container, edges: .bottom)
        }
        .background(Color(red: 31/255, green: 31/255, blue: 31/255))
        .preferredColorScheme(.dark)
    }
}
