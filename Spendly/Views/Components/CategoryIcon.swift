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
            .background(color.opacity(0.16), in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
            .accessibilityHidden(true)
    }
}

extension CategoryIcon {
    init(category: ExpenseCategory?, size: CGFloat = 40) {
        self.init(
            iconName: category?.iconName ?? "questionmark",
            color: category?.color ?? .gray,
            size: size
        )
    }
}

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
        .accessibilityValue(Text(progress.formatted(.percent.precision(.fractionLength(0)))))
    }
}

struct Chip: View {
    let text: String
    var icon: String?
    var isSelected = false
    var tint: Color = .accentColor

    var body: some View {
        HStack(spacing: 5) {
            if let icon {
                Image(systemName: icon).font(.caption.weight(.semibold))
            }
            Text(text).font(.subheadline.weight(.medium))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .background(isSelected ? tint : Color(.tertiarySystemFill), in: Capsule())
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
    @Binding var value: Double?
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
