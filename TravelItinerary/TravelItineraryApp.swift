//
//  TravelItineraryApp.swift
//  TravelItinerary
//
//  Created by Sanithu on 2026-08-28.
//

import SwiftUI
import SwiftData

@main
struct TravelItineraryApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Trip.self,
            Day.self,
            Activity.self,
            Place.self,
            User.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        let container: ModelContainer
        do {
            container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }

        // Missing seed data shouldn't stop the app from launching, so log and carry on.
        do {
            try SeedLoader().loadIfNeeded(into: container.mainContext)
        } catch {
            print("Seeding failed: \(error)")
        }
        return container
    }()

    /// Admin state shared by every screen through the environment.
    @State private var session = SessionStore()

    init() {
        // First launch only: store the demo admin PIN so admin mode can be unlocked (see KeychainStore).
        do {
            try KeychainStore().setDefaultPINIfNeeded()
        } catch {
            print("Couldn't set the default admin PIN: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
        }
        .modelContainer(sharedModelContainer)
    }
}
