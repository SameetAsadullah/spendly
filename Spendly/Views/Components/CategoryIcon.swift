import SwiftUI

struct CategoryIcon: View {
    let iconName: String
    let color: Color
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: iconName)
            .font(.system(size: size * 0.44, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(
                color.opacity(0.16),
                in: RoundedRectangle(cornerRadius: Theme.Radius.icon(size), style: .continuous)
            )
            .accessibilityHidden(true)
    }
}

extension CategoryIcon {
    init(category: ExpenseCategory?, size: CGFloat = 40) {
        self.init(
            iconName: category?.iconName ?? "questionmark",
            color: category?.color ?? Theme.uncategorized,
            size: size
        )
    }
}

/// The fill stops at 100% and turns red above it.
struct BudgetBar: View {
    let progress: Double
    let tint: Color
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(tint.opacity(0.18))
                Capsule()
                    .fill(progress > 1 ? Color.red : tint)
                    .frame(width: geometry.size.width * min(max(progress, 0), 1))
            }
        }
        .frame(height: height)
        .animation(.spring(duration: 0.4), value: progress)
        .accessibilityElement()
        .accessibilityLabel("Budget used")
        .accessibilityValue(Text(progress.formatted(.percent.precision(.fractionLength(0)))))
    }
}

/// Selectable chip. When selected it is BrandFill with white text and icon.
struct Chip: View {
    let text: String
    var icon: String?
    /// Icon colour while not selected, for example a category colour.
    var iconTint: Color?
    var isSelected = false

    var body: some View {
        HStack(spacing: 5) {
            if let icon {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.white : (iconTint ?? Color.primary))
            }
            Text(text).font(.subheadline.weight(.medium))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .background(isSelected ? Theme.brandFill : Color(.tertiarySystemFill), in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct RemovableChip: View {
    let text: String
    var icon: String?
    var tint: Color = .accentColor
    let onRemove: () -> Void

    var body: some View {
        Button(action: onRemove) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon).font(.caption.weight(.semibold))
                }
                Text(text).font(.footnote.weight(.semibold)).lineLimit(1)
                Image(systemName: "xmark").font(.caption2.weight(.bold)).opacity(0.7)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .foregroundStyle(tint)
            .background(tint.opacity(0.14), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remove filter \(text)")
    }
}

struct StatTile: View {
    let icon: String
    let value: String
    let label: String
    var tint: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
            Text(value)
                .font(.tileAmount)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .card(padding: Theme.Spacing.tile)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }
}

/// Three StatTiles of equal height.
struct StatTileRow<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 12) {
            content
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct CardHeader<Action: View>: View {
    let title: String
    let subtitle: String?
    let action: Action

    init(title: String, subtitle: String? = nil, @ViewBuilder action: () -> Action) {
        self.title = title
        self.subtitle = subtitle
        self.action = action()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            action
                .font(.footnote.weight(.semibold))
                .tint(.accentColor)
        }
    }
}

extension CardHeader where Action == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width
            widest = max(widest, x)
            x += spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: widest, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// Text field bound to an optional amount; nil when empty or unparsable.
struct AmountField: View {
    let placeholder: String
    @Binding var value: Decimal?
    @State private var text = ""

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(.decimalPad)
            .onAppear {
                text = value.map(AmountParser.string(from:)) ?? ""
            }
            .onChange(of: text) { _, newValue in
                let parsed = AmountParser.parse(newValue)
                if parsed != value { value = parsed }
            }
            .onChange(of: value) { _, newValue in
                if AmountParser.parse(text) != newValue {
                    text = newValue.map(AmountParser.string(from:)) ?? ""
                }
            }
    }
}
