import SwiftUI

struct DoseReminderSetupSheet: View {
    let activeProtocol: ProtocolModel?
    let onCancel: () -> Void
    let onOpenProtocols: () -> Void
    let onConfirm: ([DoseReminderPreference]) -> Void

    @State private var reminderTimes: [UUID: Date]
    @State private var enabledCompoundIDs: Set<UUID>

    init(
        activeProtocol: ProtocolModel?,
        existingReminders: [DoseReminderPreference],
        onCancel: @escaping () -> Void,
        onOpenProtocols: @escaping () -> Void,
        onConfirm: @escaping ([DoseReminderPreference]) -> Void
    ) {
        self.activeProtocol = activeProtocol
        self.onCancel = onCancel
        self.onOpenProtocols = onOpenProtocols
        self.onConfirm = onConfirm

        var times: [UUID: Date] = [:]
        var enabledIDs: Set<UUID> = []
        for compound in activeProtocol?.compounds ?? [] {
            let existing = existingReminders.first {
                $0.compoundID == compound.id
            }
            times[compound.id] = ReminderTimeFormatter.date(
                from: existing?.localTime
            )
            if existing?.enabled ?? true {
                enabledIDs.insert(compound.id)
            }
        }
        _reminderTimes = State(initialValue: times)
        _enabledCompoundIDs = State(initialValue: enabledIDs)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let activeProtocol, !activeProtocol.compounds.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            Text("Set a local reminder time for each compound in \(activeProtocol.name).")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(Color.pepTextSecondary)
                                .fixedSize(horizontal: false, vertical: true)

                            ForEach(activeProtocol.compounds) { compound in
                                compoundRow(compound)
                            }
                        }
                        .padding(Spacing.md)
                    }
                } else {
                    VStack(spacing: Spacing.md) {
                        ContentUnavailableView(
                            "No active protocol",
                            systemImage: "cross.case",
                            description: Text(
                                "Activate a protocol before turning on dose reminders."
                            )
                        )

                        Button("View protocols", action: onOpenProtocols)
                            .font(
                                .system(
                                    .headline,
                                    design: .rounded,
                                    weight: .semibold
                                )
                            )
                            .foregroundStyle(.white)
                            .padding(.horizontal, Spacing.lg)
                            .frame(minHeight: 48)
                            .background(Color.pepPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
            .background(Color.pepBackground.ignoresSafeArea())
            .navigationTitle("Dose reminders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Continue") {
                        onConfirm(reminders)
                    }
                    .disabled(!reminders.contains(where: \.enabled))
                }
            }
        }
    }

    private func compoundRow(_ compound: Compound) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(
                isOn: Binding(
                    get: { enabledCompoundIDs.contains(compound.id) },
                    set: { enabled in
                        if enabled {
                            enabledCompoundIDs.insert(compound.id)
                        } else {
                            enabledCompoundIDs.remove(compound.id)
                        }
                    }
                )
            ) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(compound.name)
                        .font(.system(.body, design: .rounded, weight: .semibold))
                    Text(compound.frequency.capitalized)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Color.pepTextSecondary)
                }
            }
            .tint(.pepSuccess)

            DatePicker(
                "Reminder time",
                selection: Binding(
                    get: {
                        reminderTimes[compound.id]
                            ?? ReminderTimeFormatter.defaultDate
                    },
                    set: { reminderTimes[compound.id] = $0 }
                ),
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.compact)
            .disabled(!enabledCompoundIDs.contains(compound.id))
        }
        .padding(Spacing.md)
        .background(Color.pepSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.pepBorder, lineWidth: 1)
        )
    }

    private var reminders: [DoseReminderPreference] {
        DoseReminderSetupState.reminders(
            compounds: activeProtocol?.compounds ?? [],
            enabledCompoundIDs: enabledCompoundIDs,
            reminderTimes: reminderTimes
        )
    }
}

struct DailyCheckinReminderSetupSheet: View {
    let onCancel: () -> Void
    let onConfirm: (String) -> Void
    @State private var selectedTime: Date

    init(
        initialTime: String?,
        onCancel: @escaping () -> Void,
        onConfirm: @escaping (String) -> Void
    ) {
        self.onCancel = onCancel
        self.onConfirm = onConfirm
        _selectedTime = State(
            initialValue: ReminderTimeFormatter.date(from: initialTime)
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.lg) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(Color.pepSuccess)
                    .accessibilityHidden(true)

                Text("Pick a time when you can pause for a quick daily check-in.")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(Color.pepTextSecondary)
                    .multilineTextAlignment(.center)

                DatePicker(
                    "Daily check-in time",
                    selection: $selectedTime,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
            }
            .padding(Spacing.lg)
            .background(Color.pepBackground.ignoresSafeArea())
            .navigationTitle("Daily check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Continue") {
                        onConfirm(ReminderTimeFormatter.string(from: selectedTime))
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct DetailedPreviewSetupSheet: View {
    let onConfirm: (Bool) -> Void
    @State private var isDetailed: Bool

    init(
        isDetailed: Bool,
        onConfirm: @escaping (Bool) -> Void
    ) {
        self.onConfirm = onConfirm
        _isDetailed = State(initialValue: isDetailed)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("Show dose details in notification previews?")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(Color.pepTextPrimary)

                Text(
                    "Detailed previews are convenient, but medication information may be visible on your lock screen."
                )
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Color.pepTextSecondary)
                .fixedSize(horizontal: false, vertical: true)

                Picker("Notification preview", selection: $isDetailed) {
                    Text("Keep private").tag(false)
                    Text("Show details").tag(true)
                }
                .pickerStyle(.segmented)

                Spacer()

                Button("Done") {
                    onConfirm(isDetailed)
                }
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Color.pepPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .padding(Spacing.lg)
            .background(Color.pepBackground.ignoresSafeArea())
            .navigationTitle("Preview privacy")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
        .interactiveDismissDisabled()
    }
}

struct QuietHoursTimeSheet: View {
    let title: String
    let onCancel: () -> Void
    let onSave: (String) -> Void
    @State private var selectedTime: Date

    init(
        title: String,
        initialTime: String?,
        onCancel: @escaping () -> Void,
        onSave: @escaping (String) -> Void
    ) {
        self.title = title
        self.onCancel = onCancel
        self.onSave = onSave
        _selectedTime = State(
            initialValue: ReminderTimeFormatter.date(from: initialTime)
        )
    }

    var body: some View {
        NavigationStack {
            DatePicker(
                title,
                selection: $selectedTime,
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .padding()
            .background(Color.pepBackground.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(ReminderTimeFormatter.string(from: selectedTime))
                    }
                }
            }
        }
    }
}

enum DoseReminderSetupState {
    static func reminders(
        compounds: [Compound],
        enabledCompoundIDs: Set<UUID>,
        reminderTimes: [UUID: Date]
    ) -> [DoseReminderPreference] {
        compounds.map { compound in
            DoseReminderPreference(
                compoundID: compound.id,
                localTime: ReminderTimeFormatter.string(
                    from: reminderTimes[compound.id]
                        ?? ReminderTimeFormatter.defaultDate
                ),
                enabled: enabledCompoundIDs.contains(compound.id)
            )
        }
    }
}

private enum ReminderTimeFormatter {
    static let defaultDate: Date = {
        Calendar(identifier: .gregorian).date(
            from: DateComponents(
                year: 2000,
                month: 1,
                day: 1,
                hour: 20,
                minute: 0
            )
        )!
    }()

    static func date(from value: String?) -> Date {
        guard let components = LocalNotificationScheduler.timeComponents(
            from: value
        ) else {
            return defaultDate
        }
        return Calendar(identifier: .gregorian).date(
            from: DateComponents(
                year: 2000,
                month: 1,
                day: 1,
                hour: components.hour,
                minute: components.minute
            )
        ) ?? defaultDate
    }

    static func string(from date: Date) -> String {
        let components = Calendar.current.dateComponents(
            [.hour, .minute],
            from: date
        )
        return String(
            format: "%02d:%02d:00",
            components.hour ?? 20,
            components.minute ?? 0
        )
    }
}
