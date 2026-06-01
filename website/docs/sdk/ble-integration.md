---
title: BLE integration
---

# BLE integration

VeltoKit accepts **bytes** and optional **rawX**. You can let **`MotionSDK`** scan and connect, feed bytes yourself, or use the sample **`TrikiInputAdapter`** for calibration UI.

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
- **Rising edge** `0→1` → `primaryAction` for one frame

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

Thin wrapper around `MotionSDK` for the **gametriki** demo (calibration prompts, `ObservableObject`):

```swift
let adapter = TrikiInputAdapter()
adapter.connect()                    // → motionSDK.connect()
adapter.setInputMode(.gesture)

let input = adapter.pollInput(deltaTime: dt)
```

| API | Role |
|-----|------|
| `connect()` / `disconnect()` | Forwards to `motionSDK` |
| `performCalibration()` | `motionSDK.calibrateNeutralPose()` + UI state |
| `pollInput(deltaTime:)` | Forwards to `motionSDK.pollInput` + auto-calibration prompt |
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
