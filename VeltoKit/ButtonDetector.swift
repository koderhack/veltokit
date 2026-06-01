import Foundation

/// Wykrywanie kliknięcia z BLE (`0x22`, bajt [1], zbocze 0→1).
@MainActor
final class ButtonDetector {
  private(set) var lastSeenButtonByte: UInt8 = 0
  private var lastButton: UInt8 = 0
  private var pendingClick = false

  var didClick: Bool { pendingClick }

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

  func reset() {
    lastButton = 0
    lastSeenButtonByte = 0
    pendingClick = false
  }
}
