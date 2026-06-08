class_name VeltoKitBleManager
extends Node

## Platform BLE facade — never blocks the main thread; emits signals for IO.

signal devices_updated(devices: Array)
signal connection_changed(connected: bool, device_name: String)
signal bytes_received(data: PackedByteArray)
signal ble_error(message: String)

@export var auto_reconnect: bool = true
@export var reconnect_delay_sec: float = 1.5

var _android := VeltoKitBleBackendAndroid.new()
var _sim := VeltoKitBleBackendSim.new()
var _use_sim := true
var _scanning := false
var _last_device_id := ""
var _reconnect_timer: Timer


func _ready() -> void:
	_use_sim = not OS.has_feature("android") or not _android.is_available()
	_wire_backend(_sim)
	if not _use_sim:
		_wire_backend(_android)
	_reconnect_timer = Timer.new()
	_reconnect_timer.one_shot = true
	_reconnect_timer.timeout.connect(_try_reconnect)
	add_child(_reconnect_timer)


func _wire_backend(backend: Object) -> void:
	backend.scan_finished.connect(_on_scan_finished)
	backend.connected.connect(_on_connected)
	backend.disconnected.connect(_on_disconnected)
	backend.bytes_received.connect(_on_bytes_received)
	backend.error.connect(_on_error)


func _process(delta: float) -> void:
	if _use_sim and _sim.is_device_connected():
		_sim.tick(delta)


func start_scan() -> void:
	_scanning = true
	if _use_sim:
		_sim.start_scan()
	else:
		_android.start_scan()


func stop_scan() -> void:
	_scanning = false
	if _use_sim:
		_sim.stop_scan()
	else:
		_android.stop_scan()


func connect_to_device(device_id: String) -> void:
	_last_device_id = device_id
	stop_scan()
	if _use_sim:
		_sim.connect_to_device(device_id)
	else:
		_android.connect_to_device(device_id)


func disconnect_device() -> void:
	_reconnect_timer.stop()
	if _use_sim:
		_sim.disconnect_device()
	else:
		_android.disconnect_device()


func is_device_connected() -> bool:
	if _use_sim:
		return _sim.is_device_connected()
	return _android.is_device_connected()


func using_simulator() -> bool:
	return _use_sim


func _on_scan_finished(devices: Array) -> void:
	_scanning = false
	devices_updated.emit(devices)
	if devices.size() == 1 and VeltoKitBleConstants.is_likely_triki_name(devices[0].get("name", "")):
		connect_to_device(devices[0].get("id", ""))


func _on_connected(device_id: String, device_name: String) -> void:
	_last_device_id = device_id
	_reconnect_timer.stop()
	connection_changed.emit(true, device_name)


func _on_disconnected() -> void:
	connection_changed.emit(false, "")
	if auto_reconnect and not _last_device_id.is_empty():
		_reconnect_timer.start(reconnect_delay_sec)


func _try_reconnect() -> void:
	if _last_device_id.is_empty() or is_device_connected():
		return
	connect_to_device(_last_device_id)


func _on_bytes_received(data: PackedByteArray) -> void:
	bytes_received.emit(data)


func _on_error(message: String) -> void:
	ble_error.emit(message)
