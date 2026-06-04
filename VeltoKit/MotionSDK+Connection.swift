import Combine
import Foundation

private let motionHudPublishInterval: TimeInterval = 0.12

/// Adds focused motion sdk helpers.
extension MotionSDK {
  /// Skan BLE + auto-connect do jedynego urządzenia z „triki” w nazwie.
  public func connect() {
    ensureBLEPipeline()
    trikiController?.ble.autoConnectWhenSingleLikelyMatch = true
    trikiController?.connect()
  }

  /// Ponowne połączenie z ostatnim zapamiętanym urządzeniem (bez pełnego skanu).
  public func connectLastDevice() {
    ensureBLEPipeline()
    trikiController?.ble.autoConnectWhenSingleLikelyMatch = false
    trikiController?.ble.connectCachedPeripheralIfAvailable()
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
    trikiController?.tick(deltaTime: deltaTime)
    applyTrikiGamepadToEngine()

    guard let parser = streamParser else {
      updateFrame(deltaTime: deltaTime)
      return input
    }

    let now = Date().timeIntervalSince1970
    let stale = trikiBLEMode.packetStaleSeconds
    if now - lastPacketAt > stale, isReceiving { isReceiving = false }
    syncTrikiPublishedState()

    if config.mode == .paddle {
      parser.refreshTiltSensors()
      parser.flushImpulsesOnly()
      let impulses = parser.consumeImpulses()
      let out = updateFrame(deltaTime: deltaTime)
      var enriched = makeEnrichedGameInput(
        output: out,
        sdkInput: input,
        parser: parser,
        impulses: impulses
      )
      applyTrikiGamepadSignals(&enriched)
      finalizeAdaptiveInput(&enriched)
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
    var enriched = makeEnrichedGameInput(
      output: out,
      sdkInput: input,
      parser: parser,
      impulses: impulses
    )
    applyTrikiGamepadSignals(&enriched)
    finalizeAdaptiveInput(&enriched)
    latestEnrichedInput = enriched
    publishLiveInputIfNeeded(now: now, input: enriched)
    return enriched
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

  /// Czy zapisano UUID ostatniego urządzenia (szybkie ponowne połączenie).
  public var hasCachedBLEDevice: Bool {
    bleManager?.cachedPeripheralUUID != nil
  }

  /// Log monitora trybu BLE (Δt między pakietami).
  public var debugBLEMonitorLogging: Bool {
    get { trikiController?.debugBLEMonitorLogging ?? false }
    set { trikiController?.debugBLEMonitorLogging = newValue }
  }

  // MARK: - Private

  /// Handles `ensureBLEPipeline`.
  func ensureBLEPipeline() {
    guard trikiController == nil else { return }

    let triki = TrikiGameController()
    let parser = MotionParser()
    parser.retainRecentFrames = false
    trikiController = triki
    bleManager = triki.ble
    streamParser = parser

    triki.ble.rxBytes
      .receive(on: DispatchQueue.main)
      .sink { [weak self] bytes in
        guard let self, !bytes.isEmpty else { return }
        self.enqueueBLE(bytes)
        self.streamParser?.enqueue(data: bytes)
        self.lastPacketAt = Date().timeIntervalSince1970
      }
      .store(in: &bleCancellables)

    triki.$isConnected
      .removeDuplicates()
      .sink { [weak self] connected in
        self?.isConnected = connected
        if !connected { self?.resetConnectionState() }
      }
      .store(in: &bleCancellables)

    triki.$bleMode
      .removeDuplicates()
      .sink { [weak self] mode in
        self?.trikiBLEMode = mode
      }
      .store(in: &bleCancellables)

    triki.$idleStatusMessage
      .sink { [weak self] message in
        self?.trikiIdleStatusMessage = message
      }
      .store(in: &bleCancellables)

    triki.$isReceiving
      .removeDuplicates()
      .sink { [weak self] receiving in
        self?.isReceiving = receiving
      }
      .store(in: &bleCancellables)
  }

  func syncTrikiPublishedState() {
    guard let triki = trikiController else { return }
    trikiBLEMode = triki.getBLEMode()
    trikiIdleStatusMessage = triki.idleStatusMessage
  }

  /// Handles `resetConnectionState`.
  func resetConnectionState() {
    streamParser?.resetStream()
    trikiController?.resetSession()
    reset()
    liveInput = GameInput()
    latestEnrichedInput = GameInput()
    isReceiving = false
    trikiBLEMode = .unknown
    trikiIdleStatusMessage = nil
    lastHudPublishAt = 0
    lastFramePosX = nil
    lastFramePosY = nil
  }

  /// Mapuje wyjście gamepada na silnik pozycji (bez surowych osi w API gry).
  func applyTrikiGamepadToEngine() {
    guard let triki = trikiController else { return }
    let pad = triki.gameInput
    if config.mode == .paddle {
      let scaled = Double(pad.direction) * BLEGyroParser.gyroDivisor
      engine.setRawX(scaled)
    } else {
      engine.updateRaw(x: Double(pad.direction), y: Double(pad.velocity))
    }
  }

  /// Handles `refreshLiveInputFromEngine`.
  func refreshLiveInputFromEngine() {
    let out = output
    var enriched = makeEnrichedGameInput(
      output: out,
      sdkInput: input,
      parser: streamParser,
      impulses: (false, false)
    )
    applyTrikiGamepadSignals(&enriched)
    finalizeAdaptiveInput(&enriched)
    latestEnrichedInput = enriched
    liveInput = enriched
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

  /// Applies Triki gamepad velocity/tilt edges to `GameInput` (all tryby gier).
  func applyTrikiGamepadSignals(_ input: inout GameInput) {
    guard let pad = trikiController?.gameInput else { return }
    input.tiltLeft = pad.isTiltLeft
    input.tiltRight = pad.isTiltRight
    let vel = Double(pad.velocity)
    input.trikiVelocity = vel
    input.isMoving = pad.isMoving
    input.intensity = max(input.intensity, vel)
    input.flick = input.flick || pad.isSwing
    let dir = Double(pad.direction)
    if dir != 0, vel > 0.5 {
      input.deltaX = dir * vel * 0.012
    }
  }

  /// Uzupełnia `bleMode`, Δpos i strategię adaptacyjną dla gier.
  func finalizeAdaptiveInput(_ input: inout GameInput) {
    input.bleMode = trikiBLEMode
    let prevX = lastFramePosX ?? input.posX
    let prevY = lastFramePosY ?? input.posY
    input.frameDeltaX = input.posX - prevX
    input.frameDeltaY = input.posY - prevY
    lastFramePosX = input.posX
    lastFramePosY = input.posY
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
      enriched.shake = impulses.shake || (trikiController?.gameInput.isShake ?? false)
      enriched.sensors = parser.sensors
      enriched.pointerDirection = pointerDirection(posX: output.x, posY: output.y)
    }
    let buttonEdge = impulses.click || sdkInput.primaryAction
    if config.mode == .paddle {
      enriched.primaryAction = buttonEdge
    } else if impulses.click {
      enriched.primaryAction = true
    }
    applyClickToSensors(&enriched, clickEdge: buttonEdge)
    return enriched
  }

  /// Sets one-shot click flag on sensors when a BLE button edge was detected.
  func applyClickToSensors(_ input: inout GameInput, clickEdge: Bool) {
    guard clickEdge else { return }
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
