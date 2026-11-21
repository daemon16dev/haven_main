extends CharacterBody3D

@export var speed: float = 1.8
@export var hearing_radius: float = 15.0
@export var turn_speed: float = 10.0
@export var max_hp: int = 100
@export var attack_damage: int = 20
@export var attack_range: float = 2.2
@export var attack_cooldown: float = 1.0

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

var player: Node3D = null
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _map_ready: bool = false
var hp: int = 100
var _attack_timer: float = 0.0

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
		return
		
	if has_node("Mesh"):
		$Mesh.set_red_tint(true)
		await get_tree().create_timer(0.2).timeout
		if is_inside_tree() and has_node("Mesh"):
			$Mesh.set_red_tint(false)

func _physics_process(delta: float) -> void:
	if _attack_timer > 0.0:
		_attack_timer = max(0.0, _attack_timer - delta)

	# Always apply gravity so the zombie stays grounded on floors and slopes
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	if not player or not _map_ready:
		move_and_slide()
		return

	# Stop attacking and chasing if player is dead
	if "is_dead" in player and player.is_dead:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	var to_player: Vector3 = player.global_position - global_position
	var horizontal_dist: float = Vector2(to_player.x, to_player.z).length()
	var vertical_dist: float = absf(to_player.y)

	# Attack player if in melee range
	if horizontal_dist <= attack_range and vertical_dist <= 2.5:
		velocity.x = 0.0
		velocity.z = 0.0
		# Rotate towards player
		var target_yaw: float = atan2(-to_player.x, -to_player.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, turn_speed * delta)

		if _attack_timer <= 0.0:
			_attack_timer = attack_cooldown
			_attack_player()

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

func _attack_player() -> void:
	if player and player.has_method("take_damage"):
		player.take_damage(attack_damage)
