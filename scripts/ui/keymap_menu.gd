extends Control

signal menu_closed

# ─── Referências de UI ───────────────────────────────────────────────────────

@onready var btn_apply: Button = %BtnApply
@onready var btn_back:  Button = %BtnBack
@onready var btn_close: Button = %BtnClose

@onready var container_bindings: Control = %ContainerBindings

# ─── Configuração de fonte ───────────────────────────────────────────────────
# Mesmo tamanho e mesma fonte "fina" usada nos labels do menu de Opções
# (ex: "Font size", "Resolução"), para manter a identidade visual do talão.
const DEFAULT_FONT_SIZE := 32
const LIST_FONT := preload("res://assets/Fonts/Texto_P/JMH Typewriter-Thin.otf")
const LIST_FONT_COLOR := Color(0, 0, 0, 1)

# ─── Dados ───────────────────────────────────────────────────────────────────

const REMAPPABLE_ACTIONS := [
	"move_left", "move_right", "move_up", "move_down",
	"jump", "attack", "interact", "pause",
	"correr", "agachar",
]

# Nomes exibidos na tela — separados do ID real da ação, que precisa
# continuar batendo com o Input Map do projeto (Project Settings) e com
# o resto do código que lê essas ações (ex: Input.is_action_pressed).
const ACTION_DISPLAY_NAMES := {
	"move_left": "Mover Esquerda",
	"move_right": "Mover Direita",
	"move_up": "Mover Cima",
	"move_down": "Mover Baixo",
	"jump": "Pular",
	"attack": "Atacar",
	"interact": "Interagir",
	"pause": "Pausar",
	"correr": "Correr",
	"agachar": "Agachar",
}


# ════════════════════════════════════════════════════════════════════════════
#  CICLO DE VIDA
# ════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
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
#  POPULAÇÃO DA LISTA DE TECLAS (LAYOUT EM DUAS COLUNAS)
# ════════════════════════════════════════════════════════════════════════════

## Monta a lista de remapeamento em duas colunas, para caber no espaço
## disponível do talão sem ficar visualmente poluído.
func _build_rebind_list() -> void:
	for child in container_bindings.get_children():
		child.queue_free()

	var row_height := 64         
	var col_width := 430          
	var btn_gap := 24            
	var actions_per_column := ceili(REMAPPABLE_ACTIONS.size() / 2.0)

	for i in REMAPPABLE_ACTIONS.size():
		var action: String = REMAPPABLE_ACTIONS[i]
		var col := i / actions_per_column
		var row := i % actions_per_column
		var col_x := col * col_width

		var label := Label.new()
		label.text = ACTION_DISPLAY_NAMES.get(action, action.replace("_", " ").capitalize())
		label.add_theme_font_size_override("font_size", DEFAULT_FONT_SIZE)
		label.add_theme_color_override("font_color", LIST_FONT_COLOR)
		label.add_theme_font_override("font", LIST_FONT)
		label.position = Vector2(col_x, row * row_height)
		container_bindings.add_child(label)


		var label_width: float = label.get_minimum_size().x

		var btn := Button.new()
		btn.text = _get_action_key_label(action)
		btn.add_theme_font_size_override("font_size", DEFAULT_FONT_SIZE)
		btn.add_theme_color_override("font_color", LIST_FONT_COLOR)
		btn.add_theme_color_override("font_hover_color", Color(0.32, 0.32, 0.32))
		btn.add_theme_font_override("font", LIST_FONT)
		btn.position = Vector2(col_x + label_width + btn_gap, row * row_height)
		btn.pressed.connect(_start_rebind.bind(action, btn))
		container_bindings.add_child(btn)


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
	_rebinding_button.add_theme_font_size_override("font_size", DEFAULT_FONT_SIZE)
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


func _on_apply_pressed() -> void:
	# Os binds já são aplicados imediatamente ao remapear (InputManager.definir_evento).
	# Aqui apenas garantimos a persistência, se o projeto salvar o InputMap junto
	# com as demais configurações.
	SettingsManager.save()


func _on_back_pressed() -> void:
	btn_back.disabled = true
	btn_close.disabled = true

	var tween := create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "position:y", get_viewport_rect().size.y, 0.4)

	await tween.finished
	menu_closed.emit()
