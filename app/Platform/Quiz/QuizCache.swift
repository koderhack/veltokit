import Foundation

private struct QuizCachePayload: Codable {
/// Przechowuje wartosc `schemaVersion`.
  static let schemaVersion = 1
/// Przechowuje wartosc `version`.
  var version: Int
/// Przechowuje wartosc `savedAt`.
  var savedAt: Date
/// Przechowuje wartosc `questions`.
  var questions: [Question]
}

/// Cache przetłumaczonych pytań (plik JSON w Application Support).
enum QuizCache {
  private static let fileName = "quiz_translated_pl.json"
  private static let expectedCount = 100

/// Wykonuje operacje `load`.
  static func load() -> [Question]? {
    let url = cacheFileURL()
    guard let data = try? Data(contentsOf: url) else { return nil }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    guard let payload = try? decoder.decode(QuizCachePayload.self, from: data),
          payload.version == QuizCachePayload.schemaVersion,
          payload.questions.count >= expectedCount else { return nil }
    return Array(payload.questions.prefix(expectedCount))
  }

/// Wykonuje operacje `save`.
  static func save(_ questions: [Question]) throws {
    guard questions.count >= expectedCount else { return }
    let url = cacheFileURL()
    let dir = url.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let payload = QuizCachePayload(
      version: QuizCachePayload.schemaVersion,
      savedAt: Date(),
      questions: Array(questions.prefix(expectedCount))
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    try encoder.encode(payload).write(to: url, options: .atomic)
  }

/// Wykonuje operacje `clear`.
  static func clear() {
    try? FileManager.default.removeItem(at: cacheFileURL())
  }

  private static func cacheFileURL() -> URL {
    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    return base.appendingPathComponent(fileName, isDirectory: false)
  }
}
