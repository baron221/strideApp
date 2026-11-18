import Foundation

struct WeeklyDistance: Identifiable, Equatable {
    var weekStart: Date
    var kilometres: Double
    var runs: Int
    var id: Date { weekStart }
}

struct TypeCount: Identifiable, Equatable {
    var type: RunType
    var count: Int
    var id: RunType { type }
}

struct IntensityBalance: Equatable {
    var easy: Int
    var hard: Int
    var total: Int { easy + hard }
    /// Share of easy runs (0...1). Coaches suggest about 80% easy, 20% hard.
    var easyShare: Double { total == 0 ? 0 : Double(easy) / Double(total) }
    var isBalanced: Bool { total == 0 || easyShare >= 0.7 }
}

/// Pure functions over the run history (easy to unit test).
enum TrainingStats {
    static func weekStart(of date: Date, calendar: Calendar) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    /// Kilometres per week for the last `weeks` weeks, oldest first (empty weeks included).
    static func weeklyDistance(_ runs: [Run], weeks: Int = 8, now: Date = .now,
                               calendar: Calendar = .current) -> [WeeklyDistance] {
        let thisWeek = weekStart(of: now, calendar: calendar)
        return (0..<weeks).reversed().compactMap { offset -> WeeklyDistance? in
            guard let start = calendar.date(byAdding: .weekOfYear, value: -offset, to: thisWeek),
                  let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start) else { return nil }
            let inWeek = runs.filter { $0.date >= start && $0.date < end }
            return WeeklyDistance(weekStart: start,
                                  kilometres: inWeek.map(\.distanceKm).reduce(0, +),
                                  runs: inWeek.count)
        }
    }

    static func thisWeek(_ runs: [Run], now: Date = .now, calendar: Calendar = .current) -> WeeklyDistance {
        weeklyDistance(runs, weeks: 1, now: now, calendar: calendar).first
            ?? WeeklyDistance(weekStart: now, kilometres: 0, runs: 0)
    }

    /// Easy vs hard runs in the last `days` days. Long and recovery runs count as easy.
    static func intensityBalance(_ runs: [Run], days: Int = 14, now: Date = .now) -> IntensityBalance {
        let recent = runs.filter { isWithin(days: days, of: now, $0.date) }
        let hard = recent.filter { $0.analysis.runType.isHard }.count
        return IntensityBalance(easy: recent.count - hard, hard: hard)
    }

    /// How many runs of each type in the last `days` days (types with 0 runs left out).
    static func typeMix(_ runs: [Run], days: Int = 14, now: Date = .now) -> [TypeCount] {
        let recent = runs.filter { isWithin(days: days, of: now, $0.date) }
        return RunType.allCases
            .map { type in TypeCount(type: type, count: recent.filter { $0.analysis.runType == type }.count) }
            .filter { $0.count > 0 }
    }

    static func painMentions(_ runs: [Run], days: Int = 7, now: Date = .now) -> Int {
        runs.filter { isWithin(days: days, of: now, $0.date) && $0.analysis.painMentioned }.count
    }

    /// Median pace (seconds per km) of the runner's previous runs before `date` (last 10 runs).
    static func usualPace(before date: Date, in runs: [Run], excluding id: UUID? = nil) -> Double? {
        let previous = runs
            .filter { $0.date < date && $0.id != id }
            .sorted { $0.date > $1.date }
            .prefix(10)
            .map(\.paceSecondsPerKm)
            .sorted()
        guard !previous.isEmpty else { return nil }
        let mid = previous.count / 2
        return previous.count.isMultiple(of: 2) ? (previous[mid - 1] + previous[mid]) / 2 : previous[mid]
    }

    /// Change in distance from last week to this week (e.g. 0.25 = +25%). nil if last week was empty.
    static func weeklyChange(_ runs: [Run], now: Date = .now, calendar: Calendar = .current) -> Double? {
        let weeks = weeklyDistance(runs, weeks: 2, now: now, calendar: calendar)
        guard weeks.count == 2, weeks[0].kilometres > 0 else { return nil }
        return (weeks[1].kilometres - weeks[0].kilometres) / weeks[0].kilometres
    }

    private static func isWithin(days: Int, of now: Date, _ date: Date) -> Bool {
        date <= now && now.timeIntervalSince(date) < Double(days) * 86_400
    }
}
