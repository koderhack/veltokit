---
sidebar_position: 1
title: SDK overview
description: VeltoKit — MotionSDK and GameInput
---

# VeltoKit SDK

**VeltoKit** maps BLE motion bytes → **`GameInput`** each frame. No UI, no CoreBluetooth in the core target.

:::tip Docs search & AI skills
Use **Search** in the top navbar (`⌘K` / `Ctrl+K`) to find any topic.  
Download Cursor / Claude prompt files on [For Cursor Claude](../for-cursor-claude#download-ai-skills) (footer: **AI skills (download)**).
:::

## Integrate (MotionSDK)

**Simple path** — BLE scan + read each frame:

```swift
import VeltoKit

let motion = MotionSDK()
motion.setMode(.paddle)
motion.connect()

let input = motion.pollInput(deltaTime: dt)
```

**Manual path** — your own `CBCentralManager`:

```swift
motion.enqueueBLE(bytes)
motion.updateFrame(deltaTime: dt)
let input = motion.input
```

Optional: **`TrikiInputAdapter`** in the sample app adds calibration UI on top of `MotionSDK` — see [BLE integration](./ble-integration).

## Modes

| Mode | Sample games |
|------|----------------|
| `.paddle` | [Pong](../examples/pong), [Quiz](../examples/quiz) |
| `.pointer` | [Dart](../examples/dart) |
| `.gesture` | [Bowling](../examples/bowling) |

```swift
motion.config = MotionConfig.preset(for: .paddle)  // optional tuning
```

## Docs

- [MotionSDK](./motion-sdk) — API
- [GameInput](./game-input) — fields
- [Triki UI navigation](./triki-ui) — `.trikiUIScreen`, focus, hold, activation lifecycle
- [BLE](./ble-integration) — packets
- [Examples](../examples/pong) — copy-paste per game

[Quick start](../quick-start)
