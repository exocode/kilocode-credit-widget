import SwiftUI
import AppKit
import WidgetKit
import ServiceManagement
import UserNotifications

@main
struct KilocodeCreditsApp: App {
    @State private var model = CreditModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(model: model)
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.window)
    }

    // macOS reduziert MenuBarExtra-Labels auf "ein Bild + ein Text" —
    // alles Weitere wird verworfen. Daher genau ein vorgerendertes Icon.
    private var menuBarLabel: some View {
        HStack(spacing: 3) {
            if let icon = model.menuBarImage {
                Image(nsImage: icon)
            } else {
                Image("MenuBarMark")
            }
            if model.showBalanceInMenuBar, let snapshot = model.snapshot {
                Text(snapshot.compactBalance(showCents: model.showCentsInMenuBar))
                    .monospacedDigit()
            }
        }
    }
}

/// Zentrales Modell: hält den Stand, pollt im Intervall und stößt Widget-Reloads an.
@MainActor
@Observable
final class CreditModel {
    var snapshot: CreditSnapshot?
    var isRefreshing = false
    var lastError: String?
    var hasToken: Bool
    var showBalanceInMenuBar: Bool {
        didSet { CreditCache.showBalanceInMenuBar = showBalanceInMenuBar }
    }
    var showCentsInMenuBar: Bool {
        didSet { CreditCache.showCentsInMenuBar = showCentsInMenuBar }
    }
    var refreshMinutes: Int {
        didSet {
            CreditCache.refreshMinutes = refreshMinutes
            restartTimer()
        }
    }
    var warningThreshold: Double {
        didSet {
            CreditCache.warningThreshold = warningThreshold
            updateMenuBarImage()
        }
    }
    var language: AppLanguage {
        didSet {
            CreditCache.language = language
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    var burnWindowMinutes: Int {
        didSet {
            CreditCache.burnWindowMinutes = burnWindowMinutes
            updateMenuBarImage()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// Aktive Übersetzungstabelle für alle Views.
    var t: L10nTable { language.table }

    /// Aktueller Verbrauch in USD/h (nil bei zu wenig Verlaufsdaten).
    var burnRatePerHour: Double? {
        _ = snapshot  // Observation-Abhängigkeit: bei jedem Refresh neu lesen
        return CreditCache.burnRatePerHour()
    }

    /// Guthabenverlauf der letzten 6 Stunden für die Sparkline.
    var historyPoints: [CreditCache.HistoryPoint] {
        _ = snapshot
        let cutoff = Date.now.addingTimeInterval(-6 * 3600)
        return CreditCache.loadHistory().filter { $0.t >= cutoff }
    }

    /// Das eine Menüleisten-Icon, vorgerendert als Nicht-Template-NSImage
    /// (Labels erzwingen sonst Monochrom und verwerfen Custom-Views):
    /// pulsierender Blitz bei Niedrigstand, sonst Tacho, sonst nil (= Gewicht).
    var menuBarImage: NSImage?

    private var pulseTask: Task<Void, Never>?

    private func updateMenuBarImage() {
        guard hasToken else {
            stopPulse()
            menuBarImage = nil
            return
        }
        if let status = snapshot?.status, status != .healthy {
            startPulseIfNeeded()
            let period: Double = status == .critical ? 1.2 : 2.4
            let t = Date.now.timeIntervalSinceReferenceDate
            let phase = (sin(2 * .pi * t / period) + 1) / 2
            let boltColor: Color = status == .critical ? .red : .orange
            let boltOpacity = 0.35 + 0.65 * phase
            if let rate = burnRatePerHour {
                // Tacho bleibt sichtbar, der Warn-Blitz pulsiert im Bogen.
                menuBarImage = render(
                    BurnGaugeIcon(ratePerHour: rate, boltTint: boltColor, boltOpacity: boltOpacity)
                )
            } else {
                menuBarImage = render(
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(boltColor)
                        .opacity(boltOpacity)
                )
            }
        } else if let rate = burnRatePerHour {
            stopPulse()
            menuBarImage = render(BurnGaugeIcon(ratePerHour: rate))
        } else {
            stopPulse()
            menuBarImage = nil
        }
    }

    private func render(_ content: some View) -> NSImage? {
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        return renderer.nsImage
    }

    private func startPulseIfNeeded() {
        guard pulseTask == nil else { return }
        pulseTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(120))
                guard !Task.isCancelled else { return }
                self?.updateMenuBarImage()
            }
        }
    }

    private func stopPulse() {
        pulseTask?.cancel()
        pulseTask = nil
    }

    /// Nur lesend gespiegelt; Änderungen laufen über setLaunchAtLogin(_:),
    /// damit kein Setter-Seiteneffekt rekursiv den Observation-Setter triggert.
    private(set) var launchAtLogin: Bool

    func setLaunchAtLogin(_ enabled: Bool) {
        guard enabled != launchAtLogin else { return }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = enabled
            lastError = nil
        } catch {
            lastError = "\(t.launchAtLogin): \(error.localizedDescription)"
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    enum AuthFlow: Equatable {
        case idle
        case waitingForBrowser
    }
    var authFlow: AuthFlow = .idle
    /// Bestätigungscode zum Abgleich mit der Browser-Anzeige.
    var authCode: String?

    private var timerTask: Task<Void, Never>?
    private var authTask: Task<Void, Never>?

    init() {
        snapshot = CreditCache.load()
        hasToken = TokenStore.load() != nil
        showBalanceInMenuBar = CreditCache.showBalanceInMenuBar
        showCentsInMenuBar = CreditCache.showCentsInMenuBar
        refreshMinutes = CreditCache.refreshMinutes
        warningThreshold = CreditCache.warningThreshold
        language = CreditCache.language
        burnWindowMinutes = CreditCache.burnWindowMinutes
        launchAtLogin = SMAppService.mainApp.status == .enabled
        restartTimer()
        updateMenuBarImage()
        Task { await refresh() }
    }

    func saveToken(_ token: String) {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            try TokenStore.save(trimmed)
            hasToken = true
            lastError = nil
            Task { await refresh() }
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Device-Auth: Browser-Login starten und auf Freigabe pollen.
    func signInWithBrowser() {
        authTask?.cancel()
        lastError = nil
        authFlow = .waitingForBrowser
        authTask = Task { [weak self] in
            do {
                let auth = try await KilocodeAPI.startDeviceAuth()
                self?.authCode = auth.code
                if let url = URL(string: auth.verificationUrl) {
                    NSWorkspace.shared.open(url)
                }
                let deadline = Date.now.addingTimeInterval(TimeInterval(auth.expiresIn ?? 600))
                while !Task.isCancelled, Date.now < deadline {
                    try await Task.sleep(for: .seconds(3))
                    switch try await KilocodeAPI.pollDeviceAuth(code: auth.code) {
                    case .pending:
                        continue
                    case .approved(let token):
                        self?.saveToken(token)
                        self?.authFlow = .idle
                        self?.authCode = nil
                        return
                    case .denied:
                        self?.failAuth(L10n.current.signInDenied)
                        return
                    case .expired:
                        self?.failAuth(L10n.current.signInExpired)
                        return
                    }
                }
                if !Task.isCancelled {
                    self?.failAuth(L10n.current.signInExpired)
                }
            } catch {
                if !Task.isCancelled {
                    self?.failAuth(error.localizedDescription)
                }
            }
        }
    }

    func cancelSignIn() {
        authTask?.cancel()
        authFlow = .idle
        authCode = nil
    }

    private func failAuth(_ message: String) {
        lastError = message
        authFlow = .idle
        authCode = nil
    }

    func removeToken() {
        TokenStore.delete()
        hasToken = false
        snapshot = nil
        updateMenuBarImage()
    }

    func refresh() async {
        guard let token = TokenStore.load() else {
            hasToken = false
            return
        }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let fresh = try await KilocodeAPI.fetchBalance(token: token)
            // Animation treibt die "Zählwerk"-Transition der Ziffern an.
            withAnimation(.spring(duration: 0.6)) {
                snapshot = fresh
            }
            lastError = nil
            CreditCache.save(fresh)
            updateMenuBarImage()
            WidgetCenter.shared.reloadAllTimelines()
            await notifyIfBalanceDropped(fresh)
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// macOS-Mitteilung beim Unterschreiten der Warn- bzw. Kritisch-Schwelle,
    /// genau einmal pro Verschlechterung (Erholung setzt zurück).
    private func notifyIfBalanceDropped(_ snapshot: CreditSnapshot) async {
        let rank = snapshot.status.rank
        let lastRank = CreditCache.lastNotifiedRank
        CreditCache.lastNotifiedRank = rank
        guard rank > 0, rank > lastRank else { return }

        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return }

        let content = UNMutableNotificationContent()
        content.title = snapshot.status == .critical ? t.notifCriticalTitle : t.notifLowTitle
        content.body = String(format: t.notifBody, snapshot.formattedBalance)
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "balance-rank-\(rank)",
            content: content,
            trigger: nil
        )
        try? await center.add(request)
    }

    private func restartTimer() {
        timerTask?.cancel()
        let minutes = refreshMinutes
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(minutes * 60))
                guard !Task.isCancelled else { return }
                await self?.refresh()
            }
        }
    }
}
