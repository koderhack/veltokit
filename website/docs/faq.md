---
sidebar_position: 8
sidebar_label: Help
title: Help & questions
description: Answers about the gametriki app, BLE controller, TV, and the VeltoKit project
---

# Help & questions

Short answers if you **play gametriki**, use a **BLE motion cap**, or want to know what this project is.

:::tip Building your own game?
Use [Quick start](quick-start), [SDK overview](sdk/overview), and [Configuration](sdk/configuration) — this page is not an API reference.
:::

## Controller & connection

### What do I need?

| | |
|---|---|
| **Phone** | iPhone with **iOS 16+** |
| **Controller** | BLE cap-style device (tilt + button) — see [Introduction](intro) |
| **For real BLE** | Physical iPhone — not Simulator |

### The app does not find my controller

1. Turn on **Bluetooth** and power the cap.
2. Open **gametriki** → **Connect** and wait a few seconds for the list.
3. Tap your device and wait until it shows **connected**.
4. If nothing appears: move closer, restart the cap, restart the app.

Step-by-step: [Getting started](getting-started).

### Calibration — what should I do?

Follow the on-screen steps (hold the cap **level**, then **center**). If aim drifts later, run calibration again from the game or settings flow.

## Games & TV

### Can I play on the phone only?

**Yes.** **Bowling** and **Dart** run on the iPhone by default. **Quiz** can show questions on the phone; the big board appears on TV only when you use AirPlay.

### How do I use the TV?

1. Connect the iPhone to the TV (**AirPlay** / screen mirroring).
2. In the game lobby, turn on the option to show the **board / lane / dartboard on TV** (wording varies per game).
3. Keep the phone as the **remote** (tilt + button).

More detail: [Demo](demo) · [Dart](examples/dart) · [Bowling](examples/bowling) · [Quiz](examples/quiz).

## About the project

### Is this an official cap / brand SDK?

**No.** VeltoKit and gametriki are an **independent, educational** experiment. Not affiliated with any hardware manufacturer or retail brand. See the disclaimer on [Introduction](intro).

### Can I use VeltoKit in my own app?

**Yes** — MIT license, free for personal and commercial use. Plain-language guide: **[Can I use this?](can-i-use-this)**.

### Documentation in other languages

Docs are written in **English**. On the live site, use the **Translate** dropdown in the navbar (powered by Google Translate) — e.g. choose **Polish** for a machine-translated view. Code blocks and API names stay in English.

[Getting started](getting-started) · [Can I use this?](can-i-use-this) · [Introduction](intro)
