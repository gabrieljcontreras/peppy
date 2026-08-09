import SwiftUI

struct ProtocolListView: View {
    let model: ProtocolListViewModel
    let navigate: (ProtocolRoute) -> Void
    @State private var selectedFilter: ProtocolListFilter = .active

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                switch model.state {
                case .idle, .loading:
                    PepLoadingView(message: "Loading protocols")
                        .frame(minHeight: 280)
                case .failed(let message):
                    retryState(message)
                case .empty:
                    emptyState
                case .loaded:
                    loadedContent
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
        .background(Color.pepBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .refreshable {
            await model.refresh()
        }
        .task {
            await model.loadIfNeeded()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center) {
                PeppyLogo(size: 34, showsWordmark: true)

                Spacer()
            }

            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Protocols")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.pepTextPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text("Your personalized plans, all in one place.")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.pepTextSecondary)
                }

                Spacer(minLength: 10)

                Button {
                    navigate(model.createRoute)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))
                            .frame(width: 24, height: 24)
                            .background(Color.white.opacity(0.9))
                            .clipShape(Circle())
                        Text("New protocol")
                            .font(.system(size: 15, weight: .bold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(Color.white)
                    .padding(.leading, 12)
                    .padding(.trailing, 18)
                    .frame(height: 50)
                    .background(Color.pepPrimary)
                    .clipShape(Capsule())
                }
                .accessibilityLabel("New protocol")
            }
        }
    }

    private var loadedContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            ProtocolListSegmentedControl(
                activeCount: model.activeCountText,
                historyCount: model.historyCountText,
                selectedFilter: $selectedFilter
            )

            if let refreshErrorMessage = model.refreshErrorMessage {
                inlineError(refreshErrorMessage)
            }

            switch selectedFilter {
            case .active:
                protocolSection(title: "Active", count: model.activeCountText, rows: model.activeRows)
                protocolSection(title: "History", count: model.historyCountText, rows: model.historyRows)
            case .past:
                protocolSection(title: "Past", count: model.historyCountText, rows: model.historyRows)
            }

            privacyCallout
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            ProtocolListSegmentedControl(
                activeCount: model.activeCountText,
                historyCount: model.historyCountText,
                selectedFilter: $selectedFilter
            )

            PepEmptyState(
                icon: "cross.case",
                title: "No protocols yet",
                message: "Create your first protocol to keep your plan and schedule in one place.",
                actionTitle: "New protocol"
            ) {
                navigate(model.createRoute)
            }
            .frame(maxWidth: .infinity)
            .background(Color.pepSurface)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.pepBorderLight, lineWidth: 1)
            )
        }
    }

    private func retryState(_ message: String) -> some View {
        PepCard {
            VStack(alignment: .leading, spacing: 14) {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.pepWarning)
                    .fixedSize(horizontal: false, vertical: true)

                PepButton(title: "Retry", style: .secondary) {
                    Task { await model.retry() }
                }
            }
        }
    }

    private func protocolSection(
        title: String,
        count: String,
        rows: [ProtocolListRowModel]
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.pepTextPrimary)

                Text(count)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.pepTextSecondary)
                    .frame(width: 30, height: 30)
                    .background(Color.pepSurfaceElevated)
                    .clipShape(Circle())
            }

            if rows.isEmpty {
                Text(title == "Active" ? "No active protocols." : "No previous protocols.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.pepTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(Color.pepSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.pepBorderLight, lineWidth: 1)
                    )
            } else {
                VStack(spacing: 12) {
                    ForEach(rows) { row in
                        ProtocolRow(row: row) {
                            navigate(row.route)
                        }
                    }
                }
            }
        }
    }

    private func inlineError(_ message: String) -> some View {
        Label(message, systemImage: "wifi.exclamationmark")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.pepWarning)
            .fixedSize(horizontal: false, vertical: true)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.pepWarningMuted)
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var privacyCallout: some View {
        HStack(spacing: 14) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.pepPrimary)
                .frame(width: 44, height: 44)
                .background(Color.pepPrimaryMuted)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text("Your protocols are private and secure.")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.pepTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Only you can see your data.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.pepTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.pepTextTertiary)
        }
        .padding(18)
        .background(Color.pepPrimaryMuted.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.pepPrimaryMuted, lineWidth: 1)
        )
    }
}

private enum ProtocolListFilter {
    case active
    case past
}

private struct ProtocolListSegmentedControl: View {
    let activeCount: String
    let historyCount: String
    @Binding var selectedFilter: ProtocolListFilter

    var body: some View {
        HStack(spacing: 0) {
            segment(title: "Active", count: activeCount, filter: .active)
            segment(title: "Past", count: historyCount, filter: .past)
        }
        .padding(3)
        .frame(height: 54)
        .background(Color.pepSurfaceElevated)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.pepBorder, lineWidth: 1))
    }

    private func segment(title: String, count: String, filter: ProtocolListFilter) -> some View {
        Button {
            selectedFilter = filter
        } label: {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(selectedFilter == filter ? Color.pepPrimary : Color.pepTextSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(selectedFilter == filter ? Color.pepSurface : Color.clear)
                .clipShape(Capsule())
        }
        .accessibilityLabel("\(title), \(count)")
    }
}

#Preview {
    let dependencies = Dependencies.mock()
    ProtocolListView(model: ProtocolListViewModel(store: dependencies.protocolStore)) { _ in }
        .withDependencies(dependencies)
}
