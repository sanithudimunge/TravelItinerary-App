import CoreLocation
import Foundation
import SwiftData

/// A real-world location that activities can be attached to.
@Model
nonisolated final class Place: Mappable {
    var name: String
    var latitude: Double
    var longitude: Double
    var category: ActivityCategory
    var isVerified: Bool
    var address: String?
    /// The original category text from the seed file when it didn't match `ActivityCategory`, otherwise `nil`.
    var invalidCategory: String? = nil
    /// The country the place is in, as an ISO region code (see `Country`), or `nil` if unknown.
    var countryCode: String? = nil
    /// Marked by the user with the heart button. Defaults to `false`, so existing places load unchanged.
    var isFavourite: Bool = false

    /// Activities at this place. Deleting the place sets their `place` to `nil`.
    @Relationship(deleteRule: .nullify, inverse: \Activity.place)
    var activities: [Activity] = []

    /// The place's coordinate, or `nil` if latitude/longitude are out of range.
    var coordinate: CLLocationCoordinate2D? {
        guard (-90...90).contains(latitude), (-180...180).contains(longitude) else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Human-readable data-quality problems with this place.
    var issues: [String] {
        var issues: [String] = []
        if !(-90...90).contains(latitude) {
            issues.append("Latitude is outside −90…90")
        }
        if !(-180...180).contains(longitude) {
            issues.append("Longitude is outside −180…180")
        }
        // "Unnamed place" is the fallback PlaceDTO uses when the seed entry has no name.
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty || trimmedName == "Unnamed place" {
            issues.append("Name is missing")
        }
        if let invalidCategory {
            issues.append("Unknown category “\(invalidCategory)”")
        }
        return issues
    }

    /// Whether an admin should look at this place before it's relied on.
    var needsReview: Bool {
        !issues.isEmpty
    }

    init(name: String, latitude: Double, longitude: Double, category: ActivityCategory, isVerified: Bool = false, address: String? = nil, countryCode: String? = nil) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.category = category
        self.isVerified = isVerified
        self.address = address
        self.countryCode = countryCode
    }
}
