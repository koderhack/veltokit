import Foundation
import VeltoKit

/// Cicha kalibracja Triki w tle — podczas odliczania „Ustaw się” przed rzutem.
struct BowlingInvisibleCalibrator {
  /// Opisuje struct `Result` używany przez warstwę UI i logikę gry.
  struct Result: Equatable {
    var neutralTilt: Double
    var lateralNeutral: Double
    var pullDepth: Double
    var throwGyroPeak: Double
    var stableEnough: Bool
  }

  private(set) var isComplete = false
  /// tiltX — oś cofnięcia / rzutu.
  private var throwTiltSamples: [Double] = []
  /// tiltY — oś celowania lewo/prawo.
  private var lateralTiltSamples: [Double] = []
  private var gyroSamples: [Double] = []
  private var stableTime: TimeInterval = 0
  private var elapsed: TimeInterval = 0

  private let stableHoldDuration: TimeInterval = 1.4
  private let minimumElapsed: TimeInterval = 0.8
  private let motionThreshold = 0.20
  private let maxSamples = 48

  mutating func reset() {
    isComplete = false
    throwTiltSamples.removeAll(keepingCapacity: true)
    lateralTiltSamples.removeAll(keepingCapacity: true)
    gyroSamples.removeAll(keepingCapacity: true)
    stableTime = 0
    elapsed = 0
  }

  /// Zwraca `true`, gdy zebrano wystarczająco stabilnych próbek.
  mutating func feed(input: GameInput, deltaTime: TimeInterval) -> Bool {
    guard !isComplete else { return true }

    elapsed += deltaTime
    let motion =
      abs(input.sensors.tiltX) * 0.35
      + abs(input.sensors.gyroX) * 0.30
      + abs(input.sensors.gyroZ) * 0.20

    if motion < motionThreshold {
      stableTime += deltaTime
      appendSample(input.sensors.tiltX, to: &throwTiltSamples)
      appendSample(input.sensors.tiltY, to: &lateralTiltSamples)
      appendSample(max(0, input.sensors.gyroX), to: &gyroSamples)
    } else {
      stableTime = max(0, stableTime - deltaTime * 0.65)
    }

    if stableTime >= stableHoldDuration, elapsed >= minimumElapsed, !throwTiltSamples.isEmpty {
      isComplete = true
      return true
    }
    return false
  }

  mutating func finalize(force: Bool = false) -> Result {
    isComplete = true
    return makeResult(stableEnough: force ? !throwTiltSamples.isEmpty : stableTime >= stableHoldDuration * 0.65)
  }

  private func makeResult(stableEnough: Bool) -> Result {
    let defaultResult = Result(
      neutralTilt: 0,
      lateralNeutral: 0,
      pullDepth: 0.052,
      throwGyroPeak: 0.78,
      stableEnough: false
    )
    guard !throwTiltSamples.isEmpty else { return defaultResult }

    let avgThrowTilt = average(throwTiltSamples)
    let avgGyro = average(gyroSamples)
    let tiltSpread = spread(throwTiltSamples)

    return Result(
      neutralTilt: avgThrowTilt,
      lateralNeutral: average(lateralTiltSamples),
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
