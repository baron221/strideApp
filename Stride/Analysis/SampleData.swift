import Foundation

/// Six weeks of realistic runs for the user story "Dilnoza trains for her first 10K".
/// At first she runs almost every run hard (a common beginner mistake); in the last two weeks
/// she mentions knee pain. This lets the demo show every AI feature straight away.
enum SampleData {
    struct Template {
        var daysAgo: Int
        var hour: Int
        var km: Double
        var minutes: Double
        var heartRate: Int?
        var effort: Int
        var note: String
    }

    static let templates: [Template] = [
        Template(daysAgo: 41, hour: 7, km: 4.0, minutes: 27.5, heartRate: 168, effort: 7, note: "First run of my 10K plan! Hard but I loved it."),
        Template(daysAgo: 39, hour: 18, km: 5.0, minutes: 32.5, heartRate: 168, effort: 7, note: "Tried to beat my pace. Legs are tired."),
        Template(daysAgo: 36, hour: 7, km: 6.5, minutes: 47.0, heartRate: 150, effort: 5, note: "Easy run with my friend Madina, nice chat."),
        Template(daysAgo: 34, hour: 18, km: 5.0, minutes: 32.0, heartRate: 176, effort: 9, note: "6 x 400 m at the stadium. Exhausting!"),
        Template(daysAgo: 32, hour: 8, km: 10.0, minutes: 74.0, heartRate: 152, effort: 6, note: "Longest run so far. Very proud."),
        Template(daysAgo: 29, hour: 18, km: 5.2, minutes: 33.0, heartRate: 169, effort: 7, note: "Pushed hard again. Not much fun today."),
        Template(daysAgo: 27, hour: 7, km: 6.0, minutes: 37.5, heartRate: 168, effort: 7, note: "Tempo along Ankhor canal. Felt strong."),
        Template(daysAgo: 25, hour: 18, km: 5.0, minutes: 31.0, heartRate: 178, effort: 9, note: "Hill repeats. I feel completely drained."),
        Template(daysAgo: 22, hour: 8, km: 11.0, minutes: 79.0, heartRate: 154, effort: 6, note: "Long run in the park, beautiful morning."),
        Template(daysAgo: 20, hour: 18, km: 6.0, minutes: 37.5, heartRate: 167, effort: 7, note: "Fast run after lectures, so stressful week."),
        Template(daysAgo: 18, hour: 7, km: 5.0, minutes: 37.0, heartRate: 140, effort: 3, note: "Slow recovery jog. Relaxed and happy."),
        Template(daysAgo: 15, hour: 18, km: 7.0, minutes: 43.5, heartRate: 168, effort: 7, note: "Tempo run. My right knee feels a bit sore."),
        Template(daysAgo: 13, hour: 8, km: 12.5, minutes: 91.0, heartRate: 156, effort: 6, note: "Long run done, but my knee started to ache."),
        Template(daysAgo: 11, hour: 18, km: 5.0, minutes: 30.5, heartRate: 180, effort: 9, note: "Intervals 5 x 800 m. Painful knee at the end."),
        Template(daysAgo: 8, hour: 7, km: 5.5, minutes: 39.0, heartRate: 148, effort: 4, note: "Easy run, no pain at all today. Great!"),
        Template(daysAgo: 6, hour: 18, km: 6.5, minutes: 40.5, heartRate: 167, effort: 7, note: "Tempo again. Knee hurts a little on the stairs."),
        Template(daysAgo: 4, hour: 8, km: 8.0, minutes: 58.0, heartRate: 150, effort: 5, note: "Easy run with music. Lovely weather."),
        Template(daysAgo: 2, hour: 18, km: 5.0, minutes: 31.0, heartRate: 179, effort: 9, note: "Speed session, tired and frustrated."),
        Template(daysAgo: 1, hour: 7, km: 4.0, minutes: 30.0, heartRate: nil, effort: 3, note: "Short easy jog, forgot my heart-rate strap."),
    ]

    static func entries(now: Date = .now, calendar: Calendar = .current) -> [RunEntry] {
        templates.compactMap { t in
            guard let day = calendar.date(byAdding: .day, value: -t.daysAgo, to: calendar.startOfDay(for: now)),
                  let date = calendar.date(byAdding: .hour, value: t.hour, to: day) else { return nil }
            return RunEntry(date: date, distanceKm: t.km, durationSeconds: t.minutes * 60,
                            averageHeartRate: t.heartRate, effort: t.effort, note: t.note)
        }
    }
}
