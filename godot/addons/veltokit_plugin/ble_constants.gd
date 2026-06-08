class_name VeltoKitBleConstants
extends RefCounted

## Nordic UART Service — same UUIDs as VeltoKit/TrikiBLEManager.swift
## Note: byte packets are static funcs (PackedByteArray() is not a const expression in GDScript).

const NUS_SERVICE := "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
const NUS_RX_CHAR := "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
const NUS_TX_CHAR := "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"


static func init_packet() -> PackedByteArray:
	var p := PackedByteArray()
	p.append(0x01)
	p.append(0x00)
	return p


static func start_packet() -> PackedByteArray:
	var p := PackedByteArray()
	p.append_array([0x20, 0x10, 0x00, 0xD0, 0x07, 0x34, 0x00, 0x03])
	return p


static func is_likely_triki_name(device_name: String) -> bool:
	var n := device_name.to_lower()
	return "triki" in n or "nordic" in n or "uart" in n or "velto" in n
