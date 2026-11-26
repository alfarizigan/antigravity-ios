import SwiftUI
import UIKit

struct ContentView: View {
    @State private var progress: Double = 0.0
    @State private var isLoading: Bool = true
    @State private var isInitialBootLoading: Bool = true
    @State private var canGoBack: Bool = false
    @State private var canGoForward: Bool = false
    @State private var isQuickBarExpanded: Bool = false
    @State private var currentURL: URL? = nil
    @State private var networkErrorMessage: String? = nil

    @State private var reloadTrigger: Bool = false
    @State private var goBackTrigger: Bool = false
    @State private var goForwardTrigger: Bool = false
    @State private var goHomeTrigger: Bool = false

    @State private var externalURLToOpen: IdentifiableURL? = nil
    @State private var popupWebItem: PopupWebItem? = nil
    @State private var sharePayload: SharePayload? = nil
    @State private var toastMessage: String? = nil

    private let surfaceColor = Color(red: 31/255, green: 31/255, blue: 31/255)
    private let barColor = Color(red: 24/255, green: 24/255, blue: 27/255)
    private let accentBlue = Color(red: 0.35, green: 0.62, blue: 1.0)

    private var showTopBar: Bool {
        canGoBack || isQuickBarExpanded
    }

    var body: some View {
        ZStack(alignment: .top) {
            surfaceColor
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Slim Adaptive Navigation Bar (auto-appears on subpages, or toggleable anytime via subtle top handle)
                if showTopBar {
                    HStack(spacing: 16) {
                        if canGoBack {
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                goBackTrigger = true
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 15, weight: .bold))
                                    Text("Kembali")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .foregroundColor(accentBlue)
                            }
                        } else {
                            Text("Antigravity")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.75))
                        }

                        if canGoForward {
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                goForwardTrigger = true
                            }) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.85))
                            }
                        }

                        Spacer()

                        if let activeURL = currentURL {
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                sharePayload = SharePayload(items: [activeURL])
                            }) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.85))
                            }
                        }

                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            goHomeTrigger = true
                        }) {
                            Image(systemName: "house.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white.opacity(0.85))
                        }

                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            reloadTrigger = true
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white.opacity(0.85))
                        }

                        if !canGoBack {
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isQuickBarExpanded = false
                                }
                            }) {
                                Image(systemName: "chevron.up")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white.opacity(0.65))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 38)
                    .background(barColor)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.22), value: showTopBar)
                }

                // Smooth Progress Bar
                if isLoading && progress < 1.0 && !isInitialBootLoading {
                    ProgressView(value: max(0.05, progress))
                        .progressViewStyle(LinearProgressViewStyle(tint: accentBlue))
                        .frame(height: 2)
                        .transition(.opacity)
                }

                // Main Native WKWebView
                WebViewContainer(
                    progress: $progress,
                    isLoading: $isLoading,
                    isInitialBootLoading: $isInitialBootLoading,
                    canGoBack: $canGoBack,
                    canGoForward: $canGoForward,
                    currentURL: $currentURL,
                    networkErrorMessage: $networkErrorMessage,
                    reloadTrigger: $reloadTrigger,
                    goBackTrigger: $goBackTrigger,
                    goForwardTrigger: $goForwardTrigger,
                    goHomeTrigger: $goHomeTrigger,
                    externalURLToOpen: $externalURLToOpen,
                    popupWebItem: $popupWebItem,
                    sharePayload: $sharePayload,
                    toastMessage: $toastMessage
                )
                .ignoresSafeArea(.keyboard)
                .ignoresSafeArea(.container, edges: .bottom)
            }

            // Ultra-subtle top-center capsule handle when bar is hidden (0 layout height, gives 1-tap Reload/Home/Share anytime)
            if !showTopBar && !isInitialBootLoading && networkErrorMessage == nil {
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isQuickBarExpanded = true
                    }
                }) {
                    Capsule()
                        .fill(Color.white.opacity(0.22))
                        .frame(width: 34, height: 4)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 14)
                        .contentShape(Rectangle())
                }
                .padding(.top, 1)
            }

            // Offline / Connection Error Card
            if let errorMsg = networkErrorMessage {
                VStack(spacing: 18) {
                    Spacer()
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 44, weight: .medium))
                        .foregroundColor(accentBlue)
                    Text("Koneksi Terputus")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    Text(errorMsg)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.72))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        reloadTrigger = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                            Text("Muat Ulang")
                                .fontWeight(.semibold)
                        }
                        .font(.system(size: 15))
                        .foregroundColor(.black)
                        .padding(.horizontal, 26)
                        .padding(.vertical, 12)
                        .background(accentBlue)
                        .clipShape(Capsule())
                    }
                    .padding(.top, 4)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(surfaceColor.ignoresSafeArea())
                .transition(.opacity)
            }

            // Branded Cold-Boot Splash Overlay
            if isInitialBootLoading {
                VStack(spacing: 20) {
                    Spacer()
                    Image("SplashLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 88, height: 88)
                    Text("Google Antigravity")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.92))
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: accentBlue))
                        .scaleEffect(0.95)
                        .padding(.top, 4)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(surfaceColor.ignoresSafeArea())
                .allowsHitTesting(false)
                .transition(.opacity)
            }

            // Subtle Toast Banner for File Downloads
            if let msg = toastMessage {
                Text(msg)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.85))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1))
                    .padding(.top, showTopBar ? 46 : 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
                            withAnimation {
                                toastMessage = nil
                            }
                        }
                    }
            }
        }
        .ignoresSafeArea(.keyboard)
        .sheet(item: $externalURLToOpen) { item in
            SafariView(url: item.url)
                .ignoresSafeArea()
        }
        .sheet(item: $popupWebItem) { item in
            PopupWebViewModal(item: item) {
                popupWebItem = nil
            }
        }
        .sheet(item: $sharePayload) { payload in
            ActivityShareSheet(items: payload.items)
        }
    }
}
