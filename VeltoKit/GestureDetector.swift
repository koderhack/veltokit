import Foundation

/// Rzut gestem: cofnięcie (BACK) → impuls do przodu (FORWARD).
@MainActor
final class GestureDetector {
  private var lastGestureRelY = 0.0
  private var gestureRelYPeak = 0.0
  private var gestureArmed = false
  private var lastShotAt: TimeInterval = 0

  private(set) var gesturePrimed = false
  private(set) var lastThrowPower: Double = 0

  var didThrow: Bool = false

  func resetBaseline() {
    gestureArmed = false
    gesturePrimed = false
    lastGestureRelY = 0
    gestureRelYPeak = 0
    lastShotAt = 0
    lastThrowPower = 0
    didThrow = false
  }

  func resetFrame() {
    didThrow = false
    lastThrowPower = 0
  }

  /// Tryby bez gestu (paletka / wskaźnik) — nie pokazuj „uzbrojenia”.
  func suppressPrimedDisplay() {
    gesturePrimed = false
  }

  /// Cofnięcie (spadek osi / szybki pull) → impuls do przodu = strzał.
  func detect(relY: Double, cfg: MotionConfig, frameScale: Double) {
    let velocity = (relY - lastGestureRelY) / max(frameScale, 0.01)
    lastGestureRelY = relY

    let now = Date().timeIntervalSince1970
    if !gestureArmed {
      gestureRelYPeak = max(gestureRelYPeak, relY)
      let pullbackFromPeak = gestureRelYPeak - relY
      let pulled =
        pullbackFromPeak >= cfg.gesturePullbackDelta
        || (pullbackFromPeak >= cfg.gesturePullbackDelta * 0.55 && velocity <= -cfg.gesturePullSpeed)
      if pulled {
        gestureArmed = true
        gestureRelYPeak = relY
      }
      gesturePrimed = gestureArmed
      return
    }

    gesturePrimed = true

    let forwardDelta = relY - gestureRelYPeak
    let forward =
      (velocity >= cfg.gestureMinThrustSpeed && forwardDelta >= cfg.gesturePullbackDelta * 0.55)
      || velocity >= cfg.gestureMinThrustSpeed * 1.35
      || forwardDelta >= cfg.gesturePullbackDelta * 0.9
    guard forward else { return }
    guard now - lastShotAt >= cfg.gestureCooldown else { return }

    lastShotAt = now
    gestureArmed = false
    gesturePrimed = false
    gestureRelYPeak = relY
    didThrow = true
    let speedFactor = velocity / max(cfg.gestureMinThrustSpeed, 0.001)
    let deltaFactor = forwardDelta / max(cfg.gesturePullbackDelta, 0.001)
    lastThrowPower = min(1, max(0, max(speedFactor, deltaFactor * 0.9)))
  }
}
