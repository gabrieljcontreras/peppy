import SwiftUI

struct ProtocolRow: View {
    let row: ProtocolListRowModel
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if row.isCurrent {
                currentRow
            } else {
                historyRow
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(row.title), \(row.statusText), \(row.compoundSummary), \(row.doseSummary)")
    }

    private var currentRow: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                protocolIcon

                VStack(alignment: .leading, spacing: 8) {
                    statusBadge

                    Text(row.title)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.pepTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(row.timelineText)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.pepPrimary)

                    Label(row.dateRangeText, systemImage: "calendar")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.pepTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.pepTextTertiary)
                    .padding(.top, 32)
            }

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("COMPOUND")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.pepTextSecondary)

                    HStack(spacing: 8) {
                        Text(row.compoundSummary)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.pepTextPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        Text(row.doseSummary)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.pepPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.pepPrimaryMuted)
                            .clipShape(Capsule())
                    }

                    Label(row.scheduleSummary, systemImage: "calendar")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.pepTextSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Rectangle()
                    .fill(Color.pepBorderLight)
                    .frame(width: 1, height: 76)
                    .padding(.horizontal, 18)

                VStack(alignment: .leading, spacing: 8) {
                    Text("SCHEDULE")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.pepTextSecondary)

                    Label(row.scheduleDisplayText, systemImage: "calendar")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.pepTextPrimary)

                    Text(row.doseSummary)
                        .font(.system(size: 16))
                        .foregroundStyle(Color.pepTextSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .background(Color.pepSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.pepBorderLight, lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .bottom) {
                    Text(row.startMarkerText)
                    Spacer()
                    Text(row.statusMarkerText)
                    Spacer()
                    Text(row.endMarkerText)
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.pepTextSecondary)

                HStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { index in
                        let isComplete = index <= row.completedTimelineSteps
                        let isCurrent = index == row.completedTimelineSteps
                        Circle()
                            .fill(isComplete ? Color.pepPrimary : Color.pepBorderLight)
                            .frame(width: isCurrent ? 18 : 12, height: isCurrent ? 18 : 12)
                            .overlay(
                                Circle()
                                    .stroke(isCurrent ? Color.pepPrimary : Color.clear, lineWidth: 3)
                            )
                        if index < 2 {
                            Rectangle()
                                .fill(index < row.completedTimelineSteps ? Color.pepPrimary : Color.pepBorderLight)
                                .frame(height: 2)
                        }
                    }
                }
            }

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(row.status == .pendingSetup ? "Setup needed" : "You're on track")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.pepPrimary)

                    Text(row.status == .pendingSetup ? "Add dose and schedule details." : "Scheduled dose: \(row.doseSummary).")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.pepTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                HStack(spacing: 6) {
                    Text("View details")
                        .font(.system(size: 14, weight: .bold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(Color.pepTextPrimary)
                .padding(.horizontal, 16)
                .frame(height: 40)
                .background(Color.pepSurface)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.pepBorder, lineWidth: 1))
            }
        }
        .padding(18)
        .background(Color.pepSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.pepBorderLight, lineWidth: 1)
        )
        .pepCardShadow()
    }

    private var historyRow: some View {
        HStack(spacing: 14) {
            protocolIcon

            VStack(alignment: .leading, spacing: 5) {
                Text(row.title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.pepTextPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                HStack(spacing: 8) {
                    Text(row.dateRangeText)
                    if let durationText = row.durationText {
                        Text(durationText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.pepSurfaceElevated)
                            .clipShape(Capsule())
                    }
                }
                .font(.system(size: 13))
                .foregroundStyle(Color.pepTextSecondary)

                HStack(spacing: 8) {
                    Text(row.compoundSummary)
                    Text(row.doseSummary)
                        .fontWeight(.bold)
                        .foregroundStyle(accentColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(accentColor.opacity(0.12))
                        .clipShape(Capsule())
                }
                .font(.system(size: 13))
                .foregroundStyle(Color.pepTextSecondary)
            }

            Spacer(minLength: 8)

            PepBadge(text: row.statusText, type: .neutral)

            Image(systemName: "chevron.right")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.pepTextTertiary)
        }
        .padding(18)
        .background(Color.pepSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.pepBorderLight, lineWidth: 1)
        )
        .pepCardShadow()
    }

    private var protocolIcon: some View {
        Image(systemName: "pill.fill")
            .font(.system(size: 28, weight: .semibold))
            .foregroundStyle(accentColor)
            .frame(width: 68, height: 68)
            .background(accentColor.opacity(0.12))
            .clipShape(Circle())
    }

    private var statusBadge: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(row.status == .active ? Color.pepSuccess : Color.pepWarning)
                .frame(width: 10, height: 10)
            Text(row.statusText)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(row.status == .active ? Color.pepSuccess : Color.pepWarning)
        }
    }

    private var accentColor: Color {
        row.status == .inactive ? Color.pepWarning : Color.pepPrimary
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 14) {
            ProtocolRow(
                row: ProtocolListRowModel(
                    id: UUID(),
                    route: .detail(UUID()),
                    title: "Retatrutide Titration",
                    status: .active,
                    statusText: "Active",
                    timelineText: "Active plan",
                    dateRangeText: "Started Apr 19, 2025",
                    compoundSummary: "Retatrutide",
                    doseSummary: "4 mg",
                    scheduleSummary: "Once weekly",
                    scheduleDisplayText: "Once Weekly",
                    durationText: "12 weeks",
                    startMarkerText: "Apr 19",
                    statusMarkerText: "Active",
                    endMarkerText: "Ongoing",
                    completedTimelineSteps: 1
                )
            ) {}
        }
        .padding()
    }
    .background(Color.pepBackground)
}
