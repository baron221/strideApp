import Foundation

/// The five kinds of run the Core ML model can recognise.
enum RunType: String, Codable, CaseIterable, Identifiable {
    case recovery = "Recovery"
    case easy = "Easy"
    case long = "Long"
    case tempo = "Tempo"
    case intervals = "Intervals"

    var id: String { rawValue }

    /// Tempo and interval runs count as "hard" for the 80/20 balance.
    var isHard: Bool { self == .tempo || self == .intervals }

    var title: String { "\(rawValue) run" }

    var symbol: String {
        switch self {
        case .recovery: "leaf.fill"
        case .easy: "figure.run"
        case .long: "road.lanes"
        case .tempo: "speedometer"
        case .intervals: "bolt.heart.fill"
        }
    }

    /// Short coaching explanation shown in the run detail screen.
    var explanation: String {
        switch self {
        case .recovery: "Very gentle running that helps your body recover."
        case .easy: "Comfortable, conversational pace. Most of your running should look like this."
        case .long: "Your longest run of the week. It builds endurance for race day."
        case .tempo: "Steady, comfortably hard running. It raises the pace you can hold."
        case .intervals: "Fast repeats with short rests. Powerful, but needs recovery afterwards."
        }
    }
}

/// Mood detected in the post-run note by the Natural Language framework.
enum Mood: String, Codable {
    case positive, neutral, negative

    var symbol: String {
        switch self {
        case .positive: "sun.max.fill"
        case .neutral: "cloud.sun.fill"
        case .negative: "cloud.rain.fill"
        }
    }

    var label: String {
        switch self {
        case .positive: "Positive"
        case .neutral: "Neutral"
        case .negative: "Negative"
        }
    }
}

/// Where an analysis came from, so the app can be honest about it.
enum AnalysisSource: String, Codable {
    case coreML = "Core ML model"
    case rules = "Rule-based fallback"
}

/// Everything the on-device AI worked out about one run.
/// It is saved together with the run, so the JSON history shows the AI's output too.
struct RunAnalysis: Codable, Equatable, Hashable {
    var runType: RunType
    /// Probability of `runType`, 0...1.
    var confidence: Double
    /// Probability for every run type, keyed by `RunType.rawValue`.
    var probabilities: [String: Double]
    var source: AnalysisSource
    var heartRateWasEstimated: Bool
    var mood: Mood
    /// Natural Language sentiment score, -1 (negative) ... +1 (positive).
    var moodScore: Double
    var painWords: [String]

    var painMentioned: Bool { !painWords.isEmpty }

    func probability(of type: RunType) -> Double { probabilities[type.rawValue] ?? 0 }

    /// The probabilities keyed by `RunType` (handy for the views).
    var typedProbabilities: [RunType: Double] {
        Dictionary(uniqueKeysWithValues: RunType.allCases.map { ($0, probability(of: $0)) })
    }
}

/// What the runner types in when logging a run (before any AI analysis).
struct RunEntry: Equatable {
    var date: Date
    var distanceKm: Double
    var durationSeconds: Double
    var averageHeartRate: Int?
    var effort: Int
    var note: String

    var isValid: Bool { distanceKm > 0 && durationSeconds > 0 && (1...10).contains(effort) }
    var paceSecondsPerKm: Double { durationSeconds / max(distanceKm, 0.01) }
}

/// One saved run.
struct Run: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var date: Date
    var distanceKm: Double
    var durationSeconds: Double
    var averageHeartRate: Int?
    /// Perceived effort, 1 (very easy) ... 10 (maximal).
    var effort: Int
    var note: String
    var analysis: RunAnalysis

    init(id: UUID = UUID(), entry: RunEntry, analysis: RunAnalysis) {
        self.id = id
        self.date = entry.date
        self.distanceKm = entry.distanceKm
        self.durationSeconds = entry.durationSeconds
        self.averageHeartRate = entry.averageHeartRate
        self.effort = entry.effort
        self.note = entry.note
        self.analysis = analysis
    }

    var entry: RunEntry {
        RunEntry(date: date, distanceKm: distanceKm, durationSeconds: durationSeconds,
                 averageHeartRate: averageHeartRate, effort: effort, note: note)
    }

    var paceSecondsPerKm: Double { durationSeconds / max(distanceKm, 0.01) }
    var durationMinutes: Double { durationSeconds / 60 }
}

enum RaceDistance: String, Codable, CaseIterable, Identifiable {
    case fiveK = "5K"
    case tenK = "10K"
    case half = "Half marathon"

    var id: String { rawValue }

    var kilometres: Double {
        switch self {
        case .fiveK: 5
        case .tenK: 10
        case .half: 21.0975
        }
    }
}

struct RunnerProfile: Codable, Equatable {
    var name: String = "Dilnoza"
    var age: Int = 19
    var goal: RaceDistance = .tenK

    /// Estimated maximum heart rate (Tanaka formula: 208 − 0.7 × age).
    var maxHeartRate: Int { Int((208 - 0.7 * Double(age)).rounded()) }
}

/// The whole file that is saved as JSON.
struct StrideData: Codable, Equatable {
    var version: Int = 1
    var profile: RunnerProfile = RunnerProfile()
    var runs: [Run] = []
}
