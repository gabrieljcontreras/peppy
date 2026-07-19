import SwiftUI

struct PepTextField: View {
    static let secureToggleTapTarget: CGFloat = 44

    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .sentences
    var accessibilityLabel: String? = nil
    @State private var showsSecureText = false

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Group {
                if isSecure && !showsSecureText {
                    SecureField(placeholder, text: $text)
                        .accessibilityLabel(accessibilityLabel ?? placeholder)
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboardType)
                        .textInputAutocapitalization(autocapitalization)
                        .accessibilityLabel(accessibilityLabel ?? placeholder)
                }
            }

            if isSecure {
                Button {
                    showsSecureText.toggle()
                } label: {
                    Image(systemName: showsSecureText ? "eye.slash" : "eye")
                        .font(.system(size: 14))
                        .foregroundColor(.pepTextTertiary)
                        .frame(
                            width: Self.secureToggleTapTarget,
                            height: Self.secureToggleTapTarget
                        )
                }
                .accessibilityLabel(showsSecureText ? "Hide password" : "Show password")
            }
        }
        .font(.body)
        .foregroundColor(.pepTextPrimary)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .frame(minHeight: 54)
        .background(Color.clear)
        .cornerRadius(CornerRadius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.sm)
                .stroke(Color.pepBorder, lineWidth: 1)
        )
        .autocorrectionDisabled()
    }
}

struct PepTextFieldWithLabel: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var errorMessage: String? = nil
    var fieldAccessibilityLabel: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.pepTextPrimary)

            PepTextField(
                placeholder: placeholder,
                text: $text,
                isSecure: isSecure,
                keyboardType: keyboardType,
                autocapitalization: keyboardType == .emailAddress ? .never : .sentences,
                accessibilityLabel: fieldAccessibilityLabel ?? label
            )

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.pepError)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    VStack(spacing: Spacing.md) {
        PepTextField(placeholder: "Email", text: .constant(""))
        PepTextField(placeholder: "Password", text: .constant(""), isSecure: true)
        PepTextFieldWithLabel(
            label: "Email",
            placeholder: "you@example.com",
            text: .constant(""),
            errorMessage: "Invalid email address"
        )
    }
    .padding()
    .background(Color.pepBackground)
}
