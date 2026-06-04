---
name: veltokit
description: VeltoKit BLE motion SDK and gametriki sample app. Use when editing Swift in VeltoKit/, app/, or website/docs/, or when answering questions about GameInput, MotionSDK, MotionMode, Triki UI, or BLE integration.
---

# VeltoKit (gametriki repo)

## Before any edit

1. Read repo root **`AGENTS.md`** for paths, `GameInput` contract, and anti-patterns.
2. Read **`VeltoKit/MotionSDK.swift`** and **`VeltoKit/GameInput.swift`** for API truth.
3. For game behavior, read the matching **`app/Games/*Game.swift`** and **`website/docs/examples/*.md`**.

## Identity

- **VeltoKit** = Swift SDK in `VeltoKit/`. **gametriki** = sample app in `app/`.
- Games use **`GameInput` only** — never raw BLE `Data` in `app/Games/`.
- **Triki UI** = `app/UI/TrikiUI/` (menus, focus, hold). Not shipped as VeltoKit API.

## Frame pipeline

`BLE → MotionSDK.connect() → pollInput → GameInput → your game`

```swift
motion.configureForPong()  // or Menu / PointerGame / GestureGame
let input = motion.pollInput(deltaTime: dt)
```

Helpers: `TrikiRecipes.swift` — `TrikiSimplePong`, `TrikiUIPicker`, `TrikiGameActions`, `TrikiButtonGate`.
Docs: `website/docs/sdk/recipes.md`.

## MotionMode → games

| Mode | Games | Main fields |
|------|-------|-------------|
| `.paddle` | Pong, Quiz | `posX`, `primaryAction` |
| `.pointer` | Dart | `posX`, `posY`, `shotTriggered` |
| `.gesture` | Bowling | `shotTriggered`, `throwPower` |

## Editing rules

- Minimal diffs; do not rename public API without request.
- Update `///` on touched Swift APIs; sync `website/docs/` if behavior changes.
- Docs source: `website/docs/` (English). Site search: navbar `⌘K` / `Ctrl+K`.

## Docs index (repo paths)

- Overview: `website/docs/sdk/overview.md`
- GameInput: `website/docs/sdk/game-input.md`
- AI context: `website/docs/ai-context.mdx`, `AGENTS.md`
