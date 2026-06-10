import Foundation

enum AppConstants {
    /// App Group, geteilt zwischen App und Widget-Extension (Team-ID-Präfix für macOS).
    static let appGroupID = "RSH2E2EZUM.com.janjezek.kilocodecredits"
    /// Keychain Access Group für das geteilte API-Token.
    static let keychainAccessGroup = "RSH2E2EZUM.com.janjezek.kilocodecredits"

    /// Profilseite mit Guthaben und "Add credits" (kilocode.ai wurde zu kilo.ai).
    static let profileURL = URL(string: "https://app.kilo.ai/profile")!
    static let apiBaseURL = URL(string: "https://api.kilo.ai/api")!

    /// Schwelle in USD, unter der das Guthaben als "niedrig" (gelb) gilt.
    static let defaultWarningThreshold: Double = 5.0
    /// Schwelle in USD, unter der das Guthaben als "kritisch" (rot) gilt.
    static let criticalThreshold: Double = 1.0

    static let defaultRefreshMinutes = 15
    static let refreshChoicesMinutes = [5, 10, 15, 30, 60]
}
