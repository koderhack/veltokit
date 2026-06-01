import CoreGraphics
import Foundation

enum TrikiUIConfig {
  /// Hold w menu i listach (sekundy).
  static let menuHoldDuration: TimeInterval = 2.25
  /// Hold przy zatwierdzaniu odpowiedzi w quizie.
  static let quizHoldDuration: TimeInterval = 2.0
  /// Po zmianie fokusu — chwila bez narastania hold (anty-przypadkowe OK).
  static let focusSettleDuration: TimeInterval = 0.45
  /// Krótki debounce przy skoku o więcej niż 1 opcję.
  static let focusSwitchDuration: TimeInterval = 0.14
  /// Sąsiednia opcja (±1) — prawie od razu.
  static let focusSwitchDurationAdjacent: TimeInterval = 0.06
  /// |posX| poniżej progu = brak wyboru przy szukaniu opcji.
  static let neutralEnterBand: Double = 0.24
  /// Węższa strefa środka — fokus znika dopiero bliżej wyprostowania Triki.
  static let neutralExitBand: Double = 0.10
  /// Krótki bufor zanim fokus zgaśnie po wejściu w strefę neutralną.
  static let focusLossGraceDuration: TimeInterval = 0.35
  /// Dolny margines treści pod paskiem Triki (żeby nie ucinało wierszy).
  static let bottomContentInset: CGFloat = 88
}
