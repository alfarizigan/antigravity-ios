import SwiftUI

struct ContentView: View {
    @State private var progress: Double = 0.0
    @State private var isLoading: Bool = true
    @State private var canGoBack: Bool = false
    @State private var canGoForward: Bool = false
    @State private var reloadTrigger: Bool = false
    @State private var goBackTrigger: Bool = false
    @State private var goHomeTrigger: Bool = false
    @State private var externalURLToOpen: IdentifiableURL? = nil
    @State private var downloadedFileURL: IdentifiableURL? = nil

    var body: some View {
        ZStack(alignment: .top) {
            Color(red: 0.07, green: 0.08, blue: 0.10)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Slim Navigation Bar (only appears when user has navigated to subpages, pushes content naturally)
                if canGoBack {
                    HStack(spacing: 16) {
                        Button(action: {
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            goBackTrigger = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 15, weight: .bold))
                                Text("Kembali")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(Color(red: 0.26, green: 0.52, blue: 0.96))
                        }

                        Spacer()

                        Button(action: {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            goHomeTrigger = true
                        }) {
                            Image(systemName: "house.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color.white.opacity(0.85))
                        }

                        Button(action: {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            reloadTrigger = true
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color.white.opacity(0.85))
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 38)
                    .background(Color(red: 0.10, green: 0.12, blue: 0.16))
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.25), value: canGoBack)
                }

                // Progress Indicator
                if isLoading && progress < 1.0 {
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: Color(red: 0.26, green: 0.52, blue: 0.96)))
                        .frame(height: 2)
                        .transition(.opacity)
                }

                // Main Native WKWebView
                WebViewContainer(
                    progress: $progress,
                    isLoading: $isLoading,
                    canGoBack: $canGoBack,
                    canGoForward: $canGoForward,
                    reloadTrigger: $reloadTrigger,
                    goBackTrigger: $goBackTrigger,
                    goHomeTrigger: $goHomeTrigger,
                    externalURLToOpen: $externalURLToOpen,
                    downloadedFileURL: $downloadedFileURL
                )
                .ignoresSafeArea(.keyboard, edges: .bottom)
                .ignoresSafeArea(.all, edges: .bottom)
            }
        }
        // In-App Safari Sheet for external links with native Done button
        .sheet(item: $externalURLToOpen) { item in
            SafariView(url: item.url)
                .ignoresSafeArea()
        }
    }
}
