import Foundation
import VeltoKit

/// Chwyt **od góry** — Triki nad tarczą, skierowany w dół (jak rzut lotką z góry na planszę).
///
/// - **Cel (żyro / pointer):** `posX` lewo–prawo, `posY` przód–tył na tarczy
/// - **Rzut (tilt):** `tiltX` podnieś rękę / opuść w dół
/// - **Impuls rzutu:** żyro X, Y, Z
struct DartGripMapping: Equatable {
  /// Przechowuje wartość `invertAimX` wykorzystywaną przez dany komponent.
  var invertAimX: Bool
  /// Przechowuje wartość `invertAimY` wykorzystywaną przez dany komponent.
  var invertAimY: Bool
  /// Przechowuje wartość `invertThrow` wykorzystywaną przez dany komponent.
  var invertThrow: Bool

  static let overhead = DartGripMapping(
    invertAimX: false,
    invertAimY: false,
    invertThrow: false
  )

  /// Stary chwyt (pionowa pięść w stronę TV) — tylko kompatybilność nazw.
  static let verticalFist = overhead

  static func from(axisMapping: MotionAxisMapping) -> DartGripMapping {
    DartGripMapping(
      invertAimX: axisMapping.invertX,
      invertAimY: axisMapping.invertY,
      invertThrow: axisMapping.invertY
    )
  }

  /// Celowanie nad tarczą — żyroskop (tryb pointer), nie tilt (za mały przy chwycie od góry).
  func aimDelta(
    from input: GameInput,
    sensors: TrikiSensors,
    neutralX: Double,
    neutralY: Double
  ) -> (x: Double, y: Double) {
    _ = sensors
    _ = neutralX
    _ = neutralY
    var x = input.posX
    var y = input.posY
    if invertAimX { x = -x }
    if invertAimY { y = -y }
    return (x, y)
  }

  /// Bowling — celowanie kuli pochyleniem (tilt).
  func aimDelta(from sensors: TrikiSensors, neutralX: Double, neutralY: Double) -> (x: Double, y: Double) {
    var x = sensors.tiltY - neutralX
    var y = sensors.tiltX - neutralY
    if invertAimX { x = -x }
    if invertAimY { y = -y }
    return (x, y)
  }

  /// Oś podniesienia / opuszczenia ręki (osobna od celowania).
  func throwTiltAxis(from sensors: TrikiSensors, neutral: Double) -> Double {
    var axis = sensors.tiltX - neutral
    if invertThrow { axis = -axis }
    return axis
  }

  /// Wykonuje operację `throwGyroImpulse` w bieżącym kontekście gry/UI.
  func throwGyroImpulse(
    from sensors: TrikiSensors,
    baselineX: inout Double,
    baselineY: inout Double,
    baselineZ: inout Double,
    adaptBaseline: Bool = true
  ) -> Double {
    if adaptBaseline {
      baselineX = baselineX * 0.985 + sensors.gyroX * 0.015
      baselineY = baselineY * 0.985 + sensors.gyroY * 0.015
      baselineZ = baselineZ * 0.985 + sensors.gyroZ * 0.015
    }
    let dx = abs(sensors.gyroX - baselineX)
    let dy = abs(sensors.gyroY - baselineY)
    let dz = abs(sensors.gyroZ - baselineZ)
    return max(0, max(dx, dy, dz) - 0.09)
  }

  /// Wykonuje operację `calibrateNeutrals` w bieżącym kontekście gry/UI.
  func calibrateNeutrals(from sensors: TrikiSensors) -> (aimX: Double, aimY: Double, throwTilt: Double) {
    (sensors.tiltY, sensors.tiltX, sensors.tiltX)
  }
}
