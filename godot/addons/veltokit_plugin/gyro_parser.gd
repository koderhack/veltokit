class_name VeltoKitGyroParser
extends RefCounted

## Parses Triki BLE notify bytes (VeltoKit / BLEGyroParser legacy block).
## Block: [0x22, 0x00] + int16 LE x,y,z @ offsets 2,4,6 — divide by 2000.

const HEADER_0: int = 0x22
const HEADER_1: int = 0x00
const BLOCK_SIZE: int = 8
const GYRO_DIVISOR: float = 2000.0

var _buffer: PackedByteArray = PackedByteArray()


func reset() -> void:
	_buffer.clear()


func ingest(data: PackedByteArray) -> Array:
	var out: Array = []
	if data.is_empty():
		return out
	_buffer.append_array(data)
	while _buffer.size() >= BLOCK_SIZE:
		if _buffer[0] != HEADER_0 or _buffer[1] != HEADER_1:
			var next := _find_header(1)
			if next < 0:
				_buffer.clear()
				break
			_buffer = _buffer.slice(next)
			continue
		var block := _buffer.slice(0, BLOCK_SIZE)
		_buffer = _buffer.slice(BLOCK_SIZE)
		out.append(parse_block(block))
	_trim_buffer()
	return out


func parse_block(block: PackedByteArray) -> Vector3:
	if block.size() < BLOCK_SIZE:
		return Vector3.ZERO
	if block[0] != HEADER_0 or block[1] != HEADER_1:
		return Vector3.ZERO
	var raw_x := _read_int16_le(block, 2)
	var raw_y := _read_int16_le(block, 4)
	var raw_z := _read_int16_le(block, 6)
	return Vector3(
		float(raw_x) / GYRO_DIVISOR,
		float(raw_y) / GYRO_DIVISOR,
		float(raw_z) / GYRO_DIVISOR
	)


func get_latest_gyro() -> Vector3:
	if _buffer.size() < BLOCK_SIZE:
		return Vector3.ZERO
	var parsed := ingest(PackedByteArray())
	if parsed.is_empty():
		return Vector3.ZERO
	return parsed[1] if parsed.size() >= 2 else parsed[parsed.size() - 1]


func _find_header(from_index: int) -> int:
	for i in range(from_index, _buffer.size() - 1):
		if _buffer[i] == HEADER_0 and _buffer[i + 1] == HEADER_1:
			return i
	return -1


func _trim_buffer() -> void:
	const MAX_KEEP := 512
	if _buffer.size() > 1024:
		_buffer = _buffer.slice(_buffer.size() - MAX_KEEP)


static func _read_int16_le(data: PackedByteArray, index: int) -> int:
	if index + 1 >= data.size():
		return 0
	var lo: int = data[index]
	var hi: int = data[index + 1]
	var raw: int = lo | (hi << 8)
	if raw & 0x8000:
		raw -= 0x10000
	return raw
