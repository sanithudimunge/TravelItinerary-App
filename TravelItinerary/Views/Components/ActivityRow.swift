import SwiftData
import SwiftUI

/// A row summarising one activity.
struct ActivityRow: View {
    let activity: Activity

    /// Size of the category icon's circle. Scales with Dynamic Type so the symbol stays inside it.
    @ScaledMetric(relativeTo: .headline) private var iconSize: CGFloat = 36
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Icon beside the text normally; icon above the text at accessibility sizes, where a side-by-side
    /// icon leaves the text so little width that words break mid-word. ViewThatFits isn't used here
    /// because it measures text unwrapped, so any long title would switch the layout even at normal sizes.
    private var layout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
    }

    var body: some View {
        layout {
            Image(systemName: activity.category.symbolName)
                .foregroundStyle(Color.accentColor)
                .frame(width: iconSize, height: iconSize)
                .background(Color("AccentSoft"), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(activity.title)
                    .font(.headline)
                Text(timeText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                locationLabel
                    .font(.footnote)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private var timeText: String {
        let start = activity.start.formatted(date: .omitted, time: .shortened)
        guard let end = activity.end else { return start }
        return "\(start) – \(end.formatted(date: .omitted, time: .shortened))"
    }

    /// The place name, or a warning when the activity can't be shown on the map.
    @ViewBuilder
    private var locationLabel: some View {
        if let place = activity.place {
            if activity.hasLocation {
                Text(place.name)
                    .foregroundStyle(.secondary)

            } else {
                Label("\(place.name) has an invalid location", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color("Warning"))
            }
        } else {
            Label("No location", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(Color("Warning"))
        }
    }
}

#Preview(traits: .sampleData) {
    @Previewable @Query var trips: [Trip]
    @Previewable @Query(filter: #Predicate<Place> { $0.name == "Adam's Peak" }) var brokenPlaces: [Place]
    List {
        if let day = trips.first?.orderedDays.first {
            ForEach(day.ordered) { activity in
                ActivityRow(activity: activity)
            }
        }
        // Not inserted into the store; these only show the two warning states.
        ActivityRow(activity: Activity(title: "Free afternoon", category: .entertainment, start: .now))
        ActivityRow(activity: Activity(title: "Climb Adam's Peak", category: .sight, start: .now, place: brokenPlaces.first))
    }
}
