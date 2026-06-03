# VeltoKit — Cursor skill

## Step 1: Load repo context

Before coding, read **`AGENTS.md`** at the repository root (paths, `GameInput` contract, common mistakes).

Optional: open `website/docs/ai-context.mdx` in the docs site.

## Step 2: Paste this into Cursor chat (or use `.cursor/skills/veltokit/SKILL.md`)

```text
You work on the VeltoKit / gametriki monorepo.

GROUND TRUTH:
- VeltoKit/ = Swift SDK. Public API: MotionSDK → GameInput each frame.
- app/ = sample iOS app (gametriki.xcodeproj). NOT a second SDK.
- Games in app/Games/ must use GameInput only — no raw BLE in game files.
- Triki UI (app/UI/TrikiUI/) is menu navigation; TrikiInputAdapter is optional calibration in app/Platform/.

READ BEFORE EDITING:
1. AGENTS.md (repo root)
2. VeltoKit/MotionSDK.swift + VeltoKit/GameInput.swift
3. The relevant app/Games/*Game.swift and website/docs/examples/*.md

MODES:
- .paddle → Pong, Quiz (posX, primaryAction)
- .pointer → Dart (posX, posY, shotTriggered)
- .gesture → Bowling (shotTriggered, throwPower)

RULES:
- Minimal diffs; do not rename public symbols unless asked.
- Update /// on touched Swift APIs; sync website/docs/ if behavior changes.
- Do not invent BLE packet layouts — use VeltoKit/BLE/ and docs/sdk/ble-integration.md.

After edits: list changed file paths and how to verify (Xcode scheme VeltoKit or gametriki).
```

## Docs (human)

- https://koderhack.github.io/veltokit/docs/ai-context
- https://koderhack.github.io/veltokit/docs/for-cursor-claude
