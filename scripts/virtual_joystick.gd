extends Control

signal joystick_moved(vector: Vector2)
signal joystick_released()

@export_group("Joystick Configuration")
@export var joystick_radius: float = 80.0
@export var joystick_deadzone: float = 0.15
@export var auto_apply_input: bool = true
@export var dynamic_positioning: bool = true

@export_group("Visuals & Colors")
@export var base_texture: Texture2D = null
@export var knob_texture: Texture2D = null
@export var base_color: Color = Color(0.1, 0.12, 0.18, 0.45)
@export var ring_color: Color = Color(1.0, 1.0, 1.0, 0.35)
@export var knob_color: Color = Color(0.85, 0.9, 1.0, 0.65)
@export var knob_ring_color: Color = Color(1.0, 1.0, 1.0, 0.9)
@export var knob_radius: float = 28.0

var _touch_id: int = -1
var _joystick_home: Vector2 = Vector2.ZERO
var _joystick_center: Vector2 = Vector2.ZERO
var _joystick_knob_pos: Vector2 = Vector2.ZERO
var _move_vector: Vector2 = Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_update_home_position()
	get_viewport().size_changed.connect(_update_home_position)

func _update_home_position() -> void:
	var vp_size = get_viewport_rect().size
	_joystick_home = Vector2(110.0, vp_size.y - 120.0)
	if _touch_id == -1:
		_joystick_center = _joystick_home
		_joystick_knob_pos = Vector2.ZERO
	queue_redraw()

func get_movement_vector() -> Vector2:
	return _move_vector

func is_active() -> bool:
	return _touch_id != -1

func reset() -> void:
	_touch_id = -1
	_joystick_center = _joystick_home
	_joystick_knob_pos = Vector2.ZERO
	_move_vector = Vector2.ZERO
	if auto_apply_input:
		_apply_movement(Vector2.ZERO)
	joystick_released.emit()
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not visible:
		return

	var vp_size = get_viewport_rect().size

	if event is InputEventScreenTouch:
		if event.pressed:
			# Left area touch initiates joystick (X < 48% of screen and Y > 20% of screen)
			if event.position.x < vp_size.x * 0.48 and event.position.y > vp_size.y * 0.20:
				if _touch_id == -1:
					_touch_id = event.index
					if dynamic_positioning:
						_joystick_center = event.position
					else:
						_joystick_center = _joystick_home
					_update_touch(event.position)
		else:
			if event.index == _touch_id:
				reset()

	elif event is InputEventScreenDrag:
		if event.index == _touch_id:
			_update_touch(event.position)

func _update_touch(touch_pos: Vector2) -> void:
	var diff = touch_pos - _joystick_center
	var dist = diff.length()
	if dist > joystick_radius:
		diff = diff.normalized() * joystick_radius
	_joystick_knob_pos = diff
	queue_redraw()

	var norm = diff / joystick_radius
	if norm.length() < joystick_deadzone:
		_move_vector = Vector2.ZERO
	else:
		_move_vector = norm

	if auto_apply_input:
		_apply_movement(_move_vector)

	joystick_moved.emit(_move_vector)

func _apply_movement(vec: Vector2) -> void:
	# Strafe X: -1 Left, +1 Right
	if vec.x < -joystick_deadzone:
		Input.action_press("strafe_left", -vec.x)
		Input.action_release("strafe_right")
	elif vec.x > joystick_deadzone:
		Input.action_press("strafe_right", vec.x)
		Input.action_release("strafe_left")
	else:
		Input.action_release("strafe_left")
		Input.action_release("strafe_right")

	# Walk Y: -1 Forward, +1 Backward
	if vec.y < -joystick_deadzone:
		Input.action_press("walk_forward", -vec.y)
		Input.action_release("walk_backward")
	elif vec.y > joystick_deadzone:
		Input.action_press("walk_backward", vec.y)
		Input.action_release("walk_forward")
	else:
		Input.action_release("walk_forward")
		Input.action_release("walk_backward")

func _draw() -> void:
	if not visible:
		return

	# Draw Base
	if base_texture:
		var base_rect = Rect2(_joystick_center - Vector2(joystick_radius, joystick_radius), Vector2(joystick_radius * 2.0, joystick_radius * 2.0))
		draw_texture_rect(base_texture, base_rect, false)
	else:
		draw_circle(_joystick_center, joystick_radius, base_color)
		draw_arc(_joystick_center, joystick_radius, 0.0, TAU, 32, ring_color, 2.0)
		draw_arc(_joystick_center, joystick_radius * joystick_deadzone, 0.0, TAU, 16, Color(ring_color.r, ring_color.g, ring_color.b, ring_color.a * 0.4), 1.0)

	# Draw Knob
	var knob_center = _joystick_center + _joystick_knob_pos
	if knob_texture:
		var knob_rect = Rect2(knob_center - Vector2(knob_radius, knob_radius), Vector2(knob_radius * 2.0, knob_radius * 2.0))
		draw_texture_rect(knob_texture, knob_rect, false)
	else:
		draw_circle(knob_center, knob_radius, knob_color)
		draw_arc(knob_center, knob_radius, 0.0, TAU, 24, knob_ring_color, 2.0)
