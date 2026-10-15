import MapKit
import SwiftData
import SwiftUI

/// Everything about one place: details, a small map, and actions to open it, add it to a trip, or favourite it.
struct PlaceDetailView: View {
    let place: Place
    @Environment(SessionStore.self) private var session
    @State private var isAddingToTrip = false
    @State private var isEditing = false
    /// Confirmation shown after "Add to Trip" succeeds.
    @State private var addedMessage: String?

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(place.name)
                        .font(.title2.bold())
                    Label(place.category.rawValue.capitalized, systemImage: place.category.symbolName)
                        .foregroundStyle(.secondary)
                    if place.needsReview {
                        StatusBadge(status: .needsReview)
                    } else if place.isVerified {
                        StatusBadge(status: .verified)
                    }
                }
                .padding(.vertical, 4)

                if let address = place.address {
                    LabeledContent("Address", value: address)
                }
                if let code = place.countryCode {
                    LabeledContent("Country", value: "\(Country.flag(for: code)) \(Country.name(for: code))")
                }
            }

            if let coordinate = place.coordinate {
                Section {
                    // A fixed preview: panning it inside a scrolling list would fight the scroll.
                    // "Open in Maps" below is the way to explore further.
                    Map(initialPosition: .region(MKCoordinateRegion(center: coordinate, latitudinalMeters: 1_500, longitudinalMeters: 1_500)), interactionModes: []) {
                        Marker(place.name, systemImage: place.category.symbolName, coordinate: coordinate)
                    }
                    .frame(height: 200)
                    .listRowInsets(EdgeInsets())
                    .accessibilityLabel("Map showing \(place.name)")
                }

                Section {
                    OpenInMapsControl(target: .place(StopSnapshot(name: place.name, coordinate: coordinate)))
                    Button("Add to Trip", systemImage: "calendar.badge.plus") {
                        isAddingToTrip = true
                    }
                }
            } else {
                Section {
                    // Activities need a valid location (see Activity.validate), so these actions are hidden.
                    Label("This place's location is being reviewed, so it can't be opened in Maps or added to a trip yet.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color("Warning"))
                }
            }
        }
        .navigationTitle(place.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(place.isFavourite ? "Remove from Favourites" : "Add to Favourites",
                       systemImage: place.isFavourite ? "heart.fill" : "heart") {
                    place.isFavourite.toggle()
                }
                .tint(place.isFavourite ? .pink : nil)
            }
            if session.isAdmin {
                ToolbarItem(placement: .secondaryAction) {
                    Button("Edit", systemImage: "pencil") { isEditing = true }
                }
            }
        }
        .sheet(isPresented: $isAddingToTrip) {
            AddToTripView(place: place) { message in
                addedMessage = message
            }
        }
        .sheet(isPresented: $isEditing) {
            PlaceEditorView(place: place)
        }
        .alert("Added", isPresented: Binding(get: { addedMessage != nil }, set: { if !$0 { addedMessage = nil } })) {
            Button("OK") {}
        } message: {
            Text(addedMessage ?? "")
        }
    }
}

#Preview(traits: .sampleData) {
    @Previewable @Query(filter: #Predicate<Place> { $0.name == "Galle Fort" }) var places: [Place]
    if let place = places.first {
        NavigationStack {
            PlaceDetailView(place: place)
        }
        .environment(SessionStore())
    }
}
