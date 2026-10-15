import SwiftData
import SwiftUI

/// Picks a trip, then a day, and adds the place to the end of that day as a new activity.
struct AddToTripView: View {
    let place: Place
    /// Called after a successful add with a short confirmation, e.g. "Added to Day 2 of Sri Lanka Highlights."
    var onAdded: (String) -> Void

    @Query(sort: \Trip.startDate) private var trips: [Trip]
    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                ForEach(trips) { trip in
                    NavigationLink(value: trip) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(trip.title)
                            Text("\(trip.startDate.formatted(date: .abbreviated, time: .omitted)) – \(trip.endDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .overlay {
                if trips.isEmpty {
                    ContentUnavailableView("No Trips", systemImage: "suitcase", description: Text("Create a trip first, then add places to it."))
                }
            }
            .navigationTitle("Add to Trip")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Trip.self) { trip in
                dayList(for: trip)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    /// Second step: the chosen trip's days.
    private func dayList(for trip: Trip) -> some View {
        List {
            if let errorMessage {
                InlineError(message: errorMessage)
            }
            ForEach(trip.orderedDays) { day in
                Button {
                    add(to: day, in: trip)
                } label: {
                    HStack {
                        DayChip(day: day, isSelected: false)
                        Spacer()
                        Text("^[\(day.activities.count) activity](inflect: true)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(.primary)
            }
        }
        .navigationTitle(trip.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func add(to day: Day, in trip: Trip) {
        let activity = Activity(title: place.name, category: place.category, start: suggestedStart(on: day), place: place)
        do throws(ItineraryError) {
            // Reuses the itinerary's own add, so validation and "goes to the end of the day" match the editor.
            try ItineraryViewModel(trip: trip).add(activity, to: day)
            onAdded("Added to Day \(day.number) of \(trip.title).")
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// A start time after the day's last activity: its end, or an hour after its start if it has no end.
    /// An empty day starts at 9:00. The time can be changed later in the activity editor.
    private func suggestedStart(on day: Day) -> Date {
        if let last = day.ordered.last {
            return last.end ?? last.start.addingTimeInterval(3600)
        }
        return Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: day.date) ?? day.date
    }
}

#Preview(traits: .sampleData) {
    @Previewable @Query(filter: #Predicate<Place> { $0.name == "Galle Fort" }) var places: [Place]
    if let place = places.first {
        AddToTripView(place: place) { _ in }
    }
}
