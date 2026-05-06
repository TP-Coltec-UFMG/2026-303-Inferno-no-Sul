extends Control

## Emitido quando o jogador fecha o menu de opções.
signal menu_closed

# ─── Referências ─────────────────────────────────────────────────────────────

@onready var tab_container: TabContainer = %TabContainer
@onready var btn_apply: Button = %BtnApply
@onready var btn_back:  Button = %BtnBack
@onready var btn_close: Button = %BtnClose

# Widgets de exemplo (Áudio)
@onready var slider_master: HSlider = %SliderMaster
@onready var slider_music:  HSlider = %SliderMusic
@onready var slider_sfx:    HSlider = %SliderSfx

# Widgets de exemplo (Vídeo)
@onready var check_fullscreen: CheckButton = %BtnFullscreen
@onready var option_resolution: OptionButton = %BtnResolution


# ════════════════════════════════════════════════════════════════════════════
#  CICLO DE VIDA
# ════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_load_current_settings()
	_connect_signals()

	# Fecha com Escape
	set_process_unhandled_input(true)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()


# ─── Carrega configurações salvas nos widgets ─────────────────────────────────

func _load_current_settings() -> void:
	# Áudio
	slider_master.value = AudioServer.get_bus_volume_db(
			AudioServer.get_bus_index("Master"))
	slider_music.value  = AudioServer.get_bus_volume_db(
			AudioServer.get_bus_index("Music"))
	slider_sfx.value    = AudioServer.get_bus_volume_db(
			AudioServer.get_bus_index("SFX"))

	# Vídeo
	check_fullscreen.button_pressed = \
			DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN


# ─── Conexão de Sinais ───────────────────────────────────────────────────────

func _connect_signals() -> void:
	btn_apply.pressed.connect(_on_apply_pressed)
	btn_back.pressed.connect(_on_back_pressed)
	btn_close.pressed.connect(_on_back_pressed)
	check_fullscreen.toggled.connect(_on_fullscreen_toggled)


# ════════════════════════════════════════════════════════════════════════════
#  HANDLERS
# ════════════════════════════════════════════════════════════════════════════

func _on_apply_pressed() -> void:
	_apply_audio_settings()
	_apply_video_settings()
	# Aqui: salve as configurações via SettingsManager (autoload futuro).


func _on_back_pressed() -> void:
	menu_closed.emit()  # MainMenu.gd escuta e chama queue_free().


func _on_fullscreen_toggled(pressed: bool) -> void:
	if pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


# ─── Aplicação de Configurações ──────────────────────────────────────────────

func _apply_audio_settings() -> void:
	_set_bus_volume("Master", slider_master.value)
	_set_bus_volume("Music",  slider_music.value)
	_set_bus_volume("SFX",    slider_sfx.value)


func _apply_video_settings() -> void:
	# Resolução (exemplo com OptionButton populado):
	# var res := _get_selected_resolution()
	# DisplayServer.window_set_size(res)
	pass


func _set_bus_volume(bus_name: String, db_value: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, db_value)
