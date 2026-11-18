import SwiftUI

/// Tab 1: this week's summary and the run history.
struct RunsView: View {
    @Environment(RunStore.self) private var store
    @State private var showingLog = false

    var body: some View {
        NavigationStack {
            Group {
                if store.runs.isEmpty {
                    ContentUnavailableView {
                        Label("No runs yet", systemImage: "figure.run")
                    } description: {
                        Text("Log your first run, or load six weeks of sample runs to try the AI features.")
                    } actions: {
                        Button("Log a run") { showingLog = true }
                            .buttonStyle(.borderedProminent)
                        Button("Load sample runs") { store.loadSampleData() }
                            .accessibilityIdentifier("loadSampleButton")
                    }
                } else {
                    List {
                        Section {
                            WeekSummaryView()
                        }
                        Section("History") {
                            ForEach(store.runs) { run in
                                NavigationLink(value: run) {
                                    RunRow(run: run)
                                }
                            }
                            .onDelete { store.delete(at: $0) }
                        }
                    }
                    .navigationDestination(for: Run.self) { run in
                        RunDetailView(run: run)
                    }
                }
            }
            .navigationTitle("Stride")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingLog = true
                    } label: {
                        Label("Log run", systemImage: "plus")
                    }
                    .accessibilityIdentifier("logRunButton")
                }
            }
            .sheet(isPresented: $showingLog) {
                LogRunView()
            }
        }
    }
}

/// "This week" card at the top of the list.
struct WeekSummaryView: View {
    @Environment(RunStore.self) private var store

    var body: some View {
        let week = store.thisWeek
        let balance = store.balance
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("This week")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(Format.kilometres(week.kilometres))
                        .font(.largeTitle.bold())
                        .contentTransition(.numericText())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(week.runs) \(week.runs == 1 ? "run" : "runs")")
                        .font(.headline)
                    Text("\(Format.percent(balance.easyShare)) easy · 14 days")
                        .font(.subheadline)
                        .foregroundStyle(balance.isBalanced ? Color.green : Color.orange)
                }
            }
            if balance.total > 0 && !balance.isBalanced {
                Label("Most of your recent runs were hard. Try the 80/20 rule: 4 easy runs for every hard one.",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
            if store.painMentionsThisWeek > 0 {
                Label("You mentioned pain \(store.painMentionsThisWeek)× this week. Consider a rest day.",
                      systemImage: "bandage.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

struct RunRow: View {
    let run: Run

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: run.analysis.runType.symbol)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(run.analysis.runType.color.gradient, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(run.analysis.runType.title)
                    .font(.headline)
                Text(run.date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Format.kilometres(run.distanceKm))
                    .font(.headline.monospacedDigit())
                HStack(spacing: 4) {
                    if run.analysis.painMentioned {
                        Image(systemName: "bandage.fill").foregroundStyle(.red)
                    }
                    Image(systemName: run.analysis.mood.symbol)
                        .foregroundStyle(run.analysis.mood.color)
                    Text("\(Format.pace(secondsPerKm: run.paceSecondsPerKm)) /km")
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline.monospacedDigit())
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        var text = "\(run.analysis.runType.title), \(run.date.formatted(date: .abbreviated, time: .omitted)), "
        text += "\(Format.kilometres(run.distanceKm)), pace \(Format.pace(secondsPerKm: run.paceSecondsPerKm)) per kilometre, "
        text += "mood \(run.analysis.mood.label)"
        if run.analysis.painMentioned { text += ", pain mentioned" }
        return text
    }
}
