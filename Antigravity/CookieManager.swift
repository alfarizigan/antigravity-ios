import Foundation
import WebKit
import UIKit

final class CookieManager: NSObject, WKHTTPCookieStoreObserver {
    static let shared = CookieManager()
    static let defaultAppURLString = "https://antigravity.google.com"

    private let cookiesKey = "SavedAntigravityCookies_v3"
    private let legacyCookiesKey = "SavedAntigravityCookies_v2"
    private let lastURLKey = "SavedLastVisitedURL_v3"
    private let legacyLastURLKey = "SavedLastVisitedURL_v2"

    private weak var currentCookieStore: WKHTTPCookieStore?
    private var debounceWorkItem: DispatchWorkItem?

    private override init() {
        super.init()
        let nc = NotificationCenter.default
        nc.addObserver(
            self,
            selector: #selector(handleAppLifecycleFlush),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        nc.addObserver(
            self,
            selector: #selector(handleAppLifecycleFlush),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        nc.addObserver(
            self,
            selector: #selector(handleAppLifecycleFlush),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }

    func setupObserver(for cookieStore: WKHTTPCookieStore) {
        if currentCookieStore !== cookieStore {
            currentCookieStore = cookieStore
            cookieStore.add(self)
        }
    }

    func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        scheduleDebouncedSave(from: cookieStore)
    }

    @objc private func handleAppLifecycleFlush() {
        flushImmediately()
    }

    func flushImmediately() {
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
        guard let store = currentCookieStore else { return }
        var bgTask: UIBackgroundTaskIdentifier = .invalid
        bgTask = UIApplication.shared.beginBackgroundTask(withName: "CookieFlush") {
            if bgTask != .invalid {
                UIApplication.shared.endBackgroundTask(bgTask)
                bgTask = .invalid
            }
        }
        persistCookies(from: store) {
            if bgTask != .invalid {
                UIApplication.shared.endBackgroundTask(bgTask)
                bgTask = .invalid
            }
        }
    }

    private func scheduleDebouncedSave(from cookieStore: WKHTTPCookieStore) {
        debounceWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self, weak cookieStore] in
            guard let self = self, let store = cookieStore else { return }
            self.persistCookies(from: store, completion: nil)
        }
        debounceWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75, execute: work)
    }

    private func persistCookies(from cookieStore: WKHTTPCookieStore, completion: (() -> Void)?) {
        cookieStore.getAllCookies { [weak self] cookies in
            guard let self = self else {
                completion?()
                return
            }
            var serialized: [[String: Any]] = []
            serialized.reserveCapacity(cookies.count)

            let oneYearFromNow = Date().addingTimeInterval(365 * 24 * 3600)
            for cookie in cookies {
                var props: [String: Any] = [
                    HTTPCookiePropertyKey.name.rawValue: cookie.name,
                    HTTPCookiePropertyKey.value.rawValue: cookie.value,
                    HTTPCookiePropertyKey.domain.rawValue: cookie.domain,
                    HTTPCookiePropertyKey.path.rawValue: cookie.path,
                    HTTPCookiePropertyKey.version.rawValue: String(cookie.version)
                ]
                if cookie.isSecure {
                    props[HTTPCookiePropertyKey.secure.rawValue] = "TRUE"
                }
                if cookie.isHTTPOnly {
                    props["HttpOnly"] = "TRUE"
                }
                if let sameSite = cookie.sameSitePolicy {
                    props[HTTPCookiePropertyKey.sameSitePolicy.rawValue] = sameSite.rawValue
                }
                // Promote session cookies to persistent cookies so force-close never logs out
                if let expiresDate = cookie.expiresDate {
                    props[HTTPCookiePropertyKey.expires.rawValue] = expiresDate
                } else {
                    props[HTTPCookiePropertyKey.expires.rawValue] = oneYearFromNow
                }
                serialized.append(props)
            }

            UserDefaults.standard.set(serialized, forKey: self.cookiesKey)
            completion?()
        }
    }

    func restoreCookies(into cookieStore: WKHTTPCookieStore, completion: @escaping () -> Void) {
        let defaults = UserDefaults.standard
        let savedCookies = (defaults.array(forKey: cookiesKey) as? [[String: Any]])
            ?? (defaults.array(forKey: legacyCookiesKey) as? [[String: Any]])

        guard let cookieDicts = savedCookies, !cookieDicts.isEmpty else {
            completion()
            return
        }

        let now = Date()
        let group = DispatchGroup()

        for cookieProps in cookieDicts {
            if let exp = cookieProps[HTTPCookiePropertyKey.expires.rawValue] as? Date, exp <= now {
                continue
            }
            var converted: [HTTPCookiePropertyKey: Any] = [:]
            for (k, v) in cookieProps {
                converted[HTTPCookiePropertyKey(rawValue: k)] = v
            }
            if let cookie = HTTPCookie(properties: converted) {
                group.enter()
                cookieStore.setCookie(cookie) {
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) {
            completion()
        }
    }

    func saveLastVisitedURL(_ url: URL) {
        guard let scheme = url.scheme?.lowercased(), scheme == "https",
              let host = url.host?.lowercased() else {
            return
        }
        // Only persist genuine Antigravity Web App URLs (antigravity.google.com),
        // never overwrite with marketing pages (antigravity.google) or OAuth login redirects
        let isWebAppHost = (host == "antigravity.google.com" || host.hasSuffix(".antigravity.google.com"))
        let pathLower = url.path.lowercased()
        let isAuthRoute = pathLower.hasPrefix("/logout") || pathLower.hasPrefix("/signin") || pathLower.hasPrefix("/_/")
        if isWebAppHost && !isAuthRoute {
            UserDefaults.standard.set(url.absoluteString, forKey: lastURLKey)
        }
    }

    func getInitialURL() -> URL {
        let defaults = UserDefaults.standard
        if let savedStr = defaults.string(forKey: lastURLKey) ?? defaults.string(forKey: legacyLastURLKey),
           let savedURL = URL(string: savedStr),
           let host = savedURL.host?.lowercased(),
           (host == "antigravity.google.com" || host.hasSuffix(".antigravity.google.com")) {
            return savedURL
        }
        return URL(string: Self.defaultAppURLString)!
    }

    func clearSavedURL() {
        UserDefaults.standard.removeObject(forKey: lastURLKey)
        UserDefaults.standard.removeObject(forKey: legacyLastURLKey)
    }
}
