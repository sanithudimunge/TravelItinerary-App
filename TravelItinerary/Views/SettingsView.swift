import SwiftUI

/// App settings: maps, units, appearance, app info, and admin mode.
struct SettingsView: View {
    @Environment(SessionStore.self) private var session
    @State private var isShowingPIN = false
    private var preferences = AppPreferences()

    /// Version and build from Info.plist, e.g. "1.0 (1)".
    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "–"
        let build = info?["CFBundleVersion"] as? String ?? "–"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Open Directions In", selection: preferences.preferredMapAppBinding) {
                        ForEach(MapApp.allCases) { app in
                            Text(app.title).tag(app)
                        }
                    }
                } header: {
                    Text("Maps")
                } footer: {
                    Text("Used by every “Open in…” button. Choose Ask Each Time to pick between Apple Maps and Google Maps each time.")
                }

                Section("Units") {
                    Picker("Distance", selection: preferences.distanceUnitBinding) {
                        ForEach(DistanceUnit.allCases) { unit in
                            Text(unit.title).tag(unit)
                        }
                    }
                }

                Section("Appearance") {
                    Picker("Appearance", selection: preferences.appearanceBinding) {
                        ForEach(Appearance.allCases) { appearance in
                            Text(appearance.title).tag(appearance)
                        }
                    }
                    // Three short options read best side by side.
                    .pickerStyle(.segmented)
                }

                Section("About") {
                    LabeledContent("Version", value: versionText)
                }

                // Kept last: it's the least-used setting and only matters to administrators.
                Section {
                    if session.isAdmin {
                        Button("Lock admin mode", systemImage: "lock.fill", role: .destructive) {
                            session.lock()
                        }
                    } else {
                        Button("Administrator mode", systemImage: "lock.open") {
                            isShowingPIN = true
                        }
                    }
                } header: {
                    Text("Administrator")
                } footer: {
                    Text(session.isAdmin
                         ? "Admin mode is unlocked. You can review, edit, and remove shared places."
                         : "Unlock with the admin PIN to manage shared places.")
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $isShowingPIN) {
                AdminPINView()
            }
        }
    }
}

#Preview {
    SettingsView()
        .environment(SessionStore())
}
