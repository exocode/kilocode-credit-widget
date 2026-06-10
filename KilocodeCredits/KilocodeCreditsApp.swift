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

    private var menuBarLabel: some View {
        HStack(spacing: 3) {
            menuBarIcon
            if model.showBalanceInMenuBar, let snapshot = model.snapshot {
                Text(snapshot.compactBalance)
                    .monospacedDigit()
            }
        }
    }

    @ViewBuilder
    private var menuBarIcon: some View {
        if !model.hasToken {
            Image("MenuBarMark")
            Image(systemName: "person.crop.circle.badge.questionmark")
        } else if let status = model.snapshot?.status, status != .healthy {
            // Unter der Warnschwelle: sanft pulsierender Blitz statt Gewicht.
            TimelineView(.animation(minimumInterval: 1.0 / 12)) { context in
                let period: Double = status == .critical ? 1.2 : 2.4
                let t = context.date.timeIntervalSinceReferenceDate
                let phase = (sin(2 * .pi * t / period) + 1) / 2
                Image(systemName: "bolt.fill")
                    .opacity(0.35 + 0.65 * phase)
            }
        } else {
            Image("MenuBarMark")
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
    var refreshMinutes: Int {
        didSet {
            CreditCache.refreshMinutes = refreshMinutes
            restartTimer()
        }
    }
    var warningThreshold: Double {
        didSet { CreditCache.warningThreshold = warningThreshold }
    }
    var language: AppLanguage {
        didSet {
            CreditCache.language = language
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// Aktive Übersetzungstabelle für alle Views.
    var t: L10nTable { language.table }

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
        refreshMinutes = CreditCache.refreshMinutes
        warningThreshold = CreditCache.warningThreshold
        language = CreditCache.language
        launchAtLogin = SMAppService.mainApp.status == .enabled
        restartTimer()
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
            snapshot = fresh
            lastError = nil
            CreditCache.save(fresh)
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
