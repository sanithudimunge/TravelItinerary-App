import SwiftData
import SwiftUI

/// Admin form for adding a new place or editing an existing one.
struct PlaceEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// The place being edited, or `nil` when adding a new one.
    private let place: Place?

    @State private var name: String
    @State private var latitude: Double
    @State private var longitude: Double
    @State private var category: ActivityCategory
    @State private var address: String
    @State private var isVerified: Bool

    init(place: Place? = nil) {
        self.place = place
        // Start from the place's current values, or blanks for a new place.
        _name = State(initialValue: place?.name ?? "")
        _latitude = State(initialValue: place?.latitude ?? 0)
        _longitude = State(initialValue: place?.longitude ?? 0)
        _category = State(initialValue: place?.category ?? .sight)
        _address = State(initialValue: place?.address ?? "")
        _isVerified = State(initialValue: place?.isVerified ?? false)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Problems that stop the form from being saved. These match the checks in `Place.issues`.
    private var validationErrors: [String] {
        var errors: [String] = []
        if trimmedName.isEmpty || trimmedName == "Unnamed place" {
            errors.append("Enter a name.")
        }
        if !(-90...90).contains(latitude) {
            errors.append("Latitude must be between −90 and 90.")
        }
        if !(-180...180).contains(longitude) {
            errors.append("Longitude must be between −180 and 180.")
        }
        return errors
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Name", text: $name)
                    Picker("Category", selection: $category) {
                        ForEach(ActivityCategory.allCases, id: \.self) { category in
                            Label(category.rawValue.capitalized, systemImage: category.symbolName)
                                .tag(category)
                        }
                    }
                    TextField("Address", text: $address)
                }

                Section("Location") {
                    // .numbersAndPunctuation includes the minus sign, which .decimalPad lacks.
                    LabeledContent("Latitude") {
                        TextField("Latitude", value: $latitude, format: .number)
                            .keyboardType(.numbersAndPunctuation)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Longitude") {
                        TextField("Longitude", value: $longitude, format: .number)
                            .keyboardType(.numbersAndPunctuation)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section {
                    Toggle("Verified", isOn: $isVerified)
                }

                if !validationErrors.isEmpty {
                    Section {
                        ForEach(validationErrors, id: \.self) { error in
                            InlineError(message: error)
                        }
                    }
                }
            }
            .navigationTitle(place == nil ? "New Place" : "Edit Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!validationErrors.isEmpty)
                }
            }
        }
    }

    private func save() {
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let savedAddress = trimmedAddress.isEmpty ? nil : trimmedAddress

        if let place {
            place.name = trimmedName
            place.latitude = latitude
            place.longitude = longitude
            place.category = category
            place.address = savedAddress
            place.isVerified = isVerified
            // The admin has now picked a real category, so the "unknown category" issue is resolved.
            place.invalidCategory = nil
        } else {
            let newPlace = Place(
                name: trimmedName,
                latitude: latitude,
                longitude: longitude,
                category: category,
                isVerified: isVerified,
                address: savedAddress
            )
            modelContext.insert(newPlace)
        }
        dismiss()
    }
}

#Preview("New Place", traits: .sampleData) {
    PlaceEditorView()
}

#Preview("Edit Place", traits: .sampleData) {
    @Previewable @Query(filter: #Predicate<Place> { $0.name == "Adam's Peak" }) var places: [Place]
    if let place = places.first {
        PlaceEditorView(place: place)
    }
}
