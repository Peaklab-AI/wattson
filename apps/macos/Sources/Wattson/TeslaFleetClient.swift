import Foundation

enum TeslaFleetClientError: LocalizedError {
    case requestFailed(status: Int, body: String)
    case noEnergySiteFound

    var errorDescription: String? {
        switch self {
        case .requestFailed(let status, let body):
            return "Tesla API request failed (\(status)): \(body)"
        case .noEnergySiteFound:
            return "No Powerwall energy site was found on this Tesla account"
        }
    }
}

enum TeslaFleetClient {
    static let authorizeURL = URL(string: "https://auth.tesla.com/oauth2/v3/authorize")!
    static let tokenURL = URL(string: "https://fleet-auth.prd.vn.cloud.tesla.com/oauth2/v3/token")!
    static let apiBaseURL = URL(string: "https://fleet-api.prd.na.vn.cloud.tesla.com")!
    static let scopes = ["openid", "offline_access", "energy_device_data"]

    static func buildAuthorizeURL(state: String) -> URL {
        var components = URLComponents(url: authorizeURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: Config.teslaClientId),
            URLQueryItem(name: "redirect_uri", value: Config.authCallbackURL.absoluteString),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scopes.joined(separator: " ")),
            URLQueryItem(name: "state", value: state),
        ]
        return components.url!
    }

    /// Refreshing does NOT require a client secret (confirmed against
    /// Tesla's docs), so this is safe to call directly from the app — only
    /// the initial code exchange needs apps/landing's /oauth/callback
    /// function, since only that step requires the secret.
    static func refreshAccessToken(refreshToken: String) async throws -> TeslaTokenResponse {
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formEncode([
            "grant_type": "refresh_token",
            "client_id": Config.teslaClientId,
            "refresh_token": refreshToken,
        ])
        return try await send(request)
    }

    static func getEnergySites(accessToken: String) async throws -> [EnergySiteSummary] {
        let raw: [RawProduct] = try await get("/api/1/products", accessToken: accessToken)
        return raw.compactMap { $0.energySiteId }.map(EnergySiteSummary.init)
    }

    static func getLiveStatus(energySiteId: Int, accessToken: String) async throws -> LiveStatus {
        try await get("/api/1/energy_sites/\(energySiteId)/live_status", accessToken: accessToken)
    }

    private static func get<T: Decodable>(_ path: String, accessToken: String) async throws -> T {
        var request = URLRequest(url: apiBaseURL.appendingPathComponent(path))
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return try await send(request)
    }

    private static func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw TeslaFleetClientError.requestFailed(status: status, body: String(data: data, encoding: .utf8) ?? "")
        }
        if let envelope = try? JSONDecoder().decode(FleetAPIEnvelope<T>.self, from: data) {
            return envelope.response
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private static func formEncode(_ params: [String: String]) -> Data {
        let allowed = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: "&="))
        return params
            .map { "\($0)=\($1.addingPercentEncoding(withAllowedCharacters: allowed) ?? $1)" }
            .joined(separator: "&")
            .data(using: .utf8)!
    }
}
