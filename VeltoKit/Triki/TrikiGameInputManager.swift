import Foundation

/// Tryb gry — każdy ma osobną strategię przetwarzania sygnału BLE.
public enum GameMode: Sendable, Equatable {
  case pong
  case quiz
  case bowling
  case dart
}

/// Profil odczuć sterowania Pong (pseudo-raw vs smooth).
public enum TrikiControlStyle: Sendable, Equatable {
  /// Zero lag: velocity × gain, minimalny deadzone.
  case raw
  /// Szybki arcade: wyższy gain, lekki clamp.
  case arcade
  /// Snake / miękki: EMA + niższy gain.
  case smooth

  struct PongTuning: Sendable, Equatable {
    let deadzone: Double
    /// `nil` = bez clampu (tylko gain).
    let velocityClamp: Double?
    let velocityGain: Double
    /// `nil` = brak wygładzania.
    let smoothPrevWeight: Double?
  }

  var pong: PongTuning {
    switch self {
    case .raw:
      return PongTuning(deadzone: 0.3, velocityClamp: 8, velocityGain: 2.5, smoothPrevWeight: nil)
    case .arcade:
      return PongTuning(deadzone: 0.35, velocityClamp: 10, velocityGain: 3.0, smoothPrevWeight: nil)
    case .smooth:
      return PongTuning(deadzone: 0.8, velocityClamp: 6, velocityGain: 1.2, smoothPrevWeight: 0.4)
    }
  }
}

/// Wynik jednej klatki `process`.
public struct TrikiGameInputFrame: Sendable, Equatable {
  public var rawVelocity: Double = 0
  public var filteredVelocity: Double = 0
  public var currentSignal: Double = 0
  public var pongMovementDelta: Double = 0
  public var quizAnswerTriggered: Bool = false
  public var quizNudgeLeftTriggered: Bool = false
  public var bowlingThrowTriggered: Bool = false
  public var bowlingThrowPower: Double = 0
  public var dartThrowTriggered: Bool = false
  public var dartThrowPower: Double = 0

  public init() {}
}

/// Wejście per gra: Pong = velocity boost, Quiz = edge trigger.
public final class TrikiGameInputManager: @unchecked Sendable {
  public struct Config: Sendable, Equatable {
    public var signalScale: Double
    public var pongControlStyle: TrikiControlStyle
    public var quizTriggerThreshold: Double
    public var quizLeftThreshold: Double
    public var quizTriggerCooldown: TimeInterval
    public var deadzone: Double
    public var bowlingPeakMinRelease: Double
    public var bowlingThrowCooldown: TimeInterval
    public var dartSpikeThreshold: Double
    public var dartThrowCooldown: TimeInterval

    public init(
      signalScale: Double = 100,
      pongControlStyle: TrikiControlStyle = .raw,
      quizTriggerThreshold: Double = 15,
      quizLeftThreshold: Double = -15,
      quizTriggerCooldown: TimeInterval = 1.2,
      deadzone: Double = 1.5,
      bowlingPeakMinRelease: Double = 6,
      bowlingThrowCooldown: TimeInterval = 0.7,
      dartSpikeThreshold: Double = 7,
      dartThrowCooldown: TimeInterval = 0.5
    ) {
      self.signalScale = signalScale
      self.pongControlStyle = pongControlStyle
      self.quizTriggerThreshold = quizTriggerThreshold
      self.quizLeftThreshold = quizLeftThreshold
      self.quizTriggerCooldown = quizTriggerCooldown
      self.deadzone = deadzone
      self.bowlingPeakMinRelease = bowlingPeakMinRelease
      self.bowlingThrowCooldown = bowlingThrowCooldown
      self.dartSpikeThreshold = dartSpikeThreshold
      self.dartThrowCooldown = dartThrowCooldown
    }

    public static func preset(for mode: GameMode) -> Config {
      switch mode {
      case .pong:
        return Config(pongControlStyle: .raw)
      case .quiz:
        return Config(
          quizTriggerThreshold: 15,
          quizLeftThreshold: -15,
          quizTriggerCooldown: 1.2
        )
      case .bowling:
        return Config(bowlingPeakMinRelease: 6, bowlingThrowCooldown: 0.7)
      case .dart:
        return Config(dartSpikeThreshold: 7, dartThrowCooldown: 0.5)
      }
    }
  }

  public private(set) var mode: GameMode
  public var config: Config

  private var lastPongX: Double = 0
  private var pongSeeded = false
  private var pongSmoothOutput: Double = 0

  private var quizCanTrigger = true
  private var quizWasAboveRight = false
  private var quizWasBelowLeft = false
  private var quizCooldownLeft: TimeInterval = 0

  private var previousRawVelocity: Double = 0
  private var bowlingCooldown: TimeInterval = 0
  private var bowlingMaxVelocity: Double = 0
  private var dartCooldown: TimeInterval = 0

  public init(mode: GameMode, config: Config? = nil) {
    self.mode = mode
    self.config = config ?? Config.preset(for: mode)
  }

  public func setMode(_ newMode: GameMode, resetState: Bool = true) {
    mode = newMode
    config = Config.preset(for: newMode)
    if resetState { reset() }
  }

  public func reset() {
    lastPongX = 0
    pongSeeded = false
    pongSmoothOutput = 0
    quizCanTrigger = true
    quizWasAboveRight = false
    quizWasBelowLeft = false
    quizCooldownLeft = 0
    previousRawVelocity = 0
    bowlingCooldown = 0
    bowlingMaxVelocity = 0
    dartCooldown = 0
  }

  @discardableResult
  public func process(input: GameInput, deltaTime: TimeInterval) -> TrikiGameInputFrame {
    let dt = max(deltaTime, 1.0 / 240.0)
    quizCooldownLeft = max(0, quizCooldownLeft - dt)
    if quizCooldownLeft <= 0 { quizCanTrigger = true }
    bowlingCooldown = max(0, bowlingCooldown - dt)
    dartCooldown = max(0, dartCooldown - dt)

    var frame = TrikiGameInputFrame()

    switch mode {
    case .pong:
      processPong(input: input, into: &frame)
    case .quiz:
      processQuiz(input: input, into: &frame)
    case .bowling:
      let raw = eventVelocity(from: input)
      frame.rawVelocity = raw
      frame.currentSignal = raw
      processBowling(rawVelocity: raw, into: &frame)
      previousRawVelocity = raw
    case .dart:
      let raw = eventVelocity(from: input)
      frame.rawVelocity = raw
      frame.currentSignal = raw
      processDart(rawVelocity: raw, into: &frame)
      previousRawVelocity = raw
    }

    return frame
  }

  // MARK: - Pong (RAW / ARCADE / SMOOTH)

  private func processPong(input: GameInput, into frame: inout TrikiGameInputFrame) {
    let tuning = config.pongControlStyle.pong
    let currentX = input.posX * config.signalScale

    if !pongSeeded {
      lastPongX = currentX
      pongSeeded = true
      frame.currentSignal = currentX
      return
    }

    let velocity = currentX - lastPongX
    lastPongX = currentX
    frame.currentSignal = currentX
    frame.rawVelocity = velocity

    guard abs(velocity) >= tuning.deadzone else { return }

    var v = velocity
    if let cap = tuning.velocityClamp {
      v = min(cap, max(-cap, v))
    }

    let output: Double
    if let w = tuning.smoothPrevWeight {
      let smooth = pongSmoothOutput * w + v * (1 - w)
      pongSmoothOutput = smooth
      output = smooth * tuning.velocityGain
      frame.filteredVelocity = smooth
    } else {
      pongSmoothOutput = 0
      output = v * tuning.velocityGain
      frame.filteredVelocity = output
    }

    let bleScale = input.bleMode == .fast ? 1.08 : 1.0
    frame.pongMovementDelta = output * bleScale
  }

  public func applyPongMovement(
    to paddleX: inout Double,
    frame: TrikiGameInputFrame,
    minX: Double,
    maxX: Double
  ) {
    guard frame.pongMovementDelta != 0 else { return }
    paddleX += frame.pongMovementDelta
    paddleX = min(maxX, max(minX, paddleX))
  }

  // MARK: - Quiz

  private func quizMotionLevel(from input: GameInput) -> Double {
    if input.trikiVelocity > 0.01 {
      return input.trikiVelocity
    }
    return max(input.intensity, abs(input.frameDeltaX) * config.signalScale)
  }

  private func processQuiz(input: GameInput, into frame: inout TrikiGameInputFrame) {
    let cfg = config
    let level = quizMotionLevel(from: input)
    frame.currentSignal = level

    let isAboveRight = level > cfg.quizTriggerThreshold
    if isAboveRight, !quizWasAboveRight, quizCanTrigger {
      frame.quizAnswerTriggered = true
      quizCanTrigger = false
      quizCooldownLeft = cfg.quizTriggerCooldown
    }
    quizWasAboveRight = isAboveRight

    let isBelowLeft = level < cfg.quizLeftThreshold
    if isBelowLeft, !quizWasBelowLeft, quizCanTrigger {
      frame.quizNudgeLeftTriggered = true
      quizCanTrigger = false
      quizCooldownLeft = cfg.quizTriggerCooldown
    }
    quizWasBelowLeft = isBelowLeft
  }

  // MARK: - Bowling / Dart

  private func eventVelocity(from input: GameInput) -> Double {
    if abs(input.frameDeltaX) > 1e-9 {
      return input.frameDeltaX * config.signalScale
    }
    let dir: Double = input.tiltRight ? 1 : (input.tiltLeft ? -1 : 0)
    return dir * max(input.trikiVelocity, input.intensity)
  }

  private func processBowling(rawVelocity: Double, into frame: inout TrikiGameInputFrame) {
    if rawVelocity > 0 {
      bowlingMaxVelocity = max(bowlingMaxVelocity, rawVelocity)
    }
    let cfg = config
    let release = rawVelocity < previousRawVelocity && previousRawVelocity > cfg.bowlingPeakMinRelease
    guard release, bowlingCooldown <= 0, bowlingMaxVelocity > cfg.deadzone else { return }
    frame.bowlingThrowTriggered = true
    frame.bowlingThrowPower = min(1, bowlingMaxVelocity / 12)
    bowlingMaxVelocity = 0
    bowlingCooldown = cfg.bowlingThrowCooldown
  }

  private func processDart(rawVelocity: Double, into frame: inout TrikiGameInputFrame) {
    guard dartCooldown <= 0 else { return }
    guard rawVelocity > config.dartSpikeThreshold else { return }
    frame.dartThrowTriggered = true
    frame.dartThrowPower = min(1, rawVelocity / 12)
    dartCooldown = config.dartThrowCooldown
  }
}
