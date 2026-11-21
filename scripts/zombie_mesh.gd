extends MeshInstance3D

@export var red_tint_strength: float = 0.7 # 0.0 = normal, 1.0 = full red
@export var tint_speed: float = 12.0

var _mat: StandardMaterial3D
var _base_albedo: Color
var _is_tinted: bool = false

func _ready() -> void:
	# Duplicate the active material so changing this mesh won't affect other zombies/meshes
	var source_mat := get_active_material(0) as StandardMaterial3D
	if source_mat:
		_mat = source_mat.duplicate() as StandardMaterial3D
		material_override = _mat
		_base_albedo = _mat.albedo_color

func _process(delta: float) -> void:
	if _mat == null:
		return

	var target_color: Color = _base_albedo
	if _is_tinted:
		# Blend slightly toward red without crushing shading details to pure flat red
		target_color = _base_albedo.lerp(Color(1.0, 0.25, 0.25, _base_albedo.a), red_tint_strength)

	_mat.albedo_color = _mat.albedo_color.lerp(target_color, tint_speed * delta)

func set_red_tint(enabled: bool) -> void:
	_is_tinted = enabled
