extends Area3D

@export var ammo_amount: int = 45
@export var bob_speed: float = 3.0
@export var bob_height: float = 0.12
@export var rotate_speed: float = 1.6

var _initial_y: float = 0.0
var _time: float = 0.0
var _collected: bool = false

func _ready() -> void:
	_initial_y = position.y
	_time = randf() * TAU
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if _collected:
		return
	_time += delta * bob_speed
	position.y = _initial_y + sin(_time) * bob_height
	rotate_y(rotate_speed * delta)

func _on_body_entered(body: Node3D) -> void:
	if _collected:
		return
	if body.is_in_group("player") and body.has_method("add_ammo"):
		var added: int = body.add_ammo(ammo_amount)
		if added > 0:
			_collected = true
			if body.has_method("show_popup_notification"):
				body.show_popup_notification("+%d AMMO" % added, Color(1.0, 0.85, 0.2))
			_play_pickup_effect()

func _play_pickup_effect() -> void:
	var tween = create_tween()
	tween.tween_property(self, "scale", scale * 1.3, 0.15)
	tween.parallel().tween_property(self, "position:y", position.y + 0.3, 0.15)
	tween.tween_callback(queue_free)
