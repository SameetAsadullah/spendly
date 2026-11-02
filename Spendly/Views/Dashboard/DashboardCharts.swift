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

        ZStack {
            Chart(slices) { slice in
                SectorMark(
                    angle: .value("Amount", slice.total.doubleValue),
                    innerRadius: .ratio(0.64),
                    angularInset: 1.5
                )
                .cornerRadius(5)
                .foregroundStyle(slice.color)
                .opacity(selected == nil || selected?.id == slice.id ? 1 : 0.3)
            }
            .chartLegend(.hidden)
            .chartAngleSelection(value: $selectedAngle)

            VStack(spacing: 2) {
                if let selected {
                    Image(systemName: selected.iconName)
                        .foregroundStyle(selected.color)
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

    var body: some View {
        Chart {
            ForEach(daily) { item in
                BarMark(
                    x: .value("Day", item.day, unit: .day),
                    y: .value("Spent", item.total.doubleValue)
                )
                .foregroundStyle(Theme.heroGradient)
                .cornerRadius(4)
            }
            if average > 0 {
                AverageRule(label: "Daily average", average: average, currency: currency)
            }
        }
        .chartXScale(domain: interval.start...interval.end)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.day())
            }
        }
        .currencyYAxis(currency)
        .frame(height: 190)
    }
}

struct MonthlyTrendChart: View {
    let totals: [MonthTotal]
    let currency: String
    var highlightedMonth: Date?
    var height: CGFloat = 190

    private var average: Decimal {
        totals.isEmpty ? 0 : totals.reduce(0) { $0 + $1.total } / Decimal(totals.count)
    }

    var body: some View {
        Chart {
            ForEach(totals) { item in
                BarMark(
                    x: .value("Month", item.month, unit: .month),
                    y: .value("Spent", item.total.doubleValue)
                )
                .foregroundStyle(Theme.heroGradient)
                .opacity(highlightedMonth == nil || item.month == highlightedMonth ? 1 : 0.4)
                .cornerRadius(4)
            }
            if average > 0 {
                AverageRule(label: "Monthly average", average: average, currency: currency)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { _ in
                AxisValueLabel(format: .dateTime.month(totals.count > 6 ? .narrow : .abbreviated), centered: true)
            }
        }
        .currencyYAxis(currency)
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
            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
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
            AxisMarks(position: .leading) { value in
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
