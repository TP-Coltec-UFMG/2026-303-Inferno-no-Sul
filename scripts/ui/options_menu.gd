extends Control

signal menu_closed

# ─── Referências de UI ───────────────────────────────────────────────────────

@onready var tab_container: TabContainer = %TabContainer
@onready var btn_apply: Button = %BtnApply
@onready var btn_back:  Button = %BtnBack
@onready var btn_close: Button = %BtnClose

@onready var slider_master: HSlider = %SliderMaster
@onready var slider_music:  HSlider = %SliderMusic
@onready var slider_sfx:    HSlider = %SliderSfx

@onready var check_fullscreen:  CheckButton  = %BtnFullscreen
@onready var option_resolution: OptionButton = %BtnResolution

@onready var slider_mouse_sensitivity: HSlider = %SliderMouseSensitivity
@onready var container_bindings: VBoxContainer = %ContainerBindings

@onready var slider_font_size: HSlider = %SliderFontSize

# ─── Dados ───────────────────────────────────────────────────────────────────

const RESOLUTIONS := [
	Vector2i(1280,  720),
	Vector2i(1600,  900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]

const REMAPPABLE_ACTIONS := [
	"move_left", "move_right", "move_up", "move_down",
	"jump", "attack", "interact", "pause",
	"correr", "agachar",
]


# ════════════════════════════════════════════════════════════════════════════
#  CICLO DE VIDA
# ════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_populate_resolutions()
	_load_settings()
	_build_rebind_list()
	_connect_signals()
	set_process_unhandled_input(true)

	position.y = get_viewport_rect().size.y
	var tween := create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", 0.0, 0.5)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()


# ════════════════════════════════════════════════════════════════════════════
#  POPULAÇÃO DE WIDGETS
# ════════════════════════════════════════════════════════════════════════════

func _populate_resolutions() -> void:
	option_resolution.clear()
	for res in RESOLUTIONS:
		option_resolution.add_item("%d × %d" % [res.x, res.y])


func _build_rebind_list() -> void:
	for child in container_bindings.get_children():
		child.queue_free()

	for action in REMAPPABLE_ACTIONS:
		var row := HBoxContainer.new()

		var label := Label.new()
		label.text = action.replace("_", " ").capitalize()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)

		var btn := Button.new()
		btn.text = _get_action_key_label(action)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_start_rebind.bind(action, btn))
		row.add_child(btn)

		container_bindings.add_child(row)


func _get_action_key_label(action: String) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return OS.get_keycode_string(event.physical_keycode)
		if event is InputEventJoypadButton:
			return "Btn %d" % event.button_index
		if event is InputEventMouseButton:
			return "Mouse %d" % event.button_index
	return "---"


# ════════════════════════════════════════════════════════════════════════════
#  CARREGAR / SALVAR
# ════════════════════════════════════════════════════════════════════════════

func _load_settings() -> void:
	slider_master.value = SettingsManager.get_setting("audio.master")
	slider_music.value  = SettingsManager.get_setting("audio.music")
	slider_sfx.value    = SettingsManager.get_setting("audio.sfx")

	check_fullscreen.button_pressed = SettingsManager.get_setting("video.fullscreen")
	var res_idx := RESOLUTIONS.find(Vector2i(
		SettingsManager.get_setting("video.resolution_x"),
		SettingsManager.get_setting("video.resolution_y")
	))
	option_resolution.select(clampi(res_idx if res_idx >= 0 else 0, 0, RESOLUTIONS.size() - 1))

	slider_mouse_sensitivity.value = SettingsManager.get_setting("controls.mouse_sensitivity")

	slider_font_size.value = SettingsManager.get_setting("accessibility.font_size")

	_apply_all()


func _save_settings() -> void:
	SettingsManager.set_setting("audio.master", slider_master.value)
	SettingsManager.set_setting("audio.music",  slider_music.value)
	SettingsManager.set_setting("audio.sfx",    slider_sfx.value)

	SettingsManager.set_setting("video.fullscreen",   check_fullscreen.button_pressed)
	var res: Vector2i = RESOLUTIONS[option_resolution.selected]
	SettingsManager.set_setting("video.resolution_x", res.x)
	SettingsManager.set_setting("video.resolution_y", res.y)

	SettingsManager.set_setting("controls.mouse_sensitivity", slider_mouse_sensitivity.value)

	SettingsManager.set_setting("accessibility.font_size", slider_font_size.value)

	SettingsManager.save()


# ════════════════════════════════════════════════════════════════════════════
#  APLICAR CONFIGURAÇÕES
# ════════════════════════════════════════════════════════════════════════════

func _apply_all() -> void:
	_apply_audio()
	_apply_video()
	_apply_accessibility()


func _apply_audio() -> void:
	_set_bus_volume("Master", slider_master.value)
	_set_bus_volume("Music",  slider_music.value)
	_set_bus_volume("SFX",    slider_sfx.value)


func _apply_video() -> void:
	var res: Vector2i = RESOLUTIONS[option_resolution.selected]
	DisplayServer.window_set_size(res)

	if check_fullscreen.button_pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _apply_accessibility() -> void:
	var root_theme := ThemeDB.get_project_theme()
	if root_theme:
		root_theme.default_font_size = int(slider_font_size.value)


func _set_bus_volume(bus_name: String, db_value: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, db_value)


# ════════════════════════════════════════════════════════════════════════════
#  REBIND DE TECLAS
# ════════════════════════════════════════════════════════════════════════════

var _rebinding_action := ""
var _rebinding_button: Button = null
var _rebind_locked := false


func _start_rebind(action: String, btn: Button) -> void:
	_rebinding_action = action
	_rebinding_button = btn
	btn.text = "[ Pressione uma tecla... ]"
	set_process_unhandled_input(false)
	_rebind_locked = true
	await get_tree().create_timer(0.2).timeout
	_rebind_locked = false
	set_process_input(true)


func _input(event: InputEvent) -> void:
	if _rebinding_action.is_empty():
		return
	if _rebind_locked:
		return
	if not (event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton):
		return
	if event is InputEventKey or event is InputEventMouseButton:
		if not event.pressed:
			return
		get_viewport().set_input_as_handled()
	if event is InputEventKey and event.keycode == KEY_ESCAPE:
		_cancel_rebind()
		return

	InputManager.definir_evento(_rebinding_action, event)
	_rebinding_button.text = _get_action_key_label(_rebinding_action)
	_rebinding_action = ""
	_rebinding_button = null
	set_process_input(false)
	set_process_unhandled_input(true)


func _cancel_rebind() -> void:
	if _rebinding_button:
		_rebinding_button.text = _get_action_key_label(_rebinding_action)
	_rebinding_action = ""
	_rebinding_button = null
	set_process_input(false)
	set_process_unhandled_input(true)


# ════════════════════════════════════════════════════════════════════════════
#  SINAIS E HANDLERS
# ════════════════════════════════════════════════════════════════════════════

func _connect_signals() -> void:
	btn_apply.pressed.connect(_on_apply_pressed)
	btn_back.pressed.connect(_on_back_pressed)
	btn_close.pressed.connect(_on_back_pressed)
	check_fullscreen.toggled.connect(_on_fullscreen_toggled)


func _on_apply_pressed() -> void:
	_apply_all()
	_save_settings()


func _on_back_pressed() -> void:
	btn_back.disabled = true
	btn_close.disabled = true

	var tween := create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "position:y", get_viewport_rect().size.y, 0.4)

	await tween.finished
	menu_closed.emit()


func _on_fullscreen_toggled(pressed: bool) -> void:
	if pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
