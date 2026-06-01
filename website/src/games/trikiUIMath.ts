/** Port `UI/TrikiUI/TrikiUIMath.swift` */
const NEUTRAL_ENTER = 0.12;
const NEUTRAL_EXIT = 0.08;

export function slotIndex(posX: number, slots: number): number {
  if (slots <= 1) return 0;
  const clamped = Math.min(1, Math.max(-1, posX));
  const slot = Math.floor(((clamped + 1) / 2) * slots);
  return Math.min(slots - 1, Math.max(0, slot));
}

export function focusedSlot(
  posX: number,
  slots: number,
  currentFocus: number | null = null,
): number | null {
  if (slots <= 0) return null;
  const neutralBand = currentFocus === null ? NEUTRAL_ENTER : NEUTRAL_EXIT;
  if (slots === 1) {
    return Math.abs(posX) < neutralBand ? null : 0;
  }
  if (Math.abs(posX) < neutralBand) return null;
  return slotIndex(posX, slots);
}
