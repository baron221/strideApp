import SwiftUI

/// Details of one run, including *why* the AI chose its run type.
struct RunDetailView: View {
    @Environment(RunStore.self) private var store
    let run: Run

    var body: some View {
        let features = store.features(for: run.entry, excluding: run.id)
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    RunTypeBadge(type: run.analysis.runType, large: true)
                    Text(run.analysis.runType.explanation)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("Run") {
                LabeledContent("Distance", value: Format.kilometres(run.distanceKm))
                LabeledContent("Time", value: Format.duration(seconds: run.durationSeconds))
                LabeledContent("Pace", value: "\(Format.pace(secondsPerKm: run.paceSecondsPerKm)) /km")
                LabeledContent("Heart rate", value: run.averageHeartRate.map { "\($0) bpm" } ?? "Not recorded")
                LabeledContent("Effort", value: "\(run.effort)/10 · \(Format.effortLabel(run.effort))")
            }

            Section {
                ProbabilityBars(probabilities: run.analysis.typedProbabilities)
                    .padding(.vertical, 4)
                LabeledContent("Pace vs. your usual", value: relativePaceText(features.relativePace))
                LabeledContent("Heart rate",
                               value: "\(Format.percent(features.heartRatePercent)) of max" +
                                   (features.heartRateWasEstimated ? " (estimated)" : ""))
                LabeledContent("Effort", value: "\(Int(features.effort)) of 10")
                LabeledContent("Duration", value: "\(Int(features.durationMin.rounded())) min")
            } header: {
                Text("Why “\(run.analysis.runType.rawValue)”?")
            } footer: {
                Text("\(run.analysis.source.rawValue) · \(Format.percent(run.analysis.confidence)) sure · runs on this iPhone")
            }

            Section("How it felt") {
                Text(run.note.isEmpty ? "No note" : run.note)
                Label("Mood: \(run.analysis.mood.label) (score \(String(format: "%+.2f", run.analysis.moodScore)))",
                      systemImage: run.analysis.mood.symbol)
                    .foregroundStyle(run.analysis.mood.color)
                if run.analysis.painMentioned {
                    Label("Pain words: \(run.analysis.painWords.joined(separator: ", "))", systemImage: "bandage.fill")
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(run.date.formatted(date: .abbreviated, time: .shortened))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func relativePaceText(_ relative: Double) -> String {
        if relative < 0.995 { return "\(Format.percent(1 - relative)) faster" }
        if relative > 1.005 { return "\(Format.percent(relative - 1)) slower" }
        return "Your usual pace"
    }
}
