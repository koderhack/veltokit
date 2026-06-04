---
title: GameInput
---

# GameInput

`GameInput` is the **only** type games use in `update(input:deltaTime:)`. Get it from `motion.pollInput(deltaTime:)`.

:::tip Simple integration
Use [Integration recipes](./recipes) first — helpers wrap the fields below (`TrikiSimplePong`, `TrikiUIPicker`, `TrikiGameActions`).
:::

## Primary game fields

| Field | Type | Typical use |
|-------|------|-------------|
| `posX` | `Double` | Paddle / aim horizontal `0…1` (center ≈ 0.5) |
| `posY` | `Double` | Vertical aim (pointer mode) |
| `primaryAction` | `Bool` | **Mode-dependent** — see [Primary action by mode](#primary-action-by-mode) |
| `bleButtonClick` | `Bool` | BLE button edge (`bytes[1]`, 0→1) — latched ~120 ms after `pollInput` for HUD/menus |
| `shotTriggered` | `Bool` | Gesture throw edge (Dart/Bowling) |
| `throwPower` | `Double` | `0…1` strength when `shotTriggered` |
| `gesturePrimed` | `Bool` | Pull-back before throw (UI hint) |
| `pointerDirection` | `PointerDirection` | `.left` `.right` `.up` `.down` `.center` |
| `bleMode` | `TrikiBLEMode` | `fast` / `normal` / `lowPower` / `unknown` |
| `frameDeltaX`, `frameDeltaY` | `Double` | Δpos between `pollInput` frames (SDK) |
| `trikiVelocity` | `Double` | Speed from `TrikiMotionEngine` |
| `isMoving` | `Bool` | Triki gamepad motion flag |
| `tiltLeft`, `tiltRight` | `Bool` | Stable tilt edges (all modes) |

### Convenience

```swift
var didShoot: Bool { primaryAction || shotTriggered }
var action: Bool { primaryAction }
var steerX: Double { lateral }
```

## Motion / debug fields

| Field | Description |
|-------|-------------|
| `tiltX`, `tiltY` | Calibrated tilt (Platform may enrich) |
| `deltaX`, `deltaY` | Frame deltas |
| `lateral`, `lateralSmooth` | Adapter copies `output.x` for HUD |
| `velocityY` | Smoothed vertical velocity proxy |
| `rotation` | Pointer rotation output |
| `intensity` | Often `output.velocityX` |

## Impulse flags (Platform)

| Field | Source |
|-------|--------|
| `shake` | `MotionParser` impulses |
| `flick`, `spin` | Reserved / parser |
| `tiltLeft`, `tiltRight` | Optional |

## Primary action by mode

`MotionSDK.publishInput()` sets `primaryAction` from the active `MotionMode`:

| Mode | `primaryAction` is `true` when… |
|------|----------------------------------|
| `.paddle` | **BLE button rising edge only** (`ButtonDetector` / `bytes[1]` 0→1) |
| `.pointer`, `.gesture` | BLE click **or** gesture throw **or** Triki velocity action (`TrikiMotionEngine.isAction`) |

In **`.paddle`** (Pong, Quiz, Triki menus), motion velocity must **not** confirm selection — only the physical cap button.

:::tip Confirm pattern (Quiz / menus)
Use **`TrikiButtonGate`** or **`TrikiUIPicker`** from [Integration recipes](./recipes) — debounced edge on `bleButtonClick` (`bytes[1]`).
:::

```swift
var button = TrikiButtonGate()

func tick(dt: TimeInterval) {
  let input = motion.pollInput(deltaTime: dt)
  if button.consume(input: input, deltaTime: dt) {
    confirmSelection()
  }
}
```

## Sensors bundle

`sensors: TrikiSensors` — raw-ish telemetry for HUD (tilt, gyro, click flag). Filled by **Platform** `MotionParser`, not core VeltoKit.

Do **not** treat `sensors.click` as a one-shot confirm — use `bleButtonClick` via `TrikiButtonGate`.

## Advanced drivers

For custom tuning beyond [recipes](./recipes): `TrikiPaddleDriver`, `TrikiMenuDriver`, `TrikiPointerDriver`, `TrikiLateralDriver` in `TrikiAdaptiveInput.swift`.
See [BLE integration](./ble-integration) for adaptive BLE mode (`TrikiBLEMode`).
