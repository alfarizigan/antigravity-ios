import SwiftUI

struct ContentView: View {
    @State private var targetURL: URL = URL(string: "https://antigravity.google")!
    @State private var progress: Double = 0.0
    @State private var isLoading: Bool = true
    @State private var canGoBack: Bool = false
    @State private var canGoForward: Bool = false
    @State private var reloadTrigger: Bool = false

    var body: some View {
        ZStack(alignment: .top) {
            Color(red: 0.07, green: 0.08, blue: 0.10)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if isLoading && progress < 1.0 {
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: Color(red: 0.26, green: 0.52, blue: 0.96)))
                        .frame(height: 2)
                        .transition(.opacity)
                }

                WebViewContainer(
                    url: targetURL,
                    progress: $progress,
                    isLoading: $isLoading,
                    canGoBack: $canGoBack,
                    canGoForward: $canGoForward,
                    reloadTrigger: $reloadTrigger
                )
                .ignoresSafeArea(.all, edges: .bottom)
            }
        }
    }
}
