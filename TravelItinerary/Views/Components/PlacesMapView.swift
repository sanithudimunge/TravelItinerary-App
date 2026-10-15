import MapKit
import SwiftData
import SwiftUI

/// Map mode of the Places tab: every place as a category-icon pin; tapping one shows a small card.
struct PlacesMapView: View {
    /// The places to show, already filtered by the Places tab. Ones without a valid coordinate are skipped.
    let places: [Place]
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedID: PersistentIdentifier?

    @ScaledMetric(relativeTo: .body) private var pinSize: CGFloat = 34

    private var selectedPlace: Place? {
        places.first { $0.persistentModelID == selectedID }
    }

    /// Pairs each place with its coordinate up front, so the map content doesn't need optional checks.
    private var pins: [(place: Place, coordinate: CLLocationCoordinate2D)] {
        places.compactMap { place in place.coordinate.map { (place, $0) } }
    }

    var body: some View {
        // `.automatic` frames all the pins when the map first appears.
        Map(position: $position) {
            ForEach(pins, id: \.place.persistentModelID) { pin in
                Annotation(pin.place.name, coordinate: pin.coordinate) {
                    Button {
                        withAnimation { selectedID = pin.place.persistentModelID }
                    } label: {
                        pinIcon(for: pin.place)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(pin.place.name)
                    .accessibilityAddTraits(pin.place.persistentModelID == selectedID ? .isSelected : [])
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let selectedPlace {
                PlaceMapCard(place: selectedPlace) {
                    withAnimation { selectedID = nil }
                }
                .padding()
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        // If filtering removes the selected place, close its card.
        .onChange(of: places.map(\.persistentModelID)) { _, ids in
            if let selectedID, !ids.contains(selectedID) {
                self.selectedID = nil
            }
        }
    }

    private func pinIcon(for place: Place) -> some View {
        let isSelected = place.persistentModelID == selectedID
        return Image(systemName: place.category.symbolName)
            .font(.subheadline.weight(.semibold))
            // The system background colour stays readable on the accent colour in light and dark mode.
            .foregroundStyle(Color(.systemBackground))
            .frame(width: pinSize, height: pinSize)
            .background(Color.accentColor, in: Circle())
            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
            .shadow(radius: 2)
            .scaleEffect(isSelected ? 1.25 : 1)
    }
}

/// The card shown over the map for the selected place.
private struct PlaceMapCard: View {
    let place: Place
    var onClose: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(place.name)
                    .font(.headline)
                if let address = place.address {
                    Text(address)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Label(place.category.rawValue.capitalized, systemImage: place.category.symbolName)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                // Goes to the detail screen via the Places tab's navigationDestination(for: Place.self).
                NavigationLink(value: place) {
                    Text("Details")
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
            }
            Spacer(minLength: 0)
            // A closure rather than `action: onClose`: passing the stored closure directly
            // makes Xcode's preview compiler report an ambiguous call.
            Button("Close", systemImage: "xmark.circle.fill") { onClose() }
                .labelStyle(.iconOnly)
                .font(.title2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

#Preview(traits: .sampleData) {
    @Previewable @Query(sort: \Place.name) var places: [Place]
    NavigationStack {
        PlacesMapView(places: places)
    }
}
