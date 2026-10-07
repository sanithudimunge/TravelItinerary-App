import SwiftData
import SwiftUI

/// Shows a trip's days and the selected day's activities.
struct ItineraryView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: ItineraryViewModel
    @State private var isAddingActivity = false
    @State private var editingActivity: Activity?
    @State private var isShowingMap = false

    init(trip: Trip) {
        _viewModel = State(initialValue: ItineraryViewModel(trip: trip))
    }

    var body: some View {
        List {
            Section {
                dayPicker
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            if let day = viewModel.selectedDay {
                activitiesSection(for: day)
            }
        }
        .navigationTitle(viewModel.trip.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Activity", systemImage: "plus") { isAddingActivity = true }
                    .disabled(viewModel.selectedDay == nil)
            }
            // Toggles the list's edit mode, which shows the reorder and delete controls.
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
            // Shows the selected day's stops and route on a map.
            ToolbarItem(placement: .topBarTrailing) {
                Button("Map", systemImage: "map") { isShowingMap = true }
                    .disabled(viewModel.selectedDay == nil)
            }
        }
        .navigationDestination(isPresented: $isShowingMap) {
            DayRouteMapView(viewModel: viewModel)
        }
        .sheet(isPresented: $isAddingActivity) {
            if let day = viewModel.selectedDay {
                ActivityEditorView(day: day, viewModel: viewModel)
            }
        }
        .sheet(item: $editingActivity) { activity in
            if let day = activity.day ?? viewModel.selectedDay {
                ActivityEditorView(day: day, activity: activity, viewModel: viewModel)
            }
        }
    }

    private var dayPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.trip.orderedDays) { day in
                    Button {
                        viewModel.selectedDay = day
                    } label: {
                        DayChip(day: day, isSelected: day == viewModel.selectedDay)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private func activitiesSection(for day: Day) -> some View {
        let activities = day.ordered
        Section(day.date.formatted(date: .complete, time: .omitted)) {
            if activities.isEmpty {
                ContentUnavailableView(
                    "No Activities",
                    systemImage: "calendar.badge.plus",
                    description: Text("Nothing planned for day \(day.number) yet.")
                )
            } else {
                ForEach(activities) { activity in
                    Button {
                        editingActivity = activity
                    } label: {
                        ActivityRow(activity: activity)
                    }
                    .tint(.primary)
                    // By default the separator starts at the title text, past the category icon.
                    // Start it at the row's leading edge instead, matching PlacesView.
                    .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                    .contextMenu {
                        // Only offered when the activity has a valid location to hand off.
                        if let stop = activity.snapshot() {
                            Menu("Open in…", systemImage: "arrow.up.forward.app") {
                                Button("Apple Maps") { MapsLauncher.openPlaceInAppleMaps(stop) }
                                Button("Google Maps") { MapsLauncher.openPlaceInGoogleMaps(stop) }
                            }
                        }
                    }
                }
                .onDelete { offsets in
                    delete(offsets.map { activities[$0] }, from: day)
                }
                // Drag handles appear in edit mode; the view model saves the new order via `sortIndex`.
                .onMove { source, destination in
                    viewModel.move(from: source, to: destination)
                }
            }
        }
    }

    private func delete(_ activities: [Activity], from day: Day) {
        for activity in activities {
            // Remove from the relationship first so the list updates before the context saves.
            day.activities.removeAll { $0 == activity }
            modelContext.delete(activity)
        }
    }
}

#Preview(traits: .sampleData) {
    @Previewable @Query var trips: [Trip]
    if let trip = trips.first {
        NavigationStack {
            ItineraryView(trip: trip)
        }
    }
}
