import SwiftUI

struct DashboardView: View {
    @Environment(\.dependencies) private var deps
    @State private var model: DashboardViewModel?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    if let state = model?.state {
                        if state.showsProfileSyncRecovery {
                            syncRecoveryCard
                        }

                        if let summary = state.summary {
                            DashboardProtocolCard(summary: summary.protocol) {
                                deps.protocolNavigation.show(summary.protocol.protocolRoute)
                            }
                            DashboardTodayCard(
                                today: summary.todayCheckin,
                                preview: model?.todayPreview
                            ) {
                                guard let model else { return }
                                deps.protocolNavigation.showCheckin(model.checkinRoute)
                            }
                            responseSnapshot(summary.responseSnapshot)
                            insightCard(summary.insight)
                            connectedContextCard(summary.connectedContext)
                        } else if state.isLoading {
                            PepLoadingView(message: "Loading your dashboard")
                                .frame(minHeight: 220)
                        } else if let message = state.errorMessage {
                            errorCard(message)
                        }
                    } else {
                        PepLoadingView(message: "Loading your dashboard")
                            .frame(minHeight: 220)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            }
            .background(Color.pepBackground.ignoresSafeArea())
            .navigationBarHidden(true)
            .task {
                if model == nil {
                    model = DashboardViewModel(
                        api: deps.api,
                        protocolStore: deps.protocolStore,
                        checkinStore: deps.checkinStore,
                        weightUnitPreferences: deps.weightUnitPreferences,
                        hasProfileAttachFailure: deps.flow.hasProfileAttachFailure
                    )
                }
                await model?.load()
            }
            .onChange(of: deps.protocolStore.revision) {
                Task { await model?.refreshIfProtocolStateChanged() }
            }
            .onChange(of: deps.checkinStore.revision) {
                Task { await model?.refreshIfCheckinStateChanged() }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            PeppyLogo(size: 28, showsWordmark: true)

            Text("Your protocol, understood.")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.pepTextPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Track what you take, how you feel, and what is changing.")
                .font(.system(size: 14))
                .foregroundStyle(Color.pepTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, Spacing.sm)
    }

    private var syncRecoveryCard: some View {
        PepCard {
            Label("Finish syncing setup", systemImage: "arrow.triangle.2.circlepath")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.pepPrimary)
        }
    }

    private func responseSnapshot(_ snapshot: DashboardResponseSnapshot) -> some View {
        PepCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Response snapshot")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.pepTextPrimary)

                Text(snapshot.weightTrend.isEmpty ? "Log a few check-ins to see your trend." : "\(snapshot.weightTrend.count) weight points logged")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.pepTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func insightCard(_ insight: DashboardInsightSummary) -> some View {
        Button {
            if let id = insight.id {
                deps.protocolNavigation.showInsight(.detail(id))
            } else {
                deps.protocolNavigation.showInsightsTab()
            }
        } label: {
            PepCard {
                HStack(spacing: Spacing.sm) {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Insight")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.pepTextPrimary)

                        Text(insight.title ?? insight.emptyMessage ?? "No new insights right now.")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.pepTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.pepTextTertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func connectedContextCard(_ context: DashboardConnectedContext) -> some View {
        PepCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Connected context")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.pepTextPrimary)

                Text(context.healthkitRequested == true ? "Apple Health is connected." : "Connect Apple Health or add labs for more context.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.pepTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func errorCard(_ message: String) -> some View {
        PepCard {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.pepWarning)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

extension DashboardProtocolSummary {
    /// Route for the Dashboard protocol card: pending starters resume setup,
    /// configured protocols open detail, and summaries without a server ID
    /// (no protocol yet) go to protocol creation.
    var protocolRoute: ProtocolRoute {
        guard let id else { return .create }
        return status == "pending_setup"
            ? .starterSetup(protocolID: id, compounds: compounds)
            : .detail(id)
    }
}

#Preview {
    DashboardView()
        .withDependencies(.mock())
}
