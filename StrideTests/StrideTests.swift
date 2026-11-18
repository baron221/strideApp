import Foundation
import Testing
@testable import Stride

// The app code runs on the main actor (Xcode 26 default), so the tests do too.

// MARK: - Helpers

@MainActor
private func makeRun(daysAgo: Double, km: Double, minutes: Double, effort: Int = 5,
                     type: RunType = .easy, note: String = "", pain: [String] = [],
                     now: Date = Date(timeIntervalSince1970: 1_800_000_000)) -> Run {
    let entry = RunEntry(date: now.addingTimeInterval(-daysAgo * 86_400), distanceKm: km,
                         durationSeconds: minutes * 60, averageHeartRate: nil, effort: effort, note: note)
    let analysis = RunAnalysis(runType: type, confidence: 0.9, probabilities: [type.rawValue: 0.9],
                               source: .coreML, heartRateWasEstimated: true, mood: .neutral,
                               moodScore: 0, painWords: pain)
    return Run(entry: entry, analysis: analysis)
}

private let fixedNow = Date(timeIntervalSince1970: 1_800_000_000)

// MARK: - Formatting

@MainActor
struct FormatTests {
    @Test func paceIsMinutesAndSeconds() {
        #expect(Format.pace(secondsPerKm: 330) == "5:30")
        #expect(Format.pace(secondsPerKm: 359.6) == "6:00")
        #expect(Format.pace(secondsPerKm: 0) == "–")
    }

    @Test func durationAddsHoursWhenNeeded() {
        #expect(Format.duration(seconds: 1500) == "25:00")
        #expect(Format.duration(seconds: 3725) == "1:02:05")
    }

    @Test func numbersAcceptCommaOrDot() {
        #expect(Format.number(from: "5,2") == 5.2)
        #expect(Format.number(from: " 10.5 ") == 10.5)
        #expect(Format.number(from: "abc") == nil)
    }

    @Test func effortHasWords() {
        #expect(Format.effortLabel(1) == "Very easy")
        #expect(Format.effortLabel(7) == "Hard")
        #expect(Format.effortLabel(10) == "All-out")
    }
}

// MARK: - Features for the Core ML model

@MainActor
struct RunFeaturesTests {
    private let entry = RunEntry(date: fixedNow, distanceKm: 5, durationSeconds: 1800,
                                 averageHeartRate: 160, effort: 6, note: "")

    @Test func heartRateBecomesShareOfMax() {
        let features = RunFeatures.make(from: entry, usualPaceSecondsPerKm: nil, maxHeartRate: 200)
        #expect(features.heartRatePercent == 0.8)
        #expect(features.heartRateWasEstimated == false)
        #expect(features.durationMin == 30)
    }

    @Test func missingHeartRateIsEstimatedFromEffort() {
        var noHR = entry
        noHR.averageHeartRate = nil
        let features = RunFeatures.make(from: noHR, usualPaceSecondsPerKm: nil, maxHeartRate: 200)
        #expect(features.heartRateWasEstimated)
        #expect(abs(features.heartRatePercent - 0.79) < 0.0001) // 0.55 + 0.04 × 6
    }

    @Test func paceIsComparedWithUsualPace() {
        // 360 s/km today vs. a usual 400 s/km → 10% faster than usual
        let features = RunFeatures.make(from: entry, usualPaceSecondsPerKm: 400, maxHeartRate: 200)
        #expect(abs(features.relativePace - 0.9) < 0.0001)
        let first = RunFeatures.make(from: entry, usualPaceSecondsPerKm: nil, maxHeartRate: 200)
        #expect(first.relativePace == 1.0)
    }
}

// MARK: - Core ML run classifier

@MainActor
struct RunClassifierTests {
    let classifier = RunClassifier()

    private func features(_ km: Double, _ min: Double, rel: Double, hr: Double, effort: Double) -> RunFeatures {
        RunFeatures(distanceKm: km, durationMin: min, relativePace: rel, heartRatePercent: hr,
                    effort: effort, heartRateWasEstimated: false)
    }

    @Test func modelIsBundledWithTheApp() {
        #expect(classifier.isUsingCoreML, "RunTypeClassifier.mlmodel should be compiled into the app")
    }

    @Test func recognisesTypicalRuns() {
        #expect(classifier.classify(features(4, 30, rel: 1.15, hr: 0.65, effort: 2)).type == .recovery)
        #expect(classifier.classify(features(6, 40, rel: 1.0, hr: 0.72, effort: 4)).type == .easy)
        #expect(classifier.classify(features(16, 105, rel: 1.05, hr: 0.75, effort: 6)).type == .long)
        #expect(classifier.classify(features(7, 35, rel: 0.87, hr: 0.86, effort: 7)).type == .tempo)
        #expect(classifier.classify(features(6, 38, rel: 0.93, hr: 0.89, effort: 9)).type == .intervals)
    }

    @Test func probabilitiesAddUpToOne() {
        let result = classifier.classify(features(7, 35, rel: 0.87, hr: 0.86, effort: 7))
        let total = result.probabilities.values.reduce(0, +)
        #expect(abs(total - 1) < 0.01)
        #expect(result.confidence > 0.5)
        #expect(result.ranked.first?.type == result.type)
    }

    @Test func ruleFallbackGivesSensibleAnswers() {
        #expect(RuleBasedClassifier.classify(features(18, 120, rel: 1.05, hr: 0.75, effort: 5)).type == .long)
        #expect(RuleBasedClassifier.classify(features(5, 30, rel: 0.95, hr: 0.9, effort: 9)).type == .intervals)
        #expect(RuleBasedClassifier.classify(features(5, 35, rel: 1.0, hr: 0.72, effort: 4)).type == .easy)
    }
}

// MARK: - Natural Language mood and pain words

@MainActor
struct MoodAnalyzerTests {
    @Test func findsPainWordsInAnyForm() {
        #expect(MoodAnalyzer.analyze("My knee hurts a little").painWords == ["hurts"])
        #expect(MoodAnalyzer.analyze("Legs feel sore and my ankle is aching").painWords.count == 2)
    }

    @Test func ignoresNegatedPain() {
        #expect(MoodAnalyzer.analyze("Easy run, no pain at all today!").painWords.isEmpty)
        #expect(MoodAnalyzer.analyze("Not sore anymore").painWords.isEmpty)
    }

    @Test func emptyNoteIsNeutral() {
        let result = MoodAnalyzer.analyze("   ")
        #expect(result.mood == .neutral)
        #expect(result.score == 0)
    }

    @Test func scoreStaysInRange() {
        let score = MoodAnalyzer.analyze("Beautiful morning, I loved this run!").score
        #expect((-1...1).contains(score))
    }
}

// MARK: - Race predictor (linear regression on a log–log scale)

@MainActor
struct RacePredictorTests {
    @Test func learnsThePersonalExponent() throws {
        // Runs that follow time = 300 s × distance^1.08 exactly
        let runs = [3.0, 5.0, 8.0, 12.0].enumerated().map { index, km in
            makeRun(daysAgo: Double(index + 1), km: km, minutes: 300 * pow(km, 1.08) / 60, effort: 7, type: .tempo)
        }
        let result = try #require(RacePredictor.predict(from: runs, now: fixedNow))
        #expect(result.isPersonalised)
        #expect(abs(result.exponent - 1.08) < 0.001)
        let tenK = try #require(result.prediction(for: .tenK))
        #expect(abs(tenK.seconds - 300 * pow(10, 1.08)) < 1)
    }

    @Test func usesTypicalExponentWithFewRuns() throws {
        let runs = [makeRun(daysAgo: 2, km: 5, minutes: 25, effort: 8, type: .tempo)]
        let result = try #require(RacePredictor.predict(from: runs, now: fixedNow))
        #expect(result.isPersonalised == false)
        #expect(result.exponent == RacePredictor.typicalExponent)
        let tenK = try #require(result.prediction(for: .tenK))
        #expect(abs(tenK.seconds - 1500 * pow(2, 1.06)) < 1)
    }

    @Test func ignoresEasyAndIntervalRuns() {
        let runs = [makeRun(daysAgo: 1, km: 5, minutes: 35, effort: 4, type: .easy),
                    makeRun(daysAgo: 2, km: 6, minutes: 33, effort: 9, type: .intervals)]
        #expect(RacePredictor.predict(from: runs, now: fixedNow) == nil)
    }

    @Test func exponentIsKeptInARealisticRange() throws {
        // Very inconsistent runs would give an unrealistic slope; it must be clamped.
        let runs = [makeRun(daysAgo: 1, km: 3, minutes: 30, effort: 7, type: .tempo),
                    makeRun(daysAgo: 2, km: 6, minutes: 31, effort: 7, type: .tempo),
                    makeRun(daysAgo: 3, km: 10, minutes: 52, effort: 7, type: .tempo)]
        let result = try #require(RacePredictor.predict(from: runs, now: fixedNow))
        #expect(RacePredictor.exponentRange.contains(result.exponent))
    }

    @Test func slopeOfAStraightLine() {
        let slope = RacePredictor.leastSquaresSlope([(x: 0, y: 1), (x: 1, y: 3), (x: 2, y: 5)])
        #expect(slope == 2)
        #expect(RacePredictor.leastSquaresSlope([(x: 1, y: 1), (x: 1, y: 2)]) == nil)
    }
}

// MARK: - Training statistics

@MainActor
struct TrainingStatsTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tashkent")!
        calendar.firstWeekday = 2 // Monday
        return calendar
    }

    @Test func weeklyDistanceHasOneBarPerWeek() {
        let runs = [makeRun(daysAgo: 0.1, km: 5, minutes: 30), makeRun(daysAgo: 0.2, km: 3, minutes: 20),
                    makeRun(daysAgo: 21, km: 10, minutes: 70)]
        let weeks = TrainingStats.weeklyDistance(runs, weeks: 8, now: fixedNow, calendar: calendar)
        #expect(weeks.count == 8)
        #expect(weeks.last?.kilometres == 8)
        #expect(weeks.map(\.kilometres).reduce(0, +) == 18)
    }

    @Test func balanceCountsHardRuns() {
        let runs = [makeRun(daysAgo: 1, km: 5, minutes: 30, type: .tempo),
                    makeRun(daysAgo: 2, km: 5, minutes: 35, type: .easy),
                    makeRun(daysAgo: 3, km: 5, minutes: 28, type: .intervals),
                    makeRun(daysAgo: 4, km: 12, minutes: 85, type: .long),
                    makeRun(daysAgo: 30, km: 5, minutes: 30, type: .tempo)] // too old
        let balance = TrainingStats.intensityBalance(runs, days: 14, now: fixedNow)
        #expect(balance.hard == 2)
        #expect(balance.easy == 2)
        #expect(balance.easyShare == 0.5)
        #expect(balance.isBalanced == false)
    }

    @Test func usualPaceIsTheMedianOfEarlierRuns() {
        let runs = [makeRun(daysAgo: 3, km: 5, minutes: 30),   // 360 s/km
                    makeRun(daysAgo: 2, km: 5, minutes: 35),   // 420 s/km
                    makeRun(daysAgo: 1, km: 5, minutes: 40)]   // 480 s/km
        #expect(TrainingStats.usualPace(before: fixedNow, in: runs) == 420)
        #expect(TrainingStats.usualPace(before: fixedNow.addingTimeInterval(-10 * 86_400), in: runs) == nil)
    }

    @Test func painMentionsOnlyCountThisWeek() {
        let runs = [makeRun(daysAgo: 1, km: 5, minutes: 30, pain: ["sore"]),
                    makeRun(daysAgo: 10, km: 5, minutes: 30, pain: ["hurt"])]
        #expect(TrainingStats.painMentions(runs, days: 7, now: fixedNow) == 1)
    }
}

// MARK: - Coach

@MainActor
struct CoachTests {
    private func context(pain: Int = 0, easy: Int = 4, hard: Int = 1) -> CoachContext {
        CoachContext(name: "Dilnoza", goal: .tenK, predictedGoalTime: "1:04:00", kilometresThisWeek: 15,
                     runsThisWeek: 3, weeklyChange: 0.05,
                     balance: IntensityBalance(easy: easy, hard: hard),
                     painMentionsThisWeek: pain, lastMood: .positive)
    }

    @Test func rulesAlwaysGiveThreeTips() {
        let advice = RuleCoach.advice(for: context())
        #expect(advice.tips.count == 3)
        #expect(advice.source == .smartRules)
    }

    @Test func painComesFirst() {
        let advice = RuleCoach.advice(for: context(pain: 2))
        #expect(advice.headline == "Listen to your body this week")
        #expect(advice.tips.first?.contains("rest") == true)
    }

    @Test func tooManyHardRunsIsFlagged() {
        let advice = RuleCoach.advice(for: context(easy: 2, hard: 3))
        #expect(advice.headline == "Slow down to get faster")
    }

    @Test func parsesTheLanguageModelFormat() throws {
        let text = """
            HEADLINE: Easy miles, strong finish
            - Run four easy runs this week.
            • Keep one tempo run of 20 minutes.
            - Rest if your knee hurts.
            """
        let advice = try #require(AICoach.parse(text))
        #expect(advice.headline == "Easy miles, strong finish")
        #expect(advice.tips.count == 3)
        #expect(AICoach.parse("Just keep running!") == nil)
    }
}

// MARK: - JSON persistence

@MainActor
struct PersistenceTests {
    @Test func savesAndLoadsTheSameData() throws {
        let url = URL.temporaryDirectory.appending(path: "stride-test-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let storage = RunStorage(fileURL: url)
        var data = StrideData()
        data.profile.age = 25
        data.runs = [makeRun(daysAgo: 1, km: 6.5, minutes: 41, effort: 7, type: .tempo, pain: ["hurts"])]
        try storage.save(data)
        let loaded = try #require(try storage.load())
        #expect(loaded.profile.age == 25)
        #expect(loaded.runs.first?.analysis.runType == .tempo)
        #expect(loaded.runs.first?.analysis.painWords == ["hurts"])
        #expect(abs(loaded.runs[0].date.timeIntervalSince(data.runs[0].date)) < 1)
    }

    @Test func jsonIsReadable() throws {
        let data = StrideData(runs: [makeRun(daysAgo: 1, km: 5, minutes: 30, type: .easy)])
        let encoded = try RunStorage.makeEncoder().encode(data)
        let json = String(decoding: encoded, as: UTF8.self)
        #expect(json.contains("\"runType\" : \"Easy\""))
        #expect(json.contains("\"distanceKm\" : 5"))
    }

    @Test func sampleDataIsAnalysedByTheAI() {
        let url = URL.temporaryDirectory.appending(path: "stride-sample-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = RunStore(storage: RunStorage(fileURL: url))
        store.loadSampleData()
        #expect(store.runs.count == SampleData.templates.count)
        #expect(Set(store.runs.map(\.analysis.runType)).count >= 4)
        #expect(store.runs.contains { $0.analysis.painMentioned })
        #expect(store.racePrediction != nil)
    }
}
