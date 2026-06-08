extends Node

## VeltoKit singleton — BLE + gyro API for Godot games (Triki controller).
## Autoload name: VeltoKit

signal gyro_updated(x: float, y: float, z: float)
signal connection_changed(connected: bool)
signal devices_updated(devices: Array)
signal ble_error(message: String)

@export_range(0.1, 5.0, 0.05) var sensitivity: float = 1.0

var _ble: VeltoKitBleManager
var _parser := VeltoKitGyroParser.new()
var _gyro := Vector3.ZERO
var _calibration_offset := Vector3.ZERO
var _connected := false


func _ready() -> void:
	_ble = VeltoKitBleManager.new()
	_ble.name = "BleManager"
	add_child(_ble)
	_ble.connection_changed.connect(_on_connection_changed)
	_ble.devices_updated.connect(_on_devices_updated)
	_ble.bytes_received.connect(_on_bytes_received)
	_ble.ble_error.connect(_on_ble_error)


## Start BLE scan (async via signals).
func start_scan() -> void:
	_ble.start_scan()


## Connect by device id from devices_updated list.
func connect_to_device(device_id: String) -> void:
	_ble.connect_to_device(device_id)


## Auto-connect when exactly one likely Triki device is found.
func connect_triki() -> void:
	_ble.auto_reconnect = true
	start_scan()


## Godot reserves `disconnect()` for signals — use this instead.
func disconnect_device() -> void:
	_ble.disconnect_device()


## Godot reserves `is_connected()` for signal checks — use this instead.
func is_device_connected() -> bool:
	return _connected


func using_simulator() -> bool:
	return _ble.using_simulator()


## Latest normalized gyro (after calibration × sensitivity).
func get_gyro() -> Vector3:
	return (_gyro - _calibration_offset) * sensitivity


## Capture current reading as neutral pose.
func calibrate_neutral() -> void:
	_calibration_offset = _gyro


func reset_calibration() -> void:
	_calibration_offset = Vector3.ZERO


func _on_connection_changed(connected: bool, _device_name: String) -> void:
	_connected = connected
	_parser.reset()
	connection_changed.emit(connected)


func _on_devices_updated(devices: Array) -> void:
	devices_updated.emit(devices)


func _on_bytes_received(data: PackedByteArray) -> void:
	var samples := _parser.ingest(data)
	if samples.is_empty():
		return
	var sample: Vector3 = samples[samples.size() - 1]
	if samples.size() >= 2:
		sample = samples[1]
	_gyro = sample
	var g := get_gyro()
	gyro_updated.emit(g.x, g.y, g.z)


func _on_ble_error(message: String) -> void:
	ble_error.emit(message)
