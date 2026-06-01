# gametriki (sample iOS app)

Reference app for **VeltoKit** — Pong, Dart, Bowling, Quiz. SDK sources live in [`../VeltoKit`](../VeltoKit/).

## Build

```bash
cd app
open gametriki.xcodeproj
```

In Xcode: scheme **gametriki** → your iPhone → Run. Use a physical device for real BLE; Simulator can use mock `enqueueBLE` bytes.

## Layout

```text
app/
  gametriki.xcodeproj
  gametriki/          App entry, assets, Info.plist
  Design/             Arcade UI theme, audio
  Engine/             Game loop, GameManager
  Games/              Pong, Dart, Bowling, Quiz
  Platform/           BLE, motion bridge, quiz API
  UI/                 SwiftUI screens
```

VeltoKit is linked from `../VeltoKit` (same repo, documented at the root).
