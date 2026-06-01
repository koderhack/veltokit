---
title: Module map
---

# VeltoKit module map

Source lives in [`VeltoKit/`](https://github.com/koderhack/veltokit/tree/main/VeltoKit). All public APIs are `public` unless noted.

## Core

| File | Types | Notes |
|------|-------|-------|
| `MotionSDK.swift` | `MotionSDK` | Facade: `connect`, `pollInput`, ingress, `input` |
| `MotionSDK+Connection.swift` | (extension) | BLE pipeline, `pollInput`, calibration helpers |
| `MotionEngine.swift` | `MotionEngine` | Per-frame pipeline, calibration |
| `MotionProcessor.swift` | `MotionProcessor` | Paddle / pointer math (internal) |
| `GestureDetector.swift` | `GestureDetector` | Throw FSM (internal) |
| `ButtonDetector.swift` | `ButtonDetector` | Click edge (internal) |
| `GameInput.swift` | `GameInput` | Output contract |
| `MotionConfig.swift` | `MotionConfig`, `MotionOutput`, `MotionDebug` | Tuning + presets |
| `MotionMode.swift` | `MotionMode` | `.paddle` `.pointer` `.gesture` |
| `InputAdapter.swift` | `InputAdapter` | SDK-only convenience |

## BLE (VeltoKit)

| File | Types | Notes |
|------|-------|-------|
| `BLE/BLEManager.swift` | `BLEManager` | Scan, connect, notify → `rxBytes` |
| `BLE/BLEByteProbe.swift` | `BLEByteProbe` | DEV hex probe |
| `Motion/MotionParser.swift` | `MotionParser` | Tilt/gyro blocks for `pollInput` |
| `BLEGyroParser.swift` | `BLEGyroParser`, `GyroTriple` | `0x22 0x00` blocks, `/2000` scale |
| `BLEButtonDecoder.swift` | `BLEButtonDecoder` | Header `0x22`, button index `1` |

## Supporting

| File | Types |
|------|-------|
| `MotionAxisMapping.swift` | `MotionAxisMapping`, `MotionAxisSource` |
| `MotionSensorInput.swift` | `MotionSensorInput` (tilt vs gyro block) |
| `PointerConfig.swift` | `PointerDirection` |
| `TrikiSensors.swift` | `TrikiSensors` (filled by Platform parser) |
| `TMKMath.swift` | clamps, helpers |
| `MotionPaddleLog.swift` | DEV logging hooks |

## Platform (sample app only — `app/Platform/`)

| File | Types |
|------|-------|
| `TrikiInputAdapter.swift` | Forwards `connect` / `pollInput` to `MotionSDK` + calibration UI |

## Related repo docs

- [`docs/ARCHITECTURE.md`](https://github.com/koderhack/veltokit/blob/main/docs/ARCHITECTURE.md) — full-app architecture (PL)
- [`VeltoKit/README.md`](https://github.com/koderhack/veltokit/blob/main/VeltoKit/README.md) — short developer readme
