---
title: BLE integration
---

# BLE integration

VeltoKit accepts **bytes** and optional **rawX**. For app code, start with [Integration recipes](./recipes); open this page when debugging packets or BLE modes.

## Gamepad pipeline (`TrikiGameController`)

Layered stack for firmware that ships **filtered int16 packets** at ~20–30 Hz:

| Layer | Type | Role |
|-------|------|------|
| BLE | `TrikiBLEManager` | Scan, connect, UUID cache, auto-reconnect, notify |
| Parser | `TrikiParser` | `parse(Data)` → `ParsedMotionData`; preset **v2** (int16 @2,4,6 ÷100), legacy + fallback |
| Motion | `TrikiMotionEngine` | Velocity, direction, shake / tilt / swing |
| API | `TrikiGameController` | `TrikiGameInput`, `onMove` / `onShake` / `onAction` |

```swift
let triki = TrikiGameController()
triki.inputMode = .game   // or .smooth
triki.onMove { direction in /* -1…1 */ }
triki.onShake { }
triki.onAction { }
triki.connect()

// Game loop:
let pad = triki.tick(deltaTime: dt)
// pad.direction, pad.velocity, pad.isMoving — no raw X/Y/Z API
```

`MotionSDK.connect()` uses this pipeline internally and still publishes **`GameInput`** for existing games.

### Adaptive BLE mode (`TrikiBLEMonitor`)

The stack measures **Δt between notify packets** and debounces mode changes (3 consecutive samples):

| Mode | Typical Δt | `TrikiInputStrategy` | Game drivers |
|------|------------|----------------------|--------------|
| `fast` | &lt; 30 ms | `.velocity` | Δpos + position follow |
| `normal` | 30 ms – 200 ms | `.hybrid` | Δpos + tilt hold |
| `lowPower` | &gt; 200 ms | `.threshold` | Tilt edges + debounce |

Each `pollInput` enriches `GameInput` with `bleMode`, `frameDeltaX/Y`, `trikiVelocity`, `tiltLeft`/`tiltRight`.

Use SDK drivers (presets per mode):

```swift
var paddle = TrikiPaddleDriver()
var menu = TrikiMenuDriver()
var pointer = TrikiPointerDriver()
var lateral = TrikiLateralDriver()

let x = paddle.steer(current: paddleX, input: input, deltaTime: dt, courtCenter: center)
let menuStep = menu.step(input: input, deltaTime: dt, slots: 4, currentSelection: selected)
```

| Driver | Sample games |
|--------|----------------|
| `TrikiPaddleDriver` | Pong — bezpośrednio `posX` w grze (jak przed adaptive input) |
| `TrikiMenuDriver` | Quiz |
| `TrikiPointerDriver` | Dart aim |
| `TrikiLateralDriver` | Bowling aim |

**FAST mode shaping:** high-rate notify can spike Δpos — `TrikiVelocityController` applies deadzone → clamp → sensitivity per mode before drivers move gameplay. Source: `VeltoKit/Triki/TrikiVelocityController.swift`.

### Game-specific input (`TrikiGameInputManager`)

Per-game strategies on **raw** `velocity = current − last` (never clamped for events). Movement uses filtered signal only in Pong.

| `GameMode` | Strategy |
|------------|----------|
| `.pong` | **`TrikiControlStyle`:** `.raw` (×2.5, dz 0.3), `.arcade` (×3), `.smooth` (EMA) — default **raw** |
| `.quiz` | `posX` → slot A–D; **przycisk BLE** (edge + cooldown) = zatwierdzenie — bez hold / velocity |
| `.bowling` | Peak velocity + release detection, 0.7 s cooldown |
| `.dart` | Spike > 7 + 0.5 s cooldown |

```swift
var inputMgr = TrikiGameInputManager(mode: .pong)
inputMgr.config.pongControlStyle = .raw  // .arcade | .smooth
let frame = inputMgr.process(input: input, deltaTime: dt)
inputMgr.applyPongMovement(to: &paddleX, frame: frame, minX: minX, maxX: maxX)
```

Source: `VeltoKit/Triki/TrikiGameInputManager.swift`. Sample games wire this in `app/Games/`.

| Mode | deadzone | max Δ | sensitivity |
|------|----------|-------|-------------|
| `fast` | 0.004 | 0.012 | 0.22 |
| `normal` | 0.0018 | 0.028 | 0.42 |
| `lowPower` | 0.005 | 0.045 | 0.62 |

```swift
let shaped = TrikiVelocityController.shape(input.frameDeltaX, mode: input.bleMode)
```

```swift
triki.onModeChanged { mode in
  switch mode {
  case .fast: /* full UI */
  case .lowPower: /* show triki.idleStatusMessage */
  default: break
  }
}
let mode = triki.getBLEMode()           // or motion.trikiBLEMode
triki.debugBLEMonitorLogging = true     // Δt + transitions in console
```

## Simple connection (built into MotionSDK)

```swift
import VeltoKit

let motion = MotionSDK()
motion.setMode(.paddle)

motion.connect()    // BLE scan; auto-connect when one likely device is found

// ~60 Hz in your game loop:
let input = motion.pollInput(deltaTime: dt)
```

| API | Role |
|-----|------|
| `connect()` | Start scan; auto-connect when a single likely match (name contains `triki`) |
| `disconnect()` | Drop session and reset motion state |
| `pollInput(deltaTime:)` | Drain parser + `updateFrame` → enriched `GameInput` |
| `isConnected` / `isReceiving` | GATT link + packets in the last ~350 ms |
| `liveInput` | Throttled `@Published` copy for SwiftUI HUD |
| `calibrateNeutralPose()` | `calibrateCenter()` + paddle reset (same as sample calibration) |

Requires `NSBluetoothAlwaysUsageDescription` in `Info.plist`. Test on a **physical iPhone**.

## Packet shape (lab hardware)

Documented from `BLEGyroParser` + `BLEButtonDecoder`:

### Gyro / IMU blocks

- Repeated blocks: **`0x22 0x00`** + 6 bytes (3× int16 LE)
- Normalized axis value: **raw / 2000** (`BLEGyroParser.gyroDivisor`)
- Multi-block notify: **first block** → tilt (scaled `/80`), **last block** → gyro used for motion

### Button

- Packet header **`0x22`** on `bytes[0]`
- Button state on **`bytes[1]`** (`0` / `1`)
- **Rising edge** `0→1` → one-frame click impulse (`ButtonDetector.consumeClick()`)

`primaryAction` mapping depends on `MotionMode`:

| Mode | Maps to `primaryAction` |
|------|-------------------------|
| `.paddle` | BLE click edge **only** |
| `.pointer`, `.gesture` | Click **or** throw **or** `TrikiMotionEngine.isAction` |

Triki gamepad velocity (`onAction`) is still available on `GameInput.trikiVelocity` / `isMoving` — it does **not** set `primaryAction` in paddle mode, so Quiz and menus are not auto-confirmed by fast tilts.

:::caution Unofficial
Packet layout is reverse-engineered for education. Your peripheral may differ — log hex in DEV and adapt.
:::

## Your own BLE stack (no `connect()`)

If you already have `CBCentralManager` notify callbacks:

```swift
let motion = MotionSDK()
motion.setMode(.paddle)

motion.enqueueBLE(bytes)           // in notify handler
let input = motion.updateFrame(deltaTime: dt)  // or read motion.input
```

Paddle mode may use `BLEGyroParser.gyroRawFromPacket` inside `enqueueBLE` without buffering full blocks.

## TrikiInputAdapter (sample app — optional)

Thin wrapper around `MotionSDK` for the **gametriki** demo (`ObservableObject`, HUD wiring):

```swift
let adapter = TrikiInputAdapter()
adapter.connect()                    // → motionSDK.connect()
adapter.setInputMode(.gesture)

let input = adapter.pollInput(deltaTime: dt)
```

| API | Role |
|-----|------|
| `connect()` / `disconnect()` | Forwards to `motionSDK` |
| `performCalibration()` | Manual neutral pose — Dev Mode **ZERO** or your own UI |
| `pollInput(deltaTime:)` | Forwards to `motionSDK.pollInput` |
| `motionSDK` | Escape hatch to low-level SDK |

Type alias: `MotionInputProvider = TrikiInputAdapter`. Source: `app/Platform/` (not required for SPM-only apps).

### Paddle path in adapter

For `.paddle`, adapter uses `MotionParser` tilt refresh + `updateFrame` without full gyro block drain — lower latency for Pong.

### Gesture / pointer path

`parser.flush()` → `setIngressSupplement` → `updateFrame` → merges impulses (shake) into `GameInput`.

## Choose a path

| You want… | Use |
|-----------|-----|
| Fastest integration | `motion.connect()` + `pollInput()` |
| Existing BLE code | `enqueueBLE` + `updateFrame` |
| Sample app UX | Copy `TrikiInputAdapter` from `app/Platform` |
| Unit tests | `ingestTrikiFrame` or inject bytes without radio |

## InputProvider protocol

```swift
public protocol InputProvider: AnyObject {
  func pollInput(deltaTime: TimeInterval?) -> GameInput
}
```

Swap your own provider in tests; games stay on `GameInput`.

[Installation](../installation) · [Architecture](./architecture)
