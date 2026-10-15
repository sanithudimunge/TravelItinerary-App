import SwiftUI

/// The app's top level: one tab per main area.
struct RootView: View {
    private var preferences = AppPreferences()

    var body: some View {
        // Each tab's view has its own NavigationStack, so navigation in one tab doesn't affect the others.
        TabView {
            Tab("Trips", systemImage: "suitcase") {
                TripListView()
            }
            Tab("Places", systemImage: "mappin.and.ellipse") {
                PlacesView()
            }
            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
        // Applied at the root so every tab and sheet follows it. `nil` (System) follows the device setting.
        .preferredColorScheme(preferences.appearance.colorScheme)
    }
}

#Preview(traits: .sampleData) {
    RootView()
        .environment(SessionStore())
}
