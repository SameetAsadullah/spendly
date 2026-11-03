import Charts
import SwiftUI

struct CategoryDonutChart: View {
    let slices: [CategorySlice]
    let total: Decimal
    let currency: String
    @State private var selectedAngle: Double?

    private var selectedSlice: CategorySlice? {
        guard let selectedAngle else { return nil }
        var cumulative = 0.0
        for slice in slices {
            cumulative += slice.total.doubleValue
            if selectedAngle <= cumulative { return slice }
        }
        return nil
    }

    var body: some View {
        let selected = selectedSlice
        let selectedID = selected.map { $0.id }

        ZStack {
            Chart(slices) { slice in
                SectorMark(
                    angle: .value("Amount", slice.total.doubleValue),
                    innerRadius: .ratio(0.6),
                    outerRadius: .ratio(selectedID == .some(slice.id) ? 1 : 0.9),
                    angularInset: 1.5
                )
                .cornerRadius(5)
                .foregroundStyle(slice.color)
                .opacity(selectedID == nil || selectedID == .some(slice.id) ? 1 : 0.4)
            }
            .chartLegend(.hidden)
            .chartAngleSelection(value: $selectedAngle)

            VStack(spacing: 2) {
                if let selected {
                    Text(selected.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(selected.total.formattedCurrency(currency))
                        .font(.headline)
                    Text((selected.total / max(total, 1)).doubleValue.formatted(.percent.precision(.fractionLength(0))))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                } else {
                    Text("Total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(total.formattedCurrency(currency))
                        .font(.system(.title3, design: .rounded, weight: .bold))
                    Text("Tap a slice")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: 120)
            .allowsHitTesting(false)
        }
        .frame(height: 230)
        .animation(.snappy, value: selectedAngle)
    }
}

struct DailySpendingChart: View {
    let daily: [DailyTotal]
    let interval: DateInterval
    let average: Decimal
    let currency: String
    var now: Date = .now

    private var days: [Date] {
        let calendar = Calendar.current
        let count = calendar.range(of: .day, in: .month, for: interval.start)?.count ?? 30
        return (0..<count).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
    }

    var body: some View {
        let calendar = Calendar.current
        let totals = Dictionary(uniqueKeysWithValues: daily.map { ($0.day, $0.total) })
        let labelDays = days.filter { [1, 8, 15, 22, 29].contains(calendar.component(.day, from: $0)) }

        Chart {
            // Days after today get no mark.
            ForEach(days.filter { $0 <= now }, id: \.self) { day in
                BarMark(
                    x: .value("Day", day, unit: .day),
                    y: .value("Spent", (totals[day] ?? 0).doubleValue)
                )
                .foregroundStyle(Color.accentColor)
                .cornerRadius(3)
            }
            if average > 0 {
                AverageRule(label: "Daily average", average: average, currency: currency)
            }
        }
        .chartXScale(domain: interval.start...interval.end)
        .chartXAxis {
            AxisMarks(values: labelDays) { _ in
                AxisValueLabel(format: .dateTime.day(), centered: true)
            }
        }
        .currencyYAxis(currency)
        .frame(height: 190)
    }
}

struct MonthlyTrendChart: View {
    enum Style {
        /// Overview card: no axis, no average, value above the selected bar.
        case compact
        /// Trends: average line and a compact currency axis.
        case detailed
    }

    let totals: [MonthTotal]
    let currency: String
    var highlightedMonth: Date?
    var style: Style = .detailed
    var height: CGFloat = 190

    private var average: Decimal {
        totals.isEmpty ? 0 : totals.reduce(0) { $0 + $1.total } / Decimal(totals.count)
    }

    private var dimmedOpacity: Double { style == .compact ? 0.3 : 0.35 }

    var body: some View {
        Chart {
            ForEach(totals) { item in
                let isHighlighted = highlightedMonth == nil || item.month == highlightedMonth
                BarMark(
                    x: .value("Month", item.month, unit: .month),
                    y: .value("Spent", item.total.doubleValue)
                )
                .foregroundStyle(Color.accentColor)
                .opacity(isHighlighted ? 1 : dimmedOpacity)
                .cornerRadius(4)
                .annotation(position: .top) {
                    if style == .compact, isHighlighted, item.total > 0 {
                        Text(item.total.formattedCurrency(currency, fractionDigits: 0))
                            .font(.caption2.weight(.semibold))
                            .monospacedDigit()
                    }
                }
            }
            if style == .detailed, average > 0 {
                AverageRule(label: "Monthly average", average: average, currency: currency)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { _ in
                AxisValueLabel(format: .dateTime.month(totals.count > 6 ? .narrow : .abbreviated), centered: true)
            }
        }
        .chartYAxis {
            if style == .detailed {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            if #available(iOS 18, *) {
                                Text(amount, format: .currency(code: currency).notation(.compactName).precision(.fractionLength(0)))
                            } else {
                                Text(amount, format: .currency(code: currency).precision(.fractionLength(0)))
                            }
                        }
                    }
                }
            }
        }
        .frame(height: height)
    }
}

struct AverageRule: ChartContent {
    let label: String
    let average: Decimal
    let currency: String

    var body: some ChartContent {
        RuleMark(y: .value(label, average.doubleValue))
            .foregroundStyle(Color.orange)
            .lineStyle(Theme.averageLineStyle)
            .annotation(position: .top, alignment: .leading) {
                Text("avg \(average.formattedCurrency(currency, fractionDigits: 0))")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.orange)
            }
    }
}

extension View {
    func currencyYAxis(_ currency: String) -> some View {
        chartYAxis {
            AxisMarks(position: .trailing) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let amount = value.as(Double.self) {
                        Text(amount, format: .currency(code: currency).precision(.fractionLength(0)))
                    }
                }
            }
        }
    }
}
