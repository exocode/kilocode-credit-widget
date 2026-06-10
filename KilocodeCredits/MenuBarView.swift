import SwiftUI
import AppKit
import Charts

struct MenuBarView: View {
    @Bindable var model: CreditModel
    @State private var showSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showSettings {
                SettingsView(model: model, onBack: { showSettings = false })
            } else {
                mainContent
            }
        }
        .frame(width: 300)
    }

    @ViewBuilder
    private var mainContent: some View {
        if !model.hasToken {
            TokenSetupView(model: model)
        } else {
            balanceContent
        }
    }

    private var balanceContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label {
                    Text("Kilocode Credits")
                } icon: {
                    Image("KiloMark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                }
                .font(.headline)
                Spacer()
                if model.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button {
                        Task { await model.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .help(model.t.refreshNow)
                }
            }

            if let snapshot = model.snapshot {
                VStack(alignment: .leading, spacing: 6) {
                    Text(snapshot.formattedBalance)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(snapshot.status.tint)
                        .contentTransition(.numericText())
                    HStack(spacing: 5) {
                        Circle()
                            .fill(snapshot.status.tint)
                            .frame(width: 7, height: 7)
                        Text(model.t.statusLabel(snapshot.status))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    if let rate = model.burnRatePerHour {
                        let trend = BurnTrend(ratePerHour: rate)
                        HStack(spacing: 5) {
                            Image(systemName: trend.symbol)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(trend.tint)
                            Text("\(model.t.burnRate): \(BurnTrend.format(ratePerHour: rate))")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .contentTransition(.numericText())
                        }
                    }
                    let history = model.historyPoints
                    if history.count >= 2 {
                        BalanceSparkline(
                            points: history,
                            tint: model.burnRatePerHour.map { BurnTrend(ratePerHour: $0).tint } ?? .secondary
                        )
                        .padding(.top, 4)
                    }
                    Text("\(model.t.updatedAt) \(snapshot.fetchedAt.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            } else if let error = model.lastError {
                errorView(error)
            } else {
                Text(model.t.loadingBalance)
                    .foregroundStyle(.secondary)
            }

            if model.snapshot != nil, let error = model.lastError {
                errorView(error)
            }

            Button {
                NSWorkspace.shared.open(AppConstants.profileURL)
            } label: {
                Label(model.t.addCredits, systemImage: "creditcard")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(model.snapshot?.status == .healthy ? .accentColor : (model.snapshot?.status.tint ?? .accentColor))

            Divider()

            HStack {
                Button(model.t.settings) { showSettings = true }
                    .buttonStyle(.borderless)
                Spacer()
                Button(model.t.quit) { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
        }
        .padding(16)
    }

    private func errorView(_ message: String) -> some View {
        Label {
            Text(message)
                .font(.caption)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
        .foregroundStyle(.secondary)
    }
}

/// Guthabenverlauf als Sparkline (letzte 6 Stunden), Trendfarbe wie der Pfeil.
struct BalanceSparkline: View {
    let points: [CreditCache.HistoryPoint]
    let tint: Color

    private var yDomain: ClosedRange<Double> {
        let values = points.map(\.b)
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 1
        let padding = max((maxValue - minValue) * 0.15, 0.05)
        return (minValue - padding)...(maxValue + padding)
    }

    var body: some View {
        Chart(points, id: \.t) { point in
            // Baseline explizit an die Domain-Untergrenze binden, sonst füllt
            // AreaMark bis zur Nulllinie weit außerhalb des Plots.
            AreaMark(
                x: .value("t", point.t),
                yStart: .value("base", yDomain.lowerBound),
                yEnd: .value("$", point.b)
            )
            .interpolationMethod(.monotone)
            .foregroundStyle(
                .linearGradient(
                    colors: [tint.opacity(0.3), tint.opacity(0.03)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            LineMark(
                x: .value("t", point.t),
                y: .value("$", point.b)
            )
            .interpolationMethod(.monotone)
            .foregroundStyle(tint)
            .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round))
        }
        .chartYScale(domain: yDomain)
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 2)) {
                AxisValueLabel()
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
            }
        }
        .chartPlotStyle { plot in
            plot
                .background(.quaternary.opacity(0.25))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .frame(height: 64)
        .clipped()
    }
}

/// Mini-Drehzahlmesser für die Menüleiste: nach unten offener Kreisbogen,
/// dessen Füllung mit dem Verbrauch nach rechts wandert und von Grün nach
/// Rot kippt.
struct BurnGaugeIcon: View {
    let ratePerHour: Double

    /// 0...1 entlang des Bogens; Wurzelkurve, damit kleine Raten sichtbar
    /// bleiben und ab ~$10/h Vollausschlag ist.
    private var progress: Double {
        guard ratePerHour > 0 else { return 0 }
        return min(1, (min(ratePerHour, 10) / 10).squareRoot())
    }

    private var needleColor: Color {
        Color(hue: 0.33 * (1 - progress), saturation: 0.85, brightness: 0.95)
    }

    var body: some View {
        ZStack {
            GaugeArc(progress: 1)
                .stroke(.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            GaugeArc(progress: max(progress, 0.07))
                .stroke(needleColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        }
        .frame(width: 14, height: 14)
    }
}

/// Kreisbogen wie beim App-Icon: 270°, unten offen, Start unten links.
struct GaugeArc: Shape {
    var progress: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2 - 1
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(135),
            endAngle: .degrees(135 + 270 * progress),
            clockwise: false
        )
        return path
    }
}

/// Erststart: Anmeldung per Browser (Device-Auth) oder manuell per API-Key
/// von app.kilo.ai/profile.
struct TokenSetupView: View {
    @Bindable var model: CreditModel
    @State private var tokenInput = ""
    @State private var showManualEntry = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(model.t.connectTitle, systemImage: "key.horizontal.fill")
                .font(.headline)

            if model.authFlow == .waitingForBrowser {
                waitingView
            } else {
                signInView
            }

            if let error = model.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Divider()

            HStack {
                Spacer()
                Button(model.t.quit) { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
        }
        .padding(16)
    }

    private var waitingView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text(model.t.waitingForBrowser)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            if let code = model.authCode {
                LabeledContent(model.t.codeLabel) {
                    Text(code)
                        .font(.body.monospaced().weight(.semibold))
                        .textSelection(.enabled)
                }
                .font(.callout)
            }
            Button(model.t.cancel) { model.cancelSignIn() }
                .buttonStyle(.borderless)
        }
    }

    @ViewBuilder
    private var signInView: some View {
        Text(model.t.connectBody)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

        Button {
            model.signInWithBrowser()
        } label: {
            Label(model.t.signInWithBrowser, systemImage: "safari")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)

        DisclosureGroup(model.t.manualEntryTitle, isExpanded: $showManualEntry) {
            VStack(alignment: .leading, spacing: 8) {
                Text(model.t.manualEntryHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                SecureField(model.t.pasteAPIKey, text: $tokenInput)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(save)
                Button(action: save) {
                    Text(model.t.save)
                        .frame(maxWidth: .infinity)
                }
                .disabled(tokenInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.top, 6)
        }
        .font(.callout)
    }

    private func save() {
        model.saveToken(tokenInput)
        tokenInput = ""
    }
}

struct SettingsView: View {
    @Bindable var model: CreditModel
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)
                Text(model.t.settings)
                    .font(.headline)
                Spacer()
            }

            Picker(model.t.refreshEvery, selection: $model.refreshMinutes) {
                ForEach(AppConstants.refreshChoicesMinutes, id: \.self) { minutes in
                    Text("\(minutes) \(model.t.minutesSuffix)").tag(minutes)
                }
            }

            Picker(model.t.language, selection: $model.language) {
                ForEach(AppLanguage.allCases) { lang in
                    Text(lang.displayName).tag(lang)
                }
            }

            Toggle(model.t.showBalanceInMenuBar, isOn: $model.showBalanceInMenuBar)

            Toggle(model.t.showCentsInMenuBar, isOn: $model.showCentsInMenuBar)
                .disabled(!model.showBalanceInMenuBar)

            Toggle(
                model.t.launchAtLogin,
                isOn: Binding(
                    get: { model.launchAtLogin },
                    set: { model.setLaunchAtLogin($0) }
                )
            )

            LabeledContent(model.t.warningThreshold) {
                HStack(spacing: 4) {
                    TextField(
                        "",
                        value: $model.warningThreshold,
                        format: .number.precision(.fractionLength(0...2))
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    .multilineTextAlignment(.trailing)
                    Text("USD")
                        .foregroundStyle(.secondary)
                }
            }

            if let error = model.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Divider()

            Button(role: .destructive) {
                model.removeToken()
                onBack()
            } label: {
                Label(model.t.removeToken, systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
    }
}
