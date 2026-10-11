import SwiftData
import SwiftUI

/// Creates a new trip and generates one day per date in its range.
struct NewTripView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var startDate = Calendar.current.startOfDay(for: .now)
    @State private var endDate = Calendar.current.startOfDay(for: .now)
    @State private var errorMessage: String?
    /// ISO region codes chosen in CountryPickerView, in the order picked.
    @State private var countryCodes: [String] = []

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                DatePicker("Starts", selection: $startDate, displayedComponents: .date)
                // The picker's range is the first safeguard against an end date before the start date.
                // Trip.validateDates in save() is a second one that keeps the rule in the model.
                DatePicker("Ends", selection: $endDate, in: startDate..., displayedComponents: .date)

                Section {
                    NavigationLink {
                        CountryPickerView(selection: $countryCodes)
                    } label: {
                        LabeledContent("Countries") {
                            // Flags for up to three picks, then a count, so the row stays short.
                            if countryCodes.isEmpty {
                                Text("None")
                            } else if countryCodes.count <= 3 {
                                Text(countryCodes.map(Country.flag(for:)).joined(separator: " "))
                                    .accessibilityLabel(countryCodes.map(Country.name(for:)).formatted(.list(type: .and)))
                            } else {
                                Text("\(countryCodes.count) countries")
                            }
                        }
                    }
                } footer: {
                    Text("Their flags appear on the trip's card.")
                }

                if let errorMessage {
                    Section {
                        InlineError(message: errorMessage)
                    }
                }
            }
            .navigationTitle("New Trip")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: startDate) { _, newStart in
                if endDate < newStart {
                    endDate = newStart
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(trimmedTitle.isEmpty)
                }
            }
        }
    }

    private func save() {
        do throws(ItineraryError) {
            try Trip.validateDates(start: startDate, end: endDate)
            let trip = Trip(title: trimmedTitle, startDate: startDate, endDate: endDate, countryCodes: countryCodes)
            modelContext.insert(trip)
            trip.generateDays()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview(traits: .sampleData) {
    NewTripView()
}
