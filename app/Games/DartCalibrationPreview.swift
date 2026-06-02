import Foundation
import VeltoKit

/// Podgląd sterowania Triki na ekranie opcji (bez pełnej gry).
@MainActor
/// Opisuje class `DartCalibrationPreview` używany przez warstwę UI i logikę gry.
final class DartCalibrationPreview: ObservableObject {
  @Published private(set) var throwState: DartThrowController.ThrowState = .idle
  @Published private(set) var throwPrimed = false
  @Published private(set) var aimNormX = 0.5
  @Published private(set) var aimNormY = 0.5

  private let throwController = DartThrowController()

  /// Wykonuje operację `reset` w bieżącym kontekście gry/UI.
  func reset() {
    throwController.reset(axis: 0)
    aimNormX = 0.5
    aimNormY = 0.5
    publish()
  }

  /// Wykonuje operację `tick` w bieżącym kontekście gry/UI.
  func tick(input: GameInput, deltaTime: TimeInterval, distanceFactor: Double) {
    let throwAxis = input.tiltY + input.sensors.gyroX * 0.25
    _ = throwController.update(
      axis: throwAxis,
      deltaTime: deltaTime,
      distanceFactor: distanceFactor
    )

    let aimSlow = throwController.isAimSlowed
    let aimGain = aimSlow ? 0.26 : 1.0
    let follow = aimSlow ? 0.12 : 0.18
    let reach = 0.42 * aimGain

    let targetX = 0.5 + min(reach, max(-reach, input.posX * reach))
    let targetY = 0.5 + min(reach, max(-reach, input.posY * reach))
    aimNormX = aimNormX * (1 - follow) + targetX * follow
    aimNormY = aimNormY * (1 - follow) + targetY * follow
    publish()
  }

  private func publish() {
    throwState = throwController.state
    throwPrimed = throwController.isPrimed
  }
}
