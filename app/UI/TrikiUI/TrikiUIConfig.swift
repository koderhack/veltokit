import CoreGraphics
import Foundation

/// Centralized constants for Triki UI timing and spacing.
///
/// Purpose: keep hold/focus behavior and HUD layout coherent across screens.
/// Use when: a Triki-enabled view needs thresholds or animation-like timing values.
/// Example: `TrikiUIConfig.menuHoldDuration` controls hold-to-confirm length.
enum TrikiUIConfig {
  /// Hold w menu i listach (sekundy).
  static let menuHoldDuration: TimeInterval = 2.25
  /// Hold przy zatwierdzaniu odpowiedzi w quizie.
  static let quizHoldDuration: TimeInterval = 2.0
  /// Po zmianie fokusu — chwila bez narastania hold (anty-przypadkowe OK).
  static let focusSettleDuration: TimeInterval = 0.45
  /// Po wejściu na ekran z `preferButtonConfirm` — ignoruj przycisk BLE (stary impuls / latch).
  static let menuConfirmArmDuration: TimeInterval = 1.0
  /// Krótki debounce przy skoku o więcej niż 1 opcję.
  static let focusSwitchDuration: TimeInterval = 0.32
  /// Sąsiednia opcja (±1) — z krótkim oczekiwaniem (mniej „latania”).
  static let focusSwitchDurationAdjacent: TimeInterval = 0.20
  /// |posX| poniżej progu = brak wyboru przy szukaniu opcji.
  static let neutralEnterBand: Double = 0.30
  /// Węższa strefa środka — fokus znika dopiero bliżej wyprostowania Triki.
  static let neutralExitBand: Double = 0.14
  /// Krótki bufor zanim fokus zgaśnie po wejściu w strefę neutralną.
  static let focusLossGraceDuration: TimeInterval = 0.35

  // Quiz — wolniejszy fokus, mniej „latania” między A–D
  static let quizNeutralEnterBand: Double = 0.34
  static let quizNeutralExitBand: Double = 0.18
  static let quizPosXSmoothing: Double = 0.74
  static let quizFocusSwitchAdjacent: TimeInterval = 0.28
  static let quizFocusSwitchJump: TimeInterval = 0.42

  /// Dolny margines treści pod paskiem Triki (żeby nie ucinało wierszy).
  static let bottomContentInset: CGFloat = 88
}
