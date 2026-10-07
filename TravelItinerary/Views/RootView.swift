import SwiftUI

/// The app's top level: one tab per main area.
struct RootView: View {
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
    }
}

#Preview(traits: .sampleData) {
    RootView()
        .environment(SessionStore())
}
