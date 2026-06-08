# VeltoKit Godot Plugin

BLE motion input for games using **Triki** controller logic from VeltoKit.

## Install

1. Copy `addons/veltokit_plugin/` into your Godot project.
2. **Project → Project Settings → Plugins** → enable **VeltoKit**.
3. Autoload `VeltoKit` is registered automatically.

## Quick start

```gdscript
func _ready() -> void:
    VeltoKit.gyro_updated.connect(_on_gyro)
    VeltoKit.connect_triki()  # scan + auto-connect (sim on desktop)

func _on_gyro(x: float, y: float, z: float) -> void:
    $Cube.rotation.y = x * 2.0
    $Cube.rotation.x = -y * 2.0
```

## API

| Method | Description |
|--------|-------------|
| `start_scan()` | Discover BLE devices |
| `connect_to_device(id)` | Connect by id |
| `connect_triki()` | Scan + auto-connect likely Triki |
| `disconnect_device()` | Disconnect (not `disconnect` — reserved by Godot) |
| `get_gyro()` | `Vector3` normalized gyro |
| `is_device_connected()` | BLE connection state |
| `calibrate_neutral()` | Zero current pose |
| `reset_calibration()` | Clear offset |

| Signal | Description |
|--------|-------------|
| `gyro_updated(x, y, z)` | Every new packet |
| `connection_changed(connected)` | BLE state |
| `devices_updated(devices)` | Scan results |

## Packet format

```
[0x22, 0x00]  header
int16 LE x @ 2
int16 LE y @ 4
int16 LE z @ 6
→ divide by 2000 (VeltoKit BLEGyroParser)
```

## Platforms

| Platform | Backend |
|----------|---------|
| Desktop / Editor | `ble_backend_sim.gd` (synthetic motion) |
| Android | `ble_backend_android.gd` + native plugin (see `android/`) |

## Demo

Open sample project in `godot/` and press **Play** — main scene `demos/triki_pong/triki_pong.tscn` (2D Pong). Optional 3D: `demos/gyro_cube/gyro_cube.tscn`.

**Docs:** [veltokit/docs/godot](https://koderhack.github.io/veltokit/docs/godot) (source: `website/docs/godot.md`).

## Properties

- `VeltoKit.sensitivity` — multiplier (default 1.0)
- `auto_reconnect` on BLE manager (via code)
