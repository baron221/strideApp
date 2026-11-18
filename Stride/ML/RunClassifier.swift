import CoreML
import Foundation

/// The five numbers the Core ML model looks at.
/// Names match the model's input features exactly.
struct RunFeatures: Equatable {
    var distanceKm: Double
    var durationMin: Double
    /// Pace ÷ the runner's usual pace. 1.0 = usual, 0.9 = 10% faster, 1.1 = 10% slower.
    var relativePace: Double
    /// Average heart rate as a fraction of max heart rate (0.5 ... 1.0).
    var heartRatePercent: Double
    var effort: Double
    var heartRateWasEstimated: Bool

    /// Same rule that was used in the training data when a runner has no heart-rate monitor.
    static func estimatedHeartRatePercent(effort: Int) -> Double { 0.55 + 0.04 * Double(effort) }

    static func make(from entry: RunEntry, usualPaceSecondsPerKm: Double?, maxHeartRate: Int) -> RunFeatures {
        let pace = entry.paceSecondsPerKm
        let relative: Double
        if let usual = usualPaceSecondsPerKm, usual > 0 {
            relative = min(max(pace / usual, 0.6), 1.5)
        } else {
            relative = 1.0 // first run: nothing to compare with yet
        }
        let hrPercent: Double
        let estimated: Bool
        if let heartRate = entry.averageHeartRate, heartRate > 0, maxHeartRate > 0 {
            hrPercent = min(max(Double(heartRate) / Double(maxHeartRate), 0.4), 1.05)
            estimated = false
        } else {
            hrPercent = estimatedHeartRatePercent(effort: entry.effort)
            estimated = true
        }
        return RunFeatures(distanceKm: entry.distanceKm,
                           durationMin: entry.durationSeconds / 60,
                           relativePace: relative,
                           heartRatePercent: hrPercent,
                           effort: Double(entry.effort),
                           heartRateWasEstimated: estimated)
    }
}

struct RunClassification: Equatable {
    var type: RunType
    var probabilities: [RunType: Double]
    var source: AnalysisSource

    var confidence: Double { probabilities[type] ?? 0 }

    /// Run types sorted from most to least likely.
    var ranked: [(type: RunType, probability: Double)] {
        RunType.allCases
            .map { (type: $0, probability: probabilities[$0] ?? 0) }
            .sorted { $0.probability > $1.probability }
    }
}

/// Wraps the bundled Core ML model `RunTypeClassifier.mlmodel`.
/// If the model can't be loaded, it falls back to simple coaching rules, so the app never breaks.
final class RunClassifier {
    private let model: MLModel?

    init(bundle: Bundle = .main) {
        // Xcode compiles RunTypeClassifier.mlmodel into RunTypeClassifier.mlmodelc inside the app.
        if let url = bundle.url(forResource: "RunTypeClassifier", withExtension: "mlmodelc") {
            model = try? MLModel(contentsOf: url)
        } else {
            model = nil
        }
    }

    var isUsingCoreML: Bool { model != nil }

    func classify(_ features: RunFeatures) -> RunClassification {
        if let model, let result = try? predict(with: model, features) {
            return result
        }
        return RuleBasedClassifier.classify(features)
    }

    private func predict(with model: MLModel, _ features: RunFeatures) throws -> RunClassification {
        let input = try MLDictionaryFeatureProvider(dictionary: [
            "distanceKm": features.distanceKm,
            "durationMin": features.durationMin,
            "relativePace": features.relativePace,
            "heartRatePercent": features.heartRatePercent,
            "effort": features.effort,
        ])
        let output = try model.prediction(from: input)

        guard let label = output.featureValue(for: "runType")?.stringValue,
              let type = RunType(rawValue: label) else {
            throw ClassifierError.unexpectedOutput
        }
        var probabilities: [RunType: Double] = [:]
        let scores = output.featureValue(for: "runTypeProbability")?.dictionaryValue ?? [:]
        for (key, value) in scores {
            if let name = key as? String, let runType = RunType(rawValue: name) {
                probabilities[runType] = value.doubleValue
            }
        }
        if probabilities.isEmpty { probabilities[type] = 1 }
        return RunClassification(type: type, probabilities: probabilities, source: .coreML)
    }

    enum ClassifierError: Error { case unexpectedOutput }
}

/// Hand-written coaching rules. Used only if the Core ML model is missing.
/// Comparing these rules with the trained model is a nice classroom discussion:
/// rules are easy to read, but the model handles the "in-between" runs better.
enum RuleBasedClassifier {
    static func classify(_ f: RunFeatures) -> RunClassification {
        let type: RunType
        if f.durationMin >= 75 || f.distanceKm >= 16 {
            type = .long
        } else if f.effort >= 9 || (f.heartRatePercent >= 0.88 && f.effort >= 8) {
            type = .intervals
        } else if f.heartRatePercent >= 0.80 || f.effort >= 6 || f.relativePace <= 0.93 {
            type = .tempo
        } else if f.heartRatePercent < 0.68 || f.effort <= 2 || f.relativePace >= 1.10 {
            type = .recovery
        } else {
            type = .easy
        }
        var probabilities = Dictionary(uniqueKeysWithValues: RunType.allCases.map { ($0, 0.05) })
        probabilities[type] = 0.8
        return RunClassification(type: type, probabilities: probabilities, source: .rules)
    }
}
