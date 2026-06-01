---
sidebar_position: 4
title: Getting Started
description: Clone veltokit, run on device, explore sample games
---

# Getting Started

## Requirements

| | |
|---|---|
| **OS** | iOS 16+ on a physical device (BLE) |
| **Tools** | Xcode 15+, Apple developer signing |
| **Hardware** | BLE cap-style controller (see [BLE integration](sdk/ble-integration)) or mock bytes in DEV |
| **Expectations** | Unofficial stack — you debug packet layout yourself if hardware differs |

## 1. Clone and open

```bash
git clone https://github.com/koderhack/veltokit.git
cd veltokit
cd app && open gametriki.xcodeproj
```

Select the **gametriki** scheme and your iPhone (not Simulator for real BLE).

## 2. First run

1. Launch the app → **Connect** screen.
2. Power on your BLE controller; wait for scan results.
3. Tap the device → wait for **connected** + packet stream.
4. **Calibrate** when prompted (hold level, center).
5. Main menu → pick **Pong**, **Dart**, **Bowling**, or **Quiz**.

## 3. What you are running

```text
app/              gametriki.xcodeproj + sample sources
  ├── Platform/   TrikiInputAdapter (UI calibration)
  ├── Engine/     GameEngine, sessions
  └── Games/      Game logic + rendering
VeltoKit/         MotionSDK.connect() + pollInput() → GameInput
```

Games never import CoreBluetooth — they read `GameInput` via `TrikiInputAdapter` or `MotionSDK` directly.

## 4. DEV mode

From the menu, open **DEV** (if enabled in your build) to:

- Inspect raw BLE bytes and `MotionDebug`
- Tune `MotionConfig` live
- Probe packet headers (`0x22`, button on `bytes[1]`)

## 5. Documentation site locally

```bash
cd website
npm install
npm run start          # dev (one locale at a time)
npm run build && npm run serve   # EN + PL like production
```

## Next steps

| Goal | Doc |
|------|-----|
| Integrate SDK only | [Installation](installation) · [Quick start](quick-start) |
| Understand API | [SDK overview](sdk/overview) |
| Watch UI previews | [Demo](demo) |
| Per-game mapping | [Examples](examples/pong) |

[Quick start](quick-start) · [FAQ](faq)
