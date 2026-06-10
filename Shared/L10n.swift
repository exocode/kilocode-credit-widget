import Foundation

/// App-Sprache: live umschaltbar, im App-Group-Container gespeichert,
/// damit das Widget dieselbe Sprache nutzt.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case german = "de"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: "System"
        case .english: "English"
        case .german: "Deutsch"
        }
    }

    /// Aufgelöste Übersetzungstabelle (System folgt der bevorzugten Sprache).
    var table: L10nTable {
        switch self {
        case .english: .en
        case .german: .de
        case .system:
            Locale.preferredLanguages.first?.hasPrefix("de") == true ? .de : .en
        }
    }
}

enum L10n {
    /// Aktuell wirksame Tabelle (App und Widget).
    static var current: L10nTable {
        CreditCache.language.table
    }
}

struct L10nTable {
    // Menüleiste / Popover
    let refreshNow: String
    let statusHealthy: String
    let statusLow: String
    let statusCritical: String
    let updatedAt: String
    let loadingBalance: String
    let addCredits: String
    let settings: String
    let quit: String

    // Setup / Anmeldung
    let connectTitle: String
    let connectBody: String
    let signInWithBrowser: String
    let waitingForBrowser: String
    let codeLabel: String
    let cancel: String
    let manualEntryTitle: String
    let manualEntryHint: String
    let pasteAPIKey: String
    let save: String

    // Einstellungen
    let refreshEvery: String
    let minutesSuffix: String
    let showBalanceInMenuBar: String
    let launchAtLogin: String
    let warningThreshold: String
    let language: String
    let removeToken: String

    // Fehler
    let invalidResponse: String
    let unauthorized: String
    let serverError: String  // mit %d
    let unexpectedPayload: String
    let signInDenied: String
    let signInExpired: String
    let keychainError: String  // mit %d

    // Widget
    let widgetDescription: String
    let widgetSetupHint: String
    let widgetNoData: String
    let widgetTopUp: String

    func statusLabel(_ status: CreditStatus) -> String {
        switch status {
        case .healthy: statusHealthy
        case .low: statusLow
        case .critical: statusCritical
        }
    }

    static let en = L10nTable(
        refreshNow: "Refresh now",
        statusHealthy: "Balance OK",
        statusLow: "Balance low",
        statusCritical: "Balance almost depleted",
        updatedAt: "Updated:",
        loadingBalance: "Loading balance …",
        addCredits: "Add credits",
        settings: "Settings",
        quit: "Quit",
        connectTitle: "Connect Kilo Code",
        connectBody: "Sign in with your Kilo account to fetch your balance.",
        signInWithBrowser: "Sign in with browser",
        waitingForBrowser: "Waiting for approval in browser …",
        codeLabel: "Code",
        cancel: "Cancel",
        manualEntryTitle: "Enter API key manually",
        manualEntryHint: "You'll find the key at the bottom of app.kilo.ai/profile.",
        pasteAPIKey: "Paste API key",
        save: "Save",
        refreshEvery: "Refresh every",
        minutesSuffix: "min",
        showBalanceInMenuBar: "Show balance in menu bar",
        launchAtLogin: "Launch at login",
        warningThreshold: "Warning threshold",
        language: "Language",
        removeToken: "Remove token",
        invalidResponse: "Invalid server response",
        unauthorized: "Token invalid or expired",
        serverError: "Server error (HTTP %d)",
        unexpectedPayload: "Unexpected response format",
        signInDenied: "Sign-in was denied",
        signInExpired: "Sign-in expired, please try again",
        keychainError: "Keychain error (%d)",
        widgetDescription: "Shows your remaining Kilo Code credits.",
        widgetSetupHint: "Open Kilocode Credits and sign in",
        widgetNoData: "No data yet",
        widgetTopUp: "Top up"
    )

    static let de = L10nTable(
        refreshNow: "Jetzt aktualisieren",
        statusHealthy: "Guthaben OK",
        statusLow: "Guthaben niedrig",
        statusCritical: "Guthaben fast aufgebraucht",
        updatedAt: "Stand:",
        loadingBalance: "Lade Guthaben …",
        addCredits: "Credits aufladen",
        settings: "Einstellungen",
        quit: "Beenden",
        connectTitle: "Kilo Code verbinden",
        connectBody: "Melde dich mit deinem Kilo-Account an, um dein Guthaben abzurufen.",
        signInWithBrowser: "Mit Browser anmelden",
        waitingForBrowser: "Warte auf Freigabe im Browser …",
        codeLabel: "Code",
        cancel: "Abbrechen",
        manualEntryTitle: "API-Key manuell eingeben",
        manualEntryHint: "Den Key findest du unten auf app.kilo.ai/profile.",
        pasteAPIKey: "API-Key einfügen",
        save: "Speichern",
        refreshEvery: "Aktualisieren alle",
        minutesSuffix: "Min.",
        showBalanceInMenuBar: "Guthaben in Menüleiste anzeigen",
        launchAtLogin: "Bei Anmeldung starten",
        warningThreshold: "Warnschwelle",
        language: "Sprache",
        removeToken: "Token entfernen",
        invalidResponse: "Ungültige Antwort vom Server",
        unauthorized: "Token ungültig oder abgelaufen",
        serverError: "Serverfehler (HTTP %d)",
        unexpectedPayload: "Antwortformat nicht erkannt",
        signInDenied: "Anmeldung wurde abgelehnt",
        signInExpired: "Anmeldung abgelaufen, bitte erneut versuchen",
        keychainError: "Keychain-Fehler (%d)",
        widgetDescription: "Zeigt dein verbleibendes Kilo-Code-Guthaben.",
        widgetSetupHint: "Kilocode Credits öffnen und anmelden",
        widgetNoData: "Noch keine Daten",
        widgetTopUp: "Aufladen"
    )
}
