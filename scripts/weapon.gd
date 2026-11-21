extends Node

@export var damage: int = 10
@export var fire_cooldown: float = 0.25

@export var normal_fov: float = 75.0
@export var scoped_fov: float = 35.0
@export var zoom_speed: float = 14.0
var position = 0.0

@export var hip_pos: Vector3 = Vector3(0.28, -0.22, -0.45)
@export var ads_pos: Vector3 = Vector3(0.0, -0.14, -0.35)

@onready var camera: Camera3D = get_parent().get_node_or_null("Head/Camera")
@onready var aim_ray: RayCast3D = get_parent().get_node_or_null("Head/Camera/Aim") as RayCast3D

var is_scoping: bool = false
var _can_shoot: bool = true

func _ready() -> void:
	position = hip_pos
	if camera:
		camera.fov = normal_fov

func _unhandled_input(_event: InputEvent) -> void:
	var player = get_parent()
	if player and "is_dead" in player and player.is_dead:
		return
	if Input.is_action_pressed("shoot") and _can_shoot:
		_shoot()

func _process(delta: float) -> void:
	var player = get_parent()
	if player and "is_dead" in player and player.is_dead:
		return
	is_scoping = Input.is_action_pressed("scope")

	var target_pos: Vector3 = ads_pos if is_scoping else hip_pos
	position = position.lerp(target_pos, zoom_speed * delta)

	if camera:
		var target_fov: float = scoped_fov if is_scoping else normal_fov
		camera.fov = lerp(camera.fov, target_fov, zoom_speed * delta)

func _shoot() -> void:
	if aim_ray == null:
		return

	_can_shoot = false
	aim_ray.force_raycast_update()

	if aim_ray.is_colliding():
		var hit: Object = aim_ray.get_collider()
		if hit and hit.has_method("take_damage"):
			hit.take_damage(damage)

	await get_tree().create_timer(fire_cooldown).timeout
	_can_shoot = true
