---
sidebar_position: 3
title: Quick Start
description: Connect and read GameInput — VeltoKit
---

# Quick Start

Add VeltoKit via [SPM or CocoaPods](installation), then:

## Simple flow (BLE built in)

```swift
import VeltoKit

let motion = MotionSDK()
motion.setMode(.paddle)   // or .pointer / .gesture

motion.connect()          // scan + auto-connect (physical iPhone)

// Each frame (~60 Hz) in your game loop:
let input = motion.pollInput(deltaTime: dt)
paddle.x = CGFloat(input.posX) * viewWidth
if input.didShoot { serveBall() }
```

Add to `Info.plist`: `NSBluetoothAlwaysUsageDescription` (and `NSBluetoothPeripheralUsageDescription` on older iOS if needed).

## Manual bytes (your own BLE stack)

If you already have `CBCentralManager` notify callbacks:

```swift
let sdk = MotionSDK()
sdk.setMode(.paddle)
sdk.enqueueBLE(bytes)
sdk.updateFrame(deltaTime: dt)
let input = sdk.input
```

## Pick a mode

| Game | `setMode` | Use |
|------|-----------|-----|
| Pong, Quiz | `.paddle` | `posX`, `primaryAction` |
| Dart | `.pointer` | `posX`, `posY` |
| Bowling | `.gesture` | `shotTriggered`, `throwPower` |

[Game examples](examples/pong) · [GameInput](sdk/game-input) · [Installation](installation)
