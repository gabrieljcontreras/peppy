import SwiftUI

/// Geometry measured from the approved 853 × 1844 More frame in
/// `Peppy IOS (2).fig`. Dynamic Type may reflow content, but these values keep
/// the default-size composition aligned with the visual source of truth.
enum SettingsFigmaLayout {
    static let referenceCanvasWidth: CGFloat = 853
    static let referenceCanvasHeight: CGFloat = 1_844
    static let horizontalPadding: CGFloat = 22
    static let minimumTapTarget: CGFloat = 44
    static let profileAvatarSize: CGFloat = 56
    static let rowIconSize: CGFloat = 30
    static let cardCornerRadius: CGFloat = 8
}

enum SettingsProfileLayout {
    static func identityLineLimit(for dynamicTypeSize: DynamicTypeSize) -> Int? {
        dynamicTypeSize.isAccessibilitySize ? nil : 1
    }
}

enum SettingsProfilePresentation {
    static func displayName(for user: User?) -> String {
        let name = user?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "Your profile" : name
    }

    static func email(for user: User?) -> String {
        user?.email ?? "Complete your account details"
    }
}

struct SettingsHeader: View {
    @ScaledMetric(relativeTo: .title) private var titleFontSize: CGFloat = 24
    @ScaledMetric(relativeTo: .body) private var subtitleFontSize: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                SettingsWordmark()

                Spacer()

                PeppyLogo(size: 22)
                    .frame(width: 36, height: 36)
                    .background(Color.pepSurface)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.pepBorder, lineWidth: 1))
                    .frame(
                        width: SettingsFigmaLayout.minimumTapTarget,
                        height: SettingsFigmaLayout.minimumTapTarget
                    )
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("More")
                    .font(.system(size: titleFontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.pepTextPrimary)

                Text("Manage your account, data, and app settings.")
                    .font(.system(size: subtitleFontSize, design: .rounded))
                    .foregroundStyle(Color.pepTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct SettingsWordmark: View {
    var body: some View {
        Image("PeppyLogoWordmark")
            .resizable()
            .scaledToFit()
            .frame(width: 131, height: 50)
            .offset(x: -24)
            .frame(width: 76, height: 30)
            .clipped()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Peppy")
    }
}

struct SettingsProfileCard: View {
    let user: User?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .headline) private var nameFontSize: CGFloat = 15
    @ScaledMetric(relativeTo: .subheadline) private var emailFontSize: CGFloat = 13

    private var displayName: String { SettingsProfilePresentation.displayName(for: user) }

    private var email: String { SettingsProfilePresentation.email(for: user) }

    var body: some View {
        NavigationLink(value: SettingsRootViewModel.profileRoute) {
            HStack(spacing: Spacing.md) {
                PeppyLogo(size: 29)
                    .frame(
                        width: SettingsFigmaLayout.profileAvatarSize,
                        height: SettingsFigmaLayout.profileAvatarSize
                    )
                    .background(Color.pepSurfaceElevated)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(displayName)
                        .font(.system(size: nameFontSize, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.pepTextPrimary)
                        .lineLimit(SettingsProfileLayout.identityLineLimit(for: dynamicTypeSize))

                    Text(email)
                        .font(.system(size: emailFontSize, design: .rounded))
                        .foregroundStyle(Color.pepTextSecondary)
                        .lineLimit(SettingsProfileLayout.identityLineLimit(for: dynamicTypeSize))
                }

                Spacer(minLength: Spacing.sm)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.pepTextTertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 13)
            .frame(minHeight: 82)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color.pepSurface)
        .clipShape(RoundedRectangle(cornerRadius: SettingsFigmaLayout.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: SettingsFigmaLayout.cardCornerRadius)
                .stroke(Color.pepBorder, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Profile, \(displayName), \(email)")
        .accessibilityHint("Opens profile settings")
    }
}

struct SettingsSectionCard: View {
    let title: String
    let rows: [SettingsRowModel]

    @ScaledMetric(relativeTo: .headline) private var titleFontSize: CGFloat = 13

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: titleFontSize, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.pepTextSecondary)

            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    NavigationLink(value: row.route) {
                        SettingsMenuRow(row: row)
                    }
                    .buttonStyle(.plain)

                    if index < rows.count - 1 {
                        Rectangle()
                            .fill(Color.pepBorderLight)
                            .frame(height: 1)
                            .padding(.leading, 12)
                    }
                }
            }
            .background(Color.pepSurface)
            .clipShape(RoundedRectangle(cornerRadius: SettingsFigmaLayout.cardCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: SettingsFigmaLayout.cardCornerRadius)
                    .stroke(Color.pepBorder, lineWidth: 1)
            )
        }
    }
}

struct SettingsMenuRow: View {
    let row: SettingsRowModel

    @ScaledMetric(relativeTo: .body) private var titleFontSize: CGFloat = 13
    @ScaledMetric(relativeTo: .subheadline) private var subtitleFontSize: CGFloat = 11

    var body: some View {
        HStack(spacing: Spacing.md) {
            icon
                .frame(
                    width: SettingsFigmaLayout.rowIconSize,
                    height: SettingsFigmaLayout.rowIconSize
                )
                .background(row.tone.backgroundColor)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(row.title)
                    .font(.system(size: titleFontSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.pepTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(row.subtitle)
                    .font(.system(size: subtitleFontSize, design: .rounded))
                    .foregroundStyle(Color.pepTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: Spacing.sm)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.pepTextTertiary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .frame(minHeight: 50)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(row.title), \(row.subtitle)")
    }

    @ViewBuilder
    private var icon: some View {
        if row.tone == .brand {
            Image("PeppyLogoMark")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(height: 17)
                .foregroundStyle(row.tone.foregroundColor)
                .accessibilityHidden(true)
        } else if let systemImage = row.systemImage {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(row.tone.foregroundColor)
                .accessibilityHidden(true)
        }
    }
}

struct SettingsRefreshBanner: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.pepError)
                .accessibilityHidden(true)

            Text(message)
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(Color.pepTextPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: Spacing.xs)

            Button("Retry", action: retry)
                .font(.system(.footnote, design: .rounded, weight: .semibold))
                .foregroundStyle(Color.pepPrimaryDark)
                .frame(minWidth: SettingsFigmaLayout.minimumTapTarget, minHeight: SettingsFigmaLayout.minimumTapTarget)
        }
        .padding(.leading, 12)
        .padding(.trailing, 6)
        .padding(.vertical, 4)
        .background(Color.pepErrorMuted)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.sm)
                .stroke(Color.pepPrimaryLight.opacity(0.45), lineWidth: 1)
        )
    }
}

private extension SettingsRowTone {
    var foregroundColor: Color {
        switch self {
        case .purple, .brand: Color(hex: "8F5BB7")
        case .orange: Color.pepWarning
        case .green: Color.pepSuccess
        case .coral: Color.pepPrimary
        case .gray: Color.pepTextSecondary
        }
    }

    var backgroundColor: Color {
        switch self {
        case .purple, .brand: Color(hex: "F4ECFA")
        case .orange: Color.pepWarningMuted
        case .green: Color.pepSuccessMuted
        case .coral: Color.pepPrimaryMuted
        case .gray: Color.pepSurfaceElevated
        }
    }
}
