import Foundation

public struct GameInput {
  public var moveX: Double = 0
  public var moveY: Double = 0
  public var moveZ: Double = 0
  public var rotation: Double = 0
  public var intensity: Double = 0
  public var pitch: Double = 0
  public var roll: Double = 0
  public var shake: Bool = false
  public var flick: Bool = false
  public var spin: Bool = false
  public var tiltLeft: Bool = false
  public var tiltRight: Bool = false
  public var primaryAction: Bool = false
  public var secondaryAction: Bool? = nil
  public var sensors: TrikiSensors = TrikiSensors()
  public var lateral: Double = 0
  public var lateralSmooth: Double = 0

  /// Tilt po odjęciu offsetu kalibracji.
  public var tiltX: Double = 0
  public var tiltY: Double = 0
  public var deltaX: Double = 0
  public var deltaY: Double = 0
  public var posX: Double = 0
  public var posY: Double = 0
  public var velocityY: Double = 0
  public var shotTriggered: Bool = false
  /// Siła ostatniego rzutu gestem (0…1), gdy `shotTriggered`.
  public var throwPower: Double = 0
  /// Gest „cofnij” przed rzutem (tryb `.gesture`).
  public var gesturePrimed: Bool = false
  public var pointerDirection: PointerDirection = .center

  /// Przycisk / impuls strzału (gry typu Dart — edge w logice gry).
  public var didShoot: Bool { primaryAction || shotTriggered }

  public var action: Bool { primaryAction }
  public var steerX: Double { lateral }

  public init(
    moveX: Double = 0,
    moveY: Double = 0,
    moveZ: Double = 0,
    rotation: Double = 0,
    intensity: Double = 0,
    pitch: Double = 0,
    roll: Double = 0,
    shake: Bool = false,
    flick: Bool = false,
    spin: Bool = false,
    tiltLeft: Bool = false,
    tiltRight: Bool = false,
    primaryAction: Bool = false,
    secondaryAction: Bool? = nil,
    sensors: TrikiSensors = TrikiSensors(),
    lateral: Double = 0,
    lateralSmooth: Double = 0,
    tiltX: Double = 0,
    tiltY: Double = 0,
    deltaX: Double = 0,
    deltaY: Double = 0,
    posX: Double = 0,
    posY: Double = 0,
    velocityY: Double = 0,
    shotTriggered: Bool = false,
    throwPower: Double = 0,
    gesturePrimed: Bool = false,
    pointerDirection: PointerDirection = .center
  ) {
    self.moveX = moveX
    self.moveY = moveY
    self.moveZ = moveZ
    self.rotation = rotation
    self.intensity = intensity
    self.pitch = pitch
    self.roll = roll
    self.shake = shake
    self.flick = flick
    self.spin = spin
    self.tiltLeft = tiltLeft
    self.tiltRight = tiltRight
    self.primaryAction = primaryAction
    self.secondaryAction = secondaryAction
    self.sensors = sensors
    self.lateral = lateral
    self.lateralSmooth = lateralSmooth
    self.tiltX = tiltX
    self.tiltY = tiltY
    self.deltaX = deltaX
    self.deltaY = deltaY
    self.posX = posX
    self.posY = posY
    self.velocityY = velocityY
    self.shotTriggered = shotTriggered
    self.throwPower = throwPower
    self.gesturePrimed = gesturePrimed
    self.pointerDirection = pointerDirection
  }
}
