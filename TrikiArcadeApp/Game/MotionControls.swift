import Foundation
import TrikiMotionKit

/// Uniwersalne funkcje wejścia — każda gra może z nich korzystać.
enum MotionControls {
  enum TurnDirection: String {
    case left
    case right
    case neutral
  }

  enum MotionGesture: String {
    case shake
    case flick
    case spin
    case tiltLeft
    case tiltRight
    case none
  }

  /// Sterowanie w bok: -1 lewo, +1 prawo (Snake, Box, Auto…).
  static func lateral(_ input: GameInput) -> Double {
    input.lateral
  }

  /// Wygładzone sterowanie w bok (ustawiane przez silnik co klatkę).
  static func lateralSmooth(_ input: GameInput) -> Double {
    input.lateralSmooth
  }

  /// Sterowanie drogą/autem po pikselach na sekundę.
  static func roadSteering(_ input: GameInput) -> Double {
    input.lateralSmooth
  }

  /// Sterowanie Box / paletka: bez prędkości, tylko pozycja -1...+1.
  static func boxSteering(_ input: GameInput) -> Double {
    lateral(input)
  }

  /// Do przodu / tyłu z tilt Y lub prędkościomierza.
  static func forward(_ input: GameInput) -> Double {
    let tilt = input.moveY
    if abs(tilt) > 0.05 { return tilt }
    return speedometer(input)
  }

  /// Intensywność ruchu z żyroskopu (detektor ruchu).
  static func motionLevel(_ input: GameInput) -> Double {
    input.sensors.motion
  }

  /// Żyroskop: osie X/Y/Z.
  static func gyroscope(_ input: GameInput) -> (x: Double, y: Double, z: Double) {
    (input.sensors.gyroX, input.sensors.gyroY, input.sensors.gyroZ)
  }

  /// Prędkościomierz na bazie pola 12-13 oraz energii gyro.
  static func speedometer(_ input: GameInput) -> Double {
    input.sensors.speed
  }

  /// Obrót jak w Snake: ujemny = lewo, dodatni = prawo.
  static func snakeTurn(_ input: GameInput) -> Double {
    rotation(input)
  }

  /// Czysty obrót lewo/prawo (Snake: skręt).
  static func rotation(_ input: GameInput) -> Double {
    input.rotation
  }

  /// Pozycja na osi X: środek + rotation × zasięg (1:1 z pochyleniem po kalibracji).
  static func horizontalPosition(
    rotation: Double,
    center: Double,
    halfTravel: Double
  ) -> Double {
    center + rotation * halfTravel
  }

  /// Płynne podążanie za celem — tłumi szum BLE bez zmiany surowego `input.rotation`.
  static func followHorizontal(
    current: Double,
    target: Double,
    deltaTime: TimeInterval,
    rate: Double = 16
  ) -> Double {
    let step = min(1, max(0, rate * deltaTime))
    return current + (target - current) * step
  }

  /// Mapowanie kursora Wii-pointer na oś X ekranu.
  static func screenX(posX: Double, width: Double) -> Double {
    width / 2 + posX * width / 2
  }

  /// Płynne podążanie paletki 60 FPS — szybkie, bez migotania pikseli.
  static func smoothPaddleX(
    current: Double,
    posX: Double,
    width: Double,
    minX: Double,
    maxX: Double,
    deltaTime: TimeInterval,
    rate: Double = 48
  ) -> Double {
    let target = min(maxX, max(minX, screenX(posX: posX, width: width)))
    return followHorizontal(current: current, target: target, deltaTime: deltaTime, rate: rate)
  }

  /// Mapowanie kursora na oś Y (góra = mniejsze Y).
  static func screenY(posY: Double, height: Double) -> Double {
    height / 2 - posY * height / 2
  }

  static func pointerScreenPosition(
    input: GameInput,
    width: Double,
    height: Double
  ) -> (x: Double, y: Double) {
    (
      screenX(posX: input.posX, width: width),
      screenY(posY: input.posY, height: height)
    )
  }

  static func pointerDirectionLabel(
    posX: Double,
    posY: Double,
    threshold: Double = 0.08
  ) -> String {
    let absX = abs(posX)
    let absY = abs(posY)
    if absX < threshold, absY < threshold { return PointerDirection.center.rawValue }
    if absX >= absY {
      return posX < 0 ? PointerDirection.left.rawValue : PointerDirection.right.rawValue
    }
    return posY < 0 ? PointerDirection.down.rawValue : PointerDirection.up.rawValue
  }

  /// Paddle / koszyk: rotation −1…+1 → pozycja X (bez velocity).
  static func paddleX(
    rotation: Double,
    current: Double,
    minX: Double,
    maxX: Double,
    smooth: Double = 0.2
  ) -> Double {
    let normalized = (rotation + 1) / 2.0
    let target = minX + normalized * (maxX - minX)
    guard smooth > 0 else { return target }
    return current + (target - current) * smooth
  }

  static func turnDirection(_ input: GameInput, threshold: Double = 0.08) -> TurnDirection {
    let r = rotation(input)
    if r < -threshold { return .left }
    if r > threshold { return .right }
    return .neutral
  }

  /// Detektor ruchu dla gestów i triggerów.
  static func isMoving(_ input: GameInput, threshold: Double = 0.35) -> Bool {
    motionLevel(input) >= threshold
  }

  static func isFlicking(_ input: GameInput) -> Bool {
    input.flick
  }

  static func isSpinning(_ input: GameInput) -> Bool {
    input.spin
  }

  static func isTiltingLeft(_ input: GameInput) -> Bool {
    input.tiltLeft
  }

  static func isTiltingRight(_ input: GameInput) -> Bool {
    input.tiltRight
  }

  static func dominantGesture(_ input: GameInput) -> MotionGesture {
    if input.shake { return .shake }
    if input.spin { return .spin }
    if input.flick { return .flick }
    if input.tiltLeft { return .tiltLeft }
    if input.tiltRight { return .tiltRight }
    return .none
  }

  /// Detektor skrętu tylko w jedną stronę.
  static func isTurningOneSide(
    _ input: GameInput,
    side: TurnDirection,
    threshold: Double = 0.12
  ) -> Bool {
    switch side {
    case .left:
      return rotation(input) <= -threshold
    case .right:
      return rotation(input) >= threshold
    case .neutral:
      return abs(rotation(input)) < threshold
    }
  }

  static func isShaking(_ input: GameInput) -> Bool {
    input.shake || input.sensors.motion > 0.55
  }

  static func primaryAction(_ input: GameInput) -> Bool {
    input.primaryAction
  }
}

/// Wygładza sygnał boczny — wspólne dla wszystkich gier.
struct LateralSmoother {
  private var smoothed = 0.0
  private var velocity = 0.0

  mutating func reset() {
    smoothed = 0
    velocity = 0
  }

  mutating func step(target: Double, tuning: GameTuning, deltaTime: TimeInterval) -> Double {
    step(
      target: target,
      tuning: tuning,
      profile: GameInputProfile(),
      deltaTime: deltaTime
    )
  }

  mutating func step(
    target: Double,
    tuning: GameTuning,
    profile: GameInputProfile,
    deltaTime: TimeInterval
  ) -> Double {
    smoothed = smoothed * 0.7 + target * 0.3

    let targetVel = smoothed * (profile.movementSpeed ?? tuning.movementSpeed)
    velocity = targetVel
    return velocity
  }
}
