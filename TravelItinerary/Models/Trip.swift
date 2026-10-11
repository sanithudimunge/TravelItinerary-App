import Foundation
import SwiftData

/// A planned journey owned by a user, made up of an ordered set of days.
@Model
nonisolated final class Trip {
    var id: UUID
    var title: String
    var startDate: Date
    var endDate: Date
    var owner: User?
    /// Countries visited, as ISO region codes (see `Country`), in the order the user picked them.
    /// Defaults to empty so existing trips load without a migration.
    var countryCodes: [String] = []

    @Relationship(deleteRule: .cascade, inverse: \Day.trip)
    var days: [Day]

    /// Number of calendar days the trip spans, counting both the first and last day.
    var dayCount: Int {
        // Compare start-of-day values so the times of day don't change the count.
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        return (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1
    }

    /// Days sorted by day number.
    var orderedDays: [Day] {
        days.sorted { $0.number < $1.number }
    }

    /// Throws `.invalidDateRange` if the trip would end on an earlier day than it starts.
    static func validateDates(start: Date, end: Date) throws(ItineraryError) {
        // Compare whole days so a same-day trip is valid whatever the times are.
        let calendar = Calendar.current
        guard calendar.startOfDay(for: end) >= calendar.startOfDay(for: start) else {
            throw .invalidDateRange
        }
    }

    /// Replaces `days` with one empty `Day` for each date from `startDate` to `endDate`.
    func generateDays() {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        guard dayCount > 0 else {
            days = []
            return
        }
        days = (0..<dayCount).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: start).map { Day(date: $0, number: offset + 1) }
        }
    }

    init(id: UUID = UUID(), title: String, startDate: Date, endDate: Date, countryCodes: [String] = [], owner: User? = nil, days: [Day] = []) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.countryCodes = countryCodes
        self.owner = owner
        self.days = days
    }
}
