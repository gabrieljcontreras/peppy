import SwiftUI

/// Values measured from the approved Profile raster embedded in
/// `Peppy IOS (2).fig` (`d3b52e…`, 853 × 1844 pixels).
enum ProfileSettingsFigmaLayout {
    static let referenceCanvasWidth: CGFloat = 853
    static let referenceCanvasHeight: CGFloat = 1_844
    static let horizontalPadding: CGFloat = 22
    static let minimumTapTarget: CGFloat = 44
    static let headerControlDiameter: CGFloat = 30
    static let headerTopAdjustment: CGFloat = -18
    static let bodyTopAdjustment: CGFloat = -8
    static let headerLogoHeight: CGFloat = 24
    static let rowIconSize: CGFloat = 30
    static let cardCornerRadius: CGFloat = 8
    static let accountRowMinimumHeight: CGFloat = 51
    static let rowMinimumHeight: CGFloat = 48
    static let baselineRowMinimumHeight: CGFloat = 44
    static let compactRowMinimumHeight: CGFloat = 32
    static let saveButtonVisualHeight: CGFloat = 32
}

enum ProfileSettingsPresentation {
    static let isEmailEditable = false
    static let sectionTitles = [
        "Account information",
        "Preferences",
        "Baseline information",
        "Onboarding goals"
    ]

    static func emailAccessibilityValue(_ email: String) -> String {
        "\(email), read only"
    }

    nonisolated static func baselineDateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}

struct ProfileSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: ProfileSettingsViewModel
    @State private var editor: ProfileEditor?

    init(
        store: SettingsStore,
        weightUnitPreferences: WeightUnitPreferences,
        now: @escaping () -> Date = Date.init
    ) {
        _model = State(
            initialValue: ProfileSettingsViewModel(
                store: store,
                weightUnitPreferences: weightUnitPreferences,
                now: now
            )
        )
    }

    #if DEBUG
    /// Deterministic state injection for the approved Figma frame, whose Save
    /// button is shown enabled. The tiny canonical change does not alter the
    /// displayed one-decimal weight value.
    init(
        visualQAStore store: SettingsStore,
        weightUnitPreferences: WeightUnitPreferences,
        now: @escaping () -> Date
    ) {
        let model = ProfileSettingsViewModel(
            store: store,
            weightUnitPreferences: weightUnitPreferences,
            now: now
        )
        model.draft.baselineWeightKg = (model.draft.baselineWeightKg ?? 0) + 0.000_001
        _model = State(initialValue: model)
    }
    #endif

    var body: some View {
        @Bindable var model = model

        ScrollView {
            ZStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 12) {
                    header

                    if let errorMessage = model.errorMessage {
                        ProfileInlineError(message: errorMessage)
                    }

                    accountSection
                        .padding(.top, ProfileSettingsFigmaLayout.bodyTopAdjustment)
                    preferencesSection
                        .padding(.top, 6)
                    baselineSection
                        .padding(.top, 3)
                    goalsSection
                    saveSection
                }
                .padding(.horizontal, ProfileSettingsFigmaLayout.horizontalPadding)
                .padding(.top, ProfileSettingsFigmaLayout.headerTopAdjustment)
                .padding(.bottom, Spacing.xs)

                headerControls
                    .padding(.horizontal, ProfileSettingsFigmaLayout.horizontalPadding)
            }
        }
        .scrollClipDisabled()
        .background(Color.pepBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $editor) { editor in
            ProfileEditorSheet(editor: editor, model: model)
                .presentationDragIndicator(.visible)
        }
        .confirmationDialog(
            "Discard unsaved changes?",
            isPresented: $model.isDiscardConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Discard Changes", role: .destructive) {
                model.discardChanges()
                dismiss()
            }
            Button("Keep Editing", role: .cancel) {
                model.cancelDiscardConfirmation()
            }
        } message: {
            Text("Your profile changes have not been saved.")
        }
        .task {
            await model.refreshIfNeeded()
        }
    }

    private var header: some View {
        VStack(spacing: 2) {
            headerControls
                .hidden()
                .accessibilityHidden(true)

            Text("Profile")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Color.pepTextPrimary)

            Text("Manage your account, preferences, and health information.")
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(Color.pepTextSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    private var headerControls: some View {
        ZStack {
            HStack {
                Button {
                    if model.requestDismiss() {
                        dismiss()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.pepSurface)
                            .overlay(Circle().stroke(Color.pepBorder, lineWidth: 1))

                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.pepTextPrimary)
                    }
                    .frame(
                        width: ProfileSettingsFigmaLayout.headerControlDiameter,
                        height: ProfileSettingsFigmaLayout.headerControlDiameter
                    )
                    .frame(
                        width: ProfileSettingsFigmaLayout.minimumTapTarget,
                        height: ProfileSettingsFigmaLayout.minimumTapTarget
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back to More")

                Spacer()

                PeppyLogo(size: 17)
                    .frame(
                        width: ProfileSettingsFigmaLayout.headerControlDiameter,
                        height: ProfileSettingsFigmaLayout.headerControlDiameter
                    )
                    .background(Color.pepSurface)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.pepBorder, lineWidth: 1))
                    .frame(
                        width: ProfileSettingsFigmaLayout.minimumTapTarget,
                        height: ProfileSettingsFigmaLayout.minimumTapTarget
                    )
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Peppy")
            }

            ProfileWordmark()
        }
    }

    private var accountSection: some View {
        ProfileSection(
            title: "Account information",
            subtitle: "This is used to manage your account and app access."
        ) {
            ProfileCard {
                ProfileValueRow(
                    systemImage: "person",
                    title: "Full name",
                    value: model.draft.fullName.isEmpty ? "Not set" : model.draft.fullName,
                    actionTitle: "Edit",
                    minimumHeight: ProfileSettingsFigmaLayout.accountRowMinimumHeight,
                    action: { editor = .name }
                )

                ProfileDivider()

                ProfileValueRow(
                    systemImage: "envelope",
                    title: "Email",
                    value: model.draft.email.isEmpty ? "Not available" : model.draft.email,
                    minimumHeight: ProfileSettingsFigmaLayout.accountRowMinimumHeight
                )
                .accessibilityValue(
                    ProfileSettingsPresentation.emailAccessibilityValue(model.draft.email)
                )
            }
        }
    }

    private var preferencesSection: some View {
        ProfileSection(
            title: "Preferences",
            subtitle: "Customize your units and display preferences."
        ) {
            ProfileCard {
                ProfilePreferenceRow(
                    systemImage: "scalemass",
                    title: "Preferred weight unit",
                    subtitle: "Used across your charts and logs"
                ) {
                    ProfileUnitControl(
                        options: [
                            ("lb", WeightUnit.pounds.rawValue),
                            ("kg", WeightUnit.kilograms.rawValue)
                        ],
                        selection: model.draft.weightUnit.rawValue,
                        onSelect: { rawValue in
                            if let unit = WeightUnit(rawValue: rawValue) {
                                model.draft.weightUnit = unit
                            }
                        }
                    )
                }

                ProfileDivider()

                ProfilePreferenceRow(
                    systemImage: "ruler",
                    title: "Preferred height unit",
                    subtitle: "Used across your charts and logs"
                ) {
                    ProfileUnitControl(
                        options: [
                            ("ft / in", HeightUnit.feetAndInches.rawValue),
                            ("cm", HeightUnit.centimeters.rawValue)
                        ],
                        selection: model.draft.heightUnit.rawValue,
                        onSelect: { rawValue in
                            if let unit = HeightUnit(rawValue: rawValue) {
                                model.draft.heightUnit = unit
                            }
                        }
                    )
                }
            }
            .padding(.top, 4)
        }
    }

    private var baselineSection: some View {
        ProfileSection(
            title: "Baseline information",
            subtitle: "Your health information is private and never shared.",
            subtitleSystemImage: "lock.fill"
        ) {
            ProfileCard {
                ProfileValueRow(
                    systemImage: "calendar",
                    title: "Baseline date",
                    value: model.draft.baselineDate.map(
                        ProfileSettingsPresentation.baselineDateText
                    ) ?? "Not set",
                    actionTitle: "Edit",
                    minimumHeight: ProfileSettingsFigmaLayout.baselineRowMinimumHeight,
                    action: { editor = .baselineDate }
                )

                ProfileDivider()

                ProfileValueRow(
                    systemImage: "scalemass",
                    title: "Baseline weight",
                    value: model.draft.baselineWeightKg.map(model.draft.weightUnit.format(kilograms:)) ?? "Not set",
                    actionTitle: "Edit",
                    minimumHeight: ProfileSettingsFigmaLayout.baselineRowMinimumHeight,
                    action: { editor = .baselineWeight }
                )

                ProfileDivider()

                ProfileValueRow(
                    systemImage: "ruler",
                    title: "Baseline height",
                    value: model.draft.baselineHeightCm.map(model.draft.heightUnit.format(centimeters:)) ?? "Not set",
                    actionTitle: "Edit",
                    minimumHeight: ProfileSettingsFigmaLayout.baselineRowMinimumHeight,
                    action: { editor = .baselineHeight }
                )
            }
            .padding(.top, 3)
        }
    }

    private var goalsSection: some View {
        ProfileSection(
            title: "Onboarding goals",
            subtitle: "These help Peppy personalize insights and recommendations."
        ) {
            ProfileCard {
                ProfileValueRow(
                    systemImage: "scope",
                    title: "Primary goal",
                    value: model.draft.primaryGoal?.title ?? "Choose a goal",
                    showsChevron: true,
                    isGoal: true,
                    action: { editor = .primaryGoal }
                )

                ProfileDivider()

                ProfileValueRow(
                    systemImage: "bolt.fill",
                    title: "Secondary goal (optional)",
                    value: model.draft.secondaryGoal?.title ?? "None",
                    showsChevron: true,
                    isGoal: true,
                    action: { editor = .secondaryGoal }
                )

                ProfileDivider()

                ProfileValueRow(
                    systemImage: "leaf.fill",
                    title: "Focus area (optional)",
                    value: model.draft.focusArea?.title ?? "None",
                    showsChevron: true,
                    isGoal: true,
                    action: { editor = .focusArea }
                )
            }
        }
    }

    private var saveSection: some View {
        VStack(spacing: 3) {
            if let validationErrorMessage = model.validationErrorMessage,
               model.hasUnsavedChanges {
                Text(validationErrorMessage)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color.pepError)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("profile-validation-error")
            }

            Button {
                Task { await model.save() }
            } label: {
                HStack(spacing: Spacing.sm) {
                    if model.isSaving {
                        ProgressView()
                            .tint(.white)
                    }
                    Text("Save changes")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: ProfileSettingsFigmaLayout.saveButtonVisualHeight)
                .background(Color.pepPrimary)
                .clipShape(
                    RoundedRectangle(cornerRadius: ProfileSettingsFigmaLayout.cardCornerRadius)
                )
            }
            .buttonStyle(.plain)
            .frame(minHeight: ProfileSettingsFigmaLayout.minimumTapTarget)
            .disabled(!model.canSave)
            .accessibilityIdentifier("profile-save-changes")

            Text("Changes are saved to your account securely.")
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(Color.pepTextSecondary)
                .frame(maxWidth: .infinity)
        }
    }

}

private struct ProfileWordmark: View {
    var body: some View {
        Image("PeppyLogoWordmark")
            .resizable()
            .scaledToFit()
            .frame(width: 84, height: 36)
            .offset(x: -15)
            .frame(width: 56, height: ProfileSettingsFigmaLayout.headerLogoHeight)
            .clipped()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Peppy")
    }
}

private struct ProfileSection<Content: View>: View {
    let title: String
    let subtitle: String
    var subtitleSystemImage: String?
    @ViewBuilder let content: Content

    init(
        title: String,
        subtitle: String,
        subtitleSystemImage: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.subtitleSystemImage = subtitleSystemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.pepTextPrimary)

                HStack(spacing: 4) {
                    if let subtitleSystemImage {
                        Image(systemName: subtitleSystemImage)
                            .font(.system(size: 10, weight: .semibold))
                            .accessibilityHidden(true)
                    }
                    Text(subtitle)
                }
                .font(.system(size: 8, design: .rounded))
                .foregroundStyle(Color.pepTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            content
        }
    }
}

private struct ProfileCard<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(Color.pepSurface)
        .clipShape(
            RoundedRectangle(cornerRadius: ProfileSettingsFigmaLayout.cardCornerRadius)
        )
        .overlay {
            RoundedRectangle(cornerRadius: ProfileSettingsFigmaLayout.cardCornerRadius)
                .stroke(Color.pepBorder, lineWidth: 1)
        }
    }
}

private struct ProfileValueRow: View {
    let systemImage: String
    let title: String
    let value: String
    var actionTitle: String?
    var showsChevron = false
    var isGoal = false
    var minimumHeight = ProfileSettingsFigmaLayout.rowMinimumHeight
    var action: (() -> Void)?

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    content
                }
                .buttonStyle(.plain)
            } else {
                content
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value)")
    }

    private var content: some View {
        HStack(spacing: 12) {
            ProfileRowIcon(
                systemImage: systemImage,
                size: isGoal ? 24 : ProfileSettingsFigmaLayout.rowIconSize,
                fontSize: isGoal ? 12 : 15
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(
                        .system(
                            size: isGoal ? 9 : 8,
                            weight: isGoal ? .medium : .regular,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(isGoal ? Color.pepTextPrimary : Color.pepTextSecondary)
                Text(value)
                    .font(
                        .system(
                            size: isGoal ? 9 : 10,
                            weight: isGoal ? .regular : .medium,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(isGoal ? Color.pepTextSecondary : Color.pepTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: Spacing.sm)

            if let actionTitle {
                Text(actionTitle)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.pepPrimary)
                    .frame(width: 36, height: 24)
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.pepPrimaryLight, lineWidth: 1)
                    }
            } else if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.pepTextSecondary)
                    .frame(width: 20, height: 20)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, isGoal ? 10 : 12)
        .padding(.vertical, isGoal ? 2 : 3)
        .frame(
            minHeight: isGoal
                ? ProfileSettingsFigmaLayout.compactRowMinimumHeight
                : minimumHeight
        )
        .overlay {
            if isGoal {
                Color.clear
                    .contentShape(Rectangle())
                    .frame(minHeight: ProfileSettingsFigmaLayout.minimumTapTarget)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

private struct ProfilePreferenceRow<Control: View>: View {
    let systemImage: String
    let title: String
    let subtitle: String
    @ViewBuilder let control: Control

    init(
        systemImage: String,
        title: String,
        subtitle: String,
        @ViewBuilder control: () -> Control
    ) {
        self.systemImage = systemImage
        self.title = title
        self.subtitle = subtitle
        self.control = control()
    }

    var body: some View {
        HStack(spacing: 12) {
            ProfileRowIcon(systemImage: systemImage)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.pepTextPrimary)
                Text(subtitle)
                    .font(.system(size: 8, design: .rounded))
                    .foregroundStyle(Color.pepTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)
            control
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
        .frame(minHeight: ProfileSettingsFigmaLayout.rowMinimumHeight)
    }
}

private struct ProfileUnitControl: View {
    let options: [(label: String, value: String)]
    let selection: String
    let onSelect: (String) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                Button {
                    onSelect(option.value)
                } label: {
                    Text(option.label)
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundStyle(
                            selection == option.value ? Color.pepPrimary : Color.pepTextPrimary
                        )
                        .frame(minWidth: 45)
                        .frame(height: 24)
                        .background(
                            selection == option.value ? Color.pepPrimaryMuted : Color.pepSurface
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == option.value ? .isSelected : [])

                if index < options.count - 1 {
                    Rectangle()
                        .fill(Color.pepBorder)
                        .frame(width: 1, height: 24)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .stroke(Color.pepBorder, lineWidth: 1)
        }
        .frame(minHeight: ProfileSettingsFigmaLayout.minimumTapTarget)
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .contain)
    }
}

private struct ProfileRowIcon: View {
    let systemImage: String
    var size = ProfileSettingsFigmaLayout.rowIconSize
    var fontSize: CGFloat = 15

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: fontSize, weight: .medium))
            .foregroundStyle(Color.pepPrimary)
            .frame(
                width: size,
                height: size
            )
            .background(Color.pepPrimaryMuted)
            .clipShape(Circle())
            .accessibilityHidden(true)
    }
}

private struct ProfileDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.pepBorderLight)
            .frame(height: 1)
            .padding(.horizontal, 12)
    }
}

private struct ProfileInlineError: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(Color.pepError)
                .accessibilityHidden(true)
            Text(message)
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(Color.pepTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.pepErrorMuted)
        .clipShape(RoundedRectangle(cornerRadius: ProfileSettingsFigmaLayout.cardCornerRadius))
        .accessibilityIdentifier("profile-save-error")
    }
}

#Preview {
    let dependencies = Dependencies.mock()
    return NavigationStack {
        ProfileSettingsView(
            store: dependencies.settingsStore,
            weightUnitPreferences: dependencies.weightUnitPreferences
        )
    }
    .withDependencies(dependencies)
}
