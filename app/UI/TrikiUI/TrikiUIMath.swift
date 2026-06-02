import Foundation

/// Maps Triki pointer movement to focusable UI slots.
///
/// Purpose: centralize slot-index math with neutral-zone hysteresis.
/// Use when: converting `posX` motion samples into stable menu focus.
/// Example: `TrikiUIMath.focusedSlot(posX: input.posX, slots: 4)`.
enum TrikiUIMath {
  /// Indeks slotu 0…(slots−1) z pozycji poziomej (−1…1).
  static func slotIndex(posX: Double, slots: Int) -> Int {
    guard slots > 1 else { return 0 }
    let clamped = min(1, max(-1, posX))
    let slot = Int(floor((clamped + 1) / 2 * Double(slots)))
    return min(slots - 1, max(0, slot))
  }

  /// Slot albo `nil` w strefie neutralnej (środek).
  /// Histereza: łatwiej utrzymać fokus niż go zdobyć (mniej mrugania przy drganiach).
  static func focusedSlot(
    posX: Double,
    slots: Int,
    currentFocus: Int? = nil,
    neutralEnterBand: Double = TrikiUIConfig.neutralEnterBand,
    neutralExitBand: Double = TrikiUIConfig.neutralExitBand
  ) -> Int? {
    guard slots > 0 else { return nil }
    let neutralBand = currentFocus == nil ? neutralEnterBand : neutralExitBand
    if slots == 1 {
      return abs(posX) < neutralBand ? nil : 0
    }
    if abs(posX) < neutralBand { return nil }
    return slotIndex(posX: posX, slots: slots)
  }
}
