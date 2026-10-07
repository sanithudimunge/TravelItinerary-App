import SwiftUI

/// Prompts for the admin PIN with a 4-digit keypad.
struct AdminPINView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var entry = ""
    @State private var errorMessage: String?

    private let pinLength = 4

    /// Keypad layout. Empty strings are spacers; "⌫" deletes the last digit.
    private let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "", "0", "⌫"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Text("Enter the admin PIN")
                    .font(.headline)

                // One dot per digit; filled dots show how many have been typed.
                HStack(spacing: 16) {
                    ForEach(0..<pinLength, id: \.self) { index in
                        Circle()
                            .fill(index < entry.count ? Color.primary : Color.clear)
                            .stroke(Color.primary, lineWidth: 1.5)
                            .frame(width: 14, height: 14)
                    }
                }
                .accessibilityElement()
                .accessibilityLabel("\(entry.count) of \(pinLength) digits entered")

                if let errorMessage {
                    InlineError(message: errorMessage)
                }

                LazyVGrid(columns: Array(repeating: GridItem(.fixed(80), spacing: 24), count: 3), spacing: 16) {
                    ForEach(keys, id: \.self) { key in
                        keyButton(key)
                    }
                }
                .disabled(session.isLockedOut)
            }
            .padding()
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
            Color.clear.frame(width: 80, height: 80)
        } else {
            Button {
                press(key)
            } label: {
                Text(key)
                    .font(.title)
                    .frame(width: 80, height: 80)
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
        }
    }
}

#Preview {
    AdminPINView()
        .environment(SessionStore())
}
