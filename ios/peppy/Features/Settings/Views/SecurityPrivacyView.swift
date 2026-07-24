import SwiftUI
import UIKit

enum SecurityPrivacyFigmaLayout {
    static let referenceCanvasWidth: CGFloat = 853
    static let referenceCanvasHeight: CGFloat = 1_844
    static let horizontalPadding: CGFloat = 22
    static let minimumTapTarget: CGFloat = 44
    static let headerControlDiameter: CGFloat = 30
    static let cardCornerRadius: CGFloat = 8
    static let rowIconSize: CGFloat = 30
}

struct SecurityPrivacyView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Bindable private var appLock: AppLockCoordinator
    @State private var model: AccountSecurityViewModel
    @State private var browserDestination: PeppyWebDestination?
    @State private var appLockMessage: String?
    @State private var showsAppLockSettingsAction = false
    @State private var isUpdatingAppLock = false

    private let userID: UUID?

    init(
        api: APIClientProtocol,
        appLock: AppLockCoordinator,
        userID: UUID?,
        finishSignedOutSession: @escaping @MainActor () async -> Void,
        removeDeviceSettings: @escaping @MainActor () -> Void
    ) {
        self.appLock = appLock
        self.userID = userID
        _model = State(
            initialValue: AccountSecurityViewModel(
                api: api,
                finishSignedOutSession: finishSignedOutSession,
                removeDeviceSettings: removeDeviceSettings
            )
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                SettingsDetailHeader(
                    title: "Security & privacy",
                    subtitle: "We keep your data private, secure, and under your control.",
                    titleAlignment: .leading,
                    backAccessibilityLabel: "Back to More",
                    isBackDisabled: model.isAccountActionInFlight,
                    dismiss: {
                        guard !model.isAccountActionInFlight else { return }
                        dismiss()
                    }
                )

                accountSecuritySection

                if let errorMessage = model.errorMessage {
                    SettingsInlineBanner(
                        message: errorMessage,
                        tint: .pepError
                    )
                }

                if let appLockMessage {
                    if showsAppLockSettingsAction {
                        SettingsInlineBanner(
                            message: appLockMessage,
                            tint: .pepWarning,
                            actionTitle: "Open Settings"
                        ) {
                            openURL(
                                URL(
                                    string: UIApplication.openSettingsURLString
                                )!
                            )
                        }
                    } else {
                        SettingsInlineBanner(
                            message: appLockMessage,
                            tint: .pepWarning
                        )
                    }
                }

                privacySection
                dangerZone
                helpCenterAction
            }
            .padding(.horizontal, SecurityPrivacyFigmaLayout.horizontalPadding)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.lg)
        }
        .background(Color.pepBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $browserDestination) { destination in
            InAppBrowserView(destination: destination)
                .ignoresSafeArea()
        }
    }

    private var accountSecuritySection: some View {
        SettingsDetailSection(title: "Account security") {
            SettingsDetailCard {
                HStack(spacing: Spacing.md) {
                    SettingsDetailIcon(
                        systemImage: "faceid",
                        tint: .pepPrimary,
                        background: .pepPrimaryMuted
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Face ID")
                            .settingsRowTitle()
                        Text("Use Face ID to unlock Peppy")
                            .settingsRowSubtitle()
                    }

                    Spacer(minLength: Spacing.sm)

                    Toggle(
                        "Use Face ID to unlock Peppy",
                        isOn: faceIDBinding
                    )
                    .labelsHidden()
                    .tint(.pepSuccess)
                    .disabled(
                        userID == nil
                            || isUpdatingAppLock
                            || model.isAccountActionInFlight
                    )
                }
                .settingsDetailRowPadding()

                SettingsDetailDivider()

                NavigationLink {
                    ChangePasswordView(model: model)
                } label: {
                    SettingsDetailRowLabel(
                        systemImage: "lock",
                        title: "Change password",
                        subtitle: "Update your password regularly",
                        tint: .pepPrimary,
                        background: .pepPrimaryMuted
                    )
                }
                .buttonStyle(.plain)
                .disabled(model.isAccountActionInFlight)
            }
        }
    }

    private var privacySection: some View {
        SettingsDetailSection(title: "Privacy & data") {
            SettingsDetailCard {
                Button {
                    browserDestination = .privacy
                } label: {
                    SettingsDetailRowLabel(
                        systemImage: "doc.text",
                        title: "Privacy policy",
                        subtitle: "Read our privacy practices",
                        tint: Color(hex: "8F5BB7"),
                        background: Color(hex: "F4ECFA")
                    )
                }
                .buttonStyle(.plain)

                SettingsDetailDivider()

                Button {
                    browserDestination = .privacySecurity
                } label: {
                    SettingsDetailRowLabel(
                        systemImage: "lock.shield",
                        title: "How we protect your data",
                        subtitle: "Learn how Peppy safeguards your information",
                        tint: .blue,
                        background: Color.blue.opacity(0.10)
                    )
                }
                .buttonStyle(.plain)

                SettingsPrivacyStatement()
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            }
        }
    }

    private var dangerZone: some View {
        SettingsDetailSection(title: "Danger zone") {
            SettingsDetailCard {
                NavigationLink {
                    DeleteAccountView(model: model)
                } label: {
                    SettingsDetailRowLabel(
                        systemImage: "trash",
                        title: "Delete account",
                        subtitle: "Permanently delete your account and all associated data. This action cannot be undone.",
                        tint: .pepError,
                        background: .pepErrorMuted,
                        isDestructive: true
                    )
                }
                .buttonStyle(.plain)
                .disabled(model.isAccountActionInFlight)
            }
        }
    }

    private var helpCenterAction: some View {
        Button {
            browserDestination = .help
        } label: {
            Label("Questions about security? Visit our Help Center", systemImage: "questionmark.circle")
                .font(.system(.footnote, design: .rounded, weight: .semibold))
                .foregroundStyle(Color.pepPrimary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .frame(minHeight: SecurityPrivacyFigmaLayout.minimumTapTarget)
        }
        .buttonStyle(.plain)
    }

    private var faceIDBinding: Binding<Bool> {
        Binding(
            get: {
                guard let userID else { return false }
                return appLock.isEnabled(for: userID)
            },
            set: { isEnabled in
                guard let userID, !isUpdatingAppLock else { return }
                isUpdatingAppLock = true
                Task {
                    defer { isUpdatingAppLock = false }
                    switch await appLock.setEnabled(isEnabled, for: userID) {
                    case .enabled, .disabled:
                        appLockMessage = nil
                        showsAppLockSettingsAction = false
                    case .cancelled:
                        appLockMessage = "Face ID wasn’t enabled. You can try again when you’re ready."
                        showsAppLockSettingsAction = false
                    case .unavailable(let reason):
                        appLockMessage = reason.message
                        showsAppLockSettingsAction = reason == .notEnrolled
                    }
                }
            }
        )
    }
}

enum SettingsDetailTitleAlignment {
    case leading
    case centered
}

struct SettingsDetailHeader: View {
    let title: String
    let subtitle: String
    let titleAlignment: SettingsDetailTitleAlignment
    let backAccessibilityLabel: String
    let isBackDisabled: Bool
    let dismiss: () -> Void

    @ScaledMetric(relativeTo: .title) private var titleSize: CGFloat = 24
    @ScaledMetric(relativeTo: .body) private var subtitleSize: CGFloat = 12
    @ScaledMetric(relativeTo: .body) private var backIconSize: CGFloat = 13

    init(
        title: String,
        subtitle: String,
        titleAlignment: SettingsDetailTitleAlignment,
        backAccessibilityLabel: String,
        isBackDisabled: Bool = false,
        dismiss: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.titleAlignment = titleAlignment
        self.backAccessibilityLabel = backAccessibilityLabel
        self.isBackDisabled = isBackDisabled
        self.dismiss = dismiss
    }

    var body: some View {
        VStack(alignment: titleAlignment == .leading ? .leading : .center, spacing: Spacing.sm) {
            ZStack {
                HStack {
                    Button(action: dismiss) {
                        ZStack {
                            Circle()
                                .fill(Color.pepSurface)
                                .overlay(
                                    Circle().stroke(Color.pepBorder, lineWidth: 1)
                                )
                            Image(systemName: "chevron.left")
                                .font(
                                    .system(
                                        size: backIconSize,
                                        weight: .semibold
                                    )
                                )
                                .foregroundStyle(Color.pepTextPrimary)
                        }
                        .frame(
                            width: SecurityPrivacyFigmaLayout.headerControlDiameter,
                            height: SecurityPrivacyFigmaLayout.headerControlDiameter
                        )
                        .frame(
                            width: SecurityPrivacyFigmaLayout.minimumTapTarget,
                            height: SecurityPrivacyFigmaLayout.minimumTapTarget
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isBackDisabled)
                    .accessibilityLabel(backAccessibilityLabel)

                    Spacer()

                    PeppyLogo(size: 17)
                        .frame(
                            width: SecurityPrivacyFigmaLayout.headerControlDiameter,
                            height: SecurityPrivacyFigmaLayout.headerControlDiameter
                        )
                        .background(Color.pepSurface)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.pepBorder, lineWidth: 1))
                        .frame(
                            width: SecurityPrivacyFigmaLayout.minimumTapTarget,
                            height: SecurityPrivacyFigmaLayout.minimumTapTarget
                        )
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Peppy")
                }

                SettingsWordmark()
            }

            VStack(
                alignment: titleAlignment == .leading ? .leading : .center,
                spacing: 3
            ) {
                Text(title)
                    .font(.system(size: titleSize, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.pepTextPrimary)

                Text(subtitle)
                    .font(.system(size: subtitleSize, design: .rounded))
                    .foregroundStyle(Color.pepTextSecondary)
                    .multilineTextAlignment(
                        titleAlignment == .leading ? .leading : .center
                    )
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(
                maxWidth: .infinity,
                alignment: titleAlignment == .leading ? .leading : .center
            )
        }
    }
}

struct SettingsDetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    @ScaledMetric(relativeTo: .body) private var titleSize: CGFloat = 13

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(
                    .system(
                        size: titleSize,
                        weight: .semibold,
                        design: .rounded
                    )
                )
                .foregroundStyle(Color.pepTextPrimary)
            content
        }
    }
}

struct SettingsDetailCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(Color.pepSurface)
        .clipShape(
            RoundedRectangle(
                cornerRadius: SecurityPrivacyFigmaLayout.cardCornerRadius
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: SecurityPrivacyFigmaLayout.cardCornerRadius
            )
            .stroke(Color.pepBorder, lineWidth: 1)
        )
    }
}

struct SettingsDetailRowLabel: View {
    let systemImage: String
    let title: String
    let subtitle: String
    let tint: Color
    let background: Color
    var isDestructive = false
    @ScaledMetric(relativeTo: .body) private var chevronSize: CGFloat = 12

    var body: some View {
        HStack(spacing: Spacing.md) {
            SettingsDetailIcon(
                systemImage: systemImage,
                tint: tint,
                background: background
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .settingsRowTitle(
                        color: isDestructive ? .pepError : .pepTextPrimary
                    )
                Text(subtitle)
                    .settingsRowSubtitle()
            }

            Spacer(minLength: Spacing.sm)

            Image(systemName: "chevron.right")
                .font(.system(size: chevronSize, weight: .semibold))
                .foregroundStyle(Color.pepTextTertiary)
                .accessibilityHidden(true)
        }
        .settingsDetailRowPadding()
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct SettingsDetailIcon: View {
    let systemImage: String
    let tint: Color
    let background: Color
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 15

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: iconSize, weight: .semibold))
            .foregroundStyle(tint)
            .frame(
                width: SecurityPrivacyFigmaLayout.rowIconSize,
                height: SecurityPrivacyFigmaLayout.rowIconSize
            )
            .background(background)
            .clipShape(Circle())
            .accessibilityHidden(true)
    }
}

struct SettingsDetailDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.pepBorderLight)
            .frame(height: 1)
            .padding(.leading, 12)
    }
}

struct SettingsInlineBanner: View {
    let message: String
    let tint: Color
    var actionTitle: String?
    var action: (() -> Void)?
    @ScaledMetric(relativeTo: .footnote) private var iconSize: CGFloat = 14

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(tint)
                .accessibilityHidden(true)

            Text(message)
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(Color.pepTextPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: Spacing.xs)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.system(.footnote, design: .rounded, weight: .semibold))
                    .foregroundStyle(Color.pepPrimaryDark)
            }
        }
        .padding(12)
        .background(tint.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
    }
}

private struct SettingsPrivacyStatement: View {
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 17

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(Color.pepTextSecondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text("Your health data is private")
                    .settingsRowTitle()
                Text(
                    "We never sell your data. Your health information is used only "
                        + "to provide and personalize Peppy features you choose."
                )
                .settingsRowSubtitle()
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.pepSuccessMuted.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
    }
}

private extension View {
    func settingsDetailRowPadding() -> some View {
        padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(
                minHeight: SecurityPrivacyFigmaLayout.minimumTapTarget,
                alignment: .leading
            )
    }

    func settingsRowTitle(
        color: Color = .pepTextPrimary
    ) -> some View {
        modifier(SettingsRowTitleModifier(color: color))
    }

    func settingsRowSubtitle() -> some View {
        modifier(SettingsRowSubtitleModifier())
    }
}

private struct SettingsRowTitleModifier: ViewModifier {
    let color: Color
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 13

    func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: .semibold, design: .rounded))
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct SettingsRowSubtitleModifier: ViewModifier {
    @ScaledMetric(relativeTo: .subheadline) private var size: CGFloat = 11

    func body(content: Content) -> some View {
        content
            .font(.system(size: size, design: .rounded))
            .foregroundStyle(Color.pepTextSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
