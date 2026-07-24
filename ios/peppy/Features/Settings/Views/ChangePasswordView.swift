import SwiftUI
import UIKit

struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: AccountSecurityViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                SettingsDetailHeader(
                    title: "Change password",
                    subtitle: "Choose a strong password you don’t use elsewhere.",
                    titleAlignment: .leading,
                    backAccessibilityLabel: "Back to Security & privacy",
                    isBackDisabled: model.isAccountActionInFlight,
                    dismiss: {
                        guard !model.isAccountActionInFlight else { return }
                        dismiss()
                    }
                )

                SettingsDetailSection(title: "Password") {
                    VStack(spacing: Spacing.sm) {
                        passwordField(
                            "Current password",
                            text: $model.currentPassword,
                            contentType: .password
                        )
                        passwordField(
                            "New password",
                            text: $model.newPassword,
                            contentType: .newPassword
                        )
                        passwordField(
                            "Confirm new password",
                            text: $model.confirmNewPassword,
                            contentType: .newPassword
                        )
                    }
                }

                Text(
                    "Use at least 8 characters. After a successful change, "
                        + "you’ll be signed out on every device."
                )
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(Color.pepTextSecondary)
                .fixedSize(horizontal: false, vertical: true)

                if let errorMessage = model.errorMessage {
                    SettingsInlineBanner(
                        message: errorMessage,
                        tint: .pepError
                    )
                }

                Button {
                    Task { await model.changePassword() }
                } label: {
                    Group {
                        if model.isAccountActionInFlight {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Update password")
                        }
                    }
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 50)
                    .background(Color.pepPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                }
                .buttonStyle(.plain)
                .disabled(model.isAccountActionInFlight)
            }
            .padding(.horizontal, SecurityPrivacyFigmaLayout.horizontalPadding)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.lg)
        }
        .background(Color.pepBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private func passwordField(
        _ title: String,
        text: Binding<String>,
        contentType: UITextContentType
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.footnote, design: .rounded, weight: .semibold))
                .foregroundStyle(Color.pepTextPrimary)

            SecureField("Enter \(title.lowercased())", text: text)
                .textContentType(contentType)
                .disabled(model.isAccountActionInFlight)
                .font(.system(.body, design: .rounded))
                .padding(.horizontal, 12)
                .frame(minHeight: 48)
                .background(Color.pepSurface)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.sm)
                        .stroke(Color.pepBorder, lineWidth: 1)
                )
        }
    }
}
