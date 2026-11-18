import Charts
import SwiftUI

/// Tab 2: AI coach, race predictor and charts.
struct InsightsView: View {
    @Environment(RunStore.self) private var store

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if store.runs.isEmpty {
                        ContentUnavailableView("No insights yet",
                                               systemImage: "chart.bar.xaxis",
                                               description: Text("Log a few runs, or load the sample runs in the Runs tab."))
                    } else {
                        CoachCard()
                        RacePredictionCard()
                        BalanceCard()
                        WeeklyDistanceCard()
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Insights")
        }
    }
}

struct CoachCard: View {
    @Environment(RunStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardHeader(title: "AI coach",
                       symbol: "sparkles",
                       subtitle: store.coach.isAppleIntelligenceAvailable
                           ? "Apple Intelligence · on-device" : "Smart rules · on-device")
            if store.isCoachThinking {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Thinking about your week…").foregroundStyle(.secondary)
                }
            } else if let advice = store.coachAdvice {
                Text(advice.headline)
                    .font(.title3.bold())
                ForEach(Array(advice.tips.enumerated()), id: \.offset) { index, tip in
                    Label(tip, systemImage: "\(index + 1).circle.fill")
                }
                Text(advice.source == .appleIntelligence
                     ? "Written by Apple Intelligence on this iPhone. Not medical advice."
                     : "Written by Stride's coaching rules. Not medical advice.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Get a short plan for this week, based on your runs, moods and pain notes.")
                    .foregroundStyle(.secondary)
            }
            Button {
                Task { await store.refreshCoach() }
            } label: {
                Label(store.coachAdvice == nil ? "Ask the coach" : "Ask again", systemImage: "wand.and.stars")
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.isCoachThinking)
            .accessibilityIdentifier("askCoachButton")
        }
        .card()
    }
}

struct RacePredictionCard: View {
    @Environment(RunStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardHeader(title: "Race predictor", symbol: "flag.checkered", subtitle: "Learns from your hard runs")
            if let result = store.racePrediction {
                ForEach(result.predictions) { prediction in
                    let isGoal = prediction.distance == store.profile.goal
                    HStack(spacing: 8) {
                        Text(prediction.distance.rawValue)
                            .font(isGoal ? .headline : .body)
                        if isGoal {
                            Text("GOAL")
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .foregroundStyle(Color.accentColor)
                                .background(Color.accentColor.opacity(0.15), in: Capsule())
                        }
                        Spacer()
                        Text(Format.duration(seconds: prediction.seconds))
                            .font(.title3.bold().monospacedDigit())
                        Text("\(Format.pace(secondsPerKm: prediction.pacePerKm))/km")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 62, alignment: .trailing)
                    }
                    .accessibilityElement(children: .combine)
                }
                Text(result.isPersonalised
                     ? "Learned from \(result.runsUsed) hard runs. Your endurance factor is \(String(format: "%.2f", result.exponent)) (typical runner: 1.06)."
                     : "Based on your best recent effort and the typical endurance factor (1.06). Log hard runs of different lengths to personalise it.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("Log a tempo or long run to unlock race predictions.")
                    .foregroundStyle(.secondary)
            }
        }
        .card()
    }
}

struct BalanceCard: View {
    @Environment(RunStore.self) private var store

    var body: some View {
        let mix = store.typeMix
        let balance = store.balance
        VStack(alignment: .leading, spacing: 12) {
            CardHeader(title: "Easy vs hard", symbol: "circle.lefthalf.filled",
                       subtitle: "Run types found by the Core ML model · last 14 days")
            if mix.isEmpty {
                Text("No runs in the last 14 days.").foregroundStyle(.secondary)
            } else {
                HStack(spacing: 20) {
                    Chart(mix) { item in
                        SectorMark(angle: .value("Runs", item.count), innerRadius: .ratio(0.62), angularInset: 2)
                            .foregroundStyle(item.type.color)
                            .cornerRadius(4)
                    }
                    .frame(width: 130, height: 130)
                    .overlay {
                        VStack(spacing: 0) {
                            Text(Format.percent(balance.easyShare)).font(.title2.bold())
                            Text("easy").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(mix) { item in
                            Label("\(item.type.rawValue): \(item.count)", systemImage: item.type.symbol)
                                .font(.subheadline)
                                .foregroundStyle(item.type.color)
                        }
                    }
                }
            }
            Text(balance.isBalanced
                 ? "Nice! Most of your runs are easy. That's how good runners train (80/20)."
                 : "Only \(Format.percent(balance.easyShare)) of your runs were easy. Coaches suggest about 80% easy runs.")
                .font(.footnote)
                .foregroundStyle(balance.isBalanced ? Color.green : Color.orange)
        }
        .card()
    }
}

struct WeeklyDistanceCard: View {
    @Environment(RunStore.self) private var store

    var body: some View {
        let weeks = store.weeklyDistance
        let average = weeks.map(\.kilometres).reduce(0, +) / Double(max(weeks.count, 1))
        VStack(alignment: .leading, spacing: 12) {
            CardHeader(title: "Weekly distance", symbol: "chart.bar.fill", subtitle: "Last 8 weeks")
            Chart {
                ForEach(weeks) { week in
                    BarMark(x: .value("Week", week.weekStart, unit: .weekOfYear),
                            y: .value("Distance", week.kilometres))
                        .foregroundStyle(Color.accentColor.gradient)
                        .cornerRadius(6)
                }
                RuleMark(y: .value("Average", average))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(.secondary)
                    .annotation(position: .top, alignment: .leading) {
                        Text("avg \(Format.kilometres(average))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
            }
            .chartYAxisLabel("km")
            .frame(height: 180)
        }
        .card()
    }
}
