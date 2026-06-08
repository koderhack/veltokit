class_name VeltoKitBleBackendAndroid
extends RefCounted

## Android BLE via optional Godot Android plugin singleton "GodotVeltoKitBLE".
## Build the Java/Kotlin plugin from addons/veltokit_plugin/android/ (see README).

signal scan_finished(devices: Array)
signal connected(device_id: String, device_name: String)
signal disconnected()
signal bytes_received(data: PackedByteArray)
signal error(message: String)

var _native: Object = null
var _connected := false


func _init() -> void:
	if Engine.has_singleton("GodotVeltoKitBLE"):
		_native = Engine.get_singleton("GodotVeltoKitBLE")
		if _native.has_signal("bytes_received"):
			_native.bytes_received.connect(_on_native_bytes)
		if _native.has_signal("connected"):
			_native.connected.connect(_on_native_connected)
		if _native.has_signal("disconnected"):
			_native.disconnected.connect(_on_native_disconnected)
		if _native.has_signal("scan_result"):
			_native.scan_result.connect(_on_native_scan)
		if _native.has_signal("error"):
			_native.error.connect(_on_native_error)


func is_available() -> bool:
	return _native != null


func start_scan() -> void:
	if _native == null:
		error.emit("Android BLE plugin not installed — use simulator on desktop")
		scan_finished.emit([])
		return
	if _native.has_method("start_scan"):
		_native.start_scan()


func stop_scan() -> void:
	if _native and _native.has_method("stop_scan"):
		_native.stop_scan()


func connect_to_device(device_id: String) -> void:
	if _native == null:
		error.emit("Android BLE plugin missing")
		return
	# Object.connect() needs (signal, callable) — native BLE uses call().
	if _native.has_method("connect_device"):
		_native.call("connect_device", device_id)


func disconnect_device() -> void:
	if _native and _native.has_method("disconnect_device"):
		_native.call("disconnect_device")
	_connected = false


func is_device_connected() -> bool:
	return _connected


func _on_native_bytes(data: PackedByteArray) -> void:
	bytes_received.emit(data)


func _on_native_connected(device_id: String, device_name: String) -> void:
	_connected = true
	connected.emit(device_id, device_name)


func _on_native_disconnected() -> void:
	_connected = false
	disconnected.emit()


func _on_native_scan(devices: Array) -> void:
	scan_finished.emit(devices)


func _on_native_error(message: String) -> void:
	error.emit(message)
