import SwiftData
import SwiftUI

/// Lists the user's trips.
struct TripListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Trip.startDate) private var trips: [Trip]
    @State private var isAddingTrip = false

    var body: some View {
        NavigationStack {
            Group {
                if trips.isEmpty {
                    ContentUnavailableView {
                        Label("No Trips", systemImage: "suitcase")
                    } description: {
                        Text("Plan your first trip to get started.")
                    } actions: {
                        Button("New Trip") { isAddingTrip = true }
                    }
                } else {
                    // Still a List (not a ScrollView) so swipe-to-delete keeps working on the cards.
                    List {
                        ForEach(trips) { trip in
                            NavigationLink(value: trip) {
                                TripCard(trip: trip)
                            }
                            // The card is the whole row, so it doesn't need the list's chevron.
                            .navigationLinkIndicatorVisibility(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        }
                        .onDelete(perform: deleteTrips)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Trips")
            .navigationDestination(for: Trip.self) { trip in
                ItineraryView(trip: trip)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("New Trip", systemImage: "plus") { isAddingTrip = true }
                }
            }
            .sheet(isPresented: $isAddingTrip) {
                NewTripView()
            }
        }
    }

    private func deleteTrips(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(trips[index])
        }
    }
}

#Preview(traits: .sampleData) {
    TripListView()
}

#Preview("No Trips") {
    TripListView()
        .modelContainer(for: Trip.self, inMemory: true)
}
