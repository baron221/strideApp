import Foundation

/// Small, pure formatting helpers (covered by unit tests).
enum Format {
    /// 330 seconds per km → "5:30"
    static func pace(secondsPerKm: Double) -> String {
        guard secondsPerKm.isFinite, secondsPerKm > 0 else { return "–" }
        let total = Int(secondsPerKm.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// 1500 → "25:00", 3725 → "1:02:05"
    static func duration(seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "–" }
        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
    }

    static func kilometres(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1))) + " km"
    }

    static func percent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(0)))
    }

    /// Words for the 1–10 effort scale.
    static func effortLabel(_ effort: Int) -> String {
        switch effort {
        case ...2: "Very easy"
        case 3...4: "Easy"
        case 5...6: "Moderate"
        case 7...8: "Hard"
        case 9: "Very hard"
        default: "All-out"
        }
    }

    /// Parses "5.2" and "5,2" (comma is the decimal separator in Uzbekistan).
    static func number(from text: String) -> Double? {
        let cleaned = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard let value = Double(cleaned), value.isFinite else { return nil }
        return value
    }
}
