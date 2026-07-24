import SwiftUI
import UIKit

struct DeleteAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: AccountSecurityViewModel
    @State private var showsFinalConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                SettingsDetailHeader(
                    title: "Delete account",
                    subtitle: "Permanently remove your Peppy account and data.",
                    titleAlignment: .leading,
                    backAccessibilityLabel: "Back to Security & privacy",
                    isBackDisabled: model.isAccountActionInFlight,
                    dismiss: {
                        guard !model.isAccountActionInFlight else { return }
                        dismiss()
                    }
                )

                deletionExplanation

                VStack(alignment: .leading, spacing: 6) {
                    Text("Confirm your password")
                        .font(.system(.footnote, design: .rounded, weight: .semibold))
                        .foregroundStyle(Color.pepTextPrimary)

                    SecureField(
                        "Enter your current password",
                        text: $model.deletionPassword
                    )
                    .textContentType(.password)
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

                if let errorMessage = model.errorMessage {
                    SettingsInlineBanner(
                        message: errorMessage,
                        tint: .pepError
                    )
                }

                Button {
                    model.requestAccountDeletion()
                    showsFinalConfirmation =
                        model.isDeleteConfirmationPresented
                } label: {
                    Group {
                        if model.isAccountActionInFlight {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Continue")
                        }
                    }
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 50)
                    .background(Color.pepError)
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
        .confirmationDialog(
            "Delete your Peppy account permanently?",
            isPresented: $showsFinalConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Permanently", role: .destructive) {
                Task { await model.confirmAccountDeletion() }
            }
            Button("Cancel", role: .cancel) {
                model.cancelAccountDeletion()
            }
        } message: {
            Text(
                "This removes your account data from Peppy’s active systems. "
                    + "This action cannot be undone."
            )
        }
    }

    private var deletionExplanation: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label("This action cannot be undone", systemImage: "exclamationmark.triangle.fill")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(Color.pepError)

            Text(
                "Deleting your account removes your profile, protocols and "
                    + "dose history, check-ins, insights, notification settings, "
                    + "connected records, and account credentials."
            )
            .font(.system(.footnote, design: .rounded))
            .foregroundStyle(Color.pepTextSecondary)
            .fixedSize(horizontal: false, vertical: true)

            Text(
                "After the server confirms deletion, Peppy also clears your "
                    + "saved session, reminders, temporary exports, and "
                    + "device-specific settings."
            )
            .font(.system(.footnote, design: .rounded))
            .foregroundStyle(Color.pepTextSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.pepErrorMuted)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .stroke(Color.pepError.opacity(0.25), lineWidth: 1)
        )
    }
}
