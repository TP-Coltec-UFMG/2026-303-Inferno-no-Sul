extends Node

## ════════════════════════════════════════════════════════════════════════════
##  SettingsManager — Autoload Singleton
##
##  Registrar em: Project > Project Settings > Autoload
##    Nome:    SettingsManager
##    Caminho: res://autoload/SettingsManager.gd
##
##  API principal:
##    SettingsManager.get_setting("audio.master")          → Variant
##    SettingsManager.set_setting("audio.master", -6.0)
##    SettingsManager.save()
##    SettingsManager.reset()
##
##  Remaps de input:
##    SettingsManager.save_remap("jump", events)
##    SettingsManager.load_remaps()                → aplica ao InputMap
## ════════════════════════════════════════════════════════════════════════════

const SETTINGS_PATH := "user://settings.cfg"

# ─── Seções usadas internamente no ConfigFile ─────────────────────────────────
const _SEC_AUDIO         := "audio"
const _SEC_VIDEO         := "video"
const _SEC_CONTROLS      := "controls"
const _SEC_ACCESSIBILITY := "accessibility"
const _SEC_REMAPS        := "remaps"

## Todos os valores padrão. Chave no formato "secao.subchave".
const _DEFAULTS: Dictionary = {
	# ── Áudio (dB: -80 a +6) ────────────────────────────────────────────
	"audio.master":                 0.0,
	"audio.music":                 -6.0,
	"audio.sfx":                    0.0,

	# ── Vídeo ───────────────────────────────────────────────────────────
	"video.fullscreen":             false,
	"video.resolution_x":           1280,
	"video.resolution_y":            720,
	"video.vsync":                  true,

	# ── Controles ────────────────────────────────────────────────────────
	"controls.mouse_sensitivity":   1.0,   # multiplicador (0.1 – 5.0)

	# ── Acessibilidade ───────────────────────────────────────────────────
	"accessibility.font_size":      16,    # int (12 – 32)
	"accessibility.high_contrast":  false,
}

# ─── Sinais reativos ──────────────────────────────────────────────────────────

## Disparado imediatamente ao alterar font_size via set_setting().
signal font_size_changed(new_size: int)

## Disparado imediatamente ao alterar high_contrast via set_setting().
signal high_contrast_changed(enabled: bool)


# ─── Estado interno ───────────────────────────────────────────────────────────
var _cfg := ConfigFile.new()


# ════════════════════════════════════════════════════════════════════════════
#  CICLO DE VIDA
# ════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	load_from_disk()


# ════════════════════════════════════════════════════════════════════════════
#  API PÚBLICA — CHAVE / VALOR
# ════════════════════════════════════════════════════════════════════════════

## Lê o valor de uma chave no formato "secao.subchave".
## Devolve o padrão definido em _DEFAULTS quando a chave não existe.
func get_setting(key: String) -> Variant:
	var parts := _split_key(key)
	if parts.is_empty():
		return null
	return _cfg.get_value(parts[0], parts[1], _DEFAULTS.get(key, null))


## Grava o valor de uma chave no formato "secao.subchave" (em memória).
## Chame save() para persistir no disco.
func set_setting(key: String, value: Variant) -> void:
	var parts := _split_key(key)
	if parts.is_empty():
		return
	_cfg.set_value(parts[0], parts[1], value)

	# Dispara sinais reativos para chaves especiais
	match key:
		"accessibility.font_size":
			font_size_changed.emit(int(value))
		"accessibility.high_contrast":
			high_contrast_changed.emit(bool(value))


## Persiste todas as configurações e remaps em disco.
func save() -> void:
	var err := _cfg.save(SETTINGS_PATH)
	if err != OK:
		push_error("SettingsManager: falha ao salvar '%s' (erro %d)" % [SETTINGS_PATH, err])


## Restaura todos os padrões, aplica ao motor e salva em disco.
func reset() -> void:
	_cfg = ConfigFile.new()
	_write_defaults()
	save()
	apply_all()


# ════════════════════════════════════════════════════════════════════════════
#  REMAPS DE INPUT
# ════════════════════════════════════════════════════════════════════════════

## Serializa e salva o remap de uma ação.
## Não persiste sozinho — chame save() depois.
func save_remap(action: String, events: Array[InputEvent]) -> void:
	_cfg.set_value(_SEC_REMAPS, action, _serialize_events(events))


## Carrega e aplica todos os remaps salvos ao InputMap do motor.
func load_remaps() -> void:
	if not _cfg.has_section(_SEC_REMAPS):
		return
	for action: String in _cfg.get_section_keys(_SEC_REMAPS):
		if not InputMap.has_action(action):
			continue
		var raw: String = _cfg.get_value(_SEC_REMAPS, action, "")
		if raw.is_empty():
			continue
		var events := _deserialize_events(raw)
		InputMap.action_erase_events(action)
		for ev in events:
			InputMap.action_add_event(action, ev)


## Remove o remap salvo de uma ação e restaura o padrão definido no projeto.
func reset_remap(action: String) -> void:
	if _cfg.has_section_key(_SEC_REMAPS, action):
		_cfg.erase_section_key(_SEC_REMAPS, action)
	if not InputMap.has_action(action):
		return
	InputMap.action_erase_events(action)
	for ev in ProjectSettings.get_setting("input/" + action, {}).get("events", []):
		InputMap.action_add_event(action, ev)


# ════════════════════════════════════════════════════════════════════════════
#  APLICAÇÃO AO MOTOR
# ════════════════════════════════════════════════════════════════════════════

## Aplica todas as configurações em memória ao motor (áudio, vídeo, remaps,
## acessibilidade). Chamado automaticamente ao carregar do disco.
func apply_all() -> void:
	_apply_audio()
	_apply_video()
	load_remaps()
	font_size_changed.emit(int(get_setting("accessibility.font_size")))
	high_contrast_changed.emit(bool(get_setting("accessibility.high_contrast")))


func _apply_audio() -> void:
	_set_bus_db("Master", get_setting("audio.master"))
	_set_bus_db("Music",  get_setting("audio.music"))
	_set_bus_db("SFX",    get_setting("audio.sfx"))


func _apply_video() -> void:
	if bool(get_setting("video.fullscreen")):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	DisplayServer.window_set_size(Vector2i(
		int(get_setting("video.resolution_x")),
		int(get_setting("video.resolution_y"))
	))

	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if bool(get_setting("video.vsync"))
		else DisplayServer.VSYNC_DISABLED
	)


func _set_bus_db(bus_name: String, db: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, db)
	else:
		push_warning("SettingsManager: bus de áudio '%s' não encontrado." % bus_name)


# ════════════════════════════════════════════════════════════════════════════
#  DISCO
# ════════════════════════════════════════════════════════════════════════════

func load_from_disk() -> void:
	var err := _cfg.load(SETTINGS_PATH)
	if err != OK:
		# Primeira execução: grava os padrões e continua normalmente
		_write_defaults()
	apply_all()


func _write_defaults() -> void:
	for key: String in _DEFAULTS:
		var parts := _split_key(key)
		if not parts.is_empty():
			_cfg.set_value(parts[0], parts[1], _DEFAULTS[key])


# ════════════════════════════════════════════════════════════════════════════
#  SERIALIZAÇÃO DE INPUTEVENTS
#
#  Formato de cada token:
#    key:<keycode>               →  InputEventKey
#    joy:<button_index>          →  InputEventJoypadButton
#    axis:<axis>:<axis_value>    →  InputEventJoypadMotion
#  Múltiplos eventos separados por "|"
# ════════════════════════════════════════════════════════════════════════════

func _serialize_events(events: Array[InputEvent]) -> String:
	var tokens: Array[String] = []
	for ev in events:
		if ev is InputEventKey:
			tokens.append("key:%d" % (ev as InputEventKey).physical_keycode)
		elif ev is InputEventJoypadButton:
			tokens.append("joy:%d" % (ev as InputEventJoypadButton).button_index)
		elif ev is InputEventJoypadMotion:
			var m := ev as InputEventJoypadMotion
			tokens.append("axis:%d:%f" % [m.axis, m.axis_value])
	return "|".join(tokens)


func _deserialize_events(raw: String) -> Array[InputEvent]:
	var events: Array[InputEvent] = []
	for token in raw.split("|", false):
		var ev := _parse_event_token(token.strip_edges())
		if ev != null:
			events.append(ev)
	return events


func _parse_event_token(token: String) -> InputEvent:
	var p := token.split(":")
	if p.size() < 2:
		return null
	match p[0]:
		"key":
			var ev := InputEventKey.new()
			ev.physical_keycode = int(p[1]) as Key
			return ev
		"joy":
			var ev := InputEventJoypadButton.new()
			ev.button_index = int(p[1]) as JoyButton
			return ev
		"axis":
			if p.size() < 3:
				return null
			var ev := InputEventJoypadMotion.new()
			ev.axis       = int(p[1]) as JoyAxis
			ev.axis_value = float(p[2])
			return ev
	push_warning("SettingsManager: token desconhecido '%s'" % token)
	return null


# ════════════════════════════════════════════════════════════════════════════
#  UTILITÁRIOS
# ════════════════════════════════════════════════════════════════════════════

## Divide "secao.subchave" → ["secao", "subchave"].
## Retorna [] e emite um erro se o formato for inválido.
func _split_key(key: String) -> PackedStringArray:
	var parts := key.split(".", false, 1)
	if parts.size() != 2:
		push_error("SettingsManager: chave inválida '%s'. Formato esperado: 'secao.chave'." % key)
		return PackedStringArray()
	return parts
