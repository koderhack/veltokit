import Foundation

// MARK: - Use case → MotionMode

/// Four integration patterns — pick one, call `MotionSDK.configure(for:)`, then `pollInput`.
public enum TrikiUseCase: Sendable, Equatable {
  /// Pong — horizontal paddle (`posX`).
  case pong
  /// Menus, quiz, category pick — slots + BLE button confirm.
  case menu
  /// Dart — 2D aim + throw (`posX`, `posY`, `shotTriggered`).
  case pointerGame
  /// Bowling — lateral aim + pull-back throw (`shotTriggered`, `throwPower`).
  case gestureGame
}

extension MotionSDK {
  /// Applies `MotionMode` + default `MotionConfig` preset for a use case.
  public func configure(for useCase: TrikiUseCase) {
    switch useCase {
    case .pong, .menu:
      setMode(.paddle)
      config = MotionConfig.preset(for: .paddle)
    case .pointerGame:
      setMode(.pointer)
      config = MotionConfig.preset(for: .pointer)
    case .gestureGame:
      setMode(.gesture)
      config = MotionConfig.preset(for: .gesture)
    }
  }

  /// Shortcut: `.paddle` preset for Pong.
  public func configureForPong() { configure(for: .pong) }

  /// Shortcut: `.paddle` preset for UI / quiz menus.
  public func configureForMenu() { configure(for: .menu) }

  /// Shortcut: `.pointer` preset (Dart).
  public func configureForPointerGame() { configure(for: .pointerGame) }

  /// Shortcut: `.gesture` preset (Bowling).
  public func configureForGestureGame() { configure(for: .gestureGame) }
}

// MARK: - BLE button (bytes[1])

/// Rising-edge gate on `GameInput.bleButtonClick` with post-confirm cooldown.
///
/// Use for menu OK, quiz answers, bowling turn start — never raw `sensors.click`.
public struct TrikiButtonGate: Sendable {
  public static let defaultCooldown: TimeInterval = 0.65

  private var lastRaw = false
  private var cooldown: TimeInterval = 0
  public var postConfirmCooldown: TimeInterval

  public init(postConfirmCooldown: TimeInterval = TrikiButtonGate.defaultCooldown) {
    self.postConfirmCooldown = postConfirmCooldown
  }

  public mutating func reset() {
    lastRaw = false
    cooldown = 0
  }

  /// Po wejściu na ekran — ustaw na bieżący stan przycisku (bez zbocza).
  public mutating func syncPressedState(_ pressed: Bool) {
    lastRaw = pressed
  }

  /// `true` on the first frame of a physical button press after cooldown.
  public mutating func consume(input: GameInput, deltaTime: TimeInterval) -> Bool {
    cooldown = max(0, cooldown - deltaTime)
    let raw = input.bleButtonClick
    let edge = raw && !lastRaw
    lastRaw = raw
    guard edge, cooldown <= 0 else { return false }
    cooldown = postConfirmCooldown
    return true
  }
}

// MARK: - Recipe 1: Pong

/// Minimal Pong steering — wraps `TrikiPaddleDriver`.
public struct TrikiSimplePong: Sendable {
  private var driver = TrikiPaddleDriver()

  public init() {}

  public mutating func reset() { driver.reset() }

  /// Returns new paddle X in screen pixels (clamp to court bounds in your game).
  public mutating func paddleX(
    current: Double,
    input: GameInput,
    deltaTime: TimeInterval,
    courtWidth: Double
  ) -> Double {
    driver.steer(
      current: current,
      input: input,
      deltaTime: deltaTime,
      courtCenter: courtWidth / 2
    )
  }
}

// MARK: - Recipe 2: UI / menu

/// Focus index + BLE confirm in one helper (quiz rows, lobby menus).
public struct TrikiUIPicker: Sendable {
  private var menu = TrikiMenuDriver()
  private var button = TrikiButtonGate()
  public private(set) var focusIndex: Int = 0

  public init(initialFocus: Int = 0) {
    focusIndex = max(0, initialFocus)
  }

  public mutating func reset(focus: Int = 0) {
    focusIndex = max(0, focus)
    menu.reset()
    button.reset()
  }

  /// Updates focus from tilt / `posX`. Returns `true` when user confirmed with the cap button.
  public mutating func tick(
    input: GameInput,
    deltaTime: TimeInterval,
    slots: Int
  ) -> Bool {
    guard slots > 0 else { return false }
    let step = menu.step(
      input: input,
      deltaTime: deltaTime,
      slots: slots,
      currentSelection: focusIndex
    )
    if let slot = step.slotFromPosition {
      focusIndex = min(slots - 1, max(0, slot))
    } else if step.nudge != 0 {
      focusIndex = min(slots - 1, max(0, focusIndex + step.nudge))
    }
    return button.consume(input: input, deltaTime: deltaTime)
  }
}

// MARK: - Recipe 3: Pointer / gesture games

/// Events from Dart / Bowling style gameplay (throw + optional button).
public enum TrikiGameEvent: Sendable, Equatable {
  case primedToThrow
  case threw(power: Double)
  case buttonConfirmed
}

/// Watches throw gestures and BLE button in pointer / gesture modes.
public struct TrikiGameActions: Sendable {
  private var button = TrikiButtonGate()
  private var wasPrimed = false

  public init() {}

  public mutating func reset() {
    button.reset()
    wasPrimed = false
  }

  /// Collect events for this frame (may be empty).
  public mutating func tick(input: GameInput, deltaTime: TimeInterval) -> [TrikiGameEvent] {
    var events: [TrikiGameEvent] = []
    if input.gesturePrimed, !wasPrimed {
      events.append(.primedToThrow)
    }
    wasPrimed = input.gesturePrimed
    if input.shotTriggered {
      events.append(.threw(power: input.throwPower))
    }
    if button.consume(input: input, deltaTime: deltaTime) {
      events.append(.buttonConfirmed)
    }
    return events
  }
}

/// 2D aim helper for pointer games (Dart).
public struct TrikiSimplePointer: Sendable {
  private var driver = TrikiPointerDriver()

  public init() {}

  public mutating func reset() { driver.reset() }

  /// Returns updated aim in game coordinates (clamp 0…1 in your renderer).
  public mutating func aim(
    currentX: Double,
    currentY: Double,
    input: GameInput,
    deltaTime: TimeInterval
  ) -> (x: Double, y: Double) {
    driver.step(
      aimX: currentX,
      aimY: currentY,
      input: input,
      rawTargetX: input.posX,
      rawTargetY: input.posY,
      deltaTime: deltaTime
    )
  }
}

/// Lateral aim (−1…1) for gesture games (Bowling lane).
public struct TrikiSimpleAim: Sendable {
  private var driver = TrikiLateralDriver()
  public var lockedX: Double = 0

  public init() {}

  public mutating func reset() {
    driver.reset()
    lockedX = 0
  }

  /// `lean` — typically `input.sensors.tiltY` or your grip mapping delta.
  public mutating func step(
    current: Double,
    lean: Double,
    input: GameInput,
    deltaTime: TimeInterval,
    invert: Bool = false
  ) -> Double {
    let result = driver.step(
      current: current,
      locked: lockedX,
      lean: lean,
      input: input,
      deltaTime: deltaTime,
      invert: invert
    )
    lockedX = result.locked
    return result.aim
  }
}
