import CoreLocation
import SwiftUI

/// A row describing one leg of a route: mode, stops, travel time, and distance.
struct LegRow: View {
    let leg: RouteLeg

    /// Width of the mode icon column. Scales with Dynamic Type so the icon isn't clipped.
    @ScaledMetric(relativeTo: .subheadline) private var iconWidth: CGFloat = 28

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: leg.mode.symbolName)
                .frame(width: iconWidth)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(leg.from.name) → \(leg.to.name)")
                    .font(.subheadline)
                Text("\(Self.timeText(leg.travelTime)) · \(Self.distanceText(leg.distance))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// Formats a duration like "1 hr, 25 min".
    static func timeText(_ time: TimeInterval) -> String {
        Duration.seconds(time).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }

    /// Formats a distance in the user's preferred units, e.g. "2.4 km" or "1.5 mi".
    static func distanceText(_ distance: CLLocationDistance) -> String {
        Measurement(value: distance, unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .road))
    }
}

#Preview {
    let from = StopSnapshot(name: "Galle Face Green", coordinate: CLLocationCoordinate2D(latitude: 6.9255, longitude: 79.8450))
    let to = StopSnapshot(name: "Galle Face Hotel", coordinate: CLLocationCoordinate2D(latitude: 6.9212, longitude: 79.8458))
    List {
        LegRow(leg: RouteLeg(from: from, to: to, travelTime: 420, distance: 550, mode: .walking, path: []))
        LegRow(leg: RouteLeg(from: to, to: from, travelTime: 5_100, distance: 24_000, mode: .driving, path: []))
    }
}
