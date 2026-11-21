extends Control
class_name MobileControls

signal look_moved(relative: Vector2)

var player: CharacterBody3D = null

# Child Joystick
const JoystickScript = preload("res://scripts/virtual_joystick.gd")
@onready var joystick: Control = get_node_or_null("VirtualJoystick") as Control

# Touch look tracking
var _look_touch_id: int = -1
var _last_look_pos: Vector2 = Vector2.ZERO

# Multi-touch button touch tracking
var _shoot_touch_id: int = -1
var _scope_touch_id: int = -1
var _jump_touch_id: int = -1
var _reload_touch_id: int = -1
var _crouch_touch_id: int = -1

# Button nodes (support both TextureButton and Button)
@onready var right_pad: Control = get_node_or_null("RightActionPad")
@onready var btn_shoot: BaseButton = get_node_or_null("RightActionPad/BtnFire") as BaseButton
@onready var btn_scope: BaseButton = get_node_or_null("RightActionPad/BtnScope") as BaseButton
@onready var btn_jump: BaseButton = get_node_or_null("RightActionPad/BtnJump") as BaseButton
@onready var btn_reload: BaseButton = get_node_or_null("RightActionPad/BtnReload") as BaseButton
@onready var btn_crouch: BaseButton = get_node_or_null("RightActionPad/BtnCrouch") as BaseButton
@onready var btn_sprint: BaseButton = get_node_or_null("RightActionPad/BtnSprint") as BaseButton

var is_sprint_active: bool = false
var _buttons_list: Array[Control] = []

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_setup_joystick()
	_setup_buttons()

func _setup_joystick() -> void:
	if not joystick:
		joystick = get_node_or_null("VirtualJoystick") as Control
	if not joystick:
		var joy_scene = load("res://scenes/virtual_joystick.tscn")
		if joy_scene:
			joystick = joy_scene.instantiate() as Control
			add_child(joystick)
			move_child(joystick, 0)

func _setup_buttons() -> void:
	if not right_pad:
		right_pad = get_node_or_null("RightActionPad")

	# Register and configure all action buttons
	var btns = [btn_shoot, btn_scope, btn_jump, btn_reload, btn_crouch, btn_sprint]
	for b in btns:
		if b and is_instance_valid(b):
			b.focus_mode = Control.FOCUS_NONE
			b.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
			if b is TextureButton:
				b.ignore_texture_size = true
				b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			elif b is Button:
				_style_round_button(b)
			if not _buttons_list.has(b):
				_buttons_list.append(b)

	# Connect button events
	if btn_shoot:
		btn_shoot.button_down.connect(_on_shoot_down)
		btn_shoot.button_up.connect(_on_shoot_up)
	if btn_scope:
		btn_scope.button_down.connect(_on_scope_down)
		btn_scope.button_up.connect(_on_scope_up)
	if btn_jump:
		btn_jump.button_down.connect(func(): Input.action_press("ui_accept"))
		btn_jump.button_up.connect(func(): Input.action_release("ui_accept"))
	if btn_reload:
		btn_reload.button_down.connect(func(): Input.action_press("reload"))
		btn_reload.button_up.connect(func(): Input.action_release("reload"))
	if btn_crouch:
		btn_crouch.button_down.connect(func(): Input.action_press("crouch"))
		btn_crouch.button_up.connect(func(): Input.action_release("crouch"))
	if btn_sprint:
		btn_sprint.pressed.connect(_toggle_sprint)

func _style_round_button(btn: Button) -> void:
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0.18, 0.22, 0.28, 0.65)
	normal.border_color = Color(1.0, 1.0, 1.0, 0.4)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(30)
	btn.add_theme_stylebox_override("normal", normal)

	var pressed = StyleBoxFlat.new()
	pressed.bg_color = Color(0.35, 0.45, 0.55, 0.9)
	pressed.border_color = Color(1.0, 0.9, 0.3, 1.0)
	pressed.set_border_width_all(3)
	pressed.set_corner_radius_all(30)
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.add_theme_stylebox_override("hover", normal)
	btn.add_theme_font_size_override("font_size", 12)

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
		if btn_sprint:
			if btn_sprint is TextureButton:
				btn_sprint.modulate = Color(0.35, 1.0, 0.45, 1.0)
			elif btn_sprint is Button:
				var style = btn_sprint.get_theme_stylebox("normal") as StyleBoxFlat
				if style:
					style.bg_color = Color(0.2, 0.85, 0.4, 0.85)
	else:
		Input.action_release("sprint")
		if btn_sprint:
			if btn_sprint is TextureButton:
				btn_sprint.modulate = Color.WHITE
			elif btn_sprint is Button:
				var style = btn_sprint.get_theme_stylebox("normal") as StyleBoxFlat
				if style:
					style.bg_color = Color(0.18, 0.22, 0.28, 0.65)

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
			# Direct touch on action buttons
			if btn_shoot and btn_shoot.is_visible_in_tree() and btn_shoot.get_global_rect().has_point(event.position):
				_shoot_touch_id = event.index
				_on_shoot_down()
				if btn_shoot is TextureButton:
					btn_shoot.button_pressed = true
				return

			if btn_scope and btn_scope.is_visible_in_tree() and btn_scope.get_global_rect().has_point(event.position):
				_scope_touch_id = event.index
				_on_scope_down()
				if btn_scope is TextureButton:
					btn_scope.button_pressed = true
				return

			if btn_jump and btn_jump.is_visible_in_tree() and btn_jump.get_global_rect().has_point(event.position):
				_jump_touch_id = event.index
				Input.action_press("ui_accept")
				if btn_jump is TextureButton:
					btn_jump.button_pressed = true
				return

			if btn_reload and btn_reload.is_visible_in_tree() and btn_reload.get_global_rect().has_point(event.position):
				_reload_touch_id = event.index
				Input.action_press("reload")
				if btn_reload is TextureButton:
					btn_reload.button_pressed = true
				return

			if btn_crouch and btn_crouch.is_visible_in_tree() and btn_crouch.get_global_rect().has_point(event.position):
				_crouch_touch_id = event.index
				Input.action_press("crouch")
				if btn_crouch is TextureButton:
					btn_crouch.button_pressed = true
				return

			if btn_sprint and btn_sprint.is_visible_in_tree() and btn_sprint.get_global_rect().has_point(event.position):
				_toggle_sprint()
				return

			# Camera drag look area: Right side of screen (X >= 45% and not touching any button)
			if event.position.x >= vp_size.x * 0.45:
				if not _is_touching_button(event.position):
					if _look_touch_id == -1:
						_look_touch_id = event.index
						_last_look_pos = event.position
		else:
			if event.index == _shoot_touch_id:
				_shoot_touch_id = -1
				_on_shoot_up()
				if btn_shoot and btn_shoot is TextureButton:
					btn_shoot.button_pressed = false
			elif event.index == _scope_touch_id:
				_scope_touch_id = -1
				_on_scope_up()
				if btn_scope and btn_scope is TextureButton:
					btn_scope.button_pressed = false
			elif event.index == _jump_touch_id:
				_jump_touch_id = -1
				Input.action_release("ui_accept")
				if btn_jump and btn_jump is TextureButton:
					btn_jump.button_pressed = false
			elif event.index == _reload_touch_id:
				_reload_touch_id = -1
				Input.action_release("reload")
				if btn_reload and btn_reload is TextureButton:
					btn_reload.button_pressed = false
			elif event.index == _crouch_touch_id:
				_crouch_touch_id = -1
				Input.action_release("crouch")
				if btn_crouch and btn_crouch is TextureButton:
					btn_crouch.button_pressed = false
			elif event.index == _look_touch_id:
				_look_touch_id = -1

	elif event is InputEventScreenDrag:
		if event.index == _look_touch_id:
			var rel = event.relative
			look_moved.emit(rel)
			_last_look_pos = event.position

func reset_all_inputs() -> void:
	if joystick:
		joystick.reset()
	_look_touch_id = -1
	if _shoot_touch_id != -1:
		_shoot_touch_id = -1
		_on_shoot_up()
		if btn_shoot and btn_shoot is TextureButton:
			btn_shoot.button_pressed = false
	if _scope_touch_id != -1:
		_scope_touch_id = -1
		_on_scope_up()
		if btn_scope and btn_scope is TextureButton:
			btn_scope.button_pressed = false
	if _jump_touch_id != -1:
		_jump_touch_id = -1
		Input.action_release("ui_accept")
		if btn_jump and btn_jump is TextureButton:
			btn_jump.button_pressed = false
	if _reload_touch_id != -1:
		_reload_touch_id = -1
		Input.action_release("reload")
		if btn_reload and btn_reload is TextureButton:
			btn_reload.button_pressed = false
	if _crouch_touch_id != -1:
		_crouch_touch_id = -1
		Input.action_release("crouch")
		if btn_crouch and btn_crouch is TextureButton:
			btn_crouch.button_pressed = false
	if is_sprint_active:
		_toggle_sprint()
	Input.action_release("shoot")
	Input.action_release("scope")
	Input.action_release("ui_accept")
	Input.action_release("crouch")
	Input.action_release("reload")
