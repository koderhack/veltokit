import Foundation

/// Limity i pomocniki rosteru graczy (501, na zmianę).
enum DartPlayers {
  static let minCount = 1
  static let maxCount = 8
  static let startingScore = 501

  static func defaultName(index: Int) -> String {
    "Gracz \(index + 1)"
  }

  static func clampCount(_ count: Int) -> Int {
    min(maxCount, max(minCount, count))
  }

  static func normalizedNames(_ names: [String], count: Int) -> [String] {
    let n = clampCount(count)
    var list = names.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    while list.count < n {
      list.append(defaultName(index: list.count))
    }
    if list.count > n {
      list = Array(list.prefix(n))
    }
    for i in list.indices where list[i].isEmpty {
      list[i] = defaultName(index: i)
    }
    return list
  }

  static func freshScores(count: Int) -> [Int] {
    Array(repeating: startingScore, count: clampCount(count))
  }
}
