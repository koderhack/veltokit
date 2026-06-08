# Android BLE plugin (optional)

Godot GDScript cannot access BLE directly. Ship a small **Android library plugin** that exposes singleton `GodotVeltoKitBLE`.

## Expected singleton API

| Method | Description |
|--------|-------------|
| `start_scan()` | Scan for NUS peripherals (`6E400001-…`) |
| `stop_scan()` | Stop scan |
| `connect_device(device_id: String)` | Connect GATT (`call`, not `connect` — Godot reserved) |
| `disconnect_device()` | Disconnect |

## Signals (emit to GDScript)

| Signal | Payload |
|--------|---------|
| `scan_result` | `Array` of `{ id, name, rssi }` |
| `connected` | `device_id`, `device_name` |
| `disconnected` | — |
| `bytes_received` | `PackedByteArray` notify payload |
| `error` | `message: String` |

## After connect

Write VeltoKit init sequence (same as `TrikiBLEManager.sendInitAndStartIfReady()`):

1. `VeltoKitBleConstants.init_packet()` → RX `6E400002-…`
2. `VeltoKitBleConstants.start_packet()` → without response
3. Subscribe to TX notify `6E400003-…`

Packet format parsed by `gyro_parser.gd`: `[0x22, 0x00]` + int16 LE x,y,z ÷ 2000.

## References

- VeltoKit Swift: `VeltoKit/Triki/TrikiBLEManager.swift`
- RN transport: `VeltoKit/js/mobile/react-native/src/bleTransport.ts`
