import SwiftUI

enum HelpAboutStartSection {
    case top
    case importantInformation
}

enum HelpAboutContent {
    static let medicalDisclaimer =
        "Peppy provides informational health tracking and AI-assisted insights. "
        + "It does not diagnose, treat, prevent, or cure any condition and is not "
        + "a substitute for professional medical advice. Consult a qualified "
        + "healthcare professional before starting, stopping, or changing a "
        + "peptide, medication, or treatment. Contact local emergency services "
        + "for urgent help."

    static func copyrightText(year: Int) -> String {
        "© \(year) Peppy. All rights reserved."
    }
}

struct HelpAboutView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var browserDestination: PeppyWebDestination?

    let version: SettingsAppVersion
    let startSection: HelpAboutStartSection
    let year: Int

    init(
        version: SettingsAppVersion,
        startSection: HelpAboutStartSection = .top,
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        self.version = version
        self.startSection = startSection
        year = calendar.component(.year, from: now)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    SettingsDetailHeader(
                        title: "Help & About",
                        subtitle: "Find answers, get support, and learn more about Peppy.",
                        titleAlignment: .centered,
                        backAccessibilityLabel: "Back to More",
                        dismiss: dismiss.callAsFunction
                    )
                    .id(HelpAboutStartSection.top)

                    getHelpSection

                    importantInformationSection
                        .id(HelpAboutStartSection.importantInformation)

                    privacyNotice
                    footer
                }
                .padding(.horizontal, SecurityPrivacyFigmaLayout.horizontalPadding)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.lg)
            }
            .background(Color.pepBackground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .task {
                guard startSection == .importantInformation else { return }
                await Task.yield()
                proxy.scrollTo(
                    HelpAboutStartSection.importantInformation,
                    anchor: .top
                )
            }
        }
        .sheet(item: $browserDestination) { destination in
            InAppBrowserView(destination: destination)
                .ignoresSafeArea()
        }
    }

    private var getHelpSection: some View {
        SettingsDetailSection(title: "Get help") {
            SettingsDetailCard {
                webRow(
                    destination: .help,
                    systemImage: "magnifyingglass",
                    title: "Search help",
                    subtitle: "Find answers to common questions",
                    tint: .pepPrimary,
                    background: .pepPrimaryMuted
                )

                SettingsDetailDivider()

                webRow(
                    destination: .contact,
                    systemImage: "envelope",
                    title: "Contact support",
                    subtitle: "We typically reply within one business day",
                    tint: .pepPrimary,
                    background: .pepPrimaryMuted
                )

                SettingsDetailDivider()

                webRow(
                    destination: .bug,
                    systemImage: "exclamationmark.triangle",
                    title: "Report a problem",
                    subtitle: "Let us know something isn’t working",
                    tint: .pepWarning,
                    background: .pepWarningMuted
                )

                SettingsDetailDivider()

                webRow(
                    destination: .feature,
                    systemImage: "lightbulb",
                    title: "Feature request",
                    subtitle: "Share an idea to make Peppy better",
                    tint: Color(hex: "8F5BB7"),
                    background: Color(hex: "F4ECFA")
                )
            }
        }
    }

    private var importantInformationSection: some View {
        SettingsDetailSection(title: "Important information") {
            SettingsDetailCard {
                NavigationLink {
                    MedicalDisclaimerView()
                } label: {
                    SettingsDetailRowLabel(
                        systemImage: "shield.checkered",
                        title: "Medical disclaimer",
                        subtitle: "Important information about Peppy",
                        tint: .pepSuccess,
                        background: .pepSuccessMuted
                    )
                }
                .buttonStyle(.plain)

                SettingsDetailDivider()

                webRow(
                    destination: .terms,
                    systemImage: "doc.text",
                    title: "Terms of service",
                    subtitle: "View our terms and conditions",
                    tint: .blue,
                    background: Color.blue.opacity(0.10)
                )

                SettingsDetailDivider()

                webRow(
                    destination: .privacy,
                    systemImage: "lock",
                    title: "Privacy policy",
                    subtitle: "Learn how we protect your data",
                    tint: Color(hex: "8F5BB7"),
                    background: Color(hex: "F4ECFA")
                )
            }
        }
    }

    private var privacyNotice: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .top, spacing: Spacing.md) {
                Image(systemName: "heart.text.square")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(Color.pepSuccess)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Your health data is private")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(Color.pepTextPrimary)
                    Text(
                        "We never sell your data. Your health information is used "
                            + "only to provide and personalize Peppy features you choose."
                    )
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color.pepTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }

            Rectangle()
                .fill(Color.pepBorderLight)
                .frame(height: 1)

            Text(
                "Peppy provides informational insights and does not replace "
                    + "professional medical advice."
            )
            .font(.system(.footnote, design: .rounded, weight: .semibold))
            .foregroundStyle(Color.pepTextPrimary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.pepSuccessMuted.opacity(0.50))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .stroke(Color.pepSuccess.opacity(0.20), lineWidth: 1)
        )
    }

    private var footer: some View {
        VStack(spacing: 5) {
            SettingsWordmark()

            Text("Personalized peptide protocol tracker")
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(Color.pepTextSecondary)

            Text(version.displayText)
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(Color.pepTextSecondary)

            Text(HelpAboutContent.copyrightText(year: year))
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(Color.pepTextTertiary)
                .padding(.top, Spacing.sm)
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }

    private func webRow(
        destination: PeppyWebDestination,
        systemImage: String,
        title: String,
        subtitle: String,
        tint: Color,
        background: Color
    ) -> some View {
        Button {
            browserDestination = destination
        } label: {
            SettingsDetailRowLabel(
                systemImage: systemImage,
                title: title,
                subtitle: subtitle,
                tint: tint,
                background: background
            )
        }
        .buttonStyle(.plain)
    }
}

/// A navigation destination used by root rows that should open a reviewed web
/// page directly. Dismissing Safari returns to More instead of leaving a blank
/// placeholder screen behind.
struct SettingsBrowserRouteView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isBrowserPresented = true
    let destination: PeppyWebDestination

    var body: some View {
        Color.pepBackground
            .ignoresSafeArea()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(
                isPresented: $isBrowserPresented,
                onDismiss: { dismiss() }
            ) {
                InAppBrowserView(destination: destination)
                    .ignoresSafeArea()
            }
    }
}
