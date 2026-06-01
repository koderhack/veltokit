import Combine
import Foundation
import VeltoKit

/// Globalna nawigacja UI: dotyk = natychmiast; Triki = obrót + hold lub przycisk.
@MainActor
final class TrikiUINavigator: ObservableObject {
  /// `nil` = żadna opcja nie jest podświetlona (strefa neutralna Triki).
  @Published private(set) var focusIndex: Int?
  @Published private(set) var holdProgress: Double = 0
  @Published private(set) var isConfigured = false
  @Published var isSuspended = false

  private var itemCount = 0
  private var onActivate: ((Int) -> Void)?
  private var holdTracker = TrikiHoldTracker()
  private var focusSettleRemaining: TimeInterval = 0
  private var neutralGraceRemaining: TimeInterval = 0
  private var lastTimestamp: TimeInterval?

  func configure(itemCount: Int, onActivate: @escaping (Int) -> Void) {
    self.itemCount = max(1, itemCount)
    self.onActivate = onActivate
    if let focusIndex, focusIndex >= self.itemCount {
      self.focusIndex = nil
    }
    isConfigured = true
    holdTracker.reset()
    focusSettleRemaining = 0
    neutralGraceRemaining = 0
    holdProgress = 0
  }

  func clear() {
    isConfigured = false
    itemCount = 0
    onActivate = nil
    focusIndex = nil
    holdTracker.reset()
    focusSettleRemaining = 0
    neutralGraceRemaining = 0
    holdProgress = 0
  }

  /// Dotyk: natychmiastowa akcja (bez hold).
  func activate(at index: Int) {
    guard isConfigured, !isSuspended, (0 ..< itemCount).contains(index) else { return }
    focusIndex = index
    holdTracker.reset()
    holdProgress = 0
    focusSettleRemaining = TrikiUIConfig.focusSettleDuration
    neutralGraceRemaining = 0
    QuizSFX.menuConfirm()
    onActivate?(index)
  }

  func clearFocus() {
    focusIndex = nil
    focusSettleRemaining = 0
    neutralGraceRemaining = 0
    holdTracker.reset()
    holdProgress = 0
  }

  func tick(motion: MotionInputProvider, now: TimeInterval) {
    guard isConfigured, !isSuspended, itemCount > 0 else { return }

    let deltaTime: TimeInterval
    if let lastTimestamp {
      deltaTime = max(0, min(1.0 / 30.0, now - lastTimestamp))
    } else {
      deltaTime = 1.0 / 60.0
    }
    lastTimestamp = now

    guard motion.isTrikiControlAvailable else {
      holdTracker.reset()
      holdProgress = 0
      return
    }

    let input = motion.pollInput(deltaTime: deltaTime)

    guard let index = TrikiUIMath.focusedSlot(
      posX: input.posX,
      slots: itemCount,
      currentFocus: focusIndex
    ) else {
      if focusIndex != nil {
        if neutralGraceRemaining <= 0 {
          neutralGraceRemaining = TrikiUIConfig.focusLossGraceDuration
        }
        neutralGraceRemaining -= deltaTime
        if neutralGraceRemaining <= 0 {
          clearFocus()
        } else {
          holdTracker.reset()
          holdProgress = 0
        }
      }
      return
    }

    neutralGraceRemaining = 0

    if index != focusIndex {
      QuizSFX.menuFocus()
      focusIndex = index
      focusSettleRemaining = TrikiUIConfig.focusSettleDuration
      holdTracker.reset()
      holdProgress = 0
      return
    }

    focusSettleRemaining = max(0, focusSettleRemaining - deltaTime)
    guard focusSettleRemaining <= 0 else {
      holdProgress = 0
      return
    }

    if input.primaryAction {
      holdProgress = 0
      holdTracker.reset()
      QuizSFX.menuConfirm()
      onActivate?(index)
      focusSettleRemaining = TrikiUIConfig.focusSettleDuration
      return
    }

    if holdTracker.advance(deltaTime: deltaTime, duration: TrikiUIConfig.menuHoldDuration) {
      holdProgress = 0
      QuizSFX.menuConfirm()
      onActivate?(index)
      holdTracker.reset()
      focusSettleRemaining = TrikiUIConfig.focusSettleDuration
    } else {
      holdProgress = holdTracker.progress
    }
  }

  func resetClock() {
    lastTimestamp = nil
  }
}
