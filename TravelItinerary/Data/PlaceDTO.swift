import Foundation

/// Raw place data decoded from seed JSON, before validation.
struct PlaceDTO: Decodable {
    let name: String?
    let lat: Double
    let lon: Double
    let category: String
    let address: String?
    /// Optional ISO region code, e.g. "LK". Entries without one use the loader's default country.
    let country: String?

    /// Converts the decoded data into a `Place` model.
    /// Missing names and unknown categories get fallbacks so the place can still be reviewed by an admin.
    /// `defaultCountryCode` fills in the country for entries that don't name one.
    func makeModel(defaultCountryCode: String? = nil) -> Place {
        let knownCategory = ActivityCategory(rawValue: category)
        let place = Place(
            name: name ?? "Unnamed place",
            latitude: lat,
            longitude: lon,
            category: knownCategory ?? .sight,
            address: address,
            countryCode: country ?? defaultCountryCode
        )
        // Keep the original text so the fallback to `.sight` shows up as an issue instead of being silent.
        if knownCategory == nil {
            place.invalidCategory = category
        }
        return place
    }
}
