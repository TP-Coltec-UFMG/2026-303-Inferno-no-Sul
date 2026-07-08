extends Control

signal menu_closed

# ─── Referências de UI ───────────────────────────────────────────────────────

@onready var btn_apply: Button = %BtnApply
@onready var btn_back:  Button = %BtnBack
@onready var btn_close: Button = %BtnClose

@onready var slider_master: HSlider = %SliderMaster
@onready var slider_music:  HSlider = %SliderMusic
@onready var slider_sfx:    HSlider = %SliderSfx

@onready var check_fullscreen:  CheckButton  = %BtnFullscreen
@onready var option_resolution: OptionButton = %BtnResolution

@onready var slider_mouse_sensitivity: HSlider = %SliderMouseSensitivity

@onready var slider_font_size: HSlider = %SliderFontSize

@onready var btn_keys: Button = %BtnKeys

# ─── Cena do menu de remapeamento de teclas ─────────────────────────────────
const KEYMAP_MENU_SCENE := preload("res://scenes/ui/keymap_menu.tscn")
var _keymap_instance: Control = null

# ─── Configuração de fonte ───────────────────────────────────────────────────

const DEFAULT_FONT_SIZE := 32
const MIN_FONT_SIZE := 16
const MAX_FONT_SIZE := 64

# ─── Dados ───────────────────────────────────────────────────────────────────

const RESOLUTIONS := [
	Vector2i(1280,  720),
	Vector2i(1600,  900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]

# ════════════════════════════════════════════════════════════════════════════
#  CICLO DE VIDA
# ════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_populate_resolutions()
	_load_settings()
	_connect_signals()
	set_process_unhandled_input(true)

	# Aplica a fonte padrão em tudo antes de qualquer coisa ficar visível
	_apply_font_size_to_all(DEFAULT_FONT_SIZE)

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


# ════════════════════════════════════════════════════════════════════════════
#  FONTE — APLICAÇÃO GLOBAL (32px padrão, ajustável)
# ════════════════════════════════════════════════════════════════════════════

## Aplica um tamanho de fonte fixo recursivamente em todos os
## Labels, Buttons, CheckButtons e OptionButtons abaixo de "node".
func _apply_font_size_to_all(size: int, node: Node = self) -> void:
	for child in node.get_children():
		if child is Label or child is Button or child is CheckButton or child is OptionButton:
			child.add_theme_font_size_override("font_size", size)
		# Chama recursivamente para pegar nós aninhados
		_apply_font_size_to_all(size, child)


## Chamado quando o slider de acessibilidade muda — reaplica em tudo.
func _on_font_size_changed(value: float) -> void:
	var size := clampi(int(value), MIN_FONT_SIZE, MAX_FONT_SIZE)
	_apply_font_size_to_all(size)

	var root_theme := ThemeDB.get_project_theme()
	if root_theme:
		root_theme.default_font_size = size


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

	# Se não houver valor salvo ainda, usa DEFAULT_FONT_SIZE
	var saved_font_size = SettingsManager.get_setting("accessibility.font_size")
	slider_font_size.value = saved_font_size if saved_font_size > 0 else DEFAULT_FONT_SIZE

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
	_on_font_size_changed(slider_font_size.value)


func _set_bus_volume(bus_name: String, db_value: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, db_value)


# ════════════════════════════════════════════════════════════════════════════
#  SINAIS E HANDLERS
# ════════════════════════════════════════════════════════════════════════════

func _connect_signals() -> void:
	btn_apply.pressed.connect(_on_apply_pressed)
	btn_back.pressed.connect(_on_back_pressed)
	btn_close.pressed.connect(_on_back_pressed)
	btn_keys.pressed.connect(_on_keys_pressed)
	check_fullscreen.toggled.connect(_on_fullscreen_toggled)
	slider_font_size.value_changed.connect(_on_font_size_changed)


## Abre a cena de remapeamento de teclas por cima do menu de opções.
func _on_keys_pressed() -> void:
	if _keymap_instance:
		return

	_keymap_instance = KEYMAP_MENU_SCENE.instantiate()
	get_parent().add_child(_keymap_instance)
	_keymap_instance.menu_closed.connect(_on_keymap_menu_closed)

	# Esconde o menu de opções enquanto o de teclas está aberto
	visible = false


## Chamado quando o menu de teclas é fechado (botão Voltar/X ou ESC).
func _on_keymap_menu_closed() -> void:
	visible = true
	if is_instance_valid(_keymap_instance):
		_keymap_instance.queue_free()
	_keymap_instance = null


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
