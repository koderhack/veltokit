extends Control

## Triki Pong — brick-breaker sterowany żyroskopem (oś X → paletka).
## Desktop: symulator VeltoKit; Android: prawdziwe BLE po dodaniu pluginu natywnego.

const VIEW_SIZE := Vector2(480, 720)

const PADDLE_W := 96.0
const PADDLE_H := 14.0
const BALL_SIZE := 10.0
const BALL_SPEED := 340.0
const PADDLE_Y := 640.0
const PADDLE_GYRO_SCALE := 220.0
const PADDLE_SMOOTHING := 10.0
const PADDLE_MAX_STEP := 18.0

const BRICK_W := 52.0
const BRICK_H := 22.0
const BRICK_GAP_X := 6.0
const BRICK_GAP_Y := 6.0
const BRICK_TOP := 120.0
const BRICK_COLS := 7
const BRICK_ROWS := [1, 1, 2, 2, 3]

const COLOR_BG := Color(0.07, 0.09, 0.13)
const COLOR_PADDLE := Color(0.25, 0.78, 0.95)
const COLOR_BALL := Color(0.95, 0.92, 0.35)
const COLOR_BRICK := {
	1: Color(0.35, 0.85, 0.9),
	2: Color(0.95, 0.82, 0.25),
	3: Color(0.95, 0.35, 0.35),
}

class Brick:
	var node: ColorRect
	var hp: int
	var max_hp: int

	func alive() -> bool:
		return hp > 0

	func points() -> int:
		return max_hp * 30


var _paddle: ColorRect
var _ball: ColorRect
var _bricks: Array[Brick] = []

var _paddle_x := VIEW_SIZE.x * 0.5
var _target_paddle_x := _paddle_x
var _gyro_x := 0.0
var _gyro_seeded := false

var _ball_pos := Vector2.ZERO
var _ball_vel := Vector2.ZERO

var _score := 0
var _lives := 5
var _game_over := false
var _win := false
var _connected := false

@onready var _score_label: Label = $HUD/ScoreLabel
@onready var _status_label: Label = $HUD/StatusLabel
@onready var _hint_label: Label = $HUD/HintLabel


func _ready() -> void:
	custom_minimum_size = VIEW_SIZE
	_build_paddle()
	_build_ball()
	_spawn_bricks()
	_reset_ball(true)
	_update_hud()

	VeltoKit.gyro_updated.connect(_on_gyro_updated)
	VeltoKit.connection_changed.connect(_on_connection_changed)
	VeltoKit.connect_triki()


func _process(delta: float) -> void:
	if not _game_over:
		_update_paddle(delta)
		_step_physics(delta)
	_update_hud()


func _build_paddle() -> void:
	_paddle = ColorRect.new()
	_paddle.color = COLOR_PADDLE
	_paddle.size = Vector2(PADDLE_W, PADDLE_H)
	_paddle.position = Vector2(_paddle_x - PADDLE_W * 0.5, PADDLE_Y)
	add_child(_paddle)


func _build_ball() -> void:
	_ball = ColorRect.new()
	_ball.color = COLOR_BALL
	_ball.size = Vector2(BALL_SIZE, BALL_SIZE)
	add_child(_ball)


func _spawn_bricks() -> void:
	for brick in _bricks:
		if is_instance_valid(brick.node):
			brick.node.queue_free()
	_bricks.clear()

	var row_width := BRICK_COLS * BRICK_W + (BRICK_COLS - 1) * BRICK_GAP_X
	var start_x := (VIEW_SIZE.x - row_width) * 0.5

	for row in BRICK_ROWS.size():
		var hp: int = BRICK_ROWS[row]
		for col in BRICK_COLS:
			var rect := ColorRect.new()
			rect.color = COLOR_BRICK[hp]
			rect.size = Vector2(BRICK_W, BRICK_H)
			rect.position = Vector2(
				start_x + col * (BRICK_W + BRICK_GAP_X),
				BRICK_TOP + row * (BRICK_H + BRICK_GAP_Y)
			)
			add_child(rect)
			var b := Brick.new()
			b.node = rect
			b.hp = hp
			b.max_hp = hp
			_bricks.append(b)


func _reset_ball(serve_from_paddle: bool) -> void:
	_ball_pos = Vector2(_paddle_x, PADDLE_Y - BALL_SIZE - 4.0)
	_ball_vel = Vector2(0.0, -BALL_SPEED) if serve_from_paddle else Vector2(0.0, BALL_SPEED)
	_sync_ball()


func _restart_match() -> void:
	_score = 0
	_lives = 5
	_game_over = false
	_win = false
	_spawn_bricks()
	_reset_ball(true)


func _update_paddle(delta: float) -> void:
	var half := PADDLE_W * 0.5
	var min_x := half + 8.0
	var max_x := VIEW_SIZE.x - half - 8.0

	if not _gyro_seeded:
		_target_paddle_x = clampf(_paddle_x, min_x, max_x)
	else:
		_target_paddle_x = clampf(VIEW_SIZE.x * 0.5 + _gyro_x * PADDLE_GYRO_SCALE, min_x, max_x)

	var step := clampf(_target_paddle_x - _paddle_x, -PADDLE_MAX_STEP, PADDLE_MAX_STEP)
	_paddle_x = lerpf(_paddle_x, _paddle_x + step, PADDLE_SMOOTHING * delta)
	_paddle.position.x = _paddle_x - half


func _step_physics(delta: float) -> void:
	if _ball_vel.length_squared() < 1.0:
		return

	var steps := maxi(1, int(ceil(delta * 120.0)))
	var dt := delta / float(steps)
	for _i in steps:
		_ball_pos += _ball_vel * dt
		_handle_wall_bounce()
		_handle_paddle_bounce()
		_handle_brick_hits()
		if _game_over:
			break
	_sync_ball()


func _handle_wall_bounce() -> void:
	var half := BALL_SIZE * 0.5
	if _ball_pos.x - half <= 0.0:
		_ball_pos.x = half
		_ball_vel.x = absf(_ball_vel.x)
	elif _ball_pos.x + half >= VIEW_SIZE.x:
		_ball_pos.x = VIEW_SIZE.x - half
		_ball_vel.x = -absf(_ball_vel.x)

	if _ball_pos.y - half <= 0.0:
		_ball_pos.y = half
		_ball_vel.y = absf(_ball_vel.y)


func _handle_paddle_bounce() -> void:
	if _ball_vel.y <= 0.0:
		return
	var half := BALL_SIZE * 0.5
	var paddle_top := PADDLE_Y
	if _ball_pos.y + half < paddle_top:
		return
	if _ball_pos.y + half > paddle_top + PADDLE_H + 6.0:
		return
	if absf(_ball_pos.x - _paddle_x) > PADDLE_W * 0.5 + half:
		return

	_ball_pos.y = paddle_top - half - 0.5
	var hit := clampf((_ball_pos.x - _paddle_x) / (PADDLE_W * 0.5), -1.0, 1.0)
	_ball_vel.y = -absf(_ball_vel.y)
	_ball_vel.x = hit * BALL_SPEED * 0.85


func _handle_brick_hits() -> void:
	var half := BALL_SIZE * 0.5
	for brick in _bricks:
		if not brick.alive():
			continue
		var rect := brick.node
		var bmin := rect.position
		var bmax := rect.position + rect.size
		if _ball_pos.x + half < bmin.x or _ball_pos.x - half > bmax.x:
			continue
		if _ball_pos.y + half < bmin.y or _ball_pos.y - half > bmax.y:
			continue

		var overlap_left := (_ball_pos.x + half) - bmin.x
		var overlap_right := bmax.x - (_ball_pos.x - half)
		var overlap_top := (_ball_pos.y + half) - bmin.y
		var overlap_bottom := bmax.y - (_ball_pos.y - half)
		var min_overlap := minf(minf(overlap_left, overlap_right), minf(overlap_top, overlap_bottom))

		if min_overlap == overlap_left or min_overlap == overlap_right:
			_ball_vel.x = -_ball_vel.x
		else:
			_ball_vel.y = -_ball_vel.y

		brick.hp -= 1
		if brick.alive():
			brick.node.color = COLOR_BRICK[brick.hp]
		else:
			brick.node.visible = false
			_score += brick.points()
		break

	var all_cleared := true
	for brick in _bricks:
		if brick.alive():
			all_cleared = false
			break
	if all_cleared:
		_win = true
		_game_over = true

	var half2 := BALL_SIZE * 0.5
	if _ball_pos.y - half2 > VIEW_SIZE.y + 20.0:
		_lives -= 1
		if _lives <= 0:
			_game_over = true
		else:
			_reset_ball(true)


func _sync_ball() -> void:
	_ball.position = _ball_pos - Vector2(BALL_SIZE, BALL_SIZE) * 0.5


func _update_hud() -> void:
	var sim_tag := "sim" if VeltoKit.using_simulator() else "BLE"
	var conn := "✓ Triki (%s)" % sim_tag if _connected else "… łączenie"
	_status_label.text = conn

	if _game_over:
		if _win:
			_score_label.text = "Wygrana! %d pkt — Enter: nowa gra" % _score
		else:
			_score_label.text = "Koniec — %d pkt — Enter: nowa gra" % _score
	else:
		_score_label.text = "Punkty: %d   Życia: %d" % [_score, _lives]


func _on_gyro_updated(x: float, _y: float, _z: float) -> void:
	_gyro_x = x
	_gyro_seeded = true


func _on_connection_changed(connected: bool) -> void:
	_connected = connected
	if connected:
		VeltoKit.calibrate_neutral()
		_gyro_seeded = false
		print("Triki Pong: połączono (sim=%s)" % VeltoKit.using_simulator())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and _game_over:
		_restart_match()
	# Klawiatura jako fallback (strzałki / A D).
	if event is InputEventKey and event.pressed and not _game_over:
		var key := event as InputEventKey
		if key.keycode == KEY_LEFT or key.keycode == KEY_A:
			_gyro_x = -0.45
			_gyro_seeded = true
		elif key.keycode == KEY_RIGHT or key.keycode == KEY_D:
			_gyro_x = 0.45
			_gyro_seeded = true
