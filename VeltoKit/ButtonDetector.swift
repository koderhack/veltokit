import Foundation

/// Wykrywanie kliknięcia z BLE (`0x22`, bajt [1], zbocze 0→1).
@MainActor
/// Wykrywa zbocze narastające przycisku w strumieniu BLE.
final class ButtonDetector {
  /// Ostatnia wartość bajtu przycisku odebrana z pakietu.
  private(set) var lastSeenButtonByte: UInt8 = 0
  private var lastButton: UInt8 = 0
  private var pendingClick = false

  /// Informuje, czy oczekuje nieodebrany impuls kliknięcia.
  var didClick: Bool { pendingClick }

  /// Przetwarza pojedynczy pakiet BLE i wykrywa zbocze 0→1.
  func process(_ data: [UInt8]) {
    guard !data.isEmpty else { return }
    if data.count > BLEButtonDecoder.buttonIndex, data[0] == BLEButtonDecoder.packetHeader {
      lastSeenButtonByte = data[BLEButtonDecoder.buttonIndex]
    }
    guard BLEButtonDecoder.risingEdge(in: data, lastButton: &lastButton) else { return }
    pendingClick = true
  }

  /// Jednorazowe odczytanie impulsu kliknięcia (co klatkę).
  func consumeClick() -> Bool {
    let edge = pendingClick
    pendingClick = false
    return edge
  }

  /// Resetuje stan detektora kliknięć.
  func reset() {
    lastButton = 0
    lastSeenButtonByte = 0
    pendingClick = false
  }
}
