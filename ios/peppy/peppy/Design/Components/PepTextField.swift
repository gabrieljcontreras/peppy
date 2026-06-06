import SwiftUI

struct PepTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .sentences

    var body: some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(autocapitalization)
            }
        }
        .font(.body)
        .foregroundColor(.pepTextPrimary)
        .padding(Spacing.md)
        .background(Color.pepSurface)
        .cornerRadius(CornerRadius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.sm)
                .stroke(Color.pepBorder, lineWidth: 1)
        )
    }
}

struct PepTextFieldWithLabel: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var errorMessage: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.pepTextSecondary)

            PepTextField(
                placeholder: placeholder,
                text: $text,
                isSecure: isSecure,
                keyboardType: keyboardType
            )

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.pepError)
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
