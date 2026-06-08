class_name VeltoKitBleBackendSim
extends RefCounted

## Desktop/editor stub — replays synthetic Triki packets (no real BLE).

signal scan_finished(devices: Array)
signal connected(device_id: String, device_name: String)
signal disconnected()
signal bytes_received(data: PackedByteArray)
signal error(message: String)

var _connected := false
var _device_id := "sim-triki-001"
var _device_name := "Triki (simulator)"
var _phase := 0.0


func start_scan() -> void:
	var devices: Array = [
		{"id": _device_id, "name": _device_name, "rssi": -42}
	]
	scan_finished.emit(devices)


func stop_scan() -> void:
	pass


func connect_to_device(device_id: String) -> void:
	if device_id != _device_id:
		error.emit("Simulator: unknown device %s" % device_id)
		return
	_connected = true
	connected.emit(_device_id, _device_name)


func disconnect_device() -> void:
	if not _connected:
		return
	_connected = false
	disconnected.emit()


func is_device_connected() -> bool:
	return _connected


func tick(delta: float) -> void:
	if not _connected:
		return
	_phase += delta * 1.8
	var raw_y := int(sin(_phase) * 800.0)
	var raw_x := int(cos(_phase * 0.7) * 400.0)
	var raw_z := int(sin(_phase * 0.3) * 200.0)
	var packet := _make_packet(raw_x, raw_y, raw_z)
	bytes_received.emit(packet)


func _make_packet(raw_x: int, raw_y: int, raw_z: int) -> PackedByteArray:
	var p := PackedByteArray()
	p.resize(8)
	p[0] = 0x22
	p[1] = 0x00
	_write_i16_le(p, 2, raw_x)
	_write_i16_le(p, 4, raw_y)
	_write_i16_le(p, 6, raw_z)
	return p


static func _write_i16_le(buf: PackedByteArray, index: int, value: int) -> void:
	var v := value
	if v < 0:
		v += 0x10000
	buf[index] = v & 0xFF
	buf[index + 1] = (v >> 8) & 0xFF
