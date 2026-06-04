---
sidebar_position: 3
title: Quick Start
description: Connect and read GameInput — VeltoKit
---

# Quick Start

**Start with [Integration recipes](sdk/recipes)** — four copy-paste patterns (Pong, UI, Dart, Bowling).

Add VeltoKit via [SPM or CocoaPods](installation), then:

## Minimal loop

```swift
import VeltoKit

let motion = MotionSDK()
motion.configureForPong()   // or .configureForMenu() / pointer / gesture — see recipes
motion.connect()            // scan + auto-connect (physical iPhone)

// Each frame (~60 Hz):
let input = motion.pollInput(deltaTime: dt)
```

Add to `Info.plist`: `NSBluetoothAlwaysUsageDescription`.

## Pick a recipe

| You build… | Call | Doc |
|------------|------|-----|
| Pong | `configureForPong()` + `TrikiSimplePong` | [Recipes §1](sdk/recipes#1-pong) |
| Menu / Quiz | `configureForMenu()` + `TrikiUIPicker` | [Recipes §2](sdk/recipes#2-ui--quiz-menu) |
| Dart | `configureForPointerGame()` | [Recipes §3](sdk/recipes#3-pointer-games-dart) |
| Bowling | `configureForGestureGame()` | [Recipes §4](sdk/recipes#4-gesture-games-bowling) |

## Manual bytes (your own BLE stack)

```swift
let motion = MotionSDK()
motion.configureForPong()
motion.enqueueBLE(bytes)
motion.updateFrame(deltaTime: dt)
let input = motion.input
```

[Recipes](sdk/recipes) · [GameInput](sdk/game-input) · [Installation](installation)
