# VeltoKit

Swift (iOS 16+) — **BLE → `GameInput`**. `connect()` + `pollInput()` built in (CoreBluetooth). No UI in this target.

## Use it

```swift
import VeltoKit

let motion = MotionSDK()
motion.setMode(.paddle)
motion.connect()

let input = motion.pollInput(deltaTime: dt)
```

## Modes

| Mode | Games (sample) |
|------|----------------|
| `.paddle` | Pong, Quiz |
| `.pointer` | Dart |
| `.gesture` | Bowling |

## Install

**SPM (Xcode):** Add package `https://github.com/koderhack/veltokit` → product **VeltoKit**.

**CocoaPods:** `pod 'VeltoKit', '~> 0.1.0'`

Docs: https://koderhack.github.io/veltokit/docs/installation

Optional **Platform** in the sample app (`app/Platform`): `TrikiInputAdapter` forwards to `MotionSDK` and adds calibration prompts.

