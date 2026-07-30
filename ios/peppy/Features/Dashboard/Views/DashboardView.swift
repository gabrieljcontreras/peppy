import SwiftUI

struct DashboardView: View {
    @Environment(\.dependencies) private var deps
    @State private var model: DashboardViewModel?
    @State private var showsPaywall = false

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
                            dateRow(for: summary.protocol)

                            if let nextDose = model?.nextDose {
                                DashboardNextDoseCard(
                                    compound: nextDose.compound,
                                    dueDate: nextDose.dueDate
                                ) {
                                    deps.protocolNavigation.show(
                                        .logDose(
                                            protocolID: summary.protocol.id ?? nextDose.compound.id,
                                            compoundID: nextDose.compound.id
                                        )
                                    )
                                }
                            } else {
                                DashboardProtocolCard(summary: summary.protocol) {
                                    deps.protocolNavigation.show(summary.protocol.protocolRoute)
                                }
                            }

                            DashboardTodayCard(
                                today: summary.todayCheckin,
                                preview: model?.todayPreview
                            ) {
                                guard let model else { return }
                                deps.protocolNavigation.showCheckin(model.checkinRoute)
                            }

                            DashboardWeightTrendCard(
                                snapshot: summary.responseSnapshot,
                                preferredUnit: deps.weightUnitPreferences.unit
                            )

                            if let wearableTiles = model?.wearableTiles {
                                DashboardWearableTilesRow(tiles: wearableTiles)
                            }

                            // Not nested inside `if let summary.insight`: the
                            // backend nulls that field for free accounts, and
                            // the locked card still has to render.
                            if PremiumGate.showsLock(for: deps.entitlements.entitlement) {
                                lockedInsightCard
                            } else if let insight = summary.insight {
                                DashboardInsightCard(insight: insight) {
                                    if let id = insight.id {
                                        deps.protocolNavigation.showInsight(.detail(id))
                                    } else {
                                        deps.protocolNavigation.showInsightsTab()
                                    }
                                }
                            }

                            if let activity = summary.recentActivity, !activity.isEmpty {
                                DashboardActivityFeed(
                                    items: activity,
                                    openProtocol: { id in
                                        deps.protocolNavigation.show(.detail(id))
                                    },
                                    openCheckin: { id in
                                        deps.protocolNavigation.showCheckin(.detail(id))
                                    }
                                )
                            }
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
                        hasProfileAttachFailure: deps.flow.hasProfileAttachFailure,
                        currentDisplayName: { deps.appState.currentUser?.displayName }
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
            .sheet(isPresented: $showsPaywall) {
                PaywallView(onDismiss: { showsPaywall = false })
            }
        }
    }

    private var lockedInsightCard: some View {
        Button {
            showsPaywall = true
        } label: {
            PepCard {
                HStack(alignment: .top, spacing: Spacing.md) {
                    ZStack {
                        Circle().fill(Color.pepPrimaryMuted)
                        Image(systemName: "lock.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.pepPrimary)
                    }
                    .frame(width: 40, height: 40)
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("LATEST INSIGHT")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.pepPrimary)
                            .tracking(0.5)

                        Text("Unlock Peppy Premium to see your insights.")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.pepTextPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: Spacing.sm)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.pepTextTertiary)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Insight locked. Unlock Peppy Premium to see your insights.")
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                PeppyLogo(size: 28, showsWordmark: true)
                Text(model?.greetingText ?? "Good day")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.pepTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Here's what's happening with your protocol today.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.pepTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: Spacing.sm)

            Button {
                deps.protocolNavigation.selectedTab = .profile
            } label: {
                ZStack {
                    Circle().fill(Color.pepPrimaryMuted)
                    PeppyLogo(size: 20, showsWordmark: false)
                }
                .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open profile")
        }
        .padding(.top, Spacing.sm)
    }

    private func dateRow(for protocolSummary: DashboardProtocolSummary) -> some View {
        HStack {
            Label(Self.dateFormatter.string(from: Date()), systemImage: "calendar")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.pepTextSecondary)

            Spacer()

            if protocolSummary.status != "missing" && protocolSummary.status != "pending_setup" {
                PepBadge(
                    text: "\(protocolSummary.badgeText) \u{2022} \(weekText(for: protocolSummary))",
                    type: protocolSummary.badgeType
                )
            }
        }
    }

    private func weekText(for protocolSummary: DashboardProtocolSummary) -> String {
        guard let startDate = protocolSummary.startDate else { return "Week 1" }
        let elapsed = Date().timeIntervalSince(startDate)
        let week = max(1, Int(elapsed / (7 * 86_400)) + 1)
        return "Week \(week)"
    }

    private var syncRecoveryCard: some View {
        PepCard {
            Label("Finish syncing setup", systemImage: "arrow.triangle.2.circlepath")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.pepPrimary)
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

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()
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
    let dependencies = Dependencies.mock()
    dependencies.appState.login(
        user: User(id: UUID(), email: "taylor@example.com", displayName: "Taylor Reed", isVerified: true)
    )
    return DashboardView()
        .withDependencies(dependencies)
}
