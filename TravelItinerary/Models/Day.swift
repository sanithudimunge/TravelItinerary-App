import Foundation
import SwiftData

/// A single day within a trip, holding that day's activities.
@Model
nonisolated final class Day {
    var date: Date
    var number: Int
    var trip: Trip?

    @Relationship(deleteRule: .cascade, inverse: \Activity.day)
    var activities: [Activity]

    // Offline route cache.
    //
    // Stored as two optional properties on Day rather than a separate CachedRoute model because:
    // - each day has at most one route, so there's nothing to look up by `dayID`;
    // - the cache is deleted along with its day, with no extra relationship or cleanup;
    // - SwiftData adds new optional properties to an existing store without migration code.

    /// The last successfully calculated route for this day, JSON-encoded. `nil` until one is calculated.
    var cachedRouteData: Data? = nil
    /// When `cachedRouteData` was saved.
    var cachedRouteSavedAt: Date? = nil

    /// Activities sorted by `sortIndex`.
    var ordered: [Activity] {
        activities.sorted { $0.sortIndex < $1.sortIndex }
    }

    /// Sendable snapshots of the day's activities that have a valid location, in order.
    var mappableStops: [StopSnapshot] {
        ordered.compactMap { $0.snapshot() }
    }

    /// Saves a freshly calculated route so it can be shown later without a connection.
    func cacheRoute(_ route: DayRoute) {
        // Encoding only fails for invalid values (e.g. NaN), in which case there's simply no cache.
        cachedRouteData = try? JSONEncoder().encode(route)
        cachedRouteSavedAt = .now
    }

    /// The saved route, but only if it still goes through exactly these stops in this order.
    /// After the day's activities change, an old route would be misleading, so it's ignored.
    func cachedRoute(for stops: [StopSnapshot]) -> DayRoute? {
        guard let cachedRouteData,
              let route = try? JSONDecoder().decode(DayRoute.self, from: cachedRouteData),
              let first = route.legs.first else { return nil }
        let routeStops = [first.from] + route.legs.map(\.to)
        return routeStops == stops ? route : nil
    }

    init(date: Date, number: Int, activities: [Activity] = []) {
        self.date = date
        self.number = number
        self.activities = activities
    }
}
