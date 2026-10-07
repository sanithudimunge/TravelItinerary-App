import SwiftUI

/// A small badge showing a status such as verified or warning.
struct StatusBadge: View {
    enum Status {
        case verified
        case needsReview

        var title: String {
            switch self {
            case .verified: "Verified"
            case .needsReview: "Needs review"
            }
        }

        var systemImage: String {
            switch self {
            case .verified: "checkmark.seal.fill"
            case .needsReview: "exclamationmark.triangle.fill"
            }
        }

        /// Text colour and soft background colour from the asset catalog.
        var colors: (foreground: Color, background: Color) {
            switch self {
            case .verified: (Color("Verified"), Color("VerifiedSoft"))
            case .needsReview: (Color("Warning"), Color("WarningSoft"))
            }
        }
    }

    let status: Status

    var body: some View {
        // An HStack rather than a Label: inside List rows a Label can be squeezed down to its icon only.
        HStack(spacing: 4) {
            // Decorative: the title already says what the icon means.
            Image(systemName: status.systemImage)
                .accessibilityHidden(true)
            Text(status.title)
        }
        .font(.caption.weight(.semibold))
        // Keep the badge on one line at its natural width; the row's other text wraps instead.
        .lineLimit(1)
        .fixedSize()
        .foregroundStyle(status.colors.foreground)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(status.colors.background, in: Capsule())
    }
}

#Preview {
    VStack {
        StatusBadge(status: .verified)
        StatusBadge(status: .needsReview)
    }
    .padding()
}
