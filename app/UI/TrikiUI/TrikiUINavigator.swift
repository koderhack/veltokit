import Combine
import Foundation
import VeltoKit

/// Runtime navigator that translates Triki motion into focused menu intent.
///
/// This file hosts the core tick-based navigation loop used by `.trikiUIScreen` and related
/// components to keep focus, hold, and activation state synchronized.

/// Coordinates Triki-driven focus and activation flow for menu-like screens.
///
/// Use this navigator when a screen should support both touch-first navigation and
/// motion-based focus with hold/button confirmation.
@MainActor
/// Zarządza cyklem focus/hold/activate dla ekranów opartych o Triki.
final class TrikiUINavigator: ObservableObject {
  /// Focused item index, or `nil` when pointer is in neutral zone.
  @Published private(set) var focusIndex: Int?
  /// Current hold-to-activate progress for the focused item (`0...1`).
  @Published private(set) var holdProgress: Double = 0
  /// Indicates whether navigator has active configuration for current screen.
  @Published private(set) var isConfigured = false
  /// Temporarily pauses motion-driven updates while preserving setup.
  @Published var isSuspended = false

  private var itemCount = 0
  private var onActivate: ((Int) -> Void)?
  private var holdTracker = TrikiHoldTracker()
  private var focusGate = TrikiFocusGate()
  private var confirmGate = TrikiButtonConfirmGate()
  private var preferButtonConfirm = false
  private var focusSettleRemaining: TimeInterval = 0
  private var neutralGraceRemaining: TimeInterval = 0
  private var lastTimestamp: TimeInterval?

  /// Configures the navigator for a screen with a fixed item count.
  ///
  /// - Parameters:
  ///   - itemCount: Number of focusable items on the target screen.
  ///   - preferButtonConfirm: When true, only the BLE button confirms (no hold auto-activate).
  ///   - onActivate: Callback executed when user confirms focused item.
  func configure(
    itemCount: Int,
    preferButtonConfirm: Bool = false,
    onActivate: @escaping (Int) -> Void
  ) {
    self.itemCount = max(1, itemCount)
    self.preferButtonConfirm = preferButtonConfirm
    self.onActivate = onActivate
    if let focusIndex, focusIndex >= self.itemCount {
      self.focusIndex = nil
    }
    isConfigured = true
    holdTracker.reset()
    focusGate.reset()
    confirmGate.reset()
    focusSettleRemaining = 0
    neutralGraceRemaining = 0
    holdProgress = 0
  }

  /// Clears configuration and resets focus/hold state.
  func clear() {
    isConfigured = false
    itemCount = 0
    onActivate = nil
    focusIndex = nil
    holdTracker.reset()
    focusGate.reset()
    confirmGate.reset()
    preferButtonConfirm = false
    focusSettleRemaining = 0
    neutralGraceRemaining = 0
    holdProgress = 0
  }

  /// Activates an item immediately, typically for touch interaction.
  ///
  /// - Parameter index: Target item index to activate.
  /// - Side Effects: Emits menu confirm sound and resets hold/focus settle windows.
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

  /// Removes current focus and clears hold progress.
  func clearFocus() {
    focusIndex = nil
    focusSettleRemaining = 0
    neutralGraceRemaining = 0
    holdTracker.reset()
    holdProgress = 0
  }

  /// Advances navigation state for a single frame.
  ///
  /// - Parameters:
  ///   - motion: Motion input provider used to sample Triki controls.
  ///   - now: Current timestamp in seconds.
  /// - Side Effects: Updates published focus/progress values and may trigger `onActivate`.
  ///
  /// Example:
  /// `navigator.tick(motion: motionProvider, now: CACurrentMediaTime())`
  func tick(motion: MotionInputProvider, now: TimeInterval) {
    guard isConfigured, !isSuspended, itemCount > 0 else { return }

    let deltaTime: TimeInterval
    if let lastTimestamp {
      deltaTime = max(0, min(1.0 / 30.0, now - lastTimestamp))
    } else {
      deltaTime = 1.0 / 60.0
    }
    lastTimestamp = now

    let input = motion.pollInput(deltaTime: deltaTime)

    guard motion.isTrikiControlAvailable else {
      holdTracker.reset()
      holdProgress = 0
      return
    }

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

    let resolved = focusGate.resolve(
      rawIndex: index,
      current: focusIndex,
      deltaTime: deltaTime,
      adjacentDwell: TrikiUIConfig.focusSwitchDurationAdjacent,
      jumpDwell: TrikiUIConfig.focusSwitchDuration
    ) ?? index

    if resolved != focusIndex {
      QuizSFX.menuFocus()
      focusIndex = resolved
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

    if confirmGate.consume(input: input, deltaTime: deltaTime) {
      holdProgress = 0
      holdTracker.reset()
      QuizSFX.menuConfirm()
      onActivate?(resolved)
      focusSettleRemaining = TrikiUIConfig.focusSettleDuration
      return
    }

    guard !preferButtonConfirm else {
      holdProgress = 0
      return
    }

    if holdTracker.advance(deltaTime: deltaTime, duration: TrikiUIConfig.menuHoldDuration) {
      holdProgress = 0
      QuizSFX.menuConfirm()
      onActivate?(resolved)
      holdTracker.reset()
      focusSettleRemaining = TrikiUIConfig.focusSettleDuration
    } else {
      holdProgress = holdTracker.progress
    }
  }

  /// Resets internal time reference used for frame delta calculations.
  func resetClock() {
    lastTimestamp = nil
  }
}
