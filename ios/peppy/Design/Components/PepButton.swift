import SwiftUI

enum PepButtonStyle {
    case primary
    case secondary
    case ghost
    case destructive

    var backgroundColor: Color {
        switch self {
        case .primary: return .pepInk
        case .secondary: return .pepSurface
        case .ghost: return .clear
        case .destructive: return .pepError
        }
    }

    var foregroundColor: Color {
        switch self {
        case .primary, .destructive: return .white
        case .secondary, .ghost: return .pepTextPrimary
        }
    }

    var borderColor: Color? {
        switch self {
        case .secondary: return .pepBorder
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
                    .font(.system(size: 15, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .foregroundColor(style.foregroundColor)
            .background(style.backgroundColor)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(style.borderColor ?? .clear, lineWidth: style.borderColor != nil ? 1.2 : 0)
            )
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
