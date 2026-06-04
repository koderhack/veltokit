import Foundation

/// Przycisk Triki w pakiecie NUS: `22` na [0], przycisk **0/1 na [1]** (edge 0→1).
public enum BLEButtonDecoder {
  /// Oczekiwany nagłówek pakietu BLE.
  public static let packetHeader: UInt8 = 0x22
  /// Indeks bajtu przycisku w pakiecie.
  public static let buttonIndex = 1

  /// Sprawdza, czy bajt reprezentuje stan wciśnięty (dowolna wartość ≠ 0).
  public static func isPressed(_ byte: UInt8) -> Bool {
    byte != 0
  }

  /// Skanuje cały notify — każdy blok zaczynający się od `0x22`, przycisk na następnym bajcie.
  public static func risingEdgeAnywhere(in data: [UInt8], lastButton: inout UInt8) -> Bool {
    guard data.count > buttonIndex else { return false }
    var edge = false
    var i = 0
    while i < data.count {
      if data[i] == packetHeader, i + buttonIndex < data.count {
        let button = data[i + buttonIndex]
        if isPressed(button), !isPressed(lastButton) {
          edge = true
        }
        lastButton = button
        i += 2
      } else {
        i += 1
      }
    }
    return edge
  }

  /// Zbocze narastające na `bytes[1]` (tylko gdy pakiet zaczyna się od `0x22`).
  public static func risingEdge(in data: [UInt8], lastButton: inout UInt8) -> Bool {
    guard data.count > buttonIndex, data[0] == packetHeader else { return false }
    let button = data[buttonIndex]
    let edge = isPressed(button) && !isPressed(lastButton)
    lastButton = button
    return edge
  }
}
