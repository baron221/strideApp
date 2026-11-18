import SwiftUI

/// Tab 3: runner profile, data export and the status of each on-device AI feature.
struct SettingsView: View {
    @Environment(RunStore.self) private var store
    @State private var confirmingDelete = false

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $store.profile.name)
                    Stepper("Age: \(store.profile.age)", value: $store.profile.age, in: 12...90)
                    LabeledContent("Max heart rate", value: "\(store.profile.maxHeartRate) bpm")
                    Picker("Goal race", selection: $store.profile.goal) {
                        ForEach(RaceDistance.allCases) { race in
                            Text(race.rawValue).tag(race)
                        }
                    }
                } header: {
                    Text("Runner")
                } footer: {
                    Text("Max heart rate is estimated with the Tanaka formula (208 − 0.7 × age). Changing your age re-analyses every run.")
                }

                Section {
                    AIFeatureRow(title: "Run type classifier",
                                 detail: store.classifier.isUsingCoreML ? "Core ML model · loaded" : "Model missing · using rules",
                                 symbol: "brain",
                                 isReady: store.classifier.isUsingCoreML)
                    AIFeatureRow(title: "Mood & pain detection",
                                 detail: "Natural Language framework",
                                 symbol: "text.bubble",
                                 isReady: true)
                    AIFeatureRow(title: "Race predictor",
                                 detail: "Learns from your runs (regression)",
                                 symbol: "function",
                                 isReady: true)
                    AIFeatureRow(title: "AI coach",
                                 detail: store.coach.statusText,
                                 symbol: "sparkles",
                                 isReady: store.coach.isAppleIntelligenceAvailable)
                } header: {
                    Text("On-device AI")
                } footer: {
                    Text("Everything runs on this iPhone. Your runs and notes are never uploaded.")
                }

                Section {
                    ShareLink(item: store.exportURL) {
                        Label("Export runs (JSON)", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        store.loadSampleData()
                    } label: {
                        Label("Load sample runs", systemImage: "tray.and.arrow.down")
                    }
                    Button(role: .destructive) {
                        confirmingDelete = true
                    } label: {
                        Label("Delete all runs", systemImage: "trash")
                    }
                } header: {
                    Text("Data")
                } footer: {
                    Text("Your history is saved on this iPhone as stride-runs.json.")
                }
            }
            .navigationTitle("Settings")
            .onChange(of: store.profile.age) { store.reanalyzeAll() }
            .onChange(of: store.profile.name) { store.save() }
            .onChange(of: store.profile.goal) { store.save() }
            .confirmationDialog("Delete all runs?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete all runs", role: .destructive) { store.deleteAll() }
            } message: {
                Text("This can't be undone.")
            }
        }
    }
}

struct AIFeatureRow: View {
    let title: String
    let detail: String
    let symbol: String
    let isReady: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: isReady ? "checkmark.circle.fill" : "minus.circle")
                .foregroundStyle(isReady ? Color.green : Color.secondary)
                .accessibilityLabel(isReady ? "Ready" : "Not available")
        }
        .accessibilityElement(children: .combine)
    }
}
