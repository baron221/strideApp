import Foundation
import NaturalLanguage

struct MoodResult: Equatable {
    var mood: Mood
    /// -1 (very negative) ... +1 (very positive)
    var score: Double
    var painWords: [String]
}

/// Reads the runner's post-run note with Apple's Natural Language framework:
/// 1. a built-in sentiment model scores how positive the note sounds,
/// 2. the lemmatizer finds pain words ("hurts", "aching" → "hurt", "ache"), ignoring "no pain".
enum MoodAnalyzer {
    /// Lemmas (dictionary forms) that suggest pain or a possible injury.
    static let painLemmas: Set<String> = [
        "pain", "painful", "hurt", "ache", "aching", "sore", "soreness", "injury", "injure", "injured",
        "cramp", "blister", "sprain", "strain", "swollen", "swell", "twinge", "limp", "tight",
        // common forms, in case the lemmatizer can't tag a very short note
        "hurts", "hurting", "aches", "ached", "cramps", "cramping", "blisters", "sprained", "strained",
    ]
    private static let negations: Set<String> = ["no", "not", "without", "never", "zero", "nothing"]

    static func analyze(_ text: String) -> MoodResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return MoodResult(mood: .neutral, score: 0, painWords: []) }
        let score = sentimentScore(trimmed)
        let mood: Mood = score > 0.2 ? .positive : (score < -0.2 ? .negative : .neutral)
        return MoodResult(mood: mood, score: score, painWords: painWords(in: trimmed))
    }

    static func sentimentScore(_ text: String) -> Double {
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text
        let (tag, _) = tagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)
        return Double(tag?.rawValue ?? "0") ?? 0
    }

    static func painWords(in text: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.lemma])
        tagger.string = text
        var found: [String] = []
        var previousWords: [String] = []
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lemma,
                             options: [.omitWhitespace, .omitPunctuation]) { tag, range in
            let word = text[range].lowercased()
            let lemma = tag?.rawValue.lowercased() ?? word
            let isPain = painLemmas.contains(lemma) || painLemmas.contains(word)
            // "no pain", "not sore", "no pain at all" → not a warning
            let negated = previousWords.suffix(2).contains { negations.contains($0) }
            if isPain && !negated && !found.contains(word) {
                found.append(word)
            }
            previousWords.append(word)
            return true
        }
        return found
    }
}
