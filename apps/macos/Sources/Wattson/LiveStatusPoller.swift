import Foundation

@MainActor
final class LiveStatusPoller {
    var onUpdate: ((LiveStatus) -> Void)?
    var onError: ((String) -> Void)?

    private var credentials: StoredCredentials
    private let credentialStore: CredentialStore
    private var timer: Timer?
    private var cachedAccessToken: String?
    private var cachedAccessTokenExpiresAt: Date = .distantPast

    init(credentials: StoredCredentials, credentialStore: CredentialStore) {
        self.credentials = credentials
        self.credentialStore = credentialStore
    }

    func start() {
        tick()
        timer = Timer.scheduledTimer(withTimeInterval: Config.pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        cachedAccessToken = nil
        cachedAccessTokenExpiresAt = .distantPast
    }

    private func tick() {
        Task {
            do {
                let accessToken = try await freshAccessToken()
                let status = try await TeslaFleetClient.getLiveStatus(
                    energySiteId: credentials.energySiteId,
                    accessToken: accessToken
                )
                onUpdate?(status)
            } catch {
                onError?(error.localizedDescription)
            }
        }
    }

    private func freshAccessToken() async throws -> String {
        if let token = cachedAccessToken, Date() < cachedAccessTokenExpiresAt {
            return token
        }
        let tokens = try await TeslaFleetClient.refreshAccessToken(refreshToken: credentials.refreshToken)
        cachedAccessToken = tokens.accessToken
        cachedAccessTokenExpiresAt = Date().addingTimeInterval(TimeInterval(max(tokens.expiresIn - 60, 30)))
        if tokens.refreshToken != credentials.refreshToken {
            credentials = StoredCredentials(refreshToken: tokens.refreshToken, energySiteId: credentials.energySiteId)
            credentialStore.save(credentials)
        }
        return tokens.accessToken
    }
}
