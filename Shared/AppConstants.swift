import Foundation

enum AppConstants {
    /// App Group, geteilt zwischen App und Widget-Extension (Team-ID-Präfix für macOS).
    static let appGroupID = "RSH2E2EZUM.com.janjezek.kilocodecredits"
    /// Keychain Access Group für das geteilte API-Token.
    static let keychainAccessGroup = "RSH2E2EZUM.com.janjezek.kilocodecredits"

    /// Profilseite mit Guthaben und "Add credits" (kilocode.ai wurde zu kilo.ai).
    static let profileURL = URL(string: "https://app.kilo.ai/profile")!
    static let apiBaseURL = URL(string: "https://api.kilo.ai/api")!
    static let coffeeURL = URL(string: "https://buymeacoffee.com/exocode")!

    /// Schwelle in USD, unter der das Guthaben als "niedrig" (gelb) gilt.
    static let defaultWarningThreshold: Double = 5.0
    /// Schwelle in USD, unter der das Guthaben als "kritisch" (rot) gilt.
    static let criticalThreshold: Double = 1.0

    static let defaultRefreshMinutes = 15
    static let refreshChoicesMinutes = [1, 5, 10, 15, 30, 60]

    /// Zeitfenster für die Burn-Rate-Berechnung (Tacho/Pfeil).
    static let defaultBurnWindowMinutes = 60
    static let burnWindowChoicesMinutes = [5, 15, 30, 60, 360]

    /// Momentanverbrauch (innerer Tacho): festes Kurzfenster.
    static let spotWindowMinutes = 10
    /// Spike-Alarm: Momentanwert liegt um diesen Faktor über dem Fenster-
    /// Durchschnitt und mindestens über dem absoluten Boden.
    static let spikeFactor = 2.5
    static let spikeFloorPerHour = 3.0
}
