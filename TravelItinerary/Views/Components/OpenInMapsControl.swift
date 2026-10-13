import SwiftUI

/// The "Open in…" control, following the preferred map app from Settings.
///
/// With a specific app chosen it's a single button that opens that app directly;
/// with "Ask Each Time" it's a menu offering Apple Maps and Google Maps.
/// Works in toolbars and context menus alike.
struct OpenInMapsControl: View {
    let target: MapsLauncher.Target
    private var preferences = AppPreferences()

    init(target: MapsLauncher.Target) {
        self.target = target
    }

    var body: some View {
        switch preferences.preferredMapApp {
        case .askEachTime:
            Menu("Open in…", systemImage: "arrow.up.forward.app") {
                Button(MapApp.appleMaps.title) { MapsLauncher.open(target, in: .appleMaps) }
                Button(MapApp.googleMaps.title) { MapsLauncher.open(target, in: .googleMaps) }
            }
        case let app:
            Button("Open in \(app.title)", systemImage: "arrow.up.forward.app") {
                MapsLauncher.open(target, in: app)
            }
        }
    }
}

#Preview {
    let stop = StopSnapshot(name: "Galle Face Green", coordinate: .init(latitude: 6.9255, longitude: 79.8450))

    /// A throwaway defaults store with the map preference set, so each row shows one state
    /// without touching the app's real settings. `.defaultAppStorage` points @AppStorage at it.
    func store(_ app: MapApp) -> UserDefaults {
        let defaults = UserDefaults(suiteName: "OpenInMapsControlPreview.\(app.rawValue)") ?? .standard
        defaults.set(app.rawValue, forKey: "preferredMapApp")
        return defaults
    }

    return VStack(alignment: .leading, spacing: 16) {
        ForEach(MapApp.allCases) { app in
            LabeledContent(app.title) {
                OpenInMapsControl(target: .place(stop))
                    .defaultAppStorage(store(app))
            }
        }
    }
    .buttonStyle(.bordered)
    .padding()
}
