import AppKit
import Foundation

enum AuthFlowError: LocalizedError {
    case invalidCallback
    case sessionFetchFailed

    var errorDescription: String? {
        switch self {
        case .invalidCallback: return "Received an unexpected callback URL"
        case .sessionFetchFailed: return "Could not complete Tesla login"
        }
    }
}

enum AuthFlow {
    static func startLogin() {
        let state = UUID().uuidString
        NSWorkspace.shared.open(TeslaFleetClient.buildAuthorizeURL(state: state))
    }

    /// Called once macOS delivers the wattson://auth-success?session=...
    /// redirect that apps/landing's /oauth/callback function sends the
    /// browser to after it exchanges the code for tokens.
    static func handleCallback(url: URL) async throws -> StoredCredentials {
        guard url.scheme == Config.protocolScheme, url.host == "auth-success",
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let sessionId = components.queryItems?.first(where: { $0.name == "session" })?.value
        else {
            throw AuthFlowError.invalidCallback
        }

        let (data, response) = try await URLSession.shared.data(from: Config.sessionURL(sessionId))
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AuthFlowError.sessionFetchFailed
        }
        let tokens = try JSONDecoder().decode(TeslaTokenResponse.self, from: data)

        let sites = try await TeslaFleetClient.getEnergySites(accessToken: tokens.accessToken)
        guard let site = sites.first else {
            throw TeslaFleetClientError.noEnergySiteFound
        }

        return StoredCredentials(refreshToken: tokens.refreshToken, energySiteId: site.energySiteId)
    }
}
