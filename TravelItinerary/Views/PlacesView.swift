import MapKit
import SwiftData
import SwiftUI

/// Browses, searches, and reviews places.
///
/// Everyone can browse places as a list or map, filter them, favourite them, open a place's details,
/// and find new places on Apple Maps. In admin mode the list also shows a review queue,
/// and places can be added, edited, and deleted.
struct PlacesView: View {
    /// List or map presentation, chosen with the segmented control at the top.
    private enum DisplayMode: String, CaseIterable, Identifiable {
        case list, map
        var id: Self { self }
        var title: String { self == .list ? "List" : "Map" }
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(SessionStore.self) private var session
    @Query(sort: \Place.name) private var places: [Place]
    @State private var searchText = ""
    @State private var mode: DisplayMode = .list
    @State private var editingPlace: Place?
    @State private var isAddingPlace = false

    // Filters. `nil` means "all".
    @State private var categoryFilter: ActivityCategory?
    @State private var countryFilter: String?
    @State private var favouritesOnly = false

    /// Apple Maps search for places that aren't in the app.
    @State private var search = PlaceSearch()
    /// The Apple Maps result the user tapped, waiting for them to pick a category to save it under.
    @State private var pendingResult: MKMapItem?

    /// Size of the category icon's circle. Scales with Dynamic Type so the symbol stays inside it.
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 32

    private var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filtersActive: Bool {
        categoryFilter != nil || countryFilter != nil || favouritesOnly
    }

    /// Places matching the search text (name or address) and every active filter.
    private var filteredPlaces: [Place] {
        let query = trimmedQuery
        return places.filter { place in
            // Separate checks rather than one long && chain keep this quick for the compiler to type-check.
            if favouritesOnly && !place.isFavourite { return false }
            if let categoryFilter, place.category != categoryFilter { return false }
            if let countryFilter, place.countryCode != countryFilter { return false }
            guard !query.isEmpty else { return true }
            return place.name.localizedStandardContains(query)
                || (place.address?.localizedStandardContains(query) ?? false)
        }
    }

    /// Countries that at least one place is in, for the country filter, sorted by name.
    private var availableCountries: [String] {
        Set(places.compactMap(\.countryCode))
            .sorted { Country.name(for: $0).localizedStandardCompare(Country.name(for: $1)) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            Group {
                switch mode {
                case .list:
                    placesList
                case .map:
                    PlacesMapView(places: filteredPlaces)
                }
            }
            .safeAreaInset(edge: .top) {
                Picker("View", selection: $mode) {
                    ForEach(DisplayMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.bar)
            }
            .searchable(text: $searchText, prompt: "Search places")
            .navigationTitle("Places")
            // Inline, because a large title would sit underneath the List/Map control's bar and be hidden.
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Place.self) { place in
                PlaceDetailView(place: place)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    filterMenu
                }
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
            .confirmationDialog(
                "Save “\(pendingResult?.name ?? "Place")”?",
                isPresented: Binding(get: { pendingResult != nil }, set: { if !$0 { pendingResult = nil } }),
                titleVisibility: .visible,
                presenting: pendingResult
            ) { item in
                // The category Apple Maps suggests comes first; the user can pick any other.
                ForEach(categoriesSuggestedFirst(for: item), id: \.self) { category in
                    let title = category.rawValue.capitalized
                    Button(category == item.suggestedCategory ? "Save as \(title) (Suggested)" : "Save as \(title)") {
                        save(item, as: category)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("It's added to Places for everyone and marked unverified until an administrator reviews it.")
            }
            // Searches Apple Maps automatically when nothing in the app matches what's typed.
            // The task restarts on every keystroke, so the short sleep acts as a debounce.
            .task(id: searchText) {
                let query = trimmedQuery
                if search.query != query {
                    search.clear()
                }
                guard !query.isEmpty, filteredPlaces.isEmpty else { return }
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                await search.search(query)
            }
        }
    }

    // MARK: List mode

    private var placesList: some View {
        List {
            if session.isAdmin {
                adminSections
            }

            Section {
                ForEach(filteredPlaces) { place in
                    NavigationLink(value: place) {
                        placeRow(place)
                    }
                    .swipeActions(edge: .leading) {
                        favouriteButton(for: place)
                        if session.isAdmin {
                            Button("Edit", systemImage: "pencil") { editingPlace = place }
                                .tint(.indigo)
                        }
                    }
                    // Swipe-to-delete is admin-only.
                    .swipeActions(edge: .trailing) {
                        if session.isAdmin {
                            Button("Delete", systemImage: "trash", role: .destructive) { delete([place]) }
                        }
                    }
                }
            } header: {
                // Travellers usually only see this one section, so it only needs a title next to others.
                if session.isAdmin || showsAppleMapsSection {
                    Text("All places")
                }
            }

            // Offered when the app has matches but the user may still want something else.
            if !trimmedQuery.isEmpty && !filteredPlaces.isEmpty && !showsAppleMapsSection {
                Section {
                    Button("Search Apple Maps for “\(trimmedQuery)”", systemImage: "globe") {
                        let query = trimmedQuery
                        Task { await search.search(query) }
                    }
                }
            }

            if showsAppleMapsSection {
                appleMapsSection
            }
        }
        .overlay {
            // With search text, the Apple Maps section explains what was found, so only filters need this.
            if filteredPlaces.isEmpty && trimmedQuery.isEmpty && filtersActive {
                ContentUnavailableView("No Matching Places", systemImage: "line.3.horizontal.decrease.circle", description: Text("Try changing or clearing the filters."))
            }
        }
    }

    /// Filter options: favourites, category, and country. The icon is filled while any filter is on.
    private var filterMenu: some View {
        Menu {
            Toggle("Favourites", systemImage: "heart", isOn: $favouritesOnly)
            Picker("Category", systemImage: "square.grid.2x2", selection: $categoryFilter) {
                Text("All Categories").tag(ActivityCategory?.none)
                ForEach(ActivityCategory.allCases, id: \.self) { category in
                    Label(category.rawValue.capitalized, systemImage: category.symbolName).tag(Optional(category))
                }
            }
            .pickerStyle(.menu)
            Picker("Country", systemImage: "flag", selection: $countryFilter) {
                Text("All Countries").tag(String?.none)
                ForEach(availableCountries, id: \.self) { code in
                    Text("\(Country.flag(for: code)) \(Country.name(for: code))").tag(Optional(code))
                }
            }
            .pickerStyle(.menu)
            if filtersActive {
                Button("Clear Filters", systemImage: "xmark.circle") {
                    categoryFilter = nil
                    countryFilter = nil
                    favouritesOnly = false
                }
            }
        } label: {
            Label("Filter", systemImage: filtersActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
        }
    }

    private func favouriteButton(for place: Place) -> some View {
        Button(place.isFavourite ? "Unfavourite" : "Favourite",
               systemImage: place.isFavourite ? "heart.slash" : "heart") {
            place.isFavourite.toggle()
        }
        .tint(.pink)
    }

    // MARK: Apple Maps results

    /// Shown while a search is running or once it has finished for the current text.
    private var showsAppleMapsSection: Bool {
        !trimmedQuery.isEmpty && (search.isSearching || search.query == trimmedQuery)
    }

    @ViewBuilder
    private var appleMapsSection: some View {
        Section("From Apple Maps") {
            if search.isSearching {
                ProgressView("Searching Apple Maps…")
            } else if let errorMessage = search.errorMessage {
                InlineError(message: errorMessage)
            } else if search.results.isEmpty {
                Text("No places found for “\(trimmedQuery)”.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(search.results, id: \.self) { item in
                    appleMapsRow(item)
                }
            }
        }
    }

    private func appleMapsRow(_ item: MKMapItem) -> some View {
        let isSaved = places.contains { $0.matches(item) }
        return Button {
            pendingResult = item
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.suggestedCategory.symbolName)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: iconSize, height: iconSize)
                    .background(Color("AccentSoft"), in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name ?? "Unnamed place")
                    if let address = item.displayAddress {
                        Text(address)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if isSaved {
                    Text("Saved")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
                }
            }
        }
        .tint(.primary)
        // Saving the same spot twice would only make a duplicate.
        .disabled(isSaved)
        .accessibilityHint(isSaved ? "Already in Places" : "Saves this place to Places")
    }

    private func categoriesSuggestedFirst(for item: MKMapItem) -> [ActivityCategory] {
        let suggested = item.suggestedCategory
        return [suggested] + ActivityCategory.allCases.filter { $0 != suggested }
    }

    private func save(_ item: MKMapItem, as category: ActivityCategory) {
        modelContext.insert(Place.fromMapItem(item, category: category))
    }

    // MARK: Admin

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

    // MARK: Rows

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
        .accessibilityElement(children: .combine)
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
            HStack(spacing: 4) {
                Text(place.name)
                if place.isFavourite {
                    Image(systemName: "heart.fill")
                        .font(.caption)
                        .foregroundStyle(.pink)
                        .accessibilityLabel("Favourite")
                }
            }
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
