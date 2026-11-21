extends Node

@export var damage: int = 10
@export var fire_cooldown: float = 0.25

# Ammo configuration
@export var max_ammo: int = 30
@export var current_ammo: int = 30
@export var reserve_ammo: int = 90
@export var max_reserve_ammo: int = 150
@export var reload_time: float = 1.8

var _base_damage: float = 10.0
var _damage_multiplier: float = 1.0

@export var normal_fov: float = 75.0
@export var scoped_fov: float = 35.0
@export var zoom_speed: float = 14.0
var position = 0.0

@export var hip_pos: Vector3 = Vector3(0.28, -0.22, -0.45)
@export var ads_pos: Vector3 = Vector3(0.0, -0.14, -0.35)

@onready var camera: Camera3D = get_parent().get_node_or_null("Head/Camera")
@onready var aim_ray: RayCast3D = get_parent().get_node_or_null("Head/Camera/Aim") as RayCast3D
@onready var gun_mesh: Node3D = get_parent().get_node_or_null("Sketchfab_Scene") as Node3D

var ammo_label: Label = null
var hitmarker_label: Label = null
var crosshair_label: Label = null
var is_scoping: bool = false
var _can_shoot: bool = true
var is_reloading: bool = false
var _orig_gun_pos: Vector3 = Vector3.ZERO
var _orig_gun_rot: Vector3 = Vector3.ZERO

func _ready() -> void:
	_base_damage = float(damage)
	position = hip_pos
	if camera:
		camera.fov = normal_fov
	if gun_mesh:
		_orig_gun_pos = gun_mesh.position
		_orig_gun_rot = gun_mesh.rotation

	crosshair_label = get_parent().get_node_or_null("Canvas/CrossHair") as Label
	_init_ammo_ui()
	_init_hitmarker()
	_update_ammo_ui()

func _init_hitmarker() -> void:
	hitmarker_label = get_parent().get_node_or_null("Canvas/Hitmarker") as Label
	if not hitmarker_label:
		var canvas = get_parent().get_node_or_null("Canvas")
		if canvas:
			hitmarker_label = Label.new()
			hitmarker_label.name = "Hitmarker"
			hitmarker_label.set_anchors_preset(Control.PRESET_CENTER)
			hitmarker_label.anchor_left = 0.5
			hitmarker_label.anchor_top = 0.5
			hitmarker_label.anchor_right = 0.5
			hitmarker_label.anchor_bottom = 0.5
			hitmarker_label.offset_left = -20.0
			hitmarker_label.offset_top = -20.0
			hitmarker_label.offset_right = 20.0
			hitmarker_label.offset_bottom = 20.0
			hitmarker_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
			hitmarker_label.grow_vertical = Control.GROW_DIRECTION_BOTH
			hitmarker_label.text = "✕"
			hitmarker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			hitmarker_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			hitmarker_label.add_theme_font_size_override("font_size", 24)
			hitmarker_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
			hitmarker_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			canvas.add_child(hitmarker_label)

func _trigger_hitmarker(was_fatal: bool) -> void:
	if not hitmarker_label:
		_init_hitmarker()
	if not hitmarker_label:
		return

	var target_col: Color = Color(1.0, 0.2, 0.2, 1.0) if was_fatal else Color(1.0, 1.0, 1.0, 0.95)
	var end_time: float = 0.16 if was_fatal else 0.10
	var fsize: int = 28 if was_fatal else 22
	hitmarker_label.add_theme_font_size_override("font_size", fsize)
	hitmarker_label.modulate = target_col
	var tween = create_tween()
	tween.tween_property(hitmarker_label, "modulate:a", 0.0, end_time)

func _init_ammo_ui() -> void:
	ammo_label = get_parent().get_node_or_null("Canvas/Ammo")
	if ammo_label == null:
		var canvas = get_parent().get_node_or_null("Canvas")
		if canvas:
			ammo_label = Label.new()
			ammo_label.name = "Ammo"
			ammo_label.anchors_preset = Control.PRESET_BOTTOM_RIGHT
			ammo_label.anchor_left = 1.0
			ammo_label.anchor_top = 1.0
			ammo_label.anchor_right = 1.0
			ammo_label.anchor_bottom = 1.0
			ammo_label.offset_left = -240.0
			ammo_label.offset_top = -35.0
			ammo_label.offset_right = -20.0
			ammo_label.offset_bottom = -12.0
			ammo_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			ammo_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
			ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			canvas.add_child(ammo_label)

func _update_ammo_ui() -> void:
	if ammo_label == null:
		_init_ammo_ui()
	if ammo_label:
		if is_reloading:
			ammo_label.text = "RELOADING... [%d / %d]" % [current_ammo, reserve_ammo]
			ammo_label.modulate = Color(1.0, 0.85, 0.3)
		elif current_ammo == 0 and reserve_ammo == 0:
			ammo_label.text = "EMPTY! [0 / 0]"
			ammo_label.modulate = Color(1.0, 0.2, 0.2)
		elif current_ammo == 0:
			ammo_label.text = "PRESS R TO RELOAD! [0 / %d]" % [reserve_ammo]
			ammo_label.modulate = Color(1.0, 0.25, 0.25)
		elif current_ammo <= 5:
			var buff_str = " 🔥 [+200% DMG]" if _damage_multiplier > 1.0 else ""
			ammo_label.text = "LOW AMMO: %d / %d%s" % [current_ammo, reserve_ammo, buff_str]
			ammo_label.modulate = Color(1.0, 0.6, 0.2)
		else:
			var buff_str = " 🔥 [+200% DMG]" if _damage_multiplier > 1.0 else ""
			ammo_label.text = "Ammo: %d / %d%s" % [current_ammo, reserve_ammo, buff_str]
			ammo_label.modulate = Color(1.0, 0.75, 0.2) if _damage_multiplier > 1.0 else Color.WHITE

func _unhandled_input(event: InputEvent) -> void:
	var player = get_parent()
	if player and "is_dead" in player and player.is_dead:
		return

	if event.is_action_pressed("reload") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R):
		reload()
		return

	if Input.is_action_pressed("shoot") and _can_shoot and not is_reloading:
		_shoot()

func _process(delta: float) -> void:
	var player = get_parent()
	if player and "is_dead" in player and player.is_dead:
		return

	if Input.is_action_just_pressed("reload"):
		reload()

	if Input.is_action_pressed("shoot") and _can_shoot and not is_reloading:
		_shoot()

	# Don't scope while reloading
	if is_reloading:
		is_scoping = false
	else:
		is_scoping = Input.is_action_pressed("scope")

	var target_pos: Vector3 = ads_pos if is_scoping else hip_pos
	position = position.lerp(target_pos, zoom_speed * delta)

	if camera:
		var target_fov: float = scoped_fov if is_scoping else normal_fov
		camera.fov = lerp(camera.fov, target_fov, zoom_speed * delta)

func _shoot() -> void:
	if aim_ray == null or is_reloading:
		return

	if current_ammo <= 0:
		if reserve_ammo > 0:
			reload()
		return

	_can_shoot = false
	current_ammo -= 1
	_update_ammo_ui()

	aim_ray.force_raycast_update()

	if aim_ray.is_colliding():
		var hit: Object = aim_ray.get_collider()
		if hit and hit.has_method("take_damage"):
			var was_fatal: bool = bool(hit.take_damage(damage))
			_trigger_hitmarker(was_fatal)

	# Crosshair recoil expansion
	if crosshair_label:
		crosshair_label.scale = Vector2(1.3, 1.3)
		var ch_tween = create_tween()
		ch_tween.tween_property(crosshair_label, "scale", Vector2.ONE, 0.08)

	# Slight gun recoil feedback
	if gun_mesh and not is_reloading:
		var tween = create_tween()
		tween.tween_property(gun_mesh, "position:z", _orig_gun_pos.z + 0.04, 0.04)
		tween.tween_property(gun_mesh, "position:z", _orig_gun_pos.z, 0.08)

	await get_tree().create_timer(fire_cooldown).timeout
	_can_shoot = true

func reload() -> void:
	if is_reloading:
		return
	if current_ammo >= max_ammo:
		return
	if reserve_ammo <= 0:
		return

	is_reloading = true
	_update_ammo_ui()

	# Visual reload animation (lower gun, tilt, and bring back up)
	if gun_mesh:
		var anim = create_tween()
		anim.tween_property(gun_mesh, "position:y", _orig_gun_pos.y - 0.2, reload_time * 0.4)
		anim.parallel().tween_property(gun_mesh, "rotation:x", _orig_gun_rot.x - deg_to_rad(20.0), reload_time * 0.4)
		anim.tween_property(gun_mesh, "position:y", _orig_gun_pos.y, reload_time * 0.6)
		anim.parallel().tween_property(gun_mesh, "rotation:x", _orig_gun_rot.x, reload_time * 0.6)

	await get_tree().create_timer(reload_time).timeout

	var player = get_parent()
	if player and "is_dead" in player and player.is_dead:
		is_reloading = false
		return

	if not is_inside_tree() or not is_reloading:
		return

	var needed: int = max_ammo - current_ammo
	var to_transfer: int = min(needed, reserve_ammo)
	current_ammo += to_transfer
	reserve_ammo -= to_transfer

	is_reloading = false
	if gun_mesh:
		gun_mesh.position = _orig_gun_pos
		gun_mesh.rotation = _orig_gun_rot

	_update_ammo_ui()

func add_ammo(amount: int) -> int:
	var space: int = max_reserve_ammo - reserve_ammo
	if space <= 0:
		return 0
	var added: int = clampi(amount, 1, space)
	reserve_ammo += added
	_update_ammo_ui()
	return added

func upgrade_stats(multiplier: float = 1.01) -> void:
	_base_damage *= multiplier
	damage = int(round(_base_damage * _damage_multiplier))
	max_ammo = int(round(float(max_ammo) * multiplier))
	max_reserve_ammo = int(round(float(max_reserve_ammo) * multiplier))
	fire_cooldown = maxf(0.05, fire_cooldown / multiplier)
	reload_time = maxf(0.4, reload_time / multiplier)
	zoom_speed *= multiplier
	_update_ammo_ui()

func set_damage_multiplier(mult: float) -> void:
	_damage_multiplier = mult
	damage = int(round(_base_damage * _damage_multiplier))
	_update_ammo_ui()
