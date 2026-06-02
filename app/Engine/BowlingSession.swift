import Combine
import Foundation

/// Reprezentuje typ `BowlingPlayMode`.
enum BowlingPlayMode: String, CaseIterable, Identifiable {
  case solo
  case duo
  case trio
  case quad

/// Przechowuje wartosc `id`.
  var id: String { rawValue }

/// Przechowuje wartosc `title`.
  var title: String {
    switch self {
    case .solo: return "1 gracz"
    case .duo: return "2 graczy"
    case .trio: return "3 graczy"
    case .quad: return "4 graczy"
    }
  }

/// Przechowuje wartosc `playerCount`.
  var playerCount: Int {
    switch self {
    case .solo: return 1
    case .duo: return 2
    case .trio: return 3
    case .quad: return 4
    }
  }
}

/// Reprezentuje typ `BowlingSession`.
final class BowlingSession: ObservableObject {
  @Published var mode: BowlingPlayMode = .solo
  @Published var player1Name = "Gracz 1"
  @Published var player2Name = "Gracz 2"
  @Published var player3Name = "Gracz 3"
  @Published var player4Name = "Gracz 4"

/// Przechowuje wartosc `playerNames`.
  var playerNames: [String] {
    switch mode {
    case .solo: return [player1Name]
    case .duo: return [player1Name, player2Name]
    case .trio: return [player1Name, player2Name, player3Name]
    case .quad: return [player1Name, player2Name, player3Name, player4Name]
    }
  }

/// Wykonuje operacje `cycleMode`.
  func cycleMode() {
    let all = BowlingPlayMode.allCases
    guard let idx = all.firstIndex(of: mode) else { return }
    mode = all[(idx + 1) % all.count]
  }
}
