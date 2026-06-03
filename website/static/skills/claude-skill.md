# VeltoKit — Claude skill

## Step 1: Load repo context

Attach or read **`AGENTS.md`** at the repository root before analysis or patches.

Optional: `website/docs/ai-context.mdx` on the docs site.

## Step 2: Project instructions (Claude Projects) or first message

```text
You work on the VeltoKit / gametriki monorepo.

GROUND TRUTH:
- VeltoKit/ = Swift SDK. MotionSDK.connect() + pollInput(deltaTime:) → GameInput.
- app/ = reference iOS sample (gametriki). The product name for the library is VeltoKit, not "gametriki SDK".
- GameInput is the only type game update loops should consume.
- TrikiInputAdapter (app/Platform/) adds calibration UI; Triki UI (app/UI/TrikiUI/) handles menu focus/hold.

ARCHITECTURE ORDER WHEN EXPLAINING:
BLE bytes → MotionSDK → MotionEngine → GameInput → app/Games/*.swift

KEY FILES:
- VeltoKit/MotionSDK.swift, MotionEngine.swift, GameInput.swift
- app/Engine/GameManager.swift (MotionMode per game)
- website/docs/sdk/game-input.md, sdk/architecture.md

MODES:
.paddle (Pong, Quiz), .pointer (Dart), .gesture (Bowling)

RULES:
- Read AGENTS.md and implementation before proposing changes.
- Small patches; no symbol renames unless required.
- Documentation changes: website/docs/ (English source).
- Never fabricate GameInput fields — verify VeltoKit/GameInput.swift.

Deliver: short summary, file list, verification steps.
```

## Docs (human)

- https://koderhack.github.io/veltokit/docs/ai-context
- https://koderhack.github.io/veltokit/docs/for-cursor-claude
