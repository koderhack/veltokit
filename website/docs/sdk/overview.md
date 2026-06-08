---
sidebar_position: 1
title: SDK overview
description: VeltoKit — MotionSDK and GameInput
---

# VeltoKit SDK

**VeltoKit** maps BLE motion bytes → **`GameInput`** each frame. No UI, no CoreBluetooth in the core target.

:::info Names (do not confuse)
| Name | What it is |
|------|------------|
| **VeltoKit** | Swift SDK in `VeltoKit/` — link this in your app |
| **gametriki** | Sample iOS app in `app/` — not a second framework |
| **Triki** | Informal name for the BLE cap + app UI layer (`TrikiInputAdapter`, `TrikiUI`) |

**API source of truth:** `VeltoKit/GameInput.swift` and `VeltoKit/MotionSDK.swift` — not marketing text on the website. If docs and code disagree, trust the Swift files.
:::

:::tip Docs search & AI skills
Use **Search** (`⌘K` / `Ctrl+K`). Assistants: [Context for AI](../ai-context) · repo root `AGENTS.md`.
Use **Search** in the top navbar (`⌘K` / `Ctrl+K`) to find any topic.  
Download Cursor / Claude prompt files on [For Cursor Claude](../for-cursor-claude#download-ai-skills) (footer: **AI skills (download)**).
:::

## Integrate (MotionSDK)

**Start here:** [Integration recipes](./recipes) — Pong, UI menu, Dart, Bowling.

**Simple path** — BLE scan + read each frame:

```swift
import VeltoKit

let motion = MotionSDK()
motion.configureForPong()   // or configureForMenu / pointer / gesture
motion.connect()

let input = motion.pollInput(deltaTime: dt)
```

**Manual path** — your own `CBCentralManager`:

```swift
motion.enqueueBLE(bytes)
motion.updateFrame(deltaTime: dt)
let input = motion.input
```

Optional: **`TrikiInputAdapter`** in the sample app adds calibration UI on top of `MotionSDK` — see [BLE integration](./ble-integration). For cap calibration + a motion-driven menu (Quiz-style), see [Triki UI — calibration & simple menu](./triki-ui#calibration-and-simple-menu).

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

- [Integration recipes](./recipes) — **four copy-paste patterns**
- [MotionSDK](./motion-sdk) — API
- [GameInput](./game-input) — fields
- [Triki UI navigation](./triki-ui) — `.trikiUIScreen`, focus, hold, activation lifecycle
- [BLE](./ble-integration) — packets
- [Godot plugin](../godot) — GDScript gyro API, desktop simulator, Android stub (`godot/`)
- [Examples](../examples/pong) — copy-paste per game

[Quick start](../quick-start)
