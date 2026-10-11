import Foundation
import SwiftData

/// Populates the store with bundled sample data on first launch.
struct SeedLoader {
    enum SeedError: Error {
        case missingResource(String)
    }

    /// Inserts seed data if the store is empty.
    func loadIfNeeded(into context: ModelContext) throws {
        // Places only exist once seeding has run, so their presence means there's nothing to do.
        guard try context.fetchCount(FetchDescriptor<Place>()) == 0 else { return }

        guard let url = Bundle.main.url(forResource: "places", withExtension: "json") else {
            throw SeedError.missingResource("places.json")
        }
        let data = try Data(contentsOf: url)
        let places = try JSONDecoder().decode([PlaceDTO].self, from: data).map { $0.makeModel() }
        places.forEach { context.insert($0) }

        insertSampleTrip(into: context, places: places)
        try context.save()
    }

    /// One planned activity in the sample trip, referring to a seeded place by name.
    private struct SampleActivity {
        let day: Int
        let title: String
        let hour: Int
        let minute: Int
        let hours: Double?
        let placeName: String
    }

    /// Adds a three-day sample trip starting today, so the itinerary screens have content.
    private func insertSampleTrip(into context: ModelContext, places: [Place]) {
        let placesByName = Dictionary(places.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        guard let end = calendar.date(byAdding: .day, value: 2, to: start) else { return }

        let trip = Trip(title: "Sri Lanka Highlights", startDate: start, endDate: end, countryCodes: ["LK"])
        context.insert(trip)
        trip.generateDays()

        let plan = [
            SampleActivity(day: 1, title: "Arrive in Colombo", hour: 8, minute: 0, hours: 1, placeName: "Bandaranaike International Airport"),
            SampleActivity(day: 1, title: "Gangaramaya Temple", hour: 11, minute: 0, hours: 1.5, placeName: "Gangaramaya Temple"),
            SampleActivity(day: 1, title: "Lunch at Ministry of Crab", hour: 13, minute: 30, hours: 1.5, placeName: "Ministry of Crab"),
            SampleActivity(day: 1, title: "Sunset walk", hour: 17, minute: 30, hours: 1, placeName: "Galle Face Green"),
            SampleActivity(day: 1, title: "Check in", hour: 19, minute: 0, hours: nil, placeName: "Galle Face Hotel"),
            SampleActivity(day: 2, title: "Train to Kandy", hour: 7, minute: 0, hours: 3, placeName: "Colombo Fort Railway Station"),
            SampleActivity(day: 2, title: "Temple of the Tooth", hour: 14, minute: 0, hours: 1.5, placeName: "Temple of the Sacred Tooth Relic"),
            SampleActivity(day: 2, title: "Botanic Gardens", hour: 16, minute: 0, hours: 1.5, placeName: "Royal Botanic Gardens, Peradeniya"),
            SampleActivity(day: 3, title: "Train to Ella", hour: 8, minute: 0, hours: 7, placeName: "Kandy Railway Station"),
            SampleActivity(day: 3, title: "Nine Arch Bridge", hour: 16, minute: 0, hours: 1, placeName: "Nine Arch Bridge"),
            SampleActivity(day: 3, title: "Dinner at Café Chill", hour: 19, minute: 0, hours: 1.5, placeName: "Café Chill"),
        ]

        let days = trip.orderedDays
        for (index, item) in plan.enumerated() {
            guard days.indices.contains(item.day - 1),
                  let place = placesByName[item.placeName] else { continue }
            let day = days[item.day - 1]
            let startTime = calendar.date(bySettingHour: item.hour, minute: item.minute, second: 0, of: day.date) ?? day.date
            let activity = Activity(
                title: item.title,
                category: place.category,
                start: startTime,
                end: item.hours.map { startTime.addingTimeInterval($0 * 3600) },
                sortIndex: index,
                place: place
            )
            day.activities.append(activity)
        }
    }
}
