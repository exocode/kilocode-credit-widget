import Foundation

/// Speichert das Kilocode-API-Token im geteilten App-Group-Container, damit App
/// und Widget-Extension darauf zugreifen können.
///
/// Bewusst App Group statt geteilter Keychain Access Group: Eine geteilte
/// Keychain-Gruppe (`keychain-access-groups`) ist ein profilpflichtiges
/// Entitlement. Unter Developer-ID-Signierung ohne eingebettetes
/// Provisioning-Profil verweigert macOS sonst den Sandbox-Start der App
/// ("Launchd job spawn failed" / SIGKILL). Der App-Group-Container ist pro
/// Benutzer geschützt und kommt ohne Profil aus.
enum TokenStore {
    private static let tokenKey = "kilocode-api-token"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: AppConstants.appGroupID) ?? .standard
    }

    static func load() -> String? {
        guard let token = defaults.string(forKey: tokenKey), !token.isEmpty else {
            return nil
        }
        return token
    }

    /// `throws` bleibt aus API-Kompatibilität erhalten (Aufrufer nutzen `try`/catch);
    /// das Schreiben in den App-Group-Store kann aktuell nicht fehlschlagen.
    static func save(_ token: String) throws {
        defaults.set(token, forKey: tokenKey)
    }

    static func delete() {
        defaults.removeObject(forKey: tokenKey)
    }
}
