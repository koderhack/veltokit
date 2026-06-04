import Combine
import Foundation
import SwiftUI
import VeltoKit

@MainActor
public final class TrikiInputAdapter: InputProvider, ObservableObject {
  public let motionSDK = MotionSDK()

  @Published public private(set) var autoCalibrationState: AutoCalibrationState = .idle
  @Published public private(set) var showsCalibrationPrompt = false
  @Published public private(set) var bleMode: TrikiBLEMode = .unknown
  @Published public private(set) var idleStatusMessage: String? = nil

  public enum AutoCalibrationState: Equatable {
    case idle
    case awaitingUser
    case done
  }

  public var liveInput: GameInput { motionSDK.liveInput }
  public var isReceiving: Bool { motionSDK.isReceiving }
  public var isConnected: Bool { motionSDK.isConnected }

  /// Połączono i napływają dane — pełne sterowanie (fast/normal).
  public var isTrikiGameplayActive: Bool {
    isConnected && isReceiving && (bleMode == .fast || bleMode == .normal)
  }

  /// Sterowanie dostępne (w tym tilt/shake w low power).
  public var isTrikiControlAvailable: Bool {
    guard isConnected else { return false }
    if isReceiving { return true }
    return bleMode == .lowPower
  }

  public var config: MotionConfig {
    get { motionSDK.config }
    set {
      motionSDK.config = newValue
      objectWillChange.send()
    }
  }

  private var autoCalibDoneForConnection = false
  private var cancellables = Set<AnyCancellable>()

  public init() {
    motionSDK.objectWillChange
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in self?.objectWillChange.send() }
      .store(in: &cancellables)

    motionSDK.$trikiBLEMode
      .receive(on: DispatchQueue.main)
      .sink { [weak self] mode in self?.bleMode = mode }
      .store(in: &cancellables)

    motionSDK.$trikiIdleStatusMessage
      .receive(on: DispatchQueue.main)
      .sink { [weak self] msg in self?.idleStatusMessage = msg }
      .store(in: &cancellables)

    motionSDK.$isConnected
      .receive(on: DispatchQueue.main)
      .sink { [weak self] connected in
        guard let self else { return }
        if connected {
          self.autoCalibDoneForConnection = true
          self.showsCalibrationPrompt = false
          self.autoCalibrationState = .idle
        } else {
          self.resetAutoCalibrationSession()
        }
      }
      .store(in: &cancellables)
  }

  public func connect() { motionSDK.connect() }

  public func connectLastDevice() { motionSDK.connectLastDevice() }

  public func disconnect() {
    motionSDK.disconnect()
    resetAutoCalibrationSession()
  }

  public func performCalibration() {
    motionSDK.calibrateNeutralPose()
    autoCalibDoneForConnection = true
    autoCalibrationState = .done
    showsCalibrationPrompt = false
  }

  public func performAutoCalibration() { performCalibration() }

  public func presentCalibrationPrompt() {
    guard isConnected else { return }
    showsCalibrationPrompt = true
    autoCalibrationState = isReceiving ? .awaitingUser : .idle
  }

  public func skipCalibrationPrompt() {
    showsCalibrationPrompt = false
    autoCalibDoneForConnection = true
    autoCalibrationState = .idle
  }

  public func setInputMode(_ mode: MotionMode) {
    motionSDK.setMode(mode)
  }

  public func pollInput(deltaTime: TimeInterval? = nil) -> GameInput {
    motionSDK.pollInput(deltaTime: deltaTime)
  }

  public func snapshotInput() -> GameInput { motionSDK.snapshotInput() }

  public func resetInputState() {
    motionSDK.disconnect()
    resetAutoCalibrationSession()
  }

  public func calibrateCenter() { motionSDK.calibrateNeutralPose() }
  public func resetOffset() { motionSDK.resetPaddleCenter() }
  public func flipPaddleOffsetSign() { motionSDK.flipPaddleOffsetSign() }
  public func zeroNeutralTilt() { calibrateCenter() }

  public func getBLEMode() -> TrikiBLEMode { bleMode }

  public var hasCachedDevice: Bool { motionSDK.hasCachedBLEDevice }

  public var debugBLEBytes: Bool {
    get { motionSDK.debugBLEBytes }
    set { motionSDK.debugBLEBytes = newValue }
  }

  public var debugBLEMonitorLogging: Bool {
    get { motionSDK.debugBLEMonitorLogging }
    set { motionSDK.debugBLEMonitorLogging = newValue }
  }

  public var logBLEPacketsInDevMode: Bool {
    get { motionSDK.logBLEPacketsInDevMode }
    set { motionSDK.logBLEPacketsInDevMode = newValue }
  }

  public var bleDevLog: [String] { motionSDK.bleDevLog }
  public func resetBLEProbe() { motionSDK.resetBLEProbe() }
  public var bleByteProbe: BLEByteProbe { motionSDK.bleByteProbe }
  public var debugParserClick: Bool { motionSDK.snapshotInput().bleButtonClick }
  public var debugBLEButtonB1: UInt8 { motionSDK.lastButtonByte }
  public func clearBLEDevLog() { motionSDK.clearBLEDevLog() }

  private func resetAutoCalibrationSession() {
    autoCalibDoneForConnection = true
    autoCalibrationState = .idle
    showsCalibrationPrompt = false
  }
}

public typealias MotionInputProvider = TrikiInputAdapter

// MARK: - UI helpers (aplikacja)

extension TrikiBLEMode {
  var uiColor: Color {
    switch self {
    case .fast: return NeonTheme.neonGreen
    case .normal: return NeonTheme.neonCyan
    case .lowPower: return NeonTheme.neonOrange
    case .unknown: return Color.red.opacity(0.85)
    }
  }

  var connectionHint: String {
    switch self {
    case .fast: return "Pełna responsywność · idealny do gry"
    case .normal: return "Stabilny strumień · dobra gra"
    case .lowPower: return "Oszczędny tryb · porusz czapką aby przyspieszyć"
    case .unknown: return "Oczekiwanie na pakiety…"
    }
  }
}

extension MotionInputProvider {
  /// Kolor kropki statusu BLE w grach i menu.
  var linkIndicatorColor: Color {
    guard isConnected else { return .red }
    if isTrikiGameplayActive { return bleMode.uiColor }
    if isReceiving { return bleMode.uiColor.opacity(0.85) }
    if bleMode == .lowPower { return NeonTheme.neonOrange }
    return .orange
  }
}

// MARK: - Odświeżanie wejścia poza pętlą gry (menu, ustawienia, kalibracja)

private let motionMenuPollInterval: TimeInterval = 1.0 / 30.0

extension View {
  /// Woła `pollInput()` w tle — bez tego `liveInput` i liczniki w ustawieniach stoją w miejscu.
  func motionInputPolling(
    _ provider: MotionInputProvider,
    active: Bool = true,
    interval: TimeInterval = motionMenuPollInterval
  ) -> some View {
    background {
      if active {
        TimelineView(.periodic(from: .now, by: interval)) { timeline in
          Color.clear
            .onChange(of: timeline.date.timeIntervalSinceReferenceDate, initial: true) { _, _ in
              _ = provider.pollInput(deltaTime: interval)
            }
        }
      }
    }
  }
}
