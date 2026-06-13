import SwiftUI

struct PepTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .sentences
    @State private var showsSecureText = false

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Group {
                if isSecure && !showsSecureText {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboardType)
                        .textInputAutocapitalization(autocapitalization)
                }
            }

            if isSecure {
                Button {
                    showsSecureText.toggle()
                } label: {
                    Image(systemName: showsSecureText ? "eye.slash" : "eye")
                        .font(.system(size: 14))
                        .foregroundColor(.pepTextTertiary)
                }
            }
        }
        .font(.system(size: 14))
        .foregroundColor(.pepTextPrimary)
        .padding(.horizontal, Spacing.md)
        .frame(height: 54)
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

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.pepTextPrimary)

            PepTextField(
                placeholder: placeholder,
                text: $text,
                isSecure: isSecure,
                keyboardType: keyboardType,
                autocapitalization: keyboardType == .emailAddress ? .never : .sentences
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
