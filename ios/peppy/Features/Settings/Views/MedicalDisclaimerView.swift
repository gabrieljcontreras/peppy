import SwiftUI

struct MedicalDisclaimerView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                SettingsDetailHeader(
                    title: "Medical disclaimer",
                    subtitle: "Important information about using Peppy.",
                    titleAlignment: .leading,
                    backAccessibilityLabel: "Back to Help & About",
                    dismiss: dismiss.callAsFunction
                )

                VStack(alignment: .leading, spacing: Spacing.md) {
                    Image(systemName: "cross.case.fill")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(Color.pepSuccess)
                        .accessibilityHidden(true)

                    Text("Peppy is informational")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(Color.pepTextPrimary)

                    Text(HelpAboutContent.medicalDisclaimer)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(Color.pepTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.pepSurface)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .stroke(Color.pepBorder, lineWidth: 1)
                )

                Text(
                    "If you think you may have a medical emergency, contact "
                        + "local emergency services immediately."
                )
                .font(.system(.footnote, design: .rounded, weight: .semibold))
                .foregroundStyle(Color.pepError)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, SecurityPrivacyFigmaLayout.horizontalPadding)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.lg)
        }
        .background(Color.pepBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
}
