import Foundation
import SwiftUI

/// Zuletzt bekannter Guthabenstand, gecacht im App-Group-Container,
/// damit App und Widget denselben Stand anzeigen.
struct CreditSnapshot: Codable, Equatable {
    let balanceUSD: Double
    let fetchedAt: Date

    var formattedBalance: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = balanceUSD < 100 ? 2 : 0
        return formatter.string(from: NSNumber(value: balanceUSD)) ?? "$\(balanceUSD)"
    }

    /// Kompakte Darstellung für die Menüleiste, z. B. "$12.40".
    var compactBalance: String {
        if balanceUSD >= 1000 {
            return String(format: "$%.0f", balanceUSD)
        }
        return String(format: "$%.2f", balanceUSD)
    }

    var status: CreditStatus {
        if balanceUSD < AppConstants.criticalThreshold { return .critical }
        if balanceUSD < CreditCache.warningThreshold { return .low }
        return .healthy
    }
}

enum CreditStatus {
    case healthy, low, critical

    /// Warnstufe für die Benachrichtigungslogik.
    var rank: Int {
        switch self {
        case .healthy: 0
        case .low: 1
        case .critical: 2
        }
    }

    var tint: Color {
        switch self {
        case .healthy: .green
        case .low: .orange
        case .critical: .red
        }
    }
}

/// Cache im App-Group-UserDefaults: App schreibt, Widget liest (und umgekehrt).
enum CreditCache {
    private static let snapshotKey = "creditSnapshot"
    private static let warningThresholdKey = "warningThreshold"
    private static let refreshMinutesKey = "refreshMinutes"
    private static let showBalanceInMenuBarKey = "showBalanceInMenuBar"
    private static let languageKey = "appLanguage"
    private static let lastNotifiedRankKey = "lastNotifiedRank"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: AppConstants.appGroupID) ?? .standard
    }

    static func load() -> CreditSnapshot? {
        guard let data = defaults.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(CreditSnapshot.self, from: data)
    }

    static func save(_ snapshot: CreditSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
    }

    static var warningThreshold: Double {
        get {
            let value = defaults.double(forKey: warningThresholdKey)
            return value > 0 ? value : AppConstants.defaultWarningThreshold
        }
        set { defaults.set(newValue, forKey: warningThresholdKey) }
    }

    static var refreshMinutes: Int {
        get {
            let value = defaults.integer(forKey: refreshMinutesKey)
            return value > 0 ? value : AppConstants.defaultRefreshMinutes
        }
        set { defaults.set(newValue, forKey: refreshMinutesKey) }
    }

    /// Zuletzt gemeldete Warnstufe (0 = OK, 1 = niedrig, 2 = kritisch),
    /// damit Benachrichtigungen nur beim Verschlechtern ausgelöst werden.
    static var lastNotifiedRank: Int {
        get { defaults.integer(forKey: lastNotifiedRankKey) }
        set { defaults.set(newValue, forKey: lastNotifiedRankKey) }
    }

    static var language: AppLanguage {
        get {
            guard let raw = defaults.string(forKey: languageKey),
                  let lang = AppLanguage(rawValue: raw)
            else { return .system }
            return lang
        }
        set { defaults.set(newValue.rawValue, forKey: languageKey) }
    }

    static var showBalanceInMenuBar: Bool {
        get {
            if defaults.object(forKey: showBalanceInMenuBarKey) == nil { return true }
            return defaults.bool(forKey: showBalanceInMenuBarKey)
        }
        set { defaults.set(newValue, forKey: showBalanceInMenuBarKey) }
    }
}
