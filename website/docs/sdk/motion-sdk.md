---
title: MotionSDK API
---

# MotionSDK API

`@MainActor` facade — call every frame from your game loop.

:::tip Start with [Integration recipes](./recipes)
`configureForPong()` · `configureForMenu()` · `configureForPointerGame()` · `configureForGestureGame()`
:::

## Connect + read (recommended)

```swift
let motion = MotionSDK()
motion.configureForPong()

motion.connect()                      // BLE scan + auto-connect

let input = motion.pollInput(deltaTime: dt)   // GameInput each frame
```

| API | Role |
|-----|------|
| `connect()` | Start BLE scan; auto-connect when one likely controller is found |
| `disconnect()` | Drop BLE session |
| `pollInput(deltaTime:)` | Parse packets + `updateFrame` → `GameInput` |
| `isConnected` / `isReceiving` | Link + live packet stream |
| `liveInput` | Throttled copy for SwiftUI HUD |

Requires Bluetooth usage strings in `Info.plist`. See [BLE integration](./ble-integration).

## Manual bytes (your own BLE)

```swift
motion.enqueueBLE(bytes)              // your notify callback
motion.updateFrame(deltaTime: dt)
let input = motion.input
```

Legacy: `motion.update(rawX:bytes:deltaTime:)`.

## Mode

```swift
motion.setMode(.gesture)
motion.config = MotionConfig.preset(for: .gesture)
```

## Calibration

```swift
motion.calibrateNeutralPose()   // connect + pollInput path
motion.resetPaddleCenter()
motion.flipPaddleOffsetSign()

// Low-level (same engine):
motion.engine.calibrateCenter()
motion.engine.resetPaddleMotion()
```

## Ingress

| Method | When |
|--------|------|
| `enqueueBLE(_:)` | Raw notify payload |
| `ingestTrikiFrame(gyroX:gyroY:gyroZ:rotation:)` | Already parsed floats |

See [GameInput](./game-input) · [Recipes](./recipes) · [BLE](./ble-integration)
