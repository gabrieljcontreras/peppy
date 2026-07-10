import SwiftUI

// MARK: - Status pill

struct ProtocolStatusPill: View {
    let status: ProtocolStatus
    let text: String

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(foregroundColor)
                .frame(width: 8, height: 8)

            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(foregroundColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(backgroundColor)
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
    }

    private var foregroundColor: Color {
        switch status {
        case .active: return .pepSuccess
        case .pendingSetup: return .pepWarning
        case .inactive: return .pepTextSecondary
        }
    }

    private var backgroundColor: Color {
        switch status {
        case .active: return .pepSuccessMuted
        case .pendingSetup: return .pepWarningMuted
        case .inactive: return .pepSurfaceElevated
        }
    }
}

// MARK: - Section card

struct ProtocolSectionCard<Content: View, Accessory: View>: View {
    let title: String
    @ViewBuilder var accessory: () -> Accessory
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.pepTextPrimary)

                Spacer(minLength: 8)

                accessory()
            }

            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.pepSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.pepBorderLight, lineWidth: 1)
        )
    }
}

extension ProtocolSectionCard where Accessory == EmptyView {
    init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.init(title: title, accessory: { EmptyView() }, content: content)
    }
}

// MARK: - Labeled info row

struct ProtocolInfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.pepTextSecondary)
                    .frame(width: 20)

                Text(label)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.pepTextSecondary)
            }
            .frame(width: 158, alignment: .leading)

            Text(value)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.pepTextPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Phase timeline

struct ProtocolTimelinePhase: Equatable {
    let title: String
    let subtitle: String
}

struct ProtocolPhaseTimeline: View {
    let phases: [ProtocolTimelinePhase]
    let currentIndex: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 8) {
                ForEach(phases.indices, id: \.self) { index in
                    VStack(alignment: columnAlignment(index), spacing: 3) {
                        Text(phases[index].title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(index == currentIndex ? Color.pepPrimary : Color.pepTextPrimary)

                        Text(phases[index].subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.pepTextSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: frameAlignment(index))
                    .multilineTextAlignment(index == 0 ? .leading : index == phases.count - 1 ? .trailing : .center)
                }
            }

            track

            HStack(spacing: 0) {
                ForEach(phases.indices, id: \.self) { index in
                    Group {
                        if index == currentIndex {
                            Text("You are here")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.pepPrimary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.pepPrimaryMuted)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            Color.clear.frame(height: 1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: frameAlignment(index))
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var track: some View {
        HStack(spacing: 0) {
            ForEach(phases.indices, id: \.self) { index in
                dot(at: index)
                if index < phases.count - 1 {
                    Rectangle()
                        .fill(index < currentIndex ? Color.pepPrimary : Color.pepBorder)
                        .frame(height: 2)
                }
            }
        }
    }

    private func dot(at index: Int) -> some View {
        ZStack {
            Circle()
                .fill(index <= currentIndex ? Color.pepPrimary : Color.pepSurface)
                .frame(width: 22, height: 22)
                .overlay(
                    Circle()
                        .stroke(index <= currentIndex ? Color.pepPrimary : Color.pepBorder, lineWidth: 2)
                )

            if index <= currentIndex {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.white)
            }
        }
    }

    private func columnAlignment(_ index: Int) -> HorizontalAlignment {
        index == 0 ? .leading : index == phases.count - 1 ? .trailing : .center
    }

    private func frameAlignment(_ index: Int) -> Alignment {
        index == 0 ? .leading : index == phases.count - 1 ? .trailing : .center
    }

    private var accessibilitySummary: String {
        guard phases.indices.contains(currentIndex) else { return "Protocol timeline" }
        return "Protocol timeline, currently \(phases[currentIndex].title), \(phases[currentIndex].subtitle)"
    }
}

// MARK: - Dose history row

struct ProtocolDoseHistoryRow: View {
    let row: DoseLogRowModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.pepSuccess)

            Text(row.dateText)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.pepTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 8)

            Text(row.doseText)
                .font(.system(size: 15))
                .foregroundStyle(Color.pepTextPrimary)

            Text(row.statusText)
                .font(.system(size: 15))
                .foregroundStyle(Color.pepTextSecondary)
                .frame(width: 62, alignment: .trailing)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(row.dateText), \(row.doseText), \(row.statusText)")
    }
}

// MARK: - Form building blocks

struct ProtocolFieldLabel: View {
    let text: String
    var isRequired = false
    var annotation: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(text)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.pepTextPrimary)

            if isRequired {
                Text("*")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.pepPrimary)
            }

            if let annotation {
                Text(annotation)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.pepTextSecondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isRequired ? "\(text), required" : text)
    }
}

struct ProtocolFieldHelper: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(Color.pepTextSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct ProtocolFieldError: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color.pepError)
            .fixedSize(horizontal: false, vertical: true)
    }
}

extension View {
    /// The bordered rounded chrome shared by every protocol form control.
    func protocolFieldChrome() -> some View {
        self
            .background(Color.pepSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.pepBorder, lineWidth: 1)
            )
    }
}

struct ProtocolPrimaryButton: View {
    let title: String
    var isDisabled = false
    var isLoading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .opacity(isLoading ? 0 : 1)

                if isLoading {
                    ProgressView()
                        .tint(.white)
                }
            }
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(isDisabled ? Color.pepPrimary.opacity(0.45) : Color.pepPrimary)
            .clipShape(Capsule())
        }
        .disabled(isDisabled || isLoading)
        .accessibilityLabel(isLoading ? "\(title), in progress" : title)
    }
}

#Preview {
    ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            ProtocolStatusPill(status: .active, text: "Active")

            ProtocolSectionCard(title: "Protocol timeline") {
                ProtocolPhaseTimeline(
                    phases: [
                        ProtocolTimelinePhase(title: "Started", subtitle: "Apr 19"),
                        ProtocolTimelinePhase(title: "Active", subtitle: "In progress"),
                        ProtocolTimelinePhase(title: "Ends", subtitle: "Jul 12"),
                    ],
                    currentIndex: 1
                )
            }

            ProtocolSectionCard(title: "Compound") {
                VStack(alignment: .leading, spacing: 12) {
                    ProtocolInfoRow(icon: "calendar", label: "Dose & frequency", value: "4 mg once weekly")
                    ProtocolInfoRow(icon: "syringe", label: "Route", value: "Subcutaneous injection")
                }
            }
        }
        .padding(20)
    }
    .background(Color.pepBackground)
}
