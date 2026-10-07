import SwiftData
import SwiftUI

/// Browses and reviews places.
///
/// Everyone can browse and search. In admin mode the list also shows a review queue,
/// and places can be added, edited, and deleted.
struct PlacesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SessionStore.self) private var session
    @Query(sort: \Place.name) private var places: [Place]
    @State private var searchText = ""
    @State private var editingPlace: Place?
    @State private var isAddingPlace = false
    /// Size of the category icon's circle. Scales with Dynamic Type so the symbol stays inside it.
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 32

    /// Places matching the search text by name or address. An empty search matches everything.
    private var filteredPlaces: [Place] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return places }
        return places.filter { place in
            place.name.localizedStandardContains(query)
                || (place.address?.localizedStandardContains(query) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if session.isAdmin {
                    adminSections
                }

                Section {
                    ForEach(filteredPlaces) { place in
                        placeRow(place)
                    }
                    .onDelete { offsets in
                        delete(offsets.map { filteredPlaces[$0] })
                    }
                    // Swipe-to-delete is admin-only.
                    .deleteDisabled(!session.isAdmin)
                } header: {
                    // Travellers only see this one section, so it doesn't need a title.
                    if session.isAdmin {
                        Text("All places")
                    }
                }
            }
            .overlay {
                if filteredPlaces.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .searchable(text: $searchText, prompt: "Search places")
            .navigationTitle("Places")
            .toolbar {
                if session.isAdmin {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Add Place", systemImage: "plus") { isAddingPlace = true }
                    }
                }
            }
            .sheet(isPresented: $isAddingPlace) {
                PlaceEditorView()
            }
            .sheet(item: $editingPlace) { place in
                PlaceEditorView(place: place)
            }
        }
    }

    /// The summary line and the review queue, shown only in admin mode.
    @ViewBuilder
    private var adminSections: some View {
        let needingReview = filteredPlaces.filter(\.needsReview)

        Section {
            Text("^[\(places.count) place](inflect: true) · \(places.filter(\.needsReview).count) need review")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }

        if !needingReview.isEmpty {
            Section("Needs review") {
                ForEach(needingReview) { place in
                    reviewRow(place)
                }
            }
        }
    }

    /// A place in the review queue: its name, then each issue with Fix and Remove buttons.
    private func reviewRow(_ place: Place) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(place.name)
                .font(.headline)
            ForEach(place.issues, id: \.self) { issue in
                // Issue and buttons on one line when they fit; at large Dynamic Type sizes
                // the buttons move below the issue instead of squeezing its text.
                ViewThatFits(in: .horizontal) {
                    HStack {
                        issueLabel(issue)
                        Spacer()
                        reviewButtons(for: place)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        issueLabel(issue)
                        reviewButtons(for: place)
                    }
                }
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
        // The issue Labels would otherwise pull the separator's start in to their text; keep it full width.
        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
    }

    private func issueLabel(_ issue: String) -> some View {
        Label(issue, systemImage: "exclamationmark.triangle.fill")
            .font(.footnote)
            .foregroundStyle(Color("Warning"))
    }

    private func reviewButtons(for place: Place) -> some View {
        HStack {
            // Fix opens the editor, where every issue type can be corrected.
            Button("Fix") { editingPlace = place }
                .buttonStyle(.bordered)
                // Several rows have "Fix" and "Remove" buttons, so VoiceOver needs the place name to tell them apart.
                .accessibilityLabel("Fix \(place.name)")
            Button("Remove", role: .destructive) { delete([place]) }
                .buttonStyle(.bordered)
                .accessibilityLabel("Remove \(place.name)")
        }
    }

    private func placeRow(_ place: Place) -> some View {
        // Badge at the trailing edge when it fits; at large Dynamic Type sizes it moves under the address.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                placeIcon(place)
                placeDetails(place)
                Spacer()
                placeBadge(place)
            }
            HStack(alignment: .top, spacing: 12) {
                placeIcon(place)
                VStack(alignment: .leading, spacing: 6) {
                    placeDetails(place)
                    placeBadge(place)
                }
                Spacer(minLength: 0)
            }
        }
        // Start every row's separator at the leading edge, so all rows match whatever they contain.
        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
        // Only admins can open the editor; for everyone else the row is read-only.
        .contentShape(Rectangle())
        .onTapGesture {
            if session.isAdmin { editingPlace = place }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(session.isAdmin ? .isButton : [])
    }

    private func placeIcon(_ place: Place) -> some View {
        Image(systemName: place.category.symbolName)
            .foregroundStyle(Color.accentColor)
            .frame(width: iconSize, height: iconSize)
            .background(Color("AccentSoft"), in: Circle())
            .accessibilityHidden(true)
    }

    private func placeDetails(_ place: Place) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(place.name)
            if let address = place.address {
                Text(address)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func placeBadge(_ place: Place) -> some View {
        if place.needsReview {
            StatusBadge(status: .needsReview)
        } else if place.isVerified {
            StatusBadge(status: .verified)
        }
    }

    private func delete(_ placesToDelete: [Place]) {
        // Activities at a deleted place keep existing; the relationship's .nullify rule clears their place.
        for place in placesToDelete {
            modelContext.delete(place)
        }
    }
}

#Preview("Traveller", traits: .sampleData) {
    PlacesView()
        .environment(SessionStore())
}

#Preview("Admin", traits: .sampleData) {
    let session = SessionStore()
    session.isAdmin = true
    return PlacesView()
        .environment(session)
}
