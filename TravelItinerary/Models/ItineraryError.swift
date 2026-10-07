import Foundation

/// Errors raised while editing itineraries, routing, or unlocking admin mode.
nonisolated enum ItineraryError: Error {
    case invalidDateRange
    case endBeforeStart
    case missingLocation(String)
    case routeUnavailable
    case incorrectPIN(attemptsLeft: Int)
}

extension ItineraryError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidDateRange:
            "The trip must end on or after its start date."
        case .endBeforeStart:
            "The end time must be after the start time."
        case .missingLocation(let name):
            "Choose a place with a valid location for “\(name)”."
        case .routeUnavailable:
            "A route couldn't be found between these stops."
        case .incorrectPIN(let attemptsLeft):
            switch attemptsLeft {
            // No attempts left means SessionStore has locked admin mode until the app is relaunched.
            case ...0: "Too many incorrect attempts. Admin mode is locked."
            case 1: "Incorrect PIN. 1 attempt left."
            default: "Incorrect PIN. \(attemptsLeft) attempts left."
            }
        }
    }
}
