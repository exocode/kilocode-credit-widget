import SwiftUI
import AppKit

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
                    .help("Jetzt aktualisieren")
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
                        Text(snapshot.status.label)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Text("Stand: \(snapshot.fetchedAt.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            } else if let error = model.lastError {
                errorView(error)
            } else {
                Text("Lade Guthaben …")
                    .foregroundStyle(.secondary)
            }

            if model.snapshot != nil, let error = model.lastError {
                errorView(error)
            }

            Button {
                NSWorkspace.shared.open(AppConstants.profileURL)
            } label: {
                Label("Credits aufladen", systemImage: "creditcard")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(model.snapshot?.status == .healthy ? .accentColor : (model.snapshot?.status.tint ?? .accentColor))

            Divider()

            HStack {
                Button("Einstellungen") { showSettings = true }
                    .buttonStyle(.borderless)
                Spacer()
                Button("Beenden") { NSApplication.shared.terminate(nil) }
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

/// Erststart: Anmeldung per Browser (Device-Auth) oder manuell per API-Key
/// von app.kilo.ai/profile.
struct TokenSetupView: View {
    @Bindable var model: CreditModel
    @State private var tokenInput = ""
    @State private var showManualEntry = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Kilo Code verbinden", systemImage: "key.horizontal.fill")
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
                Button("Beenden") { NSApplication.shared.terminate(nil) }
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
                Text("Warte auf Freigabe im Browser …")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            if let code = model.authCode {
                LabeledContent("Code") {
                    Text(code)
                        .font(.body.monospaced().weight(.semibold))
                        .textSelection(.enabled)
                }
                .font(.callout)
            }
            Button("Abbrechen") { model.cancelSignIn() }
                .buttonStyle(.borderless)
        }
    }

    @ViewBuilder
    private var signInView: some View {
        Text("Melde dich mit deinem Kilo-Account an, um dein Guthaben abzurufen.")
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

        Button {
            model.signInWithBrowser()
        } label: {
            Label("Mit Browser anmelden", systemImage: "safari")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)

        DisclosureGroup("API-Key manuell eingeben", isExpanded: $showManualEntry) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Den Key findest du unten auf app.kilo.ai/profile.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                SecureField("API-Key einfügen", text: $tokenInput)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(save)
                Button(action: save) {
                    Text("Speichern")
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
                Text("Einstellungen")
                    .font(.headline)
                Spacer()
            }

            Picker("Aktualisieren alle", selection: $model.refreshMinutes) {
                ForEach(AppConstants.refreshChoicesMinutes, id: \.self) { minutes in
                    Text("\(minutes) Min.").tag(minutes)
                }
            }

            Toggle("Guthaben in Menüleiste anzeigen", isOn: $model.showBalanceInMenuBar)

            Toggle(
                "Bei Anmeldung starten",
                isOn: Binding(
                    get: { model.launchAtLogin },
                    set: { model.setLaunchAtLogin($0) }
                )
            )

            LabeledContent("Warnschwelle") {
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
                Label("Token entfernen", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
    }
}
