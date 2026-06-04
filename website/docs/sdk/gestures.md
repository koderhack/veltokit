---
title: Gestures
---

# Gesture throws

Enable with:

```swift
motion.setMode(.gesture)
```

## State machine

```text
IDLE
  → pull back (relY drops / velocity negative)
  → ARMED (gesturePrimed == true)
  → thrust forward
  → THROW (shotTriggered, throwPower > 0)
  → cooldown (gestureCooldown)
```

`GestureDetector` uses **relative vertical motion** (`relY`) and per-frame velocity, scaled to 60 fps via `frameScale`.

## Game code

```swift
if input.gesturePrimed {
  hud.show("Pull back…")
}

if input.shotTriggered {
  game.throw(power: input.throwPower)
}
```

In **`.gesture`** and **`.pointer`** modes, `input.primaryAction` is also `true` on the throw frame (click OR throw OR velocity action). In **`.paddle`** mode, `primaryAction` is the BLE button only — see [GameInput](./game-input#primary-action-by-mode).

## Tuning

| `MotionConfig` field | Effect |
|----------------------|--------|
| `gesturePullbackDelta` | How far back before armed |
| `gesturePullSpeed` | Fast pull sensitivity |
| `gestureMinThrustSpeed` | Forward speed to fire |
| `gestureMinRelY` | Minimum forward displacement |
| `gestureThreshold` | Legacy scale gate |
| `gestureCooldown` | Minimum time between throws |

Preset defaults are in `MotionConfig.preset(for: .gesture)`.

## Bowling vs Dart

Both use `.gesture`. Bowling maps `throwPower` to SceneKit impulse; Dart uses it for launch speed. Input profile is set in `GameManager` / `BowlingInputHandler` / `DartThrowController` in the sample app.

[Configuration](./configuration) · [GameInput](./game-input)
