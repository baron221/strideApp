import Foundation
import Observation

/// Single source of truth for the app. Views read from it and call its methods.
@Observable
final class RunStore {
    /// Newest first.
    private(set) var runs: [Run] = []
    var profile = RunnerProfile()
    private(set) var coachAdvice: CoachAdvice?
    private(set) var isCoachThinking = false
    var errorMessage: String?

    private let storage: RunStorage
    let classifier: RunClassifier
    let coach: AICoach

    init(storage: RunStorage = RunStorage(), classifier: RunClassifier = RunClassifier(), coach: AICoach = AICoach()) {
        self.storage = storage
        self.classifier = classifier
        self.coach = coach
        load()
    }

    // MARK: - AI analysis

    /// Runs the on-device AI on one entry:
    /// Core ML (run type) + Natural Language (mood and pain words).
    func analyze(_ entry: RunEntry, history: [Run]? = nil, excluding id: UUID? = nil) -> RunAnalysis {
        let usualPace = TrainingStats.usualPace(before: entry.date, in: history ?? runs, excluding: id)
        let features = RunFeatures.make(from: entry, usualPaceSecondsPerKm: usualPace,
                                        maxHeartRate: profile.maxHeartRate)
        let classification = classifier.classify(features)
        let mood = MoodAnalyzer.analyze(entry.note)
        return RunAnalysis(
            runType: classification.type,
            confidence: classification.confidence,
            probabilities: Dictionary(uniqueKeysWithValues: classification.probabilities.map { ($0.key.rawValue, $0.value) }),
            source: classification.source,
            heartRateWasEstimated: features.heartRateWasEstimated,
            mood: mood.mood,
            moodScore: mood.score,
            painWords: mood.painWords
        )
    }

    /// The features the model sees for an entry (shown in the run detail "Why?" section).
    func features(for entry: RunEntry, excluding id: UUID? = nil) -> RunFeatures {
        RunFeatures.make(from: entry,
                         usualPaceSecondsPerKm: TrainingStats.usualPace(before: entry.date, in: runs, excluding: id),
                         maxHeartRate: profile.maxHeartRate)
    }

    // MARK: - Editing

    func add(_ entry: RunEntry) {
        let run = Run(entry: entry, analysis: analyze(entry))
        runs.append(run)
        runs.sort { $0.date > $1.date }
        coachAdvice = nil
        save()
    }

    func delete(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) { runs.remove(at: index) }
        coachAdvice = nil
        save()
    }

    func delete(_ run: Run) {
        runs.removeAll { $0.id == run.id }
        coachAdvice = nil
        save()
    }

    func deleteAll() {
        runs = []
        coachAdvice = nil
        save()
    }

    /// Replaces the history with the six-week sample from the user story.
    func loadSampleData(now: Date = .now) {
        runs = []
        var history: [Run] = []
        for entry in SampleData.entries(now: now).sorted(by: { $0.date < $1.date }) {
            history.append(Run(entry: entry, analysis: analyze(entry, history: history)))
        }
        runs = history.sorted { $0.date > $1.date }
        coachAdvice = nil
        save()
    }

    /// Re-runs the AI on every run in date order (e.g. after the age, and so max heart rate, changes).
    func reanalyzeAll() {
        var history: [Run] = []
        for run in runs.sorted(by: { $0.date < $1.date }) {
            var updated = run
            updated.analysis = analyze(run.entry, history: history)
            history.append(updated)
        }
        runs = history.sorted { $0.date > $1.date }
        coachAdvice = nil
        save()
    }

    func profileChanged() {
        reanalyzeAll()
    }

    // MARK: - Insights

    var thisWeek: WeeklyDistance { TrainingStats.thisWeek(runs) }
    var weeklyDistance: [WeeklyDistance] { TrainingStats.weeklyDistance(runs) }
    var balance: IntensityBalance { TrainingStats.intensityBalance(runs) }
    var typeMix: [TypeCount] { TrainingStats.typeMix(runs) }
    var painMentionsThisWeek: Int { TrainingStats.painMentions(runs) }
    var racePrediction: RacePredictorResult? { RacePredictor.predict(from: runs) }

    var coachContext: CoachContext {
        var goalTime: String?
        if let prediction = racePrediction?.prediction(for: profile.goal) {
            goalTime = Format.duration(seconds: prediction.seconds)
        }
        return CoachContext(name: profile.name,
                            goal: profile.goal,
                            predictedGoalTime: goalTime,
                            kilometresThisWeek: thisWeek.kilometres,
                            runsThisWeek: thisWeek.runs,
                            weeklyChange: TrainingStats.weeklyChange(runs),
                            balance: balance,
                            painMentionsThisWeek: painMentionsThisWeek,
                            lastMood: runs.first?.analysis.mood)
    }

    func refreshCoach() async {
        isCoachThinking = true
        coachAdvice = await coach.advice(for: coachContext)
        isCoachThinking = false
    }

    // MARK: - Persistence

    var exportURL: URL { storage.fileURL }

    func load() {
        do {
            if let data = try storage.load() {
                profile = data.profile
                runs = data.runs.sorted { $0.date > $1.date }
            } else {
                save() // create the file on first launch, so it can be exported
            }
        } catch {
            errorMessage = "Couldn't read saved runs: \(error.localizedDescription)"
        }
    }

    func save() {
        do {
            try storage.save(StrideData(profile: profile, runs: runs))
        } catch {
            errorMessage = "Couldn't save runs: \(error.localizedDescription)"
        }
    }
}
