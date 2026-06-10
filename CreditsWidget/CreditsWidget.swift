import WidgetKit
import SwiftUI

@main
struct CreditsWidgetBundle: WidgetBundle {
    var body: some Widget {
        CreditsWidget()
    }
}

struct CreditsEntry: TimelineEntry {
    let date: Date
    let snapshot: CreditSnapshot?
    let needsSetup: Bool
}

struct CreditsProvider: TimelineProvider {
    func placeholder(in context: Context) -> CreditsEntry {
        CreditsEntry(
            date: .now,
            snapshot: CreditSnapshot(balanceUSD: 23.41, fetchedAt: .now),
            needsSetup: false
        )
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (CreditsEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<CreditsEntry>) -> Void) {
        Task {
            var entry = currentEntry()
            // Widget aktualisiert selbst, falls Token vorhanden — unabhängig von der App.
            if let token = TokenStore.load() {
                if let snapshot = try? await KilocodeAPI.fetchBalance(token: token) {
                    CreditCache.save(snapshot)
                    entry = CreditsEntry(date: .now, snapshot: snapshot, needsSetup: false)
                }
            }
            let interval = TimeInterval(CreditCache.refreshMinutes * 60)
            let timeline = Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(interval)))
            completion(timeline)
        }
    }

    private func currentEntry() -> CreditsEntry {
        let snapshot = CreditCache.load()
        let hasToken = TokenStore.load() != nil
        return CreditsEntry(date: .now, snapshot: snapshot, needsSetup: !hasToken && snapshot == nil)
    }
}

struct CreditsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "KilocodeCreditsWidget", provider: CreditsProvider()) { entry in
            CreditsWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Kilocode Credits")
        .description(L10n.current.widgetDescription)
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct CreditsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CreditsEntry

    private var t: L10nTable { L10n.current }

    var body: some View {
        Group {
            if entry.needsSetup {
                setupView
            } else if let snapshot = entry.snapshot {
                switch family {
                case .systemMedium: mediumView(snapshot)
                default: smallView(snapshot)
                }
            } else {
                noDataView
            }
        }
        .widgetURL(AppConstants.profileURL)
    }

    private var setupView: some View {
        VStack(spacing: 6) {
            Image(systemName: "key.horizontal")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(t.widgetSetupHint)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(8)
    }

    private var noDataView: some View {
        VStack(spacing: 6) {
            Image(systemName: "wifi.exclamationmark")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(t.widgetNoData)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func smallView(_ snapshot: CreditSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            header
            Spacer(minLength: 0)
            Text(snapshot.formattedBalance)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundStyle(snapshot.status.tint)
                .contentTransition(.numericText())
            Text(snapshot.fetchedAt, style: .relative)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func mediumView(_ snapshot: CreditSnapshot) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                header
                Spacer(minLength: 0)
                Text(snapshot.formattedBalance)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundStyle(snapshot.status.tint)
                    .contentTransition(.numericText())
                HStack(spacing: 4) {
                    Circle()
                        .fill(snapshot.status.tint)
                        .frame(width: 6, height: 6)
                    Text(t.statusLabel(snapshot.status))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text(snapshot.fetchedAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Label(t.widgetTopUp, systemImage: "arrow.up.right")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.quaternary, in: Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack(spacing: 5) {
            Image("KiloMark")
                .resizable()
                .scaledToFit()
                .frame(width: 11, height: 11)
                .foregroundStyle(.secondary)
            Text("KILO CODE")
                .font(.caption2.weight(.semibold))
                .kerning(1)
                .foregroundStyle(.secondary)
        }
    }
}
