extends CharacterBody3D

@export var speed: float = 1.0
@export var hearing_radius: float = 15.0
@export var turn_speed: float = 10.0

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

var player: Node3D = null
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _map_ready: bool = false
@export var max_hp: int = 100
var hp: int = 100

func _ready() -> void:
	hp = max_hp
	player = get_tree().get_first_node_in_group("player") as Node3D
	# Wait one physics frame so NavigationServer3D finishes registering the baked mesh
	await get_tree().physics_frame
	_map_ready = true

func take_damage(amount: int) -> void:
	hp -= amount
	if hp <= 0:
		queue_free()

func _physics_process(delta: float) -> void:
	# Always apply gravity so the zombie stays grounded on floors and slopes
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	if not player or not _map_ready:
		move_and_slide()
		return

	# Blind behavior: only update the target if the player is within hearing range
	# (Remove the distance check if you want continuous global tracking)
	if global_position.distance_to(player.global_position) <= hearing_radius:
		nav_agent.target_position = player.global_position

	if nav_agent.is_navigation_finished():
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	# Must be called every physics frame to advance waypoints
	var next_pos: Vector3 = nav_agent.get_next_path_position()
	var to_next: Vector3 = next_pos - global_position
	to_next.y = 0.0

	if to_next.length_squared() > 0.001:
		var dir: Vector3 = to_next.normalized()
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed

		var target_yaw: float = atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, turn_speed * delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	move_and_slide()
