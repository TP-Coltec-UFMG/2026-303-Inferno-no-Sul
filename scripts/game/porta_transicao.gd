extends Area2D
class_name PortaTransicao

# ════════════════════════════════════════════════════════════════════════════
#  PortaTransicao — Area2D colocado nas bordas de cada sala.
#
#  Configurar no editor:
#    destino_path  → "res://scenes/game/patio.tscn"
#    spawn_pos     → posição do player na sala destino
#    prompt_texto  → texto do label filho "Prompt" (opcional)
#
#  O nó "Game" no root é buscado pelo nome — não depende de autoload.
# ════════════════════════════════════════════════════════════════════════════

@export var destino_path : String  = ""
@export var spawn_pos    : Vector2 = Vector2.ZERO
@export var prompt_texto : String  = "Ir para próxima área"

@onready var _prompt : Label = get_node_or_null("Prompt")

var _player_dentro := false


func _ready() -> void:
	body_entered.connect(_ao_entrar)
	body_exited.connect(_ao_sair)
	if _prompt:
		_prompt.text    = prompt_texto
		_prompt.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if _player_dentro and event.is_action_pressed("interact"):
		_transicionar()
		get_viewport().set_input_as_handled()


func _ao_entrar(body: Node2D) -> void:
	if body is MC:
		_player_dentro = true
		if _prompt:
			_prompt.visible = true


func _ao_sair(body: Node2D) -> void:
	if body is MC:
		_player_dentro = false
		if _prompt:
			_prompt.visible = false


func _transicionar() -> void:
	if destino_path.is_empty():
		push_error("PortaTransicao: destino_path não configurado.")
		return
	var game := get_tree().root.get_node_or_null("Game")
	if game == null:
		push_error("PortaTransicao: nó 'Game' não encontrado no root.")
		return
	game.ir_para_fase(destino_path, spawn_pos)
