extends Node3D

@export var max_active_zombies: int = 24
@export var spawn_interval: float = 1.0

var tank_scene = preload("res://scenes/zombie_tank.tscn")
var clingy_scene = preload("res://scenes/zombie_clingy.tscn")
var hazardous_scene = preload("res://scenes/zombie_hazardous.tscn")
var super_tank_scene = preload("res://scenes/zombie_super_tank.tscn")

var ammo_crate_scene = preload("res://scenes/ammo_crate.tscn")
var medkit_scene = preload("res://scenes/medkit.tscn")

var current_wave: int = 1
var total_zombies_in_wave: int = 101
var zombies_remaining: int = 101
var zombies_alive: int = 0
var spawn_queue: Array[int] = []
var _spawn_timer: float = 0.0
var _wave_cleared: bool = false
var _active_super_tank: Node3D = null

# UI Elements
var ui_layer: CanvasLayer = null
var wave_label: Label = null
var count_label: Label = null
var banner_label: Label = null
var boss_container: VBoxContainer = null
var boss_bar: ProgressBar = null
var boss_name_label: Label = null

# Spawn locations spread around the 100x100 arena
var spawn_points: Array[Vector3] = [
	Vector3(-40, 0.2, -40),
	Vector3(0, 0.2, -42),
	Vector3(40, 0.2, -40),
	Vector3(-42, 0.2, 0),
	Vector3(42, 0.2, 0),
	Vector3(-40, 0.2, 40),
	Vector3(0, 0.2, 42),
	Vector3(40, 0.2, 40),
	Vector3(-28, 0.2, -30),
	Vector3(28, 0.2, -30),
	Vector3(-28, 0.2, 30),
	Vector3(28, 0.2, 30)
]

func _ready() -> void:
	_setup_ui()
	# Give the navigation server and player a moment to initialize
	await get_tree().create_timer(1.0).timeout
	start_wave(current_wave)

func _setup_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.name = "WaveUI"
	add_child(ui_layer)

	# Top container for wave & count
	var top_panel = VBoxContainer.new()
	top_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top_panel.offset_left = -200.0
	top_panel.offset_right = 200.0
	top_panel.offset_top = 16.0
	top_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(top_panel)

	wave_label = Label.new()
	wave_label.text = "WAVE 1"
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_label.add_theme_font_size_override("font_size", 28)
	wave_label.modulate = Color(1.0, 0.85, 0.2)
	top_panel.add_child(wave_label)

	count_label = Label.new()
	count_label.text = "Zombies Left: 101 / 101"
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.add_theme_font_size_override("font_size", 18)
	count_label.modulate = Color(0.9, 0.9, 0.9)
	top_panel.add_child(count_label)

	# Super Tank Boss bar container
	boss_container = VBoxContainer.new()
	boss_container.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boss_container.offset_left = -250.0
	boss_container.offset_right = 250.0
	boss_container.offset_top = 80.0
	boss_container.visible = false
	boss_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(boss_container)

	boss_name_label = Label.new()
	boss_name_label.text = "☠ SUPER TANK ☠"
	boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_name_label.add_theme_font_size_override("font_size", 20)
	boss_name_label.modulate = Color(1.0, 0.2, 0.2)
	boss_container.add_child(boss_name_label)

	boss_bar = ProgressBar.new()
	boss_bar.custom_minimum_size = Vector2(500, 18)
	boss_bar.max_value = 750
	boss_bar.value = 750
	boss_bar.show_percentage = false
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.85, 0.1, 0.1, 0.9)
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	boss_bar.add_theme_stylebox_override("fill", sb)
	boss_container.add_child(boss_bar)

	# Center banner for wave start / wave clear
	banner_label = Label.new()
	banner_label.set_anchors_preset(Control.PRESET_CENTER)
	banner_label.offset_left = -400.0
	banner_label.offset_right = 400.0
	banner_label.offset_top = -120.0
	banner_label.offset_bottom = -20.0
	banner_label.pivot_offset = Vector2(400.0, 50.0)
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner_label.add_theme_font_size_override("font_size", 36)
	banner_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	banner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(banner_label)

func start_wave(wave_num: int) -> void:
	current_wave = wave_num
	_wave_cleared = false
	total_zombies_in_wave = 101 # 100 regular zombies + 1 Super Tank
	zombies_remaining = total_zombies_in_wave
	zombies_alive = 0
	_active_super_tank = null
	if boss_container:
		boss_container.visible = false

	# Build wave composition:
	# 100 Zombies: 25% Hazardous (25), 30% Clingy (30), Rest Tanks (45)
	# 10% random (10 zombies replaced with random type)
	# + 1 Super Tank
	spawn_queue = _generate_wave_queue()

	_update_hud()
	show_banner("WAVE %d START" % current_wave, Color(1.0, 0.85, 0.2))

func _generate_wave_queue() -> Array[int]:
	var queue: Array[int] = []

	# 25 Hazardous
	for i in range(25):
		queue.append(2) # HAZARDOUS

	# 30 Clingy
	for i in range(30):
		queue.append(1) # CLINGY

	# 45 Tanks (100 - 25 - 30)
	for i in range(45):
		queue.append(0) # TANK

	# 10% random: pick 10 random indices and assign a random type
	var indices: Array[int] = []
	for i in range(100):
		indices.append(i)
	indices.shuffle()

	for i in range(10):
		var idx = indices[i]
		var rand_type = randi() % 3 # 0, 1, or 2
		queue[idx] = rand_type

	# Shuffle regular zombies
	queue.shuffle()

	# Add 1 Super Tank (insert around halfway through the wave for maximum drama)
	var super_tank_idx = mini(50, queue.size())
	queue.insert(super_tank_idx, 3) # SUPER_TANK

	return queue

func _process(delta: float) -> void:
	if _wave_cleared:
		return

	# Update Boss Bar if Super Tank is alive
	if _active_super_tank and is_instance_valid(_active_super_tank):
		if boss_container:
			boss_container.visible = true
		if boss_bar and "hp" in _active_super_tank:
			boss_bar.value = _active_super_tank.hp
	elif boss_container and boss_container.visible:
		boss_container.visible = false

	_spawn_timer += delta
	if _spawn_timer >= spawn_interval:
		_spawn_timer = 0.0
		_try_spawn_zombie()

func _try_spawn_zombie() -> void:
	if zombies_alive >= max_active_zombies:
		return
	if spawn_queue.is_empty():
		return

	var z_type = spawn_queue.pop_front()
	var spawn_pos = _get_best_spawn_position()

	var zombie: Node3D = null
	match z_type:
		0: # TANK
			zombie = tank_scene.instantiate()
		1: # CLINGY
			zombie = clingy_scene.instantiate()
		2: # HAZARDOUS
			zombie = hazardous_scene.instantiate()
		3: # SUPER_TANK
			zombie = super_tank_scene.instantiate()
			_active_super_tank = zombie
			if boss_bar and "max_hp" in zombie:
				boss_bar.max_value = zombie.max_hp
				boss_bar.value = zombie.max_hp
			if boss_container:
				boss_container.visible = true
			show_banner("⚠ WARNING: SUPER TANK SPAWNED! ⚠", Color(1.0, 0.2, 0.2))

	if zombie:
		zombie.position = spawn_pos
		get_parent().add_child(zombie)
		zombies_alive += 1
		if zombie.has_signal("died"):
			zombie.died.connect(_on_zombie_died)

func _get_best_spawn_position() -> Vector3:
	var player = get_tree().get_first_node_in_group("player") as Node3D
	var player_pos = player.global_position if player else Vector3.ZERO

	# Choose spawn points at least 16 units away from player
	var valid_points: Array[Vector3] = []
	for p in spawn_points:
		if p.distance_to(player_pos) > 16.0:
			valid_points.append(p)

	var base_pos = valid_points.pick_random() if valid_points.size() > 0 else spawn_points.pick_random()
	# Add slight jitter so zombies don't stack exactly on top of each other
	var jitter = Vector3(randf_range(-3.0, 3.0), 0.0, randf_range(-3.0, 3.0))
	return base_pos + jitter

func _on_zombie_died(zombie: Node3D) -> void:
	zombies_alive = maxi(0, zombies_alive - 1)
	zombies_remaining = maxi(0, zombies_remaining - 1)

	if zombie == _active_super_tank:
		_active_super_tank = null
		if boss_container:
			boss_container.visible = false
		show_banner("SUPER TANK ELIMINATED!", Color(1.0, 0.8, 0.2))

	_update_hud()

	if zombies_remaining <= 0 and not _wave_cleared:
		_on_wave_cleared()

func _update_hud() -> void:
	if wave_label:
		wave_label.text = "WAVE %d" % current_wave
	if count_label:
		count_label.text = "Zombies Left: %d / %d" % [zombies_remaining, total_zombies_in_wave]

func _on_wave_cleared() -> void:
	_wave_cleared = true
	show_banner("WAVE %d CLEARED!\nALL PLAYER STATS IMPROVED BY 1%%!" % current_wave, Color(0.2, 1.0, 0.4), 3.5)

	# Improve every stat of every player by 1%
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if p.has_method("upgrade_stats"):
			p.upgrade_stats(1.01)

	# Spawn celebratory supplies in arena
	_spawn_wave_cleared_supplies()

	# Wait before starting next wave
	await get_tree().create_timer(4.5).timeout
	start_wave(current_wave + 1)

func _spawn_wave_cleared_supplies() -> void:
	var supply_offsets = [
		Vector3(-4, 0.3, -4),
		Vector3(4, 0.3, -4),
		Vector3(-4, 0.3, 4),
		Vector3(4, 0.3, 4)
	]
	var player = get_tree().get_first_node_in_group("player") as Node3D
	var center = player.global_position if player else Vector3.ZERO
	center.y = 0.2

	var ammo1 = ammo_crate_scene.instantiate()
	ammo1.global_position = center + supply_offsets[0]
	get_parent().add_child(ammo1)

	var med1 = medkit_scene.instantiate()
	med1.global_position = center + supply_offsets[1]
	get_parent().add_child(med1)

	var ammo2 = ammo_crate_scene.instantiate()
	ammo2.global_position = center + supply_offsets[2]
	get_parent().add_child(ammo2)

	var med2 = medkit_scene.instantiate()
	med2.global_position = center + supply_offsets[3]
	get_parent().add_child(med2)

func show_banner(text: String, color: Color = Color.WHITE, stay_duration: float = 2.0) -> void:
	if not banner_label:
		return
	banner_label.text = text
	banner_label.modulate = Color(color.r, color.g, color.b, 0.0)
	banner_label.scale = Vector2(0.8, 0.8)

	var tween = create_tween()
	tween.tween_property(banner_label, "modulate:a", 1.0, 0.3)
	tween.parallel().tween_property(banner_label, "scale", Vector2.ONE, 0.3)
	tween.tween_interval(stay_duration)
	tween.tween_property(banner_label, "modulate:a", 0.0, 0.5)
