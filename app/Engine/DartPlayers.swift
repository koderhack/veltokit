import Foundation

/// Limity i pomocniki rosteru graczy (501, na zmianę).
enum DartPlayers {
/// Przechowuje wartosc `minCount`.
  static let minCount = 1
/// Przechowuje wartosc `maxCount`.
  static let maxCount = 8
/// Przechowuje wartosc `startingScore`.
  static let startingScore = 501

/// Wykonuje operacje `defaultName`.
  static func defaultName(index: Int) -> String {
    "Gracz \(index + 1)"
  }

/// Wykonuje operacje `clampCount`.
  static func clampCount(_ count: Int) -> Int {
    min(maxCount, max(minCount, count))
  }

/// Wykonuje operacje `normalizedNames`.
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

/// Wykonuje operacje `freshScores`.
  static func freshScores(count: Int) -> [Int] {
    Array(repeating: startingScore, count: clampCount(count))
  }
}
