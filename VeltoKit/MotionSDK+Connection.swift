import Combine
import Foundation

private let motionHudPublishInterval: TimeInterval = 0.12

/// Adds focused motion sdk helpers.
extension MotionSDK {
  /// Skan BLE + auto-connect do jedynego urządzenia z „triki” w nazwie.
  public func connect() {
    ensureBLEPipeline()
    bleManager?.autoConnectWhenSingleLikelyMatch = true
    bleManager?.startScan(clearList: true)
  }

  /// Zamyka połączenie BLE i czyści stan sesji.
  public func disconnect() {
    bleManager?.disconnect()
    resetConnectionState()
  }

  /// Wywołuj co klatkę gry (~60 Hz) po `connect()` — zwraca gotowy `GameInput`.
  @discardableResult
  /// Handles `pollInput`.
  ///
  /// - Parameters:
  ///   - deltaTime: Input used by this operation.
  /// - Returns: Result produced by this operation.
  public func pollInput(deltaTime: TimeInterval? = nil) -> GameInput {
    guard let parser = streamParser else {
      updateFrame(deltaTime: deltaTime)
      return input
    }

    let now = Date().timeIntervalSince1970
    if now - lastPacketAt > 0.35, isReceiving { isReceiving = false }

    if config.mode == .paddle {
      parser.refreshTiltSensors()
      parser.flushImpulsesOnly()
      let impulses = parser.consumeImpulses()
      let out = updateFrame(deltaTime: deltaTime)
      var enriched = input
      enriched.tiltY = parser.sensors.tiltY
      enriched.tiltX = parser.sensors.tiltX
      enriched.lateral = out.x
      enriched.lateralSmooth = out.x
      enriched.shake = impulses.shake
      enriched.sensors = parser.sensors
      applyClickToSensors(&enriched)
      latestEnrichedInput = enriched
      publishLiveInputIfNeeded(now: now, input: enriched)
      return enriched
    }

    parser.flush()
    setIngressSupplement(
      rotation: parser.sensors.rotation,
      tiltX: parser.sensors.tiltX,
      gyroY: parser.sensors.gyroY
    )
    let out = updateFrame(deltaTime: deltaTime)
    let impulses = parser.consumeImpulses()
    latestEnrichedInput = makeEnrichedGameInput(
      output: out,
      sdkInput: input,
      parser: parser,
      impulses: impulses
    )
    publishLiveInputIfNeeded(now: now, input: latestEnrichedInput)
    return latestEnrichedInput
  }

  /// Pobiera ostatnią wzbogaconą ramkę wejścia bez aktualizacji stanu.
  public func snapshotInput() -> GameInput { latestEnrichedInput }

  /// Kalibruje neutralną pozycję na podstawie bieżących danych.
  public func calibrateNeutralPose() {
    _ = pollInput()
    engine.calibrateCenter()
    engine.resetPaddleMotion()
    refreshLiveInputFromEngine()
  }

  /// Resetuje środek paletki.
  public func resetPaddleCenter() {
    engine.resetCenter()
    refreshLiveInputFromEngine()
  }

  /// Odwraca znak offsetu paletki.
  public func flipPaddleOffsetSign() {
    engine.flipPaddleOffsetSign()
    refreshLiveInputFromEngine()
  }

  // MARK: - DEV / BLE diagnostics

  /// Włącza logowanie surowych bajtów BLE.
  public var debugBLEBytes: Bool {
    get { bleManager?.debugRXBytes ?? false }
    set { bleManager?.debugRXBytes = newValue }
  }

  /// Włącza logowanie całych pakietów BLE w trybie deweloperskim.
  public var logBLEPacketsInDevMode: Bool {
    get { bleManager?.logRXPacketsInDevMode ?? false }
    set { bleManager?.logRXPacketsInDevMode = newValue }
  }

  /// Bufor logów BLE z aktualnej sesji.
  public var bleDevLog: [String] { bleManager?.devRawLog ?? [] }

  /// Narzędzie do analizy zmian bajtów między pakietami BLE.
  public var bleByteProbe: BLEByteProbe { bleManager?.byteProbe ?? BLEByteProbe() }

  /// Resetuje stan analizatora bajtów BLE i czyści log.
  public func resetBLEProbe() {
    bleManager?.byteProbe.reset()
    bleManager?.devRawLog.removeAll()
  }

  /// Czyści bufor logów BLE.
  public func clearBLEDevLog() { bleManager?.devRawLog.removeAll() }

  // MARK: - Private

  /// Handles `ensureBLEPipeline`.
  func ensureBLEPipeline() {
    guard bleManager == nil else { return }

    let ble = BLEManager()
    let parser = MotionParser()
    parser.retainRecentFrames = false
    bleManager = ble
    streamParser = parser

    ble.rxBytes
      .receive(on: DispatchQueue.main)
      .sink { [weak self] bytes in
        guard let self, !bytes.isEmpty else { return }
        self.enqueueBLE(bytes)
        self.streamParser?.enqueue(data: bytes)
        self.lastPacketAt = Date().timeIntervalSince1970
        if !self.isReceiving { self.isReceiving = true }
      }
      .store(in: &bleCancellables)

    ble.$status
      .map { $0 == .connected }
      .removeDuplicates()
      .sink { [weak self] connected in
        self?.isConnected = connected
        if !connected { self?.resetConnectionState() }
      }
      .store(in: &bleCancellables)
  }

  /// Handles `resetConnectionState`.
  func resetConnectionState() {
    streamParser?.resetStream()
    reset()
    liveInput = GameInput()
    latestEnrichedInput = GameInput()
    isReceiving = false
    lastHudPublishAt = 0
  }

  /// Handles `refreshLiveInputFromEngine`.
  func refreshLiveInputFromEngine() {
    let out = output
    latestEnrichedInput = makeEnrichedGameInput(
      output: out,
      sdkInput: input,
      parser: streamParser,
      impulses: (false, false)
    )
    liveInput = latestEnrichedInput
    lastHudPublishAt = Date().timeIntervalSince1970
  }

  /// Handles `publishLiveInputIfNeeded`.
  ///
  /// - Parameters:
  ///   - now: Input used by this operation.
  ///   - input: Input used by this operation.
  func publishLiveInputIfNeeded(now: TimeInterval, input: GameInput) {
    guard now - lastHudPublishAt >= motionHudPublishInterval else { return }
    lastHudPublishAt = now
    liveInput = input
  }

  /// Builds a UI/game-friendly input snapshot from raw engine output and parser state.
  ///
  /// - Parameters:
  ///   - output: Current processed motion output frame.
  ///   - sdkInput: Base input snapshot that will be enriched.
  ///   - parser: Optional parser containing latest sensor payload.
  ///   - impulses: Edge-triggered click/shake impulses for this frame.
  /// - Returns: Enriched `GameInput` used by HUD and gameplay layers.
  func makeEnrichedGameInput(
    output: MotionOutput,
    sdkInput: GameInput,
    parser: MotionParser?,
    impulses: (click: Bool, shake: Bool)
  ) -> GameInput {
    let dbg = debug
    var enriched = sdkInput
    enriched.moveX = dbg.rawX
    enriched.moveY = dbg.rawY
    enriched.posX = output.x
    enriched.posY = output.y
    enriched.deltaX = dbg.relX
    enriched.deltaY = dbg.relY
    if let parser {
      enriched.tiltX = parser.sensors.tiltX
      enriched.tiltY = parser.sensors.tiltY
      enriched.rotation = output.x
      enriched.lateral = output.x
      enriched.lateralSmooth = output.x
      enriched.velocityY = dbg.relY
      enriched.intensity = output.velocityX
      enriched.shake = impulses.shake
      enriched.sensors = parser.sensors
      enriched.pointerDirection = pointerDirection(posX: output.x, posY: output.y)
    }
    applyClickToSensors(&enriched)
    return enriched
  }

  /// Handles `applyClickToSensors`.
  ///
  /// - Parameters:
  ///   - input: Input used by this operation.
  func applyClickToSensors(_ input: inout GameInput) {
    guard input.primaryAction else { return }
    var sensors = input.sensors
    sensors.click = true
    input.sensors = sensors
  }

  /// Converts normalized pointer coordinates into a coarse cardinal direction.
  ///
  /// - Parameters:
  ///   - posX: Normalized horizontal pointer position.
  ///   - posY: Normalized vertical pointer position.
  ///   - threshold: Deadzone threshold treated as centered pointer.
  /// - Returns: Dominant pointer direction used by UI hints.
  func pointerDirection(
    posX: Double,
    posY: Double,
    threshold: Double = 0.08
  ) -> PointerDirection {
    let absX = abs(posX)
    let absY = abs(posY)
    if absX < threshold, absY < threshold { return .center }
    if absX >= absY { return posX < 0 ? .left : .right }
    return posY < 0 ? .down : .up
  }
}
