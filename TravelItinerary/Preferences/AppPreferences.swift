import Foundation
import SwiftUI

/// Which app "Open in…" hands directions to.
enum MapApp: String, CaseIterable, Identifiable {
    case appleMaps
    case googleMaps
    /// Offer both apps every time instead of opening one directly.
    case askEachTime

    var id: Self { self }

    var title: String {
        switch self {
        case .appleMaps: "Apple Maps"
        case .googleMaps: "Google Maps"
        case .askEachTime: "Ask Each Time"
        }
    }
}

/// The unit distances are shown in.
enum DistanceUnit: String, CaseIterable, Identifiable {
    case kilometres
    case miles

    var id: Self { self }

    var title: String {
        switch self {
        case .kilometres: "Kilometres"
        case .miles: "Miles"
        }
    }

    var unitLength: UnitLength {
        switch self {
        case .kilometres: .kilometers
        case .miles: .miles
        }
    }

    /// Miles where road distances are normally given in miles (US and UK), kilometres elsewhere.
    static var localeDefault: DistanceUnit {
        switch Locale.current.measurementSystem {
        case .us, .uk: .miles
        default: .kilometres
        }
    }

    /// Formats a distance in metres in this unit, e.g. "2.4 km" or "1.5 mi".
    func format(_ metres: Double) -> String {
        Measurement(value: metres, unit: UnitLength.meters)
            .converted(to: unitLength)
            // `.asProvided` keeps the chosen unit; the default `.road` usage would switch back to the locale's.
            .formatted(.measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(0...1))))
    }
}

/// Light, dark, or following the system setting.
enum Appearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: Self { self }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    /// The value for `.preferredColorScheme`; `nil` means follow the system.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// The user's app settings, stored in UserDefaults through `@AppStorage`.
///
/// Declare it in any view (`private var preferences = AppPreferences()`). As a `DynamicProperty`,
/// SwiftUI watches the `@AppStorage` values inside it, so the view updates when a setting changes
/// anywhere in the app. Keys and defaults live here so every screen agrees on them.
struct AppPreferences: DynamicProperty {
    @AppStorage("preferredMapApp") var preferredMapApp: MapApp = .askEachTime
    @AppStorage("distanceUnit") var distanceUnit: DistanceUnit = .localeDefault
    @AppStorage("appearance") var appearance: Appearance = .system

    // Bindings for Settings pickers. The `$` projections are only reachable from inside this type.
    var preferredMapAppBinding: Binding<MapApp> { $preferredMapApp }
    var distanceUnitBinding: Binding<DistanceUnit> { $distanceUnit }
    var appearanceBinding: Binding<Appearance> { $appearance }
}
