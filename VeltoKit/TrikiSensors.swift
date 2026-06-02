import Foundation

/// Sensory z ramki Triki 16 B (`22 00` … `F7`/`F8`).
///
/// | Bajt   | Znaczenie              |
/// |--------|------------------------|
/// | 2–3    | Tilt X                 |
/// | 4–5    | Tilt Y                 |
/// | 6–7    | Żyroskop X             |
/// | 8–9    | Żyroskop Y             |
/// | 10–11  | Żyroskop Z             |
/// | 12–13  | Obrót / prędkościomierz (skręt Snake lewo/prawo) |
/// | 14     | Flagi: bit0 klik, bit1 shake |
public struct TrikiSensors: Equatable {
  /// Stores `tiltX` used by this scope.
  public var tiltX: Double = 0
  /// Stores `tiltY` used by this scope.
  public var tiltY: Double = 0
  /// Stores `gyroX` used by this scope.
  public var gyroX: Double = 0
  /// Stores `gyroY` used by this scope.
  public var gyroY: Double = 0
  /// Stores `gyroZ` used by this scope.
  public var gyroZ: Double = 0
  /// Obrót wokół osi Z — skręt lewo/prawo (Snake, Box).
  public var rotation: Double = 0
  /// Prędkościomierz (pole 12–13, alternatywna interpretacja energii).
  public var speed: Double = 0
  /// Detektor ruchu — norma żyroskopu.
  public var motion: Double = 0
  /// Stores `click` used by this scope.
  public var click: Bool = false
  /// Stores `shake` used by this scope.
  public var shake: Bool = false

  public init(
    tiltX: Double = 0,
    tiltY: Double = 0,
    gyroX: Double = 0,
    gyroY: Double = 0,
    gyroZ: Double = 0,
    rotation: Double = 0,
    speed: Double = 0,
    motion: Double = 0,
    click: Bool = false,
    shake: Bool = false
  ) {
    self.tiltX = tiltX
    self.tiltY = tiltY
    self.gyroX = gyroX
    self.gyroY = gyroY
    self.gyroZ = gyroZ
    self.rotation = rotation
    self.speed = speed
    self.motion = motion
    self.click = click
    self.shake = shake
  }
}
