import SwiftUI

/// The app's top level: one tab per main area.
struct RootView: View {
    /// The app's tabs, so code (like Today's "Plan a Trip" button) can switch between them.
    enum AppTab: Hashable {
        case today, trips, places, settings
    }

    private var preferences = AppPreferences()
    @State private var selectedTab: AppTab = .today

    var body: some View {
        // Each tab's view has its own NavigationStack, so navigation in one tab doesn't affect the others.
        TabView(selection: $selectedTab) {
            Tab("Today", systemImage: "sun.max", value: .today) {
                TodayView(onPlanTrip: { selectedTab = .trips })
            }
            Tab("Trips", systemImage: "suitcase", value: .trips) {
                TripListView()
            }
            Tab("Places", systemImage: "mappin.and.ellipse", value: .places) {
                PlacesView()
            }
            Tab("Settings", systemImage: "gearshape", value: .settings) {
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
