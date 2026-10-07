import Foundation
import Security

/// Stores and checks the admin PIN in the Keychain.
nonisolated struct KeychainStore: Sendable {
    enum KeychainError: Error {
        /// A Security framework call failed; the status explains why (see `SecCopyErrorMessageString`).
        case unexpectedStatus(OSStatus)
    }

    /// Together, service and account identify the one Keychain item this app uses for the PIN.
    private let service = "TravelItinerary.admin"
    private let account = "adminPIN"

    /// Attributes shared by every query on the PIN item.
    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    /// Saves a new admin PIN, replacing any existing one.
    func setPIN(_ pin: String) throws {
        // Delete then add is simpler than deciding between SecItemAdd and SecItemUpdate.
        // A missing item (errSecItemNotFound) is fine here, so the delete's status is ignored.
        SecItemDelete(baseQuery as CFDictionary)

        var query = baseQuery
        query[kSecValueData as String] = Data(pin.utf8)
        // Readable only while the device is unlocked, and never synced or restored to another device.
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Returns whether the given PIN matches the stored one.
    func verify(_ pin: String) -> Bool {
        guard let storedPIN = storedPIN() else { return false }
        return storedPIN == pin
    }

    /// Stores the default PIN if none has been saved yet, i.e. on first launch.
    func setDefaultPINIfNeeded() throws {
        guard storedPIN() == nil else { return }
        // DEMO DEFAULT: "1234" is only here so the admin features can be tried out.
        // A real app would make the administrator choose their own PIN during setup.
        try setPIN("1234")
    }

    /// Reads the PIN from the Keychain, or `nil` if there isn't one.
    private func storedPIN() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
