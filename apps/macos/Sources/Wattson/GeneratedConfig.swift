/// Placeholder for the real Tesla client id. scripts/build-app.sh overwrites
/// this file with the actual value during a release build (--client-id) and
/// reverts it once the build finishes, so the real id never lingers in
/// git-tracked source.
enum GeneratedConfig {
    static let teslaClientId: String? = nil
}
