import SwiftData
import SwiftUI

/// The day at a glance: what's next on an active trip, a countdown to the next trip, or a prompt to plan one.
struct TodayView: View {
    /// Switches the app to the Trips tab (used by "Plan a Trip").
    var onPlanTrip: () -> Void

    @Query(sort: \Trip.startDate) private var trips: [Trip]
    /// The view model for "Today's Route", created when the button is tapped.
    @State private var routeViewModel: ItineraryViewModel?

    var body: some View {
        NavigationStack {
            // Re-evaluates every minute so "Next up" moves on as activities finish.
            TimelineView(.everyMinute) { context in
                content(now: context.date)
            }
            .navigationTitle("Today")
            .navigationDestination(for: Trip.self) { trip in
                ItineraryView(trip: trip)
            }
            .navigationDestination(isPresented: Binding(get: { routeViewModel != nil }, set: { if !$0 { routeViewModel = nil } })) {
                if let routeViewModel {
                    DayRouteMapView(viewModel: routeViewModel)
                }
            }
        }
    }

    // MARK: Choosing what to show

    @ViewBuilder
    private func content(now: Date) -> some View {
        if let trip = activeTrip(on: now) {
            activeTripView(trip, now: now)
        } else if let trip = upcomingTrip(after: now) {
            countdownView(trip, now: now)
        } else {
            ContentUnavailableView {
                Label(trips.isEmpty ? "No Trips Yet" : "No Upcoming Trips", systemImage: "sun.max")
            } description: {
                Text("Plan a trip and each day's activities will show up here.")
            } actions: {
                Button("Plan a Trip", action: onPlanTrip)
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    /// The first trip whose date range includes today. Whole days are compared, so times don't matter.
    private func activeTrip(on now: Date) -> Trip? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        return trips.first { trip in
            calendar.startOfDay(for: trip.startDate) <= today && today <= calendar.startOfDay(for: trip.endDate)
        }
    }

    /// The soonest trip that hasn't started yet (`trips` is sorted by start date).
    private func upcomingTrip(after now: Date) -> Trip? {
        let today = Calendar.current.startOfDay(for: now)
        return trips.first { Calendar.current.startOfDay(for: $0.startDate) > today }
    }

    // MARK: Active trip

    @ViewBuilder
    private func activeTripView(_ trip: Trip, now: Date) -> some View {
        let today = trip.orderedDays.first { Calendar.current.isDate($0.date, inSameDayAs: now) }
        let activities = today?.ordered ?? []
        // The next activity is the first one that hasn't finished; an activity without an end time
        // counts as finished once it has started.
        let next = activities.first { ($0.end ?? $0.start) >= now }

        List {
            Section {
                NavigationLink(value: trip) {
                    HStack(spacing: 12) {
                        if let today {
                            DayChip(day: today, isSelected: true)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(trip.title)
                                .font(.headline)
                            if let today {
                                Text("Day \(today.number) of \(trip.dayCount)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            if let today {
                if let next {
                    Section {
                        NextActivityCard(activity: next, day: today, now: now)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                } else {
                    Section {
                        Label(activities.isEmpty ? "Nothing planned for today." : "That's everything for today.", systemImage: "checkmark.circle")
                            .foregroundStyle(.secondary)
                    }
                }

                restOfDaySections(activities: activities, next: next)

                if today.mappableStops.count >= 2 {
                    Section {
                        Button("Today's Route", systemImage: "map") {
                            let viewModel = ItineraryViewModel(trip: trip)
                            viewModel.selectedDay = today
                            routeViewModel = viewModel
                        }
                    }
                }
            } else {
                // A trip's days are generated when it's created, so this only happens with unusual data.
                Section {
                    Text("Today isn't one of this trip's days.")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    /// Everything except the "next" activity: what's still to come, then what's already done.
    @ViewBuilder
    private func restOfDaySections(activities: [Activity], next: Activity?) -> some View {
        let nextIndex = next.flatMap { activities.firstIndex(of: $0) }
        let later = nextIndex.map { Array(activities[($0 + 1)...]) } ?? []
        let earlier = nextIndex.map { Array(activities[..<$0]) } ?? activities

        if !later.isEmpty {
            Section("Later Today") {
                ForEach(later) { ActivityRow(activity: $0) }
            }
        }
        if !earlier.isEmpty {
            Section("Earlier Today") {
                ForEach(earlier) { activity in
                    ActivityRow(activity: activity)
                        // Dimmed because it's already happened; VoiceOver reads it as normal.
                        .opacity(0.6)
                }
            }
        }
    }

    // MARK: Upcoming trip

    private func countdownView(_ trip: Trip, now: Date) -> some View {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: trip.startDate)).day ?? 0

        return List {
            Section {
                NavigationLink(value: trip) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(days == 1 ? "\(trip.title) starts tomorrow" : "\(trip.title) starts in \(days) days")
                            .font(.title2.bold())
                        TripCard(trip: trip)
                    }
                    .padding(.vertical, 4)
                }
                .navigationLinkIndicatorVisibility(.hidden)
                .listRowBackground(Color.clear)
            }
        }
    }
}

/// The large card for the next activity: when, where, how long to get there, and a button to navigate.
private struct NextActivityCard: View {
    let activity: Activity
    let day: Day
    let now: Date
    private var preferences = AppPreferences()

    init(activity: Activity, day: Day, now: Date) {
        self.activity = activity
        self.day = day
        self.now = now
    }

    private var tint: Color { DayPalette.color(forDay: day.number) }
    private var isHappeningNow: Bool { activity.start <= now }

    private var timeText: String {
        let start = activity.start.formatted(date: .omitted, time: .shortened)
        guard let end = activity.end else { return start }
        return "\(start) – \(end.formatted(date: .omitted, time: .shortened))"
    }

    /// The leg arriving at this activity, taken from the day's saved route.
    /// Only used if the saved route still matches today's stops (see `Day.cachedRoute(for:)`).
    private var arrivingLeg: RouteLeg? {
        let stops = day.mappableStops
        guard let route = day.cachedRoute(for: stops), let snapshot = activity.snapshot() else { return nil }
        // Leg i runs from stop i to stop i + 1, so the leg into stop k is leg k - 1.
        guard let index = stops.firstIndex(of: snapshot), index > 0, index - 1 < route.legs.count else { return nil }
        return route.legs[index - 1]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(isHappeningNow ? "Happening Now" : "Next Up")
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(tint)

            Label {
                Text(activity.title)
                    .font(.title2.bold())
            } icon: {
                Image(systemName: activity.category.symbolName)
                    .foregroundStyle(tint)
            }

            detailLabel(timeText, systemImage: "clock")
                .font(.headline)

            if let place = activity.place {
                detailLabel(place.name, systemImage: "mappin.and.ellipse")
                    .foregroundStyle(.secondary)
            }

            if let leg = arrivingLeg {
                detailLabel("\(LegRow.timeText(leg.travelTime)) · \(preferences.distanceUnit.format(leg.distance)) from \(leg.from.name)",
                            systemImage: leg.mode.symbolName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let snapshot = activity.snapshot() {
                OpenInMapsControl(target: .place(snapshot))
                    .buttonStyle(.borderedProminent)
                    .tint(tint)
                    // The system background colour reads well on every day colour in light and dark mode,
                    // and keeps the icon from picking up the app's accent colour.
                    .foregroundStyle(Color(.systemBackground))
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        // A soft wash of the day's colour, matching the day chips; the colour has a dark-mode variant.
        .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(tint.opacity(0.4), lineWidth: 1))
    }

    /// A label whose icon is always the day colour. Labels in a List otherwise tint icons with the
    /// app's accent colour, which clashed with the card.
    private func detailLabel(_ text: String, systemImage: String) -> some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
        }
    }
}

#Preview("Active trip", traits: .sampleData) {
    // The sample trip starts today, so this shows the active-trip layout.
    TodayView(onPlanTrip: {})
}

#Preview("Next up") {
    // A trip happening today with activities in one and three hours, so the "Next Up" card always shows.
    let container = try! ModelContainer(for: Trip.self, Day.self, Activity.self, Place.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let today = Calendar.current.startOfDay(for: .now)
    let trip = Trip(title: "Colombo Weekend", startDate: today, endDate: today, countryCodes: ["LK"])
    container.mainContext.insert(trip)
    trip.generateDays()
    let temple = Place(name: "Gangaramaya Temple", latitude: 6.9166, longitude: 79.8564, category: .sight, countryCode: "LK")
    let green = Place(name: "Galle Face Green", latitude: 6.9255, longitude: 79.8450, category: .sight, countryCode: "LK")
    if let day = trip.days.first {
        day.activities.append(Activity(title: "Gangaramaya Temple", category: .sight, start: .now.addingTimeInterval(3_600), end: .now.addingTimeInterval(7_200), sortIndex: 0, place: temple))
        day.activities.append(Activity(title: "Sunset walk", category: .sight, start: .now.addingTimeInterval(10_800), sortIndex: 1, place: green))
    }
    return TodayView(onPlanTrip: {})
        .modelContainer(container)
}

#Preview("Upcoming trip") {
    // An in-memory store with one trip two weeks away, to show the countdown card.
    let container = try! ModelContainer(for: Trip.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let start = Calendar.current.date(byAdding: .day, value: 14, to: Calendar.current.startOfDay(for: .now)) ?? .now
    let end = Calendar.current.date(byAdding: .day, value: 4, to: start) ?? start
    let trip = Trip(title: "Kandy & Ella", startDate: start, endDate: end, countryCodes: ["LK"])
    container.mainContext.insert(trip)
    trip.generateDays()
    return TodayView(onPlanTrip: {})
        .modelContainer(container)
}

#Preview("No trips") {
    TodayView(onPlanTrip: {})
        .modelContainer(for: Trip.self, inMemory: true)
}
