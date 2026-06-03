# VeltoKit

[![Docs](https://img.shields.io/badge/docs-GitHub%20Pages-0ea5e9)](https://koderhack.github.io/veltokit/)
[![iOS 16+](https://img.shields.io/badge/iOS-16%2B-black)](./VeltoKit/)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange)](./VeltoKit/)
[![BLE unofficial](https://img.shields.io/badge/BLE-unofficial-lightgrey)](./website/docs/intro.mdx)

**VeltoKit** is an experimental Swift framework that maps **BLE cap IMU + button packets** into a single [`GameInput`](./VeltoKit/GameInput.swift) struct each frame. **gametriki** is the reference iOS sample (Pong, Dart, Bowling, Quiz) that exercises the SDK without importing CoreBluetooth in game code.

> **Disclaimer:** Independent project for **education and development**. Not affiliated with, endorsed by, or connected to any hardware manufacturer or brand.

## Features

- **`MotionSDK`** — `connect()` + `pollInput()` → `GameInput` (or `enqueueBLE` + `updateFrame` with your own BLE)
- **`MotionMode`** — `.paddle` · `.pointer` · `.gesture` with [`MotionConfig.preset(for:)`](./VeltoKit/MotionConfig.swift)
- **Optional `Platform/`** — [`TrikiInputAdapter`](./app/Platform/TrikiInputAdapter.swift) (calibration UI; forwards to `MotionSDK`)
- **Sample games** — integration tests in [`app/Games/`](./app/Games/)
- **Documentation** — Docusaurus site in [`website/`](./website/) (English; Google Translate in navbar)
- **SPM & CocoaPods** — `Package.swift` + `VeltoKit.podspec` (iOS 16+)

## Install VeltoKit

**Swift Package Manager** — in Xcode: *Add Package Dependencies* → `https://github.com/koderhack/veltokit` → product **VeltoKit**.

**CocoaPods** — `pod 'VeltoKit', '~> 0.1.0'`

Details: [installation docs](website/docs/installation.md) · [VeltoKit/README.md](./VeltoKit/README.md)

## Quick start (SDK only)

```swift
import VeltoKit

let motion = MotionSDK()
motion.setMode(.paddle)
motion.connect()

func onFrame(dt: TimeInterval) {
  let input = motion.pollInput(deltaTime: dt)
  paddle.x = CGFloat(input.posX) * courtWidth
}
```

## Quick start (sample app adapter)

```swift
import VeltoKit

let adapter = TrikiInputAdapter()
adapter.connect()
GameManager.applyMotionMode(gameType: .pong, to: adapter)

func tick(dt: TimeInterval) {
  let input = adapter.pollInput(deltaTime: dt)
  // same GameInput fields
}
```

## Sample games → VeltoKit

| Game | `MotionMode` in sample | Main `GameInput` fields | Source |
|------|------------------------|-------------------------|--------|
| [Pong](website/docs/examples/pong.md) | `.paddle` | `posX`, `didShoot` | [`app/Games/PongGame.swift`](./app/Games/PongGame.swift) |
| [Dart](website/docs/examples/dart.md) | `.pointer` + throw FSM | `posX`, `posY`, `sensors` | [`app/Games/DartGame.swift`](./app/Games/DartGame.swift) |
| [Bowling](website/docs/examples/bowling.md) | `.gesture` | `posX`, `shotTriggered`, `throwPower` | [`app/Games/BowlingGame.swift`](./app/Games/BowlingGame.swift) |
| [Quiz](website/docs/examples/quiz.md) | `.paddle` | `posX`, `primaryAction` | [`app/Games/QuizGame.swift`](./app/Games/QuizGame.swift) |

Presets and per-game tuning: [`app/Engine/GameManager.swift`](./app/Engine/GameManager.swift).

## For AI assistants (Cursor, Claude, …)

If the model confuses **VeltoKit** vs **gametriki** or invents APIs, point it at:

| Resource | Location |
|----------|----------|
| **AGENTS.md** | Repo root — read this first |
| **Context for AI** | [website/docs/ai-context.mdx](./website/docs/ai-context.mdx) |
| **Cursor skill** | [.cursor/skills/veltokit/SKILL.md](./.cursor/skills/veltokit/SKILL.md) (tracked in repo) |
| **Triki menu + calibration** | [Triki UI docs](website/docs/sdk/triki-ui.md#calibration-and-simple-menu) · Quiz: `app/UI/Quiz/QuizFlowView.swift` |
| **Download prompts** | [For Cursor Claude](https://koderhack.github.io/veltokit/docs/for-cursor-claude) |

Ground truth for game code: [`VeltoKit/GameInput.swift`](./VeltoKit/GameInput.swift) and [`VeltoKit/MotionSDK.swift`](./VeltoKit/MotionSDK.swift).

## Documentation

| | |
|---|---|
| **Site** | https://koderhack.github.io/veltokit/ |
| **Docs** | https://koderhack.github.io/veltokit/docs/intro |
| **AI context** | https://koderhack.github.io/veltokit/docs/ai-context |

English source docs; use **Translate** in the navbar for other languages (Google Translate). **Search** in the docs navbar: `⌘K` / `Ctrl+K`.

[intro](website/docs/intro.mdx) · [SDK](website/docs/sdk/overview.md) · [Pong](website/docs/examples/pong.md)

```bash
cd website && npm install && npm run start
```

## Repository layout

```text
VeltoKit/       MotionSDK.connect(), BLEManager, GameInput (link this target)
app/            Sample iOS app (open app/gametriki.xcodeproj)
  Platform/     TrikiInputAdapter (optional calibration UI)
  Engine/       GameEngine, GameManager
  Games/        Pong, Dart, Bowling, Quiz
  UI/           SwiftUI screens
website/        Docusaurus docs (EN + Google Translate)
```

See also [VeltoKit/README.md](./VeltoKit/README.md).

## Requirements

- **iOS 16+**, Xcode 15+
- Physical iPhone for real BLE (Simulator: feed mock bytes via `enqueueBLE`)
- Generic BLE cap-style controller (IMU + button) — packet layout in [BLE integration](website/docs/sdk/ble-integration.md)

## Clone and run

```bash
git clone https://github.com/koderhack/veltokit.git
cd veltokit/app
open gametriki.xcodeproj
```

Scheme **gametriki** → your iPhone → Connect BLE → pick a game from the menu.


