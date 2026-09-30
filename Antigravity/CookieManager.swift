import Foundation
import WebKit
import UIKit

class CookieManager: NSObject, WKHTTPCookieStoreObserver {
    static let shared = CookieManager()
    private let cookiesKey = "SavedAntigravityCookies_v2"
    private let lastURLKey = "SavedLastVisitedURL_v2"
    private let defaultRootURL = "https://antigravity.google"
    private weak var currentCookieStore: WKHTTPCookieStore?

    private override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }

    func setupObserver(for cookieStore: WKHTTPCookieStore) {
        self.currentCookieStore = cookieStore
        cookieStore.add(self)
    }

    func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        saveCookies(from: cookieStore)
    }

    @objc private func handleAppBackground() {
        if let store = currentCookieStore {
            saveCookies(from: store)
        }
    }

    func saveCookies(from cookieStore: WKHTTPCookieStore) {
        cookieStore.getAllCookies { cookies in
            var cookiesData: [[String: Any]] = []
            for cookie in cookies {
                var props: [String: Any] = [:]
                props[HTTPCookiePropertyKey.name.rawValue] = cookie.name
                props[HTTPCookiePropertyKey.value.rawValue] = cookie.value
                props[HTTPCookiePropertyKey.domain.rawValue] = cookie.domain
                props[HTTPCookiePropertyKey.path.rawValue] = cookie.path
                if cookie.isSecure {
                    props[HTTPCookiePropertyKey.secure.rawValue] = "TRUE"
                }
                // Convert session cookies to persistent cookies with 1 year expiration
                if let expiresDate = cookie.expiresDate {
                    props[HTTPCookiePropertyKey.expires.rawValue] = expiresDate
                } else {
                    props[HTTPCookiePropertyKey.expires.rawValue] = Date().addingTimeInterval(365 * 24 * 3600)
                }
                cookiesData.append(props)
            }
            UserDefaults.standard.set(cookiesData, forKey: self.cookiesKey)
            UserDefaults.standard.synchronize()
        }
    }

    func restoreCookies(into cookieStore: WKHTTPCookieStore, completion: @escaping () -> Void) {
        guard let savedCookies = UserDefaults.standard.array(forKey: cookiesKey) as? [[String: Any]], !savedCookies.isEmpty else {
            completion()
            return
        }

        let group = DispatchGroup()
        for cookieProps in savedCookies {
            var convertedProps: [HTTPCookiePropertyKey: Any] = [:]
            for (k, v) in cookieProps {
                convertedProps[HTTPCookiePropertyKey(rawValue: k)] = v
            }
            if let cookie = HTTPCookie(properties: convertedProps) {
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
        guard let host = url.host?.lowercased() else { return }
        // Save antigravity application URLs, skip external domains or oauth login pages
        if host.contains("antigravity.google") && !host.contains("accounts.google") {
            UserDefaults.standard.set(url.absoluteString, forKey: lastURLKey)
            UserDefaults.standard.synchronize()
        }
    }

    func getInitialURL() -> URL {
        if let savedStr = UserDefaults.standard.string(forKey: lastURLKey),
           let savedURL = URL(string: savedStr),
           let host = savedURL.host?.lowercased(),
           host.contains("antigravity.google") {
            return savedURL
        }
        return URL(string: defaultRootURL)!
    }

    func clearSavedURL() {
        UserDefaults.standard.removeObject(forKey: lastURLKey)
        UserDefaults.standard.synchronize()
    }
}
