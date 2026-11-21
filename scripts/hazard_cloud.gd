extends Area3D

@export var direct_damage: int = 20
@export var damage_per_tick: int = 5
@export var tick_interval: float = 0.5
@export var duration: float = 3.2

var _timer: float = 0.0
var _tick_timer: float = 0.0

func _ready() -> void:
	await get_tree().physics_frame
	_detonate_blast()
	# Visual fade out animation near end
	var light = get_node_or_null("OmniLight3D")
	var cloud = get_node_or_null("CloudMesh")
	if light or cloud:
		var tween = create_tween()
		tween.tween_interval(duration - 1.0)
		if light:
			tween.parallel().tween_property(light, "light_energy", 0.0, 1.0)
		if cloud:
			tween.parallel().tween_property(cloud, "scale", Vector3.ZERO, 1.0)

func _detonate_blast() -> void:
	for body in get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(direct_damage)
		elif body.is_in_group("zombies") and body.has_method("take_damage"):
			body.take_damage(direct_damage * 2)

func _process(delta: float) -> void:
	_timer += delta
	_tick_timer += delta

	if _tick_timer >= tick_interval:
		_tick_timer = 0.0
		for body in get_overlapping_bodies():
			if body.is_in_group("player") and body.has_method("take_damage"):
				body.take_damage(damage_per_tick)

	if _timer >= duration:
		queue_free()
