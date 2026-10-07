import SwiftUI

/// App settings, including entering and leaving admin mode.
struct SettingsView: View {
    @Environment(SessionStore.self) private var session
    @State private var isShowingPIN = false

    var body: some View {
        NavigationStack {
            Form {
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
