import Combine
import Foundation
import SwiftUI

/// Limity rosteru imprezowego bowlingu.
enum BowlingRoster {
  static let minPlayers = 1
  static let maxPlayers = 20
}

/// Sesja lobby — liczba graczy 1…20 i lista nicków.
final class BowlingSession: ObservableObject {
  @Published var playerCount: Int = 4 {
    didSet {
      let clamped = min(BowlingRoster.maxPlayers, max(BowlingRoster.minPlayers, playerCount))
      if clamped != playerCount { playerCount = clamped; return }
      ensureRosterSize()
    }
  }

  @Published var roster: [String] = (1...4).map { "Gracz \($0)" }

  var playerNames: [String] {
    ensureRosterSize()
    return roster.prefix(playerCount).map { name in
      let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
      return trimmed.isEmpty ? "Gracz" : trimmed
    }
  }

  var partySummary: String {
    let n = playerCount
    switch n {
    case 1: return "1 gracz"
    default: return "\(n) graczy"
    }
  }

  init() {
    ensureRosterSize()
  }

  func incrementPlayers() {
    playerCount = min(BowlingRoster.maxPlayers, playerCount + 1)
  }

  func decrementPlayers() {
    playerCount = max(BowlingRoster.minPlayers, playerCount - 1)
  }

  func bindingName(at index: Int) -> Binding<String> {
    Binding(
      get: {
        self.ensureRosterSize()
        guard self.roster.indices.contains(index) else { return "" }
        return self.roster[index]
      },
      set: { newValue in
        self.ensureRosterSize()
        guard self.roster.indices.contains(index) else { return }
        self.roster[index] = newValue
      }
    )
  }

  private func ensureRosterSize() {
    while roster.count < BowlingRoster.maxPlayers {
      roster.append("Gracz \(roster.count + 1)")
    }
  }
}
