import Foundation
import Combine

/// Fasada Motion SDK: pozycja, gest rzutu, przycisk BLE → `GameInput`.
@MainActor
/// Represents motion sdk.
public final class MotionSDK: ObservableObject {
  /// Stores `processor` used by this scope.
  let processor = MotionProcessor()
  /// Stores `gesture` used by this scope.
  let gesture = GestureDetector()
  /// Stores `button` used by this scope.
  let button = ButtonDetector()
  /// Współdzielony silnik przetwarzania ruchu.
  public let engine: MotionEngine

  /// Ostatni bajt przycisku BLE (DEV).
  public var lastButtonByte: UInt8 { button.lastSeenButtonByte }

  /// Ostatnia opublikowana ramka wejścia.
  public private(set) var input = GameInput()

  // MARK: - BLE (connect + pollInput)

  /// Stan połączenia BLE.
  @Published public internal(set) var isConnected = false
  /// Informuje, czy napływają pakiety BLE.
  @Published public internal(set) var isReceiving = false
  /// Wykryty tryb częstotliwości notify (fast / normal / low power).
  @Published public internal(set) var trikiBLEMode: TrikiBLEMode = .unknown
  /// Podpowiedź UX przy low power (np. „czeka na ruch”).
  @Published public internal(set) var trikiIdleStatusMessage: String? = nil
  /// Ostatnia ramka wejścia publikowana do HUD.
  @Published public internal(set) var liveInput = GameInput()

  /// Stores `bleManager` used by this scope.
  var bleManager: TrikiBLEManager?
  /// Gamepad pipeline (parser + motion engine).
  var trikiController: TrikiGameController?
  /// Stores `streamParser` used by this scope.
  var streamParser: MotionParser?
  /// Stores `bleCancellables` used by this scope.
  var bleCancellables = Set<AnyCancellable>()
  /// Stores `lastPacketAt` used by this scope.
  var lastPacketAt: TimeInterval = 0
  /// Stores `lastHudPublishAt` used by this scope.
  var lastHudPublishAt: TimeInterval = 0
  /// Stores `latestEnrichedInput` used by this scope.
  var latestEnrichedInput = GameInput()

  /// Konfiguracja silnika ruchu.
  public var config: MotionConfig {
    get { engine.config }
    set { engine.config = newValue }
  }

  /// Aktualny tryb sterowania.
  public var mode: MotionMode {
    get { engine.config.mode }
    set { engine.setMode(newValue) }
  }

  /// Ostatni wynik ruchu z silnika.
  public var output: MotionOutput { engine.output }
  /// Ostatnie dane debugowe z silnika.
  public var debug: MotionDebug { engine.debug }

  private var rxBuffer: [UInt8] = []
  private var lastPollTime: TimeInterval?
  private var ingressRotation = 0.0
  private var ingressTiltX = 0.0
  private var ingressGyroY = 0.0
  private var latestPaddleRaw: Double?
  var lastFramePosX: Double?
  var lastFramePosY: Double?

  /// Tworzy instancję SDK ruchu.
  public init() {
    engine = MotionEngine(processor: processor, gesture: gesture)
  }

  /// Ustawia tryb pracy silnika.
  public func setMode(_ mode: MotionMode) {
    engine.setMode(mode)
  }

  /// Ustawia dodatkowe źródła wejścia podawane spoza BLE.
  public func setIngressSupplement(rotation: Double, tiltX: Double, gyroY: Double) {
    ingressRotation = rotation
    ingressTiltX = tiltX
    ingressGyroY = gyroY
  }

  /// BLE callback — buforuje bajty (przycisk) i rawX w trybie paletki.
  public func enqueueBLE(_ data: [UInt8]) {
    guard !data.isEmpty else { return }
    button.process(data)
    if engine.config.mode == .paddle {
      if let raw = BLEGyroParser.gyroRawFromPacket(data) {
        latestPaddleRaw = raw
      }
      return
    }
    rxBuffer.append(contentsOf: data)
    if rxBuffer.count > 512 {
      rxBuffer.removeSubrange(0..<(rxBuffer.count - 256))
    }
  }

  /// Handles `flushIngress`.
  public func flushIngress() {
    if engine.config.mode == .paddle {
      if let raw = latestPaddleRaw {
        engine.setRawX(raw)
      }
      return
    }

    let cfg = engine.config
    var tiltBlock: BLEGyroParser.GyroTriple?
    var gyroBlock: BLEGyroParser.GyroTriple?
    var blockIndex = 0

    if !rxBuffer.isEmpty {
      let blocks = BLEGyroParser.drainGyroBlocks(from: &rxBuffer)
      if !blocks.isEmpty {
        if let first = blocks.first {
          tiltBlock = BLEGyroParser.scaledTiltBlock(first)
        }
        if blocks.count >= 2 {
          gyroBlock = blocks[blocks.count - 1]
          blockIndex = blocks.count - 1
        }
      }
    }

    let gx = gyroBlock?.x ?? tiltBlock?.x ?? ingressTiltX
    let gy = gyroBlock?.y ?? tiltBlock?.y ?? ingressGyroY
    let gz = gyroBlock?.z ?? tiltBlock?.z ?? 0
    let mapped = cfg.axisMapping.map(
      gx: gx,
      gy: gy,
      gz: gz,
      rotation: ingressRotation
    )
    engine.setPaddleSources(rotation: mapped.x, gyroZ: gz)
    engine.updateRaw(x: mapped.x, y: mapped.y, gyroBlockIndex: blockIndex)
  }

  /// Podaje do SDK zdekodowaną ramkę Triki.
  public func ingestTrikiFrame(
    gyroX: Double,
    gyroY: Double,
    gyroZ: Double,
    rotation: Double
  ) {
    ingressRotation = rotation
    ingressGyroY = gyroY
    let mapping = engine.config.axisMapping
    let mapped = mapping.map(gx: gyroX, gy: gyroY, gz: gyroZ, rotation: rotation)
    engine.setPaddleSources(rotation: mapped.x, gyroZ: gyroZ)
    if engine.config.mode == .paddle {
      latestPaddleRaw = mapped.x * BLEGyroParser.gyroDivisor
    } else {
      engine.updateRaw(x: mapped.x, y: mapped.y, gyroBlockIndex: 1)
    }
  }

  /// Aktualizacja klatki: opcjonalnie surowy X i pakiet BLE (przycisk).
  ///
  /// - Parameters:
  ///   - rawX: Optional raw X sample forwarded directly to motion engine.
  ///   - bytes: Optional BLE payload slice used for button decoding.
  ///   - deltaTime: Optional frame delta in seconds overriding internal timing.
  /// - Returns: Motion output produced for the updated frame.
  @discardableResult
  /// Convenience frame update entrypoint with optional raw input and BLE packet payload.
  public func update(
    rawX: Double? = nil,
    bytes: [UInt8] = [],
    deltaTime: TimeInterval? = nil
  ) -> MotionOutput {
    if let rawX {
      engine.setRawX(rawX)
    }
    if !bytes.isEmpty {
      button.process(bytes)
    }
    return updateFrame(deltaTime: deltaTime)
  }

  /// Aktualizuje silnik i zwraca wynik aktualnej klatki.
  @discardableResult
  /// Handles `updateFrame`.
  ///
  /// - Parameters:
  ///   - deltaTime: Input used by this operation.
  /// - Returns: Result produced by this operation.
  public func updateFrame(deltaTime: TimeInterval? = nil) -> MotionOutput {
    flushIngress()
    let now = Date().timeIntervalSince1970
    let dt: TimeInterval
    if let deltaTime {
      dt = deltaTime
    } else {
      dt = min(0.05, max(0, now - (lastPollTime ?? now)))
    }
    lastPollTime = now
    engine.updateFrame(deltaTime: dt)
    publishInput()
    return engine.output
  }

  /// Resetuje pełny stan SDK i silnika.
  public func reset() {
    rxBuffer.removeAll(keepingCapacity: false)
    lastPollTime = nil
    ingressRotation = 0
    ingressTiltX = 0
    ingressGyroY = 0
    latestPaddleRaw = nil
    lastFramePosX = nil
    lastFramePosY = nil
    button.reset()
    engine.resetState()
    input = GameInput()
  }

  private func publishInput() {
    let out = engine.output
    let click = button.consumeClick()
    let trikiAction = trikiController?.gameInput.isAction ?? false
    let throwShot = out.didShoot
    input.posX = out.x
    input.posY = out.y
    input.shotTriggered = throwShot
    switch engine.config.mode {
    case .paddle:
      // Quiz / Pong / menu: only the physical BLE button — not velocity or throw.
      input.primaryAction = click
    case .pointer, .gesture:
      input.primaryAction = click || throwShot || trikiAction
    }
    input.throwPower = throwShot ? engine.lastGestureThrowPower : 0
    input.gesturePrimed = engine.gesturePrimed
  }
}
