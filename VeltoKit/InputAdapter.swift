import Foundation

/// Czysty adapter SDK (bez BLE) — `update` + `input` w jednym miejscu.
@MainActor
/// Represents input adapter.
public final class InputAdapter {
  private let sdk = MotionSDK()

  /// Ostatnia ramka wejścia wyliczona przez SDK.
  public var input: GameInput { sdk.input }
  /// Konfiguracja przetwarzania ruchu.
  public var config: MotionConfig {
    get { sdk.config }
    set { sdk.config = newValue }
  }

  /// Tworzy adapter wejścia oparty o `MotionSDK`.
  public init() {}

  /// Ustawia aktywny tryb pracy wejścia.
  public func setMode(_ mode: MotionMode) {
    sdk.setMode(mode)
  }

  /// Rozpoczyna skanowanie i połączenie BLE.
  public func connect() { sdk.connect() }
  /// Rozłącza aktywne połączenie BLE.
  public func disconnect() { sdk.disconnect() }
  /// Informuje, czy adapter ma aktywne połączenie BLE.
  public var isConnected: Bool { sdk.isConnected }
  /// Informuje, czy napływają dane BLE.
  public var isReceiving: Bool { sdk.isReceiving }

  @discardableResult
  /// Handles `pollInput`.
  ///
  /// - Parameters:
  ///   - deltaTime: Input used by this operation.
  /// - Returns: Result produced by this operation.
  public func pollInput(deltaTime: TimeInterval? = nil) -> GameInput {
    sdk.pollInput(deltaTime: deltaTime)
  }

  /// Aktualizuje dane wejścia bezpośrednio surowymi wartościami.
  public func update(
    rawX: Double? = nil,
    bytes: [UInt8] = [],
    deltaTime: TimeInterval? = nil
  ) {
    _ = sdk.update(rawX: rawX, bytes: bytes, deltaTime: deltaTime)
  }

  /// Resetuje stan SDK i bieżącej ramki wejścia.
  public func reset() {
    sdk.reset()
  }
}
