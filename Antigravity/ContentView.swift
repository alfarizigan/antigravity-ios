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

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(red: 0.07, green: 0.08, blue: 0.10)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Loading Progress Bar
                if isLoading && progress < 1.0 {
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: Color(red: 0.26, green: 0.52, blue: 0.96)))
                        .frame(height: 2)
                        .transition(.opacity)
                }

                // Native WKWebView
                WebViewContainer(
                    progress: $progress,
                    isLoading: $isLoading,
                    canGoBack: $canGoBack,
                    canGoForward: $canGoForward,
                    reloadTrigger: $reloadTrigger,
                    goBackTrigger: $goBackTrigger,
                    goHomeTrigger: $goHomeTrigger,
                    externalURLToOpen: $externalURLToOpen
                )
                .ignoresSafeArea(.all, edges: .bottom)
            }

            // Floating Smart Back Button (appears whenever user has navigated to another page)
            if canGoBack {
                HStack(spacing: 8) {
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        goBackTrigger = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .bold))
                            Text("Kembali")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(Color(red: 0.12, green: 0.15, blue: 0.22).opacity(0.92))
                                .overlay(
                                    Capsule()
                                        .stroke(Color(red: 0.26, green: 0.52, blue: 0.96).opacity(0.6), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 3)
                        )
                    }

                    // Home Button to quickly return to main Antigravity instance
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        goHomeTrigger = true
                    }) {
                        Image(systemName: "house.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(
                                Circle()
                                    .fill(Color(red: 0.12, green: 0.15, blue: 0.22).opacity(0.92))
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                                    .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 3)
                            )
                    }
                }
                .padding(.top, 52) // positioned just below the iPhone 11 notch
                .padding(.leading, 14)
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .opacity
                ))
                .animation(.spring(response: 0.35, dampingFraction: 0.75), value: canGoBack)
            }
        }
        // In-app Safari sheet for external links with native Done button
        .sheet(item: $externalURLToOpen) { item in
            SafariView(url: item.url)
                .ignoresSafeArea()
        }
    }
}
