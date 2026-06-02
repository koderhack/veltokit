---
title: Skill for Claude
description: Claude-oriented guide for SDK analysis, docs, and safe refactors
---

# Skill for Claude

Use this workflow when Claude is helping with VeltoKit, Triki UI, and game integration docs.

## Analysis priorities

1. Build architecture context first:
   - [Architecture](./sdk/architecture)
   - [Module map](./sdk/modules)
2. Verify API intent from usage sites in `app/Games` and `app/UI`.
3. When documenting, prefer concise developer language over generic text.

## Claude execution checklist

1. Map all impacted files.
2. Separate behavior change from documentation change.
3. Keep patches small and composable.
4. Add/update Swift `///` documentation for touched APIs.
5. Update docs pages that explain changed behavior (`sdk/*`, examples).
6. Provide clear test/verification notes.

## Claude-style prompt templates

### 1) Deep codebase explanation

```text
Analyze the full flow from BLE ingress to GameInput to game UI behavior.
Focus on MotionSDK, MotionEngine, TrikiInputAdapter, and trikiUIScreen.
Return a concise architecture explanation and risk points.
```

### 2) Production-grade documentation pass

```text
Generate high-quality Swift /// documentation for all touched public/internal APIs.
For functions include parameters, return value, side effects, and practical examples.
Do not modify code logic.
```

### 3) Safe refactor preparation

```text
Prepare a no-risk refactor plan with explicit file list, acceptance criteria, and rollback strategy.
Then implement in small commits preserving behavior.
```

## Quality bar

- Every explanation should map to concrete symbols/files.
- Examples should mirror real game flows (Pong, Dart, Bowling, Quiz).
- Triki UI docs must cover lifecycle (`isActive`), focus mapping, and activation side effects.

[For Cursor Claude hub](./for-cursor-claude) · [Skill for Cursor](./for-cursor)
