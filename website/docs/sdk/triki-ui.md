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
| `TrikiButtonConfirmGate` | Debounced rising edge on `primaryAction` (BLE button only in `.paddle`) |
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
.trikiUIScreen(
  itemCount: 3,
  isActive: true,
  showsPhoneHUD: true,
  preferButtonConfirm: true   // Quiz-style: button only, no hold auto-OK
) { index in
  handleSelection(index)
}
```

| Parameter | Default | Effect |
|-----------|---------|--------|
| `preferButtonConfirm` | `false` | When `true`: HUD hides hold bar; navigator skips hold-to-activate; only BLE button confirms |

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
BLE / parser -> posX -> TrikiFocusGate -> focused slot
  -> TrikiButtonConfirmGate (primaryAction edge) OR hold -> onActivate(index)
```

- **Focus source:** horizontal position (`posX`) mapped to discrete slots (`TrikiUIMath.focusedSlot`).
- **Activation source:** debounced **BLE button edge** (`TrikiButtonConfirmGate` on `primaryAction`); optional **hold** when `preferButtonConfirm == false`.
- **Fallback:** touch buttons still work because `TrikiFocusRow` is a normal SwiftUI `Button`.

:::caution False confirms
Do not activate on `input.primaryAction` every frame while it stays `true`, and do not use `sensors.click` as confirm — both cause accidental double-OK. The sample navigator uses `TrikiButtonConfirmGate` (~0.65 s cooldown).
:::

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

## Calibration and simple menu {#calibration-and-simple-menu}

Triki UI lives in the **sample app** only. You need:

1. `MotionInputProvider` + `TrikiUINavigator` as `@EnvironmentObject` (see `gametrikiApp.swift`).
2. BLE: `motion.connect()` (Main menu → **POŁĄCZ BLE** or `ConnectView`).
3. **Calibration** — neutral pose while holding the cap:

```swift
// Same as TrikiCalibrationView — sets SDK neutral center
motion.performCalibration()  // → MotionSDK.calibrateNeutralPose()
```

Calibration is **manual** in the sample app (Dev Mode → **ZERO**, or your own screen). There is no forced calibration sheet on connect.

4. **UI mode** for horizontal menu selection (Quiz category picker uses this):

```swift
GameManager.applyUIMode(to: motion)  // .paddle tuning for posX slots + hold
```

5. **Menu screen** — mirror `QuizFlowView` category pick:

```swift
import SwiftUI
import VeltoKit

struct SimpleTrikiMenuView: View {
  @EnvironmentObject private var motion: MotionInputProvider
  @EnvironmentObject private var trikiUI: TrikiUINavigator

  private let items = ["Start", "Settings", "Quit"]
  @State private var lastChoice: String?

  var body: some View {
    VStack(spacing: 12) {
      Text("Triki: turn = focus · hold or button = OK")
        .font(.caption.monospaced())

      ForEach(Array(items.enumerated()), id: \.offset) { i, title in
        TrikiFocusRow(index: i, title: title, accent: .cyan, icon: "circle.fill")
      }

      if let lastChoice {
        Text("Selected: \(lastChoice)")
      }
      Spacer()
    }
    .padding()
    .trikiUIScreen(itemCount: items.count, isActive: true, preferButtonConfirm: true) { index in
      guard items.indices.contains(index) else { return }
      lastChoice = items[index]
    }
    .onAppear {
      if !motion.isConnected { motion.connect() }
      GameManager.applyUIMode(to: motion)
    }
  }
}
```

**Reference implementation:** `app/UI/Quiz/QuizFlowView.swift` — `trikiNavigationActive` only in `.categoryPick`, `preferButtonConfirm: true`, rows use `TrikiFocusRow`, activation in `handleTrikiActivate`.

| Step | Quiz equivalent |
|------|-----------------|
| Calibrate (optional) | Dev Mode **ZERO** or `motion.performCalibration()` |
| Menu with Triki | `.categoryPick` + `.trikiUIScreen(preferButtonConfirm: true)` |
| In-round confirm | `QuizGame` + `TrikiButtonConfirmGate` |
| Touch fallback | `TrikiFocusRow` is a `Button` |

## Where to look in the sample app

- `app/UI/TrikiCalibrationView.swift` — calibration UX
- `app/UI/MainMenu.swift` — BLE + calibration sheet wiring
- `app/UI/TrikiUI/TrikiUIComponents.swift`
- `app/UI/TrikiUI/TrikiUINavigator.swift`
- `app/UI/TrikiUI/TrikiFocusGate.swift`
- `app/UI/TrikiUI/TrikiButtonConfirmGate.swift`
- `app/UI/TrikiUI/TrikiHoldTracker.swift`
- `app/UI/Quiz/QuizFlowView.swift`
- `app/UI/GameCalibrationView.swift`

[GameInput](./game-input) · [MotionSDK](./motion-sdk) · [Architecture](./architecture)
