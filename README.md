# TrikiMotionKit + Demo App

`TrikiMotionKit` to lekki SDK do sterowania grami mobilnymi ruchem urządzenia (tilt-based motion input) oraz połączeniem BLE.

## Quick Start

```swift
let motion = MotionInputProvider()
motion.connect()
let input = motion.pollInput()
player.x += input.rotation * speed
```

SDK zwraca stabilny `rotation` oparty o `tiltX` z deadzone, dzięki czemu sterowanie jest płynne i nie dryfuje przy spokojnym trzymaniu urządzenia.

## Demo Games

- `CarGame` – płynne skręcanie przez `input.rotation` i ruch oparty o velocity.
- `SnakeGame` – zmiana kierunku na podstawie progów rotacji.

## Structure

- `TrikiMotionKit/` – minimalne API SDK (`connect`, `disconnect`, `pollInput`)
- `TrikiArcadeApp/` + `gametriki/` – aplikacja demo i gry pokazowe
- `docs/` – landing page do publikacji na GitHub
