import SwiftUI

/// A map annotation marking a stop.
struct StopAnnotationView: View {
    /// The stop's 1-based position in the day.
    let number: Int
    /// The day's colour from `DayPalette`.
    let color: Color

    /// Grows with Dynamic Type so the number never overflows the circle.
    @ScaledMetric(relativeTo: .caption) private var diameter: CGFloat = 28

    var body: some View {
        Text("\(number)")
            .font(.caption.weight(.bold))
            // The system background is white in light mode and black in dark mode. The day colours
            // are lighter in dark mode, where white text only reached about 2:1 contrast.
            .foregroundStyle(Color(.systemBackground))
            .frame(width: diameter, height: diameter)
            .background(color, in: Circle())
            // A ring in the background colour separates the pin from the map in either appearance.
            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
            .shadow(radius: 2)
            .accessibilityLabel("Stop \(number)")
    }
}

#Preview {
    HStack {
        ForEach(1...5, id: \.self) { day in
            StopAnnotationView(number: day, color: DayPalette.color(forDay: day))
        }
    }
    .padding()
}
