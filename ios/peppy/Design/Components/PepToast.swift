import SwiftUI

enum ToastType {
    case success
    case error
    case info

    var backgroundColor: Color {
        switch self {
        case .success: return .pepSuccess
        case .error: return .pepError
        case .info: return .pepInfo
        }
    }

    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.circle.fill"
        case .info: return "info.circle.fill"
        }
    }
}

struct Toast: Equatable {
    let id: UUID
    let message: String
    let type: ToastType

    init(message: String, type: ToastType) {
        self.id = UUID()
        self.message = message
        self.type = type
    }

    static func == (lhs: Toast, rhs: Toast) -> Bool {
        lhs.id == rhs.id
    }
}

struct PepToast: View {
    let toast: Toast

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: toast.type.icon)
                .foregroundColor(.white)
            Text(toast.message)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .lineLimit(2)
            Spacer()
        }
        .padding(Spacing.md)
        .background(toast.type.backgroundColor)
        .cornerRadius(CornerRadius.sm)
        .pepCardShadow()
        .padding(.horizontal, Spacing.md)
    }
}

struct ToastModifier: ViewModifier {
    @Binding var toast: Toast?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let toast = toast {
                    PepToast(toast: toast)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                withAnimation {
                                    self.toast = nil
                                }
                            }
                        }
                        .padding(.top, Spacing.xl)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: toast)
    }
}

extension View {
    func pepToast(_ toast: Binding<Toast?>) -> some View {
        self.modifier(ToastModifier(toast: toast))
    }
}

#Preview {
    VStack {
        Text("Content")
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.pepBackground)
    .pepToast(.constant(Toast(message: "Something went wrong. Please try again.", type: .error)))
}
