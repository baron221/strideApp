import SwiftUI

extension RunType {
    var color: Color {
        switch self {
        case .recovery: .mint
        case .easy: .green
        case .long: .blue
        case .tempo: .orange
        case .intervals: .red
        }
    }
}

extension Mood {
    var color: Color {
        switch self {
        case .positive: .orange
        case .neutral: .gray
        case .negative: .indigo
        }
    }
}

/// Coloured capsule with the run type's symbol and name.
struct RunTypeBadge: View {
    let type: RunType
    var large = false

    var body: some View {
        Label(type.title, systemImage: type.symbol)
            .font(large ? .title3.bold() : .subheadline.weight(.semibold))
            .padding(.horizontal, large ? 14 : 10)
            .padding(.vertical, large ? 8 : 5)
            .foregroundStyle(type.color)
            .background(type.color.opacity(0.15), in: Capsule())
            .accessibilityLabel("Run type: \(type.rawValue)")
    }
}

/// One bar per run type showing how sure the Core ML model is.
struct ProbabilityBars: View {
    let probabilities: [RunType: Double]

    private var sortedTypes: [RunType] {
        RunType.allCases.sorted { (probabilities[$0] ?? 0) > (probabilities[$1] ?? 0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(sortedTypes) { type in
                let probability = probabilities[type] ?? 0
                HStack(spacing: 8) {
                    Label(type.rawValue, systemImage: type.symbol)
                        .font(.caption)
                        .foregroundStyle(type.color)
                        .frame(width: 100, alignment: .leading)
                    ProgressView(value: probability)
                        .tint(type.color)
                    Text(Format.percent(probability))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 42, alignment: .trailing)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(type.rawValue): \(Format.percent(probability))")
            }
        }
    }
}

/// Title row used at the top of each Insights card.
struct CardHeader: View {
    let title: String
    let symbol: String
    var subtitle: String?

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(Color.accentColor)
                .frame(width: 32, height: 32)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

extension View {
    func card() -> some View { modifier(CardStyle()) }
}
