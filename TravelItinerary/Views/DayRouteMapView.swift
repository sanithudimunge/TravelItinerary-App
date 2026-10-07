import MapKit
import SwiftData
import SwiftUI

/// Maps the selected day's stops and route.
struct DayRouteMapView: View {
    let viewModel: ItineraryViewModel
    @State private var position: MapCameraPosition = .automatic
    @State private var isLoading = false
    /// The legs sheet is always shown while this screen is; it's turned off on the way out so it closes with it.
    @State private var isShowingLegs = true

    /// The day's stops that have a valid location, in visiting order.
    private var stops: [StopSnapshot] {
        viewModel.selectedDay?.mappableStops ?? []
    }

    /// The day's colour, used for the pins and route lines.
    private var tint: Color {
        DayPalette.color(forDay: viewModel.selectedDay?.number ?? 1)
    }

    var body: some View {
        Map(position: $position) {
            // Pins are numbered in visiting order. Offsets are stable ids here: the list doesn't change on this screen.
            ForEach(Array(stops.enumerated()), id: \.offset) { index, stop in
                Annotation(stop.name, coordinate: stop.coordinate) {
                    StopAnnotationView(number: index + 1, color: tint)
                }
            }

            if let route = viewModel.route {
                ForEach(Array(route.legs.enumerated()), id: \.offset) { _, leg in
                    // Walking legs are dashed so they stand out from driving ones.
                    MapPolyline(coordinates: leg.path)
                        .stroke(tint, style: StrokeStyle(lineWidth: 5, lineCap: .round, dash: leg.mode == .walking ? [6, 8] : []))
                }
            }
        }
        .safeAreaInset(edge: .top) {
            // Hidden while loading, since the flag still describes the previous result until loading finishes.
            if viewModel.isShowingCachedRoute && !isLoading {
                offlineBanner
            }
        }
        .navigationTitle(viewModel.selectedDay.map { "Day \($0.number) Route" } ?? "Route")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu("Open in…", systemImage: "arrow.up.forward.app") {
                    Button("Apple Maps") { MapsLauncher.openDayInAppleMaps(stops) }
                    Button("Google Maps") { MapsLauncher.openDayInGoogleMaps(stops) }
                }
                .disabled(stops.isEmpty)
            }
        }
        .sheet(isPresented: $isShowingLegs) {
            legsSheet
                .presentationDetents([.height(160), .medium, .large])
                // Keep the map usable behind the sheet when it's small.
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                // The sheet belongs to this screen, so it can't be swiped away on its own.
                .interactiveDismissDisabled()
        }
        .task {
            await loadRoute()
        }
        .onDisappear {
            isShowingLegs = false
        }
    }

    /// Shown above the map when the route came from the offline cache.
    private var offlineBanner: some View {
        Label("Offline: showing the last saved route", systemImage: "wifi.slash")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color("Warning"))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            // A rounded rectangle rather than a capsule: at large text sizes the banner wraps onto
            // several lines, and a capsule's round ends would cut into the text.
            .background(Color("WarningSoft"), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            // Keep the banner inside the screen margins so long text wraps instead of running off the edge.
            .padding(.horizontal)
            .padding(.top, 8)
    }

    /// The bottom sheet: totals, any error, and one row per leg.
    private var legsSheet: some View {
        List {
            if isLoading {
                ProgressView("Finding route…")
            }
            if let errorMessage = viewModel.errorMessage {
                InlineError(message: errorMessage)
            }
            if let route = viewModel.route {
                Section {
                    LabeledContent("Total", value: "\(LegRow.timeText(route.totalTime)) · \(LegRow.distanceText(route.totalDistance))")
                        .font(.headline)
                }
                Section("Legs") {
                    ForEach(Array(route.legs.enumerated()), id: \.offset) { _, leg in
                        LegRow(leg: leg)
                    }
                }
            }
            if !isLoading && stops.count < 2 {
                Text("Add at least two activities with a location to see a route.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Loads the route, then fits the camera to it.
    private func loadRoute() async {
        // Clear the previous day's result so it isn't shown while this one loads.
        viewModel.route = nil
        viewModel.errorMessage = nil
        fitCamera(to: stops.map(\.coordinate))

        isLoading = true
        await viewModel.loadRoute()
        isLoading = false

        // Road paths can bulge past the stops, so refit using every point on the route.
        if let route = viewModel.route {
            fitCamera(to: route.legs.flatMap(\.path) + stops.map(\.coordinate))
        }
    }

    /// Moves the camera to show all the given coordinates with some padding.
    private func fitCamera(to coordinates: [CLLocationCoordinate2D]) {
        guard !coordinates.isEmpty else { return }
        let points = coordinates.map(MKMapPoint.init)
        let minX = points.map(\.x).min() ?? 0
        let maxX = points.map(\.x).max() ?? 0
        let minY = points.map(\.y).min() ?? 0
        let maxY = points.map(\.y).max() ?? 0
        let rect = MKMapRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)

        // Pad by 25% on each side, with a minimum so a single stop isn't zoomed in to street level.
        let padding = max(max(rect.width, rect.height) * 0.25, 2_000)
        withAnimation {
            position = .rect(rect.insetBy(dx: -padding, dy: -padding))
        }
    }
}

#Preview(traits: .sampleData) {
    @Previewable @Query var trips: [Trip]
    if let trip = trips.first {
        NavigationStack {
            DayRouteMapView(viewModel: ItineraryViewModel(trip: trip))
        }
    }
}
