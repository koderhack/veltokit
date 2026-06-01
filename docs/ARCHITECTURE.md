# Architecture

> **Online docs (EN/PL):** [website/docs/sdk/architecture.md](../website/docs/sdk/architecture.md) · [SDK overview](../website/docs/sdk/overview.md)

## Overview

Gametriki składa się z **warstwy SDK** (czysty ruch + wejście) oraz **warstwy aplikacji** (BLE, gry, UI). Gry widzą wyłącznie `GameInput` z frameworku **VeltoKit** — nie importują parsera BLE ani logiki gestów bezpośrednio.

```
┌─────────────┐     notify      ┌──────────────────┐
│ Triki (BLE) │ ──────────────► │ Platform         │
└─────────────┘                 │ TrikiInputAdapter│
                                └────────┬─────────┘
                                         │ enqueueBLE / updateFrame
                                         ▼
                                ┌──────────────────┐
                                │ VeltoKit         │
                                │ MotionSDK        │
                                │  ├ MotionProcessor│
                                │  ├ GestureDetector│
                                │  └ ButtonDetector │
                                └────────┬─────────┘
                                         │ GameInput
                                         ▼
                                ┌──────────────────┐
                                │ Engine + Games   │
                                │ update(input:)   │
                                └──────────────────┘
```

## VeltoKit (`VeltoKit.framework`)

Framework bez zależności od gier ani UI. Kod źródłowy: folder `VeltoKit/`.

| Plik | Odpowiedzialność |
|------|------------------|
| `MotionSDK.swift` | Fasada: `update(rawX:bytes:deltaTime:)`, `input` |
| `MotionProcessor.swift` | `rawX` → `posX` (offset, wygładzanie, paletka / wskaźnik) |
| `GestureDetector.swift` | Cofnięcie → rzut (`didThrow`, `throwPower`) |
| `ButtonDetector.swift` | BLE `0x22`, bajt `[1]`, zbocze 0→1 |
| `MotionEngine.swift` | Orkiestracja trybów `.paddle` / `.pointer` / `.gesture` |
| `InputAdapter.swift` | SDK bez BLE (testy, integracja własna) |
| `GameInput.swift` | Kontrakt wyjścia dla gier |
| `MotionConfig.swift` | Parametry i presety |

### Przepływ klatki (SDK)

1. Surowy `rawX` trafia do `MotionProcessor` (filtr + offset).
2. W trybie `.gesture` `GestureDetector` analizuje `relY` i prędkość.
3. `ButtonDetector` przetwarza pakiety BLE (niezależnie od trybu).
4. `MotionSDK.publishInput()` składa `GameInput`: `didShoot = klik ∨ gest`.

## Platform

| Moduł | Rola |
|-------|------|
| `BLE/` | Skan, NUS, strumień bajtów |
| `Motion/` | `MotionParser`, `TrikiMotionProtocol` → `TrikiSensors` |
| `TrikiInputAdapter.swift` | Łączy BLE z `MotionSDK`, `pollInput()` @ 60 FPS |

`MotionInputProvider` jest aliasem typu `TrikiInputAdapter` (kompatybilność wsteczna).

## Engine

| Plik | Rola |
|------|------|
| `Game.swift` | Protokół gry + `GameInputProfile` |
| `GameContext.swift` | Bufor rysowania 160×90 |
| `GameEngine.swift` | Pętla: `pollInput` → `game.update` → HUD |
| `GameManager.swift` | Presety trybu motion per gra |

Gry implementują tylko:

```swift
func update(input: GameInput, deltaTime: TimeInterval)
```

## Games

| Gra | Tryb motion | Wejście |
|-----|-------------|---------|
| Pong | `.paddle` | `input.posX` |
| Dart | `.pointer` + rzut | `posX`, `didShoot`, `gesturePrimed` |
| Bowling | `.gesture` | rzut + sesja wieloosobowa |
| Quiz | `.paddle` | `primaryAction` / kategorie |

## UI

- `MainMenu.swift` — wybór gry, połączenie Triki
- `HUD.swift` — wspólne komponenty statusu
- Widoki per gra (`DartGameView`, `BowlingGameView`, …)

## Zależności (reguły)

- **VeltoKit** → Foundation (brak SwiftUI, brak gier)
- **Platform** → VeltoKit + CoreBluetooth (w aplikacji)
- **Games** → Engine + **VeltoKit** (`GameInput` tylko)
- **UI** → Engine, Platform, Design

## Rozszerzanie

1. Nowa gra: struct w `app/Games/`, protokół `Game`, profil w `GameManager`.
2. Nowy tryb motion: preset w `MotionConfig.preset(for:)`.
3. Własne BLE: użyj `MotionSDK` + `InputAdapter` bez `TrikiInputAdapter`.
