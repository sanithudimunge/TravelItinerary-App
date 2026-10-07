import SwiftUI

/// Prompts for the admin PIN with a 4-digit keypad.
struct AdminPINView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var entry = ""
    @State private var errorMessage: String?

    private let pinLength = 4

    // Sizes scale with Dynamic Type. The key size is capped so three keys plus spacing
    // still fit across the narrowest iPhone at the largest accessibility sizes.
    @ScaledMetric(relativeTo: .title) private var scaledKeySize: CGFloat = 80
    @ScaledMetric(relativeTo: .body) private var dotSize: CGFloat = 14
    private var keySize: CGFloat { min(scaledKeySize, 96) }

    /// Keypad layout. Empty strings are spacers; "⌫" deletes the last digit.
    private let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "", "0", "⌫"]

    var body: some View {
        NavigationStack {
            // Scrolls only when the content is taller than the screen, e.g. at the largest text sizes.
            ScrollView {
                VStack(spacing: 32) {
                    Text("Enter the admin PIN")
                        .font(.headline)

                    // One dot per digit; filled dots show how many have been typed.
                    HStack(spacing: 16) {
                        ForEach(0..<pinLength, id: \.self) { index in
                            Circle()
                                .fill(index < entry.count ? Color.primary : Color.clear)
                                .stroke(Color.primary, lineWidth: 1.5)
                                .frame(width: dotSize, height: dotSize)
                        }
                    }
                    .accessibilityElement()
                    .accessibilityLabel("\(entry.count) of \(pinLength) digits entered")

                    if let errorMessage {
                        InlineError(message: errorMessage)
                    }

                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(keySize), spacing: 20), count: 3), spacing: 16) {
                        ForEach(keys, id: \.self) { key in
                            keyButton(key)
                        }
                    }
                    .disabled(session.isLockedOut)
                }
                .padding()
            }
            .scrollBounceBehavior(.basedOnSize)
            .navigationTitle("Administrator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                // Opening the screen while locked out should explain why the keypad doesn't work.
                if session.isLockedOut {
                    errorMessage = ItineraryError.incorrectPIN(attemptsLeft: 0).localizedDescription
                }
            }
        }
    }

    @ViewBuilder
    private func keyButton(_ key: String) -> some View {
        if key.isEmpty {
            Color.clear.frame(width: keySize, height: keySize)
                .accessibilityHidden(true)
        } else {
            Button {
                press(key)
            } label: {
                Text(key)
                    .font(.title)
                    .frame(width: keySize, height: keySize)
                    .background(.fill.tertiary, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(key == "⌫" ? "Delete" : key)
        }
    }

    private func press(_ key: String) {
        if key == "⌫" {
            if !entry.isEmpty { entry.removeLast() }
            return
        }
        guard entry.count < pinLength else { return }
        entry.append(key)

        // Check automatically once all four digits are in, like the system passcode screen.
        if entry.count == pinLength {
            submit()
        }
    }

    private func submit() {
        do throws(ItineraryError) {
            try session.unlockAdmin(pin: entry)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            // Clear the dots so the next attempt starts fresh.
            entry = ""
            // VoiceOver doesn't read new text on its own, so announce why the entry was cleared.
            AccessibilityNotification.Announcement(error.localizedDescription).post()
        }
    }
}

#Preview {
    AdminPINView()
        .environment(SessionStore())
}
