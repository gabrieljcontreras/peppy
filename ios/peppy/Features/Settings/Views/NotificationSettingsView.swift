import SwiftUI
import UIKit

/// Values measured from the approved Notifications raster embedded in
/// `Peppy IOS (2).fig` (`980283…`, 853 × 1844 pixels).
enum NotificationSettingsFigmaLayout {
    static let referenceCanvasWidth: CGFloat = 853
    static let referenceCanvasHeight: CGFloat = 1_844
    static let horizontalPadding: CGFloat = 22
    static let minimumTapTarget: CGFloat = 44
    static let cardCornerRadius: CGFloat = 8
    static let headerControlDiameter: CGFloat = 30
    static let rowIconSize: CGFloat = 30
}

enum NotificationSettingsPresentation {
    static func lineLimit(for dynamicTypeSize: DynamicTypeSize) -> Int? {
        dynamicTypeSize.isAccessibilitySize ? nil : 2
    }

    static func displayTime(_ value: String?) -> String {
        guard let components = LocalNotificationScheduler.timeComponents(from: value),
              let hour = components.hour,
              let minute = components.minute else {
            return "Not set"
        }
        let date = Calendar(identifier: .gregorian).date(
            from: DateComponents(
                year: 2000,
                month: 1,
                day: 1,
                hour: hour,
                minute: minute
            )
        ) ?? Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    static func displayDose(_ compound: Compound) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.maximumFractionDigits = 3
        formatter.minimumFractionDigits = 0
        let amount = formatter.string(
            from: NSNumber(value: compound.doseMg)
        ) ?? "\(compound.doseMg)"
        return "\(amount) \(compound.doseUnit)"
    }
}

private enum NotificationQuietHoursEditor: Identifiable {
    case start
    case end

    var id: Int { self == .start ? 0 : 1 }
}

struct NotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase
    @State private var model: NotificationSettingsViewModel
    @State private var quietHoursEditor: NotificationQuietHoursEditor?
    private let showProtocols: () -> Void

    @ScaledMetric(relativeTo: .title) private var pageTitleSize: CGFloat = 24
    @ScaledMetric(relativeTo: .body) private var pageDescriptionSize: CGFloat = 12
    @ScaledMetric(relativeTo: .subheadline) private var helperSize: CGFloat = 11

    init(
        store: SettingsStore,
        protocolStore: ProtocolStore,
        permissionService: NotificationPermissionServiceProtocol,
        scheduler: LocalNotificationScheduling,
        registerForRemoteNotifications: @escaping () -> Void,
        showProtocols: @escaping () -> Void
    ) {
        _model = State(
            initialValue: NotificationSettingsViewModel(
                store: store,
                protocolStore: protocolStore,
                permissionService: permissionService,
                scheduler: scheduler,
                registerForRemoteNotifications: registerForRemoteNotifications
            )
        )
        self.showProtocols = showProtocols
    }

    #if DEBUG
    init(
        visualQAStore store: SettingsStore,
        protocolStore: ProtocolStore,
        permissionService: NotificationPermissionServiceProtocol,
        scheduler: LocalNotificationScheduling
    ) {
        let model = NotificationSettingsViewModel(
            store: store,
            protocolStore: protocolStore,
            permissionService: permissionService,
            scheduler: scheduler
        )
        model.draft.insightsEnabled = true
        model.draft.alertSeverityOnly = false
        model.draft.doseRemindersEnabled = true
        model.draft.dailyCheckinRemindersEnabled = true
        model.draft.dailyCheckinTime = "20:00:00"
        model.draft.detailedPreviewsEnabled = true
        model.draft.quietHoursStart = "22:00:00"
        model.draft.quietHoursEnd = "07:00:00"
        _model = State(initialValue: model)
        showProtocols = {}
    }
    #endif

    var body: some View {
        @Bindable var model = model

        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                headerControls
                pageHeader

                if let errorMessage = model.errorMessage {
                    notificationBanner(
                        message: errorMessage,
                        systemImage: "exclamationmark.triangle.fill",
                        tint: .pepError
                    )
                }

                if let repairMessage = model.repairMessage {
                    notificationBanner(
                        message: repairMessage,
                        systemImage: "arrow.clockwise.circle.fill",
                        tint: .pepWarning,
                        actionTitle: "Repair",
                        action: {
                            Task {
                                await model.repairLocalScheduling()
                                announce(
                                    model.repairMessage == nil
                                        ? "Notification reminders repaired."
                                        : model.repairMessage
                                )
                            }
                        }
                    )
                }

                if model.showsOpenSystemSettingsAction {
                    notificationBanner(
                        message: "Notifications are off in iOS Settings. Your Peppy preferences are still saved.",
                        systemImage: "bell.slash.fill",
                        tint: .pepWarning,
                        actionTitle: "Open Settings",
                        action: model.openSystemSettings
                    )
                }

                remindersSection
                    .disabled(model.isLoading)
                insightsSection
                    .disabled(model.isLoading)
                quietHoursSection
                    .disabled(model.isLoading)
                previewSection
                saveButton
            }
            .padding(.horizontal, NotificationSettingsFigmaLayout.horizontalPadding)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.lg)
        }
        .background(Color.pepBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $model.activeSetup) { setup in
            setupSheet(setup)
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $quietHoursEditor) { editor in
            QuietHoursTimeSheet(
                title: editor == .start ? "Quiet hours start" : "Quiet hours end",
                initialTime: editor == .start
                    ? model.draft.quietHoursStart
                    : model.draft.quietHoursEnd,
                onCancel: { quietHoursEditor = nil },
                onSave: { value in
                    switch editor {
                    case .start:
                        model.setQuietHours(
                            start: value,
                            end: model.draft.quietHoursEnd ?? "07:00:00"
                        )
                    case .end:
                        model.setQuietHours(
                            start: model.draft.quietHoursStart ?? "22:00:00",
                            end: value
                        )
                    }
                    quietHoursEditor = nil
                }
            )
            .presentationDetents([.height(360)])
            .presentationDragIndicator(.visible)
        }
        .task {
            await model.load()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                await model.refreshPermissionStatus()
            }
        }
    }

    private var headerControls: some View {
        ZStack {
            HStack {
                Button {
                    dismiss()
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
                        width: NotificationSettingsFigmaLayout.headerControlDiameter,
                        height: NotificationSettingsFigmaLayout.headerControlDiameter
                    )
                    .frame(
                        width: NotificationSettingsFigmaLayout.minimumTapTarget,
                        height: NotificationSettingsFigmaLayout.minimumTapTarget
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back to More")

                Spacer()

                PeppyLogo(size: 17)
                    .frame(
                        width: NotificationSettingsFigmaLayout.headerControlDiameter,
                        height: NotificationSettingsFigmaLayout.headerControlDiameter
                    )
                    .background(Color.pepSurface)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.pepBorder, lineWidth: 1))
                    .frame(
                        width: NotificationSettingsFigmaLayout.minimumTapTarget,
                        height: NotificationSettingsFigmaLayout.minimumTapTarget
                    )
            }

            NotificationWordmark()
        }
    }

    private var pageHeader: some View {
        VStack(spacing: 2) {
            Text("Notifications")
                .font(
                    .system(
                        size: pageTitleSize,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .foregroundStyle(Color.pepTextPrimary)

            Text("Choose what Peppy sends and when reminders arrive.")
                .font(.system(size: pageDescriptionSize, design: .rounded))
                .foregroundStyle(Color.pepTextSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    private var remindersSection: some View {
        NotificationSection(title: "Reminder notifications") {
            NotificationCard {
                NotificationToggleRow(
                    systemImage: "syringe.fill",
                    title: "Dose reminders",
                    subtitle: "Based on your active protocol",
                    tint: .pepPrimary,
                    background: .pepPrimaryMuted,
                    isOn: Binding(
                        get: { model.draft.doseRemindersEnabled },
                        set: model.setDoseRemindersEnabled
                    )
                )

                NotificationDivider()

                NotificationToggleRow(
                    systemImage: "checkmark.circle.fill",
                    title: "Daily check-in reminders",
                    subtitle: model.draft.dailyCheckinRemindersEnabled
                        ? NotificationSettingsPresentation.displayTime(
                            model.draft.dailyCheckinTime
                        )
                        : "Build a consistent check-in habit",
                    tint: .pepSuccess,
                    background: .pepSuccessMuted,
                    isOn: Binding(
                        get: { model.draft.dailyCheckinRemindersEnabled },
                        set: model.setDailyCheckinRemindersEnabled
                    )
                )
            }
        }
    }

    private var insightsSection: some View {
        NotificationSection(title: "Insights & updates") {
            NotificationCard {
                NotificationToggleRow(
                    systemImage: "lightbulb.fill",
                    title: "Insights",
                    subtitle: "New patterns and weekly summaries",
                    tint: Color(hex: "8F5BB7"),
                    background: Color(hex: "F4ECFA"),
                    isOn: Binding(
                        get: { model.draft.insightsEnabled },
                        set: model.setInsightsEnabled
                    )
                )

                NotificationDivider()

                NotificationToggleRow(
                    systemImage: "bell.badge.fill",
                    title: "Alert-level insights only",
                    subtitle: "Limit insight notifications to important alerts",
                    tint: .pepWarning,
                    background: .pepWarningMuted,
                    isOn: Binding(
                        get: { model.draft.alertSeverityOnly },
                        set: model.setAlertSeverityOnly
                    ),
                    isEnabled: model.draft.insightsEnabled
                )
            }
        }
    }

    private var quietHoursSection: some View {
        NotificationSection(
            title: "Quiet hours",
            subtitle: "Pause check-in and insight notifications overnight."
        ) {
            NotificationCard {
                NotificationValueRow(
                    systemImage: "moon.fill",
                    title: "Start",
                    value: NotificationSettingsPresentation.displayTime(
                        model.draft.quietHoursStart
                    ),
                    tint: .pepInfo,
                    background: .pepInfoMuted,
                    action: { quietHoursEditor = .start }
                )

                NotificationDivider()

                NotificationValueRow(
                    systemImage: "sunrise.fill",
                    title: "End",
                    value: NotificationSettingsPresentation.displayTime(
                        model.draft.quietHoursEnd
                    ),
                    tint: .pepWarning,
                    background: .pepWarningMuted,
                    action: { quietHoursEditor = .end }
                )
            }

            Label(
                "Dose reminders still arrive during quiet hours.",
                systemImage: "info.circle"
            )
            .font(.system(size: helperSize, design: .rounded))
            .foregroundStyle(Color.pepTextSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var previewSection: some View {
        NotificationSection(title: "Notification preview") {
            VStack(spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    PeppyLogo(size: 22)
                        .frame(width: 34, height: 34)
                        .background(Color.pepPrimaryMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("PEPPY")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.pepTextSecondary)
                            Spacer()
                            Text(previewTime)
                                .font(.system(size: 10, design: .rounded))
                                .foregroundStyle(Color.pepTextTertiary)
                        }

                        Text(
                            model.draft.detailedPreviewsEnabled
                                ? previewTitle
                                : "Peppy"
                        )
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(Color.pepTextPrimary)

                        Text(
                            model.draft.detailedPreviewsEnabled
                                ? previewBody
                                : "You have a Peppy reminder"
                        )
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Color.pepTextSecondary)
                        .lineLimit(
                            NotificationSettingsPresentation.lineLimit(
                                for: dynamicTypeSize
                            )
                        )
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(12)
                .background(Color.pepSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Text(
                    model.draft.detailedPreviewsEnabled
                        ? "Detailed previews can show dose information on your lock screen."
                        : "Generic previews hide dose details on your lock screen."
                )
                .font(.system(size: helperSize, design: .rounded))
                .foregroundStyle(Color.pepTextSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(Color.pepPrimaryMuted)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: NotificationSettingsFigmaLayout.cardCornerRadius
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: NotificationSettingsFigmaLayout.cardCornerRadius
                )
                .stroke(Color.pepPrimaryLight.opacity(0.35), lineWidth: 1)
            )
        }
    }

    private var saveButton: some View {
        Button {
            Task {
                let saved = await model.save()
                announce(
                    saved
                        ? "Notification settings saved."
                        : model.errorMessage
                )
            }
        } label: {
            HStack(spacing: Spacing.sm) {
                if model.isSaving {
                    ProgressView()
                        .tint(.white)
                }
                Text(model.isSaving ? "Saving…" : "Save changes")
            }
            .font(.system(.headline, design: .rounded, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .background(model.canSave ? Color.pepPrimary : Color.pepTextTertiary)
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .disabled(!model.canSave)
        .accessibilityHint("Saves your notification preferences to your Peppy account")
    }

    private var previewReminder: DoseReminderPreference? {
        model.draft.doseReminders.first(where: \.enabled)
    }

    private var previewCompound: Compound? {
        if let compoundID = previewReminder?.compoundID,
           let compound = model.activeProtocol?.compounds.first(where: {
               $0.id == compoundID
           }) {
            return compound
        }
        return model.activeProtocol?.compounds.first
    }

    private var previewTime: String {
        NotificationSettingsPresentation.displayTime(
            previewReminder?.localTime ?? "09:00:00"
        )
    }

    private var previewTitle: String {
        "Time for your \(previewCompound?.name ?? "Retatrutide") dose"
    }

    private var previewBody: String {
        let dose: String
        if let previewCompound {
            dose = NotificationSettingsPresentation.displayDose(previewCompound)
        } else {
            dose = "4 mg"
        }
        return "Your \(dose) dose is scheduled for \(previewTime)."
    }

    private func announce(_ message: String?) {
        guard let message, !message.isEmpty else { return }
        UIAccessibility.post(notification: .announcement, argument: message)
    }

    @ViewBuilder
    private func setupSheet(_ setup: NotificationReminderSetup) -> some View {
        switch setup {
        case .dose:
            DoseReminderSetupSheet(
                activeProtocol: model.activeProtocol,
                existingReminders: model.draft.doseReminders,
                onCancel: model.cancelSetup,
                onOpenProtocols: {
                    model.cancelSetup()
                    showProtocols()
                },
                onConfirm: { reminders in
                    Task { await model.confirmDoseSetup(reminders: reminders) }
                }
            )
        case .dailyCheckin:
            DailyCheckinReminderSetupSheet(
                initialTime: model.draft.dailyCheckinTime,
                onCancel: model.cancelSetup,
                onConfirm: { localTime in
                    Task {
                        await model.confirmDailyCheckinSetup(
                            localTime: localTime
                        )
                    }
                }
            )
        case .detailedPreviews:
            DetailedPreviewSetupSheet(
                isDetailed: model.draft.detailedPreviewsEnabled,
                onConfirm: model.confirmDetailedPreviews
            )
        }
    }

    private func notificationBanner(
        message: String,
        systemImage: String,
        tint: Color,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: systemImage)
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
                    .frame(minHeight: NotificationSettingsFigmaLayout.minimumTapTarget)
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .padding(.vertical, 6)
        .background(tint.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct NotificationWordmark: View {
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

private struct NotificationSection<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let content: Content

    @ScaledMetric(relativeTo: .headline) private var titleSize: CGFloat = 13
    @ScaledMetric(relativeTo: .subheadline) private var subtitleSize: CGFloat = 11

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: titleSize, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.pepTextSecondary)

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: subtitleSize, design: .rounded))
                    .foregroundStyle(Color.pepTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            content
        }
    }
}

private struct NotificationCard<Content: View>: View {
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
            RoundedRectangle(
                cornerRadius: NotificationSettingsFigmaLayout.cardCornerRadius
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: NotificationSettingsFigmaLayout.cardCornerRadius
            )
            .stroke(Color.pepBorder, lineWidth: 1)
        )
    }
}

private struct NotificationToggleRow: View {
    let systemImage: String
    let title: String
    let subtitle: String
    let tint: Color
    let background: Color
    @Binding var isOn: Bool
    var isEnabled = true

    @ScaledMetric(relativeTo: .body) private var titleSize: CGFloat = 13
    @ScaledMetric(relativeTo: .subheadline) private var subtitleSize: CGFloat = 11

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(
                    width: NotificationSettingsFigmaLayout.rowIconSize,
                    height: NotificationSettingsFigmaLayout.rowIconSize
                )
                .background(background)
                .clipShape(Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: titleSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.pepTextPrimary)
                Text(subtitle)
                    .font(.system(size: subtitleSize, design: .rounded))
                    .foregroundStyle(Color.pepTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: Spacing.sm)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.pepSuccess)
                .frame(minWidth: 51, minHeight: 44)
                .disabled(!isEnabled)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .frame(minHeight: 54)
        .opacity(isEnabled ? 1 : 0.55)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(subtitle)")
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

private struct NotificationValueRow: View {
    let systemImage: String
    let title: String
    let value: String
    let tint: Color
    let background: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(
                        width: NotificationSettingsFigmaLayout.rowIconSize,
                        height: NotificationSettingsFigmaLayout.rowIconSize
                    )
                    .background(background)
                    .clipShape(Circle())
                    .accessibilityHidden(true)

                Text(title)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(Color.pepTextPrimary)

                Spacer()

                HStack(spacing: 6) {
                    Text(value)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .accessibilityHidden(true)
                }
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(Color.pepTextSecondary)
                .padding(.horizontal, 10)
                .frame(minHeight: 32)
                .background(Color.pepBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.pepBorder, lineWidth: 1)
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(value)")
        .accessibilityHint("Opens a time picker")
    }
}

private struct NotificationDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.pepBorderLight)
            .frame(height: 1)
            .padding(.leading, 12)
    }
}
