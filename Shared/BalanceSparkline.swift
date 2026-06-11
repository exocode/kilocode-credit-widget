import SwiftUI
import Charts

/// Guthabenverlauf als Sparkline (letzte 6 Stunden), Trendfarbe wie der Pfeil.
/// Geteilt zwischen Popover und Widget.
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
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .chartPlotStyle { plot in
            plot
                .background(.quaternary.opacity(0.25))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .clipped()
    }
}
