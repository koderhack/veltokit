import Foundation
import VeltoKit

/// Cicha kalibracja Triki w tle — podczas odliczania „Ustaw się” przed rzutem.
struct BowlingInvisibleCalibrator {
  struct Result: Equatable {
    var lateralNeutral: Double
    var neutralTilt: Double
    var pullDepth: Double
    var throwGyroPeak: Double
    var stableEnough: Bool
  }

  private(set) var isComplete = false
  /// tiltY — pochylenie ciała lewo / prawo (celowanie).
  private var lateralSamples: [Double] = []
  /// tiltX — oś cofnięcia / rzutu.
  private var throwTiltSamples: [Double] = []
  private var gyroSamples: [Double] = []
  private var stableTime: TimeInterval = 0
  private var elapsed: TimeInterval = 0

  private let stableHoldDuration: TimeInterval = 1.4
  private let minimumElapsed: TimeInterval = 0.8
  private let motionThreshold = 0.20
  private let maxSamples = 48

  mutating func reset() {
    isComplete = false
    lateralSamples.removeAll(keepingCapacity: true)
    throwTiltSamples.removeAll(keepingCapacity: true)
    gyroSamples.removeAll(keepingCapacity: true)
    stableTime = 0
    elapsed = 0
  }

  /// Zwraca `true`, gdy zebrano wystarczająco stabilnych próbek.
  mutating func feed(input: GameInput, deltaTime: TimeInterval) -> Bool {
    guard !isComplete else { return true }

    elapsed += deltaTime
    let motion =
      abs(input.sensors.tiltY - (lateralSamples.last ?? input.sensors.tiltY)) * 2.2
      + abs(input.sensors.tiltX) * 0.35
      + abs(input.sensors.gyroX) * 0.30
      + abs(input.sensors.gyroZ) * 0.20

    if motion < motionThreshold {
      stableTime += deltaTime
      appendSample(input.sensors.tiltY, to: &lateralSamples)
      appendSample(input.sensors.tiltX, to: &throwTiltSamples)
      appendSample(max(0, input.sensors.gyroX), to: &gyroSamples)
    } else {
      stableTime = max(0, stableTime - deltaTime * 0.65)
    }

    if stableTime >= stableHoldDuration, elapsed >= minimumElapsed, !lateralSamples.isEmpty {
      isComplete = true
      return true
    }
    return false
  }

  mutating func finalize(force: Bool = false) -> Result {
    isComplete = true
    return makeResult(stableEnough: force ? !lateralSamples.isEmpty : stableTime >= stableHoldDuration * 0.65)
  }

  private func makeResult(stableEnough: Bool) -> Result {
    let defaultResult = Result(
      lateralNeutral: 0,
      neutralTilt: 0,
      pullDepth: 0.052,
      throwGyroPeak: 0.78,
      stableEnough: false
    )
    guard !lateralSamples.isEmpty else { return defaultResult }

    let avgLateral = average(lateralSamples)
    let avgThrowTilt = average(throwTiltSamples)
    let avgGyro = average(gyroSamples)
    let tiltSpread = spread(throwTiltSamples)

    return Result(
      lateralNeutral: avgLateral,
      neutralTilt: avgThrowTilt,
      pullDepth: min(0.088, max(0.046, 0.048 + tiltSpread * 0.55)),
      throwGyroPeak: min(1.05, max(0.62, 0.70 + avgGyro * 0.45)),
      stableEnough: stableEnough
    )
  }

  private func appendSample(_ value: Double, to buffer: inout [Double]) {
    buffer.append(value)
    if buffer.count > maxSamples {
      buffer.removeFirst(buffer.count - maxSamples)
    }
  }

  private func average(_ values: [Double]) -> Double {
    guard !values.isEmpty else { return 0 }
    return values.reduce(0, +) / Double(values.count)
  }

  private func spread(_ values: [Double]) -> Double {
    guard values.count > 1 else { return 0 }
    let mean = average(values)
    let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)
    return sqrt(variance)
  }
}
