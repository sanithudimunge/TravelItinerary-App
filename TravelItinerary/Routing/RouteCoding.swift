import CoreLocation
import Foundation

// Codable conformances for the route types, so a calculated `DayRoute` can be saved as JSON
// for offline use (see `Day.cachedRouteData`).
//
// `CLLocationCoordinate2D` isn't Codable, so coordinates are written as `{ "latitude", "longitude" }`
// pairs via `CodableCoordinate` rather than adding a retroactive conformance to a CoreLocation type.

/// A plain, Codable stand-in for `CLLocationCoordinate2D`.
nonisolated struct CodableCoordinate: Codable {
    let latitude: Double
    let longitude: Double

    init(_ coordinate: CLLocationCoordinate2D) {
        latitude = coordinate.latitude
        longitude = coordinate.longitude
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

nonisolated extension StopSnapshot: Codable {
    private enum CodingKeys: String, CodingKey {
        case name, coordinate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            name: try container.decode(String.self, forKey: .name),
            coordinate: try container.decode(CodableCoordinate.self, forKey: .coordinate).coordinate
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(CodableCoordinate(coordinate), forKey: .coordinate)
    }
}

nonisolated extension RouteLeg: Codable {
    private enum CodingKeys: String, CodingKey {
        case from, to, travelTime, distance, mode, path
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            from: try container.decode(StopSnapshot.self, forKey: .from),
            to: try container.decode(StopSnapshot.self, forKey: .to),
            travelTime: try container.decode(TimeInterval.self, forKey: .travelTime),
            distance: try container.decode(CLLocationDistance.self, forKey: .distance),
            mode: try container.decode(TransportMode.self, forKey: .mode),
            path: try container.decode([CodableCoordinate].self, forKey: .path).map(\.coordinate)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(from, forKey: .from)
        try container.encode(to, forKey: .to)
        try container.encode(travelTime, forKey: .travelTime)
        try container.encode(distance, forKey: .distance)
        try container.encode(mode, forKey: .mode)
        try container.encode(path.map(CodableCoordinate.init), forKey: .path)
    }
}

nonisolated extension DayRoute: Codable {
    private enum CodingKeys: String, CodingKey {
        case legs
    }

    // Only the legs are stored; the totals are recalculated by `init(legs:)` so they can't get out of sync.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(legs: try container.decode([RouteLeg].self, forKey: .legs))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(legs, forKey: .legs)
    }
}
