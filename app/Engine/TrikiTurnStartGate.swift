import Foundation
import VeltoKit

/// Multiplayer: nowy gracz musi nacisnąć przycisk Triki, żeby rozpocząć turę.
struct TrikiTurnStartGate: Equatable {
  private(set) var confirmedPlayerIndex: Int?

/// Wykonuje operacje `reset`.
  mutating func reset() {
    confirmedPlayerIndex = nil
  }

/// Wykonuje operacje `needsConfirm`.
  func needsConfirm(playerIndex: Int, playerCount: Int) -> Bool {
    guard playerCount > 1 else { return false }
    return confirmedPlayerIndex != playerIndex
  }

/// Wykonuje operacje `confirm`.
  mutating func confirm(playerIndex: Int) {
    confirmedPlayerIndex = playerIndex
  }
}

/// Rozszerza istniejacy typ o dodatkowe zachowanie.
extension GameInput {
  /// Impuls z fizycznego przycisku Triki (BLE bytes[1]).
  var trikiButtonPressed: Bool {
    sensors.click || primaryAction
  }
}
