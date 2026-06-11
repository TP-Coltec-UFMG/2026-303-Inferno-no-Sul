extends Area2D
class_name Porta

enum Estado { TRANCADA, DESBLOQUEADA, ABERTA }

@export var id: String = ""
@export var prompt_texto: String = "Abrir"

@onready var _prompt: Label = get_node_or_null("Prompt")

var estado: Estado = Estado.TRANCADA
var _player_dentro: bool = false

signal estado_alterado(novo: Estado)


func _ready() -> void:
	add_to_group("salvavel")
	add_to_group("porta_trancada")
	if id == "":
		id = name
	body_entered.connect(_ao_entrar)
	body_exited.connect(_ao_sair)
	if _prompt:
		_prompt.text = prompt_texto
		_prompt.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if _player_dentro and event.is_action_pressed("interact"):
		_ao_interagir()
		get_viewport().set_input_as_handled()


## Chamado quando player interage. Subclasses podem sobrescrever.
func _ao_interagir() -> void:
	match estado:
		Estado.DESBLOQUEADA:
			abrir()
		Estado.TRANCADA:
			push_warning("Porta '%s' está trancada." % id)


func _ao_entrar(body: Node2D) -> void:
	if body is MC:
		_player_dentro = true
		if _prompt:
			_prompt.visible = estado != Estado.ABERTA


func _ao_sair(body: Node2D) -> void:
	if body is MC:
		_player_dentro = false
		if _prompt:
			_prompt.visible = false


func destrancar() -> void:
	if estado == Estado.TRANCADA:
		_set_estado(Estado.DESBLOQUEADA)


func abrir() -> void:
	if estado == Estado.DESBLOQUEADA:
		_set_estado(Estado.ABERTA)


func _set_estado(novo: Estado) -> void:
	estado = novo
	estado_alterado.emit(estado)
	_aplicar_estado()


func _aplicar_estado() -> void:
	match estado:
		Estado.TRANCADA, Estado.DESBLOQUEADA:
			if has_node("CollisionShape2D"):
				$CollisionShape2D.disabled = false
		Estado.ABERTA:
			if has_node("CollisionShape2D"):
				$CollisionShape2D.disabled = true
			if _prompt:
				_prompt.visible = false


# ── Save ──────────────────────────────────────────────────────────────────────

func get_save_data() -> Dictionary:
	return { "id": id, "estado": estado }


func load_save_data(d: Dictionary) -> void:
	estado = d.get("estado", Estado.TRANCADA) as Estado
	_aplicar_estado()
