import Foundation

/// Przycisk Triki w pakiecie NUS: `22` na [0], przycisk **0/1 na [1]** (edge 0→1).
public enum BLEButtonDecoder {
  public static let packetHeader: UInt8 = 0x22
  public static let buttonIndex = 1

  public static func isPressed(_ byte: UInt8) -> Bool {
    byte == 1
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
