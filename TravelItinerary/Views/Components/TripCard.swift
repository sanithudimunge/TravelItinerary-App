import SwiftData
import SwiftUI

/// A 4:3 card summarising a trip: country flags, title, dates, and length.
struct TripCard: View {
    let trip: Trip
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                // At accessibility sizes the text can't fit a fixed 4:3 shape, so the card grows to fit it.
                content
                    .padding(20)
            } else {
                // A clear 4:3 base sets the card's shape; the content is laid out on top of it.
                Color.clear
                    .aspectRatio(4 / 3, contentMode: .fit)
                    .overlay {
                        content
                            .padding(20)
                    }
            }
        }
        .frame(maxWidth: .infinity)
        .background(background, in: shape)
        .overlay(shape.strokeBorder(Color(.separator).opacity(0.5), lineWidth: 1))
        .contentShape(shape)
        .accessibilityElement(children: .combine)
    }

    /// The flag cover centred in the space above, trip details pinned to the bottom.
    private var content: some View {
        VStack(alignment: .leading, spacing: 6) {
            FlagStack(countryCodes: trip.countryCodes)
                // Take all the space the text doesn't need and centre the cover in it.
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, 10)
            Text(trip.title)
                .font(.title2.bold())
                .foregroundStyle(.primary)
            Text("\(trip.startDate.formatted(date: .abbreviated, time: .omitted)) – \(trip.endDate.formatted(date: .abbreviated, time: .omitted))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("^[\(trip.dayCount) day](inflect: true)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    /// A soft wash of the accent colour; both colours have dark-mode variants.
    private var background: LinearGradient {
        LinearGradient(
            colors: [Color("AccentSoft"), Color(.secondarySystemGroupedBackground)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

#Preview(traits: .sampleData) {
    @Previewable @Query var trips: [Trip]
    if let trip = trips.first {
        TripCard(trip: trip)
            .padding()
    }
}
