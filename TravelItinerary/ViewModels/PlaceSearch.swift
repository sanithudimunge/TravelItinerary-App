import Foundation
import MapKit
import Observation

/// Searches Apple Maps for places that aren't in the app yet.
@Observable
final class PlaceSearch {
    /// Results for `query`, in Apple Maps' relevance order.
    private(set) var results: [MKMapItem] = []
    /// The search text these results belong to, so stale results can be told apart from current ones.
    private(set) var query: String?
    private(set) var isSearching = false
    private(set) var errorMessage: String?

    /// Runs a natural-language search such as "tea factory Nuwara Eliya".
    func search(_ text: String) async {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = text
        request.resultTypes = [.pointOfInterest, .address]

        isSearching = true
        defer { isSearching = false }

        do {
            let response = try await MKLocalSearch(request: request).start()
            // The user may have typed something else while this was in flight; drop the old answer.
            guard !Task.isCancelled else { return }
            results = response.mapItems
            errorMessage = nil
        } catch let error as MKError where error.code == .placemarkNotFound {
            // MapKit reports "no matches" as an error; to the user it's just an empty result.
            results = []
            errorMessage = nil
        } catch {
            guard !Task.isCancelled else { return }
            results = []
            errorMessage = "Apple Maps search isn't available right now. Check your connection and try again."
        }
        query = text
    }

    /// Forgets the current results, e.g. when the search text changes.
    func clear() {
        results = []
        query = nil
        errorMessage = nil
    }
}

extension MKMapItem {
    /// A best guess at the app's category for this Apple Maps result, used as the suggested choice.
    var suggestedCategory: ActivityCategory {
        switch pointOfInterestCategory {
        case .restaurant, .cafe, .bakery, .brewery, .winery, .foodMarket:
            .food
        case .hotel, .campground:
            .stay
        case .airport, .publicTransport, .carRental, .gasStation, .evCharger, .parking:
            .transport
        case .theater, .movieTheater, .nightlife, .stadium, .amusementPark, .aquarium, .zoo:
            .entertainment
        default:
            .sight
        }
    }

    /// One-line address for lists, e.g. "Sri Dalada Veediya, Kandy".
    var displayAddress: String? {
        address?.shortAddress ?? address?.fullAddress
    }
}

// Main actor: `Place` is nonisolated (it's a SwiftData model), so without this these helpers would be
// nonisolated too and couldn't read the main-actor `MKMapItem` helpers above. They're only used from views.
@MainActor
extension Place {
    /// A new, unverified place built from an Apple Maps result.
    /// User-added places start unverified so an administrator can review them.
    static func fromMapItem(_ item: MKMapItem, category: ActivityCategory) -> Place {
        let coordinate = item.location.coordinate
        return Place(
            name: item.name ?? "Unnamed place",
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            category: category,
            isVerified: false,
            address: item.displayAddress,
            // In Swift the country is a Locale.Region; its identifier is the ISO code, e.g. "LK".
            countryCode: item.addressRepresentations?.region?.identifier
        )
    }

    /// Whether this place is (almost) the same spot with the same name as the result,
    /// so saving the result again would only create a duplicate.
    func matches(_ item: MKMapItem) -> Bool {
        guard let coordinate else { return false }
        let here = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return name.localizedCaseInsensitiveCompare(item.name ?? "") == .orderedSame
            && here.distance(from: item.location) < 100
    }
}
