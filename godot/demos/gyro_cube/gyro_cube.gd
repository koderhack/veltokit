extends MeshInstance3D

## Demo: rotate cube from Triki gyro (VeltoKit singleton).
## x → rotation.y, y → rotation.x

@export var rotation_scale: float = 2.5
@export var smoothing: float = 8.0

var _target_rot := Vector3.ZERO
var _connected := false


func _ready() -> void:
	VeltoKit.gyro_updated.connect(_on_gyro_updated)
	VeltoKit.connection_changed.connect(_on_connection_changed)
	VeltoKit.connect_triki()


func _process(delta: float) -> void:
	var current := rotation_degrees
	current.x = lerpf(current.x, _target_rot.x, smoothing * delta)
	current.y = lerpf(current.y, _target_rot.y, smoothing * delta)
	rotation_degrees = current


func _on_gyro_updated(x: float, y: float, z: float) -> void:
	# Map gyro axes to cube tilt (radians → degrees).
	_target_rot.y = x * rotation_scale * 57.2958
	_target_rot.x = -y * rotation_scale * 57.2958
	# z available for roll if needed: _target_rot.z = z * rotation_scale * 57.2958


func _on_connection_changed(connected: bool) -> void:
	_connected = connected
	if connected:
		print("VeltoKit: połączono (sim=%s)" % VeltoKit.using_simulator())
	else:
		print("VeltoKit: rozłączono")
