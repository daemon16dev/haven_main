extends Control
class_name MobileControls

signal look_moved(relative: Vector2)

@export var joystick_radius: float = 65.0
@export var joystick_deadzone: float = 0.15

var player: CharacterBody3D = null

# Joystick tracking
var _move_touch_id: int = -1
var _joystick_home: Vector2 = Vector2.ZERO
var _joystick_center: Vector2 = Vector2.ZERO
var _joystick_knob_pos: Vector2 = Vector2.ZERO
var _move_vector: Vector2 = Vector2.ZERO

# Touch look tracking
var _look_touch_id: int = -1
var _last_look_pos: Vector2 = Vector2.ZERO

# Multi-touch button touch tracking
var _shoot_touch_id: int = -1
var _scope_touch_id: int = -1

# Button nodes
@onready var right_pad: Control = get_node_or_null("RightActionPad")
@onready var btn_shoot: TextureButton = get_node_or_null("RightActionPad/BtnFire")
@onready var btn_scope: TextureButton = get_node_or_null("RightActionPad/BtnScope")
@onready var btn_jump: Button = get_node_or_null("RightActionPad/BtnJump")
@onready var btn_reload: Button = get_node_or_null("RightActionPad/BtnReload")
@onready var btn_crouch: Button = get_node_or_null("RightActionPad/BtnCrouch")
@onready var btn_sprint: Button = get_node_or_null("RightActionPad/BtnSprint")

var is_sprint_active: bool = false
var _buttons_list: Array[Control] = []

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_setup_buttons()
	_update_joystick_home()
	get_viewport().size_changed.connect(_update_joystick_home)

func _update_joystick_home() -> void:
	var vp_size = get_viewport_rect().size
	_joystick_home = Vector2(110.0, vp_size.y - 120.0)
	_joystick_center = _joystick_home
	_joystick_knob_pos = Vector2.ZERO
	queue_redraw()

func _setup_buttons() -> void:
	# Fallback if nodes don't exist yet (e.g. instanced without .tscn)
	if not right_pad:
		right_pad = Control.new()
		right_pad.name = "RightActionPad"
		right_pad.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		right_pad.anchor_left = 1.0
		right_pad.anchor_top = 1.0
		right_pad.anchor_right = 1.0
		right_pad.anchor_bottom = 1.0
		right_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(right_pad)

	# 1. Fire Button (with custom texture asset)
	if not btn_shoot:
		btn_shoot = TextureButton.new()
		btn_shoot.name = "BtnFire"
		btn_shoot.texture_normal = load("res://assets/ui/btn_fire_normal.png")
		btn_shoot.texture_pressed = load("res://assets/ui/btn_fire_pressed.png")
		btn_shoot.ignore_texture_size = true
		btn_shoot.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn_shoot.size = Vector2(100, 100)
		btn_shoot.position = Vector2(-128, -138)
		right_pad.add_child(btn_shoot)
	else:
		if not btn_shoot.texture_normal:
			btn_shoot.texture_normal = load("res://assets/ui/btn_fire_normal.png")
		if not btn_shoot.texture_pressed:
			btn_shoot.texture_pressed = load("res://assets/ui/btn_fire_pressed.png")

	btn_shoot.focus_mode = Control.FOCUS_NONE
	btn_shoot.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	btn_shoot.button_down.connect(_on_shoot_down)
	btn_shoot.button_up.connect(_on_shoot_up)
	_buttons_list.append(btn_shoot)

	# 2. Scope Button (with custom texture asset)
	if not btn_scope:
		btn_scope = TextureButton.new()
		btn_scope.name = "BtnScope"
		btn_scope.texture_normal = load("res://assets/ui/btn_scope_normal.png")
		btn_scope.texture_pressed = load("res://assets/ui/btn_scope_pressed.png")
		btn_scope.ignore_texture_size = true
		btn_scope.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn_scope.size = Vector2(80, 80)
		btn_scope.position = Vector2(-222, -122)
		right_pad.add_child(btn_scope)
	else:
		if not btn_scope.texture_normal:
			btn_scope.texture_normal = load("res://assets/ui/btn_scope_normal.png")
		if not btn_scope.texture_pressed:
			btn_scope.texture_pressed = load("res://assets/ui/btn_scope_pressed.png")

	btn_scope.focus_mode = Control.FOCUS_NONE
	btn_scope.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	btn_scope.button_down.connect(_on_scope_down)
	btn_scope.button_up.connect(_on_scope_up)
	_buttons_list.append(btn_scope)

	# 3. Jump Button
	if not btn_jump:
		btn_jump = Button.new()
		btn_jump.name = "BtnJump"
		btn_jump.text = "🦘\nJUMP"
		btn_jump.size = Vector2(64, 64)
		btn_jump.position = Vector2(-118, -224)
		right_pad.add_child(btn_jump)
	_style_round_button(btn_jump, Color(0.25, 0.75, 0.35, 0.65), 13)
	btn_jump.button_down.connect(func(): Input.action_press("ui_accept"))
	btn_jump.button_up.connect(func(): Input.action_release("ui_accept"))
	_buttons_list.append(btn_jump)

	# 4. Reload Button
	if not btn_reload:
		btn_reload = Button.new()
		btn_reload.name = "BtnReload"
		btn_reload.text = "🔄\nRELOAD"
		btn_reload.size = Vector2(60, 60)
		btn_reload.position = Vector2(-208, -196)
		right_pad.add_child(btn_reload)
	_style_round_button(btn_reload, Color(0.85, 0.7, 0.2, 0.65), 12)
	btn_reload.button_down.connect(func(): Input.action_press("reload"))
	btn_reload.button_up.connect(func(): Input.action_release("reload"))
	_buttons_list.append(btn_reload)

	# 5. Crouch / Slide Button
	if not btn_crouch:
		btn_crouch = Button.new()
		btn_crouch.name = "BtnCrouch"
		btn_crouch.text = "⬇\nSLIDE"
		btn_crouch.size = Vector2(60, 60)
		btn_crouch.position = Vector2(-48, -230)
		right_pad.add_child(btn_crouch)
	_style_round_button(btn_crouch, Color(0.5, 0.3, 0.8, 0.65), 12)
	btn_crouch.button_down.connect(func(): Input.action_press("crouch"))
	btn_crouch.button_up.connect(func(): Input.action_release("crouch"))
	_buttons_list.append(btn_crouch)

	# 6. Sprint Button
	if not btn_sprint:
		btn_sprint = Button.new()
		btn_sprint.name = "BtnSprint"
		btn_sprint.text = "🏃\nRUN"
		btn_sprint.size = Vector2(58, 58)
		btn_sprint.position = Vector2(-292, -88)
		right_pad.add_child(btn_sprint)
	_style_round_button(btn_sprint, Color(0.3, 0.3, 0.4, 0.65), 12)
	btn_sprint.pressed.connect(_toggle_sprint)
	_buttons_list.append(btn_sprint)

func _style_round_button(btn: Button, bg_col: Color, font_sz: int) -> void:
	btn.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	btn.focus_mode = Control.FOCUS_NONE

	var normal = StyleBoxFlat.new()
	normal.bg_color = bg_col
	normal.border_color = Color(1.0, 1.0, 1.0, 0.4)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(30)
	btn.add_theme_stylebox_override("normal", normal)

	var pressed = StyleBoxFlat.new()
	pressed.bg_color = Color(bg_col.r * 1.3, bg_col.g * 1.3, bg_col.b * 1.3, 0.95)
	pressed.border_color = Color(1.0, 0.9, 0.3, 1.0)
	pressed.set_border_width_all(3)
	pressed.set_corner_radius_all(30)
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.add_theme_stylebox_override("hover", normal)
	btn.add_theme_font_size_override("font_size", font_sz)

func _on_shoot_down() -> void:
	Input.action_press("shoot")

func _on_shoot_up() -> void:
	Input.action_release("shoot")

func _on_scope_down() -> void:
	Input.action_press("scope")

func _on_scope_up() -> void:
	Input.action_release("scope")

func _toggle_sprint() -> void:
	is_sprint_active = not is_sprint_active
	if is_sprint_active:
		Input.action_press("sprint")
		var style = btn_sprint.get_theme_stylebox("normal") as StyleBoxFlat
		if style:
			style.bg_color = Color(0.2, 0.85, 0.4, 0.85)
			style.border_color = Color(1.0, 1.0, 0.2, 1.0)
	else:
		Input.action_release("sprint")
		var style = btn_sprint.get_theme_stylebox("normal") as StyleBoxFlat
		if style:
			style.bg_color = Color(0.3, 0.3, 0.4, 0.65)
			style.border_color = Color(1.0, 1.0, 1.0, 0.4)

func _is_touching_button(pos: Vector2) -> bool:
	for b in _buttons_list:
		if b and b.is_visible_in_tree() and b.get_global_rect().has_point(pos):
			return true
	return false

func _input(event: InputEvent) -> void:
	if not visible:
		return

	var vp_size = get_viewport_rect().size

	if event is InputEventScreenTouch:
		if event.pressed:
			# Check direct touch on Fire button
			if btn_shoot and btn_shoot.is_visible_in_tree() and btn_shoot.get_global_rect().has_point(event.position):
				_shoot_touch_id = event.index
				_on_shoot_down()
				btn_shoot.button_pressed = true
				return

			# Check direct touch on Scope button
			if btn_scope and btn_scope.is_visible_in_tree() and btn_scope.get_global_rect().has_point(event.position):
				_scope_touch_id = event.index
				_on_scope_down()
				btn_scope.button_pressed = true
				return

			# Left area: Movement joystick
			if event.position.x < vp_size.x * 0.48 and event.position.y > vp_size.y * 0.25:
				if _move_touch_id == -1:
					_move_touch_id = event.index
					_joystick_center = event.position
					_update_joystick(event.position)
			# Right area: Camera drag look (if not pressing any action button)
			elif event.position.x >= vp_size.x * 0.45:
				if not _is_touching_button(event.position):
					if _look_touch_id == -1:
						_look_touch_id = event.index
						_last_look_pos = event.position
		else:
			if event.index == _shoot_touch_id:
				_shoot_touch_id = -1
				_on_shoot_up()
				if btn_shoot:
					btn_shoot.button_pressed = false
			elif event.index == _scope_touch_id:
				_scope_touch_id = -1
				_on_scope_up()
				if btn_scope:
					btn_scope.button_pressed = false
			elif event.index == _move_touch_id:
				_reset_joystick()
			elif event.index == _look_touch_id:
				_look_touch_id = -1

	elif event is InputEventScreenDrag:
		if event.index == _move_touch_id:
			_update_joystick(event.position)
		elif event.index == _look_touch_id:
			var rel = event.relative
			look_moved.emit(rel)
			_last_look_pos = event.position

func _update_joystick(touch_pos: Vector2) -> void:
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

	_apply_movement(_move_vector)

func _reset_joystick() -> void:
	_move_touch_id = -1
	_joystick_center = _joystick_home
	_joystick_knob_pos = Vector2.ZERO
	_move_vector = Vector2.ZERO
	_apply_movement(Vector2.ZERO)
	queue_redraw()

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

func reset_all_inputs() -> void:
	_reset_joystick()
	_look_touch_id = -1
	if _shoot_touch_id != -1:
		_shoot_touch_id = -1
		_on_shoot_up()
		if btn_shoot:
			btn_shoot.button_pressed = false
	if _scope_touch_id != -1:
		_scope_touch_id = -1
		_on_scope_up()
		if btn_scope:
			btn_scope.button_pressed = false
	if is_sprint_active:
		_toggle_sprint()
	Input.action_release("shoot")
	Input.action_release("scope")
	Input.action_release("ui_accept")
	Input.action_release("crouch")
	Input.action_release("reload")

func _draw() -> void:
	if not visible:
		return

	# Draw virtual joystick base ring
	draw_circle(_joystick_center, joystick_radius, Color(0.1, 0.12, 0.18, 0.42))
	draw_arc(_joystick_center, joystick_radius, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.35), 2.0)
	draw_arc(_joystick_center, joystick_radius * joystick_deadzone, 0.0, TAU, 16, Color(1.0, 1.0, 1.0, 0.15), 1.0)

	# Draw movable knob
	var knob_center = _joystick_center + _joystick_knob_pos
	draw_circle(knob_center, 28.0, Color(0.85, 0.9, 1.0, 0.65))
	draw_arc(knob_center, 28.0, 0.0, TAU, 24, Color(1.0, 1.0, 1.0, 0.9), 2.0)
