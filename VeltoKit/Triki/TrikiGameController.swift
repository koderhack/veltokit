import Combine
import Foundation

/// Publiczna fasada gamepada Triki — BLE → parser → motion → `TrikiGameInput`.
@MainActor
public final class TrikiGameController: ObservableObject {
  /// Tryb czułości (szybki vs stabilny).
  public enum InputMode: Sendable, Equatable {
    case game
    case smooth
  }

  public let ble = TrikiBLEManager()

  public var inputMode: InputMode = .game {
    didSet { motion.inputMode = mapInputMode(inputMode) }
  }

  /// Log hex + wartości parsera (DEV).
  public var debugParserLogging: Bool {
    get { parser.debugLoggingEnabled }
    set { parser.debugLoggingEnabled = newValue }
  }

  @Published public private(set) var gameInput = TrikiGameInput()
  @Published public private(set) var isConnected = false
  @Published public private(set) var isReceiving = false

  private var parser = TrikiParser()
  private var motion = TrikiMotionEngine()
  private var cancellables = Set<AnyCancellable>()
  private var lastPacketAt: TimeInterval = 0
  private var lastPollTime: TimeInterval?

  private var moveHandlers: [(Float) -> Void] = []
  private var shakeHandlers: [() -> Void] = []
  private var actionHandlers: [() -> Void] = []

  public init() {
    motion.inputMode = .game
    wireBLE()
  }

  // MARK: - Connection

  /// Skan + auto-connect do jedynego urządzenia z „triki” w nazwie.
  public func connect() {
    ble.autoConnectWhenSingleLikelyMatch = true
    if ble.cachedPeripheralUUID != nil, ble.status == .idle {
      ble.connectCachedPeripheralIfAvailable()
    } else {
      ble.startScan(clearList: true)
    }
  }

  public func disconnect() {
    ble.disconnect()
    resetSession()
  }

  // MARK: - Manual bytes (własny central)

  public func ingest(_ bytes: [UInt8]) {
    guard !bytes.isEmpty else { return }
    parser.append(bytes)
    lastPacketAt = Date().timeIntervalSince1970
    if !isReceiving { isReceiving = true }
  }

  /// Wywołuj w pętli gry (~60 Hz). Zwraca bieżącą ramkę gamepada.
  @discardableResult
  public func tick(deltaTime: TimeInterval? = nil) -> TrikiGameInput {
    let now = Date().timeIntervalSince1970
    if now - lastPacketAt > 0.35, isReceiving { isReceiving = false }

    let dt: TimeInterval
    if let deltaTime {
      dt = deltaTime
    } else {
      dt = min(0.05, max(0, now - (lastPollTime ?? now)))
    }
    lastPollTime = now

    let frames = parser.drainParsedFrames()
    if !frames.isEmpty {
      motion.ingest(parsed: frames, deltaTime: dt)
      gameInput = motion.output
      dispatchCallbacks()
    }
    return gameInput
  }

  public func resetSession() {
    parser.reset()
    motion.reset()
    gameInput = TrikiGameInput()
    isReceiving = false
    lastPollTime = nil
  }

  // MARK: - Gamepad API (bez surowych osi)

  public func getDirection() -> Float { motion.getDirection() }
  public func getVelocity() -> Float { motion.getVelocity() }
  public func isShake() -> Bool { motion.isShake() }
  public func isMoving() -> Bool { motion.isMoving() }

  // MARK: - Callbacks (DX)

  public func onMove(_ handler: @escaping (Float) -> Void) {
    moveHandlers.append(handler)
  }

  public func onShake(_ handler: @escaping () -> Void) {
    shakeHandlers.append(handler)
  }

  public func onAction(_ handler: @escaping () -> Void) {
    actionHandlers.append(handler)
  }

  public func clearHandlers() {
    moveHandlers.removeAll()
    shakeHandlers.removeAll()
    actionHandlers.removeAll()
  }

  // MARK: - Private

  private func wireBLE() {
    ble.rxBytes
      .receive(on: DispatchQueue.main)
      .sink { [weak self] bytes in
        self?.ingest(bytes)
      }
      .store(in: &cancellables)

    ble.$status
      .map { $0 == .connected }
      .removeDuplicates()
      .sink { [weak self] connected in
        guard let self else { return }
        self.isConnected = connected
        if !connected { self.resetSession() }
      }
      .store(in: &cancellables)
  }

  private func dispatchCallbacks() {
    let direction = gameInput.direction
    if gameInput.isMoving {
      for handler in moveHandlers { handler(direction) }
    }
    if gameInput.isShake {
      for handler in shakeHandlers { handler() }
    }
    if gameInput.isAction {
      for handler in actionHandlers { handler() }
    }
  }

  private func mapInputMode(_ mode: InputMode) -> TrikiInputMode {
    switch mode {
    case .game: return .game
    case .smooth: return .smooth
    }
  }
}
