import Foundation
import Observation

/// Tracks the signed-in user and whether admin mode is unlocked.
@Observable
final class SessionStore {
    /// Wrong PINs allowed before admin mode is locked out.
    static let maxAttempts = 3

    var currentUser: User?
    var isAdmin: Bool = false
    private(set) var failedAttempts: Int = 0

    private let keychain = KeychainStore()

    /// True once all attempts are used up. The count lives in memory only,
    /// so the lockout lasts until the app is relaunched.
    var isLockedOut: Bool {
        failedAttempts >= Self.maxAttempts
    }

    /// Unlocks admin mode if the PIN matches; otherwise records a failed attempt.
    func unlockAdmin(pin: String) throws(ItineraryError) {
        // Once locked out, don't check the PIN at all, so further guesses can't succeed.
        guard !isLockedOut else {
            throw .incorrectPIN(attemptsLeft: 0)
        }

        if keychain.verify(pin) {
            isAdmin = true
            failedAttempts = 0
        } else {
            failedAttempts += 1
            throw .incorrectPIN(attemptsLeft: Self.maxAttempts - failedAttempts)
        }
    }

    /// Leaves admin mode.
    func lock() {
        isAdmin = false
    }
}
