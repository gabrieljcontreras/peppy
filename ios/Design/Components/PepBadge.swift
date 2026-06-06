import SwiftUI

enum PepBadgeType {
    case success
    case warning
    case error
    case info
    case neutral

    var backgroundColor: Color {
        switch self {
        case .success: return .pepSuccessMuted
        case .warning: return .pepWarningMuted
        case .error: return .pepErrorMuted
        case .info: return .pepInfoMuted
        case .neutral: return .pepBorder
        }
    }

    var textColor: Color {
        switch self {
        case .success: return .pepSuccess
        case .warning: return .pepWarning
        case .error: return .pepError
        case .info: return .pepInfo
        case .neutral: return .pepTextSecondary
        }
    }
}

struct PepBadge: View {
    let text: String
    var type: PepBadgeType = .neutral

    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(type.textColor)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(type.backgroundColor)
            .cornerRadius(CornerRadius.full)
    }
}

#Preview {
    HStack(spacing: Spacing.sm) {
        PepBadge(text: "Active", type: .success)
        PepBadge(text: "Warning", type: .warning)
        PepBadge(text: "Alert", type: .error)
        PepBadge(text: "Info", type: .info)
        PepBadge(text: "Neutral", type: .neutral)
    }
    .padding()
    .background(Color.pepBackground)
}
