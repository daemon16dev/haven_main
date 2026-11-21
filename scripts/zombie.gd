extends CharacterBody3D

signal died(zombie)

enum ZombieType {
	TANK,
	CLINGY,
	HAZARDOUS,
	SUPER_TANK
}

@export var zombie_type: ZombieType = ZombieType.TANK
@export var speed: float = 1.8
@export var hearing_radius: float = 120.0
@export var turn_speed: float = 10.0
@export var max_hp: int = 100
@export var attack_damage: int = 20
@export var attack_range: float = 2.2
@export var attack_cooldown: float = 1.0
@export var is_hazardous: bool = false
@export var is_super_tank: bool = false
@export var custom_scale: float = 1.0
@export var ammo_drop_chance: float = 0.20
@export var medkit_drop_chance: float = 0.12

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

const AMMO_CRATE_SCENE = preload("res://scenes/ammo_crate.tscn")
const MEDKIT_SCENE = preload("res://scenes/medkit.tscn")
const HAZARD_CLOUD_SCENE = preload("res://scenes/hazard_cloud.tscn")

var player: Node3D = null
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _map_ready: bool = false
var hp: int = 100
var _attack_timer: float = 0.0
var _is_dead: bool = false

func _ready() -> void:
	add_to_group("zombies")
	if custom_scale != 1.0:
		scale = Vector3(custom_scale, custom_scale, custom_scale)
	hp = max_hp
	player = get_tree().get_first_node_in_group("player") as Node3D
	# Wait one physics frame so NavigationServer3D finishes registering the baked mesh
	await get_tree().physics_frame
	_map_ready = true

func take_damage(amount: int) -> void:
	if _is_dead:
		return

	hp -= amount
	if hp <= 0:
		_die()
		return

	_flash_hit()

func _die() -> void:
	if _is_dead:
		return
	_is_dead = true
	died.emit(self)

	if is_hazardous:
		_trigger_hazard_explosion()

	_spawn_drops()
	queue_free()

func _flash_hit() -> void:
	var tree = get_tree()
	if not tree:
		return
	if has_node("Mesh") and $Mesh.has_method("set_red_tint"):
		$Mesh.set_red_tint(true)
		await tree.create_timer(0.18).timeout
		if is_inside_tree() and has_node("Mesh") and $Mesh.has_method("set_red_tint"):
			$Mesh.set_red_tint(false)
	else:
		var csg_nodes = find_children("*", "CSGBox3D")
		for csg in csg_nodes:
			if csg is CSGBox3D and csg.material:
				var orig_mat: Material = csg.material
				var flash_mat = StandardMaterial3D.new()
				flash_mat.albedo_color = Color(1.0, 0.2, 0.2)
				flash_mat.emission_enabled = true
				flash_mat.emission = Color(1.0, 0.1, 0.1)
				csg.material = flash_mat
				tree.create_timer(0.18).timeout.connect(func():
					if is_inside_tree() and is_instance_valid(csg):
						csg.material = orig_mat
				)

func _trigger_hazard_explosion() -> void:
	var p = get_parent()
	if p and HAZARD_CLOUD_SCENE:
		var cloud = HAZARD_CLOUD_SCENE.instantiate()
		cloud.global_position = global_position
		p.add_child(cloud)

func _spawn_drops() -> void:
	var parent_node = get_parent()
	if not parent_node:
		return

	if is_super_tank:
		# Super Tank guaranteed drops
		_drop_item(parent_node, AMMO_CRATE_SCENE, Vector3(-0.7, 0.4, 0))
		_drop_item(parent_node, MEDKIT_SCENE, Vector3(0.7, 0.4, 0))
		return

	var roll = randf()
	if roll < ammo_drop_chance:
		_drop_item(parent_node, AMMO_CRATE_SCENE, Vector3(0, 0.3, 0))
	elif roll < (ammo_drop_chance + medkit_drop_chance):
		_drop_item(parent_node, MEDKIT_SCENE, Vector3(0, 0.3, 0))

func _drop_item(parent_node: Node, scene: PackedScene, offset: Vector3) -> void:
	if not scene:
		return
	var item = scene.instantiate()
	item.global_position = global_position + offset
	parent_node.add_child(item)

func _physics_process(delta: float) -> void:
	if _is_dead:
		return

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

	# Update target position if player is within hearing radius
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
