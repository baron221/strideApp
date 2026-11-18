import Foundation

struct RacePrediction: Identifiable, Equatable {
    var distance: RaceDistance
    var seconds: Double
    var id: RaceDistance { distance }
    var pacePerKm: Double { seconds / distance.kilometres }
}

struct RacePredictorResult: Equatable {
    var predictions: [RacePrediction]
    /// The runner's personal "endurance factor" (Riegel exponent). Typical runners ≈ 1.06.
    var exponent: Double
    var runsUsed: Int
    /// true when the exponent was learned from this runner's own runs.
    var isPersonalised: Bool

    func prediction(for distance: RaceDistance) -> RacePrediction? {
        predictions.first { $0.distance == distance }
    }
}

/// Predicts race finish times by learning from the runner's own hard efforts.
///
/// Peter Riegel found that race time grows with distance like a power law:
///     time = a × distance^b
/// Taking logarithms turns it into a straight line:
///     ln(time) = ln(a) + b × ln(distance)
/// so we can *learn* a and b with simple linear regression (least squares).
/// b is personal: a lower b means you slow down less over longer distances.
enum RacePredictor {
    static let typicalExponent = 1.06
    static let exponentRange = 1.01...1.15
    static let lookbackDays = 90

    /// Hard efforts tell us most about race fitness. Interval runs are left out
    /// because their average pace includes the rest breaks.
    static func qualityRuns(from runs: [Run], now: Date = .now) -> [Run] {
        let start = Calendar.current.date(byAdding: .day, value: -lookbackDays, to: now) ?? now
        return runs.filter { run in
            let type = run.analysis.runType
            let isRecent = run.date >= start && run.date <= now
            let isHardEffort = type == .tempo || type == .long || run.effort >= 7
            return isRecent && run.distanceKm >= 1 && type != .intervals && isHardEffort
        }
    }

    static func predict(from runs: [Run], now: Date = .now) -> RacePredictorResult? {
        let quality = qualityRuns(from: runs, now: now)
        guard !quality.isEmpty else { return nil }

        let points = quality.map { (x: log($0.distanceKm), y: log($0.durationSeconds)) }
        var exponent = typicalExponent
        var personalised = false

        let distances = quality.map(\.distanceKm)
        if points.count >= 3, let minD = distances.min(), let maxD = distances.max(), maxD / minD >= 1.5,
           let slope = leastSquaresSlope(points) {
            exponent = min(max(slope, exponentRange.lowerBound), exponentRange.upperBound)
            personalised = true
        }

        let intercept: Double
        if personalised {
            // Best-fit line through the average point, using the (clamped) personal exponent.
            intercept = points.map { $0.y - exponent * $0.x }.reduce(0, +) / Double(points.count)
        } else {
            // Not enough variety yet: anchor the typical curve on the best recent effort.
            guard let best = quality.min(by: { equivalentTenK($0, exponent) < equivalentTenK($1, exponent) }) else {
                return nil
            }
            intercept = log(best.durationSeconds) - exponent * log(best.distanceKm)
        }

        let predictions = RaceDistance.allCases.map { race in
            RacePrediction(distance: race, seconds: exp(intercept + exponent * log(race.kilometres)))
        }
        return RacePredictorResult(predictions: predictions, exponent: exponent,
                                   runsUsed: quality.count, isPersonalised: personalised)
    }

    /// Slope of the least-squares line through the points (nil if all x are equal).
    static func leastSquaresSlope(_ points: [(x: Double, y: Double)]) -> Double? {
        let n = Double(points.count)
        guard n >= 2 else { return nil }
        let meanX = points.map { $0.x }.reduce(0, +) / n
        let meanY = points.map { $0.y }.reduce(0, +) / n
        let sxx = points.map { ($0.x - meanX) * ($0.x - meanX) }.reduce(0, +)
        guard sxx > 1e-9 else { return nil }
        let sxy = points.map { ($0.x - meanX) * ($0.y - meanY) }.reduce(0, +)
        return sxy / sxx
    }

    private static func equivalentTenK(_ run: Run, _ exponent: Double) -> Double {
        run.durationSeconds * pow(10 / run.distanceKm, exponent)
    }
}
