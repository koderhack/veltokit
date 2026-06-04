import Foundation

/// Znormalizowana ramka wejścia dla warstwy gry i UI.
public struct GameInput {
  /// Oś ruchu X po mapowaniu wejścia.
  public var moveX: Double = 0
  /// Oś ruchu Y po mapowaniu wejścia.
  public var moveY: Double = 0
  /// Oś ruchu Z po mapowaniu wejścia.
  public var moveZ: Double = 0
  /// Rotacja urządzenia po normalizacji.
  public var rotation: Double = 0
  /// Intensywność ruchu (metryka zależna od źródła).
  public var intensity: Double = 0
  /// Pitch urządzenia.
  public var pitch: Double = 0
  /// Roll urządzenia.
  public var roll: Double = 0
  /// Flaga potrząśnięcia.
  public var shake: Bool = false
  /// Flaga szybkiego ruchu typu flick.
  public var flick: Bool = false
  /// Flaga obrotu spin.
  public var spin: Bool = false
  /// Sygnał przechyłu w lewo.
  public var tiltLeft: Bool = false
  /// Sygnał przechyłu w prawo.
  public var tiltRight: Bool = false
  /// Główna akcja wejścia (np. klik/strzał).
  public var primaryAction: Bool = false
  /// Jednoklatkowy impuls fizycznego przycisku BLE (`bytes[1]`, zbocze 0→1).
  public var bleButtonClick: Bool = false
  /// Opcjonalna akcja dodatkowa.
  public var secondaryAction: Bool? = nil
  /// Surowe sensory Triki przypisane do tej ramki.
  public var sensors: TrikiSensors = TrikiSensors()
  /// Oś boczna w przestrzeni gry.
  public var lateral: Double = 0
  /// Wygładzona wartość osi bocznej.
  public var lateralSmooth: Double = 0

  /// Tilt po odjęciu offsetu kalibracji.
  public var tiltX: Double = 0
  /// Tilt osi Y po kalibracji.
  public var tiltY: Double = 0
  /// Delta X względem referencji.
  public var deltaX: Double = 0
  /// Delta Y względem referencji.
  public var deltaY: Double = 0
  /// Pozycja końcowa X po obróbce.
  public var posX: Double = 0
  /// Pozycja końcowa Y po obróbce.
  public var posY: Double = 0
  /// Prędkość pionowa w trybie gestu.
  public var velocityY: Double = 0
  /// Impuls strzału wykryty w tej ramce.
  public var shotTriggered: Bool = false
  /// Siła ostatniego rzutu gestem (0…1), gdy `shotTriggered`.
  public var throwPower: Double = 0
  /// Gest „cofnij” przed rzutem (tryb `.gesture`).
  public var gesturePrimed: Bool = false
  /// Stores `pointerDirection` used by this scope.
  public var pointerDirection: PointerDirection = .center
  /// Wykryty tryb BLE notify (fast / normal / lowPower).
  public var bleMode: TrikiBLEMode = .unknown
  /// Δ`posX` od poprzedniej klatki `pollInput` (SDK).
  public var frameDeltaX: Double = 0
  /// Δ`posY` od poprzedniej klatki `pollInput` (SDK).
  public var frameDeltaY: Double = 0
  /// Prędkość z `TrikiMotionEngine` (nie mylić z `intensity` silnika pozycji).
  public var trikiVelocity: Double = 0
  /// Czy gamepad Triki wykrywa ruch w tej ramce.
  public var isMoving: Bool = false

  /// Przycisk / impuls strzału (gry typu Dart — edge w logice gry).
  public var didShoot: Bool { primaryAction || shotTriggered }

  /// Alias kompatybilności na główną akcję.
  public var action: Bool { primaryAction }
  /// Alias kompatybilności na oś sterowania poziomego.
  public var steerX: Double { lateral }

  /// Tworzy nową ramkę wejścia gry.
  ///
  /// - Parameters:
  ///   - moveX: Oś ruchu X po mapowaniu.
  ///   - moveY: Oś ruchu Y po mapowaniu.
  ///   - moveZ: Oś ruchu Z po mapowaniu.
  ///   - rotation: Rotacja urządzenia po normalizacji.
  ///   - intensity: Intensywność ruchu.
  ///   - pitch: Pitch urządzenia.
  ///   - roll: Roll urządzenia.
  ///   - shake: Flaga potrząśnięcia.
  ///   - flick: Flaga ruchu typu flick.
  ///   - spin: Flaga obrotu spin.
  ///   - tiltLeft: Sygnał przechyłu w lewo.
  ///   - tiltRight: Sygnał przechyłu w prawo.
  ///   - primaryAction: Główna akcja wejścia.
  ///   - bleButtonClick: Impuls fizycznego przycisku BLE (jedna klatka).
  ///   - secondaryAction: Opcjonalna akcja dodatkowa.
  ///   - sensors: Zrzut surowych sensorów Triki.
  ///   - lateral: Oś boczna.
  ///   - lateralSmooth: Oś boczna po wygładzeniu.
  ///   - tiltX: Tilt osi X po kalibracji.
  ///   - tiltY: Tilt osi Y po kalibracji.
  ///   - deltaX: Delta X względem referencji.
  ///   - deltaY: Delta Y względem referencji.
  ///   - posX: Pozycja końcowa X.
  ///   - posY: Pozycja końcowa Y.
  ///   - velocityY: Prędkość pionowa.
  ///   - shotTriggered: Impuls strzału.
  ///   - throwPower: Siła rzutu gestem.
  ///   - gesturePrimed: Stan uzbrojenia gestu.
  ///   - pointerDirection: Kierunek wskaźnika.
  ///   - bleMode: Tryb BLE notify.
  ///   - frameDeltaX: Δ posX między klatkami.
  ///   - frameDeltaY: Δ posY między klatkami.
  ///   - trikiVelocity: Prędkość gamepada Triki.
  ///   - isMoving: Ruch wykryty przez Triki.
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
    bleButtonClick: Bool = false,
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
    pointerDirection: PointerDirection = .center,
    bleMode: TrikiBLEMode = .unknown,
    frameDeltaX: Double = 0,
    frameDeltaY: Double = 0,
    trikiVelocity: Double = 0,
    isMoving: Bool = false
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
    self.bleButtonClick = bleButtonClick
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
    self.bleMode = bleMode
    self.frameDeltaX = frameDeltaX
    self.frameDeltaY = frameDeltaY
    self.trikiVelocity = trikiVelocity
    self.isMoving = isMoving
  }
}
