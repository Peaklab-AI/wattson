import Foundation

/// Client id and backend URL identify *this app* to Tesla and are baked in
/// at build time (every user shares them) — they're not secrets, unlike the
/// client_secret, which never leaves apps/landing's server functions.
/// The env var below only exists to make local development easier; a
/// shipped build gets its client id baked into GeneratedConfig.swift by
/// scripts/build-app.sh --client-id, so the real value never sits in
/// git-tracked source.
enum Config {
    static let protocolScheme = "wattson"

    static let teslaClientId: String = {
        if let fromEnv = ProcessInfo.processInfo.environment["WATTSON_TESLA_CLIENT_ID"] {
            return fromEnv
        }
        guard let baked = GeneratedConfig.teslaClientId else {
            fatalError(
                "No Tesla client id configured — set WATTSON_TESLA_CLIENT_ID for local development, "
                    + "or build a release with scripts/build-app.sh --client-id <id>."
            )
        }
        return baked
    }()

    static let authCallbackBaseURL: URL = {
        let raw = ProcessInfo.processInfo.environment["WATTSON_AUTH_CALLBACK_URL"] ?? "https://wattson.peaklab.ai"
        guard let url = URL(string: raw) else {
            fatalError("WATTSON_AUTH_CALLBACK_URL is not a valid URL: \(raw)")
        }
        return url
    }()

    static let pollInterval: TimeInterval = {
        guard let raw = ProcessInfo.processInfo.environment["WATTSON_POLL_INTERVAL_MS"],
              let ms = Double(raw) else {
            return 30
        }
        return ms / 1000
    }()

    // All Tesla-related endpoints live under /oauth on the backend, keeping
    // the rest of the domain free for the Wattson landing page.
    static var authCallbackURL: URL {
        authCallbackBaseURL.appendingPathComponent("oauth").appendingPathComponent("callback")
    }

    static func sessionURL(_ sessionId: String) -> URL {
        let base = authCallbackBaseURL.appendingPathComponent("oauth").appendingPathComponent("session")
        var components = URLComponents(url: base, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "session", value: sessionId)]
        return components.url!
    }
}
