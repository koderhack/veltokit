# VeltoKit / gametriki — context for AI assistants

Read this file **before** changing code or answering questions about this repository. Human docs: https://koderhack.github.io/veltokit/docs/intro — source in `website/docs/`.

## What this project is

- **VeltoKit** (`VeltoKit/`) — Swift package: BLE motion bytes → **`GameInput`** every frame. Public API: **`MotionSDK`**.
- **gametriki** (`app/`) — sample iOS app (Xcode: `app/gametriki.xcodeproj`) that uses VeltoKit. Not a second SDK.
- **Triki** — informal name for the BLE cap UI layer in the app (`app/UI/TrikiUI/`, `TrikiInputAdapter`). Games still consume **`GameInput`**, not raw BLE.

Unofficial / educational. Do not invent hardware brands or packet layouts not in `VeltoKit/BLE/` and `website/docs/sdk/ble-integration.md`.

## Terminology (do not confuse)

| Term | Meaning |
|------|---------|
| `MotionSDK` | Main SDK facade: `connect()`, `pollInput()`, `enqueueBLE`, `input` |
| `MotionEngine` | Internal frame processor (modes, gestures) |
| `GameInput` | **Only** struct games should use in `update(input:deltaTime:)` |
| `MotionMode` | `.paddle` \| `.pointer` \| `.gesture` |
| `TrikiInputAdapter` | App-only wrapper with calibration UI; forwards to `MotionSDK` |
| `trikiUIScreen` | SwiftUI modifier for focus/hold navigation in menus |
| `MotionInputProvider` | Typealias / protocol used by Triki UI for live `GameInput` |

## Repository map (read these paths)

```text
VeltoKit/
  MotionSDK.swift      # Public API — start here for SDK questions
  MotionEngine.swift   # Per-frame processing, modes, calibration
  GameInput.swift      # Output contract — start here for game logic
  MotionConfig.swift   # Presets per MotionMode
  BLE/BLEManager.swift # Stub → TrikiBLEManager
  Triki/TrikiBLEManager.swift      # Scan, connect, reconnect, notify
  Triki/TrikiBLEMonitor.swift      # fast/normal/lowPower from packet Δt
  Triki/TrikiParser.swift          # Format-detecting int16 decode
  Triki/TrikiMotionEngine.swift    # Velocity / shake / tilt / swing
  Triki/TrikiGameController.swift  # Gamepad API (TrikiGameInput)
  BLEGyroParser.swift  # Legacy block parser (enriched GameInput path)
app/
  gametriki.xcodeproj
  Platform/TrikiInputAdapter.swift   # Optional adapter (sample app)
  Engine/GameManager.swift           # Applies MotionMode per game
  Engine/GameEngine.swift
  Games/PongGame.swift               # .paddle
  Games/DartGame.swift               # .pointer + throw
  Games/BowlingGame.swift            # .gesture
  Games/QuizGame.swift               # .paddle
  UI/TrikiUI/                        # Navigation chrome (not in VeltoKit target)
website/docs/                        # Docusaurus source (English)
website/static/skills/               # Downloadable Cursor/Claude prompts
```

## Data flow (ground truth)

```text
BLE notify bytes
  → MotionSDK.enqueueBLE (or BLEManager inside connect())
  → BLEGyroParser / ButtonDetector
  → MotionEngine.updateFrame(deltaTime:)
  → MotionSDK copies into GameInput
  → Game.update(input:deltaTime:)  OR  Triki UI reads live GameInput
```

Preferred integration after `connect()`:

```swift
let input = motion.pollInput(deltaTime: dt)
```

Manual BLE ownership:

```swift
motion.enqueueBLE(bytes)
motion.updateFrame(deltaTime: dt)
let input = motion.input
```

## GameInput — fields games actually use

| Field | Type | When it matters |
|-------|------|-----------------|
| `posX`, `posY` | `Double` | Aim / paddle position (~0…1, center ≈ 0.5) |
| `primaryAction` | `Bool` | Button click this frame |
| `shotTriggered` | `Bool` | Gesture throw edge (Dart, Bowling) |
| `throwPower` | `Double` | 0…1 when `shotTriggered` |
| `gesturePrimed` | `Bool` | Pull-back before throw (UI) |
| `pointerDirection` | enum | Pointer mode sectors |
| `didShoot` | computed | `primaryAction \|\| shotTriggered` |
| `tiltX`, `tiltY`, `deltaX`, `deltaY` | `Double` | Debug / HUD |
| `sensors` | `TrikiSensors` | Filled mainly by app `MotionParser`, not core SDK |

Full reference: `website/docs/sdk/game-input.md` and `VeltoKit/GameInput.swift`.

## MotionMode → sample games

| Mode | Games | Main inputs |
|------|-------|-------------|
| `.paddle` | Pong, Quiz | `posX`, `primaryAction` / `didShoot` |
| `.pointer` | Dart | `posX`, `posY`, `shotTriggered`, `sensors` |
| `.gesture` | Bowling | `posX`, `shotTriggered`, `throwPower` |

Mode setup in app: `app/Engine/GameManager.swift`. Per-game docs: `website/docs/examples/*.md`.

## Which docs to open (in repo)

| Task | Read first |
|------|------------|
| Integrate SDK in a new app | `website/docs/quick-start.md`, `sdk/motion-sdk.md`, `sdk/game-input.md` |
| BLE packets / debugging | `sdk/ble-integration.md`, `VeltoKit/BLE/` |
| Change gesture / throw | `sdk/gestures.md`, `VeltoKit/GestureDetector.swift` |
| Triki menus / focus | `sdk/triki-ui.md`, `app/UI/TrikiUI/` |
| Calibrate cap + simple menu (Quiz-style) | `sdk/triki-ui.md` (§ calibration), `app/UI/Quiz/QuizFlowView.swift`, `TrikiCalibrationView.swift` |
| Copy a game pattern | `website/docs/examples/pong.md` (etc.) + matching `app/Games/*.swift` |
| AI workflow / skills | `website/docs/ai-context.mdx`, `website/docs/for-cursor-claude.mdx` |

Website paths map 1:1: `website/docs/sdk/overview.md` → `/docs/sdk/overview` on the site.

## Rules when editing

1. **Scope**: SDK changes → `VeltoKit/` only unless app integration is requested. Do not move BLE into games.
2. **Stable API**: Do not rename public symbols unless asked. Prefer minimal diffs.
3. **Single output type**: Games must not depend on raw `Data` BLE in game files.
4. **Docs**: Behavior change → update `website/docs/` and Swift `///` on touched APIs.
5. **Swift comments**: Existing Polish `///` in VeltoKit is OK; new public API docs can be English or Polish — stay consistent within the file you touch.
6. **No fake APIs**: If unsure, read `MotionSDK.swift` and call sites in `app/Games/`.

## Common AI mistakes in this repo

- Treating **gametriki** as a separate framework from **VeltoKit**.
- Using marketing names for hardware instead of “generic BLE cap” / packet docs.
- Editing `posX` mapping in games without checking `MotionMode` and `MotionConfig.preset`.
- Confusing **Triki UI** (SwiftUI navigation) with **GameInput** (per-frame state).
- Linking to `/skills/...` as Docusaurus routes — they are static files under `website/static/skills/`.
- Assuming Algolia search — docs use **local search** (navbar, `⌘K` / `Ctrl+K`).

## Validation

- SDK-only logic: build **VeltoKit** scheme in Xcode or SwiftPM.
- App + BLE: scheme **gametriki** on a physical iPhone.
- Docs site: `cd website && npm run build`.
