import SwiftUI

/// Sheet for logging a run. The AI analysis updates live while you type.
struct LogRunView: View {
    @Environment(RunStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var date = Date.now
    @State private var distanceText = "5.0"
    @State private var minutesText = "32"
    @State private var secondsText = "00"
    @State private var hasHeartRate = true
    @State private var heartRateText = "150"
    @State private var effort = 5.0
    @State private var note = ""

    private var entry: RunEntry {
        let minutes = Format.number(from: minutesText) ?? 0
        let seconds = Format.number(from: secondsText) ?? 0
        var heartRate: Int?
        if hasHeartRate, let value = Format.number(from: heartRateText) {
            heartRate = Int(value)
        }
        return RunEntry(date: date,
                        distanceKm: Format.number(from: distanceText) ?? 0,
                        durationSeconds: minutes * 60 + seconds,
                        averageHeartRate: heartRate,
                        effort: Int(effort),
                        note: note)
    }

    private var analysis: RunAnalysis? {
        entry.isValid ? store.analyze(entry) : nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Your run") {
                    DatePicker("Date", selection: $date, in: ...Date.now)
                    HStack {
                        Text("Distance")
                        Spacer()
                        TextField("5.0", text: $distanceText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 90)
                            .accessibilityIdentifier("distanceField")
                        Text("km").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Time")
                        Spacer()
                        TextField("30", text: $minutesText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 50)
                            .accessibilityLabel("Minutes")
                        Text("min").foregroundStyle(.secondary)
                        TextField("00", text: $secondsText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 36)
                            .accessibilityLabel("Seconds")
                        Text("s").foregroundStyle(.secondary)
                    }
                    LabeledContent("Pace",
                                   value: entry.isValid ? "\(Format.pace(secondsPerKm: entry.paceSecondsPerKm)) /km" : "–")
                }

                Section {
                    Toggle("Heart-rate data", isOn: $hasHeartRate.animation())
                    if hasHeartRate {
                        HStack {
                            Text("Average heart rate")
                            Spacer()
                            TextField("150", text: $heartRateText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                            Text("bpm").foregroundStyle(.secondary)
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Effort")
                            Spacer()
                            Text("\(Int(effort)) · \(Format.effortLabel(Int(effort)))")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $effort, in: 1...10, step: 1) {
                            Text("Effort")
                        } minimumValueLabel: {
                            Text("1")
                        } maximumValueLabel: {
                            Text("10")
                        }
                    }
                } header: {
                    Text("How hard was it?")
                } footer: {
                    if !hasHeartRate {
                        Text("No heart-rate monitor? Stride estimates your heart rate from your effort.")
                    }
                }

                Section("How did it feel?") {
                    TextField("e.g. Felt strong, but my knee is a little sore", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                        .accessibilityIdentifier("noteField")
                }

                Section {
                    AnalysisPreview(analysis: analysis)
                } header: {
                    Label("On-device AI · live", systemImage: "sparkles")
                } footer: {
                    Text("Run type: Core ML model. Mood and pain words: Natural Language framework. Nothing leaves your iPhone.")
                }
            }
            .navigationTitle("Log a run")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.add(entry)
                        dismiss()
                    }
                    .disabled(!entry.isValid)
                    .accessibilityIdentifier("saveRunButton")
                }
            }
        }
    }
}

/// The live AI result inside the log form.
struct AnalysisPreview: View {
    let analysis: RunAnalysis?

    var body: some View {
        if let analysis {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    RunTypeBadge(type: analysis.runType)
                    Spacer()
                    Text("\(Format.percent(analysis.confidence)) sure")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                ProbabilityBars(probabilities: analysis.typedProbabilities)
                Divider()
                Label("Mood: \(analysis.mood.label)", systemImage: analysis.mood.symbol)
                    .foregroundStyle(analysis.mood.color)
                if analysis.painMentioned {
                    Label("Pain words: \(analysis.painWords.joined(separator: ", "))", systemImage: "bandage.fill")
                        .foregroundStyle(.red)
                }
                if analysis.heartRateWasEstimated {
                    Label("Heart rate estimated from effort", systemImage: "heart.text.square")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        } else {
            Text("Enter a distance and a time to see what the AI thinks.")
                .foregroundStyle(.secondary)
        }
    }
}
