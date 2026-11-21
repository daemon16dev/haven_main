extends CharacterBody3D

@onready var health = $Canvas/Health
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera # Change to $Head/Camera3D if named Camera3D
@onready var standing_collision: CollisionShape3D = $StandingCollision
@onready var crouch_collider: CollisionShape3D = $CrouchCollider

var HEALTH: int = 100
@export var max_health: int = 100
var is_dead: bool = false
var damage_overlay: ColorRect = null

@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.5
@export var crouch_speed: float = 2.5
@export var slide_speed: float = 11.0
@export var jump_velocity: float = 4.5

@export var mouse_sensitivity: float = 0.003
@export var slide_duration: float = 0.65
@export var slide_cooldown: float = 1.0

var is_crouching: bool = false
var is_sliding: bool = false
var slide_timer: float = 0.0
var slide_cooldown_timer: float = 0.0
var slide_direction: Vector3 = Vector3.ZERO

var stand_head_y: float = 0.0
@export var crouch_head_offset: float = -0.6

# Low health surge configuration
@export var low_health_threshold: int = 30
@export var surge_cooldown: float = 35.0
@export var invincibility_duration: float = 2.0
@export var damage_boost_duration: float = 6.0

var is_invincible: bool = false
var is_surge_active: bool = false
var invincibility_timer: float = 0.0
var surge_damage_timer: float = 0.0
var surge_cooldown_timer: float = 0.0

var surge_overlay: ColorRect = null
var surge_mat: ShaderMaterial = null
var surge_label: Label = null

func _ready() -> void:
	HEALTH = max_health
	stand_head_y = head.position.y
	_set_collision_state(false) # Start standing
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_setup_ui()

func _setup_ui() -> void:
	_update_health_ui()
	var canvas := get_node_or_null("Canvas")
	if canvas:
		# Low health vision blur + Night Light temperature filter overlay
		surge_overlay = ColorRect.new()
		surge_overlay.name = "SurgeOverlay"
		surge_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		surge_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		surge_mat = ShaderMaterial.new()
		var shader = load("res://assets/shaders/low_health_effect.gdshader")
		if shader:
			surge_mat.shader = shader
			surge_mat.set_shader_parameter("effect_weight", 0.0)
			surge_mat.set_shader_parameter("blur_strength", 1.4)
			surge_overlay.material = surge_mat
		canvas.add_child(surge_overlay)

		# Surge status indicator on HUD (Invincibility + Damage boost countdown)
		surge_label = Label.new()
		surge_label.name = "SurgeStatus"
		surge_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		surge_label.anchor_left = 0.5
		surge_label.anchor_right = 0.5
		surge_label.anchor_top = 1.0
		surge_label.anchor_bottom = 1.0
		surge_label.offset_left = -260.0
		surge_label.offset_right = 260.0
		surge_label.offset_top = -90.0
		surge_label.offset_bottom = -55.0
		surge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		surge_label.add_theme_font_size_override("font_size", 20)
		surge_label.modulate = Color(1.0, 0.75, 0.2, 0.0)
		surge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.add_child(surge_label)

		# Damage overlay
		damage_overlay = ColorRect.new()
		damage_overlay.name = "DamageOverlay"
		damage_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		damage_overlay.color = Color(1.0, 0.0, 0.0, 0.0)
		damage_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.add_child(damage_overlay)

func _update_health_ui() -> void:
	if health:
		if is_invincible:
			health.text = "Health: " + str(HEALTH) + " [INVINCIBLE]"
			health.modulate = Color(1.0, 0.88, 0.25)
		else:
			health.text = "Health: " + str(HEALTH)
			if health.modulate == Color(1.0, 0.88, 0.25):
				health.modulate = Color.WHITE

func take_damage(amount: int) -> void:
	if is_dead:
		return
	if is_invincible:
		_flash_invincible()
		return

	var potential_health: int = HEALTH - amount

	# Trigger low health surge if dropping below threshold and cooldown is ready
	var threshold: int = maxi(low_health_threshold, int(round(float(max_health) * 0.30)))
	if potential_health <= threshold and surge_cooldown_timer <= 0.0 and not is_surge_active:
		HEALTH = max(1, potential_health)
		_update_health_ui()
		_flash_damage()
		_trigger_low_health_surge()
		return

	HEALTH = max(0, potential_health)
	_update_health_ui()
	_flash_damage()
	if HEALTH <= 0:
		die()

func _flash_invincible() -> void:
	if health:
		health.modulate = Color(1.0, 0.92, 0.3)
		var tween = create_tween()
		tween.tween_property(health, "modulate", Color(1.0, 0.88, 0.25) if is_invincible else Color.WHITE, 0.2)

func _trigger_low_health_surge() -> void:
	is_surge_active = true
	is_invincible = true
	invincibility_timer = invincibility_duration
	surge_damage_timer = damage_boost_duration
	surge_cooldown_timer = surge_cooldown

	# Activate weapon +200% damage boost (3x damage)
	var weapon = get_node_or_null("Weapon")
	if weapon and weapon.has_method("set_damage_multiplier"):
		weapon.set_damage_multiplier(3.0)

	# Smoothly fade in vision blur & Night Light temperature filter
	if surge_mat:
		var tween = create_tween()
		tween.tween_method(func(val: float):
			if surge_mat:
				surge_mat.set_shader_parameter("effect_weight", val)
		, 0.0, 1.0, 0.25)

	# Announcement popup
	show_popup_notification("⚡ ADRENALINE SURGE!\n2s INVINCIBLE + 200% DAMAGE!", Color(1.0, 0.7, 0.1))
	_update_surge_label_ui()

func _end_low_health_surge() -> void:
	is_surge_active = false
	is_invincible = false
	invincibility_timer = 0.0
	surge_damage_timer = 0.0

	var weapon = get_node_or_null("Weapon")
	if weapon and weapon.has_method("set_damage_multiplier"):
		weapon.set_damage_multiplier(1.0)

	if surge_mat:
		surge_mat.set_shader_parameter("effect_weight", 0.0)

	if surge_label:
		surge_label.modulate.a = 0.0

	_update_health_ui()

func _update_surge_label_ui() -> void:
	if not surge_label:
		return
	var text_parts: Array[String] = []
	if is_invincible and invincibility_timer > 0.0:
		text_parts.append("🛡 INVINCIBLE: %.1fs" % invincibility_timer)
	if surge_damage_timer > 0.0:
		text_parts.append("🔥 +200% DMG: %.1fs" % surge_damage_timer)

	if text_parts.size() > 0:
		surge_label.text = " | ".join(text_parts)
		surge_label.modulate = Color(1.0, 0.75, 0.2, 1.0)
	else:
		surge_label.modulate.a = 0.0

func _flash_damage() -> void:
	if health:
		health.modulate = Color(1.0, 0.2, 0.2)
		var tween = create_tween()
		tween.tween_property(health, "modulate", Color.WHITE, 0.3)
	if damage_overlay:
		damage_overlay.color = Color(0.8, 0.0, 0.0, 0.35)
		var tween2 = create_tween()
		tween2.tween_property(damage_overlay, "color", Color(0.8, 0.0, 0.0, 0.0), 0.4)

func heal(amount: int) -> int:
	if is_dead or HEALTH >= max_health:
		return 0
	var old_health: int = HEALTH
	HEALTH = mini(max_health, HEALTH + amount)
	var gained: int = HEALTH - old_health
	_update_health_ui()
	_flash_heal()
	return gained

func _flash_heal() -> void:
	if health:
		health.modulate = Color(0.2, 1.0, 0.3)
		var tween = create_tween()
		tween.tween_property(health, "modulate", Color.WHITE, 0.4)
	if damage_overlay:
		damage_overlay.color = Color(0.0, 0.8, 0.2, 0.25)
		var tween2 = create_tween()
		tween2.tween_property(damage_overlay, "color", Color(0.0, 0.8, 0.2, 0.0), 0.4)

func add_ammo(amount: int) -> int:
	var weapon = get_node_or_null("Weapon")
	if weapon and weapon.has_method("add_ammo"):
		return weapon.add_ammo(amount)
	return 0

func upgrade_stats(multiplier: float = 1.01) -> void:
	max_health = int(round(float(max_health) * multiplier))
	HEALTH = mini(max_health, HEALTH + maxi(1, int(round(float(max_health) * 0.1))))
	walk_speed *= multiplier
	sprint_speed *= multiplier
	crouch_speed *= multiplier
	slide_speed *= multiplier
	jump_velocity *= multiplier
	slide_cooldown = maxf(0.3, slide_cooldown / multiplier)
	_update_health_ui()

	var weapon = get_node_or_null("Weapon")
	if weapon and weapon.has_method("upgrade_stats"):
		weapon.upgrade_stats(multiplier)

	show_popup_notification("+1% ALL STATS UPGRADED!", Color(0.2, 1.0, 0.4))

func show_popup_notification(text: String, color: Color = Color(1.0, 0.9, 0.2)) -> void:
	var canvas = get_node_or_null("Canvas")
	if not canvas:
		return
	var notif = Label.new()
	notif.text = text
	notif.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notif.anchors_preset = Control.PRESET_CENTER_TOP
	notif.anchor_left = 0.5
	notif.anchor_right = 0.5
	notif.offset_left = -200.0
	notif.offset_right = 200.0
	notif.offset_top = 100.0
	notif.offset_bottom = 140.0
	notif.modulate = color
	notif.add_theme_font_size_override("font_size", 22)
	canvas.add_child(notif)
	var tween = create_tween()
	tween.tween_property(notif, "position:y", notif.position.y - 25.0, 1.4)
	tween.parallel().tween_property(notif, "modulate:a", 0.0, 1.4)
	tween.tween_callback(notif.queue_free)

func die() -> void:
	if is_dead:
		return
	is_dead = true
	HEALTH = 0
	if is_surge_active:
		_end_low_health_surge()
	if surge_overlay:
		surge_overlay.visible = false
	_update_health_ui()

	if health:
		health.text = "YOU DIED\nPress 'R' or wait to restart"
		health.modulate = Color(1.0, 0.2, 0.2)

	if damage_overlay:
		damage_overlay.color = Color(0.6, 0.0, 0.0, 0.4)
		var tween = create_tween()
		tween.tween_property(damage_overlay, "color", Color(0.3, 0.0, 0.0, 0.75), 1.2)

	# Camera death effect: slight tilt and drop
	var cam_tween = create_tween()
	cam_tween.tween_property(head, "position:y", stand_head_y - 0.7, 0.5)
	cam_tween.parallel().tween_property(head, "rotation:z", deg_to_rad(25.0), 0.5)

	# Release mouse capture so user can see cursor if desired
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Auto-reload current scene after 3 seconds
	await get_tree().create_timer(3.0).timeout
	if is_dead and is_inside_tree():
		get_tree().reload_current_scene()

func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		if event is InputEventKey and event.pressed and event.keycode == KEY_R:
			get_tree().reload_current_scene()
		return

	# Toggle mouse capture with Esc so you can use a UI slider if needed
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Mouse look: yaw on CharacterBody3D, pitch on Head
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-85.0), deg_to_rad(85.0))

# Connect an HSlider's "value_changed(value)" signal to this if using a sensitivity slider
func set_mouse_sensitivity(value: float) -> void:
	mouse_sensitivity = value

func _physics_process(delta: float) -> void:
	if is_dead:
		if not is_on_floor():
			velocity += get_gravity() * delta
		else:
			velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
		move_and_slide()
		return

	_update_health_ui()

	# Update slide cooldown timer
	if slide_cooldown_timer > 0.0:
		slide_cooldown_timer = max(slide_cooldown_timer - delta, 0.0)

	# Update low health surge timers
	if surge_cooldown_timer > 0.0:
		surge_cooldown_timer = max(0.0, surge_cooldown_timer - delta)

	if is_surge_active:
		if invincibility_timer > 0.0:
			invincibility_timer = max(0.0, invincibility_timer - delta)
			if invincibility_timer <= 0.0:
				is_invincible = false

		if surge_damage_timer > 0.0:
			surge_damage_timer = max(0.0, surge_damage_timer - delta)

			# As surge nears its end (last 1.5s), fade out blur and Night Light filter smoothly
			if surge_damage_timer < 1.5 and surge_mat:
				var fade_weight: float = surge_damage_timer / 1.5
				surge_mat.set_shader_parameter("effect_weight", fade_weight)

			if surge_damage_timer <= 0.0:
				_end_low_health_surge()

		_update_surge_label_ui()
	elif surge_label and surge_label.modulate.a > 0.0:
		surge_label.modulate.a = 0.0

	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Jump (cancels slide if currently sliding)
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		if is_sliding:
			_end_slide()
		velocity.y = jump_velocity

	var input_dir := Input.get_vector("strafe_left", "strafe_right", "walk_forward", "walk_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	# Start slide ONLY on just_pressed (holding the key won't re-trigger)
	if Input.is_action_just_pressed("crouch") and Input.is_action_pressed("sprint") and not is_sliding and slide_cooldown_timer <= 0.0 and is_on_floor():
		_start_slide(direction)

	# Handle active slide
	if is_sliding:
		slide_timer -= delta
		velocity.x = slide_direction.x * slide_speed
		velocity.z = slide_direction.z * slide_speed

		if slide_timer <= 0.0 or not is_on_floor():
			_end_slide()
	else:
		# Crouch state (when not sliding)
		var wants_crouch := Input.is_action_pressed("crouch") and is_on_floor()
		if wants_crouch != is_crouching:
			is_crouching = wants_crouch
			_set_collision_state(is_crouching)

		var wants_sprint := Input.is_action_pressed("sprint") and not is_crouching and direction != Vector3.ZERO
		var current_speed := walk_speed
		if is_crouching:
			current_speed = crouch_speed
		elif wants_sprint:
			current_speed = sprint_speed

		if direction:
			velocity.x = direction.x * current_speed
			velocity.z = direction.z * current_speed
		else:
			velocity.x = move_toward(velocity.x, 0.0, current_speed)
			velocity.z = move_toward(velocity.z, 0.0, current_speed)

	# Smoothly lower/raise Head for crouch or slide
	var target_head_y := stand_head_y + (crouch_head_offset if (is_crouching or is_sliding) else 0.0)
	head.position.y = lerp(head.position.y, target_head_y, 14.0 * delta)

	move_and_slide()

func _start_slide(move_dir: Vector3) -> void:
	is_sliding = true
	is_crouching = false
	slide_timer = slide_duration
	# Slide along current movement input, or forward if standing still
	slide_direction = move_dir if move_dir != Vector3.ZERO else (-transform.basis.z).normalized()
	_set_collision_state(true) # Enable CrouchCollider, disable StandingCollision

func _end_slide() -> void:
	is_sliding = false
	slide_cooldown_timer = slide_cooldown # Disable slide for 1 second
	is_crouching = false
	_set_collision_state(false) # Restore StandingCollision, disable CrouchCollider

# true = use CrouchCollider | false = use StandingCollision
func _set_collision_state(use_crouch_collider: bool) -> void:
	crouch_collider.disabled = not use_crouch_collider
	standing_collision.disabled = use_crouch_collider
