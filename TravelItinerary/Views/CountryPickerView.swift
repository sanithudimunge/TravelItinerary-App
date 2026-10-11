import SwiftUI

/// A searchable list for choosing one or more countries.
struct CountryPickerView: View {
    /// Selected ISO region codes, kept in the order they were picked so flags show in that order.
    @Binding var selection: [String]
    @State private var searchText = ""

    private var filteredCodes: [String] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return Country.allCodes }
        return Country.allCodes.filter { Country.name(for: $0).localizedStandardContains(query) }
    }

    var body: some View {
        List {
            // Chosen countries stay at the top, so it's easy to see and undo picks without scrolling.
            if !selection.isEmpty && searchText.isEmpty {
                Section("Selected") {
                    ForEach(selection, id: \.self) { code in
                        row(code)
                    }
                }
            }
            Section(searchText.isEmpty ? "All countries" : "Results") {
                ForEach(filteredCodes, id: \.self) { code in
                    row(code)
                }
            }
        }
        .overlay {
            if filteredCodes.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .searchable(text: $searchText, prompt: "Search countries")
        .navigationTitle("Countries")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ code: String) -> some View {
        let isSelected = selection.contains(code)
        return Button {
            toggle(code)
        } label: {
            HStack(spacing: 12) {
                Text(Country.flag(for: code))
                    .font(.title2)
                    .accessibilityHidden(true)
                Text(Country.name(for: code))
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
                }
            }
        }
        // Buttons in a List take the accent colour; country names should read as normal text.
        .tint(.primary)
        // VoiceOver announces "Selected" instead of the decorative checkmark.
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func toggle(_ code: String) {
        if let index = selection.firstIndex(of: code) {
            selection.remove(at: index)
        } else {
            selection.append(code)
        }
    }
}

#Preview {
    @Previewable @State var selection = ["LK"]
    NavigationStack {
        CountryPickerView(selection: $selection)
    }
}
