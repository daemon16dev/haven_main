extends CharacterBody3D

@onready var health = $Canvas/Health
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera # Change to $Head/Camera3D if named Camera3D
@onready var standing_collision: CollisionShape3D = $StandingCollision
@onready var crouch_collider: CollisionShape3D = $CrouchCollider

var HEALTH = 100
const WALK_SPEED = 5.0
const SPRINT_SPEED = 8.5
const CROUCH_SPEED = 2.5
const SLIDE_SPEED = 11.0
const JUMP_VELOCITY = 4.5

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

func _ready() -> void:
	stand_head_y = head.position.y
	_set_collision_state(false) # Start standing
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
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
	health.text = "Health: " + str(HEALTH)
	HEALTH = HEALTH - 1

	# Update slide cooldown timer
	if slide_cooldown_timer > 0.0:
		slide_cooldown_timer = max(slide_cooldown_timer - delta, 0.0)

	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Jump (cancels slide if currently sliding)
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		if is_sliding:
			_end_slide()
		velocity.y = JUMP_VELOCITY

	var input_dir := Input.get_vector("strafe_left", "strafe_right", "walk_forward", "walk_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	# Start slide ONLY on just_pressed (holding the key won't re-trigger)
	if Input.is_action_just_pressed("crouch") and Input.is_action_pressed("sprint") and not is_sliding and slide_cooldown_timer <= 0.0 and is_on_floor():
		_start_slide(direction)

	# Handle active slide
	if is_sliding:
		slide_timer -= delta
		velocity.x = slide_direction.x * SLIDE_SPEED
		velocity.z = slide_direction.z * SLIDE_SPEED

		if slide_timer <= 0.0 or not is_on_floor():
			_end_slide()
	else:
		# Crouch state (when not sliding)
		var wants_crouch := Input.is_action_pressed("crouch") and is_on_floor()
		if wants_crouch != is_crouching:
			is_crouching = wants_crouch
			_set_collision_state(is_crouching)

		var wants_sprint := Input.is_action_pressed("sprint") and not is_crouching and direction != Vector3.ZERO
		var current_speed := WALK_SPEED
		if is_crouching:
			current_speed = CROUCH_SPEED
		elif wants_sprint:
			current_speed = SPRINT_SPEED

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
