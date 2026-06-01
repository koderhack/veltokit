# VeltoKit

[![Docs](https://img.shields.io/badge/docs-GitHub%20Pages-0ea5e9)](https://przemyslawsikora.github.io/veltokit/)
[![iOS 16+](https://img.shields.io/badge/iOS-16%2B-black)](./VeltoKit/)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange)](./VeltoKit/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](./LICENSE)
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

**Swift Package Manager** — in Xcode: *Add Package Dependencies* → `https://github.com/przemyslawsikora/veltokit` → product **VeltoKit**.

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

## Documentation

| | |
|---|---|
| **Site** | https://przemyslawsikora.github.io/veltokit/ |
| **Docs** | https://przemyslawsikora.github.io/veltokit/docs/intro |

English source docs; use **Translate** in the navbar for other languages (Google Translate).

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

See also [VeltoKit/README.md](./VeltoKit/README.md) and [.github/PUBLISHING.md](./.github/PUBLISHING.md) for release tags and GitHub metadata.

## Requirements

- **iOS 16+**, Xcode 15+
- Physical iPhone for real BLE (Simulator: feed mock bytes via `enqueueBLE`)
- Generic BLE cap-style controller (IMU + button) — packet layout in [BLE integration](website/docs/sdk/ble-integration.md)

## Clone and run

```bash
git clone https://github.com/przemyslawsikora/veltokit.git
cd veltokit/app
open gametriki.xcodeproj
```

Scheme **gametriki** → your iPhone → Connect BLE → pick a game from the menu.

## License

### 🔥 MIT License

Full text: [LICENSE](./LICENSE)

