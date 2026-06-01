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
| `primaryAction` | `Bool` | BLE click **or** gesture shot this frame |
| `shotTriggered` | `Bool` | Gesture throw edge (Dart/Bowling) |
| `throwPower` | `Double` | `0…1` strength when `shotTriggered` |
| `gesturePrimed` | `Bool` | Pull-back before throw (UI hint) |
| `pointerDirection` | `PointerDirection` | `.left` `.right` `.up` `.down` `.center` |

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

## Sensors bundle

`sensors: TrikiSensors` — raw-ish telemetry for HUD (tilt, gyro, click flag). Filled by **Platform** `MotionParser`, not core VeltoKit.

## Example: Pong

```swift
func update(input: GameInput, deltaTime: TimeInterval) {
  paddle.center.x = CGFloat(input.posX) * courtWidth
}
```

## Example: Dart

```swift
if input.gesturePrimed {
  showPullBackHint()
}
if input.shotTriggered {
  launch(power: input.throwPower)
}
```

## Example: Quiz

```swift
highlightAnswer(at: input.posX)
if input.primaryAction {
  confirmSelection()
}
```

[MotionSDK](./motion-sdk) · [Gestures](./gestures)
