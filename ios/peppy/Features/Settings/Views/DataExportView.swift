import SwiftUI
import UIKit

enum DataExportFigmaLayout {
    static let horizontalPadding: CGFloat = 22
    static let minimumTapTarget: CGFloat = 44
    static let headerControlDiameter: CGFloat = 30
    static let cardCornerRadius: CGFloat = 8
}

struct DataExportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: DataExportViewModel
    @State private var showsDatePicker = false
    @State private var showsShareSheet = false

    @ScaledMetric(relativeTo: .title) private var pageTitleSize: CGFloat = 24
    @ScaledMetric(relativeTo: .body) private var pageDescriptionSize: CGFloat = 12
    @ScaledMetric(relativeTo: .body) private var rowTitleSize: CGFloat = 13
    @ScaledMetric(relativeTo: .subheadline) private var rowSubtitleSize: CGFloat = 11
    @ScaledMetric(relativeTo: .footnote) private var warningTitleSize: CGFloat = 12

    init(
        api: APIClientProtocol,
        fileService: ExportFileServicing
    ) {
        _model = State(
            initialValue: DataExportViewModel(
                api: api,
                fileService: fileService
            )
        )
    }

    var body: some View {
        @Bindable var model = model

        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                headerControls
                pageHeader

                exportCategories
                exportFormat
                dateRange

                if let errorMessage = model.errorMessage {
                    errorBanner(errorMessage)
                }

                privacyWarning
                exportAction
            }
            .padding(.horizontal, DataExportFigmaLayout.horizontalPadding)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.lg)
        }
        .background(Color.pepBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showsDatePicker) {
            DataExportDatePickerSheet(model: model)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(
            isPresented: $showsShareSheet,
            onDismiss: {
                model.shareSheetDidFinish()
            }
        ) {
            if let shareURL = model.shareURL {
                ActivityView(activityItems: [shareURL]) {
                    showsShareSheet = false
                }
                .ignoresSafeArea()
            }
        }
        .onDisappear {
            model.cancelExport()
            if !showsShareSheet {
                model.removeSharedFile()
            }
        }
        .task {
            model.removeStaleFiles()
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
                            .overlay(
                                Circle().stroke(Color.pepBorder, lineWidth: 1)
                            )

                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.pepTextPrimary)
                    }
                    .frame(
                        width: DataExportFigmaLayout.headerControlDiameter,
                        height: DataExportFigmaLayout.headerControlDiameter
                    )
                    .frame(
                        width: DataExportFigmaLayout.minimumTapTarget,
                        height: DataExportFigmaLayout.minimumTapTarget
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back to More")

                Spacer()

                PeppyLogo(size: 17)
                    .frame(
                        width: DataExportFigmaLayout.headerControlDiameter,
                        height: DataExportFigmaLayout.headerControlDiameter
                    )
                    .background(Color.pepSurface)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.pepBorder, lineWidth: 1))
                    .frame(
                        width: DataExportFigmaLayout.minimumTapTarget,
                        height: DataExportFigmaLayout.minimumTapTarget
                    )
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Peppy")
            }

            DataExportWordmark()
        }
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Data export")
                .font(
                    .system(
                        size: pageTitleSize,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .foregroundStyle(Color.pepTextPrimary)

            Text(
                "Export your data to review, keep for your records, "
                    + "or share with a healthcare provider."
            )
            .font(.system(size: pageDescriptionSize, design: .rounded))
            .foregroundStyle(Color.pepTextSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var exportCategories: some View {
        DataExportSection(
            title: "1. Choose what to include",
            subtitle: "Your account, profile, and preferences are always included."
        ) {
            DataExportCard {
                DataExportToggleRow(
                    systemImage: "list.clipboard.fill",
                    title: "Protocols",
                    subtitle: "Doses, medications, and protocol details",
                    tint: .pepPrimary,
                    background: .pepPrimaryMuted,
                    isOn: binding(\.includeProtocols)
                )

                DataExportDivider()

                DataExportToggleRow(
                    systemImage: "checkmark.circle.fill",
                    title: "Check-ins",
                    subtitle: "Daily check-ins, symptoms, and notes",
                    tint: .pepSuccess,
                    background: .pepSuccessMuted,
                    isOn: binding(\.includeCheckins)
                )

                DataExportDivider()

                DataExportToggleRow(
                    systemImage: "lightbulb.fill",
                    title: "Insights",
                    subtitle: "AI insights and recommendations",
                    tint: Color(hex: "8F5BB7"),
                    background: Color(hex: "F4ECFA"),
                    isOn: binding(\.includeInsights)
                )
            }
        }
        .disabled(model.isExporting)
    }

    private var exportFormat: some View {
        DataExportSection(title: "2. Choose format") {
            VStack(spacing: Spacing.sm) {
                DataExportFormatRow(
                    systemImage: "doc.richtext.fill",
                    title: "PDF summary",
                    subtitle: "Human-readable summary with key charts and tables",
                    badge: "Recommended",
                    tint: .pepPrimary,
                    background: .pepPrimaryMuted,
                    isSelected: model.selectedFormat == .pdf
                ) {
                    model.selectedFormat = .pdf
                }

                DataExportFormatRow(
                    systemImage: "doc.zipper",
                    title: "CSV data",
                    subtitle: "Detailed, raw data for analysis in spreadsheets",
                    badge: nil,
                    tint: .pepSuccess,
                    background: .pepSuccessMuted,
                    isSelected: model.selectedFormat == .csv
                ) {
                    model.selectedFormat = .csv
                }
            }
            .disabled(model.isExporting)
        }
    }

    private var dateRange: some View {
        DataExportSection(
            title: "3. Choose date range",
            subtitle: "The date range applies to time-based records."
        ) {
            Button {
                showsDatePicker = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "calendar")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.pepPrimary)
                        .frame(width: 30, height: 30)
                        .background(Color.pepPrimaryMuted)
                        .clipShape(Circle())
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Date range")
                            .font(
                                .system(
                                    size: rowTitleSize,
                                    weight: .semibold,
                                    design: .rounded
                                )
                            )
                            .foregroundStyle(Color.pepTextPrimary)

                        Text(model.dateRangeSummary)
                            .font(
                                .system(
                                    size: rowSubtitleSize,
                                    design: .rounded
                                )
                            )
                            .foregroundStyle(Color.pepTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: Spacing.sm)

                    Text("Change")
                        .font(
                            .system(
                                size: rowTitleSize,
                                weight: .semibold,
                                design: .rounded
                            )
                        )
                        .foregroundStyle(Color.pepPrimaryDark)
                        .padding(.horizontal, 12)
                        .frame(
                            minHeight: DataExportFigmaLayout.minimumTapTarget
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.pepPrimary, lineWidth: 1)
                        )
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(minHeight: 54)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(Color.pepSurface)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: DataExportFigmaLayout.cardCornerRadius
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: DataExportFigmaLayout.cardCornerRadius
                )
                .stroke(Color.pepBorder, lineWidth: 1)
            )
            .disabled(model.isExporting)
            .accessibilityLabel(
                "Date range, \(model.selectedDatePreset.title), "
                    + model.dateRangeSummary
            )
            .accessibilityHint("Opens date range choices")
        }
    }

    private var privacyWarning: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.pepWarning)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text("Sensitive information")
                    .font(
                        .system(
                            size: warningTitleSize,
                            weight: .semibold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(Color.pepTextPrimary)

                Text(
                    "Your export may contain private health information. "
                        + "Only share it with people you trust."
                )
                .font(
                    .system(size: rowSubtitleSize, design: .rounded)
                )
                .foregroundStyle(Color.pepTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.pepWarningMuted)
        .clipShape(
            RoundedRectangle(
                cornerRadius: DataExportFigmaLayout.cardCornerRadius
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: DataExportFigmaLayout.cardCornerRadius
            )
            .stroke(Color.pepWarning.opacity(0.3), lineWidth: 1)
        )
    }

    private var exportAction: some View {
        VStack(spacing: 8) {
            Button {
                Task {
                    await model.createExport()
                    if model.shareURL != nil {
                        showsShareSheet = true
                        announce("Your export is ready to share.")
                    } else if let errorMessage = model.errorMessage {
                        announce(errorMessage)
                    }
                }
            } label: {
                HStack(spacing: Spacing.sm) {
                    if model.isExporting {
                        ProgressView()
                            .tint(.white)
                    }

                    Text(
                        model.isExporting
                            ? "Creating export…"
                            : "Create export"
                    )
                }
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 52)
                .background(Color.pepPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .buttonStyle(.plain)
            .disabled(model.isExporting)
            .accessibilityHint("Creates a protected file and opens sharing options")

            if model.isExporting {
                Button("Cancel export") {
                    model.cancelExport()
                    announce("Export cancelled.")
                }
                .font(
                    .system(
                        .subheadline,
                        design: .rounded,
                        weight: .semibold
                    )
                )
                .foregroundStyle(Color.pepPrimaryDark)
                .frame(minHeight: DataExportFigmaLayout.minimumTapTarget)
            } else {
                Label(
                    "Your data is encrypted and secure.",
                    systemImage: "lock.fill"
                )
                .font(
                    .system(size: rowSubtitleSize, design: .rounded)
                )
                .foregroundStyle(Color.pepTextSecondary)
            }
        }
    }

    private func binding(
        _ keyPath: ReferenceWritableKeyPath<DataExportViewModel, Bool>
    ) -> Binding<Bool> {
        Binding(
            get: { model[keyPath: keyPath] },
            set: { model[keyPath: keyPath] = $0 }
        )
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
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
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
    }

    private func announce(_ message: String) {
        UIAccessibility.post(
            notification: .announcement,
            argument: message
        )
    }
}

private struct DataExportDatePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: DataExportViewModel

    private var today: Date {
        Calendar.current.startOfDay(for: Date())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.md) {
                    DataExportCard {
                        ForEach(
                            Array(DataExportDatePreset.allCases.enumerated()),
                            id: \.element.id
                        ) { index, preset in
                            Button {
                                model.selectedDatePreset = preset
                                if preset != .custom {
                                    dismiss()
                                }
                            } label: {
                                HStack {
                                    Text(preset.title)
                                        .font(
                                            .system(
                                                .body,
                                                design: .rounded,
                                                weight: .medium
                                            )
                                        )
                                        .foregroundStyle(Color.pepTextPrimary)

                                    Spacer()

                                    Image(
                                        systemName: model.selectedDatePreset == preset
                                            ? "checkmark.circle.fill"
                                            : "circle"
                                    )
                                    .foregroundStyle(
                                        model.selectedDatePreset == preset
                                            ? Color.pepPrimary
                                            : Color.pepTextTertiary
                                    )
                                }
                                .frame(
                                    minHeight: DataExportFigmaLayout.minimumTapTarget
                                )
                                .padding(.horizontal, 12)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if index < DataExportDatePreset.allCases.count - 1 {
                                DataExportDivider()
                            }
                        }
                    }

                    if model.selectedDatePreset == .custom {
                        VStack(spacing: 12) {
                            DatePicker(
                                "Start date",
                                selection: $model.customStartDate,
                                in: ...min(model.customEndDate, today),
                                displayedComponents: .date
                            )
                            DatePicker(
                                "End date",
                                selection: $model.customEndDate,
                                in: max(model.customStartDate, .distantPast)...today,
                                displayedComponents: .date
                            )
                        }
                        .font(.system(.body, design: .rounded))
                        .padding(12)
                        .background(Color.pepSurface)
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: DataExportFigmaLayout.cardCornerRadius
                            )
                        )
                        .overlay(
                            RoundedRectangle(
                                cornerRadius: DataExportFigmaLayout.cardCornerRadius
                            )
                            .stroke(Color.pepBorder, lineWidth: 1)
                        )
                    }
                }
                .padding(DataExportFigmaLayout.horizontalPadding)
            }
            .background(Color.pepBackground.ignoresSafeArea())
            .navigationTitle("Date range")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(model.selectedDatePreset != .custom)
                }
            }
        }
    }
}

private struct DataExportSection<Content: View>: View {
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
                .font(
                    .system(
                        size: titleSize,
                        weight: .semibold,
                        design: .rounded
                    )
                )
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

private struct DataExportCard<Content: View>: View {
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
                cornerRadius: DataExportFigmaLayout.cardCornerRadius
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: DataExportFigmaLayout.cardCornerRadius
            )
            .stroke(Color.pepBorder, lineWidth: 1)
        )
    }
}

private struct DataExportToggleRow: View {
    let systemImage: String
    let title: String
    let subtitle: String
    let tint: Color
    let background: Color
    @Binding var isOn: Bool

    @ScaledMetric(relativeTo: .body) private var titleSize: CGFloat = 13
    @ScaledMetric(relativeTo: .subheadline) private var subtitleSize: CGFloat = 11

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(background)
                .clipShape(Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(
                        .system(
                            size: titleSize,
                            weight: .semibold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(Color.pepTextPrimary)

                Text(subtitle)
                    .font(.system(size: subtitleSize, design: .rounded))
                    .foregroundStyle(Color.pepTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: Spacing.sm)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Color.pepSuccess)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(minHeight: 52)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(subtitle)")
        .accessibilityValue(isOn ? "Included" : "Not included")
    }
}

private struct DataExportFormatRow: View {
    let systemImage: String
    let title: String
    let subtitle: String
    let badge: String?
    let tint: Color
    let background: Color
    let isSelected: Bool
    let action: () -> Void

    @ScaledMetric(relativeTo: .body) private var titleSize: CGFloat = 13
    @ScaledMetric(relativeTo: .subheadline) private var subtitleSize: CGFloat = 11
    @ScaledMetric(relativeTo: .caption2) private var badgeSize: CGFloat = 9

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(
                    systemName: isSelected
                        ? "largecircle.fill.circle"
                        : "circle"
                )
                .font(.system(size: 20))
                .foregroundStyle(
                    isSelected ? Color.pepPrimary : Color.pepTextTertiary
                )
                .accessibilityHidden(true)

                Image(systemName: systemImage)
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(tint)
                    .frame(width: 38, height: 38)
                    .background(background)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(
                                .system(
                                    size: titleSize,
                                    weight: .semibold,
                                    design: .rounded
                                )
                            )
                            .foregroundStyle(Color.pepTextPrimary)

                        if let badge {
                            Text(badge)
                                .font(
                                    .system(
                                        size: badgeSize,
                                        weight: .semibold,
                                        design: .rounded
                                    )
                                )
                                .foregroundStyle(Color.pepPrimaryDark)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.pepPrimaryMuted)
                                .clipShape(Capsule())
                        }
                    }

                    Text(subtitle)
                        .font(.system(size: subtitleSize, design: .rounded))
                        .foregroundStyle(Color.pepTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: Spacing.sm)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minHeight: 56)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color.pepSurface)
        .clipShape(
            RoundedRectangle(
                cornerRadius: DataExportFigmaLayout.cardCornerRadius
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: DataExportFigmaLayout.cardCornerRadius
            )
            .stroke(
                isSelected ? Color.pepPrimary : Color.pepBorder,
                lineWidth: isSelected ? 1.5 : 1
            )
        )
        .accessibilityLabel("\(title), \(subtitle)")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct DataExportDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.pepBorderLight)
            .frame(height: 1)
            .padding(.leading, 54)
    }
}

private struct DataExportWordmark: View {
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

#Preview {
    DataExportView(
        api: MockAPIClient(),
        fileService: ExportFileService()
    )
}
