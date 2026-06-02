---
title: Triki UI navigation
description: Build focus-based game menus with trikiUIScreen, TrikiUINavigator, and MotionInputProvider
---

# Triki UI navigation

This layer connects **motion input** to a **focus-driven SwiftUI UI** used by menus, calibration, and quiz-style selection screens.

Use it when you want players to navigate UI with the Triki controller instead of touch.

## Core pieces

| Component | Role |
|-----------|------|
| `MotionInputProvider` (`TrikiInputAdapter`) | Produces `GameInput`/`liveInput` from BLE frames |
| `TrikiUINavigator` | Holds UI navigation state (`focusIndex`, hold progress, activation callback) |
| `TrikiFocusGate` | Stabilizes slot focus before selection |
| `TrikiHoldTracker` | Converts focused dwell time into activation |
| `.trikiUIScreen(...)` | View modifier that wires screen lifecycle + HUD + ticking |
| `TrikiFocusRow` | Reusable row that reflects focus and hold state |

## `.trikiUIScreen` behavior

`trikiUIScreen` is the main integration point for a screen with N selectable items.

```swift
VStack(spacing: 12) {
  TrikiFocusRow(index: 0, title: "Start")
  TrikiFocusRow(index: 1, title: "Settings")
  TrikiFocusRow(index: 2, title: "Quit")
}
.trikiUIScreen(itemCount: 3, isActive: true, showsPhoneHUD: true) { index in
  handleSelection(index)
}
```

### What happens in lifecycle

When the modifier becomes active:

1. `GameManager.applyUIMode(to:)` applies UI-friendly motion tuning.
2. Navigator clock resets.
3. Navigator is configured with `itemCount` and `onActivate`.
4. Every game/UI tick, navigator consumes `MotionInputProvider` state.
5. Optional phone HUD appears (`TrikiUIHUD`) when Triki control is available.

When deactivated, navigator state is cleared so stale focus does not leak between screens.

## Input integration model

The flow is:

```text
BLE / parser -> MotionInputProvider.liveInput.posX -> focused slot -> hold or click -> onActivate(index)
```

- **Focus source:** horizontal position (`posX`) mapped to discrete slots.
- **Activation source:** cap button edge or hold-complete (depending on current screen logic).
- **Fallback:** touch buttons still work because `TrikiFocusRow` is a normal SwiftUI `Button`.

## Recommended screen pattern

1. Render rows/items with deterministic indices (`0..<count`).
2. Attach `.trikiUIScreen(itemCount:isActive:showsPhoneHUD:onActivate:)` at the container level.
3. Keep `onActivate` side effects idempotent (navigation, submit, continue).
4. Toggle `isActive` when overlays/modals should temporarily own focus.
5. Optionally hide HUD (`showsPhoneHUD: false`) for TV-first screens.

## Side effects and gotchas

- Reconfiguring `itemCount` while active resets navigation mapping.
- Leaving `isActive = true` on hidden screens can steal focus updates.
- If your menu feels jittery, tune `MotionConfig` deadzones and smoothing in UI mode.

## Where to look in the sample app

- `app/UI/TrikiUI/TrikiUIComponents.swift`
- `app/UI/TrikiUI/TrikiUINavigator.swift`
- `app/UI/TrikiUI/TrikiFocusGate.swift`
- `app/UI/TrikiUI/TrikiHoldTracker.swift`
- `app/UI/Quiz/QuizFlowView.swift`
- `app/UI/GameCalibrationView.swift`

[GameInput](./game-input) · [MotionSDK](./motion-sdk) · [Architecture](./architecture)
