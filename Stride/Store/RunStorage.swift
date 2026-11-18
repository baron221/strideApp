import Foundation

/// Saves and loads the whole history as a human-readable JSON file (Codable).
struct RunStorage {
    let fileURL: URL

    init(fileURL: URL = URL.documentsDirectory.appending(path: "stride-runs.json")) {
        self.fileURL = fileURL
    }

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// Returns nil when there is no saved file yet (first launch).
    func load() throws -> StrideData? {
        guard FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)) else { return nil }
        let data = try Data(contentsOf: fileURL)
        return try Self.makeDecoder().decode(StrideData.self, from: data)
    }

    func save(_ value: StrideData) throws {
        let data = try Self.makeEncoder().encode(value)
        try data.write(to: fileURL, options: [.atomic])
    }
}
