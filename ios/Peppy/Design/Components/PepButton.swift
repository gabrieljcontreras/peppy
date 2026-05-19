import SwiftUI

enum PepButtonStyle {
    case primary
    case secondary
    case ghost
    case destructive

    var backgroundColor: Color {
        switch self {
        case .primary: return .pepPrimary
        case .secondary: return .clear
        case .ghost: return .pepSurfaceElevated
        case .destructive: return .pepError
        }
    }

    var foregroundColor: Color {
        switch self {
        case .primary, .destructive: return .white
        case .secondary: return .pepPrimary
        case .ghost: return .pepTextPrimary
        }
    }

    var borderColor: Color? {
        switch self {
        case .secondary: return .pepPrimary
        default: return nil
        }
    }
}

struct PepButton: View {
    let title: String
    var style: PepButtonStyle = .primary
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .tint(style.foregroundColor)
                }
                Text(title)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .foregroundColor(style.foregroundColor)
            .background(style.backgroundColor)
            .cornerRadius(CornerRadius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.sm)
                    .stroke(style.borderColor ?? .clear, lineWidth: style.borderColor != nil ? 2 : 0)
            )
            .opacity(isDisabled ? 0.5 : 1.0)
        }
        .disabled(isLoading || isDisabled)
    }
}

#Preview {
    VStack(spacing: Spacing.md) {
        PepButton(title: "Primary Button", style: .primary) {}
        PepButton(title: "Secondary Button", style: .secondary) {}
        PepButton(title: "Ghost Button", style: .ghost) {}
        PepButton(title: "Destructive", style: .destructive) {}
        PepButton(title: "Loading...", style: .primary, isLoading: true) {}
        PepButton(title: "Disabled", style: .primary, isDisabled: true) {}
    }
    .padding()
    .background(Color.pepBackground)
}
