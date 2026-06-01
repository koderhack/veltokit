---
title: Configuration
---

# Configuration

Tuning lives in **`MotionConfig`**. Start with presets — only override when a game feels jittery or throws are weak.

## Presets

```swift
motion.setMode(.paddle)
// same as:
motion.config = MotionConfig.preset(for: .paddle)
```

| Mode | Preset highlights |
|------|-------------------|
| `.paddle` | Gyro Y → delta, auto-offset, `paddleScreenScale` 66, no reference drift |
| `.pointer` | Rotation accumulation, higher smoothing |
| `.gesture` | Pull-back / thrust thresholds, cooldown 0.45s |

## Common tweaks

```swift
var cfg = MotionConfig.preset(for: .gesture)
cfg.gestureThreshold = 0.30
cfg.gestureMinThrustSpeed = 0.14
cfg.inputSmoothing = 0.40
motion.config = cfg
```

### Paddle jitter

| Field | Direction |
|-------|-----------|
| `paddleMicroDeadzone` | ↑ less micro noise |
| `paddleRawSmoothing` | ↑ smoother raw (more lag) |
| `paddleSmoothRetain` | ↑ heavier smoothing |
| `paddleStillThreshold` | ↑ stricter auto-calib when still |

### Weak throws

| Field | Direction |
|-------|-----------|
| `gesturePullbackDelta` | ↓ easier arm |
| `gestureMinThrustSpeed` | ↓ register slower throws |
| `gestureThreshold` | ↓ more sensitive |

## Axis mapping

```swift
motion.config.axisMapping.inputX = .gyroY
motion.config.axisMapping.invertX = false
```

Sources: `.gyroX`, `.gyroY`, `.gyroZ`, `.rotation` (Triki twist field).

## MotionOutput / MotionDebug

After `updateFrame`:

```swift
let out = motion.output   // x, y, didShoot, paddleAtRest
let dbg = motion.debug      // rawX, relY, paddleSteer, gyroBlockIndex, …
```

Use **`debug`** in DEV overlays only — do not ship gameplay logic on debug fields.

## Full field reference

Every property is documented inline in [`MotionConfig.swift`](https://github.com/koderhack/veltokit/blob/main/VeltoKit/MotionConfig.swift). Legacy paddle fields remain for DEV UI compatibility but are unused in the current paddle model.

[Gestures](./gestures) · [MotionSDK](./motion-sdk)
