---
sidebar_position: 12
title: Godot plugin
description: VeltoKit GDScript plugin — Triki gyro input for Godot 4 games
slug: /godot
---

# Godot plugin

Pure **GDScript** plugin for **Godot 4.2+** — maps Triki BLE motion packets to gyro `Vector3` for gameplay (rotate objects, aim, etc.). Packet parsing matches VeltoKit [`BLEGyroParser`](https://github.com/koderhack/veltokit/blob/main/VeltoKit/BLEGyroParser.swift).

:::info Repository path
`godot/addons/veltokit_plugin/` — sample project: `godot/project.godot`, example game `demos/triki_pong/`, 3D demo `demos/gyro_cube/`.
:::

## What works today

| Platform | Real BLE | Notes |
|----------|----------|--------|
| **Desktop** (Mac / Windows / Linux) | No | **Simulator** — synthetic gyro for dev |
| **Android** | Planned | Needs native plugin `GodotVeltoKitBLE` (stub + [android/README](https://github.com/koderhack/veltokit/blob/main/godot/addons/veltokit_plugin/android/README.md)) |
| **iOS (Swift)** | Yes | Use [gametriki](examples/pong) + `MotionSDK` — not this plugin |

On desktop, `VeltoKit.connect_triki()` connects to **Triki (simulator)** (`sim=true` in the console). Same packet format as production; only the radio layer is simulated.

## Install

1. Copy `godot/addons/veltokit_plugin/` into your Godot project under `addons/veltokit_plugin/`.
2. **Project → Project Settings → Plugins** → enable **VeltoKit**.
3. Autoload **`VeltoKit`** is registered by the editor plugin.

## Run the example game

1. Open the `godot/` folder in Godot 4.2+.
2. Enable the **VeltoKit** plugin.
3. **Play** (F5) — main scene **`demos/triki_pong/triki_pong.tscn`** (2D brick-breaker, gyro X → paddle).
4. Tilt the cap left/right; on desktop the simulator moves the paddle automatically. Console: `Triki Pong: połączono (sim=true)`.
5. Optional 3D demo: **`demos/gyro_cube/gyro_cube.tscn`** — cube rotation from gyro.

## Quick start (example game — Triki Pong)

```gdscript
func _ready() -> void:
    VeltoKit.gyro_updated.connect(_on_gyro)
    VeltoKit.connection_changed.connect(_on_connection_changed)
    VeltoKit.connect_triki()

func _on_gyro(x: float, _y: float, _z: float) -> void:
    # Paddle mode: gyro X → horizontal position (see demos/triki_pong/triki_pong.gd)
    var half := paddle_width * 0.5
    paddle_x = clampf(view_width * 0.5 + x * 220.0, half, view_width - half)

func _on_connection_changed(connected: bool) -> void:
    if connected:
        VeltoKit.calibrate_neutral()
```

3D tilt demo (`demos/gyro_cube/`): map `x`/`y` to `rotation` on a `MeshInstance3D`.

## API (autoload `VeltoKit`)

### Methods

| Method | Description |
|--------|-------------|
| `start_scan()` | Start BLE scan (async via signals) |
| `connect_to_device(device_id)` | Connect by id from `devices_updated` |
| `connect_triki()` | Scan + auto-connect likely Triki |
| `disconnect_device()` | Disconnect (not `disconnect()` — reserved by Godot) |
| `get_gyro()` | Latest `Vector3` (after calibration × sensitivity) |
| `is_device_connected()` | Connection state (not `is_connected()` — reserved by Godot) |
| `calibrate_neutral()` | Store current reading as zero |
| `reset_calibration()` | Clear offset |
| `using_simulator()` | `true` on desktop editor/player |

### Signals

| Signal | Description |
|--------|-------------|
| `gyro_updated(x, y, z)` | New normalized sample |
| `connection_changed(connected)` | BLE link up/down |
| `devices_updated(devices)` | Scan results `{ id, name, rssi }` |
| `ble_error(message)` | Backend error |

### Properties

- `sensitivity` (`float`, default `1.0`) — multiplier after calibration.

## Packet format

Same as VeltoKit legacy block (see [BLE integration](./sdk/ble-integration)):

```text
[0x22, 0x00]     header
int16 LE x @ 2
int16 LE y @ 4
int16 LE z @ 6
→ divide by 2000
```

Implemented in `gyro_parser.gd`. NUS UUIDs and init bytes: `ble_constants.gd` (aligned with `TrikiBLEManager`).

## Plugin layout

```text
addons/veltokit_plugin/
  plugin.cfg
  plugin.gd           # registers VeltoKit autoload
  veltokit.gd         # public singleton API
  ble_manager.gd      # scan / connect / reconnect
  gyro_parser.gd      # 0x22 blocks → Vector3
  ble_constants.gd    # NUS UUIDs, init packets
  ble_backend_sim.gd  # desktop simulator
  ble_backend_android.gd
  android/README.md   # native Android BLE plugin contract
```

## Godot reserved names

Do **not** use these on the singleton (they collide with `Object`):

- `disconnect()` → use **`disconnect_device()`**
- `is_connected()` → use **`is_device_connected()`**

## Android (real BLE)

Godot cannot access BLE from GDScript alone. Ship a small **Android library plugin** exposing singleton `GodotVeltoKitBLE` — methods `start_scan`, `connect_device`, `disconnect_device`, signals `bytes_received`, etc. See `addons/veltokit_plugin/android/README.md` in the repo.

After GATT connect, write the same init sequence as Swift:

- `VeltoKitBleConstants.init_packet()` → RX characteristic
- `VeltoKitBleConstants.start_packet()` → without response
- Subscribe to TX notify

## Related docs

- [BLE integration](./sdk/ble-integration) — Swift stack, NUS, `TrikiBLEManager`
- [Desktop bridge](./sdk/desktop-bridge) — macOS Electron control (not Godot)
- [SDK overview](./sdk/overview)
