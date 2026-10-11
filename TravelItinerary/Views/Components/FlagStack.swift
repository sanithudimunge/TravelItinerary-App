import SwiftUI

/// A fanned pile of circles, each holding a country's flag emoji, used as a trip card's cover.
///
/// Each circle overlaps the one before it, with the outer circles sitting slightly lower,
/// like a hand of cards. The flags themselves are kept straight.
struct FlagStack: View {
    /// ISO region codes, in the order to show them. Later flags sit on top of earlier ones.
    let countryCodes: [String]
    /// Flags shown before the rest are summarised as "+N". Three keeps the fan inside the card.
    var maxVisible = 3

    /// Circle size. Scales with Dynamic Type, capped so the cover still fits the card at large sizes.
    @ScaledMetric(relativeTo: .largeTitle) private var scaledDiameter: CGFloat = 96
    private var diameter: CGFloat { min(scaledDiameter, 120) }

    /// Each circle shifts this far sideways from the previous one. A bit over half the diameter
    /// keeps them stacked while leaving enough of each flag uncovered to recognise it.
    private var step: CGFloat { diameter * 0.62 }

    var body: some View {
        let items = coverItems

        ZStack {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                // Distance from the middle of the fan: negative on the left, positive on the right.
                let position = CGFloat(index) - CGFloat(items.count - 1) / 2

                // Circles stay upright so the flags read straight; only their positions form the fan.
                circle(for: item)
                    .offset(x: position * step, y: abs(position) * diameter * 0.08)
            }
        }
        // Reserve the fan's full width so the card can centre it.
        .frame(width: diameter + step * CGFloat(max(items.count - 1, 0)), height: diameter * 1.15)
        // VoiceOver reads the country names rather than each emoji ("flag: Sri Lanka", …).
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    /// What goes in each circle, left to right.
    private enum CoverItem {
        case flag(String)
        case more(Int)
        case globe
    }

    private var coverItems: [CoverItem] {
        // Trips created before countries existed, or saved without any, get a neutral globe.
        guard !countryCodes.isEmpty else { return [.globe] }
        let visible = countryCodes.prefix(maxVisible).map(CoverItem.flag)
        let hiddenCount = countryCodes.count - visible.count
        return hiddenCount > 0 ? visible + [.more(hiddenCount)] : visible
    }

    @ViewBuilder
    private func circle(for item: CoverItem) -> some View {
        Group {
            switch item {
            case .flag(let code):
                // Sized from `diameter`, which follows Dynamic Type, so the emoji fills the circle at any text size.
                Text(Country.flag(for: code))
                    .font(.system(size: diameter * 0.55))
            case .more(let count):
                Text("+\(count)")
                    .font(.title.bold())
                    .foregroundStyle(.secondary)
            case .globe:
                Image(systemName: "globe")
                    .font(.system(size: diameter * 0.45))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: diameter, height: diameter)
        .background(Color(.systemBackground), in: Circle())
        .overlay(Circle().strokeBorder(Color(.separator), lineWidth: 1))
        // A soft shadow lifts each circle off the one beneath it.
        .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
    }

    private var accessibilityText: String {
        countryCodes.isEmpty ? "No countries" : countryCodes.map(Country.name(for:)).formatted(.list(type: .and))
    }
}

#Preview {
    VStack(spacing: 40) {
        FlagStack(countryCodes: ["LK"])
        FlagStack(countryCodes: ["LK", "IN", "MV"])
        FlagStack(countryCodes: ["FR", "IT", "ES", "PT", "DE", "NL"])
        FlagStack(countryCodes: [])
    }
    .padding()
}
