import Foundation

/// Strategia mapowania wejścia Triki — zależy od wykrytego trybu BLE notify.
public enum TrikiInputStrategy: Sendable, Equatable {
  /// ~100 Hz — prędkość / Δpos dominują (joystick-like).
  case velocity
  /// ~20–30 Hz filtrowane — hybrid Δ + tilt hold.
  case hybrid
  /// ~5–10 Hz — krawędzie pochylenia + debounce (gesture controller).
  case threshold
}

extension TrikiBLEMode {
  /// Rekomendowana strategia sterowania dla gier i menu.
  public var inputStrategy: TrikiInputStrategy {
    switch self {
    case .fast: return .velocity
    case .normal: return .hybrid
    case .lowPower: return .threshold
    case .unknown: return .hybrid
    }
  }
}

// MARK: - Slot math (menu / quiz)

/// Mapowanie `posX` na sloty menu — w VeltoKit, bez zależności od UI aplikacji.
public enum TrikiSlotMath {
  /// Indeks slotu 0…(slots−1) z pozycji poziomej (−1…1).
  public static func slotIndex(posX: Double, slots: Int) -> Int {
    guard slots > 1 else { return 0 }
    let clamped = min(1, max(-1, posX))
    let slot = Int(floor((clamped + 1) / 2 * Double(slots)))
    return min(slots - 1, max(0, slot))
  }

  /// Slot lub `nil` w strefie neutralnej (histereza enter/exit).
  public static func focusedSlot(
    posX: Double,
    slots: Int,
    currentFocus: Int? = nil,
    neutralEnterBand: Double = 0.30,
    neutralExitBand: Double = 0.14
  ) -> Int? {
    guard slots > 0 else { return nil }
    let neutralBand = currentFocus == nil ? neutralEnterBand : neutralExitBand
    if slots == 1 {
      return abs(posX) < neutralBand ? nil : 0
    }
    if abs(posX) < neutralBand { return nil }
    return slotIndex(posX: posX, slots: slots)
  }
}

// MARK: - Paddle (Pong)

/// Sterowanie paletką / osią X — adaptacyjne per `GameInput.bleMode`.
public struct TrikiPaddleDriver: Sendable {
  public struct Config: Sendable, Equatable {
    public var velocityGain: Double
    public var tiltSpeed: Double
    public var flickVelocityThreshold: Double
    public var flickSpeed: Double
    public var positionScale: Double
    public var centerFollowRate: Double

    public init(
      velocityGain: Double = 880,
      tiltSpeed: Double = 240,
      flickVelocityThreshold: Double = 5,
      flickSpeed: Double = 320,
      positionScale: Double = 66,
      centerFollowRate: Double = 18
    ) {
      self.velocityGain = velocityGain
      self.tiltSpeed = tiltSpeed
      self.flickVelocityThreshold = flickVelocityThreshold
      self.flickSpeed = flickSpeed
      self.positionScale = positionScale
      self.centerFollowRate = centerFollowRate
    }

    public static func preset(for mode: TrikiBLEMode) -> Config {
      switch mode.inputStrategy {
      case .velocity:
        return Config(
          velocityGain: 420,
          tiltSpeed: 140,
          flickVelocityThreshold: 9,
          flickSpeed: 160,
          positionScale: 58,
          centerFollowRate: 10
        )
      case .hybrid:
        return Config()
      case .threshold:
        return Config(
          velocityGain: 1_050,
          tiltSpeed: 300,
          flickVelocityThreshold: 999,
          flickSpeed: 0,
          positionScale: 66,
          centerFollowRate: 8
        )
      }
    }
  }

  private var lastPosX: Double?

  public init() {}

  public mutating func reset() {
    lastPosX = nil
  }

  /// Nowa pozycja paletki w pikselach (clamp po stronie gry).
  public mutating func steer(
    current: Double,
    input: GameInput,
    deltaTime: TimeInterval,
    courtCenter: Double,
    config: Config? = nil
  ) -> Double {
    let cfg = config ?? Config.preset(for: input.bleMode)
    let dt = max(deltaTime, 1.0 / 240.0)
    var x = current

    let frameDelta = input.frameDeltaX != 0
      ? input.frameDeltaX
      : input.posX - (lastPosX ?? input.posX)
    lastPosX = input.posX

    let shapedDelta = TrikiVelocityController.shapedFrameDeltaX(
      input: input,
      fallbackRaw: frameDelta
    )

    switch input.bleMode.inputStrategy {
    case .velocity:
      x += shapedDelta * cfg.velocityGain
      let shapedVel = TrikiVelocityController.shapedTrikiVelocity(
        input.trikiVelocity,
        mode: input.bleMode
      )
      if shapedVel >= 1.0 {
        let sign = directionSign(input: input, frameDelta: shapedDelta)
        if sign != 0 { x += sign * cfg.flickSpeed * dt }
      }
      let target = courtCenter + input.posX * cfg.positionScale
      x += (target - x) * min(1, dt * cfg.centerFollowRate)

    case .hybrid:
      x += shapedDelta * cfg.velocityGain
      if input.trikiVelocity >= cfg.flickVelocityThreshold {
        let sign = directionSign(input: input, frameDelta: shapedDelta)
        if sign != 0 { x += sign * cfg.flickSpeed * dt }
      }
      if input.tiltRight { x += cfg.tiltSpeed * dt }
      else if input.tiltLeft { x -= cfg.tiltSpeed * dt }

    case .threshold:
      if input.tiltRight { x += cfg.tiltSpeed * dt }
      else if input.tiltLeft { x -= cfg.tiltSpeed * dt }
      else if abs(shapedDelta) > 0 {
        x += shapedDelta * cfg.velocityGain
      }
    }

    return x
  }

  private func directionSign(input: GameInput, frameDelta: Double) -> Double {
    if input.tiltRight || frameDelta > 0.002 { return 1 }
    if input.tiltLeft || frameDelta < -0.002 { return -1 }
    return 0
  }
}

// MARK: - Menu (Quiz)

/// Wybór slotów menu — krawędzie tilt + debounce + fallback `posX`.
public struct TrikiMenuDriver: Sendable {
  public struct Config: Sendable, Equatable {
    public var velocityThreshold: Double
    public var frameDeltaThreshold: Double
    public var debounce: TimeInterval
    public var neutralEnter: Double
    public var neutralExit: Double

    public init(
      velocityThreshold: Double = 6,
      frameDeltaThreshold: Double = 0.003,
      debounce: TimeInterval = 0.45,
      neutralEnter: Double = 0.24,
      neutralExit: Double = 0.10
    ) {
      self.velocityThreshold = velocityThreshold
      self.frameDeltaThreshold = frameDeltaThreshold
      self.debounce = debounce
      self.neutralEnter = neutralEnter
      self.neutralExit = neutralExit
    }

    public static func preset(for mode: TrikiBLEMode) -> Config {
      switch mode.inputStrategy {
      case .velocity:
        return Config(
          velocityThreshold: 7,
          frameDeltaThreshold: 0.006,
          debounce: 0.32,
          neutralEnter: 0.22,
          neutralExit: 0.10
        )
      case .hybrid:
        return Config()
      case .threshold:
        return Config(
          velocityThreshold: 999,
          frameDeltaThreshold: 0.006,
          debounce: 0.55,
          neutralEnter: 0.38,
          neutralExit: 0.16
        )
      }
    }
  }

  public struct StepResult: Sendable, Equatable {
    public var nudge: Int
    public var slotFromPosition: Int?
    public var usePositionFocus: Bool

    public init(nudge: Int = 0, slotFromPosition: Int? = nil, usePositionFocus: Bool = true) {
      self.nudge = nudge
      self.slotFromPosition = slotFromPosition
      self.usePositionFocus = usePositionFocus
    }
  }

  private var tiltLeftHeld = false
  private var tiltRightHeld = false
  private var cooldown: TimeInterval = 0

  public init() {}

  public mutating func reset() {
    tiltLeftHeld = false
    tiltRightHeld = false
    cooldown = 0
  }

  /// Jedna klatka nawigacji menu (quiz, kategorie).
  public mutating func step(
    input: GameInput,
    deltaTime: TimeInterval,
    slots: Int,
    currentSelection: Int,
    config: Config? = nil
  ) -> StepResult {
    let cfg = config ?? Config.preset(for: input.bleMode)
    let dt = max(deltaTime, 1.0 / 240.0)
    cooldown = max(0, cooldown - dt)

    let leftEdge = input.tiltLeft && !tiltLeftHeld
    let rightEdge = input.tiltRight && !tiltRightHeld
    tiltLeftHeld = input.tiltLeft
    tiltRightHeld = input.tiltRight

    var nudge = 0
    if cooldown <= 0 {
      let shapedDX = TrikiVelocityController.shapedFrameDeltaX(input: input, fallbackRaw: input.frameDeltaX)
      let strong = TrikiVelocityController.shapedTrikiVelocity(input.trikiVelocity, mode: input.bleMode) >= 1.5
      if rightEdge || (strong && shapedDX > cfg.frameDeltaThreshold) {
        nudge = 1
        cooldown = cfg.debounce
      } else if leftEdge || (strong && shapedDX < -cfg.frameDeltaThreshold) {
        nudge = -1
        cooldown = cfg.debounce
      }
    }

    let usePosition = input.bleMode.inputStrategy != .velocity
      || input.trikiVelocity < cfg.velocityThreshold

    let neutralEnter = input.bleMode.inputStrategy == .threshold ? cfg.neutralEnter : cfg.neutralEnter
    let neutralExit = input.bleMode.inputStrategy == .threshold ? cfg.neutralExit : cfg.neutralExit

    let slot: Int?
    if usePosition {
      slot = TrikiSlotMath.focusedSlot(
        posX: input.posX,
        slots: slots,
        currentFocus: currentSelection,
        neutralEnterBand: neutralEnter,
        neutralExitBand: neutralExit
      )
    } else {
      slot = TrikiSlotMath.focusedSlot(
        posX: input.posX,
        slots: slots,
        currentFocus: currentSelection,
        neutralEnterBand: max(cfg.neutralEnter, 0.32),
        neutralExitBand: max(cfg.neutralExit, 0.14)
      )
    }

    return StepResult(
      nudge: nudge,
      slotFromPosition: slot,
      usePositionFocus: usePosition
    )
  }
}

// MARK: - Pointer (Dart)

/// Celowanie 2D — hybrid Δ / pozycja / tilt.
public struct TrikiPointerDriver: Sendable {
  public struct Config: Sendable, Equatable {
    public var followRate: Double
    public var deltaGain: Double
    public var tiltNudge: Double

    public init(followRate: Double = 12, deltaGain: Double = 420, tiltNudge: Double = 0.022) {
      self.followRate = followRate
      self.deltaGain = deltaGain
      self.tiltNudge = tiltNudge
    }

    public static func preset(for mode: TrikiBLEMode) -> Config {
      switch mode.inputStrategy {
      case .velocity:
        return Config(followRate: 10, deltaGain: 120, tiltNudge: 0.010)
      case .hybrid:
        return Config()
      case .threshold:
        return Config(followRate: 6, deltaGain: 520, tiltNudge: 0.035)
      }
    }
  }

  public init() {}

  public mutating func reset() {}

  /// Aktualizuje punkt celowania (współrzędne gry, np. siatka 0…1).
  public mutating func step(
    aimX: Double,
    aimY: Double,
    input: GameInput,
    rawTargetX: Double,
    rawTargetY: Double,
    deltaTime: TimeInterval,
    config: Config? = nil
  ) -> (x: Double, y: Double) {
    let cfg = config ?? Config.preset(for: input.bleMode)
    let dt = max(deltaTime, 1.0 / 240.0)
    var x = aimX
    var y = aimY

    switch input.bleMode.inputStrategy {
    case .velocity:
      let dx = TrikiVelocityController.shapedFrameDeltaX(input: input, fallbackRaw: input.frameDeltaX)
      let dy = TrikiVelocityController.shapedFrameDeltaY(input: input, fallbackRaw: input.frameDeltaY)
      x += dx * cfg.deltaGain * dt
      y += dy * cfg.deltaGain * dt
      let follow = min(1, cfg.followRate * dt * 0.65)
      x = x * (1 - follow) + rawTargetX * follow
      y = y * (1 - follow) + rawTargetY * follow

    case .hybrid:
      let dx = TrikiVelocityController.shapedFrameDeltaX(input: input, fallbackRaw: input.frameDeltaX)
      let dy = TrikiVelocityController.shapedFrameDeltaY(input: input, fallbackRaw: input.frameDeltaY)
      x += dx * cfg.deltaGain * dt
      y += dy * cfg.deltaGain * dt
      let follow = min(1, cfg.followRate * dt * 0.85)
      x = x * (1 - follow) + rawTargetX * follow
      y = y * (1 - follow) + rawTargetY * follow

    case .threshold:
      if input.tiltRight { x += cfg.tiltNudge }
      else if input.tiltLeft { x -= cfg.tiltNudge }
      if input.pointerDirection == .up { y -= cfg.tiltNudge }
      else if input.pointerDirection == .down { y += cfg.tiltNudge }
      x += input.frameDeltaX * cfg.deltaGain * dt
      y += input.frameDeltaY * cfg.deltaGain * dt
    }

    return (x, y)
  }
}

// MARK: - Lateral (Bowling aim)

/// Celowanie boczne (−1…1) z pochylenia — krok adaptacyjny per tryb BLE.
public struct TrikiLateralDriver: Sendable {
  public struct Config: Sendable, Equatable {
    public var leanThreshold: Double
    public var stepGain: Double
    public var maxStepPerFrame: Double
    public var tiltHoldSpeed: Double

    public init(
      leanThreshold: Double = 0.011,
      stepGain: Double = 2.1,
      maxStepPerFrame: Double = 0.014,
      tiltHoldSpeed: Double = 0.32
    ) {
      self.leanThreshold = leanThreshold
      self.stepGain = stepGain
      self.maxStepPerFrame = maxStepPerFrame
      self.tiltHoldSpeed = tiltHoldSpeed
    }

    public static func preset(for mode: TrikiBLEMode) -> Config {
      switch mode.inputStrategy {
      case .velocity:
        return Config(leanThreshold: 0.010, stepGain: 1.8, maxStepPerFrame: 0.010, tiltHoldSpeed: 0.18)
      case .hybrid:
        return Config()
      case .threshold:
        return Config(leanThreshold: 0.014, stepGain: 1.6, maxStepPerFrame: 0.011, tiltHoldSpeed: 0.42)
      }
    }
  }

  public init() {}

  public mutating func reset() {}

  /// `lean` — boczne odchylenie sensora (np. tiltY − neutral).
  public mutating func step(
    current: Double,
    locked: Double,
    lean: Double,
    input: GameInput,
    deltaTime: TimeInterval,
    invert: Bool = false,
    config: Config? = nil
  ) -> (aim: Double, locked: Double) {
    let cfg = config ?? Config.preset(for: input.bleMode)
    let dt = max(deltaTime, 1.0 / 120.0)
    var lock = locked
    var aim = current

    switch input.bleMode.inputStrategy {
    case .velocity, .hybrid:
      guard abs(lean) > cfg.leanThreshold else {
        return (lock, lock)
      }
      let shapedLean = TrikiVelocityController.shape(
        lean,
        limits: .preset(for: input.bleMode)
      )
      guard abs(shapedLean) > 0 else {
        return (lock, lock)
      }
      let sign: Double = shapedLean >= 0 ? 1 : -1
      let strength = min(1, abs(shapedLean) / max(cfg.leanThreshold, 0.001))
      var step = sign * strength * cfg.maxStepPerFrame * cfg.stepGain * 0.36 * dt * 60
      if invert { step = -step }
      lock = min(1, max(-1, lock + step))
      aim = lock

    case .threshold:
      if input.tiltRight {
        var step = cfg.tiltHoldSpeed * dt
        if invert { step = -step }
        lock = min(1, max(-1, lock + step))
      } else if input.tiltLeft {
        var step = -cfg.tiltHoldSpeed * dt
        if invert { step = -step }
        lock = min(1, max(-1, lock + step))
      } else if abs(lean) > cfg.leanThreshold {
        let sign: Double = lean >= 0 ? 1 : -1
        var step = sign * cfg.maxStepPerFrame * 0.8
        if invert { step = -step }
        lock = min(1, max(-1, lock + step))
      }
      aim = lock
    }

    return (aim, lock)
  }
}
