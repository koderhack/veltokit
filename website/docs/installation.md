---
sidebar_position: 5
title: Installation
description: Add VeltoKit via SPM, CocoaPods, or Xcode
---

# Installation

VeltoKit ships as a **Swift package** and **CocoaPod** (includes **CoreBluetooth** for `MotionSDK.connect()`). The sample **Platform** layer (`TrikiInputAdapter`) is optional UI/calibration glue in `app/Platform`.

## Swift Package Manager (recommended)

**Xcode:** File → Add Package Dependencies… →

```text
https://github.com/przemyslawsikora/veltokit
```

Select product **VeltoKit** → add to your app target.

**Package.swift:**

```swift
dependencies: [
  .package(url: "https://github.com/przemyslawsikora/veltokit", from: "0.1.0"),
],
targets: [
  .target(
    name: "YourApp",
    dependencies: [
      .product(name: "VeltoKit", package: "veltokit"),
    ]
  ),
]
```

Requires **iOS 16+**, Swift 5.9+.

## CocoaPods

```ruby
platform :ios, '16.0'

target 'YourApp' do
  use_frameworks!
  pod 'VeltoKit', '~> 0.1.0'
end
```

Then `pod install` and open the `.xcworkspace`.

Podspec: [`VeltoKit.podspec`](https://github.com/przemyslawsikora/veltokit/blob/main/VeltoKit.podspec) in the repo root.

## Xcode project (monorepo / fork)

1. Open `app/gametriki.xcodeproj` (or copy the `VeltoKit/` folder).
2. Add target **VeltoKit** — **Frameworks** + **Target Dependency**.
3. `import VeltoKit`

## First import

```swift
import VeltoKit

let motion = MotionSDK()
motion.setMode(.paddle)
motion.connect()   // scan + auto-connect (physical iPhone)

// Each frame in your game loop:
let input = motion.pollInput(deltaTime: dt)
```

Add to `Info.plist`: `NSBluetoothAlwaysUsageDescription`.

- Real BLE needs a **physical iPhone** (Simulator has no controller radio).
- Already have `CBCentralManager`? Skip `connect()` and use `enqueueBLE` + `updateFrame` — see [Quick start](quick-start).
- Sample app uses **`TrikiInputAdapter`** for calibration prompts; it delegates to `motionSDK.connect()`.

[Quick start](quick-start) · [SDK overview](sdk/overview)
