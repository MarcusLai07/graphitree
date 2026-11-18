import SwiftUI

/// A tool's plan limits from a `LimitReading`: Gemini CLI's, Copilot's or OpenCode's. Like
/// `AllowancesCard`, without the left-over-time chart, which needs a history these tools don't keep.
struct ToolAllowancesCard: View {
    @ObservedObject var model: ToolLimitsModel
    let showLeft: Bool

    var body: some View {
        if let reading = model.current {
            card(reading)
        } else if let problem = model.problem {
            EmptyStateView(icon: "gauge.with.dots.needle.0percent", title: title(problem), message: problem.message)
                .designCard()
        } else {
            ProgressView("Reading \(model.provider.name)'s limits…")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
                .designCard()
        }
    }

    private func card(_ reading: LimitReading) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                ModelLogo(id: model.provider.brandID, size: 18)
                Text(model.provider.name).font(.system(size: 14, weight: .semibold))
                if let plan = reading.plan {
                    Text(plan).font(.system(size: 12.5)).foregroundStyle(.secondary)
                }
                Spacer()
                AgeBadge(since: reading.fetchedAt, stale: model.isStale)
            }
            let displays = MetricPresentation.displays(for: reading.windows, showLeft: showLeft)
            if displays.isEmpty {
                Text("\(model.provider.name) reported no limits for this plan.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
            }
            ForEach(displays) { MetricBarRow(metric: $0) }
            if model.isStale, let problem = model.problem {
                Label("Couldn't refresh: \(problem.message)", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .designCard()
    }

    private func title(_ problem: LimitProblem) -> String {
        switch problem {
        case .notSignedIn: return "Not signed in"
        case .expired: return "Sign-in ran out"
        case .noLimits: return "No plan limits to show"
        case .offline: return "Offline"
        case .http, .unreadable: return "Couldn't read \(model.provider.name)'s limits"
        }
    }
}
