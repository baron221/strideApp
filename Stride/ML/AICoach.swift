import Foundation
import FoundationModels

/// A short weekly coaching note.
struct CoachAdvice: Equatable {
    enum Source: Equatable {
        case appleIntelligence
        case smartRules
    }

    var headline: String
    var tips: [String]
    var source: Source
}

/// The training facts the coach is allowed to see (no personal data leaves the device).
struct CoachContext: Equatable {
    var name: String
    var goal: RaceDistance
    var predictedGoalTime: String?
    var kilometresThisWeek: Double
    var runsThisWeek: Int
    var weeklyChange: Double?
    var balance: IntensityBalance
    var painMentionsThisWeek: Int
    var lastMood: Mood?

    /// The facts written as plain text for the language model.
    var summary: String {
        var lines = [
            "Runner: \(name), training for a \(goal.rawValue).",
            "This week: \(String(format: "%.1f", kilometresThisWeek)) km in \(runsThisWeek) runs.",
            "Last 14 days: \(balance.easy) easy runs and \(balance.hard) hard runs (\(Format.percent(balance.easyShare)) easy).",
        ]
        if let change = weeklyChange { lines.append("Distance change vs last week: \(Format.percent(change)).") }
        if let time = predictedGoalTime { lines.append("Predicted \(goal.rawValue) time: \(time).") }
        lines.append("Pain mentioned in notes this week: \(painMentionsThisWeek) time(s).")
        if let mood = lastMood { lines.append("Mood after the last run: \(mood.label.lowercased()).") }
        return lines.joined(separator: "\n")
    }
}

/// Writes the weekly coaching note.
/// - With Apple Intelligence available, Apple's on-device language model (Foundation Models framework)
///   writes a personal note from the training facts.
/// - Otherwise, the same facts go through simple coaching rules. The app works everywhere.
final class AICoach {
    static let instructions = """
        You are a friendly, careful running coach for beginner and student runners.
        Use only the training facts you are given. Be encouraging and specific.
        Follow the 80/20 idea: about 80% of runs easy, 20% hard.
        Never increase weekly distance by more than about 10%.
        If pain is mentioned, recommend rest and seeing a doctor or physiotherapist if it continues.
        Do not give medical diagnoses.
        Reply in exactly this format and nothing else:
        HEADLINE: <a headline of at most 8 words>
        - <tip 1, at most 20 words>
        - <tip 2, at most 20 words>
        - <tip 3, at most 20 words>
        """

    var isAppleIntelligenceAvailable: Bool { SystemLanguageModel.default.isAvailable }

    /// Friendly status text for the Settings screen.
    var statusText: String {
        switch SystemLanguageModel.default.availability {
        case .available:
            return "Ready — runs on this device"
        case .unavailable(let reason):
            switch reason {
            case .appleIntelligenceNotEnabled:
                return "Turn on Apple Intelligence in Settings to use it"
            case .modelNotReady:
                return "The on-device model is still downloading"
            default:
                return "Not supported on this device — using Smart rules"
            }
        }
    }

    func advice(for context: CoachContext) async -> CoachAdvice {
        guard isAppleIntelligenceAvailable else { return RuleCoach.advice(for: context) }
        do {
            let session = LanguageModelSession(instructions: Self.instructions)
            let prompt: String = "Training facts:\n" + context.summary
            let response = try await session.respond(to: prompt)
            if let advice = Self.parse(response.content) {
                return advice
            }
        } catch {
            // Guardrails, a busy model or any other error: fall back to the rules below.
        }
        return RuleCoach.advice(for: context)
    }

    /// Turns the model's text into a headline and tips. Returns nil if the format is wrong.
    static func parse(_ text: String) -> CoachAdvice? {
        var headline = ""
        var tips: [String] = []
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.uppercased().hasPrefix("HEADLINE:") {
                headline = String(line.dropFirst("HEADLINE:".count)).trimmingCharacters(in: .whitespaces)
            } else if let first = line.first, "-•*".contains(first) {
                let tip = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
                if !tip.isEmpty { tips.append(tip) }
            }
        }
        guard !headline.isEmpty, !tips.isEmpty else { return nil }
        return CoachAdvice(headline: headline, tips: Array(tips.prefix(3)), source: .appleIntelligence)
    }
}

/// Coaching rules used when Apple Intelligence is not available (and in unit tests).
enum RuleCoach {
    static func advice(for c: CoachContext) -> CoachAdvice {
        var tips: [String] = []
        let headline: String

        if c.painMentionsThisWeek > 0 {
            headline = "Listen to your body this week"
            tips.append("You mentioned pain \(c.painMentionsThisWeek == 1 ? "once" : "\(c.painMentionsThisWeek) times"). Take a rest day, and see a doctor if it continues.")
        } else if c.runsThisWeek == 0 {
            headline = "Let's get this week started"
            tips.append("Start with an easy 20–30 minute run at a pace where you can still talk.")
        } else if !c.balance.isBalanced {
            headline = "Slow down to get faster"
        } else {
            headline = "Great balance — keep it steady"
        }

        if !c.balance.isBalanced {
            tips.append("Only \(Format.percent(c.balance.easyShare)) of your recent runs were easy. Aim for about 80% easy runs.")
        }
        if let change = c.weeklyChange, change > 0.10 {
            tips.append("Your distance went up \(Format.percent(change)). Keep increases to about 10% a week.")
        }
        if let time = c.predictedGoalTime {
            tips.append("Your predicted \(c.goal.rawValue) time is \(time). One steady tempo run a week will help it drop.")
        }
        if c.lastMood == .negative {
            tips.append("Your last note sounded tough. Make the next run short and easy, and enjoy it.")
        }
        if tips.count < 3 {
            tips.append("Plan one longer, easy run this week to build endurance for your \(c.goal.rawValue).")
        }
        if tips.count < 3 {
            tips.append("Sleep, water and a short warm-up make every run feel better.")
        }
        return CoachAdvice(headline: headline, tips: Array(tips.prefix(3)), source: .smartRules)
    }
}
