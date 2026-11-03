import SwiftUI

/// The icon picker shared by the category and subcategory editors.
struct CategoryIconGrid: View {
    @Binding var selection: String
    let tint: Color

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 8), spacing: 6) {
            ForEach(CategoryPalette.icons, id: \.self) { icon in
                let isSelected = selection == icon
                Button {
                    selection = icon
                } label: {
                    Image(systemName: icon)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(isSelected ? tint : Color.primary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .background(
                            Color(.tertiarySystemFill),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                        .overlay {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(tint, lineWidth: 2)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(icon)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(.vertical, 6)
    }
}
