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

    /// Kompakte Darstellung für die Menüleiste, z. B. "$12.40" bzw. "$12".
    func compactBalance(showCents: Bool) -> String {
        if !showCents || balanceUSD >= 1000 {
            return String(format: "$%.0f", balanceUSD.rounded())
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

/// Verbrauchs-Trend ("Torque-Indikator"): Pfeilrichtung wie eine Tachonadel,
/// von steil aufwärts (kaum Verbrauch) bis steil abwärts (hoher Verbrauch).
enum BurnTrend {
    case rising      // Guthaben gestiegen (Aufladung)
    case idle        // praktisch kein Verbrauch
    case slow        // < 1 $/h
    case moderate    // 1-5 $/h
    case fast        // >= 5 $/h

    init(ratePerHour: Double) {
        switch ratePerHour {
        case ..<(-0.01): self = .rising
        case ..<0.05: self = .idle
        case ..<1.0: self = .slow
        case ..<5.0: self = .moderate
        default: self = .fast
        }
    }

    var symbol: String {
        switch self {
        case .rising: "arrow.up"
        case .idle: "arrow.up.right"
        case .slow: "arrow.right"
        case .moderate: "arrow.down.right"
        case .fast: "arrow.down"
        }
    }

    var tint: Color {
        switch self {
        case .rising, .idle: .green
        case .slow: .mint
        case .moderate: .orange
        case .fast: .red
        }
    }

    static func format(ratePerHour: Double) -> String {
        String(format: "$%.2f/h", abs(ratePerHour))
    }
}

/// Cache im App-Group-UserDefaults: App schreibt, Widget liest (und umgekehrt).
enum CreditCache {
    private static let snapshotKey = "creditSnapshot"
    private static let warningThresholdKey = "warningThreshold"
    private static let refreshMinutesKey = "refreshMinutes"
    private static let showBalanceInMenuBarKey = "showBalanceInMenuBar"
    private static let showCentsInMenuBarKey = "showCentsInMenuBar"
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
        appendHistory(snapshot)
    }

    // MARK: - Verlauf für die Burn-Rate

    struct HistoryPoint: Codable {
        let t: Date
        let b: Double
    }

    private static let historyKey = "balanceHistory"
    private static let historyMinGap: TimeInterval = 30
    private static let historyMaxAge: TimeInterval = 24 * 3600
    private static let historyMaxCount = 200

    static func loadHistory() -> [HistoryPoint] {
        guard let data = defaults.data(forKey: historyKey) else { return [] }
        return (try? JSONDecoder().decode([HistoryPoint].self, from: data)) ?? []
    }

    private static func appendHistory(_ snapshot: CreditSnapshot) {
        var points = loadHistory()
        if let last = points.last,
           snapshot.fetchedAt.timeIntervalSince(last.t) < historyMinGap {
            return
        }
        points.append(HistoryPoint(t: snapshot.fetchedAt, b: snapshot.balanceUSD))
        let cutoff = Date.now.addingTimeInterval(-historyMaxAge)
        points.removeAll { $0.t < cutoff }
        if points.count > historyMaxCount {
            points.removeFirst(points.count - historyMaxCount)
        }
        guard let data = try? JSONEncoder().encode(points) else { return }
        defaults.set(data, forKey: historyKey)
    }

    /// Verbrauch in USD pro Stunde über das letzte Stundenfenster.
    /// Negativ = Guthaben gestiegen (Aufladung). Nil, wenn zu wenig Daten.
    static func burnRatePerHour() -> Double? {
        let windowStart = Date.now.addingTimeInterval(-3600)
        let recent = loadHistory().filter { $0.t >= windowStart }
        guard let first = recent.first, let last = recent.last else { return nil }
        let span = last.t.timeIntervalSince(first.t)
        guard span >= 180 else { return nil }
        return (first.b - last.b) / (span / 3600)
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

    static var showCentsInMenuBar: Bool {
        get {
            if defaults.object(forKey: showCentsInMenuBarKey) == nil { return true }
            return defaults.bool(forKey: showCentsInMenuBarKey)
        }
        set { defaults.set(newValue, forKey: showCentsInMenuBarKey) }
    }
}
