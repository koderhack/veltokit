---
sidebar_position: 2
title: Integration recipes
description: Four copy-paste patterns — Pong, UI menu, Dart, Bowling
---

# Integration recipes

Most apps need **one** of four patterns. Use **`MotionSDK.configure(for:)`** + a small helper from `TrikiRecipes.swift` — then `pollInput` every frame.

```swift
import VeltoKit

let motion = MotionSDK()
motion.connect()   // physical iPhone; see BLE doc for manual bytes

// In your game loop (~60 Hz):
let input = motion.pollInput(deltaTime: dt)
```

| Recipe | `configure(for:)` | Helper | Main fields |
|--------|-------------------|--------|-------------|
| [Pong](#1-pong) | `.pong` | `TrikiSimplePong` | `posX` |
| [UI / Quiz menu](#2-ui--quiz-menu) | `.menu` | `TrikiUIPicker` | `posX`, `bleButtonClick` |
| [Dart / pointer](#3-pointer-games-dart) | `.pointerGame` | `TrikiSimplePointer`, `TrikiGameActions` | `posX`, `posY`, `shotTriggered` |
| [Bowling / gesture](#4-gesture-games-bowling) | `.gestureGame` | `TrikiSimpleAim`, `TrikiGameActions` | `shotTriggered`, `bleButtonClick` |

Deep tuning: [GameInput](./game-input) · [BLE](./ble-integration) · [Configuration](./configuration).

---

## 1. Pong

```swift
motion.configureForPong()
var pong = TrikiSimplePong()
var paddleX = courtWidth / 2

func tick(dt: TimeInterval) {
  let input = motion.pollInput(deltaTime: dt)
  paddleX = pong.paddleX(
    current: paddleX,
    input: input,
    deltaTime: dt,
    courtWidth: courtWidth
  )
  paddleX = min(max(0, paddleX), courtWidth)
}
```

Shortcut: map `input.posX` directly if you do not need adaptive BLE shaping — see [Pong example](../examples/pong).

---

## 2. UI / Quiz menu

Tilt → focus slot · **physical button** (`bytes[1]`) → confirm. No hold required.

```swift
motion.configureForMenu()
var picker = TrikiUIPicker()

func tick(dt: TimeInterval) {
  let input = motion.pollInput(deltaTime: dt)
  if picker.tick(input: input, deltaTime: dt, slots: itemCount) {
    onActivate(picker.focusIndex)
  }
  highlightRow(picker.focusIndex)
}
```

- **`TrikiButtonGate`** — debounced edge on `bleButtonClick` (also used inside `TrikiUIPicker`).
- SwiftUI sample: [Triki UI](./triki-ui) (`.trikiUIScreen`, `preferButtonConfirm: true`).

---

## 3. Pointer games (Dart)

```swift
motion.configureForPointerGame()
var aim = TrikiSimplePointer()
var actions = TrikiGameActions()
var aimX = 0.5, aimY = 0.5

func tick(dt: TimeInterval) {
  let input = motion.pollInput(deltaTime: dt)
  (aimX, aimY) = aim.aim(currentX: aimX, currentY: aimY, input: input, deltaTime: dt)

  for event in actions.tick(input: input, deltaTime: dt) {
    switch event {
    case .primedToThrow: showPullBackHint()
    case .threw(let power): launchDart(power: power)
    case .buttonConfirmed: confirmSelection()
    }
  }
}
```

---

## 4. Gesture games (Bowling)

```swift
motion.configureForGestureGame()
var lateral = TrikiSimpleAim()
var actions = TrikiGameActions()
var aimX = 0.0

func tick(dt: TimeInterval) {
  let input = motion.pollInput(deltaTime: dt)

  aimX = lateral.step(
    current: aimX,
    lean: input.sensors.tiltY,
    input: input,
    deltaTime: dt
  )

  for event in actions.tick(input: input, deltaTime: dt) {
    switch event {
    case .threw(let power): rollBall(power: power, lateral: aimX)
    case .buttonConfirmed: startTurn()   // lobby or between players
    default: break
    }
  }
}
```

Throws use **`shotTriggered`** / gesture pipeline — not the cap button. Button is for **confirm** only (menu, turn start).

---

## Manual BLE (no `connect()`)

Same recipes; feed bytes yourself:

```swift
motion.configureForPong()
motion.enqueueBLE(bytes)
motion.updateFrame(deltaTime: dt)
let input = motion.input
```

[MotionSDK](./motion-sdk) · [Quick start](../quick-start)
