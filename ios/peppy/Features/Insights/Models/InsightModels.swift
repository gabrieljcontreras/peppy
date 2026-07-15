import SwiftUI

enum InsightRoute: Hashable {
    case detail(UUID)
    case weeklySummary
}

enum InsightTypeFilter: String, CaseIterable, Identifiable {
    case all, trends, anomalies, suggestions, milestones

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .trends: return "Trends"
        case .anomalies: return "Anomalies"
        case .suggestions: return "Suggestions"
        case .milestones: return "Milestones"
        }
    }

    /// Server-side `Insight.type` value this filter matches; nil shows everything.
    var matchesType: String? {
        switch self {
        case .all: return nil
        case .trends: return "trend"
        case .anomalies: return "anomaly"
        case .suggestions: return "suggestion"
        case .milestones: return "milestone"
        }
    }
}

// MARK: - Presentation mapping (shared by the list and detail screens)

extension Insight {
    var typeBadgeStyle: PepBadgeType {
        switch type {
        case "trend": return .success
        case "anomaly": return .warning
        case "suggestion": return .info
        default: return .neutral
        }
    }

    var typeIcon: String {
        switch type {
        case "trend": return "chart.line.uptrend.xyaxis"
        case "anomaly": return "exclamationmark.triangle"
        case "suggestion": return "lightbulb"
        case "milestone": return "flag.checkered"
        default: return "circle"
        }
    }

    var typeDisplayName: String {
        switch type {
        case "trend": return "Trend"
        case "anomaly": return "Anomaly"
        case "suggestion": return "Suggestion"
        case "milestone": return "Milestone"
        default: return type.capitalized
        }
    }

    var confidenceLabel: String {
        if confidence >= 0.75 { return "High" }
        if confidence >= 0.5 { return "Medium" }
        return "Low"
    }

    var confidenceColor: Color {
        if confidence >= 0.75 { return .pepSuccess }
        if confidence >= 0.5 { return .pepWarning }
        return .pepTextSecondary
    }

    var severityIcon: String {
        switch severity {
        case "warning": return "exclamationmark.triangle"
        case "alert": return "bell.badge"
        default: return "info.circle"
        }
    }
}
