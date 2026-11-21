extends Control
class_name SettingsMenu

signal mobile_controls_toggled(enabled: bool)
signal sensitivity_changed(val: float)
signal render_scale_changed(val: float)
signal closed()

const SETTINGS_PATH = "user://settings.cfg"

@onready var mobile_toggle: CheckButton = $CenterContainer/Panel/MarginContainer/VBoxContainer/RowMobile/MobileToggle
@onready var sens_slider: HSlider = $CenterContainer/Panel/MarginContainer/VBoxContainer/SensSlider
@onready var sens_label: Label = $CenterContainer/Panel/MarginContainer/VBoxContainer/RowSensitivity/SensValue
@onready var vol_slider: HSlider = get_node_or_null("CenterContainer/Panel/MarginContainer/VBoxContainer/VolSlider") as HSlider
@onready var vol_label: Label = get_node_or_null("CenterContainer/Panel/MarginContainer/VBoxContainer/RowVolume/VolValue") as Label
@onready var scale_options: OptionButton = $CenterContainer/Panel/MarginContainer/VBoxContainer/RowScale/ScaleOptions
@onready var btn_resume: Button = $CenterContainer/Panel/MarginContainer/VBoxContainer/BtnResume

func _ready() -> void:
	visible = false
	if mobile_toggle:
		mobile_toggle.toggled.connect(_on_mobile_toggled)
	if sens_slider:
		sens_slider.value_changed.connect(_on_sensitivity_changed)
	if vol_slider:
		vol_slider.value_changed.connect(_on_volume_changed)
	if scale_options:
		scale_options.item_selected.connect(_on_scale_selected)
	if btn_resume:
		btn_resume.pressed.connect(close_menu)

	# Load volume setting
	var saved_vol: float = float(load_setting("master_volume", 0.8))
	if vol_slider:
		vol_slider.set_value_no_signal(saved_vol)
	if vol_label:
		vol_label.text = "%d%%" % int(round(saved_vol * 100.0))
	_apply_master_volume(saved_vol)

func initialize_settings(is_mobile_on: bool, current_sens: float, current_scale: float) -> void:
	if mobile_toggle:
		mobile_toggle.set_pressed_no_signal(is_mobile_on)
		mobile_toggle.text = "ON" if is_mobile_on else "OFF"
	if sens_slider:
		sens_slider.set_value_no_signal(current_sens)
	if sens_label:
		sens_label.text = "%.1fx" % (current_sens / 0.003)
	if scale_options:
		if is_equal_approx(current_scale, 0.70):
			scale_options.selected = 2
		elif is_equal_approx(current_scale, 0.85):
			scale_options.selected = 1
		else:
			scale_options.selected = 0

func _on_mobile_toggled(toggled_on: bool) -> void:
	if mobile_toggle:
		mobile_toggle.text = "ON" if toggled_on else "OFF"
	save_setting("mobile_controls", toggled_on)
	mobile_controls_toggled.emit(toggled_on)

func _on_sensitivity_changed(val: float) -> void:
	if sens_label:
		sens_label.text = "%.1fx" % (val / 0.003)
	save_setting("look_sensitivity", val)
	sensitivity_changed.emit(val)

func _on_volume_changed(val: float) -> void:
	if vol_label:
		vol_label.text = "%d%%" % int(round(val * 100.0))
	save_setting("master_volume", val)
	_apply_master_volume(val)

func _apply_master_volume(val: float) -> void:
	var bus_idx = AudioServer.get_bus_index("Master")
	if bus_idx != -1:
		if val <= 0.01:
			AudioServer.set_bus_mute(bus_idx, true)
		else:
			AudioServer.set_bus_mute(bus_idx, false)
			AudioServer.set_bus_volume_db(bus_idx, linear_to_db(val))

func _on_scale_selected(index: int) -> void:
	var scale_val: float = 1.0
	match index:
		0: scale_val = 1.0
		1: scale_val = 0.85
		2: scale_val = 0.70
	save_setting("render_scale", scale_val)
	render_scale_changed.emit(scale_val)

func open_menu() -> void:
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close_menu() -> void:
	visible = false
	get_tree().paused = false
	closed.emit()

static func save_setting(key: String, value: Variant) -> void:
	var cfg = ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("settings", key, value)
	cfg.save(SETTINGS_PATH)

static func load_setting(key: String, default_val: Variant) -> Variant:
	var cfg = ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		return cfg.get_value("settings", key, default_val)
	return default_val
