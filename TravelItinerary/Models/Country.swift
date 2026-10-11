import Foundation

/// Helpers for countries, identified by ISO 3166-1 alpha-2 region codes such as "LK" or "IN".
///
/// Codes are stored rather than names so trips don't depend on the device language;
/// names are looked up in the user's language when shown.
nonisolated enum Country {
    /// Every two-letter ISO region code the system knows, sorted by name in the user's language.
    static let allCodes: [String] = Locale.Region.isoRegions
        .map(\.identifier)
        // isoRegions also includes numeric area codes such as "001" (World); keep countries only.
        .filter { $0.count == 2 && $0.allSatisfy(\.isLetter) }
        .sorted { name(for: $0).localizedStandardCompare(name(for: $1)) == .orderedAscending }

    /// The flag emoji for a region code, e.g. "LK" → 🇱🇰.
    ///
    /// Flag emoji are pairs of "regional indicator" symbols, one per letter of the code,
    /// so each letter A–Z is shifted into that Unicode block.
    static func flag(for code: String) -> String {
        let base: UInt32 = 0x1F1E6 - 0x41  // Regional indicator A minus ASCII "A".
        return String(code.uppercased().unicodeScalars.compactMap { Unicode.Scalar(base + $0.value) }.map(Character.init))
    }

    /// The country's name in the user's language, e.g. "LK" → "Sri Lanka".
    static func name(for code: String) -> String {
        Locale.current.localizedString(forRegionCode: code) ?? code
    }
}
