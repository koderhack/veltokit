---
title: GameInput
---

# GameInput

`GameInput` is the **only** type sample games use in `update(input:deltaTime:)`. Populate it via `MotionSDK.input` or `TrikiInputAdapter.pollInput()`.

## Primary game fields

| Field | Type | Typical use |
|-------|------|-------------|
| `posX` | `Double` | Paddle / aim horizontal `0…1` (center ≈ 0.5) |
| `posY` | `Double` | Vertical aim (pointer mode) |
| `primaryAction` | `Bool` | **Mode-dependent** — see [Primary action by mode](#primary-action-by-mode) |
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
Use a **rising-edge gate with cooldown** on `primaryAction`, not `sensors.click` (HUD flag can stay high ~250 ms). Sample app: `TrikiButtonConfirmGate` in `app/UI/TrikiUI/`.
:::

```swift
var confirmGate = TrikiButtonConfirmGate()

func tick(dt: TimeInterval) {
  let input = motion.pollInput(deltaTime: dt)
  // … update selection from posX …
  if confirmGate.consume(input: input, deltaTime: dt) {
    confirmSelection()
  }
}
```

## Sensors bundle

`sensors: TrikiSensors` — raw-ish telemetry for HUD (tilt, gyro, click flag). Filled by **Platform** `MotionParser`, not core VeltoKit.

Do **not** treat `sensors.click` as a one-shot confirm in game logic — prefer `primaryAction` (paddle) or `TrikiButtonConfirmGate`.

## Adaptive drivers (Triki BLE modes)

`TrikiBLEMode.inputStrategy` → `.velocity` | `.hybrid` | `.threshold`.

```swift
var driver = TrikiPaddleDriver()
paddleX = driver.steer(current: paddleX, input: input, deltaTime: dt, courtCenter: center)
```

See [BLE integration](./ble-integration) · `TrikiAdaptiveInput.swift` · `TrikiVelocityController.swift` · **`TrikiGameInputManager.swift`** (per-game: pong steps, quiz debounce, bowling peak, dart spike).

## Example: Pong

```swift
private var paddle = TrikiPaddleDriver()

func update(input: GameInput, deltaTime: TimeInterval) {
  paddleX = paddle.steer(
    current: paddleX,
    input: input,
    deltaTime: deltaTime,
    courtCenter: courtWidth / 2
  )
}
```

## Example: Dart

```swift
private var pointer = TrikiPointerDriver()

if input.gesturePrimed { showPullBackHint() }
if input.shotTriggered { launch(power: input.throwPower) }
```

## Example: Quiz

Tilt → slot A–D; **button edge** → submit. Sample: `QuizGame.swift` + `TrikiFocusGate` for stable slot changes.

```swift
var confirmGate = TrikiButtonConfirmGate()

// posX → selected (smoothed, adjacent steps only)
if confirmGate.consume(input: input, deltaTime: dt) {
  confirmSelection(selected)
}
```

[MotionSDK](./motion-sdk) · [Gestures](./gestures)
